# Architecture Decision Records

This directory captures durable architectural decisions for FIVUCSAS that previously lived buried in `CHANGELOG.md` narrative or in `docs/plans/`. Each ADR is a short, dated, immutable record of one decision: the context, the choice, the consequences, and the alternatives that were considered and rejected.

## Convention

We follow a lightweight [MADR](https://adr.github.io/madr/) template:

```
# ADR NNNN: <short title>

**Status**: Accepted | Superseded by ADR-NNNN | Deprecated
**Date**: YYYY-MM-DD
**Deciders**: Roles / individuals

## Context
Why are we deciding this now? What forces are at play?

## Decision
We will <verb> <object>.

## Consequences
Positive, negative, and neutral follow-on effects.

## Alternatives considered
Each rejected option + the reason it lost.
```

ADRs are **append-only**. To overturn an existing decision, write a new ADR that supersedes it and update the older one's status field — do not edit the rejected decision.

Numbering is monotonic. New ADRs claim the next free number. Filenames are `NNNN-kebab-case-title.md`.

## Index

| # | Title | Status | Date |
|---|-------|--------|------|
| 0001 | [Hosted-first OIDC as primary integration mode](0001-hosted-first-oidc.md) | Accepted | 2026-04-16 |
| 0002 | [PostgreSQL + pgvector for biometric embeddings](0002-pgvector.md) | Accepted | 2026-03-19 |
| 0003 | [Remove client-side MobileFaceNet](0003-mobilefacenet-removal.md) | Accepted | 2026-04-18 |
| 0004 | [Facenet512 as server-authoritative face embedding](0004-facenet512-server-authoritative.md) | Accepted | 2026-04-18 |
| 0005 | [RFC 6749 §10.4 refresh-token family-revoke (V50)](0005-rfc-6749-family-revoke.md) | Accepted | 2026-04-30 |
| 0006 | [V53 BEFORE-DELETE trigger to forbid hard-deletes on users + tenants](0006-v53-before-delete-trigger.md) | Accepted | 2026-04-30 |
| 0007 | [`Persistable<UUID>` wire format for refresh tokens (PR #71)](0007-persistable-uuid-refresh-tokens.md) | Accepted | 2026-05-04 |
| 0008 | [Spoof-detector as a standalone submodule](0008-spoof-detector-standalone.md) | Accepted | 2026-05-07 |

## How to add a new ADR

1. Claim the next number. Run `ls -1 *.md | grep -E '^[0-9]{4}-' | sort | tail -1` to see the highest in use.
2. Copy this template into `NNNN-your-title.md`:
   ```
   # ADR NNNN: <title>

   **Status**: Accepted
   **Date**: YYYY-MM-DD
   **Deciders**: <roles>

   ## Context
   ## Decision
   ## Consequences
   ## Alternatives considered
   ```
3. Open a PR with the ADR. Reviewers should challenge the **alternatives considered** section — if it is empty or perfunctory, the decision was not really made.
4. Once merged, append a row to the index table above.
5. Cross-reference the ADR from the corresponding `CHANGELOG.md` entry and from any related design doc in `docs/plans/`.

## Why ADRs?

- **Onboarding**: a new contributor can read 8 ADRs and have most of the load-bearing why behind the platform.
- **Drift detection**: if code starts violating an Accepted ADR, the deviation is visible in code review.
- **Audit trail**: regulators and academic reviewers (the project is a CSE4297 deliverable) get a clean decision log without spelunking through 800 lines of CHANGELOG.

For the underlying technology choices and current state, see `02-architecture/ARCHITECTURE_ANALYSIS.md`.
