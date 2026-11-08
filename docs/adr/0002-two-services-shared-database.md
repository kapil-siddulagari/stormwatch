# 0002. Share one PostgreSQL database between services (temporary)

Status: Accepted

Date: 2026-11-06

## Context

StormWatch has two services: ingestion-service polls the National Weather
Service and stores alerts; alert-api serves alerts and manages user
subscriptions. The usual microservices practice is a database per service,
so each service can change its schema, scale and fail independently.

In Week 1 there is no event pipeline yet. The only way for alert-api to see
the alerts that ingestion-service produces is to read them from the database
ingestion-service writes to. Building an event-driven read model now would
delay the core features (ingestion, geospatial queries, security) that the
rest of the system depends on.

## Decision

Both services will use the same PostgreSQL database for Week 1, with
ownership kept explicit so the shortcut is easy to remove:

- Each service gets its own schema: `ingestion` (alerts, zones) and `api`
  (subscriptions).
- Each service runs its own Flyway migrations against its own schema only,
  with a separate Flyway history table.
- alert-api only reads from the `ingestion` schema and never writes to it.
  For now this is a convention; database-level read-only grants may follow.
- In Week 2, ingestion-service will publish alert events to Kafka and
  alert-api will build its own read model, ending shared table access.

## Consequences

- One database to run locally and deploy, so less setup while core features
  are built.
- Schema coupling: a change to the alerts tables can break alert-api without
  either service's code changing. Separate schemas make this coupling
  visible, but do not remove it.
- Shared failure: if the database is unavailable or overloaded, both
  services are affected.
- The services cannot choose their data stores or tune their databases
  independently.
- A Week 2 ADR will supersede this one when the Kafka read model is in place.