# ADR 0002: PostgreSQL + pgvector for biometric embeddings

**Status**: Accepted
**Date**: 2026-03-19
**Deciders**: Backend, biometric processing, data

## Context

FIVUCSAS needs to store and search face and voice embeddings at tenant-scale. Embeddings are dense float vectors — 512-dim for Facenet512 face embeddings, 256-dim for Resemblyzer voice embeddings. The two operations we run against them are:

1. **Verify(user, probe)** — compute cosine similarity between a probe embedding and a single known embedding. Constant-time, no index needed.
2. **Identify / search(probe)** — find the top-k nearest neighbours across an entire tenant's enrollments. Requires an ANN index.

We already run PostgreSQL 17 as the source of truth for users, tenants, audit logs, OAuth2 clients, and so on. Adding a separate vector DB (Pinecone, Milvus, Weaviate) would mean:

- A second persistence layer to back up, monitor, and rotate credentials for.
- Eventual consistency between "this user exists in Postgres" and "their embedding exists in vector store" — exactly the kind of cross-store integrity problem we avoid.
- Extra failure mode at enrollment time (commit to Postgres, then commit to vector DB; what if step 2 fails?).
- Cost: a managed vector DB at our enrollment volume is non-trivial compared to a single Postgres instance.

The single-machine prototype already used pgvector 0.2.x for the face table. The question was whether to keep it as the platform scales.

## Decision

We standardize on **PostgreSQL + pgvector** as the only vector store. All embedding tables (`face_embeddings`, `voice_enrollments`, `client_embedding_observations`) live in the same database as the rest of the domain, with vector columns typed `vector(N)`. ANN search uses **HNSW** indexes (`USING hnsw (embedding vector_cosine_ops)`) on tables that need search; observation-only tables get no index.

Operationally:

- Single backup, single replica, single set of credentials.
- Embedding-vs-domain-data integrity is enforced by FK + transactional commit, not by cross-store coordination.
- pgvector version pin tracked in `infra/`; upgraded from 0.2.4 to 0.3.x (CHANGELOG entry).
- HNSW index on `face_embeddings` and `voice_enrollments`. Log-only `client_embedding_observations` (Alembic 0004) deliberately has no HNSW — it is written but never searched.

## Consequences

**Positive**
- One source of truth. A user, their tenant, their enrollment, and the embedding live in the same transactional boundary.
- Backups are atomic (pg_dump captures everything).
- Operational simplicity: one Docker container (`postgres:17`), one set of secrets, one monitoring dashboard.
- HNSW gives sub-10ms p99 for 1:N search at our current cohort sizes; verifiable with `EXPLAIN ANALYZE`.
- pgvector cosine ops integrate directly with JDBC / Hibernate — `PGvector` driver landed in `identity-core-api` cleanly.

**Negative**
- Single-store scaling: if embedding cardinality outgrows what one Postgres can serve, sharding tenants across Postgres clusters is the path forward (not bolt-on Pinecone). We assess this when face row count crosses ~10⁷.
- HNSW indexes are slower to build than IVFFlat. Initial bulk-load of historical data requires a maintenance window or per-tenant background build.
- We are coupled to pgvector's pace of feature work. Acceptable: it is widely deployed, BSD-licensed, and used by other identity products.

**Neutral**
- The biometric-processor (Python) and identity-core-api (Java) both speak pgvector. Two repository classes, one schema.

## Alternatives considered

- **Pinecone / Milvus / Weaviate / Qdrant (dedicated vector DB).** Rejected: dual-store integrity overhead, extra cost, no clear capability win at our volume.
- **Redis vector search.** Rejected: ephemeral by design; we already use Redis for cache + queue and do not want to graft durability onto it.
- **FAISS in-process inside biometric-processor.** Rejected: not durable; would lose embeddings on container restart unless we also wrote them to Postgres, which is the round-trip we are trying to avoid.
- **Raw `bytea` + similarity computed in app code.** Rejected: forecloses HNSW for the search use case; will not scale beyond verify-only.

## References

- Parent `CHANGELOG.md` `[2026-03-19]` Performance Investigation — missing HNSW indexes called out.
- `biometric-processor/CLAUDE.md` — pgvector repositories enforce tenant scoping on `find_similar()` and `delete()`.
- `04-database-schema.md` (`09-auth-flows/`) — vector column types per table.
- pgvector docs: https://github.com/pgvector/pgvector
