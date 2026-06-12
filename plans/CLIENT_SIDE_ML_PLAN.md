# Client-Side ML Strategy (Client-Authoritative Embedding + Puzzle-as-Layer)

**Version:** 3.0
**Last Updated:** 2026-06-12
**Status:** Active — landed dark, feature-flagged (default OFF). Supersedes v2.0 (pre-filter-only) and its D1/D2 locks.
**Project:** FIVUCSAS — Face and Identity Verification Using Cloud-Based SaaS
**Server:** Hetzner CX43 — 8 vCPU / 16 GB RAM — **NO GPU**

---

## 0. What changed since v2.0 (read this first)

v2.0 (2026-04-14) locked **pre-filter only**: the client detected/quality-gated/cropped a
face and uploaded a **JPEG**; the **server** ran MTCNN → quality → passive liveness →
Facenet512 → pgvector match. Any client embedding was **log-only** (D2).

v3.0 moves the **face embedding into the browser** and makes it **authoritative**, while
keeping the **server** the sole owner of liveness, the pgvector match, and the
accept/reject decision. It also promotes the **Biometric Puzzle to a first-class auth-flow
layer** backed by a server-issued, single-use, anti-replay session. Everything is
flag-gated and landed dark; the v2.0 legacy image path remains as the default and the
fallback.

| | v2.0 (pre-filter only) | v3.0 (this doc) |
|---|---|---|
| Face embedding | **server** (DeepFace Facenet512) | **browser** (Facenet512 via onnxruntime-web), authoritative; server path kept as fallback |
| What the client uploads for FACE | a JPEG image | only a 512-float vector (flag ON); JPEG (flag OFF / fallback) |
| Liveness | server passive (`/verify`) | server: passive **or** the active Puzzle layer; the vector path carries no liveness and MUST be paired |
| Client embedding role | log-only (D2) | authoritative (when the flag is ON); the old 128-dim landmark-geometry log-only field is retained, unchanged, for observability |
| Puzzle | a FACE liveness sub-component | a first-class auth-flow **layer** an admin composes, server-authoritative session, optional identity-binding |

**The reason** is that this is exactly the **client-loaded, GPU-less** design already shown
in the system-context / container diagrams and the poster: privacy-preserving (the raw
image stays on the device), bandwidth-light (~2 KB vector vs a JPEG), and it offloads the
server's heaviest CPU step.

---

## 1. Strategic Position

The server has no GPU. Under v3.0 the **client computes the face embedding** (the heavy
CPU step), and the **server keeps the security-critical, untrusted-client-resistant work**:
liveness, the 1:1 / 1:N pgvector match, the threshold/decision, lockout and rate-limit. The
client is untrusted, so it is never allowed to assert "liveness passed" or "match = true" —
it can only produce a vector, which the server matches against the enrolled template and
decides on.

This keeps the v2.0 win (latency/bandwidth) and adds a genuine **data-minimization**
privacy win, without moving any verdict to the client.

---

## 2. Locked Decisions (2026-06-12, v3.0)

| ID | Decision | Rationale |
|---|---|---|
| **D1′** | **Client computes the authoritative face embedding** (Facenet512, onnxruntime-web). Flag-gated `app.auth.client-side-embedding` (default OFF). | Matches the presented GPU-less design; offloads the server's heaviest step; raw image never leaves the device. **Supersedes v2.0 D1 (pre-filter only).** |
| **D2′** | **Only the 512-d vector leaves the device for FACE** (flag ON). The legacy 128-dim landmark-geometry `client_embedding` field stays log-only for observability. | The transmitted biometric is a derived, non-invertible template, not the image. **Supersedes v2.0 D2 (client embedding log-only as the only client embedding).** |
| **D3** | **Download-once, SHA256-verified model delivery.** FP16 Facenet512 ONNX (~47 MB) served from `app.fivucsas.com/models/`, content-hashed filename, cached Service-Worker (CacheFirst) + IndexedDB, integrity-checked, re-verify-on-read. INT8 **rejected** (onnxruntime-web WASM lacks `ConvInteger`/`MatMulInteger`/`DynamicQuantizeLinear`). | Deterministic, no git-lfs, honors no-dockerize-static; extends the YOLO-card `fetch-models` pattern. |
| **D4** | **Server owns liveness + match + decision.** The vector path has no liveness; it MUST be paired with a liveness factor (passive or the Puzzle layer) before it is a trusted login factor. | The client is untrusted; a stolen/forged vector replayed without a fresh server session must not pass. |
| **D5** | **Puzzle is a first-class auth-flow layer**, backed by a server-issued, single-use, randomized, owner-bound, short-TTL session (anti-replay). Optional **identity-binding** extracts the embedding from the same live puzzle frames. Flag-gated `app.auth.puzzle-layer` (default OFF). | Closes split-capture; makes the active puzzle composable like any other factor; the server is the sole authority. |
| **D6** | **Re-enroll developers** with the client pipeline so probe and template share the client preprocessing (self-consistency, no MTCNN-parity gymnastics). No real users exist, so this is acceptable. | Avoids mixed old/new templates and parity risk. |

The voice strategy (Silero VAD client-side, server Resemblyzer embedding) is unchanged from
v2.0 D4 (see §8 legacy appendix). Card detection (client-side YOLO) is unchanged.

---

## 3. Trust model (the crux)

Browser computes; the **server verifies only what it can re-check without trusting the
client's word.**

- **Identity:** the client uploads the 512-d embedding; the **server** runs the pgvector
  cosine match against enrolled templates and decides. A forged vector cannot match a real
  template; the server owns the threshold + verdict.
- **Liveness:** proven by the **active Biometric Puzzle** — the server issues a *randomized*
  challenge, the client performs it and uploads landmark/gesture **traces** (not an image),
  and the **server re-scores** the traces against the challenge it issued. Random challenge
  + server re-score + single-use session defeats replay; no image needed.
- **Binding (anti split-capture):** when identity-binding is on, the embedding is extracted
  from the **same live puzzle frames** as the liveness challenge, so identity and liveness
  come from one capture.

**Platform offers methods; tenant configures policy.** The *assurance level* is a tenant
config, not a hard mandate, with two tiers:

- **Baseline correctness (always on):** the embedding is accepted ONLY inside a
  server-issued, single-use, short-TTL session, with anti-replay. Without this floor the
  upload-the-vector method is simply broken, so it is table stakes — not a security policy.
- **Assurance level (tenant config + warning):** above the floor, the admin chooses how
  strong the liveness binding is (passive only / passive + active-puzzle-bound-to-the-same-
  capture). The bound option is the recommended default and closes split-capture; weaker
  options are offered with a clear "lower assurance" warning.

### 3a. Privacy statement (honest framing)

The correct claim is precise: **the raw face image never leaves the device; the only
biometric data transmitted is a derived, non-invertible 512-d embedding, sent over TLS and
stored encrypted at rest (Fernet).** We do **not** claim "biometric data never leaves the
device" — the embedding is personal biometric data under KVKK/GDPR. The genuine win is
**data minimization**: the image is not transmitted, only a template-grade vector.

---

## 4. Components (landed dark)

1. **Client embedding module** — Facenet512 ONNX via onnxruntime-web; one module used by
   BOTH the FACE (passive) path and the PUZZLE (active) path. Replicates DeepFace's exact
   preprocessing: aligned face crop → aspect-preserving resize + centre black-pad →
   `(1,160,160,3)` float32, **BGR**, **[0,1]** (`normalization="base"`, NOT prewhiten) →
   L2-normalize. In-browser **eye aligner** (similarity transform to canonical eye coords)
   addresses the alignment risk. (`web-app` `embedCapturedFace.ts`.)
2. **Model cache** — FP16 `facenet512-<sha256>.onnx`, downloaded once, SW CacheFirst +
   IndexedDB, SHA256-manifest integrity-checked, re-verify-on-read. (D3.)
3. **Upload contract (FACE)** — browser → Identity Core → bio:
   - verify: `POST /api/v1/verify-embedding {tenant_id, user_id, embedding[512]}`
   - enroll: `POST /api/v1/enroll-embedding {…, embedding[512]}`
   - bio runs ONLY the pgvector match (verify) / encrypt+persist (enroll); no image, no
     server-side detect/quality/Facenet512.
4. **Identity Core routing** — `ClientSideEmbeddingPolicy` (`app.auth.client-side-embedding`,
   global or per-canary-tenant, default OFF, fail-closed). `FaceVerifyMfaStepHandler` and
   `EnrollBiometricService` route to the embedding path when enabled.
5. **Puzzle layer (D5)** — `AuthMethodType.PUZZLE` + `PuzzleLayerPolicy`
   (`app.auth.puzzle-layer`). bio `PuzzleSessionManager` + `/api/v1/liveness/puzzle-session*`
   (create / submit / verdict; single-use, TTL 300s, owner-bound, server-randomized).
   Identity Core MFA-flow proxy (`/auth/mfa/puzzle/session*`) + server-authoritative
   `PuzzleVerifyMfaStepHandler` (`{puzzle_session_id[, embedding]}` → bio verdict,
   HARD-FAIL, no client-trust). Optional identity-binding double-gated on
   `alsoMatchFaceIdentity` AND `app.auth.client-side-embedding`.
6. **Server fallback (kept)** — the v2.0 image → server-Facenet512 path stays in code as
   the default and the fallback; it runs when the flags are OFF.

The canonical puzzle-session contract is
`docs/superpowers/plans/2026-06-12-puzzle-session-convergence.md`.

---

## 5. Inference Distribution — v3.0 state

| Task | Client | Server | Status |
|---|---|---|---|
| Face detection | **Primary** (MediaPipe FaceLandmarker / BlazeFace) | — | Live |
| Face quality gate | **Primary** | — | Live |
| Face align (eye-aligner) | **Primary** (client-side embedding path) | — (server aligns on the legacy path) | Live (flag) |
| **Face embedding** | **Authoritative** (Facenet512, onnxruntime-web) when flag ON | Fallback (DeepFace Facenet512) when flag OFF | Landed dark (flag) |
| Face 1:1 verify (match + decision) | — | **Only** (pgvector cosine + threshold) | Server only |
| Face 1:N search | — | **Only** | Server only |
| Passive liveness pre-screen | **Primary** (advisory) | Authoritative (legacy path) | Live |
| Active liveness puzzle (detection) | **Primary** (MediaPipe in-browser) | — | Live |
| Active liveness puzzle (scoring + verdict) | — | **Authoritative** (server-issued session, re-score) | Landed dark (flag) |
| Voice VAD | **Primary** (Silero) | — | Live |
| Voice embedding / verify / search | — | **Only** (Resemblyzer 256-dim) | Server only |
| Card detection | **Only** (YOLO ONNX, in-browser) | — | Live |
| Card OCR + MRZ | — | **Only** | Server only |

**No client-side verdict path exists.** The client never compares embeddings, never applies
thresholds, never decides accept/reject; it produces a vector and traces, the server
decides. UI state reflects server responses.

---

## 6. Reversibility / rollout (flag-gated, landed dark)

`app.auth.client-side-embedding` (FACE) and `app.auth.puzzle-layer` (PUZZLE) both default
OFF. Sequence: **land dark** (flags OFF, prod unchanged) → host the FP16 model + re-add the
manifest entry + build a JSON enroll endpoint → **canary** (one tenant) → re-enroll devs →
real-device same-person cosine validation across two devices → broad flip. Kill-switch =
flag OFF (no redeploy). Server image path is the fallback.

**Ordering caveat:** flip the Identity Core flag **before** the web `VITE_CLIENT_SIDE_EMBEDDING`
flag — web-ON + identity-OFF breaks FACE login (no image sent → legacy path fails). Best
fix = drive the web flag from login-config. (Phase-6 runbook:
`docs/superpowers/2026-06-12-client-side-embedding-PHASE6-runbook.md`.)

---

## 7. Model Delivery (D3)

FP16 Facenet512 ONNX (~47 MB) exported from our own SHA-pinned `facenet512_weights.h5`
(`tf2onnx`, opset 17 — do NOT ship unlicensed public ONNX). Served from
`app.fivucsas.com/models/` with a content-hashed filename and a `manifest.json` SHA256;
downloaded once, cached (SW CacheFirst + IndexedDB), integrity-checked on read. INT8 is
rejected for onnxruntime-web WASM (missing quant ops). The voice (Silero) + card (YOLO)
models continue to ship via the same manifest pattern.

---

## 8. Legacy appendix — v2.0 (pre-filter only), retained for history

v2.0 (2026-04-14) was the **pre-filter-only** strategy: the client detected / quality-gated
/ cropped and uploaded a JPEG; the server owned embeddings and verdicts; any client
embedding (D2) was log-only. The v2.0 image path is still in the codebase as the default and
the fallback when the v3.0 flags are OFF, so its behavior is preserved verbatim — v3.0 does
not remove it, it adds the client-authoritative path on top behind a flag.

Earlier v1.0 (2026-04-05) promised client-primary verdicts, a 128↔512 projection matrix,
CDN delivery and a 10-week KMP rollout; that design was retired in v2.0. v3.0 does **not**
resurrect client-side verdicts or the projection matrix — the server still owns every
decision; what v3.0 adds is a client-computed *authoritative embedding* that the server
matches.

The v2.0 voice plan (D4: Silero VAD client-side now; ECAPA-TDNN client embedding deferred)
and the card-detection-on-client decision carry forward unchanged.
