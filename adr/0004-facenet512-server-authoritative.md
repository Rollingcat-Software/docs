# ADR 0004: Facenet512 as the server-authoritative face embedding

**Status**: Accepted; **amended 2026-06-11** (see note below)
**Date**: 2026-04-18
**Deciders**: Biometric processing, security, backend

> **Amendment (2026-06-11) — client-side embedding option.** The encoder choice
> (DeepFace **Facenet512**, **512-dim**, cosine match) is unchanged and remains the
> single platform-wide embedding shape. What changed: a flag-gated path
> (`app.auth.client-side-embedding`, default OFF) computes that **same Facenet512
> embedding in the browser** (onnxruntime-web, exported from our own SHA-pinned
> weights) and uploads **only the 512-d vector** — the raw face image never leaves
> the device. When the flag is ON, the client embedding is the **authoritative**
> template/probe (re-enroll on the client pipeline so probe and template share
> preprocessing); the server still owns the pgvector match, the liveness verdict, and
> the accept/reject decision, and the legacy image→Facenet512 path is retained as
> fallback. This supersedes the §Decision claim that the client embedding is "a
> different model / shape … never compared against `face_embeddings`": the *old*
> `geometry-512` pre-filter (ADR 0003) was indeed different, but the *new*
> client-side Facenet512 is identical to the server encoder by design. See
> [`plans/CLIENT_SIDE_ML_PLAN.md`](../plans/CLIENT_SIDE_ML_PLAN.md) (v3.0).

## Context

Once we accepted that the client-side embedding cannot make auth decisions (ADR 0003), the next question was which model the *server* should run as the authoritative face encoder. The biometric-processor service stack includes DeepFace, which exposes a handful of backends (`Facenet`, `Facenet512`, `ArcFace`, `OpenFace`, `VGG-Face`, `DeepFace`, etc.). The choice determines:

- The embedding dimensionality stored in `face_embeddings.embedding` (`vector(N)`).
- Verification thresholds (cosine similarity cutoff).
- The reference numbers for any future divergence analysis vs the client.

A few practical constraints:

- We already use pgvector with HNSW (ADR 0002); the dimensionality must be fixed at table-creation time. Migrating later costs a column type change + index rebuild + bulk re-embed.
- Production reality (per `MEMORY.md` "Biometric Pipeline State"): `opencv + Facenet + no liveness in enroll/verify + anti-spoof off` had been live for a while. Moving the authoritative encoder is a non-trivial deploy that re-embeds every existing enrollment.
- Anti-spoof was added separately (see ADR 0008); we did not want to also tweak the encoder at the same time.

## Decision

The server-authoritative face encoder is **DeepFace `Facenet512`**, producing 512-dim embeddings stored in `face_embeddings.embedding` as `vector(512)`. Verification computes cosine similarity between the probe and the enrolled embedding; the threshold is configurable per tenant (`auth_method_config`) with a platform default tuned against the project's evaluation set.

Specifically:

- Enrollment: client uploads a frame → biometric-processor runs face-detect → `Facenet512` → embedding written to `face_embeddings`.
- Verification: same pipeline → cosine similarity against stored enrollment → boolean verdict.
- All other DeepFace backends remain *available* (the library bundles them) but are not enabled in production.
- The client-side `geometry-512` pre-filter embedding (ADR 0003) is **a different shape and a different model**, used only for quality / liveness pre-filtering and for log-only divergence analysis in `client_embedding_observations`. It must never be compared against `face_embeddings`.

## Consequences

**Positive**
- 512-dim is a sweet spot: better discrimination than 128-dim Facenet, lower compute than ArcFace at our throughput, well-supported in DeepFace.
- pgvector HNSW on 512-dim is performant — sub-10ms p99 for 1:N search at current cohort sizes.
- DeepFace abstracts the model loading + face-detect pre-step (`opencv` detector by default), keeping our code path small.
- A single embedding shape across the whole platform.

**Negative**
- DeepFace pulls a chunky dependency tree (TensorFlow, ML weights). Container image size is non-trivial; we already accept this and ship the GPU variant where supported.
- Migrating away later (e.g., to ArcFace) costs a bulk re-embed across all tenants. We accept the lock-in.
- The Facenet512 weights are downloaded by DeepFace on first run; the production image pre-warms them at build time so cold start does not depend on network.

**Neutral**
- Future modality additions (voice — see V33 `voice_enrollments`) use their own encoders + columns + indexes. They do not inherit this choice.

## Alternatives considered

- **ArcFace.** Stronger recognition numbers in published benchmarks but a heavier model + slower inference; 512-dim too. Marginal benefit at our quality target; rejected for now.
- **OpenFace / VGG-Face.** Dimensionality and discrimination both worse for our use case.
- **Continue running plain `Facenet` (128-dim).** Rejected: dimensionality too low for the verification headroom we want; doubling the column width is a one-time cost we should pay now.
- **Host our own encoder.** Rejected for the same reasons as in ADR 0003: dataset and compute do not justify the win.

## References

- ADR 0002 — pgvector + HNSW.
- ADR 0003 — MobileFaceNet removal; explains the client-side delta.
- `biometric-processor/CLAUDE.md` — DeepFace backend pin, integration points.
- `MEMORY.md` "Biometric Pipeline State" — captures production reality at decision time.
