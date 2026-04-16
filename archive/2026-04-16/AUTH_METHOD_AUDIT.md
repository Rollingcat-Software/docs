# Auth Method Data Contract Audit

**Date**: 2026-04-11
**Scope**: All 10 auth methods x 4 frontend dispatchers x 2 backend code paths
**Status**: BUGS FOUND -- 5 critical mismatches, 2 moderate issues

---

## 1. Enum Audit

### Frontend (`web-app/src/domain/models/AuthMethod.ts`)
```
PASSWORD, FACE, FINGERPRINT, QR_CODE, NFC_DOCUMENT, TOTP, SMS_OTP, EMAIL_OTP, VOICE, HARDWARE_KEY
```
(10 values)

### Backend (`identity-core-api/.../AuthMethodType.java`)
```
PASSWORD, EMAIL_OTP, SMS_OTP, TOTP, QR_CODE, FACE, FINGERPRINT, VOICE, NFC_DOCUMENT, HARDWARE_KEY,
DOCUMENT_SCAN, NFC_CHIP_READ, DATA_EXTRACT, FACE_MATCH, LIVENESS_CHECK, ADDRESS_PROOF,
WATCHLIST_CHECK, AGE_VERIFICATION, PHONE_VERIFICATION
```
(19 values -- 10 auth + 9 verification pipeline)

**Verdict**: MATCH for all 10 auth methods. The 9 extra verification pipeline types are not used in auth flows. No mismatch.

---

## 2. Repository Wrapping Audit

### AuthRepository.verifyMfaStep() (MFA path)
```typescript
// File: web-app/src/core/repositories/AuthRepository.ts:137
httpClient.post('/auth/mfa/step', {
    sessionToken,
    method,
    data,         // <-- data is passed through as-is from dispatcher
})
```
Backend reads: `request.get("sessionToken")`, `request.get("method")`, `request.getOrDefault("data", Map.of())`
**Verdict**: MATCH. No extra wrapping. Data flows cleanly.

### AuthSessionRepository.completeStep() (Session path)
```typescript
// File: web-app/src/core/repositories/AuthSessionRepository.ts:133
httpClient.post(`/auth/sessions/${sessionId}/steps/${stepOrder}`, {
    data    // <-- wraps in { data: {...} }
})
```
Backend reads: `CompleteAuthStepCommand.data()` which is `Map<String, Object> data`
The `CompleteAuthStepCommand` record is `record CompleteAuthStepCommand(@NotNull Map<String, Object> data) {}`
So Spring deserializes `{ "data": {...} }` into `command.data()`.
**Verdict**: MATCH. The `{ data }` wrapping aligns with the `CompleteAuthStepCommand` record.

---

## 3. Data Contract Table (Per Method x Per Dispatcher)

### Legend
- **D1** = TwoFactorDispatcher (MFA login flow)
- **D2** = LoginMfaFlow (Widget login MFA flow)
- **D3** = MultiStepAuthFlow (Auth session flow)
- **D4** = WidgetAuthPage (Legacy widget page -- uses different API endpoints)
- **BE-MFA** = AuthController.verifyMfaStep() switch statement
- **BE-Session** = Auth method handler via ExecuteAuthSessionService

---

### 3.1 PASSWORD

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D3 | `{ email, password }` | `data.get("email")`, `data.get("password")` | MATCH |
| D4 | N/A (direct fetch to `/auth/login`) | N/A | N/A |

Not used in D1/D2 (password is handled before MFA).

---

### 3.2 EMAIL_OTP

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | EmailOtpMfaStep sends `{ code }` via `authRepository.verifyMfaStep()` | BE-MFA: `data.get("code")` | MATCH |
| D2 | EmailOtpMfaStep sends `{ code }` via `authRepository.verifyMfaStep()` | BE-MFA: `data.get("code")` | MATCH |
| D3 | EmailOtpStep: `{ code }` or `{ action: 'send_otp' }` | BE-Session: `data.get("code")` or `data.get("action")` == "send" | **BUG B1** |

**BUG B1**: D3 sends `{ action: 'send_otp' }` but EmailOtpAuthHandler checks `"send".equals(action)`. The value `"send_otp"` != `"send"` so the OTP will never be sent via the session path. The send-OTP button in MultiStepAuthFlow silently fails.

---

### 3.3 SMS_OTP

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ code }` (OTP send via separate `/auth/mfa/send-otp` endpoint) | BE-MFA: `data.get("code")` | MATCH |
| D2 | `{ code }` (OTP send via separate `/auth/mfa/send-otp` endpoint) | BE-MFA: `data.get("code")` | MATCH |
| D3 | `{ code }` or `{ action: 'send_otp' }` | BE-Session: `data.get("code")` or `data.get("action")` == "send" | **BUG B2** |

**BUG B2**: Same as B1. D3 sends `"send_otp"` but SmsOtpAuthHandler expects `"send"`.

---

### 3.4 TOTP

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ code }` | BE-MFA: `data.get("code")` | MATCH |
| D2 | `{ code }` | BE-MFA: `data.get("code")` | MATCH |
| D3 | `{ code }` | BE-Session: `data.get("code")` | MATCH |

---

### 3.5 FACE

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ image }` -- base64 data URL (`data:image/jpeg;base64,...`) | BE-MFA: `data.get("image")`, strips data URL prefix, `Base64.getDecoder().decode()` | MATCH |
| D2 | `{ image }` -- same as D1 | Same as D1 | MATCH |
| D3 | `{ image }` -- base64 data URL | BE-Session FaceAuthHandler: `data.get("image")`, `Base64.getDecoder().decode(imageBase64)` | **BUG B3** |

**BUG B3**: FaceAuthHandler in the session path does `Base64.getDecoder().decode(imageBase64)` directly on the full string. It does NOT strip the `data:image/jpeg;base64,` prefix like the MFA path does. The MFA path (AuthController line 674) has:
```java
image.contains(",") ? image.substring(image.indexOf(",") + 1) : image
```
But FaceAuthHandler (line 46) does:
```java
byte[] imageBytes = Base64.getDecoder().decode(imageBase64);
```
This will throw `IllegalArgumentException` when the frontend sends a data URL (which it always does -- `canvas.toDataURL()` returns `data:image/jpeg;base64,...`).

---

### 3.6 VOICE

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ voiceData }` -- base64 data URL from FileReader.readAsDataURL() | BE-MFA: `data.get("voiceData")` | MATCH |
| D2 | `{ voiceData }` -- same | Same | MATCH |
| D3 | `{ voiceData }` -- same | BE-Session VoiceAuthHandler: `data.get("voiceData")` | MATCH |

Note: The voice data is a data URL (`data:audio/webm;base64,...`). Both the MFA and session paths pass the raw string to `biometricService.verifyVoice()` which must handle the prefix. Consistency is maintained.

---

### 3.7 FINGERPRINT

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ assertion: btoa(JSON.stringify({credentialId, authenticatorData, clientDataJSON, signature})) }` | BE-MFA: `data.get("assertion")`, Base64 decode, parse JSON for `credentialId`, `authenticatorData`, `clientDataJSON`, `signature` | MATCH |
| D2 | Same as D1 | Same | MATCH |
| D3 | `{ assertion: btoa(JSON.stringify({...})) }` | BE-Session FingerprintAuthHandler: `data.get("fingerprintData")` | **BUG B4** |

**BUG B4 (CRITICAL)**: D3 sends `{ assertion: "..." }` but FingerprintAuthHandler reads `data.get("fingerprintData")`. The field name mismatch means the handler always receives `null` and returns "Fingerprint data is required". Fingerprint authentication via the auth session flow is completely broken.

This is because:
- MultiStepAuthFlow line 390: `onSubmit={(data) => handleStepSubmit({ assertion: data })}`
- FingerprintAuthHandler line 53: `String fingerprintData = (String) data.get("fingerprintData");`

---

### 3.8 HARDWARE_KEY

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ assertion: btoa(JSON.stringify({credentialId, authenticatorData, clientDataJSON, signature})) }` | BE-MFA: `data.get("assertion")`, Base64 decode, parse JSON | MATCH |
| D2 | Same as D1 | Same | MATCH |
| D3 | `{ assertion: btoa(JSON.stringify({...})) }` | BE-Session HardwareKeyAuthHandler: reads `data.get("credentialId")`, `data.get("authenticatorData")`, `data.get("clientDataJSON")`, `data.get("signature")` as separate top-level fields | **BUG B5** |

**BUG B5 (CRITICAL)**: D3 sends `{ assertion: "<base64 JSON>" }` but HardwareKeyAuthHandler reads individual fields (`credentialId`, `authenticatorData`, `clientDataJSON`, `signature`) directly from `data`. It does NOT unwrap the base64 JSON. All four fields will be `null`, and the handler returns "Credential ID is required".

The MFA path (AuthController) handles this by base64-decoding `assertion` and parsing the JSON. But HardwareKeyAuthHandler has no such logic -- it expects the fields to be top-level in the data map.

---

### 3.9 QR_CODE

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ token }` | BE-MFA: `data.get("token")` | MATCH |
| D2 | `{ token }` | Same | MATCH |
| D3 | `{ token }` | BE-Session QrCodeAuthHandler: `data.get("qrToken")` | **BUG B6** |

**BUG B6**: D3 sends `{ token: "..." }` but QrCodeAuthHandler reads `data.get("qrToken")`. Field name mismatch. QR code authentication via the session path always fails with "QR token is required".

MultiStepAuthFlow line 355: `onSubmit={(token) => handleStepSubmit({ token })}`
QrCodeAuthHandler line 29: `String qrToken = (String) data.get("qrToken");`

---

### 3.10 NFC_DOCUMENT

| Path | Frontend sends | Backend expects | Match? |
|------|---------------|-----------------|--------|
| D1 | `{ nfcData: serialNumber }` | BE-MFA: `data.get("nfcData")` | MATCH |
| D2 | `{ nfcData: serialNumber }` | Same | MATCH |
| D3 | NfcStep renders **without onSubmit** -- `<NfcStep loading={loading} error={error} />` | BE-Session NfcDocumentAuthHandler: `data.get("nfcData")` | **BUG B7** |

**BUG B7**: In MultiStepAuthFlow (line 431), NfcStep is rendered without the `onSubmit` prop:
```tsx
case 'NFC_DOCUMENT':
    return <NfcStep loading={loading} error={error} />
```
The NfcStep component checks `if (onSubmit) { onSubmit(serialNumber) }` so even if NFC scan succeeds, the result is never sent to the backend. NFC via session path is dead code.

---

## 4. Encoding Audit

### Base64 vs Base64url

| Component | Encoding | Notes |
|-----------|----------|-------|
| FingerprintStep.onSubmit | `btoa(JSON.stringify({...}))` where inner values use `arrayBufferToBase64()` (standard base64) | Standard base64 for the outer envelope and inner fields |
| HardwareKeyStep.onSubmit | Same as FingerprintStep | Same |
| AuthController (MFA) | `Base64.getDecoder().decode(assertionRaw)` -- standard base64 | MATCH with frontend |
| FingerprintAuthHandler (Session) | `Base64.getDecoder().decode(fingerprintData)` -- standard base64 | Would match IF the field name were correct |
| webauthn-utils.ts `arrayBufferToBase64()` | Standard base64 (NOT base64url) | Used for authenticatorData, clientDataJSON, signature |
| webauthn-utils.ts `bytesToBase64url()` | Base64url (no padding, `-_` instead of `+/`) | Used for credential IDs in allowCredentials |
| webauthn-utils.ts `base64urlToBytes()` | Decodes base64url | Used to decode server-provided allowCredentials |
| Challenge from server | Standard base64 from `webAuthnService.generateChallenge()` | Frontend decodes via `decodeChallengeToBytes()` using `atob()` (standard base64) -- MATCH |

**Verdict**: Base64 encoding is consistent within each path. No encoding mismatch bugs. All WebAuthn assertion data uses standard base64, and the backend `Base64.getDecoder()` handles standard base64.

### Face image encoding

| Frontend | Backend (MFA) | Backend (Session) |
|----------|--------------|-------------------|
| `canvas.toDataURL('image/jpeg', 0.85)` returns `data:image/jpeg;base64,<data>` | Strips prefix: `image.substring(image.indexOf(",") + 1)` then `Base64.getDecoder().decode()` | `Base64.getDecoder().decode(imageBase64)` -- NO prefix stripping (**BUG B3**) |

---

## 5. WidgetAuthPage (D4) -- Separate Analysis

WidgetAuthPage uses a completely different API surface:
- Login: `POST /auth/login` (direct fetch, not via AuthRepository)
- 2FA send: `POST /auth/2fa/send` (with Bearer token)
- 2FA verify: `POST /auth/2fa/verify` (with Bearer token, sends `{ code }`)
- Method verify: `POST /auth/2fa/verify-method` (sends `{ method, data }`)
- Hardware challenge: `POST /auth/2fa/hardware-challenge`
- QR generate: `POST /auth/2fa/qr-generate`
- SMS send: `POST /auth/2fa/send-sms`

**These endpoints likely do not exist on the backend.** The actual MFA endpoints are:
- `POST /auth/mfa/step` (public, session-token based)
- `POST /auth/mfa/send-otp`
- `POST /auth/mfa/qr-generate`

**BUG B8 (MODERATE)**: WidgetAuthPage calls `/auth/2fa/send`, `/auth/2fa/verify`, `/auth/2fa/verify-method`, `/auth/2fa/hardware-challenge`, `/auth/2fa/send-sms` -- none of which appear to exist in AuthController. These are likely dead endpoints from an older 2FA design that was replaced by the N-step MFA system. The WidgetAuthPage 2FA flow is completely non-functional.

However, the WidgetAuthPage's `LoginMfaFlow` component (used in VerifyApp session=login mode) uses the correct `authRepository.verifyMfaStep()` path. So the new widget flow works; only the legacy WidgetAuthPage 2FA path is broken.

---

## 6. Bugs Found (Priority-Ordered)

### P0 -- Silent verification failures (data never reaches backend)

| Bug | Severity | File:Line | Description | Fix |
|-----|----------|-----------|-------------|-----|
| **B4** | P0/CRITICAL | `FingerprintAuthHandler.java:53` | Session path reads `fingerprintData` but frontend sends `assertion` | Either rename handler to read `assertion` OR change `MultiStepAuthFlow.tsx:390` to send `{ fingerprintData: data }` |
| **B5** | P0/CRITICAL | `HardwareKeyAuthHandler.java:38-41` | Session path reads individual fields (`credentialId`, etc.) but frontend sends single base64 `assertion` blob | Add base64 JSON unwrapping logic (like MFA path), or change frontend to send individual fields |
| **B6** | P0 | `QrCodeAuthHandler.java:29` | Session path reads `qrToken` but frontend sends `token` | Change handler to `data.get("token")` OR change `MultiStepAuthFlow.tsx:355` to `{ qrToken: token }` |

### P1 -- OTP send broken in session path

| Bug | Severity | File:Line | Description | Fix |
|-----|----------|-----------|-------------|-----|
| **B1** | P1 | `MultiStepAuthFlow.tsx:317` + `EmailOtpAuthHandler.java:33` | Frontend sends `action: 'send_otp'`, backend expects `action: 'send'` | Change frontend to `{ action: 'send' }` |
| **B2** | P1 | `MultiStepAuthFlow.tsx:331` + `SmsOtpAuthHandler.java:33` | Same mismatch for SMS | Change frontend to `{ action: 'send' }` |

### P2 -- Face image decoding crash in session path

| Bug | Severity | File:Line | Description | Fix |
|-----|----------|-----------|-------------|-----|
| **B3** | P2 | `FaceAuthHandler.java:46` | Does not strip `data:image/jpeg;base64,` prefix, causing `IllegalArgumentException` on Base64 decode | Add prefix stripping: `imageBase64.contains(",") ? imageBase64.substring(imageBase64.indexOf(",") + 1) : imageBase64` |

### P3 -- Dead code / non-functional paths

| Bug | Severity | File:Line | Description | Fix |
|-----|----------|-----------|-------------|-----|
| **B7** | P3 | `MultiStepAuthFlow.tsx:431` | NfcStep rendered without `onSubmit` in session path | Add `onSubmit={(data) => handleStepSubmit({ nfcData: data })}` |
| **B8** | P3 | `WidgetAuthPage.tsx:284-345` | Calls non-existent `/auth/2fa/*` endpoints | Migrate to `authRepository.verifyMfaStep()` or deprecate WidgetAuthPage in favor of LoginMfaFlow |

---

## 7. Data Contract Summary Table

### MFA Path (POST /auth/mfa/step) -- AuthController switch statement

| Method | Frontend field | Backend reads | Encoding | Match |
|--------|---------------|---------------|----------|-------|
| PASSWORD | N/A (handled before MFA) | N/A | N/A | N/A |
| EMAIL_OTP | `code` | `data.get("code")` | String (6 digits) | MATCH |
| SMS_OTP | `code` | `data.get("code")` | String (6 digits) | MATCH |
| TOTP | `code` | `data.get("code")` | String (6 digits) | MATCH |
| FACE | `image` | `data.get("image")` | base64 data URL (prefix stripped) | MATCH |
| VOICE | `voiceData` | `data.get("voiceData")` | base64 data URL | MATCH |
| FINGERPRINT | `assertion` | `data.get("assertion")` | base64(JSON{credentialId, authenticatorData, clientDataJSON, signature}) | MATCH |
| HARDWARE_KEY | `assertion` | `data.get("assertion")` | Same as FINGERPRINT | MATCH |
| QR_CODE | `token` | `data.get("token")` | String (UUID) | MATCH |
| NFC_DOCUMENT | `nfcData` | `data.get("nfcData")` | String (NFC serial number) | MATCH |

### Session Path (POST /auth/sessions/{id}/steps/{order}) -- AuthMethodHandler implementations

| Method | Frontend field | Backend reads | Match | Bug |
|--------|---------------|---------------|-------|-----|
| PASSWORD | `email`, `password` | `data.get("email")`, `data.get("password")` | MATCH | -- |
| EMAIL_OTP | `code` or `action: 'send_otp'` | `data.get("code")` or `data.get("action")` == `"send"` | **MISMATCH** | B1 |
| SMS_OTP | `code` or `action: 'send_otp'` | `data.get("code")` or `data.get("action")` == `"send"` | **MISMATCH** | B2 |
| TOTP | `code` | `data.get("code")` | MATCH | -- |
| FACE | `image` (data URL) | `data.get("image")` (no prefix strip) | **MISMATCH** | B3 |
| VOICE | `voiceData` | `data.get("voiceData")` | MATCH | -- |
| FINGERPRINT | `assertion` | `data.get("fingerprintData")` | **MISMATCH** | B4 |
| HARDWARE_KEY | `assertion` (base64 blob) | `data.get("credentialId")` etc. (individual fields) | **MISMATCH** | B5 |
| QR_CODE | `token` | `data.get("qrToken")` | **MISMATCH** | B6 |
| NFC_DOCUMENT | (no onSubmit prop) | `data.get("nfcData")` | **DEAD** | B7 |

---

## 8. Recommended Shared Contract

To prevent future drift, create a shared constants/types file used by both frontend and backend documentation:

### 1. Field name constants
```typescript
// shared/auth-contracts.ts
export const AUTH_DATA_FIELDS = {
    PASSWORD: { email: 'email', password: 'password' },
    EMAIL_OTP: { code: 'code', sendAction: 'send' },
    SMS_OTP: { code: 'code', sendAction: 'send' },
    TOTP: { code: 'code' },
    FACE: { image: 'image' },         // base64, data URL prefix must be stripped by backend
    VOICE: { voiceData: 'voiceData' }, // base64 data URL
    FINGERPRINT: { assertion: 'assertion' }, // base64(JSON)
    HARDWARE_KEY: { assertion: 'assertion' }, // base64(JSON)
    QR_CODE: { token: 'token' },
    NFC_DOCUMENT: { nfcData: 'nfcData' },
} as const
```

### 2. WebAuthn assertion JSON schema
```typescript
export interface WebAuthnAssertionPayload {
    credentialId: string    // base64url from navigator.credentials.get().id
    authenticatorData: string // standard base64
    clientDataJSON: string    // standard base64
    signature: string         // standard base64
}
// Sent as: btoa(JSON.stringify(payload)) in the `assertion` field
```

### 3. Action values
- OTP send action: `"send"` (NOT `"send_otp"`)
- WebAuthn challenge action: `"challenge"`

### 4. Backend normalization
All backend handlers (both MFA switch and session handlers) should:
1. Read the same field names
2. Handle the same encodings
3. Strip data URL prefixes for image data consistently
4. Unwrap base64 JSON assertion blobs consistently

### 5. OpenAPI contract
Generate OpenAPI schemas for the `data` field of each auth method and validate frontend against them in CI.

---

## 9. Root Cause Analysis

The MFA path (AuthController.verifyMfaStep) and the Session path (AuthMethodHandler implementations) were written at different times by different patterns:

- **MFA path**: Written as a single monolithic switch statement in AuthController, handling all methods inline. Field names were chosen to match what the TwoFactorDispatcher sends.
- **Session path**: Written as separate handler classes (hexagonal architecture) with independently chosen field names. Nobody verified these matched the frontend.

The TwoFactorDispatcher and LoginMfaFlow both call `authRepository.verifyMfaStep()` which hits the MFA path -- so they work.
MultiStepAuthFlow calls `authSessionRepo.completeStep()` which hits the Session path -- and 6 out of 10 methods are broken.

**The session path has never been end-to-end tested with real frontend components.**
