# Auth-Test vs Web-App Forensic Comparison

**Date**: 2026-04-11
**Author**: Claude Opus 4.6 (automated analysis)
**Scope**: All 10 auth methods across auth-test (standalone HTML/JS), web-app (React 18), and widget (verify-app)

---

## 1. Executive Summary — Top 5 Reasons for Transfer Failures

### BUG #1: FINGERPRINT field name mismatch across dispatchers (CRITICAL)
- **TwoFactorDispatcher** (line 201) and **LoginMfaFlow** (line 260) send: `{ assertion: data }`
- **MultiStepAuthFlow** (line 390) sends: `{ fingerprintData: data }`
- Backend (`AuthController.java`, line 701) reads: `data.get("assertion")`
- **Impact**: Fingerprint verification through MultiStepAuthFlow (widget session mode) ALWAYS FAILS — the backend never finds the `assertion` field because it's sent as `fingerprintData`.

### BUG #2: Two completely different verification paths
- **Auth-test** calls individual endpoints directly: `/api/v1/biometric/verify/{userId}`, `/api/v1/otp/email/verify/{userId}`, etc. Each endpoint is standalone and well-tested.
- **Web-app MFA path** uses a single unified endpoint: `POST /auth/mfa/step` with `{ sessionToken, method, data }`. This endpoint is newer and less battle-tested.
- **Web-app session path** (MultiStepAuthFlow) uses yet another endpoint: `POST /auth/sessions/{id}/steps/{order}` with `{ data }`.
- **Impact**: Three different code paths for the same logical operation means bugs in one path don't surface in another.

### BUG #3: Auth-test uses `location.hostname` for rpId; web-app relies on server challenge
- **Auth-test** (`app.js`, lines 2054, 2087, 2116, 2459, 2500): Always uses `location.hostname` as rpId for all WebAuthn operations (register + verify). Credentials are bound to whatever hostname the page runs on.
- **Web-app** (`FingerprintStep.tsx`, line 89; `HardwareKeyStep.tsx`, line 68): Uses `rpId` from server challenge response, falling back to `window.location.hostname`.
- **Server** returns `rpId: "fivucsas.com"` (from `webAuthnService.getRpId()`).
- **Impact**: Credentials registered via auth-test (on e.g. `auth-test.fivucsas.com` or `localhost`) will NOT work in web-app because the rpId differs. Cross-subdomain works only when rpId is set to the eTLD+1 (`fivucsas.com`), which auth-test never does.

### BUG #4: Auth-test uses localStorage for credential IDs; web-app depends on server allowCredentials
- **Auth-test** stores credential IDs in `localStorage` (`fivucsas_fpe_credId`, `fivucsas_hw_credId`) and always provides them as `allowCredentials`.
- **Web-app** requests `allowCredentials` from the server via the challenge endpoint. If the server returns no credentials (e.g., empty enrollment, transport filter mismatch), the WebAuthn prompt shows only discoverable/resident credentials.
- **Impact**: Non-discoverable credentials (common on Android) won't be found without explicit `allowCredentials`. If server filtering by transport type goes wrong, auth silently fails.

### BUG #5: Auth-test generates random client-side challenges; web-app uses server challenges
- **Auth-test** (`app.js`, lines 2048-2049, 2076, 2452-2453, 2489): `randomBytes(32)` for every challenge. No server validation of challenge.
- **Web-app** uses `resolveChallenge()` (`webauthn-utils.ts`, line 104) which requests a server challenge and falls back to random. Server stores the challenge in MFA session for later verification.
- **Impact**: Auth-test's WebAuthn verification is purely client-side (checks that the authenticator responds, but never verifies the signature server-side). Web-app does full cryptographic verification. If the challenge request fails silently, the fallback random challenge will NEVER pass server verification.

---

## 2. Method-by-Method Comparison

### 2.1 PASSWORD

| Aspect | Auth-Test | Web-App | Difference | Impact |
|--------|-----------|---------|------------|--------|
| Endpoint | `POST /api/v1/auth/login` | `POST /api/v1/auth/login` (via AuthRepository.login) | Same | None |
| Request | `{ email, password }` | `{ email, password }` | Same | None |
| Response | Reads `data.token \|\| data.accessToken` | Reads typed `AuthResponse` | Repo maps to typed object | None |
| Token storage | `localStorage.setItem('fivucsas_token')` | React auth state + context | Different mechanism | None (both work) |
| MFA handling | None — just stores token | Checks `twoFactorRequired`, stores `mfaSessionToken` | Auth-test ignores MFA | Auth-test skips 2FA entirely |

### 2.2 EMAIL_OTP

| Aspect | Auth-Test | Web-App (MFA) | Difference | Impact |
|--------|-----------|---------------|------------|--------|
| Send endpoint | `POST /api/v1/otp/email/send/{userId}` | `POST /auth/mfa/send-otp` (TwoFactorDispatcher) or `handleStepSubmit({ action: 'send_otp' })` (MultiStepAuthFlow) | Different endpoints | Auth-test uses standalone OTP service; web-app routes through MFA session |
| Verify endpoint | `POST /api/v1/otp/email/verify/{userId}` | `POST /auth/mfa/step` with `{ code }` | Different endpoints | Web-app goes through unified MFA path |
| Auth required | Yes (Bearer token) | No (uses `sessionToken`) | Auth-test needs JWT first | None (both work in their context) |
| Auto-send | Manual button | EmailOtpMfaStep auto-sends on mount | UX difference | None |

### 2.3 SMS_OTP

| Aspect | Auth-Test | Web-App (MFA) | Difference | Impact |
|--------|-----------|---------------|------------|--------|
| Send endpoint | `POST /api/v1/otp/sms/send/{userId}` | `POST /auth/mfa/send-otp` with `{ sessionToken, method: 'SMS_OTP' }` | Different endpoints | Same as EMAIL_OTP pattern |
| Verify endpoint | `POST /api/v1/otp/sms/verify/{userId}` | `POST /auth/mfa/step` with `{ code }` | Different endpoints | Web-app MFA path |
| Service | NoOpSmsService (both) | NoOpSmsService | Same | Both log-only, Twilio not activated |

### 2.4 TOTP

| Aspect | Auth-Test | Web-App (MFA) | Difference | Impact |
|--------|-----------|---------------|------------|--------|
| Setup | `POST /api/v1/totp/setup/{userId}` | TotpEnrollment uses same endpoint | Same | None |
| Verify | `POST /api/v1/totp/verify-setup/{userId}` | `POST /auth/mfa/step` with `{ code }` | Different: auth-test uses dedicated verify, web-app uses MFA step | MFA path uses `TotpService.verifyCode()` internally — same logic |
| Auto-submit | No | Yes (TotpStep auto-submits on 6 digits) | UX difference | None |

### 2.5 FACE

| Aspect | Auth-Test | Web-App (MFA) | Difference | Impact |
|--------|-----------|---------------|------------|--------|
| Capture | Canvas + `toBlob()` → `FormData` | Canvas + `toDataURL('image/jpeg', 0.85)` → base64 string | **Blob vs Base64** | Both work but format differs |
| Verify endpoint | `POST /api/v1/biometric/verify/{userId}` (multipart) | `POST /auth/mfa/step` with `{ image: base64String }` | Different endpoints AND formats | Auth-test sends multipart/form-data; web-app sends JSON with base64 |
| Backend handling | Multipart file directly to BiometricServicePort | MFA handler decodes base64, strips `data:` prefix, creates in-memory MultipartFile (AuthController.java lines 672-688) | Auth-test is simpler | Both work but base64 path has extra decode overhead |
| Quality check | Client-side Laplacian + brightness + face size | Uses `useFaceDetection` + `useQualityAssessment` hooks (MediaPipe/BlazeFace) | Web-app has richer quality pipeline | None (both send image regardless) |
| Face detection | MediaPipe FaceLandmarker loaded in-page | `useFaceDetection` hook with lazy-loaded MediaPipe | Same underlying tech | None |

### 2.6 VOICE

| Aspect | Auth-Test | Web-App (MFA) | Difference | Impact |
|--------|-----------|---------------|------------|--------|
| Recording | MediaRecorder → WAV 16kHz conversion → base64 | MediaRecorder → `audio/webm` blob → `FileReader.readAsDataURL()` → base64 | **WAV vs WebM format** | Auth-test converts to WAV 16kHz for optimal Resemblyzer input; web-app sends raw WebM |
| Verify endpoint | `POST /api/v1/biometric/voice/verify/{userId}` | `POST /auth/mfa/step` with `{ voiceData }` | Different endpoints | MFA handler passes voiceData to `biometricService.verifyVoice()` |
| Sample rate | 16kHz (explicit conversion) | Browser default (usually 48kHz WebM) | **Potential quality mismatch** | Backend may handle both, but WAV 16kHz is optimal for Resemblyzer |

### 2.7 FINGERPRINT (CRITICAL)

| Aspect | Auth-Test | Web-App TwoFactorDispatcher | Web-App MultiStepAuthFlow | Difference | Impact |
|--------|-----------|---------------------------|--------------------------|------------|--------|
| rpId | `location.hostname` | Server challenge `rpId` (fallback: `window.location.hostname`) | Server challenge `rpId` via `completeStep` | Auth-test binds to hostname; web-app binds to `fivucsas.com` | **Credentials not portable** |
| Challenge | `randomBytes(32)` (client) | Server challenge via `requestWebAuthnChallenge()` | Server challenge via `completeStep({ action: 'challenge' })` | Auth-test: no server verification; web-app: full crypto | Auth-test is cosmetic only |
| allowCredentials | `localStorage.getItem('fivucsas_fpe_credId')` | Server-provided (from challenge response) | Server-provided | Auth-test always has cred ID; web-app depends on server | Android non-discoverable creds may fail |
| authenticatorAttachment | `'platform'` | `WEBAUTHN.ATTACHMENT_PLATFORM` = `'platform'` | Not specified directly (via challenge) | Same | None |
| Data field sent | N/A (client-only) | `{ assertion: btoa(JSON.stringify({...})) }` | **`{ fingerprintData: btoa(JSON.stringify({...})) }`** | **MISMATCH** | **MultiStepAuthFlow BROKEN** |
| Backend reads | N/A | `data.get("assertion")` | `data.get("assertion")` (but receives `fingerprintData`) | Backend gets null for `assertion` | **Always fails via widget session mode** |
| Error handling | Simple try/catch | Distinguishes NotAllowedError (user cancel vs no passkey), SecurityError | Same as TwoFactorDispatcher | Auth-test lumps all errors | UX difference only |

### 2.8 HARDWARE_KEY

| Aspect | Auth-Test | Web-App TwoFactorDispatcher | Web-App MultiStepAuthFlow | Difference | Impact |
|--------|-----------|---------------------------|--------------------------|------------|--------|
| rpId | `location.hostname` | Server challenge `rpId` | Server challenge via `completeStep` | Same issue as fingerprint | Credentials not portable |
| Challenge | `randomBytes(32)` | Server challenge | Server challenge | Same issue | Auth-test cosmetic only |
| authenticatorAttachment | `'cross-platform'` | Not set (allows any) | Not set | Auth-test restricts to USB/NFC; web-app allows any | Web-app more flexible |
| userVerification | `'preferred'` | `WEBAUTHN.UV_PREFERRED` = `'preferred'` | Via challenge | Same | None |
| Data format | N/A (client-only) | `verifyStep(HARDWARE_KEY, { credentialId, authenticatorData, clientDataJSON, signature })` — sends object directly | `handleStepSubmit(data)` — passes object through | TwoFactorDispatcher sends flat object; backend expects `assertion` field | **Potential issue** |
| Timeout | 90000ms | 60000ms (`WEBAUTHN.TIMEOUT_MS`) | 60000ms | Auth-test gives more time | Minor UX |

**NOTE on HardwareKeyStep data format**: HardwareKeyStep's `onSubmit` returns an object `{ credentialId, authenticatorData, clientDataJSON, signature }`. In TwoFactorDispatcher (line 230), this is passed as: `verifyStep(AuthMethodType.HARDWARE_KEY, data)` — the data becomes `{ credentialId, authenticatorData, ... }` at the top level. But the backend reads `data.get("assertion")` (line 701). The HardwareKey data is sent as flat fields, NOT wrapped in an `assertion` base64 JSON like FingerprintStep does. **This is likely broken in TwoFactorDispatcher too.**

Wait — let me re-check. FingerprintStep wraps with `btoa(JSON.stringify({...}))` and TwoFactorDispatcher sends `{ assertion: data }` where `data` is already the base64 string. HardwareKeyStep sends a plain object `{ credentialId, ... }`. TwoFactorDispatcher passes it as `verifyStep(HARDWARE_KEY, data)` → `{ credentialId, authenticatorData, clientDataJSON, signature }`. Backend for HARDWARE_KEY case (line 698) reads `data.get("assertion")` — it expects the same base64 wrapper. **HardwareKeyStep does NOT wrap its data in base64 JSON.**

### 2.9 QR_CODE

| Aspect | Auth-Test | Web-App (MFA) | Difference | Impact |
|--------|-----------|---------------|------------|--------|
| QR Generation | Client-side via qrserver.com API | Server-side via `POST /auth/mfa/qr-generate` or `authSessionRepo.generateQrToken()` | Completely different | Auth-test QR is cosmetic; web-app has real server token |
| Verification | Manual visual decode | `POST /auth/mfa/step` with `{ token }` | Different | Web-app properly verifies |
| Auto-refresh | No | Yes (countdown + auto-regenerate on expiry) | Web-app more robust | None |

### 2.10 NFC_DOCUMENT

| Aspect | Auth-Test | Web-App | Difference | Impact |
|--------|-----------|---------|------------|--------|
| Scan | NDEFReader API (Chrome Android only) | NDEFReader API (same) | Same | None |
| Enroll | `POST /api/v1/nfc/enroll` with `{ userId, cardSerial, cardType }` | NfcStep sends serial number via `onSubmit` | Auth-test has full enroll/verify/search/delete flow | Web-app is a stub |
| Verify | `POST /api/v1/nfc/verify` + search + delete | `POST /auth/mfa/step` with `{ nfcData: serialNumber }` | MFA path uses different backend handler | NfcDocumentAuthHandler may not match auth-test's flow |

---

## 3. Architectural Divergences

### 3.1 Three Verification Paths

```
Auth-Test → Direct REST endpoints (standalone, JWT-authenticated)
   /api/v1/biometric/verify/{userId}    (face, multipart)
   /api/v1/biometric/voice/verify/{userId}  (voice, JSON)
   /api/v1/otp/email/verify/{userId}    (email OTP)
   /api/v1/totp/verify-setup/{userId}   (TOTP)
   Client-side WebAuthn only            (fingerprint, hardware key)

Web-App (TwoFactorDispatcher / LoginMfaFlow) → N-step MFA endpoint
   POST /auth/mfa/step  { sessionToken, method, data }

Web-App (MultiStepAuthFlow) → Session-based step completion
   POST /auth/sessions/{id}/steps/{order}  { data }
```

### 3.2 Data Wrapping Differences

The `AuthSessionRepository.completeStep()` wraps data in `{ data }`:
```typescript
// AuthSessionRepository.ts line 133-136
const response = await this.httpClient.post(
    `/auth/sessions/${sessionId}/steps/${stepOrder}`,
    { data }  // ← extra wrapper
)
```

The `AuthRepository.verifyMfaStep()` also wraps in `data`:
```typescript
// AuthRepository.ts line 137-141
const response = await this.httpClient.post('/auth/mfa/step', {
    sessionToken,
    method,
    data,  // ← nested under `data` key
})
```

Backend `AuthController.verifyMfaStep()`:
```java
// AuthController.java line 570
Map<String, Object> data = (Map<String, Object>) request.getOrDefault("data", Map.of());
```

This is consistent. But the **contents** of `data` differ between dispatchers.

### 3.3 Challenge Source Architecture

```
Auth-Test:
   challenge = crypto.getRandomValues(new Uint8Array(32))
   → Used only for WebAuthn ceremony
   → NEVER sent to server
   → Server NEVER validates

Web-App (MFA path):
   1. Client calls verifyMfaStep(token, method, { action: "challenge" })
   2. Server generates challenge, stores in MfaSession, returns challenge+rpId+allowCredentials
   3. Client uses challenge for WebAuthn ceremony
   4. Client sends assertion back via verifyMfaStep(token, method, { assertion: ... })
   5. Server verifies signature against stored challenge

Web-App (Session path):
   1. Client calls completeStep(sessionId, stepOrder, { action: "challenge" })
   2. Goes to auth-sessions endpoint (different controller)
   3. Returns challenge data
   4. Client sends assertion via completeStep(sessionId, stepOrder, { fingerprintData: ... })
   5. ← BUG: field name mismatch
```

---

## 4. Data Flow Mismatches

### 4.1 FingerprintStep onSubmit payload
```typescript
// FingerprintStep.tsx lines 101-106
onSubmit(btoa(JSON.stringify({
    credentialId: credential.id,
    authenticatorData: arrayBufferToBase64(assertionResponse.authenticatorData),
    clientDataJSON: arrayBufferToBase64(assertionResponse.clientDataJSON),
    signature: arrayBufferToBase64(assertionResponse.signature),
})))
// Returns: a single base64 string
```

### 4.2 HardwareKeyStep onSubmit payload
```typescript
// HardwareKeyStep.tsx lines 77-82
onSubmit({
    credentialId: credential.id,
    authenticatorData: arrayBufferToBase64(assertionResponse.authenticatorData),
    clientDataJSON: arrayBufferToBase64(assertionResponse.clientDataJSON),
    signature: arrayBufferToBase64(assertionResponse.signature),
})
// Returns: a plain object with 4 fields
```

### 4.3 How each dispatcher wraps the data

| Dispatcher | Fingerprint | Hardware Key |
|-----------|-------------|--------------|
| **TwoFactorDispatcher** | `{ assertion: base64String }` | `{ credentialId, authenticatorData, clientDataJSON, signature }` (flat) |
| **LoginMfaFlow** | `{ assertion: base64String }` | `{ credentialId, authenticatorData, clientDataJSON, signature }` (flat) |
| **MultiStepAuthFlow** | `{ fingerprintData: base64String }` | `{ credentialId, authenticatorData, clientDataJSON, signature }` (flat) |

### 4.4 What the backend expects

```java
// AuthController.java lines 698-705 — handles BOTH fingerprint and hardware key
case FINGERPRINT, HARDWARE_KEY -> {
    String assertionRaw = (String) data.get("assertion");
    if (assertionRaw == null || assertionRaw.isBlank()) yield false;
    
    String assertionJson = new String(Base64.getDecoder().decode(assertionRaw));
    // Parses: credentialId, authenticatorData, clientDataJSON, signature
}
```

**Result**:
- FingerprintStep via TwoFactorDispatcher: WORKS (sends `assertion` = base64 string)
- FingerprintStep via MultiStepAuthFlow: **BROKEN** (sends `fingerprintData`, backend reads `assertion` → null → false)
- HardwareKeyStep via TwoFactorDispatcher: **BROKEN** (sends flat object fields, backend reads `assertion` → gets object not string, cast fails)
- HardwareKeyStep via LoginMfaFlow: **BROKEN** (same issue)
- HardwareKeyStep via MultiStepAuthFlow: **BROKEN** (sends flat object, backend reads `assertion`)

---

## 5. Recommendations — Specific Code Changes

### FIX #1: MultiStepAuthFlow fingerprint field name (CRITICAL)
**File**: `/opt/projects/fivucsas/web-app/src/features/auth/components/MultiStepAuthFlow.tsx`
**Line**: 390
```typescript
// CURRENT (broken):
onSubmit={(data) => handleStepSubmit({ fingerprintData: data })}

// FIX:
onSubmit={(data) => handleStepSubmit({ assertion: data })}
```

### FIX #2: HardwareKeyStep must wrap data as base64 JSON (CRITICAL)
**File**: `/opt/projects/fivucsas/web-app/src/features/auth/components/steps/HardwareKeyStep.tsx`
**Lines**: 77-82

The `onSubmit` callback should return a base64-encoded JSON string (same format as FingerprintStep), not a plain object.

```typescript
// CURRENT (onSubmit sends plain object):
onSubmit({
    credentialId: credential.id,
    authenticatorData: arrayBufferToBase64(assertionResponse.authenticatorData),
    clientDataJSON: arrayBufferToBase64(assertionResponse.clientDataJSON),
    signature: arrayBufferToBase64(assertionResponse.signature),
})

// FIX (wrap as base64 JSON string — matches FingerprintStep format):
onSubmit(btoa(JSON.stringify({
    credentialId: credential.id,
    authenticatorData: arrayBufferToBase64(assertionResponse.authenticatorData),
    clientDataJSON: arrayBufferToBase64(assertionResponse.clientDataJSON),
    signature: arrayBufferToBase64(assertionResponse.signature),
})))
```

Then update all callers to send as `{ assertion: data }`:

**TwoFactorDispatcher.tsx line 230**:
```typescript
// CURRENT:
onSubmit={(data) => verifyStep(AuthMethodType.HARDWARE_KEY, data)}
// FIX:
onSubmit={(data) => verifyStep(AuthMethodType.HARDWARE_KEY, { assertion: data })}
```

**LoginMfaFlow.tsx line 289**:
```typescript
// CURRENT:
onSubmit={(data) => verifyStep(AuthMethodType.HARDWARE_KEY, data)}
// FIX:
onSubmit={(data) => verifyStep(AuthMethodType.HARDWARE_KEY, { assertion: data })}
```

**MultiStepAuthFlow.tsx line 424**:
```typescript
// CURRENT:
onSubmit={(data) => handleStepSubmit(data)}
// FIX:
onSubmit={(data) => handleStepSubmit({ assertion: data })}
```

Also update the `HardwareKeyStepProps` interface to match:
```typescript
// CURRENT:
onSubmit: (data: { credentialId: string; ... }) => void
// FIX:
onSubmit: (data: string) => void  // base64-encoded JSON
```

### FIX #3: Voice recording format (IMPROVEMENT)
**File**: `/opt/projects/fivucsas/web-app/src/features/auth/components/steps/VoiceStep.tsx`

Auth-test converts WebM → WAV 16kHz before sending. Web-app sends raw WebM base64. If biometric-processor handles both formats (likely), this is not a bug. But for consistency with auth-test's proven path, consider adding WAV conversion.

### FIX #4: Auth-test WebAuthn should use server rpId
**File**: `/opt/projects/fivucsas/auth-test/app.js`

Lines 2054, 2087, 2116, 2459, 2500: Change `location.hostname` to `'fivucsas.com'` (or make it configurable) so credentials registered in auth-test can be used in web-app.

```javascript
// CURRENT:
rp: { name: 'FIVUCSAS Auth Test', id: location.hostname },
// and:
rpId: location.hostname,

// FIX (use same rpId as production):
var RP_ID = 'fivucsas.com'; // or read from a config field
rp: { name: 'FIVUCSAS Auth Test', id: RP_ID },
rpId: RP_ID,
```

### FIX #5: Auth-test should use server challenges for full verification
The auth-test page does client-only WebAuthn — it never validates signatures server-side. This means credentials created/verified in auth-test provide a false sense of security. Consider adding backend integration for WebAuthn registration and verification.

---

## 6. Priority Matrix

| # | Fix | Severity | Effort | Files |
|---|-----|----------|--------|-------|
| 1 | MultiStepAuthFlow `fingerprintData` → `assertion` | P0-CRITICAL | 1 line | MultiStepAuthFlow.tsx:390 |
| 2 | HardwareKeyStep base64 wrap + all callers | P0-CRITICAL | ~15 lines | HardwareKeyStep.tsx:77, TwoFactorDispatcher.tsx:230, LoginMfaFlow.tsx:289, MultiStepAuthFlow.tsx:424 |
| 3 | Auth-test rpId alignment | P1-HIGH | 5 lines | auth-test/app.js (5 locations) |
| 4 | Voice WAV conversion in web-app | P2-MEDIUM | ~30 lines | VoiceStep.tsx |
| 5 | Auth-test server challenge integration | P3-LOW | ~100 lines | auth-test/app.js |
