# Client-Side ML Strategy (Pre-Filter Only)

**Version:** 2.0
**Last Updated:** 2026-04-14
**Status:** Active (rewritten from 1.0 aspirational design)
**Project:** FIVUCSAS — Face and Identity Verification Using Cloud-Based SaaS
**Server:** Hetzner CX43 — 8 vCPU / 16 GB RAM — **NO GPU**

---

## 1. Strategic Position

The server has no GPU. All heavy ML **inference for auth decisions** stays server-side (CPU-lean, pgvector-backed). The client role is **pre-filtering**: detection, quality, liveness pre-screen, crop, and voice activity detection. The goal is to reduce server load and upload bandwidth — not to move verdicts to the client.

**What changed vs v1.0:** the 2026-04-05 design document claimed client-primary face verification, a 128↔512 projection matrix, and CDN-hosted model delivery. Audit on 2026-04-14 confirmed none of that was built. This version retires those ambitions explicitly.

---

## 2. Locked Decisions (2026-04-14)

| ID | Decision | Rationale |
|---|---|---|
| D1 | **Pre-filter only** | Client pre-screens; server is sole source of truth for embeddings and verdicts. Delivers latency/bandwidth wins without rebuilding auth. |
| D2 | **`client_embedding` log-only** | Client embedding is now landmark-geometry (512-dim, MediaPipe-based). MobileFaceNet ONNX deprecated 2026-04-18 — server-side DeepFace Facenet512 remains the sole trusted embedding for auth. Server accepts and persists the field for offline divergence analysis only. Never trusted for auth decisions. |
| D3 | **Build-time model fetch (Hostinger static + SHA256 manifest)** | Deterministic deploys, no git-lfs, matches the no-dockerize-static rule. |
| D4 | **Voice V1 now, V2 later** | V1: Silero VAD client-side, skip upload on silence. V2 (ECAPA-TDNN client embedding, remove librosa pin): deferred until V33 stable. |

---

## 3. Inference Distribution — Actual State (2026-04-14)

| Task | Client | Server | Status |
|---|---|---|---|
| Face detection | **Primary** (MediaPipe FaceMesh / BlazeFace fallback) | — | Live |
| Face quality gate | **Primary** | — | Live (`QualityAssessor.ts`) |
| Face crop 224×224 before upload | **Primary** | — | Live (`faceCropper.ts`) |
| Face tracking (IoU) | **Primary** | — | Live (`FaceTracker.ts`) |
| Passive liveness pre-screen | **Primary** (advisory today, gating in Phase 5) | Authoritative | Live (`PassiveLivenessDetector.ts`) |
| Active liveness puzzle | **Primary** | **Authoritative** | Live (`BiometricPuzzle.ts`) |
| Face embedding | — | **Only** (ArcFace 512-dim, DeepFace) | Server only |
| Face 1:1 verify | — | **Only** (cosine in pgvector) | Server only |
| Face 1:N search | — | **Only** | Server only |
| Voice VAD | **Primary** (Phase 4, this plan) | — | In progress |
| Voice embedding | — | **Only** (Resemblyzer 256-dim) | Server only, V2 may revisit |
| Voice 1:1 verify | — | **Only** | Server only |
| Card detection | **Primary** (YOLOv8n ONNX / WASM) | Fallback | Wired, awaiting model file (Phase 3) |
| Card OCR + MRZ | — | **Only** | Server only |
| Proctoring gaze / deepfake / object | — | **Only** | Server only |

**No client-side verdict path exists.** The client never compares embeddings, never applies thresholds, never decides accept/reject. UI state reflects server responses.

---

## 4. Model Inventory

### 4.1 Face Detection — MediaPipe FaceMesh / BlazeFace
Live in browser. No action needed. Model bundled with MediaPipe runtime.

### 4.2 Face Embedding — MobileFaceNet (client pre-screen, **not** for verdicts)
| Property | Value |
|---|---|
| Format | ONNX (WASM) |
| Size | ~4.9 MB INT8 |
| Input | 112×112 aligned face |
| Output | 128-dim L2-normalized embedding |
| Role | **Sent to server as `client_embedding` for log-only observation (D2).** Never used for client-side verify. |

**Out of scope:** 128→512 projection matrix, client-side cosine verification, embedding cache on device.

### 4.3 Voice VAD — Silero
| Property | Value |
|---|---|
| Format | ONNX (WASM) |
| Size | ~1.8 MB |
| Input | 16 kHz mono PCM, 512-sample frames |
| Output | Per-frame speech probability |
| Role | Skip upload when `speechRatio < 0.2`. Graceful fallback when model missing. |

### 4.4 Card Detection — YOLOv8n
| Property | Value |
|---|---|
| Format | ONNX (WASM) |
| Size | ~6.2 MB |
| Input | 640×640 RGB (letterboxed) |
| Output | Bounding boxes + class |
| Role | Real-time client overlay; crop sent to server for OCR + MRZ. Server fallback on missing model. |

### 4.5 Passive Liveness — MobileNet-v3 Anti-Spoof
Currently heuristic (texture/moire/color) in `PassiveLivenessDetector.ts`. No neural model. Phase 5 will wire it into a gating threshold or demote it — no new model purchase required.

### 4.6 Explicitly Deferred
- ECAPA-TDNN voice embedding (D4 V2)
- Neural DNN liveness (no incident justifies XL effort)
- Iris / gaze tracking (no browser API)
- Demographics (server-only, DeepFace Python)

---

## 5. Model Delivery (Phase 3 of Rollout Plan)

**Hostinger static bucket** at `app.fivucsas.com/models/` serves the three `.onnx` files. Repo contains a committed `manifest.json` with SHA256 hashes; `scripts/fetch-models.mjs` runs as `prebuild` to download and verify. Fatal on hash mismatch.

```json
{
  "base_url": "https://app.fivucsas.com/models",
  "files": [
    {"name": "mobilefacenet.onnx", "sha256": "<hash>", "bytes": 4915200},
    {"name": "yolo-card-nano.onnx", "sha256": "<hash>", "bytes": 6500000},
    {"name": "silero-vad.onnx",    "sha256": "<hash>", "bytes": 1850000}
  ]
}
```

`.onnx` files are git-ignored. CI runs `npm run fetch-models` before `npm run build`.

---

## 6. Server Contract for Log-Only Embedding

Web-app already posts `client_embedding` (single JSON array) and `client_embeddings` (JSON array of arrays). Server persists them into `client_embedding_observations` via FastAPI `BackgroundTasks`:

```sql
client_embedding_observations (
  observation_id UUID PK, user_id, tenant_id, session_id,
  modality ('face'|'card'), flow ('enroll'|'verify'),
  client_embedding vector(128), client_model_version,
  server_embedding_ref UUID NULL, cosine_similarity FLOAT8 NULL,
  device_platform, user_agent, created_at
)
```

Failure to record must **not** break the primary flow. Cosine similarity is computed offline, not at request time.

---

## 7. Rollout Plan (Active)

Tracked in `/home/deploy/.claude/plans/resilient-finding-thunder.md`.

| Phase | Work | Status |
|---|---|---|
| 1 | Rewrite this doc + memory files | Done (this commit) |
| 2 | Alembic V4 `client_embedding_observations` + route wiring | In progress |
| 3 | Hostinger bucket + `fetch-models.mjs` + manifest + CI prebuild | Awaiting model hashes (user action) |
| 4 | Client-side Silero VAD (`VoiceVAD.ts`) + upload gate | In progress |
| 5 | Wire `PassiveLivenessDetector` into capture gate **or** demote | Pending |

---

## 8. Explicitly Out of Scope

- 128↔512 projection matrix (retired)
- Client-primary face verify (retired)
- Client-side 1:N search
- Encrypted on-device embedding cache
- ECAPA-TDNN client voice embedding (deferred per D4)
- Neural DNN liveness
- Voice STT challenge (separate `VOICE_STT_PLAN.md`)
- Server face-detection refactor to MediaPipe Tasks (reversed — strategy is client-first pre-filter, not server rewrite)
- KMP client-apps ML (this document now scopes to web-app only; mobile has its own track)

---

## 9. Risk & Mitigation

| Risk | Mitigation |
|---|---|
| Model file missing in production | Build-time fetch with SHA256; fatal on mismatch. Graceful client fallback (server handles) during transition. |
| Log-only insert fails and breaks enrollment | `try/except` with background task; never raise. Telemetry is best-effort. |
| Tampered `client_embedding` from malicious client | Field is never trusted. Offline analysis can flag divergence but cannot affect auth. |
| VAD false-negatives block legitimate users | Threshold conservative (0.2). VAD-unavailable path always allows upload. User error message is retry-friendly. |
| Doc drift recurs | Single source of truth: this file. Memory files reference it; no parallel "future design" doc. |

---

## 10. Verification

Each phase has an acceptance check in the rollout plan. Summary:

- Phase 1: `grep -n "Primary" docs/plans/CLIENT_SIDE_ML_PLAN.md` returns zero hits in the face-verify row.
- Phase 2: `alembic upgrade head` clean; round-trip POST with `client_embedding` lands a row; missing field still works.
- Phase 3: fresh clone → `npm install && npm run build` produces `dist/models/*.onnx` with correct hashes.
- Phase 4: silent recording blocked; speech recording passes; missing VAD model fails open.
- Phase 5: every client ML class has at least one real consumer.

---

*Previous v1.0 (2026-04-05) promised client-primary verdicts, projection matrix, CDN, 10-week KMP rollout. That design is retired in favor of the pre-filter-only strategy above. See `/home/deploy/.claude/plans/resilient-finding-thunder.md` for execution detail.*
