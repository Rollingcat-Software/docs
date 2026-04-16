# FIVUCSAS Biometric Flow Research Report

> Comprehensive end-to-end trace of Face, Voice, and Fingerprint (WebAuthn) enrollment and verification flows.
> Generated: 2026-04-11

---

## 1. Architecture Overview

```
                         Browser (React 18 / TypeScript)
                         ================================
                         MediaPipe BlazeFace (face detection)
                         Web Audio API + MediaRecorder (voice)
                         WebAuthn API (fingerprint/hardware key)
                                    |
                                    | HTTPS
                                    v
             +----------------------------------------------+
             |          Traefik v3.6.12 (SSL/routing)       |
             +----------------------------------------------+
                   |                              |
                   v                              v
    +--------------------------+     +---------------------------+
    | Identity Core API        |     | Biometric Processor       |
    | Spring Boot 3.2.0        |     | FastAPI / Python 3.12     |
    | Java 21 / Port 8080      |     | Port 8001 (internal only) |
    | Hexagonal Architecture   |     | DeepFace + Resemblyzer    |
    +--------------------------+     +---------------------------+
          |           |                    |
          v           v                    v
    +-----------+ +---------+     +------------------+
    | PostgreSQL| | Redis   |     | PostgreSQL 17    |
    | 17        | | 7.4     |     | + pgvector       |
    | identity_ | | (WebAuthn|    | biometric_db     |
    | core      | | challenges)   +------------------+
    +-----------+ +---------+

    Databases:
      identity_core: users, user_enrollments, webauthn_credentials, auth_sessions
      biometric_db:  face_embeddings (512-dim), voice_enrollments (256-dim)
```

**Two enrollment paths exist:**

1. **Direct path** (Face enrollment from dashboard): Browser -> BiometricService.ts -> biometric-processor directly (via VITE_BIOMETRIC_API_URL, X-API-Key auth)
2. **Proxy path** (Voice enrollment, MFA verification): Browser -> identity-core-api BiometricController/AuthHandlers -> BiometricServiceAdapter -> biometric-processor (Docker internal network)

---

## 2. Face -- Enrollment Flow

### 2.1 Browser: Capture, Processing, Encoding

**Key files:**
- `web-app/src/features/auth/components/FaceEnrollmentFlow.tsx`
- `web-app/src/features/auth/hooks/useFaceChallenge.ts` (lines 37-43)
- `web-app/src/features/auth/hooks/useFaceDetection.ts`

**Step-by-step:**

1. **Camera init**: `getUserMedia({ video: { facingMode: 'user', width: 640, height: 480 } })` (FaceEnrollmentFlow.tsx:52-53)

2. **Face detection**: MediaPipe BlazeFace runs on every animation frame via `useFaceDetection` hook. Returns `detected`, `centered`, `boundingBox`, `confidence`, `tooClose`, `tooFar`.

3. **5-stage liveness challenge** (useFaceChallenge.ts:37-43):
   | Stage | Instruction | Hold time |
   |-------|------------|-----------|
   | `position` | Position face in oval | 300ms |
   | `frontal` | Look straight at camera | 300ms |
   | `turn_left` | Turn head left | 300ms |
   | `turn_right` | Turn head right | 300ms |
   | `blink` | Blink naturally | 400ms |

4. **Stage detection logic** (useFaceChallenge.ts:84-125):
   - `position`: face detected AND centered AND not too close/far
   - `frontal`: face detected AND centered
   - `turn_left`: bounding box center X > 0.5 + 0.06 (HEAD_TURN_THRESHOLD)
   - `turn_right`: bounding box center X < 0.5 - 0.06
   - `blink`: confidence drops from >0.6 to <0.5 then recovers

5. **Timeouts** (useFaceChallenge.ts:46):
   - Soft timeout: 6s (STAGE_TIMEOUT_MS) with face detected -> auto-advance with 500ms hold
   - Hard timeout: 12s without any detection -> auto-advance

6. **Image capture** (useFaceChallenge.ts:157-182): At each stage completion:
   - Primary: `cropFace(canvas)` extracts face bounding box region
   - Fallback: center-crop ~60% of frame if no bounding box
   - Format: `canvas.toDataURL('image/jpeg', 0.85)` -> base64 data URL

7. **Result**: Array of 5 base64 JPEG images (one per stage) passed to `onComplete(captures)`

### 2.2 API Call (Enrollment)

**Key file:** `web-app/src/core/services/BiometricService.ts` (lines 72-98)

The `EnrollmentPage.tsx` (line 460) calls:
```typescript
await biometric.enrollFace(userId, images, tenantId)
```

**BiometricService.enrollFace()** routes based on image count:
- **1 image**: `POST /enroll` (multipart form-data: `file` + `user_id`)
- **2+ images** (typical, 5 from liveness): `POST /enroll/multi` (multipart form-data: `files[]` + `user_id`)

The call goes **directly to biometric-processor** (not through identity-core-api):
```
Browser -> https://bio.fivucsas.com/api/v1/enroll/multi
           (or VITE_BIOMETRIC_API_URL, X-API-Key header)
```

**Request shape (multi-image):**
```
POST /enroll/multi
Content-Type: multipart/form-data
X-API-Key: <key>

- user_id: "<uuid>"
- files: face_0.jpg (binary)
- files: face_1.jpg (binary)
- ... up to 5
```

**Response shape:**
```json
{
  "success": true,
  "user_id": "<uuid>",
  "images_processed": 5,
  "fused_quality_score": 78.5,
  "average_quality_score": 72.3,
  "individual_quality_scores": [68.1, 73.2, 75.0, 71.5, 73.8],
  "message": "Multi-image enrollment completed successfully",
  "embedding_dimension": 512,
  "fusion_strategy": "quality_weighted_average"
}
```

### 2.3 Biometric Processor: Embedding Extraction & Storage

**Key files:**
- `biometric-processor/app/api/routes/enrollment.py` (lines 147-305: `/enroll/multi`)
- `biometric-processor/app/application/use_cases/enroll_face.py` (lines 54-154)
- `biometric-processor/app/infrastructure/persistence/repositories/pgvector_embedding_repository.py`

**Processing pipeline per image** (EnrollFaceUseCase.execute):

1. **Load image**: `cv2.imread(image_path)` (line 85)
2. **Detect face**: `IFaceDetector.detect(image)` -- DeepFace detector (line 91)
3. **Extract face region**: `detection.get_face_region(image)` -- crop bounding box (line 96)
4. **Quality assessment**: `IQualityAssessor.assess(face_region)` -- blur, resolution, lighting checks (line 99)
   - Enrollment threshold: quality_score must be `is_acceptable` (configurable, ~70/100)
   - Raises `PoorImageQualityError` if below threshold
5. **Extract embedding**: `IEmbeddingExtractor.extract(face_region)` -- DeepFace FaceNet model -> 512-dim float32 vector (line 120)

**Multi-image fusion** (EnrollMultiImageUseCase):
- Processes each image independently (steps 1-5)
- Fuses embeddings using quality-weighted average (higher quality = higher weight)
- Stores the fused template

**Storage** (PgVectorEmbeddingRepository.save, lines 173-314):

1. Insert INDIVIDUAL enrollment row with 512-dim embedding
2. Cap at MAX_INDIVIDUAL_ENROLLMENTS = 5 per user (prune lowest quality)
3. Compute CENTROID as `AVG(embedding)::vector(512)` across all INDIVIDUAL rows
4. Upsert CENTROID row (create or update)

### 2.4 Database Storage (biometric_db)

**Table: `face_embeddings`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key (uuid_generate_v4) |
| `user_id` | VARCHAR(255) | User identifier |
| `tenant_id` | VARCHAR(255) | Optional multi-tenant |
| `embedding` | vector(512) | 512-dim FaceNet embedding |
| `quality_score` | FLOAT | 0.0-1.0 (normalized from 0-100) |
| `enrollment_type` | VARCHAR | 'INDIVIDUAL' or 'CENTROID' |
| `is_active` | BOOLEAN | Active flag (default true) |
| `deleted_at` | TIMESTAMP | Soft delete timestamp |
| `created_at` | TIMESTAMP | Creation time |
| `updated_at` | TIMESTAMP | Last update (auto-trigger) |
| `metadata` | JSONB | Additional metadata |

**Indexes:**
- `idx_face_embeddings_embedding_hnsw`: HNSW index on `embedding` column using `vector_cosine_ops` (m=16, ef_construction=64) -- replaces old IVFFlat
- `idx_embeddings_user_id`: B-tree on `user_id`
- `idx_embeddings_tenant_id`: B-tree on `tenant_id`

### 2.5 Enrollment Status Lifecycle

After biometric-processor succeeds, the frontend updates identity_core:

```typescript
// 1. Create enrollment record
await createEnrollment({ tenantId, methodType: 'FACE' })
// 2. Mark as complete (FACE is async type)
await httpClient.put(`/users/${userId}/enrollments/FACE/complete`, {})
```

**Table: `user_enrollments`** (identity_core DB, V16 migration)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | FK -> users(id) |
| `tenant_id` | UUID | FK -> tenants(id) |
| `auth_method_type` | VARCHAR(30) | 'FACE', 'VOICE', etc. |
| `status` | VARCHAR(20) | Lifecycle state |
| `enrollment_data` | JSONB | Method-specific data |
| `enrolled_at` | TIMESTAMP | When enrolled |
| `expires_at` | TIMESTAMP | Optional expiry |
| `revoked_at` | TIMESTAMP | When revoked |

**Status lifecycle:** `NOT_ENROLLED` -> `PENDING` -> `ENROLLED` | `FAILED` | `REVOKED` | `EXPIRED`

---

## 3. Face -- Verification Flow

### 3.1 Browser: Capture & Submission

**Two verification contexts:**

**A. Dashboard verification** (FaceCaptureStep.tsx):
- Single capture: detect face, hold 1.5s (HOLD_DURATION), auto-capture via `cropFace(canvas)`
- Sends single base64 JPEG via `onSubmit(image)`

**B. MFA step verification** (FaceCaptureStep in auth flow):
- Same single-capture flow
- Submits via `AuthSessionRepository.completeStep()` with `{ data: { image: base64 } }`

### 3.2 MFA Verification Path (through identity-core-api)

**Endpoint:** `POST /auth/mfa/step`
```json
{
  "sessionToken": "<mfa-session-token>",
  "data": { "image": "<base64-jpeg-no-prefix>" }
}
```

**FaceAuthHandler.validate()** (FaceAuthHandler.java:34-82):
1. Extract `image` from data map (base64 string)
2. Check `session.getUser() != null`
3. Decode base64 -> byte[] -> `Base64MultipartFile`
4. Call `biometricServicePort.verifyFace(userId, imageFile)`

**BiometricServiceAdapter.verifyFace()** (BiometricServiceAdapter.java:113-136):
```
POST http://biometric-processor:8001/verify
Content-Type: multipart/form-data
X-API-Key: <BIOMETRIC_SERVICE_API_KEY>

- file: face.jpg (binary)
- user_id: "<uuid>"
```

### 3.3 Biometric Processor: Verification

**Key file:** `biometric-processor/app/application/use_cases/verify_face.py`

1. Load image, detect face, extract face region
2. **Quality gate**: score >= 50.0 (VERIFICATION_QUALITY_THRESHOLD, line 37) -- more lenient than enrollment (70)
3. Extract 512-dim embedding from probe image
4. Retrieve stored CENTROID embedding: `repository.find_by_user_id(user_id)` (prefers CENTROID, falls back to latest INDIVIDUAL)
5. **Calculate cosine distance**: `CosineSimilarityCalculator.calculate(new_embedding, stored_embedding)`
   - L2-normalize both vectors
   - `cosine_distance = 1.0 - dot(emb1_norm, emb2_norm)`
6. **Threshold check**: distance < 0.6 (default threshold)
   - 0.0 = identical, 0.4 = high confidence, 0.6 = balanced threshold, 0.8 = different

**Confidence = 1.0 - distance** (cosine_similarity.py:135-145)

**Response:**
```json
{
  "verified": true,
  "confidence": 0.82,
  "distance": 0.18,
  "threshold": 0.6,
  "message": "Face verified successfully"
}
```

### 3.4 Back in FaceAuthHandler

**Double-check logic** (FaceAuthHandler.java:60-77):
1. Check `result.get("error_code")` for `"SPOOF_DETECTED"` -> reject
2. Check `result.get("verified")` boolean
3. **Fallback**: if not verified but `confidence >= 0.7` (DEFAULT_CONFIDENCE_THRESHOLD), accept anyway
4. Return `StepResult.success()` or `StepResult.failure()`

---

## 4. Voice -- Enrollment Flow

### 4.1 Browser: Recording & Encoding

**Key file:** `web-app/src/features/auth/components/VoiceEnrollmentFlow.tsx`

1. **Recording**: `MediaRecorder` with `mimeType: 'audio/webm;codecs=opus'` (line 219)
2. **Duration**: Up to 10 seconds (MAX_RECORDING_SECONDS)
3. **Voice activity check**: Amplitude monitoring via AnalyserNode; rejects if `maxAmplitude < 0.05` (line 231)
4. **Passphrase**: Random from 6 built-in English phrases (lines 89-96), displayed to user
5. **Audio conversion** (lines 59-77):
   - WebM -> WAV 16kHz mono via `AudioContext({ sampleRate: 16000 })`
   - `decodeAudioData()` -> mono channel -> `createWavBuffer()` (PCM int16)
   - Fallback: send raw WebM if conversion fails
6. **Encoding**: `FileReader.readAsDataURL(wavBlob)` -> strip `data:audio/wav;base64,` prefix -> raw base64 string

### 4.2 API Call (Enrollment)

**VoiceEnrollmentFlow calls identity-core-api proxy** (line 321):
```
POST /api/v1/biometric/voice/enroll/{userId}
Authorization: Bearer <jwt>
Content-Type: application/json

{ "voiceData": "<base64-wav>" }
```

**BiometricController.enrollVoice()** -> `biometricServicePort.enrollVoice(userId, voiceData)`

**BiometricServiceAdapter.enrollVoice()** (BiometricServiceAdapter.java:176-189):
```
POST http://biometric-processor:8001/voice/enroll
Content-Type: application/json
X-API-Key: <key>

{ "user_id": "<uuid>", "voice_data": "<base64-wav>" }
```

### 4.3 Biometric Processor: Voice Embedding

**Key files:**
- `biometric-processor/app/api/routes/voice.py` (lines 58-108)
- `biometric-processor/app/infrastructure/ml/voice/speaker_embedder.py`

1. **Decode audio** (speaker_embedder.py:81-104):
   - Strip data URI prefix if present
   - Base64 decode -> raw bytes
   - Auto-detect format (WAV magic bytes `RIFF`, WebM `\x1aE\xdf\xa3`, etc.)

2. **Convert to 16kHz mono** (speaker_embedder.py:110-154):
   - pydub + ffmpeg for WebM/Opus
   - Direct WAV parse for WAV files (faster, no ffmpeg)
   - Resample if needed via `scipy.signal.resample`
   - Minimum duration: 0.5 seconds

3. **Extract embedding** (speaker_embedder.py:193-226):
   - `resemblyzer.preprocess_wav()` -- VAD + normalization (skips resample since already 16kHz)
   - `VoiceEncoder.embed_utterance(processed)` -> 256-dim vector
   - L2-normalize to unit vector for cosine similarity
   - Output: `np.float32` array of shape (256,)

### 4.4 Database Storage (biometric_db)

**Table: `voice_enrollments`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | (auto) | Primary key |
| `user_id` | VARCHAR | User identifier |
| `tenant_id` | VARCHAR | Optional tenant |
| `embedding` | vector(256) | 256-dim Resemblyzer speaker embedding |
| `quality_score` | FLOAT | Always 1.0 (no voice quality metric yet) |
| `enrollment_type` | VARCHAR | 'INDIVIDUAL' or 'CENTROID' |
| `deleted_at` | TIMESTAMP | Soft delete |
| `created_at` | TIMESTAMP | Creation time |
| `updated_at` | TIMESTAMP | Last update |

**Centroid pattern** (same as face): Each enrollment stores an INDIVIDUAL row, then computes/updates CENTROID as `AVG(embedding)::vector(256)` across all INDIVIDUAL rows.

**Indexes:**
- `idx_voice_enrollments_embedding_hnsw`: HNSW (m=16, ef_construction=64, vector_cosine_ops)
- `idx_voice_enrollments_user_type`: B-tree on `(user_id, enrollment_type) WHERE deleted_at IS NULL`

---

## 5. Voice -- Verification Flow

### 5.1 Browser

Same recording flow as enrollment. Submitted via:
- **MFA step**: `POST /auth/mfa/step` with `{ data: { voiceData: "<base64>" } }`
- **Direct verify**: `POST /api/v1/biometric/voice/verify/{userId}` with `{ voiceData: "<base64>" }`

### 5.2 VoiceAuthHandler (MFA path)

**VoiceAuthHandler.java:27-57:**
1. Extract `voiceData` from data map
2. Call `biometricServicePort.verifyVoice(userId, voiceData)`
3. Check `result.get("verified")` -> StepResult.success/failure

### 5.3 Biometric Processor Verification

**voice.py:114-178:**
1. Extract 256-dim probe embedding from submitted audio (same pipeline as enrollment)
2. Load enrolled CENTROID: `repo.find_by_user_id(user_id)` (prefers CENTROID, falls back to latest INDIVIDUAL)
3. **Cosine similarity**: `np.dot(probe_embedding, enrolled_embedding)` -- both already L2-normalized
4. Clamp to [0, 1]
5. **Threshold**: `VERIFY_THRESHOLD = 0.65` (voice.py:120)
6. `verified = similarity >= 0.65`

**Response:**
```json
{
  "success": true,
  "verified": true,
  "confidence": 0.7823,
  "message": "Voice verified successfully",
  "user_id": "<uuid>",
  "modality": "voice"
}
```

---

## 6. Fingerprint/WebAuthn -- Enrollment Flow

### 6.1 Browser: WebAuthn Registration Ceremony

**Key file:** `web-app/src/features/auth/components/WebAuthnEnrollment.tsx`

This uses the **W3C WebAuthn API** for platform authenticators (Touch ID, Windows Hello, Android biometrics).

**Step 1: Get registration options** (WebAuthnEnrollment.tsx:137-140):
```
POST /api/v1/webauthn/register/options/{userId}
Authorization: Bearer <jwt>
```

**Response from DeviceController.getRegistrationOptions()** (DeviceController.java:85-113):
```json
{
  "sessionId": "<uuid>",
  "challenge": "<base64url-32-random-bytes>",
  "rpId": "fivucsas.com",
  "rpName": "Fivucsas Identity",
  "userId": "<uuid>",
  "userName": "user@example.com",
  "excludeCredentials": ["<existing-credential-id-1>", ...],
  "attestation": "direct",
  "authenticatorSelection": {
    "authenticatorAttachment": "platform",
    "requireResidentKey": false,
    "userVerification": "preferred"
  }
}
```

**Challenge generation** (WebAuthnService.java:37-44):
- 32 random bytes via `SecureRandom`
- Base64url encoded (no padding)
- Stored in Redis: key `webauthn:challenge:<sessionId>`, TTL 5 minutes

**Step 2: Browser WebAuthn create** (WebAuthnEnrollment.tsx:154-179):
```typescript
navigator.credentials.create({
  publicKey: {
    challenge: <ArrayBuffer>,
    rp: { name: "Fivucsas Identity", id: "fivucsas.com" },
    user: { id: <userId-bytes>, name: email, displayName: email },
    pubKeyCredParams: [
      { type: "public-key", alg: -7 },   // ES256 (ECDSA P-256)
      { type: "public-key", alg: -257 },  // RS256 (RSASSA-PKCS1-v1_5)
    ],
    authenticatorSelection: {
      authenticatorAttachment: "platform",  // or "cross-platform" for hardware keys
      requireResidentKey: false,
      userVerification: "preferred",
    },
    excludeCredentials: [...],
    attestation: "direct",
    timeout: 60000,
  }
})
```

The browser prompts for biometric (fingerprint/Face ID/Windows Hello). On success, returns `PublicKeyCredential`.

**Step 3: Encode and send attestation** (WebAuthnEnrollment.tsx:189-222):
```
POST /api/v1/webauthn/register/verify
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "userId": "<uuid>",
  "sessionId": "<uuid>",
  "credentialId": "<base64url>",           // credential.id (from browser)
  "publicKey": "<base64url>",              // getPublicKey() or attestationObject
  "clientDataJSON": "<base64url>",         // attestationResponse.clientDataJSON
  "attestationFormat": "packed",
  "transports": "internal",               // or "usb,ble,nfc" for hardware keys
  "deviceName": "My MacBook Touch ID"
}
```

### 6.2 Backend: Registration Verification

**DeviceController.verifyRegistration()** (DeviceController.java:116-175):

1. Parse request fields
2. **Validate challenge** via `webAuthnService.validateRegistrationChallenge(sessionId, clientDataJson)`:
   - Retrieve stored challenge from Redis
   - Decode clientDataJSON (base64url -> JSON)
   - Verify `type == "webauthn.create"`
   - Verify `challenge` matches stored value
   - Consume (delete) challenge from Redis
3. Check `credentialRepository.existsByCredentialId(credentialId)` for duplicates
4. **Store credential** in `webauthn_credentials` table:
   ```java
   WebAuthnCredential.builder()
       .user(user)
       .credentialId(credentialId)
       .publicKey(publicKey)          // base64url X.509 ECDSA public key
       .publicKeyAlgorithm("ES256")
       .attestationFormat("packed")
       .transports("internal")
       .deviceName("My MacBook Touch ID")
       .build()
   ```
5. **Auto-complete enrollment**: `manageEnrollmentUseCase.completeEnrollment(userId, FINGERPRINT, "{}")` -- marks `user_enrollments` row as ENROLLED

### 6.3 Database Storage (identity_core)

**Table: `webauthn_credentials`** (V18 migration)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key (gen_random_uuid) |
| `user_id` | UUID | FK -> users(id) CASCADE |
| `credential_id` | VARCHAR(512) | WebAuthn credential ID (UNIQUE) |
| `public_key` | TEXT | Base64url X.509 public key |
| `public_key_algorithm` | VARCHAR(20) | 'ES256' (default) or 'RS256' |
| `sign_count` | BIGINT | Authenticator signature counter |
| `device_name` | VARCHAR(100) | User-provided device label |
| `attestation_format` | VARCHAR(50) | 'packed', 'none', etc. |
| `transports` | VARCHAR(255) | 'internal', 'usb', 'ble,nfc', etc. |
| `created_at` | TIMESTAMP | Creation time |
| `last_used_at` | TIMESTAMP | Last authentication time |

**Indexes:**
- `idx_webauthn_credentials_user_id`: B-tree on `user_id`
- `idx_webauthn_credentials_credential_id`: B-tree on `credential_id`

---

## 7. Fingerprint/WebAuthn -- Verification Flow

### 7.1 Browser: WebAuthn Assertion

**Key file:** `web-app/src/features/auth/components/steps/FingerprintStep.tsx`

**Step 1: Request challenge** (via MFA step or `onRequestChallenge` callback):
- MFA path: `POST /auth/mfa/step` with `{ data: { action: "challenge" } }`
- FingerprintAuthHandler.generateChallenge() returns:
  ```json
  {
    "status": "CHALLENGE",
    "data": {
      "challenge": "<base64url>",
      "rpId": "fivucsas.com",
      "authenticatorAttachment": "platform",
      "timeout": "60000",
      "allowCredentials": ["<cred-id-1>", "<cred-id-2>"]
    }
  }
  ```

**Step 2: Browser WebAuthn get** (FingerprintStep.tsx:86-95):
```typescript
navigator.credentials.get({
  publicKey: {
    challenge: <ArrayBuffer>,
    rpId: "fivucsas.com",           // from server, NOT window.location.hostname
    userVerification: "required",    // biometric required for fingerprint
    authenticatorAttachment: "platform",
    timeout: 60000,
    allowCredentials: [              // enables non-discoverable credentials
      { type: "public-key", id: <ArrayBuffer> }
    ],
  }
})
```

**Step 3: Encode assertion** (FingerprintStep.tsx:101-106):
```typescript
btoa(JSON.stringify({
  credentialId: credential.id,               // base64url from browser
  authenticatorData: arrayBufferToBase64(assertionResponse.authenticatorData),
  clientDataJSON: arrayBufferToBase64(assertionResponse.clientDataJSON),
  signature: arrayBufferToBase64(assertionResponse.signature),
}))
```
Result: base64-encoded JSON string submitted as `fingerprintData`.

### 7.2 Backend: Assertion Verification

**FingerprintAuthHandler.validate()** (FingerprintAuthHandler.java:44-126):

1. If `action == "challenge"`: generate and return challenge (see above)
2. Parse `fingerprintData`: base64 decode -> JSON -> extract credentialId, authenticatorData, clientDataJSON, signature
3. Look up credential: `credentialRepository.findByCredentialId(credentialId)`
4. Verify user ownership: `credential.getUser().getId().equals(session.getUser().getId())`
5. **Cryptographic verification** via `webAuthnService.verifyAssertion()`:

**WebAuthnService.verifyAssertion()** (WebAuthnService.java:99-148):
1. Retrieve stored challenge from Redis (`webauthn:challenge:<sessionId>`)
2. **Validate clientDataJSON** (lines 209-243):
   - Decode base64url -> JSON
   - `type == "webauthn.get"`
   - `challenge` matches stored value
   - `origin` contains `rpId` ("fivucsas.com")
3. **Validate authenticatorData** (lines 252-291):
   - Minimum 37 bytes (32 rpIdHash + 1 flags + 4 signCount)
   - SHA-256 of rpId ("fivucsas.com") must match first 32 bytes
   - User Present (UP) flag bit 0 must be set
4. **Verify ECDSA signature** (lines 153-184):
   - Decode public key (base64url -> X.509 -> EC PublicKey)
   - Build signed data: `authenticatorData || SHA-256(clientDataJSON)`
   - Verify with `SHA256withECDSA` signature algorithm
5. Consume challenge from Redis (one-time use)

6. **Update sign count** (FingerprintAuthHandler.java:108-112):
   - Extract from authenticatorData bytes 33-36 (big-endian uint32)
   - If new > stored: update credential (detects cloned authenticators)

### 7.3 Database Queries During Verification

```sql
-- 1. Find credential by ID
SELECT * FROM webauthn_credentials WHERE credential_id = ?;

-- 2. Challenge from Redis
GET webauthn:challenge:<sessionId>

-- 3. Update sign count after successful verification
UPDATE webauthn_credentials SET sign_count = ?, last_used_at = NOW()
WHERE id = ?;
```

---

## 8. Complete Database Schema Summary

### identity_core Database

**`user_enrollments`** (V16):
```sql
CREATE TABLE user_enrollments (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id        UUID NOT NULL REFERENCES tenants(id),
    auth_method_type VARCHAR(30) NOT NULL,  -- FACE, VOICE, FINGERPRINT, etc.
    status           VARCHAR(20) NOT NULL DEFAULT 'NOT_ENROLLED',
    enrollment_data  JSONB DEFAULT '{}',
    enrolled_at      TIMESTAMP WITH TIME ZONE,
    expires_at       TIMESTAMP WITH TIME ZONE,
    revoked_at       TIMESTAMP WITH TIME ZONE,
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, auth_method_type, tenant_id)
);
```

**`webauthn_credentials`** (V18):
```sql
CREATE TABLE webauthn_credentials (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id        VARCHAR(512) NOT NULL UNIQUE,
    public_key           TEXT NOT NULL,
    public_key_algorithm VARCHAR(20) NOT NULL DEFAULT 'ES256',
    sign_count           BIGINT NOT NULL DEFAULT 0,
    device_name          VARCHAR(100),
    attestation_format   VARCHAR(50),
    transports           VARCHAR(255),
    created_at           TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_used_at         TIMESTAMP WITH TIME ZONE
);
```

### biometric_db Database

**`face_embeddings`**:
```sql
CREATE TABLE face_embeddings (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id        VARCHAR(255) NOT NULL,
    tenant_id      VARCHAR(255),
    embedding      vector(512) NOT NULL,
    quality_score  FLOAT NOT NULL,         -- 0.0-1.0 (normalized)
    enrollment_type VARCHAR,               -- 'INDIVIDUAL' or 'CENTROID'
    is_active      BOOLEAN DEFAULT TRUE,
    deleted_at     TIMESTAMP WITH TIME ZONE,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata       JSONB DEFAULT '{}'
);
-- HNSW index: idx_face_embeddings_embedding_hnsw (m=16, ef_construction=64)
```

**`voice_enrollments`**:
```sql
CREATE TABLE voice_enrollments (
    -- Same structure as face_embeddings but with vector(256)
    user_id        VARCHAR,
    tenant_id      VARCHAR,
    embedding      vector(256) NOT NULL,
    quality_score  FLOAT,
    enrollment_type VARCHAR,               -- 'INDIVIDUAL' or 'CENTROID'
    deleted_at     TIMESTAMP WITH TIME ZONE,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at     TIMESTAMP WITH TIME ZONE
);
-- HNSW index: idx_voice_enrollments_embedding_hnsw (m=16, ef_construction=64)
```

---

## 9. Known Issues & Gaps

### 9.1 Face

1. **Liveness score is hardcoded**: `EnrollmentResponse.liveness_score = 1.0` (enrollment.py:127). Server-side anti-spoofing runs during verification (SPOOF_DETECTED check in FaceAuthHandler) but not during enrollment.

2. **FaceAuthHandler confidence fallback**: If biometric-processor returns `verified: false` but `confidence >= 0.7`, the handler overrides to success (FaceAuthHandler.java:66-68). This secondary threshold (0.7) differs from the processor's own threshold (0.6) and could cause inconsistent behavior.

3. **Init SQL schema drift**: The `scripts/db/init.sql` defines `face_embeddings` without `enrollment_type`, `deleted_at`, or `is_active` columns that the repository code uses. The production schema was likely altered via manual SQL or a separate migration. The `scripts/init-database.sql` shows an older 128-dim schema.

4. **Unique constraint conflict**: `init.sql` has `UNIQUE (user_id, tenant_id)` on face_embeddings, but the repository stores multiple INDIVIDUAL rows per user. The production schema must have dropped this constraint.

5. **Direct browser -> biometric-processor path**: Face enrollment bypasses identity-core-api, meaning JWT auth is not enforced at the biometric level (only API key). The CLAUDE.md notes bio.fivucsas.com is internal-only, but the BiometricService.ts has a fallback URL.

### 9.2 Voice

6. **No voice quality metric**: `quality_score` is always 1.0 (voice.py:83). No SNR, speech clarity, or minimum energy checks beyond the basic amplitude gate (0.05 threshold in the browser).

7. **No voice liveness detection**: No anti-replay or anti-spoofing for voice. A recording of someone's voice would pass verification.

8. **Voice centroid unbounded**: Unlike face (capped at 5 INDIVIDUAL rows), voice enrollment has no cap on individual enrollments, which could dilute the centroid over time.

### 9.3 Fingerprint/WebAuthn

9. **No attestation verification**: The backend does NOT verify the attestation object during registration (DeviceController.java:137-138 only validates the challenge, not the attestation signature). This means any client can register a credential without proving it came from a genuine authenticator.

10. **Public key source ambiguity**: The frontend sends `getPublicKey()` if available, otherwise falls back to `attestationObject` (WebAuthnEnrollment.tsx:208-211). The backend stores whatever is sent without validation -- if attestationObject is sent instead of the raw public key, signature verification during authentication will fail.

### 9.4 Cross-Cutting

11. **Enrollment status can desync**: Face and voice enrollment data lives in biometric_db while enrollment status lives in identity_core. If biometric-processor succeeds but the subsequent `PUT /enrollments/FACE/complete` call fails, data exists in biometric_db but status remains PENDING.

12. **No enrollment health verification for voice**: The enrollment health check validates face by calling the biometric processor, but voice enrollment health is not explicitly checked.

---

## 10. Recommendations

1. **Add server-side liveness during enrollment**: Run anti-spoofing checks during face enrollment, not just verification. Reject enrollment of photos/screens.

2. **Harmonize face confidence thresholds**: Use a single configurable threshold rather than having 0.6 in biometric-processor and 0.7 fallback in FaceAuthHandler.

3. **Add voice quality scoring**: Implement SNR measurement and minimum speech energy checks in the biometric processor.

4. **Add attestation verification**: Verify the attestation signature chain during WebAuthn registration to ensure credentials come from genuine authenticators.

5. **Cap voice enrollments**: Add MAX_INDIVIDUAL_ENROLLMENTS limit for voice (same as face's 5-cap) to prevent centroid dilution.

6. **Add enrollment saga/compensation**: If biometric enrollment succeeds but enrollment record update fails, implement a compensation mechanism to clean up orphaned biometric data.

7. **Fix init.sql schema**: Update `scripts/db/init.sql` to match the production schema (add enrollment_type, deleted_at, is_active; remove UNIQUE constraint; update vector dimension to 512).

8. **Add voice anti-replay**: Implement challenge-response for voice (e.g., require reading a random phrase) and/or add server-side replay detection using audio fingerprinting.
