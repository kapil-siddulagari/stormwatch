# 0001. Record architecture decisions

Status: Accepted

Date: 2026-11-06

## Context

StormWatch makes design choices that will not be obvious from the code alone:
service boundaries, data stores, messaging, deployment, and security. Without
a record of the reasoning, those choices are hard to review, easy to undo by
accident, and hard to revisit when circumstances change.

## Decision

We will record significant architecture decisions as Architecture Decision
Records, using the format described by Michael Nygard.

- ADRs live in `docs/adr/`, one Markdown file per decision.
- Files are numbered sequentially: `NNNN-short-title.md`.
- Each ADR has Title, Status, Date, Context, Decision, and Consequences.
- A decision is "significant" if it is hard to reverse, affects more than one
  component, or is likely to be questioned later.
- Accepted ADRs are not edited. A changed decision gets a new ADR, and the
  old one is marked "Superseded by ADR-NNNN".

## Consequences

- The reasoning behind the system's design is kept in the repository,
  versioned and reviewed alongside the code.
- Writing an ADR adds a small amount of effort to each significant decision.
- Superseded ADRs remain as history, showing how and why the design evolved.