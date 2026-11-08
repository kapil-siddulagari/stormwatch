# 0004. Use a multi-architecture PostGIS image for local development

Status: Accepted

Date: 2026-11-06

## Context

Local development runs on Apple Silicon (ARM64). The official
`postgis/postgis` Docker image is published only for amd64. It can run
under emulation (`platform: linux/amd64`), but every database operation is
then translated, slowing local work and Testcontainers-based tests, which
start fresh databases on each run.

## Decision

Use `imresamu/postgis`, pinned to `17-3.6.1-bookworm`. It is built from the
same Dockerfiles by a maintainer of the official PostGIS images, and is
published for both amd64 and arm64. Use the same image in Docker Compose,
Testcontainers and CI.

## Consequences

- Native performance on Apple Silicon; the same image runs on amd64 CI
  runners, so local and CI environments match.
- The image comes from an individual maintainer's account rather than the
  official repository, and its ARM64 support is labeled experimental.
- Production will not use this image: managed PostgreSQL (for example AWS
  RDS) provides PostGIS directly.
- Revisit if the official `postgis/postgis` image adds ARM64 support.