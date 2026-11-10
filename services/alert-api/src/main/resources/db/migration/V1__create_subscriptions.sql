-- alert-api schema: users' saved locations.
-- Flyway runs this with the `api` schema as the current schema (see ADR-0002).
-- PostGIS is installed in `public` and its types are qualified with `public.`;
-- IF NOT EXISTS makes this safe whichever service migrates first.

CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;

-- A user's saved place: alert them about alerts within radius_m of location
-- that are at least min_severity. user_id is the identity provider's `sub` claim.
CREATE TABLE subscriptions (
    id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            text        NOT NULL,
    name               text        NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
    location           public.geography(Point, 4326) NOT NULL,
    radius_m           integer     NOT NULL CHECK (radius_m BETWEEN 100 AND 200000),
    min_severity       text        NOT NULL DEFAULT 'Moderate'
                                   CHECK (min_severity IN ('Extreme', 'Severe', 'Moderate', 'Minor', 'Unknown')),
    min_severity_rank  smallint    GENERATED ALWAYS AS (
                                       CASE min_severity WHEN 'Extreme'  THEN 4
                                                         WHEN 'Severe'   THEN 3
                                                         WHEN 'Moderate' THEN 2
                                                         WHEN 'Minor'    THEN 1
                                                         ELSE 0 END) STORED,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    -- Also serves as the index for "list my subscriptions" (user_id is the leading column).
    CONSTRAINT subscriptions_user_name_unique UNIQUE (user_id, name)
);

-- Used in Week 2 to find the subscriptions a new alert affects.
CREATE INDEX subscriptions_location_gix ON subscriptions USING GIST (location);
