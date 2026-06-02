# FIVUCSAS Biometric Pipelines

Accurate, code-grounded Mermaid diagrams of the FIVUCSAS biometric stack.
All facts below were read directly from `biometric-processor`, `spoof-detector`,
and `identity-core-api` source on 2026-06-02 — not invented.

**Honesty notes (read these before trusting any marketing slide):**

- **Auth decision is server-side.** The browser pre-filters with MediaPipe and
  may send a 128-dim client embedding, but that is **log-only** (D2). The
  authoritative 1:1 cosine match runs in `VerifyFaceUseCase` on the server.
- **Server-side fingerprint was REMOVED** (it was a SHA-256 placeholder, never a
  real biometric). `FINGERPRINT` is delivered *only* via WebAuthn / FIDO2
  platform authenticators in `identity-core-api` (`FingerprintAuthHandler`).
- **NFC passive authentication is fail-closed and needs CSCA roots loaded.** With
  an empty trust store the verdict is always `is_authentic=false`
  (`reason_code=NO_TRUST_STORE`). **Serial-only enrollment/verify works without
  CSCA** (campus MIFARE UID cards have no ICAO chip).
- **Anti-spoof / EAR veto on `/verify` is flag-gated** (`ANTISPOOF_*`,
  `spoof_detector` is an optional dep). When the package is absent or all flags
  are off, those response fields are `None` and nothing is vetoed.
- Config defaults verified: cosine distance threshold `0.45`
  (`VERIFICATION_THRESHOLD`, aged > 2 yr ⇒ more-permissive `_AGED`, must be ≥
  base or boot fails), `EMBEDDING_DIMENSION=512`, `LIVENESS_MODE=passive` →
  `uniface`, voice verify cosine `≥ 0.65` / search distance `< 0.6`, HNSW
  `m=16, ef_construction=64`, Fernet = AES-128-CBC + HMAC-SHA256.

---

## 1a. Face ENROLLMENT pipeline (8 stages in 4 cards)

`POST /enroll` and `/enroll/multi`. Server-authoritative passive liveness +
anti-spoof now run **before** the embedding is persisted
(`ENROLL_LIVENESS_ENABLED=true`, default; multi-image is **fail-CLOSED** per
frame). Embedding is written twice: encrypted ciphertext (store-of-record) +
plaintext pgvector column (search index).

```mermaid
flowchart TB
    IN[/"Image(s) upload<br/>multipart/form-data"/]

    subgraph C1["Card 1 — Detect + Quality"]
        S1["Stage 1 · Detect face<br/>DeepFace + OpenCV (default backend)<br/>AsyncFaceDetector → thread pool<br/>+ circuit breaker, 30s timeout"]
        S2["Stage 2 · Quality gate<br/>blur + lighting + face-size<br/>enroll threshold = 70/100"]
        S1 --> S2
    end

    subgraph LIVE["Liveness + anti-spoof gate (pre-persist)"]
        L1["CheckLivenessUseCase<br/>UniFace MiniFASNet (passive)"]
        L2["spoof-detector assembler + EAR veto<br/>(ANTISPOOF_* flags, optional dep)"]
        L1 --> L2
    end

    subgraph C2["Card 2 — Landmark + Align"]
        S3["Stage 3 · Landmarks / face region<br/>detection.get_face_region(image)"]
        S4["Stage 4 · Align + crop<br/>(client pre-crops ~224x224)"]
        S3 --> S4
    end

    subgraph C3["Card 3 — Embed + Encrypt"]
        S5["Stage 5 · Extract embedding<br/>Facenet-512 (512-dim, L2-normalized)<br/>AsyncEmbeddingExtractor → thread pool"]
        S6["Stage 6 · Multi-image fusion (optional)<br/>EmbeddingFusionService<br/>quality-weighted centroid + L2"]
        S7["Stage 7 · Encrypt at rest<br/>EmbeddingCipher (Fernet / AES-128-CBC<br/>+ HMAC-SHA256), u32-len header"]
        S5 --> S6 --> S7
    end

    subgraph C4["Card 4 — Index"]
        S8["Stage 8 · Persist (dual-column)<br/>embedding_ciphertext = store-of-record<br/>embedding (pgvector) = ANN search copy<br/>HNSW m=16, ef_construction=64,<br/>vector_cosine_ops · key_version smallint"]
    end

    IN --> C1
    C1 --> LIVE
    LIVE -->|"live + not spoof"| C2
    LIVE -.->|"non-live / spoof<br/>fail-CLOSED → HTTP 400"| REJ[["Reject enrollment"]]
    C2 --> C3 --> C4
    C4 --> OUT[/"BiometricResponse<br/>quality_score, dimension"/]
```

---

## 1b. Face VERIFICATION (1:1) — sequence

Client MediaPipe pre-filter (log-only) → server detect → embed → cosine match
with aged-threshold adaptation → flag-gated anti-spoof veto. The `/verify` route
runs a passive-liveness **floor** (score ≥ 0.4) before the match.

```mermaid
sequenceDiagram
    autonumber
    participant B as Browser (MediaPipe FaceLandmarker)
    participant API as identity-core-api (FaceVerifyMfaStepHandler)
    participant V as bio /verify (verification.py)
    participant LU as CheckLivenessUseCase (UniFace)
    participant UC as VerifyFaceUseCase
    participant DB as PostgreSQL + pgvector

    B->>B: detect face, quality pre-filter,<br/>passive-liveness gate (0.45)
    B->>API: face image (+ optional 128-dim<br/>client_embedding = LOG-ONLY)
    API->>V: POST /verify (X-API-Key, user_id, file)
    V->>V: validate magic bytes + format
    V->>LU: passive liveness (UniFace MiniFASNet)
    LU-->>V: is_live, score
    alt not is_live OR score < 0.4
        V-->>API: 400 LIVENESS_FAILED
    end
    V->>UC: execute(user_id, image_path, tenant_id)
    UC->>UC: detect → face region → quality (≥50)
    UC->>UC: extract Facenet-512 embedding
    UC->>DB: find_by_user_id (tenant-scoped)
    DB-->>UC: stored embedding (decrypted from ciphertext)
    UC->>UC: cosine distance vs threshold 0.45
    UC->>DB: find_created_at
    DB-->>UC: enrollment age
    UC->>UC: if age > 2 yr → use _AGED (more permissive)
    UC-->>V: verified, distance, confidence, threshold
    V->>V: anti-spoof helpers (flag-gated):<br/>device-risk, assembler, EAR (single frame)
    alt block_reason AND ANTISPOOF_BLOCK_ENFORCE
        V-->>API: 403 ANTISPOOF_BLOCKED {reason}
    else allowed
        V->>DB: BackgroundTask: log client-embedding<br/>observation (offline divergence, no auth use)
        V-->>API: 200 VerificationResponse
    end
    API-->>B: MFA step result (server decides)
```

---

## 2a. Voice ENROLLMENT — flowchart

Resemblyzer 256-dim speaker embedding, centroid storage. The `optimize=true`
("İyileştir" / re-enroll & optimize) path folds the new sample into the existing
centroid via a quality-weighted running mean instead of replacing it.

```mermaid
flowchart TB
    IN[/"POST /voice/enroll<br/>base64 WebM/Opus + optimize?"/]
    DEC["Decode → 16 kHz mono WAV<br/>(thread pool, off event loop)"]
    EMB["Resemblyzer → 256-dim speaker embedding<br/>(L2-normalized)"]
    Q["Voice quality score 0..100<br/>(duration + loudness + SNR)<br/>fail-soft → 50.0"]
    DEC --> EMB
    DEC --> Q

    EMB --> OPT{optimize == true<br/>AND user has voiceprint?}
    OPT -->|"no"| SAVE["Save NEW individual row<br/>+ recompute centroid<br/>(idempotent accumulation)"]
    OPT -->|"yes — İyileştir"| FUSE["fuse_incremental():<br/>quality-weighted running mean<br/>w_existing = q*sample_count, w_new = q_new<br/>→ L2-normalize · never regresses"]
    SAVE --> STORE[("voice_enrollments<br/>pgvector + HNSW m=16/ef=64")]
    FUSE --> STORE
    Q --> STORE
    STORE --> OUT[/"BiometricResponse<br/>dim=256, quality_score"/]
```

## 2b. Voice VERIFICATION / SEARCH — sequence

Note the **two different thresholds**: 1:1 verify uses cosine **similarity ≥
0.65**; 1:N search uses pgvector cosine **distance < 0.6**. The replay-attack
detector is advisory + log-only (gated `VOICE_REPLAY_DETECTION_ENABLED`,
default off) — it never blocks today.

```mermaid
sequenceDiagram
    autonumber
    participant API as identity-core-api (VoiceVerifyMfaStepHandler)
    participant V as bio voice.py
    participant E as Resemblyzer (thread pool)
    participant D as VoiceReplayDetector
    participant DB as pgvector_voice_repository

    API->>V: POST /voice/verify {user_id, voice_data}
    V->>D: replay check (advisory, log-only)
    D-->>V: suspected? (does NOT block)
    V->>E: decode → 256-dim probe embedding
    E-->>V: probe vector (L2)
    V->>DB: find_by_user_id → enrolled centroid
    DB-->>V: centroid (or none → verified=false)
    V->>V: cosine similarity = dot(probe, centroid),<br/>clamp [0,1]
    alt similarity ≥ 0.65
        V-->>API: verified=true, confidence
    else
        V-->>API: verified=false
    end

    Note over API,DB: 1:N — POST /voice/search (tenant-scoped)<br/>repo.find_similar(threshold=0.6 DISTANCE)<br/>matches reported as similarity = 1 - distance
```

---

## 3a. NFC two rails — sequence

Rail A = mobile native chip read (IsoDep + BouncyCastle, BAC session from MRZ,
DG2 face → Facenet match). Rail B = browser Web NFC. Both rails converge on the
same server endpoints: `/nfc/mrz` (parse) and `/nfc/verify-authenticity`
(passive auth). API side is `NfcController` + `NfcDocumentVerifyMfaStepHandler`.

```mermaid
sequenceDiagram
    autonumber
    participant M as Rail A · Mobile (KMP)<br/>IsoDep + BouncyCastle
    participant W as Rail B · Web NFC (browser)
    participant API as identity-core-api · NfcController
    participant BIO as bio nfc.py
    participant PA as EmrtdPassiveAuthService

    rect rgb(235,245,255)
    Note over M: Rail A — full ICAO chip read
    M->>M: read MRZ (OCR/manual) → derive BAC keys
    M->>M: BAC secure channel over IsoDep
    M->>M: read DG1 (MRZ), DG2 (JPEG2000 face), EF.SOD
    M->>API: POST /nfc/verify-mrz {dg1BytesB64 | mrzText}
    API->>BIO: /nfc/mrz (X-API-Key)
    BIO-->>API: parsed fields + ICAO check-digit result
    M->>API: POST /nfc/verify-authenticity {sod, dg1..dgN}
    end

    rect rgb(245,235,255)
    Note over W: Rail B — Web NFC (serial / limited DG)
    W->>API: serial-only /nfc/verify  (campus MIFARE UID)
    W->>API: or /nfc/verify-authenticity {sod_b64, dg keys}<br/>when a Web-NFC reader yields SOD + DGs
    end

    API->>BIO: POST /nfc/verify-authenticity {sod_b64, data_groups}
    BIO->>PA: verify(sod_der, data_groups)
    PA-->>BIO: {is_authentic, reason_code, ds_subject,<br/>ds_serial, csca_matched, dg_hash_results}
    BIO-->>API: passive-auth verdict
    Note over API: FAIL-CLOSED — NfcChipAuthenticityVerdict<br/>not authentic / error / NO_TRUST_STORE ⇒ 422 reject
    API-->>M: 200 authentic / 422 NFC_PA_NOT_AUTHENTIC
    Note over M,API: Rail A also: DG2 face ↔ live selfie<br/>Facenet cosine match (face-to-document)
```

## 3b. NFC passive authentication — flowchart (fail-closed)

ICAO 9303 Part 11. Three checks must ALL pass: DG hashes match the signed values
in EF.SOD, the SOD CMS signature verifies under the embedded Document Signer
cert, and that DS chains to a trusted CSCA root. Serial-only is the fallback when
no SOD is supplied.

```mermaid
flowchart TB
    IN[/"POST /nfc/verify-authenticity<br/>{sod_b64, data_groups: 1..16}"/]
    TS{CSCA trust store<br/>loaded?<br/>NFC_CSCA_TRUST_DIR}
    IN --> TS
    TS -->|"empty"| NTS["is_authentic = false<br/>reason_code = NO_TRUST_STORE"]

    TS -->|"≥1 root cert<br/>(mtime-cached)"| H["Check A · DG hashes<br/>each provided DG hash ==<br/>signed value in LDSSecurityObject"]
    H -->|"mismatch"| FC1["FAIL-CLOSED reject"]
    H -->|"match"| SIG["Check B · SOD CMS signature<br/>verifies under embedded<br/>Document Signer (DS) cert"]
    SIG -->|"invalid"| FC2["FAIL-CLOSED reject"]
    SIG -->|"valid"| CHAIN["Check C · DS chains to a<br/>trusted CSCA root"]
    CHAIN -->|"no chain"| FC3["FAIL-CLOSED reject"]
    CHAIN -->|"chains"| OK["is_authentic = true<br/>ds_subject, ds_serial, csca_matched=true"]

    SO{SOD supplied at all?}
    SOIN[/"/nfc/enroll or MFA step<br/>without SOD"/] --> SO
    SO -->|"no SOD"| SERIAL["SERIAL-ONLY fallback<br/>MIFARE UID lookup only<br/>(works without CSCA;<br/>proves 'serial enrolled', NOT chip genuine)"]
    SO -->|"SOD present"| IN

    NTS --> REJ[["api FAIL-CLOSED → 422"]]
    FC1 --> REJ
    FC2 --> REJ
    FC3 --> REJ
```

---

## 4. Liveness decision — passive + active

Two distinct mechanisms. **Passive** = single-frame UniFace MiniFASNet on
`/verify` and `/liveness` (default `LIVENESS_MODE=passive`). **Active** =
challenge/response: the server generates a sequence (face challenges scored by
EAR/MAR/yaw, hand-gesture challenges scored from landmarks), tracks the session,
and on success issues a short-lived **HS256 JWT verification token** (TTL 300s,
UUID `jti`). 23 micro-challenges exist in the web registry: **14 face + 9 hand**.

```mermaid
flowchart TB
    subgraph PASSIVE["PASSIVE — single frame"]
        P1[/"POST /liveness or /verify<br/>one still frame"/]
        P2["UniFace MiniFASNet (passive)<br/>texture / depth cue → score"]
        P3{"is_live AND<br/>score ≥ floor?<br/>(verify floor 0.4)"}
        P1 --> P2 --> P3
        P3 -->|"no"| PR[["reject"]]
        P3 -->|"yes"| PG[["pass to match"]]
    end

    subgraph ACTIVE["ACTIVE — challenge / response"]
        A1[/"POST /liveness/active/start<br/>(or /active/gesture/start)"/]
        A2["StartActiveLiveness:<br/>session_id = uuid4()<br/>pick num_challenges (cfg 1–5, def 3)<br/>session TTL = 120s · per-challenge 5s"]
        A3["Client performs each action,<br/>POSTs frames to /active/frame"]
        A4["FACE: MediaPipe FaceLandmarker (server)<br/>EAR (blink), MAR (mouth), yaw (head turn),<br/>eyebrow-raise vs per-session baseline"]
        A5["HAND/gesture: client sends 21-pt hand<br/>landmarks + anti-spoof scores (landmarks-only,<br/>no server MediaPipe)"]
        A6{"all challenges<br/>completed in order,<br/>within TTL?"}
        A7["ActiveLivenessTokenService:<br/>HS256 JWT, scope=active_liveness_verification,<br/>jti=uuid4(), exp = now + 300s"]
        A1 --> A2 --> A3
        A3 --> A4
        A3 --> A5
        A4 --> A6
        A5 --> A6
        A6 -->|"expired → 410"| AEXP[["session expired"]]
        A6 -->|"not found → 404"| ANF[["unknown session"]]
        A6 -->|"yes"| A7 --> ATOK[["signed liveness token"]]
    end

    subgraph PUZZLE["ACTIVE (puzzle variant) — GeneratePuzzle / VerifyPuzzle"]
        Z1["GeneratePuzzleUseCase: random steps<br/>(easy 2-3 / standard 3-4 / hard 4-5),<br/>incompatible pairs (turn_left↔turn_right) filtered,<br/>thresholds sent to client (ear 0.21, mar 0.4, yaw 0.15)"]
        Z2["persist puzzle, expires = timeout + 60s"]
        Z3["VerifyPuzzleUseCase: anti-replay (P0-#9) —<br/>corrupt/garbage frames counted as FAILURE;<br/>timestamp-before-puzzle rejected"]
        Z1 --> Z2 --> Z3
    end
```

---

## 5. spoof-detector — session verdict (peak-sensitive)

Standalone `spoof-detector` repo (algorithms live here; `biometric-processor`
only wires them). Per frame: MiniFASNet ONNX classifier + a bank of analyzers
(`src/infrastructure/analyzers/` ships **14**: MiniFASNet, texture, moiré,
screen-replay, screen-flicker, micro-tremor, rPPG, temporal, landmark-variance,
device-boundary, background-grid, AR-filter, blink, + flash). Frames fuse into a
**session** verdict that is intentionally NOT a plain average — it is
peak-sensitive (blends mean P(real) with the **worst sliding window**) so a brief
spoof flash can't be averaged away.

```mermaid
flowchart TB
    F[/"Webcam frame stream<br/>(amispoof / proctoring)"/]

    subgraph FRAME["Per-frame analysis"]
        MFN["MiniFASNet ONNX<br/>P(real) classifier"]
        ANA["12+ analyzers:<br/>texture · moiré · screen-replay ·<br/>screen-flicker · micro-tremor · rPPG ·<br/>temporal · landmark-variance ·<br/>device-boundary · background-grid ·<br/>AR-filter · blink"]
        GATE["FaceUsabilityGate<br/>(usable face present?)"]
        FUSE["HybridFusionEvaluator<br/>calibrated multi-class fusion<br/>→ SpoofClassification"]
        MFN --> FUSE
        ANA --> FUSE
        GATE --> FUSE
    end

    F --> FRAME

    subgraph SESSION["SessionEngine — accumulate over time"]
        ING["ingest(): append category evidence<br/>+ LivenessProver ('guilty until proven',<br/>must reach 60/100) + incident detection"]
        AVG["avg_real = mean P(real)"]
        WORST["worst_window_real = min over<br/>sliding 3–5 frame windows (PEAK)"]
        BLEND["blended_real = 0.50*avg + 0.50*worst"]
        ADJ["adjusted_real ×= data_confidence (full@150f/5s)<br/>×= (1 - incident_penalty*0.4)<br/>+= temporal_boost*0.15"]
        INC{"incidents ≥ 3?"}
        PROV{"prover proven_live<br/>(≥ 60)?"}
        DEC{"adjusted_real > 0.45<br/>AND prover_live<br/>AND not incident_override"}
        ING --> AVG --> BLEND
        ING --> WORST --> BLEND
        BLEND --> ADJ --> DEC
        INC --> DEC
        PROV --> DEC
    end

    FRAME --> SESSION
    DEC -->|"all agree"| LIVE[["LIVE"]]
    DEC -->|"else"| SPOOF[["SPOOF — dominant_threat<br/>(replay / screen / deepfake)"]]

    subgraph WHY["Why attacks fail"]
        R1["Replay/screen: MiniFASNet oscillates<br/>(mean<80, std>25) + moiré/flicker/device-boundary<br/>→ incidents + worst-window drag → SPOOF"]
        R2["Deepfake/photo: no real blink (prover<60),<br/>flat rPPG, unnatural landmark variance,<br/>peak-sensitive verdict refuses to average it away"]
    end
    SPOOF -.-> WHY
```

---

## 6. Fingerprint → WebAuthn mapping (no server biometric)

There is **no server-side fingerprint matcher**. The `FINGERPRINT` auth method is
a WebAuthn/FIDO2 *platform* authenticator ceremony — the device's secure enclave
does the biometric match locally and returns a signed assertion; the server only
verifies the assertion + sign-counter against the stored public key. This is a
possession+inherence factor, not a template stored in pgvector.

```mermaid
flowchart LR
    subgraph CLIENT["Device (secure enclave)"]
        TOUCH["User touches sensor /<br/>Face ID — biometric match<br/>happens ON-DEVICE only"]
        ASSERT["WebAuthn assertion:<br/>credentialId, authenticatorData,<br/>clientDataJSON, signature"]
        TOUCH --> ASSERT
    end

    subgraph SERVER["identity-core-api · FingerprintAuthHandler"]
        CH["Phase 1: generateChallenge<br/>(authenticatorAttachment=platform,<br/>allowCredentials = user's credential IDs)"]
        LK["lookup WebAuthnCredential by credentialId<br/>+ assert it belongs to session user"]
        VER["WebAuthnService.verifyAssertion<br/>(public key)"]
        SC{"sign-counter<br/>> stored?<br/>(spec §6.1.17)"}
        OKR["StepResult.success(verified=true)"]
        CLONE["reject — counter regression<br/>(possible cloned credential)"]
        CH --> LK --> VER --> SC
        SC -->|"yes"| OKR
        SC -->|"no / regressed"| CLONE
    end

    ASSERT --> LK

    NOTE["NO embedding · NO pgvector · NO bio-processor call.<br/>Server-side SHA-256 'fingerprint' path was REMOVED (P1.4).<br/>AuthMethodType.FINGERPRINT is retained ONLY for WebAuthn."]
    SERVER -.-> NOTE
```
