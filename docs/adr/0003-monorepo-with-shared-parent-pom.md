# 0003. Use a monorepo with a shared Maven parent POM

Status: Accepted

Date: 2026-11-06

## Context

StormWatch consists of several independently deployable services, plus
shared infrastructure configuration (Docker Compose, Terraform, Helm) and
documentation. The code could be organized as one repository with a shared
build, one repository with fully independent builds, or one repository per
service.

The project is also a portfolio piece: a reviewer should be able to
understand the whole system from a single link, and run it with a few
commands.

## Decision

Keep all services in one repository. A root `pom.xml` (`stormwatch-parent`)
inherits from `spring-boot-starter-parent` and aggregates the services as
Maven modules. Each service:

- has its own `main` class, configuration, port, and (later) container image;
- inherits dependency and plugin versions from the shared parent;
- is built with a single Maven Wrapper at the repository root.

## Consequences

- Dependency versions stay consistent across services, and one command
  builds and tests everything.
- The whole system, including infrastructure and ADRs, is visible in one
  place.
- Services share a release of their dependency versions: upgrading Spring
  Boot upgrades every service at once.
- CI must avoid rebuilding and redeploying every service on every change;
  path-based pipeline triggers will handle this in Week 3.
- Separate deployables remain the architectural boundary. If a service needs
  an independent release cycle, it can drop the shared parent without any
  change to how services communicate.