# NWS alerts: domain notes

Notes on the National Weather Service alerts API (`https://api.weather.gov/alerts/active`)
as StormWatch consumes it. Examples come from the sample payloads in
`services/ingestion-service/src/test/resources/nws/`.

NWS alerts follow the Common Alerting Protocol (CAP), returned as GeoJSON: a
`FeatureCollection` where each `Feature` is one alert message.

## Fields StormWatch uses

| Field | Example | Notes |
| --- | --- | --- |
| `properties.id` | `urn:oid:2.49.0.1.840.0.dff934...001.1` | Unique message id. The feature's top-level `id` is the same value as a URL |
| `messageType` | `Alert`, `Update`, `Cancel` | CAP also defines `Ack` and `Error`, which NWS does not use here |
| `status` | `Actual` | CAP values: `Actual`, `Exercise`, `System`, `Test`, `Draft` |
| `event` | `Flood Advisory` | Human-readable hazard name |
| `severity` | `Minor` | `Extreme`, `Severe`, `Moderate`, `Minor`, `Unknown` |
| `urgency` | `Expected` | `Immediate`, `Expected`, `Future`, `Past`, `Unknown` |
| `certainty` | `Likely` | `Observed`, `Likely`, `Possible`, `Unlikely`, `Unknown` |
| `sent`, `effective`, `onset` | `2026-11-09T14:38:00-06:00` | ISO-8601 with the issuing office's local offset |
| `expires`, `ends` | `2026-11-09T18:45:00-06:00` | See "When is an alert in effect?" |
| `areaDesc` | `Kimble, TX; Sutton, TX` | Text for display; not used for matching |
| `affectedZones` | `https://api.weather.gov/zones/county/TXC267` | Zone URLs; types seen: `county`, `forecast` |
| `geocode.UGC` | `TXC267`, `FLZ076` | Zone and county codes; first two letters are the state |
| `references` | see below | Earlier messages this one updates or cancels |
| `parameters.VTEC` | `/O.NEW.KSJT.FA.Y.0233.261109T2038Z-261110T0045Z/` | NWS event-tracking code (see below) |
| `geometry` | `Polygon` or `null` | See "Alerts without geometry" |

## 1. Identity and the update chain

Every message has its own `properties.id`. An Update or Cancel is a **new
message with a new id**; it does not reuse the id of the alert it changes.
It points back through `references`, a list of earlier messages:

```json
"references": [{
  "identifier": "urn:oid:2.49.0.1.840.0.f9f1d6...001.1",
  "sender": "w-nws.webmaster@noaa.gov",
  "sent": "2026-11-08T22:28:00-05:00"
}]
```

So one real-world hazard is a chain of messages:

```
Alert (id A)  <-- Update (id B, references A)  <-- Cancel (id C, references B)
```

`parameters.expiredReferences` holds older messages in the chain as one
space-separated string of `sender,identifier,sent` triples.

**VTEC** (Valid Time Event Code) identifies the hazard event itself across its
whole life. In `/O.NEW.KSJT.FA.Y.0233.261109T2038Z-261110T0045Z/`:

| Part | Value | Meaning |
| --- | --- | --- |
| Action | `NEW` | `NEW`, `CON` (continued), `EXT` (extended), `EXP` (expiring), `CAN` (cancelled), `UPG` (upgraded), and others |
| Office | `KSJT` | Issuing NWS office (San Angelo, TX) |
| Phenomenon.Significance | `FA.Y` | Areal flood, advisory |
| Event tracking number | `0233` | With office and phenomenon, identifies the event |
| Valid times | `261109T2038Z-261110T0045Z` | Event start and end in UTC (`000000T0000Z` = already in effect) |

`messageType` alone does not tell the whole story: the Coastal Flood Statement
sample is `messageType: Alert` with empty `references`, yet its VTEC action is
`EXT` and it carries 20 `expiredReferences`. It is an extension of an existing
event, not a new hazard.

## 2. Status values to ignore

Store and notify only `status = Actual`. `Exercise`, `System`, `Test` and
`Draft` messages are not real hazards and must never reach users.

## 3. When is an alert in effect?

- `expires`: when this **message** stops being valid; NWS normally sends a
  follow-up before then.
- `ends`: when the **hazard** itself is expected to end. It can be absent.

In all three samples the two are equal, but they need not be. StormWatch
treats an alert as in effect while all of these hold:

- `status` is `Actual`, and it has not been cancelled;
- no later message references it (otherwise the newer message replaces it);
- the current time is before `ends`, or before `expires` when `ends` is absent.

Store every timestamp as `timestamptz`; the offsets differ by issuing office.

## 4. Alerts without geometry

Only storm-based warnings (for example tornado, severe thunderstorm and flash
flood warnings) and some advisories come with a drawn polygon. Many other
products, such as statements, watches and most advisories, are issued for whole
zones or counties and arrive with `"geometry": null`. Two of the three samples
(the Rip Current and Coastal Flood Statements) have no geometry.

Fallback: resolve each URL in `affectedZones` (for example
`https://api.weather.gov/zones/forecast/FLZ076`) to that zone's polygon and use
the union of the zones as the alert's area. Zone shapes rarely change, so they
are cached in the `ingestion.zones` table instead of fetched on every poll.

## Implications for StormWatch

- Upsert by `properties.id`, so re-polling the same message is a no-op.
- On an Update or Cancel, mark every referenced message as superseded or
  cancelled. A message can reference one StormWatch never stored (for example
  after downtime); record the reference anyway and do not fail.
- Keep the raw feature as JSONB for debugging and reprocessing.
- Use VTEC (office + phenomenon + significance + tracking number) when grouping
  messages into one event for display.
- Send a `User-Agent` identifying StormWatch on every request, as NWS requires.
