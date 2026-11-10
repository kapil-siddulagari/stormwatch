# 0005. Store spatial data as PostGIS geography in SRID 4326

Status: Accepted

Date: 2026-11-10

## Context

StormWatch stores three kinds of shapes: alert areas (polygons and
multipolygons from NWS), cached zone polygons, and subscription locations
(points). The central query asks for active alerts within a user-chosen
radius of a point, with the radius given in meters (100 m to 200 km).

NWS publishes all shapes as GeoJSON longitude/latitude coordinates (WGS 84,
SRID 4326), and coverage spans the whole United States, including Alaska,
Hawaii, territories and marine zones.

PostGIS offers two column types for this data:

- `geometry` treats coordinates as points on a flat plane. With SRID 4326 its
  distances are in degrees, and a degree of longitude shrinks from about
  111 km at the equator to about 40 km in northern Alaska. Getting meters
  means casting to `geography` in every query, or transforming to a
  projected coordinate system, which is only accurate for one region.
- `geography` treats coordinates as points on the Earth's surface. Distances
  and buffers are in meters and stay correct over large areas and at any
  latitude, at the cost of slower calculations and a smaller set of
  supported functions.

## Decision

Use `geography` with SRID 4326 for every spatial column:

- `ingestion.alerts.area` and `ingestion.zones.area`:
  `geography(Geometry, 4326)`, since NWS sends both Polygon and MultiPolygon
  shapes, and a union of zones is often a MultiPolygon.
- `api.subscriptions.location`: `geography(Point, 4326)`, so the database
  rejects anything other than a point.

Each spatial column gets a GiST index. Types are written as
`public.geography` because PostGIS is installed in the `public` schema
(see ADR-0002).

## Consequences

- The main query works directly in meters:
  `ST_DWithin(area, point::geography, radius_m)`. It is correct anywhere in
  the country without per-query casts or projections, and it uses the GiST
  index (verified with 20,000 synthetic alerts).
- Data is stored exactly as NWS sends it, with no coordinate transformation
  on ingest.
- Calculations on a sphere are slower than planar ones. At StormWatch's scale
  (thousands of active alerts) this is negligible, and the index keeps
  searches fast.
- Some PostGIS functions do not accept `geography`. For example, building an
  alert's area from its zones needs `ST_Union`, which requires a cast to
  `geometry` and back. These casts are confined to ingestion code.
- JPA entities need a spatial type mapping (Hibernate Spatial) on Day 3.
- Revisit if StormWatch needs heavy geometric processing that `geography`
  does not support, or high-volume spatial joins where planar speed matters
  more than global accuracy.
