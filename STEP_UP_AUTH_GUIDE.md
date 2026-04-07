# Step-Up Authentication Integration Guide

**Audience**: Mobile developers integrating fingerprint step-up auth (Aysenur)
**Base URL**: `https://api.fivucsas.com`
**Last updated**: 2026-03-28

## Overview

Step-up authentication is a re-authentication mechanism for sensitive operations.
When a user attempts a high-risk action (e.g., changing password, approving a transaction),
the backend requires them to prove device possession by signing a cryptographic challenge
with a private key stored in the device's secure hardware (Android Keystore / iOS Secure Enclave).

**Flow summary:**

1. Register the device's ECDSA P-256 public key once (`/register-device`)
2. Before a sensitive operation, request a challenge nonce (`/challenge`)
3. Sign the challenge with the device private key + biometric prompt (`/verify-challenge`)
4. Receive a fresh elevated-privilege access token

All endpoints require a valid JWT Bearer token in the `Authorization` header.

## Endpoints

### 1. Register Device Public Key

**`POST /api/v1/step-up/register-device`**

Registers (or updates) the device's public key for step-up authentication. Call this once per device, typically after the user logs in for the first time on a new device.

#### Request

```json
{
  "deviceFingerprint": "android-a1b2c3d4e5f6",
  "platform": "ANDROID",
  "publicKey": "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...",
  "publicKeyAlgorithm": "EC_P256",
  "deviceName": "Aysenur's Pixel 8",
  "capabilities": ["FINGERPRINT", "STEP_UP"]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceFingerprint` | string | **Yes** | Stable device identifier (e.g., `Settings.Secure.ANDROID_ID` or a UUID you generate and persist) |
| `platform` | enum | **Yes** | One of: `ANDROID`, `IOS`, `WEB`, `DESKTOP` |
| `publicKey` | string | **Yes** | **X.509 SubjectPublicKeyInfo, DER-encoded, then Base64** (standard Java/Android format -- see Public Key Format section below) |
| `publicKeyAlgorithm` | string | No | Recommended: `"EC_P256"`. Defaults to ECDSA P-256 on the server. |
| `deviceName` | string | No | Human-readable name shown in the admin UI |
| `capabilities` | string[] | No | Tags like `["FINGERPRINT", "STEP_UP"]` for device capability tracking |

#### Response `201 Created`

```json
{
  "id": "d4e5f6a7-b8c9-4d0e-a1b2-c3d4e5f6a7b8",
  "deviceName": "Aysenur's Pixel 8",
  "platform": "ANDROID",
  "fingerprint": "android-a1b2c3d4e5f6",
  "capabilities": ["FINGERPRINT", "STEP_UP"],
  "isTrusted": false,
  "lastUsed": "2026-03-28T14:30:00Z",
  "createdAt": "2026-03-28T14:30:00Z"
}
```

---

### 2. Request Challenge Nonce

**`POST /api/v1/step-up/challenge`**

Requests a cryptographic challenge (32 random bytes, URL-safe Base64, no padding). The challenge is stored in Redis with a 5-minute TTL and can only be used once.

#### Request

```json
{
  "deviceFingerprint": "android-a1b2c3d4e5f6"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceFingerprint` | string | **Yes** | Must match a previously registered device |

#### Response `200 OK`

```json
{
  "challenge": "dGhpcyBpcyBhIDMyLWJ5dGUgcmFuZG9tIG5vbmNl",
  "expiresInSeconds": 300
}
```

---

### 3. Verify Signed Challenge

**`POST /api/v1/step-up/verify-challenge`**

Submit the original challenge and its ECDSA signature. On success, returns a fresh access token with elevated privileges.

#### Request

```json
{
  "deviceFingerprint": "android-a1b2c3d4e5f6",
  "challenge": "dGhpcyBpcyBhIDMyLWJ5dGUgcmFuZG9tIG5vbmNl",
  "signature": "MEUCIQD...base64-encoded-DER-signature..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `deviceFingerprint` | string | **Yes** | Same device that requested the challenge |
| `challenge` | string | **Yes** | The exact challenge string from the `/challenge` response (URL-safe Base64, no padding) |
| `signature` | string | **Yes** | **Standard Base64** encoding of the DER-encoded ECDSA signature (SHA256withECDSA) |

#### Response `200 OK` (success)

```json
{
  "verified": true,
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}
```

#### Response `200 OK` (signature invalid)

```json
{
  "verified": false,
  "accessToken": null,
  "expiresIn": 0
}
```

---

## Public Key Format

The server uses Java's `X509EncodedKeySpec` to parse the public key. This means:

**Format**: X.509 SubjectPublicKeyInfo, DER-encoded, then **standard Base64** (NOT URL-safe).

This is exactly what Android Keystore gives you when you call:

```kotlin
val publicKey: PublicKey = keyPair.public
val publicKeyBase64 = Base64.encodeToString(publicKey.encoded, Base64.NO_WRAP)
```

The `publicKey.encoded` property returns the X.509 SubjectPublicKeyInfo DER bytes, which is what the server expects.

**Do NOT send:**
- Raw 64-byte ECDSA coordinates (no X.509 wrapper)
- PEM format with `-----BEGIN PUBLIC KEY-----` headers
- JWK format

**Signature format**: The `signature` field must be **standard Base64** (not URL-safe) of the DER-encoded signature bytes. Android's `Signature.sign()` returns DER-encoded bytes by default.

**Challenge format**: The `challenge` field uses **URL-safe Base64 without padding** (as returned by the server). When verifying, the server decodes with `Base64.getUrlDecoder()`.

---

## Mobile Integration Guide (Android)

### Step 1: Generate an ECDSA P-256 Key Pair in Android Keystore

```kotlin
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyPairGenerator
import java.security.KeyStore

private fun generateStepUpKeyPair(): KeyPair {
    val alias = "fivucsas_step_up_key"

    val spec = KeyGenParameterSpec.Builder(
        alias,
        KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
    )
        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
        .setDigests(KeyProperties.DIGEST_SHA256)
        .setUserAuthenticationRequired(true)          // Requires biometric
        .setUserAuthenticationParameters(
            0,                                         // Every use requires auth
            KeyProperties.AUTH_BIOMETRIC_STRONG        // Fingerprint / face
        )
        .setInvalidatedByBiometricEnrollment(true)    // Re-register if fingerprint changes
        .build()

    val keyPairGenerator = KeyPairGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore"
    )
    keyPairGenerator.initialize(spec)
    return keyPairGenerator.generateKeyPair()
}
```

### Step 2: Register the Public Key with the Server

```kotlin
import android.util.Base64

suspend fun registerDevice(token: String, keyPair: KeyPair) {
    val publicKeyBase64 = Base64.encodeToString(
        keyPair.public.encoded,  // X.509 SubjectPublicKeyInfo DER
        Base64.NO_WRAP
    )

    val body = mapOf(
        "deviceFingerprint" to getDeviceFingerprint(),
        "platform" to "ANDROID",
        "publicKey" to publicKeyBase64,
        "publicKeyAlgorithm" to "EC_P256",
        "deviceName" to "${Build.MANUFACTURER} ${Build.MODEL}",
        "capabilities" to listOf("FINGERPRINT", "STEP_UP")
    )

    httpClient.post("$BASE_URL/api/v1/step-up/register-device") {
        header("Authorization", "Bearer $token")
        contentType(ContentType.Application.Json)
        setBody(body)
    }
}
```

### Step 3: Request Challenge + Sign with Biometric Prompt

```kotlin
import androidx.biometric.BiometricPrompt
import java.security.Signature

suspend fun performStepUp(
    activity: FragmentActivity,
    token: String
): String? {
    // 1. Request challenge from server
    val challengeResponse = httpClient.post("$BASE_URL/api/v1/step-up/challenge") {
        header("Authorization", "Bearer $token")
        contentType(ContentType.Application.Json)
        setBody(mapOf("deviceFingerprint" to getDeviceFingerprint()))
    }.body<StepUpChallengeResponse>()

    // 2. Prepare Signature object with AndroidKeyStore private key
    val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    val privateKey = keyStore.getKey("fivucsas_step_up_key", null) as PrivateKey

    val signature = Signature.getInstance("SHA256withECDSA")
    signature.initSign(privateKey)

    // 3. Show biometric prompt (required because key has setUserAuthenticationRequired(true))
    val cryptoObject = BiometricPrompt.CryptoObject(signature)

    val signedBytes = suspendCancellableCoroutine<ByteArray> { cont ->
        val prompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                val sig = result.cryptoObject!!.signature!!
                // Decode challenge from URL-safe Base64 (as server sends it)
                val challengeBytes = java.util.Base64.getUrlDecoder()
                    .decode(challengeResponse.challenge)
                sig.update(challengeBytes)
                cont.resume(sig.sign())
            }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                cont.resumeWithException(Exception("Biometric auth failed: $errString"))
            }
        })
        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Confirm Identity")
                .setSubtitle("Sign with your fingerprint")
                .setNegativeButtonText("Cancel")
                .build(),
            cryptoObject
        )
    }

    // 4. Send signature to server (standard Base64, NOT URL-safe)
    val signatureBase64 = Base64.encodeToString(signedBytes, Base64.NO_WRAP)

    val verifyResponse = httpClient.post("$BASE_URL/api/v1/step-up/verify-challenge") {
        header("Authorization", "Bearer $token")
        contentType(ContentType.Application.Json)
        setBody(mapOf(
            "deviceFingerprint" to getDeviceFingerprint(),
            "challenge" to challengeResponse.challenge,
            "signature" to signatureBase64
        ))
    }.body<StepUpVerifyResponse>()

    return if (verifyResponse.verified) verifyResponse.accessToken else null
}
```

### Step 4: Use the Elevated Token

```kotlin
// The accessToken from step-up verification has elevated privileges.
// Use it for the sensitive operation immediately.
httpClient.post("$BASE_URL/api/v1/users/me/change-password") {
    header("Authorization", "Bearer ${elevatedToken}")
    contentType(ContentType.Application.Json)
    setBody(mapOf("oldPassword" to old, "newPassword" to new))
}
```

---

## Error Codes

| HTTP Status | Error | When | Action |
|-------------|-------|------|--------|
| `401 Unauthorized` | Missing/invalid JWT | No `Authorization` header or expired token | Re-login the user |
| `404 Not Found` | `Device not found for fingerprint: ...` | `deviceFingerprint` not registered | Call `/register-device` first |
| `400 Bad Request` | Validation error | Missing required fields | Check request body |
| `500 Internal Server Error` | `Device not registered for step-up authentication` | Device exists but has no public key | Call `/register-device` with `publicKey` |
| `500 Internal Server Error` | `Challenge expired or not found` | Challenge TTL (5 min) exceeded or already consumed | Request a new `/challenge` |
| `500 Internal Server Error` | `Challenge mismatch` | `challenge` field does not match server's stored value | Do not modify the challenge string |
| `200 OK` with `verified: false` | Signature invalid | Wrong key, wrong algorithm, or tampered challenge | Check signing code and key alias |

---

## Sequence Diagram

```
Mobile App                          Server (/api/v1/step-up)           Redis
    |                                        |                           |
    |--- POST /register-device ------------->|                           |
    |    {deviceFingerprint, publicKey, ...}  |--- save UserDevice ----->|
    |<-- 201 {id, deviceName, ...} ----------|                           |
    |                                        |                           |
    |  ... later, sensitive operation ...     |                           |
    |                                        |                           |
    |--- POST /challenge ------------------->|                           |
    |    {deviceFingerprint}                 |--- store challenge ------>|
    |<-- 200 {challenge, expiresInSeconds} --|    (5 min TTL)            |
    |                                        |                           |
    |  [BiometricPrompt + ECDSA sign]        |                           |
    |                                        |                           |
    |--- POST /verify-challenge ------------>|--- consume challenge ---->|
    |    {deviceFingerprint,                 |    (one-time use)         |
    |     challenge, signature}              |                           |
    |                                        |--- verify ECDSA sig      |
    |<-- 200 {verified: true,                |                           |
    |         accessToken, expiresIn} -------|                           |
```

---

## Testing with curl

```bash
# Login first
TOKEN=$(curl -s -X POST https://api.fivucsas.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@fivucsas.local","password":"Test@123"}' | jq -r '.accessToken')

# Register device (use a test public key)
curl -X POST https://api.fivucsas.com/api/v1/step-up/register-device \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceFingerprint": "test-device-001",
    "platform": "ANDROID",
    "publicKey": "<your-base64-x509-public-key>",
    "publicKeyAlgorithm": "EC_P256",
    "deviceName": "Test Device",
    "capabilities": ["FINGERPRINT", "STEP_UP"]
  }'

# Request challenge
curl -X POST https://api.fivucsas.com/api/v1/step-up/challenge \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"deviceFingerprint": "test-device-001"}'

# Verify (sign the challenge with your EC private key externally)
curl -X POST https://api.fivucsas.com/api/v1/step-up/verify-challenge \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceFingerprint": "test-device-001",
    "challenge": "<challenge-from-above>",
    "signature": "<base64-ecdsa-signature>"
  }'
```

---

## FAQ

**Q: What happens if the user re-enrolls their fingerprint on the device?**
A: If you set `setInvalidatedByBiometricEnrollment(true)` (recommended), the Android Keystore key becomes permanently invalid. You must generate a new key pair and call `/register-device` again with the new public key.

**Q: Can I use RSA instead of ECDSA?**
A: No. The server currently only supports ECDSA P-256 (`SHA256withECDSA`). The `verifySignature` method in `StepUpChallengeService` uses `KeyFactory.getInstance("EC")`.

**Q: How long is the challenge valid?**
A: 5 minutes (300 seconds). After that, it expires in Redis and you must request a new one.

**Q: Can a challenge be reused?**
A: No. The challenge is deleted from Redis the moment it is consumed by `/verify-challenge` (even if verification fails).

**Q: What does the elevated access token give me?**
A: It is a standard JWT with the same claims as a normal login token. The step-up verification confirms that the user is physically present with their registered device. Your backend logic should check that the token was recently issued for sensitive operations.
