# ADR 0003: Remove client-side MobileFaceNet

**Status**: Accepted
**Date**: 2026-04-18
**Deciders**: Web platform, biometric, security

## Context

The web-app face-enrollment / face-verification flow originally shipped a client-side `MobileFaceNet` ONNX model that ran in the browser. The plan was:

1. Capture frames in the browser.
2. Detect the face with BlazeFace.
3. Compute a 128-dim MobileFaceNet embedding **in the browser**.
4. Send the embedding to the server for storage / comparison.

This was attractive for two reasons: server load (no full-frame upload to biometric-processor for every enrollment), and a perceived privacy win (pixel data never leaves the device).

In practice, this plan ran into three structural problems by 2026-04-18:

1. **Authoritative model download was blocked.** Every public mirror of the canonical MobileFaceNet ONNX file we wanted to use returned 401 or 404. Sourcing it required an authenticated InsightFace or HuggingFace download — not redistributable as part of our build pipeline. A graceful fallback was added so auth would continue to work without the model, but the fallback became the only live path.
2. **Two embedding spaces.** MobileFaceNet produces a 128-dim embedding; the server-side path (Facenet512) produces 512-dim. Storing both and choosing one at compare time invited divergence — and the divergence analysis itself motivated `client_embedding_observations` (Alembic 0004), which is log-only by design (D2). Production auth must never depend on the client-side number.
3. **Server is authoritative anyway.** Per D2 (locked 2026-04-14 in `CLIENT_SIDE_ML_PLAN.md` v2.0), the client-side embedding was log-only — never used for auth decisions, only fed into the observation table for offline analysis. If the client number cannot make a decision, computing it on every enrollment is just operational overhead.

## Decision

Strip MobileFaceNet entirely from `web-app`. The web face pipeline is now **landmark-geometry only** (`geometry-512`, 512-D derived from MediaPipe FaceLandmarker), used as a pre-filter (quality, single-face-present, liveness gate). The 512-dim *authoritative* face embedding is computed server-side from the uploaded frame by biometric-processor (Facenet512 backend), and that is the only embedding that touches `face_embeddings`.

Alembic 0004 `client_embedding_observations` (vector(128), no HNSW) is **retained** as a log-only divergence analysis surface — but it is populated by the geometry-512 pipeline when present, never by MobileFaceNet.

## Consequences

**Positive**
- One source of truth for the auth-decision embedding (Facenet512 on the server).
- No more graceful-fallback complexity in the web bundle.
- Removed an authentication-gating asset we could not redistribute legally.
- Smaller web-app bundle.

**Negative**
- Full frame is uploaded to biometric-processor on every enrollment / verification. Bandwidth cost; we accept it for the integrity win.
- "Privacy: pixels never leave the device" is no longer literally true — although in practice it never was, because liveness verdict and quality always required server-side compute.

**Neutral**
- BlazeFace stays in the browser as a face-presence detector. MediaPipe FaceLandmarker stays for the pre-filter geometry-512 path.

## Alternatives considered

- **Procure MobileFaceNet under license + bundle it.** Rejected: re-distribution license unclear; adds a third-party dependency we cannot rotate easily.
- **Train and host our own MobileFaceNet equivalent.** Rejected: the labelled dataset and compute were both prohibitive for a CSE4297-scope project, and the win — log-only telemetry — does not justify the effort.
- **Move to a different on-device model (e.g., FaceNet-Lite).** Rejected: same authoritative-model-availability problem; same divergence risk vs server.
- **Keep MobileFaceNet but gate it behind a feature flag.** Rejected: feature flags that default to off and stay off forever are just dead code with extra steps.

## References

- Parent `CHANGELOG.md` `[2026-04-18]` "Face embedding pipeline (web-app)" — MobileFaceNet stripped entirely.
- `docs/plans/CLIENT_SIDE_ML_PLAN.md` v2.0 — D1-D4 decisions (pre-filter client, log-only server, SHA256 model delivery, Silero V1).
- Alembic 0004 (`biometric-processor/alembic/versions/0004_*.py`) — `client_embedding_observations` table.
- ADR 0004 (server-authoritative Facenet512).
