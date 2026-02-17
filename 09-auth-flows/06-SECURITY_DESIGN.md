# Security Design

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document defines the security architecture for the multi-modal authentication system. Each authentication method has unique attack vectors and countermeasures. The system implements defense-in-depth across all layers.

---

## 2. Threat Model

### 2.1 Threat Actors

| Actor | Capability | Motivation |
|---|---|---|
| **Opportunistic Attacker** | Stolen password, social engineering | Account takeover |
| **Sophisticated Attacker** | Photo/video spoofing, replay attacks | Identity impersonation |
| **Insider Threat** | Legitimate access, data exfiltration | Unauthorized access escalation |
| **Automated Bot** | Credential stuffing, brute force | Mass account compromise |

### 2.2 Attack Surface Summary

| Attack Vector | Affected Methods | Severity | Mitigation |
|---|---|---|---|
| Credential stuffing | Password | High | Rate limiting, account lockout, MFA |
| Phishing | Password, OTP | High | Hardware keys (phishing-resistant), user education |
| Photo spoofing | Face | Medium | Liveness detection (passive + active) |
| Video replay | Face | Medium | Active liveness challenges, timestamp binding |
| Voice replay | Voice | Medium | Challenge phrases, spectrogram analysis |
| SIM swapping | SMS OTP | Medium | SMS as secondary only, prefer TOTP |
| Token theft | QR Code, JWT | Medium | Short TTL, single-use, encryption |
| Device theft | Fingerprint, FIDO2 | Low | PIN/passcode on device, remote wipe |
| NFC cloning | NFC Document | Low | Chip authentication (BAC/PACE/EAC) |
| Session hijacking | Auth sessions | Medium | IP binding, device fingerprint, short TTL |
| MitM | All | High | TLS 1.3, certificate pinning |
| Replay attacks | All | Medium | Nonces, timestamps, idempotency keys |

---

## 3. Security Per Authentication Method

### 3.1 Password

| Control | Implementation |
|---|---|
| **Hashing** | BCrypt with work factor 12 (adaptive) |
| **Policy** | Min 8 chars, upper+lower+digit+special |
| **Brute Force** | Max 5 attempts per step, then lockout |
| **Rate Limiting** | 100 req/min per IP (Bucket4j) |
| **Credential Stuffing** | Account lockout after 10 failed logins across sessions |
| **Storage** | `users.password_hash` column, never plaintext |
| **Transmission** | HTTPS only, password in request body (not URL) |
| **Rotation** | No forced rotation (NIST 800-63B recommendation) |
| **Compromised Check** | Optional: check against HaveIBeenPwned API on enrollment |

### 3.2 Email OTP

| Control | Implementation |
|---|---|
| **Code Generation** | Cryptographically random 6-digit code (SecureRandom) |
| **Expiry** | 5 minutes (300 seconds) |
| **Single Use** | Code invalidated after successful verification |
| **Rate Limiting** | Max 5 OTP sends per hour per user |
| **Delivery** | SMTP/SendGrid with TLS |
| **Storage** | Hashed OTP + expiry timestamp in Redis (ephemeral) |
| **Attempt Limit** | Max 3 wrong codes, then new OTP required |
| **Side Channel** | Generic error message ("Invalid or expired code") |

### 3.3 SMS OTP

| Control | Implementation |
|---|---|
| **Code Generation** | Cryptographically random 6-digit code |
| **Expiry** | 3 minutes (180 seconds, shorter than email due to SIM swap risk) |
| **Single Use** | Code invalidated after use |
| **Rate Limiting** | Max 3 OTP sends per hour per user |
| **SIM Swap Mitigation** | SMS OTP should NOT be the only factor; always paired with another method |
| **Delivery** | Twilio/Vonage with TLS |
| **Storage** | Hashed OTP + expiry in Redis |
| **Recommendation** | NIST discourages SMS OTP as primary factor; use as secondary only |

### 3.4 TOTP (Authenticator App)

| Control | Implementation |
|---|---|
| **Algorithm** | HMAC-SHA1 (RFC 6238 / RFC 4226) |
| **Secret** | 160-bit random, Base32 encoded |
| **Time Step** | 30 seconds |
| **Digits** | 6 |
| **Clock Drift** | Accept 1 time step forward/backward (30s tolerance) |
| **Secret Storage** | AES-256-GCM encrypted in `user_enrollments.enrollment_data` |
| **Backup Codes** | 10 single-use, BCrypt hashed, stored in enrollment_data |
| **Replay Prevention** | Track last used time step; reject same code twice |
| **Phishing** | Partially resistant (code changes every 30s, but can be relayed in real-time) |

### 3.5 QR Code

| Control | Implementation |
|---|---|
| **Token Generation** | JWT-like signed token: `{userId, tenantId, issuedAt, nonce}` |
| **Signing** | HMAC-SHA256 with server secret key |
| **Encryption** | AES-256-GCM wrapping the signed token |
| **TTL** | 60 seconds for session QR, indefinite for badge QR |
| **Single Use** | Session QR tokens are single-use |
| **Badge QR** | Contains encrypted user reference; server validates on each scan |
| **Rotation** | Admin can rotate/revoke badge QR tokens |
| **Replay** | Nonce prevents replay of session QR codes |
| **Tampering** | Signature verification detects any modification |

### 3.6 Face Recognition

| Control | Implementation |
|---|---|
| **Liveness Detection** | **Passive**: LBP texture analysis (anti-photo, anti-video) |
|  | **Active**: Challenge-response (blink, smile, head turn) |
| **Quality Gate** | Minimum quality score 70/100 before accepting |
| **Confidence Threshold** | Configurable per tenant (default 0.6 cosine similarity) |
| **Anti-Spoofing** | Passive liveness score > 0.7 required |
| **Embedding Security** | Stored as vectors in pgvector (not reversible to face image) |
| **Image Handling** | Face images are NOT stored after embedding extraction |
| **Transport** | Images sent over HTTPS, base64 in JSON body |
| **Rate Limiting** | Max 10 verification attempts per minute per user |
| **Model** | ArcFace/Facenet with 512-dim embeddings |
| **Multi-Enrollment** | 3 images from different angles for robustness |

### 3.7 Fingerprint (FIDO2/WebAuthn)

| Control | Implementation |
|---|---|
| **Protocol** | WebAuthn Level 2 / FIDO2 CTAP2 |
| **Biometric Storage** | Template NEVER leaves device (per FIDO2 spec) |
| **Server Storage** | Only public key + credential ID |
| **Challenge-Response** | Server sends random challenge; device signs with private key |
| **Phishing Resistant** | Origin-bound credentials (rpId validation) |
| **Replay Prevention** | Sign counter increments on each use |
| **User Verification** | `userVerification: "required"` (device PIN/biometric) |
| **Attestation** | Validate authenticator identity (optional, "none" for privacy) |
| **Multiple Keys** | Users can register multiple fingerprints/devices |

### 3.8 Voice Recognition

| Control | Implementation |
|---|---|
| **Anti-Replay** | Random challenge phrases (not static passphrase) |
| **Spectrogram Analysis** | Detect synthesized/recorded audio artifacts |
| **Embedding Security** | Voiceprint stored as vector (not reversible to audio) |
| **Audio Handling** | Audio NOT stored after voiceprint extraction |
| **Minimum Duration** | 3+ seconds of speech required |
| **Noise Rejection** | SNR threshold; reject noisy environments |
| **Model** | ECAPA-TDNN with 192-dim embeddings (planned) |
| **Freshness** | Re-enrollment if voiceprint accuracy degrades over time |
| **Privacy** | Audio processed server-side, deleted immediately after |

### 3.9 NFC Document

| Control | Implementation |
|---|---|
| **Chip Authentication** | BAC (Basic Access Control) - MRZ-derived keys |
|  | PACE (Password Authenticated Connection Establishment) |
|  | Active Authentication (challenge-response with chip) |
| **Passive Authentication** | Verify digital signatures on data groups (CSCA/DS certificates) |
| **Face Matching** | Compare chip photo with live selfie (liveness + matching) |
| **Data Minimization** | Store only document hash + verification status, NOT raw data |
| **Document Expiry** | Check expiry date; reject expired documents |
| **Certificate Chain** | Validate issuing country's CA certificate chain |
| **Privacy** | No MRZ data stored; only SHA-256 hashes of identifiers |

### 3.10 Hardware Key (FIDO2/WebAuthn)

| Control | Implementation |
|---|---|
| **Protocol** | WebAuthn Level 2 / FIDO2 CTAP2 |
| **Phishing Resistant** | Strongest protection - origin-bound, no shared secrets |
| **Private Key** | Hardware-isolated, cannot be extracted |
| **Challenge-Response** | Server challenge signed by hardware key |
| **Sign Counter** | Detects cloned keys (counter mismatch) |
| **Attestation** | Verify authenticator model and firmware |
| **Transport** | USB, NFC, or BLE (per key capability) |
| **Multiple Keys** | Register 2+ keys for redundancy |
| **Recovery** | Backup key or alternative method for key loss |

---

## 4. Auth Session Security

### 4.1 Session Token Security

| Property | Value |
|---|---|
| **Session ID** | UUID v4 (128-bit random) |
| **TTL** | 10 minutes (configurable per flow) |
| **Storage** | PostgreSQL with expiry index |
| **Binding** | IP address + device fingerprint |
| **Concurrency** | Max 3 active sessions per user |
| **Cleanup** | Expired sessions purged every 5 minutes |

### 4.2 IP Binding

```
Session creation: Store client IP
Step submission: Verify IP matches session IP
IP change: Session invalidated (configurable: strict or warn)
```

### 4.3 Device Fingerprint Binding

```
Session creation: Store device fingerprint (browser/app-generated)
Step submission: Verify fingerprint matches
Mismatch: Reject step (potential session hijacking)
```

### 4.4 Idempotency

Every step submission includes:
```
X-Idempotency-Key: {sessionId}-step-{stepOrder}-attempt-{attemptNumber}
```
- Server checks Redis cache for existing result
- If found: return cached result (no re-execution)
- If not found: execute and cache result for 5 minutes

---

## 5. Cross-Device Delegation Security

### 5.1 Delegation Token

| Property | Value |
|---|---|
| **Format** | Signed JWT (HMAC-SHA256) |
| **Payload** | `{sessionId, stepOrder, userId, tenantId, iat, exp}` |
| **TTL** | 5 minutes |
| **Single Use** | Token invalidated after successful use |
| **Binding** | Bound to specific session + step |

### 5.2 QR Code Security

```
QR Payload (encrypted):
{
  "v": 1,                              // protocol version
  "s": "session-uuid",                 // session ID
  "p": 2,                              // step order
  "t": "delegation-token",             // signed JWT
  "u": "https://api.fivucsas.com",     // server URL
  "n": "random-nonce"                  // replay prevention
}

Encrypted with: AES-256-GCM using server secret
```

### 5.3 WebSocket Security

```
Connection: wss:// (TLS required)
Authentication: delegation token as query param or first message
Origin validation: Only allow known origins
Rate limiting: Max 10 messages per second per connection
Heartbeat: Ping/pong every 30 seconds
Timeout: Auto-disconnect after 10 minutes
```

---

## 6. JWT Token Security (Post-Authentication)

### 6.1 Access Token Claims

```json
{
  "sub": "user@example.com",
  "tenant_id": "uuid",
  "user_id": "uuid",
  "roles": ["ADMIN"],
  "permissions": ["user:read", "biometric:enroll"],
  "auth_methods": ["PASSWORD", "FACE"],
  "auth_level": 3,
  "auth_session_id": "uuid",
  "iat": 1739782200,
  "exp": 1739868600
}
```

### 6.2 Auth Level in Token

The `auth_level` claim enables downstream services to enforce minimum security levels:

```
Level 1: Single basic method       → Read-only access
Level 2: Basic + Standard          → Standard operations
Level 3: Basic + Premium           → Sensitive operations
Level 4: Multi-biometric           → Administrative operations
Level 5: Three-factor              → Critical operations (delete, configure)
```

Resources can require minimum auth levels:
```java
@PreAuthorize("hasAuthLevel(3)")
public void deleteTenant(UUID tenantId) { ... }
```

---

## 7. Data Protection

### 7.1 Encryption at Rest

| Data | Encryption | Key Management |
|---|---|---|
| Passwords | BCrypt hash (irreversible) | N/A |
| TOTP secrets | AES-256-GCM | Server encryption key (env var) |
| QR tokens | AES-256-GCM | Server encryption key |
| Face embeddings | pgvector storage (not encrypted*) | Database-level encryption |
| Voice embeddings | pgvector storage | Database-level encryption |
| NFC document data | SHA-256 hashes only | N/A (hashes are one-way) |
| FIDO2 public keys | Stored plaintext (public data) | N/A |
| Delegation tokens | JWT signed (not encrypted) | HMAC key (env var) |

*Face/voice embeddings are mathematical vectors that cannot be reversed to reconstruct the original biometric image. However, they are still sensitive and should be protected by database-level encryption (PostgreSQL TDE or disk encryption).

### 7.2 Encryption in Transit

| Channel | Protocol | Notes |
|---|---|---|
| API requests | HTTPS (TLS 1.2+) | Certificate from Let's Encrypt |
| WebSocket | WSS (TLS) | Same certificate |
| Biometric processor | HTTPS (internal) | Mutual TLS optional |
| Email delivery | TLS (SMTP STARTTLS) | Via SendGrid/SES |
| SMS delivery | TLS | Via Twilio/Vonage API |

### 7.3 Data Retention

| Data Type | Retention | Deletion Method |
|---|---|---|
| Auth sessions (active) | 10 minutes (TTL) | Auto-expire + cleanup job |
| Auth sessions (completed) | 24 hours | Scheduled deletion |
| Audit logs | Indefinite | Regulatory requirement |
| Face images | 0 seconds (not stored) | Deleted after embedding extraction |
| Voice audio | 0 seconds (not stored) | Deleted after voiceprint extraction |
| OTP codes | 5 minutes | Redis TTL auto-expiry |
| Delegation tokens | 5 minutes | Redis TTL + single-use invalidation |

---

## 8. Rate Limiting

### 8.1 Global Rate Limits

| Resource | Limit | Window | Action on Exceed |
|---|---|---|---|
| API requests (per IP) | 100 | 1 minute | HTTP 429 |
| Auth session creation | 10 | 1 minute per IP | HTTP 429 |
| Step submission | 5 | 30 seconds per session | HTTP 429 |
| OTP send (email) | 5 | 1 hour per user | HTTP 429 |
| OTP send (SMS) | 3 | 1 hour per user | HTTP 429 |
| Face verification | 10 | 1 minute per user | HTTP 429 |
| Delegation requests | 3 | 5 minutes per session | HTTP 429 |
| Device registration | 5 | 1 hour per user | HTTP 429 |

### 8.2 Account Lockout

```
Failed login attempts: 10 within 30 minutes
  → Account locked for 15 minutes
  → Audit log: ACCOUNT_LOCKED
  → Email notification to user
  → Admin can manually unlock

Failed biometric attempts: 5 within 10 minutes
  → Biometric method temporarily disabled for user
  → Fallback to alternative method
  → Audit log: BIOMETRIC_LOCKOUT
```

---

## 9. Audit and Compliance

### 9.1 Security Events Logged

| Event | Severity | Data Captured |
|---|---|---|
| Login success | INFO | userId, methods, authLevel, IP, device |
| Login failure | WARN | email, failedMethod, IP, device |
| Account lockout | HIGH | userId, failedAttempts, IP |
| Enrollment created | INFO | userId, method, device |
| Enrollment revoked | WARN | userId, method, revokedBy |
| Delegation used | INFO | sessionId, primaryDevice, companionDevice |
| Session expired | INFO | sessionId, lastStep |
| Rate limit hit | WARN | IP, endpoint, userId |
| Spoofing detected | HIGH | userId, method, confidence |
| Certificate error | HIGH | documentId, errorType |

### 9.2 Compliance Considerations

| Regulation | Requirement | Implementation |
|---|---|---|
| **GDPR** | Data minimization | No face/voice images stored; only embeddings |
| **GDPR** | Right to erasure | Delete all enrollments on user request |
| **GDPR** | Consent | Explicit consent before biometric enrollment |
| **KVKK** (Turkish) | Same as GDPR | Same implementation |
| **FIDO Alliance** | Biometric on-device | Fingerprint template never leaves device |

---

## 10. Security Checklist for Implementation

- [ ] All endpoints require HTTPS
- [ ] JWT secrets from environment variables (never hardcoded)
- [ ] BCrypt work factor >= 12
- [ ] TOTP secrets encrypted with AES-256-GCM
- [ ] Face images deleted after embedding extraction
- [ ] Voice audio deleted after voiceprint extraction
- [ ] Delegation tokens are single-use and short-lived
- [ ] WebSocket connections validate authentication
- [ ] Rate limiting on all auth-related endpoints
- [ ] Account lockout after repeated failures
- [ ] Audit logs for all security events
- [ ] Input validation on all API inputs (Zod/Jakarta Validation)
- [ ] CORS configured for known origins only
- [ ] No sensitive data in URL parameters
- [ ] Error messages don't leak internal details
- [ ] Session cleanup runs on schedule
- [ ] Database encryption at rest enabled
- [ ] Certificate pinning in mobile apps (optional)
