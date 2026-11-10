-- ingestion-service schema: NWS alert messages, their update chain, and cached zone shapes.
-- Flyway runs this with the `ingestion` schema as the current schema (see ADR-0002).
-- PostGIS is installed in `public` and its types are qualified with `public.`, so this
-- works regardless of the search path and the extension is shared by both services.

CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;

-- One row per NWS alert message (Alert, Update or Cancel). Only status = Actual is stored.
CREATE TABLE alerts (
    id               text        PRIMARY KEY,
    message_type     text        NOT NULL CHECK (message_type IN ('Alert', 'Update', 'Cancel')),
    lifecycle        text        NOT NULL DEFAULT 'ACTIVE'
                                 CHECK (lifecycle IN ('ACTIVE', 'SUPERSEDED', 'CANCELLED')),
    event            text        NOT NULL,
    severity         text        NOT NULL
                                 CHECK (severity IN ('Extreme', 'Severe', 'Moderate', 'Minor', 'Unknown')),
    severity_rank    smallint    GENERATED ALWAYS AS (
                                     CASE severity WHEN 'Extreme'  THEN 4
                                                   WHEN 'Severe'   THEN 3
                                                   WHEN 'Moderate' THEN 2
                                                   WHEN 'Minor'    THEN 1
                                                   ELSE 0 END) STORED,
    urgency          text        NOT NULL,
    certainty        text        NOT NULL,
    headline         text,
    description      text,
    instruction      text,
    area_desc        text        NOT NULL,
    sender_name      text,
    vtec             text[]      NOT NULL DEFAULT '{}',
    affected_zones   text[]      NOT NULL DEFAULT '{}',
    area             public.geography(Geometry, 4326),
    area_source      text        CHECK (area_source IN ('ALERT', 'ZONES')),
    sent             timestamptz NOT NULL,
    effective        timestamptz NOT NULL,
    onset            timestamptz,
    expires          timestamptz NOT NULL,
    ends             timestamptz,
    in_effect_until  timestamptz GENERATED ALWAYS AS (COALESCE(ends, expires)) STORED,
    raw              jsonb       NOT NULL,
    first_seen_at    timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT alerts_area_and_source_together CHECK ((area IS NULL) = (area_source IS NULL))
);

-- Users almost only query active alerts, so both indexes cover active rows only.
-- Queries must include `lifecycle = 'ACTIVE'` for Postgres to use them.
CREATE INDEX alerts_area_active_gix  ON alerts USING GIST (area)     WHERE lifecycle = 'ACTIVE';
CREATE INDEX alerts_until_active_idx ON alerts (in_effect_until)     WHERE lifecycle = 'ACTIVE';

-- Which earlier messages each Update or Cancel replaces.
-- referenced_id has no foreign key: a message may reference one StormWatch never stored.
CREATE TABLE alert_references (
    alert_id         text        NOT NULL REFERENCES alerts (id) ON DELETE CASCADE,
    referenced_id    text        NOT NULL,
    referenced_sent  timestamptz NOT NULL,
    PRIMARY KEY (alert_id, referenced_id)
);

-- Lets an older message arriving late find out it has already been replaced.
CREATE INDEX alert_references_referenced_idx ON alert_references (referenced_id);

-- NWS zone polygons, cached to build an alert's area when the alert has no geometry.
CREATE TABLE zones (
    id          text        PRIMARY KEY,
    zone_type   text        NOT NULL,
    name        text        NOT NULL,
    state       char(2),
    area        public.geography(Geometry, 4326) NOT NULL,
    fetched_at  timestamptz NOT NULL
);
