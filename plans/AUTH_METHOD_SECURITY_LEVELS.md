# Auth Method Security Levels — Design Document v3

**Status**: FINAL DRAFT v3
**Author**: Ahmet Abdullah Gultekin
**Date**: 2026-04-08
**Revision**: v3 — professional-grade rewrite (scoring formula, AAL compliance, adaptive context, lifecycle)
**Related Standards**: NIST SP 800-63B (rev 4), ISO/IEC 29115:2013, eIDAS (EU 910/2014), PSD2 SCA (EU 2015/2366), KVKK (6698)

---

## 1. Problem Statement

All 10 authentication methods in FIVUCSAS are currently treated equally in terms
of security assurance. In reality, security varies **within** each method type:

- A TC Kimlik (NFC with BAC+PACE) and an Istanbulkart (serial-only NFC) are both "NFC" but worlds apart
- A 6-char password and a 20-char passphrase are both "PASSWORD" but not equal
- A face photo check and a face + active liveness + depth are both "FACE" but different
- A YubiKey 5 and a cheap U2F dongle are both "HARDWARE_KEY" but different assurance

The system must model **variants within each method**, compute security dynamically
based on configuration, and provide **compliance-aware recommendations** to tenant
administrators building authentication flows.

### 1.1 Goals

1. **Quantify security** — assign a defensible, standards-based score to every auth action
2. **Guide tenant admins** — surface clear shield ratings + compliance badges in the flow builder
3. **Enable compliance** — map flows to NIST AAL, eIDAS LoA, PSD2 SCA, KVKK requirements
4. **Support lifecycle** — deprecate variants safely, audit score changes, plan sunset paths
5. **Future-proof** — extensible for adaptive/risk-based scoring without schema changes

---

## 2. Architecture: Method -> Variant -> Configuration -> Context

```
AUTH_METHOD (10 types)
  +-- VARIANT (specific implementation/subtype)
       +-- CONFIGURATION (tenant-configurable parameters that affect base score)
            +-- CONTEXT MODIFIERS (runtime signals: device trust, IP, geo, behavior)
                 +-- EFFECTIVE SCORE (dynamic, capped by factor-type ceiling)
```

### 2.1 Key Principles

| Principle | Description |
|-----------|-------------|
| **Score = variant base + config bonuses + context modifiers** | Three layers, each independently adjustable |
| **Factor-type ceiling** | No amount of configuration can exceed the inherent ceiling of a factor type |
| **All scores 1-5** | Uniform scale everywhere (base, config, effective, flow) |
| **Tenants configure, not create** | Variants are system-defined; tenants choose variant + tweak config params |
| **Score changes are audited** | Every config change that alters a computed score is logged |

### 2.2 Example

```
NFC_DOCUMENT (method)
  +-- NFC_PASSPORT (variant)     -> BAC + Active Auth     -> shields: 5
  +-- NFC_TCKN (variant)         -> BAC + PACE            -> shields: 5
  +-- NFC_DESFIRE_EV2 (variant)  -> AES-128 mutual auth   -> shields: 3
  +-- NFC_STUDENT_CARD (variant) -> MIFARE Classic (weak)  -> shields: 1
  +-- NFC_ISTANBULKART (variant) -> Serial number only     -> shields: 1
```

---

## 3. Complete Variant Classification

### 3.1 PASSWORD

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| WEAK_PASSWORD | No policy enforcement, any length | 1 | 2 | Brute force in seconds |
| BASIC_PASSWORD | 8+ chars, complexity rules | 2 | 3 | Dictionary attacks |
| STRONG_PASSWORD | 12+ chars, breach detection (HaveIBeenPwned), bcrypt cost 12+ | 3 | 4 | Targeted attacks only |
| PASSPHRASE | 20+ chars, entropy-based validation | 4 | 4 | Very resistant |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `minLength` | 6/8/12/16/20 | +0/+0/+1/+1/+2 | Longer = more entropy |
| `requireComplexity` | true/false | +1/+0 | Mixed case/symbols |
| `breachDetection` | true/false | +1/+0 | HaveIBeenPwned API check |
| `bcryptCost` | 10/12/14 | +0/+0/+1 | Slower hash = harder brute force |
| `maxAttempts` (lockout) | none/10/5/3 | +0/+0/+1/+1 | Rate limiting |
| `historyCheck` (prevent reuse) | 0/3/5/10 | +0/+0/+1/+1 | Credential rotation |

**Factor ceiling: 4** (knowledge factor is always phishable and replayable)

### 3.2 EMAIL_OTP

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| EMAIL_OTP_BASIC | 6-digit, 5 min expiry | 2 | 3 | Email account compromise |
| EMAIL_OTP_SECURE | 8-digit, 2 min expiry, single-use, IP binding | 3 | 3 | Targeted email attack + timing |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `codeLength` | 4/6/8 | -1/+0/+1 | Brute-force resistance |
| `expirySeconds` | 600/300/120 | +0/+0/+1 | Narrower attack window |
| `maxAttempts` | none/5/3 | +0/+0/+1 | Anti-brute-force |
| `ipBinding` | true/false | +1/+0 | Prevents remote interception use |

**Factor ceiling: 3** (possession-weak: channel can be compromised)

### 3.3 SMS_OTP

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| SMS_OTP_STANDARD | 6-digit via carrier gateway | 2 | 3 | SIM swap, SS7 interception |
| SMS_OTP_VERIFIED | + number verification API, carrier lookup | 3 | 3 | Sophisticated SIM swap only |

> **NIST SP 800-63B Warning**: SMS OTP is classified as a **"restricted authenticator"**
> per Section 5.1.3.3. The system MUST display a warning to tenant admins choosing this
> method, and SHOULD offer TOTP or push notification as alternatives.

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `codeLength` | 4/6/8 | -1/+0/+1 | Brute-force resistance |
| `expirySeconds` | 600/300/120 | +0/+0/+1 | Narrower attack window |
| `carrierVerification` | true/false | +1/+0 | Detects VoIP/prepaid numbers |

**Factor ceiling: 3** (possession-weak: SS7/SIM-swap are systemic vulnerabilities)

### 3.4 QR_CODE

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| QR_DISPLAY | Show QR, scan from mobile (cross-device) | 2 | 3 | Screen capture, QRLjacking |
| QR_SCAN | Scan QR from physical token/badge | 3 | 4 | Requires physical proximity |
| QR_MUTUAL | Bidirectional verification (both devices confirm) | 4 | 4 | Very resistant |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `expirySeconds` | 300/120/60/30 | +0/+0/+1/+1 | Shorter = harder to reuse |
| `singleUse` | true/false | +1/+0 | Prevents replay |
| `proximityCheck` | true/false | +1/+0 | BLE/NFC range verification |

**Factor ceiling: 4** (possession, can be phished unless mutual verification)

### 3.5 TOTP

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| TOTP_STANDARD | 6-digit, 30s window (RFC 6238) | 3 | 4 | Device theft, seed phishing |
| TOTP_EXTENDED | 8-digit, SHA256/512 | 4 | 4 | Same but harder brute force |
| TOTP_DEVICE_BOUND | + device attestation, seed in hardware enclave | 5 | 5 | Physical device theft only |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `digits` | 6/8 | +0/+1 | Larger keyspace |
| `period` | 30/60 | +0/+0 | UX tradeoff, no security impact |
| `algorithm` | SHA1/SHA256/SHA512 | +0/+0/+1 | Stronger HMAC |
| `deviceAttestation` | true/false | +2/+0 | Proves seed is in trusted hardware |

**Factor ceiling: 5** (possession-crypto, when device-bound)

### 3.6 VOICE

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| VOICE_TEXT_INDEPENDENT | Any speech, speaker embedding match | 3 | 4 | Recording replay, deepfake |
| VOICE_TEXT_DEPENDENT | Specific passphrase required | 4 | 4 | Targeted deepfake |
| VOICE_CHALLENGE_RESPONSE | Random phrase + anti-spoofing model | 5 | 5 | Real-time deepfake only |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `antiSpoofing` | none/basic/advanced | +0/+1/+2 | Detects synthetic speech |
| `minDuration` | 1s/3s/5s | +0/+0/+1 | More audio = better match confidence |
| `matchThreshold` | 0.3/0.5/0.7 | +0/+0/+1 | Stricter matching |
| `challengeResponse` | true/false | +2/+0 | Prevents replay attacks |

**Factor ceiling: 5** (inherence, with proper liveness/anti-spoofing)

### 3.7 FACE

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| FACE_PHOTO | Static photo comparison, no liveness | 2 | 2 | Printed photo, screen replay |
| FACE_PASSIVE_LIVENESS | + passive liveness (texture/frequency analysis) | 4 | 4 | High-quality deepfake |
| FACE_ACTIVE_LIVENESS | + active liveness (head turn, blink, smile) | 5 | 5 | Real-time deepfake only |
| FACE_3D_DEPTH | + depth camera (IR/structured light) | 5 | 5 | Very sophisticated attack only |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `livenessMode` | none/passive/active | +0/+2/+3 | Primary anti-spoofing control |
| `depthCheck` | true/false | +1/+0 | Hardware-based depth verification |
| `matchThreshold` | 0.4/0.6/0.8 | +0/+0/+1 | Stricter = fewer false accepts |
| `multiAngle` | true/false | +1/+0 | Multiple angles = harder to spoof |
| `antiSpoofModel` | none/blazeface/mediapipe | +0/+1/+2 | ML-based presentation attack detection |

**Factor ceiling: 5** (inherence, not phishing-resistant since user still navigates to URL)

> **Note on AAL**: Face verification alone does NOT qualify for AAL3 per NIST SP 800-63B
> because it lacks verifier impersonation resistance. It achieves AAL2 at best.
> Combined with a phishing-resistant factor (WebAuthn), the flow can reach AAL3.

### 3.8 FINGERPRINT (WebAuthn Platform)

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| PLATFORM_BASIC | Phone/laptop biometric, no attestation | 4 | 4 | Device theft + biometric spoof |
| PLATFORM_ATTESTED | + attestation certificate verified | 5 | 5 | Same, with authenticator provenance |
| CROSS_PLATFORM | External USB fingerprint reader | 4 | 4 | Physical access to reader |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `attestation` | none/indirect/direct | +0/+1/+2 | Proves authenticator identity |
| `userVerification` | discouraged/preferred/required | -1/+0/+1 | Enforces biometric/PIN on device |
| `authenticatorAttachment` | any/platform/cross-platform | +0/+0/+0 | UX preference, not security |

**Factor ceiling: 5** (inherence + possession via WebAuthn, phishing-resistant)

### 3.9 HARDWARE_KEY (WebAuthn Roaming)

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| U2F_BASIC | Basic U2F dongle, no user verification | 4 | 4 | Physical theft |
| FIDO2_STANDARD | FIDO2 key with PIN (e.g., YubiKey 5) | 5 | 5 | Physical theft + PIN guess |
| FIDO2_BIOMETRIC | FIDO2 + on-key fingerprint (e.g., YubiKey Bio) | 5 | 5 | Physical theft + biometric |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `attestation` | none/indirect/direct | +0/+1/+2 | Proves key provenance |
| `residentKey` | discouraged/preferred/required | +0/+0/+1 | Discoverable credentials |
| `userVerification` | discouraged/preferred/required | -1/+0/+1 | Enforces PIN/biometric on key |

**Factor ceiling: 5** (possession-crypto, phishing-resistant, verifier-impersonation-resistant)

> **AAL3 qualification**: Only FIDO2_STANDARD and FIDO2_BIOMETRIC qualify for NIST AAL3
> because they provide cryptographic proof of possession AND verifier impersonation
> resistance (origin-bound credentials). U2F_BASIC qualifies for AAL2 only.

### 3.10 NFC_DOCUMENT

| Variant | Description | Base Score | Max Score | Attack Surface |
|---------|-------------|-----------|-----------|----------------|
| NFC_GENERIC_NDEF | Generic NDEF tag, serial only | 1 | 1 | Trivially cloneable |
| NFC_ISTANBULKART | Transit card, DESFire serial | 1 | 1 | No crypto auth, serial only |
| NFC_STUDENT_CARD | MIFARE Classic student ID | 1 | 1 | Crypto broken (Darkside/nested attack) |
| NFC_MIFARE_ULTRALIGHT | Simple NFC tag | 1 | 1 | No security |
| NFC_DESFIRE_EV2 | DESFire EV2 with AES-128 mutual auth | 3 | 4 | Key extraction (difficult) |
| NFC_PASSPORT | ICAO 9303, BAC + Active Authentication | 5 | 5 | Government-grade crypto |
| NFC_TCKN | Turkish eID, BAC + PACE + chip auth | 5 | 5 | Government-grade crypto |
| NFC_EIDAS_CARD | EU eID card with EAC/PACE | 5 | 5 | Government-grade crypto |

**Configuration parameters:**

| Parameter | Values | Score Impact | Rationale |
|-----------|--------|-------------|-----------|
| `requireBAC` | true/false | +2/+0 | Basic Access Control — encrypted channel |
| `requirePACE` | true/false | +1/+0 | Password Authenticated Connection Establishment |
| `verifySOD` | true/false | +1/+0 | Document Security Object — tamper detection |
| `checkExpiry` | true/false | +1/+0 | Reject expired documents |
| `extractPhoto` | true/false | +0/+0 | Convenience feature, no security impact |

**Factor ceiling: 5** (possession-government, tamper-resistant hardware)

> **AAL clarification**: NFC document reading proves the *document* is present and
> cryptographically authentic, but does NOT prove the *user* possesses a bound
> authenticator in the NIST AAL3 sense (no verifier impersonation resistance).
> NFC government documents are classified as **AAL2 with HIGH identity assurance**
> (eIDAS HIGH), not AAL3. The distinction: AAL measures authenticator assurance,
> while eIDAS LoA measures identity proofing assurance.

---

## 4. Security Score Computation

### 4.1 Base Score Algorithm

```
effectiveScore = min(
    variant.baseScore + sum(config_bonuses) + sum(context_modifiers),
    variant.factorTypeCeiling,
    MAX_SHIELDS
)
MAX_SHIELDS = 5
```

All scores are **integers 1-5**. No score can exceed 5 or the factor-type ceiling.

### 4.2 Factor-Type Ceilings

| Factor Type | Ceiling | NIST Category | Reasoning |
|-------------|---------|---------------|-----------|
| Knowledge (password) | 4 | Memorized secret | Always phishable, always replayable |
| Possession-weak (email, SMS) | 3 | Out-of-band (restricted) | Channel can be compromised (SIM swap, email hack) |
| Possession-crypto (TOTP, WebAuthn, hardware) | 5 | Single/multi-factor crypto | Cryptographic proof of possession |
| Possession-government (NFC passport/eID) | 5 | N/A (identity proofing) | State-issued, tamper-resistant hardware |
| Inherence (face, voice, fingerprint) | 5 | Biometric | Cannot be shared (with proper anti-spoofing) |

### 4.3 Context Modifiers (Adaptive — Phase 5)

Runtime signals that adjust the effective score **at authentication time**:

| Signal | Modifier | Detection Method |
|--------|----------|-----------------|
| Trusted device (seen 3+ times) | +1 | Device fingerprint + cookie |
| New/unknown device | -1 | No prior device record |
| Impossible travel (>500km/h) | -2 | GeoIP comparison with last auth |
| Known VPN/proxy IP | -1 | IP reputation database |
| Corporate network (whitelisted IP) | +1 | Tenant IP whitelist |
| Repeated failed attempts (>3 in 10min) | -1 | Rate limiting counter |
| Time anomaly (unusual hour for user) | -1 | User behavior baseline |

Context modifiers are **not implemented in v1** but the data model supports them
via the `security_config` JSONB column. This section documents the design for Phase 5.

### 4.4 Combined Flow Score

For multi-step auth flows, the combined assurance considers both strength AND diversity:

```
weakestMandatoryScore = min(step_scores)        -- chain is as strong as weakest link
strongestScore        = max(step_scores)         -- highest individual assurance
factorTypes           = distinct_factor_types(steps)
additionalStepBonus   = min(1, (stepCount - 1) * 0.5)  -- reward multi-step

flowScore = round(
    strongestScore * 0.6          -- primary factor weight
  + weakestMandatoryScore * 0.3   -- weakest link penalty
  + additionalStepBonus           -- multi-step reward
  + factorDiversityBonus          -- multi-factor reward
)

factorDiversityBonus:
  1 factor type  -> +0
  2 factor types -> +1  (e.g., knowledge + possession)
  3 factor types -> +2  (knowledge + possession + inherence)

-- Final flow score capped at 5
flowScore = min(flowScore, 5)
```

### 4.5 Flow-to-AAL Mapping

| Flow Score | Assurance Level | NIST AAL | eIDAS LoA | PSD2 SCA |
|-----------|-----------------|----------|-----------|----------|
| 1-2 | BASIC | AAL1 | Low | NO |
| 3 | STANDARD | AAL2 | Substantial | Partial* |
| 4 | ADVANCED | AAL2+ | Substantial+ | YES |
| 5 | MAXIMUM | AAL3** | High | YES |

> *PSD2 SCA requires 2 of 3 factor types (knowledge/possession/inherence). A single
> factor at shield 3 does not satisfy SCA even though it's AAL2.
>
> **AAL3 requires at least one step to be a hardware cryptographic authenticator
> with verifier impersonation resistance (WebAuthn/FIDO2). The system validates
> this — a flow of Password(3) + Face(5) = score 5 but AAL2, NOT AAL3.

### 4.6 Weakest Link Warnings

The flow builder MUST display warnings when:

| Condition | Warning (EN) | Warning (TR) | Severity |
|-----------|-------------|--------------|----------|
| Any step score <= 1 | "Step X provides minimal security and may be easily bypassed." | "Adim X minimum guvenlik saglar ve kolayca atlanabilir." | ERROR |
| Any step score <= 2 in a flow targeting AAL2+ | "Step X is below the minimum for your target assurance level." | "Adim X hedef guvenlik seviyenizin altinda." | WARNING |
| Flow uses SMS OTP | "SMS is a restricted authenticator (NIST). Consider TOTP or push notification." | "SMS kisitli bir dogrulayicidir (NIST). TOTP veya push bildirim dusunun." | INFO |
| Flow has no phishing-resistant method | "No step provides phishing resistance. Add WebAuthn or hardware key for AAL3." | "Hicbir adim oltalama direnci saglamiyor. AAL3 icin WebAuthn ekleyin." | WARNING |
| Single factor type across all steps | "All steps use the same factor type. Add a different factor for true MFA." | "Tum adimlar ayni faktor turunde. Gercek MFA icin farkli faktor ekleyin." | WARNING |

---

## 5. Security Properties Matrix

Each variant has boolean security properties used for compliance checking:

| Property | Description | Required for |
|----------|-------------|-------------|
| `phishing_resistant` | Authenticator is bound to the origin (WebAuthn challenge-response) | AAL3 |
| `verifier_impersonation_resistant` | Authenticator validates the verifier's identity (origin check) | AAL3 |
| `replay_resistant` | Each auth produces a unique, one-time cryptographic proof | AAL2+ |
| `intent_to_authenticate` | User performs a deliberate action (tap, biometric) | PSD2 SCA |
| `requires_hardware` | Requires dedicated hardware (security key, NFC reader) | — |

### 5.1 Properties per Variant Category

| Variant Category | Phishing Resistant | Verifier Impersonation Resistant | Replay Resistant | Intent |
|-----------------|-------------------|--------------------------------|-----------------|--------|
| PASSWORD (all) | NO | NO | NO | YES |
| EMAIL_OTP (all) | NO | NO | YES (single-use) | YES |
| SMS_OTP (all) | NO | NO | YES (single-use) | YES |
| QR_CODE (all) | NO | NO | YES (if single-use) | YES |
| TOTP (standard/extended) | NO | NO | YES (time-based) | YES |
| TOTP (device-bound) | NO | NO | YES | YES |
| VOICE (all) | NO | NO | NO (embedding match) | YES |
| FACE (all) | NO | NO | NO (embedding match) | YES |
| FINGERPRINT (WebAuthn) | **YES** | **YES** | **YES** | YES |
| HARDWARE_KEY (FIDO2) | **YES** | **YES** | **YES** | YES |
| HARDWARE_KEY (U2F) | **YES** | **Partial** | **YES** | YES |
| NFC_DOCUMENT (government) | NO* | NO | YES (chip challenge) | YES |

> *NFC documents are not phishing-resistant in the WebAuthn sense — the user reads
> the card locally, but the system cannot cryptographically verify that the reading
> happened at the legitimate verifier's origin.

---

## 6. Variant Lifecycle Management

### 6.1 Lifecycle States

```
ACTIVE  -->  DEPRECATED  -->  SUNSET  -->  REMOVED
```

| State | Behavior |
|-------|----------|
| **ACTIVE** | Fully available for enrollment and authentication |
| **DEPRECATED** | New enrollments blocked; existing enrollments work; admin warning shown |
| **SUNSET** | Authentication still works but user prompted to migrate; countdown timer |
| **REMOVED** | Variant no longer accepted; enrollments auto-revoked |

### 6.2 Variant Table Fields for Lifecycle

```
deprecated         BOOLEAN NOT NULL DEFAULT FALSE
deprecated_reason  TEXT                          -- e.g., "MIFARE Classic crypto broken"
deprecated_at      TIMESTAMP
sunset_date        DATE                          -- after this date, enters SUNSET state
replacement_code   VARCHAR(50)                   -- suggested replacement variant
```

### 6.3 Migration Path Example

When MIFARE Classic is deprecated (it already should be, given Darkside attacks):

1. Set `deprecated = true`, `deprecated_reason = 'MIFARE Classic crypto broken (Darkside attack)'`
2. Set `sunset_date = 2026-07-01`, `replacement_code = 'NFC_DESFIRE_EV2'`
3. Admin dashboard shows: "NFC Student Card is deprecated. Migrate to DESFire EV2 by Jul 1."
4. After sunset: users with NFC_STUDENT_CARD enrollment see "Please re-enroll with a supported card"
5. After removal: enrollment status set to REVOKED, variant no longer in picker

---

## 7. Compliance Preset Templates

Pre-built flow templates for common regulatory requirements:

### 7.1 Template Definitions

| Template | Required Steps | Min Flow Score | Factor Types Required |
|----------|---------------|---------------|----------------------|
| **KVKK Basic** | Password (strong) | 3 | 1 (knowledge) |
| **KVKK Enhanced** | Password + Email OTP | 3 | 2 (knowledge + possession) |
| **PSD2 SCA** | Password + (TOTP or Face or Fingerprint) | 4 | 2 of 3 (knowledge + possession/inherence) |
| **eIDAS Substantial** | Password + TOTP + Face | 4 | 3 (knowledge + possession + inherence) |
| **eIDAS High** | Password + FIDO2 + NFC TCKN | 5 | 3 (knowledge + possession + government) |
| **Banking KYC** | Password + Face (active) + NFC TCKN | 5 | 3 (knowledge + inherence + government) |
| **Healthcare** | Password + FIDO2 | 4 | 2 (knowledge + crypto possession) |
| **Education** | Password + Email OTP | 3 | 2 (knowledge + possession) |

### 7.2 Template Behavior

- Admin clicks "Apply Template" in flow builder
- System creates auth flow with pre-configured steps + variants + config
- Admin can customize after applying (template is a starting point)
- Compliance validator warns if admin removes a required step

---

## 8. User-Facing Shield System

### 8.1 Shield Labels

| Shields | EN Label | TR Label | Color | Hex | Description (EN) | Description (TR) |
|---------|----------|----------|-------|-----|-------------------|-------------------|
| 1 | Basic | Temel | Gray | #9CA3AF | Minimal protection. Easy to bypass. | Asgari koruma. Kolay atlatilabilir. |
| 2 | Standard | Standart | Blue | #3B82F6 | Protects against casual access. | Siradan yetkisiz erisime karsi korur. |
| 3 | Strong | Guclu | Green | #10B981 | Resistant to common attacks. | Yaygin saldirilarin coguna dayanikli. |
| 4 | Very Strong | Cok Guclu | Purple | #8B5CF6 | Cryptographic or biometric verification. | Kriptografik veya biyometrik dogrulama. |
| 5 | Maximum | Maksimum | Gold | #F59E0B | Highest assurance. Phishing-proof. | En yuksek guvence. Oltalamaya karsi korumali. |

### 8.2 Method Card (User Sees in Enrollment/MFA Picker)

```
+-----------------------------------------------+
|  [====] Very Strong (4/5)                     |
|                                               |
|  Fingerprint                                  |
|  Unlock with your device's fingerprint        |
|  sensor. Cryptographically secure.            |
|                                               |
|  Factor: Something you are + have             |
|  Phishing-proof: Yes                          |
|  Replay-proof: Yes                            |
+-----------------------------------------------+
```

### 8.3 Flow Builder (Admin Sees)

```
+-- Auth Flow: Banking KYC ----------------------------+
|                                                      |
|  Step 1: Password (strong)    [==  ] Standard (2/5)  |
|  Step 2: Face (active)        [====] V.Strong (4/5)  |
|  Step 3: NFC TC Kimlik        [=====] Maximum (5/5)  |
|                                                      |
|  ------------------------------------------------    |
|  Flow Assurance: [=====] Maximum (5/5)               |
|  NIST: AAL2   eIDAS: HIGH   PSD2: YES   KVKK: YES   |
|  Factor Types: Knowledge + Inherence + Government    |
|                                                      |
|  ! Step 1 (Password) is the weakest link (2/5).      |
|    Consider upgrading to Passphrase or TOTP.         |
|                                                      |
|  ! No phishing-resistant step. Add WebAuthn/FIDO2    |
|    to qualify for AAL3.                              |
|                                                      |
|  [Apply Template: Banking KYC]  [Validate Flow]      |
+------------------------------------------------------+
```

> **AAL note in mockup**: Even though the flow score is 5 (Maximum), the AAL is
> displayed as AAL2 because no step provides verifier impersonation resistance.
> This is intentional — the system correctly distinguishes shield score from AAL.

---

## 9. Data Model

### 9.1 New Lookup Table: `auth_method_types`

```sql
-- V32: Auth method type lookup (replaces FK to auth_methods which is per-tenant)
CREATE TABLE auth_method_types (
    method_type VARCHAR(30) PRIMARY KEY,
    display_name_en VARCHAR(100) NOT NULL,
    display_name_tr VARCHAR(100) NOT NULL,
    factor_category VARCHAR(30) NOT NULL
        CHECK (factor_category IN ('KNOWLEDGE','POSSESSION','INHERENCE','GOVERNMENT')),
    max_shield_score SMALLINT NOT NULL CHECK (max_shield_score BETWEEN 1 AND 5),
    icon_name VARCHAR(50),
    display_order SMALLINT NOT NULL DEFAULT 0
);

INSERT INTO auth_method_types VALUES
('PASSWORD',     'Password',     'Sifre',           'KNOWLEDGE',   4, 'lock',        1),
('EMAIL_OTP',    'Email OTP',    'E-posta OTP',     'POSSESSION',  3, 'mail',        2),
('SMS_OTP',      'SMS OTP',      'SMS OTP',         'POSSESSION',  3, 'smartphone',  3),
('QR_CODE',      'QR Code',      'QR Kod',          'POSSESSION',  4, 'qr-code',     4),
('TOTP',         'Authenticator', 'Dogrulayici',    'POSSESSION',  5, 'key',         5),
('VOICE',        'Voice',        'Ses',             'INHERENCE',   5, 'mic',         6),
('FACE',         'Face',         'Yuz',             'INHERENCE',   5, 'scan-face',   7),
('FINGERPRINT',  'Fingerprint',  'Parmak Izi',      'INHERENCE',   5, 'fingerprint', 8),
('HARDWARE_KEY', 'Security Key', 'Guvenlik Anahtari','POSSESSION', 5, 'usb',         9),
('NFC_DOCUMENT', 'NFC Document', 'NFC Belge',       'GOVERNMENT',  5, 'nfc',        10);
```

### 9.2 New Table: `auth_method_variants`

```sql
CREATE TABLE auth_method_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    method_type VARCHAR(30) NOT NULL
        REFERENCES auth_method_types(method_type),
    variant_code VARCHAR(50) NOT NULL UNIQUE,
    variant_name_en VARCHAR(100) NOT NULL,
    variant_name_tr VARCHAR(100) NOT NULL,

    -- Security scoring (all 1-5, base <= max)
    base_security_score SMALLINT NOT NULL CHECK (base_security_score BETWEEN 1 AND 5),
    max_security_score SMALLINT NOT NULL CHECK (max_security_score BETWEEN 1 AND 5),
    CHECK (base_security_score <= max_security_score),

    -- Factor classification
    factor_type VARCHAR(25) NOT NULL CHECK (factor_type IN (
        'KNOWLEDGE','POSSESSION_WEAK','POSSESSION_CRYPTO',
        'POSSESSION_GOVERNMENT','INHERENCE'
    )),

    -- Standards mapping
    nist_aal VARCHAR(10) NOT NULL DEFAULT 'AAL1'
        CHECK (nist_aal IN ('AAL1','AAL2','AAL3')),
    eidas_loa VARCHAR(20) NOT NULL DEFAULT 'LOW'
        CHECK (eidas_loa IN ('LOW','SUBSTANTIAL','HIGH')),

    -- Security properties (boolean flags for compliance checks)
    phishing_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    verifier_impersonation_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    replay_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    intent_to_authenticate BOOLEAN NOT NULL DEFAULT TRUE,
    requires_hardware BOOLEAN NOT NULL DEFAULT FALSE,

    -- Lifecycle
    deprecated BOOLEAN NOT NULL DEFAULT FALSE,
    deprecated_reason TEXT,
    deprecated_at TIMESTAMP,
    sunset_date DATE,
    replacement_code VARCHAR(50) REFERENCES auth_method_variants(variant_code),

    -- Metadata
    description_en TEXT,
    description_tr TEXT,
    attack_vectors TEXT[],
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    display_order SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_variants_method ON auth_method_variants(method_type);
CREATE INDEX idx_variants_active ON auth_method_variants(deprecated) WHERE deprecated = FALSE;
```

### 9.3 New Table: `auth_method_config_params`

```sql
CREATE TABLE auth_method_config_params (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_code VARCHAR(50) NOT NULL
        REFERENCES auth_method_variants(variant_code) ON DELETE CASCADE,
    param_name VARCHAR(50) NOT NULL,
    param_type VARCHAR(20) NOT NULL
        CHECK (param_type IN ('INTEGER','BOOLEAN','ENUM')),
    default_value VARCHAR(100) NOT NULL,
    allowed_values TEXT[] NOT NULL,           -- e.g., {'6','8','12','16','20'} for minLength
    score_impact JSONB NOT NULL DEFAULT '{}',
    -- Validated format: all keys must be in allowed_values, all values must be integers
    -- Example: {"8": 0, "12": 1, "16": 2} for minLength
    -- Example: {"true": 1, "false": 0} for boolean params
    description_en TEXT,
    description_tr TEXT,
    display_order SMALLINT NOT NULL DEFAULT 0,
    UNIQUE(variant_code, param_name)
);
```

### 9.4 Extend `auth_flow_steps`

```sql
ALTER TABLE auth_flow_steps
    ADD COLUMN variant_code VARCHAR(50)
        REFERENCES auth_method_variants(variant_code),
    ADD COLUMN security_config JSONB DEFAULT '{}',
    ADD COLUMN computed_score SMALLINT CHECK (computed_score BETWEEN 1 AND 5),
    ADD COLUMN step_mode VARCHAR(10) DEFAULT 'REQUIRED'
        CHECK (step_mode IN ('REQUIRED','OPTIONAL','CHOICE'));
-- step_mode: REQUIRED = must complete, OPTIONAL = can skip, CHOICE = pick N of M
```

### 9.5 New Table: `security_score_audit_log`

```sql
-- Audit trail for score-affecting configuration changes (PSD2/eIDAS compliance)
CREATE TABLE security_score_audit_log (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    flow_id UUID REFERENCES auth_flows(id),
    step_id UUID REFERENCES auth_flow_steps(id),
    changed_by UUID NOT NULL REFERENCES users(id),
    change_type VARCHAR(30) NOT NULL
        CHECK (change_type IN ('VARIANT_CHANGED','CONFIG_CHANGED','STEP_ADDED',
               'STEP_REMOVED','FLOW_CREATED','FLOW_DELETED')),
    old_score SMALLINT,
    new_score SMALLINT,
    old_config JSONB,
    new_config JSONB,
    reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_score_audit_tenant ON security_score_audit_log(tenant_id, created_at DESC);
```

### 9.6 New Table: `compliance_templates`

```sql
CREATE TABLE compliance_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code VARCHAR(30) NOT NULL UNIQUE,
    template_name_en VARCHAR(100) NOT NULL,
    template_name_tr VARCHAR(100) NOT NULL,
    description_en TEXT,
    description_tr TEXT,
    min_flow_score SMALLINT NOT NULL CHECK (min_flow_score BETWEEN 1 AND 5),
    required_factor_types TEXT[] NOT NULL,      -- e.g., {'KNOWLEDGE','POSSESSION'}
    min_factor_type_count SMALLINT NOT NULL DEFAULT 2,
    requires_phishing_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    requires_replay_resistant BOOLEAN NOT NULL DEFAULT TRUE,
    nist_aal_target VARCHAR(10),
    eidas_loa_target VARCHAR(20),
    template_steps JSONB NOT NULL,
    -- template_steps format:
    -- [{"method_type":"PASSWORD","variant_code":"STRONG_PASSWORD","required":true},
    --  {"method_type":"TOTP","variant_code":"TOTP_STANDARD","required":true}]
    display_order SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO compliance_templates (template_code, template_name_en, template_name_tr, description_en, description_tr, min_flow_score, required_factor_types, min_factor_type_count, requires_phishing_resistant, nist_aal_target, eidas_loa_target, template_steps) VALUES
('KVKK_BASIC',      'KVKK Basic',       'KVKK Temel',       'Minimum KVKK compliance',        'Minimum KVKK uyumlulugu',            3, '{"KNOWLEDGE"}',                        1, FALSE, 'AAL1', 'LOW',         '[{"method_type":"PASSWORD","variant_code":"STRONG_PASSWORD","required":true}]'),
('PSD2_SCA',         'PSD2 SCA',         'PSD2 GKD',         'EU Payment Services Directive',   'AB Odeme Hizmetleri Direktifi',      4, '{"KNOWLEDGE","POSSESSION"}',           2, FALSE, 'AAL2', 'SUBSTANTIAL', '[{"method_type":"PASSWORD","variant_code":"STRONG_PASSWORD","required":true},{"method_type":"TOTP","variant_code":"TOTP_STANDARD","required":true}]'),
('EIDAS_SUBSTANTIAL','eIDAS Substantial', 'eIDAS Onemli',     'EU eIDAS Substantial level',     'AB eIDAS Onemli seviye',             4, '{"KNOWLEDGE","POSSESSION","INHERENCE"}',3, FALSE, 'AAL2', 'SUBSTANTIAL', '[{"method_type":"PASSWORD","variant_code":"STRONG_PASSWORD","required":true},{"method_type":"TOTP","variant_code":"TOTP_STANDARD","required":true},{"method_type":"FACE","variant_code":"FACE_ACTIVE_LIVENESS","required":true}]'),
('EIDAS_HIGH',       'eIDAS High',       'eIDAS Yuksek',      'EU eIDAS High level',            'AB eIDAS Yuksek seviye',             5, '{"KNOWLEDGE","POSSESSION"}',           2, TRUE,  'AAL3', 'HIGH',        '[{"method_type":"PASSWORD","variant_code":"STRONG_PASSWORD","required":true},{"method_type":"HARDWARE_KEY","variant_code":"FIDO2_STANDARD","required":true}]'),
('BANKING_KYC',      'Banking KYC',      'Banka KYC',         'Know Your Customer for banking', 'Bankacilik icin musteri tanima',     5, '{"KNOWLEDGE","INHERENCE","GOVERNMENT"}',3, FALSE, 'AAL2', 'HIGH',        '[{"method_type":"PASSWORD","variant_code":"STRONG_PASSWORD","required":true},{"method_type":"FACE","variant_code":"FACE_ACTIVE_LIVENESS","required":true},{"method_type":"NFC_DOCUMENT","variant_code":"NFC_TCKN","required":true}]');
```

---

## 10. Implementation Phases

### Phase 1: Data Model + Score Engine (~1 session)

| Task | Component | Priority |
|------|-----------|----------|
| V32 Flyway migration (all tables + seed data) | Backend | P0 |
| `AuthMethodType.java` JPA entity | Backend | P0 |
| `AuthMethodVariant.java` JPA entity | Backend | P0 |
| `AuthMethodConfigParam.java` JPA entity | Backend | P0 |
| `SecurityScoreCalculator.java` — compute effective score | Backend | P0 |
| `ComplianceValidator.java` — validate flow against templates | Backend | P0 |
| `AuthMethodVariantRepository.java` + `ConfigParamRepository.java` | Backend | P0 |
| Extend `AuthFlowStep.java` with variant_code, security_config, computed_score | Backend | P0 |
| `GET /api/v1/auth-methods/variants` — list all variants with security metadata | Backend | P0 |
| `GET /api/v1/auth-methods/variants/{code}` — single variant details | Backend | P1 |
| `GET /api/v1/compliance/templates` — list compliance templates | Backend | P1 |
| `POST /api/v1/compliance/validate` — validate a flow against a template | Backend | P1 |
| Unit tests: score computation (edge cases, ceiling enforcement) | Backend | P0 |
| Unit tests: compliance validation | Backend | P1 |
| Update `ARCHITECTURE.md` | Docs | P1 |

### Phase 2: UI Shield Ratings (~1 session)

| Task | Component | Priority |
|------|-----------|----------|
| `ShieldRating.tsx` — reusable 1-5 shield component with colors | Web | P0 |
| `SecurityBadge.tsx` — phishing-resistant / replay-resistant badges | Web | P1 |
| Update `MethodPickerStep.tsx` — shields next to each method in MFA picker | Web | P0 |
| Update `EnrollmentPage.tsx` — sort by score, show variant details | Web | P0 |
| `AuthMethodDto.kt` — add security fields from API | Mobile | P0 |
| `MfaFlowScreen.kt` — show shields in method picker | Mobile | P0 |
| `EnrollmentsScreen.kt` — show shield rating per enrollment | Mobile | P1 |
| Widget `MethodPickerStep.tsx` — shields in embedded picker | Widget | P0 |
| i18n: shield labels, descriptions, warnings (EN + TR) | All | P0 |
| API docs: security metadata in responses | Docs | P1 |

### Phase 3: Flow Builder Intelligence (~1 session)

| Task | Component | Priority |
|------|-----------|----------|
| `FlowSecuritySummary.tsx` — combined score, AAL, compliance badges | Web | P0 |
| `AuthFlowBuilder.tsx` — security badges per step, variant selection | Web | P0 |
| Compliance template picker — "Apply Template" button | Web | P0 |
| Weak link warnings in flow builder | Web | P0 |
| `ComplianceChecker.tsx` — real-time validation as admin edits flow | Web | P1 |
| Biometric processor: accept `livenessMode` parameter | Bio | P1 |
| Flow score recomputation on any step change (backend) | Backend | P0 |
| Score change audit logging | Backend | P0 |

### Phase 4: Analytics Dashboard (~1 session)

| Task | Component | Priority |
|------|-----------|----------|
| `SecurityOverviewWidget.tsx` — tenant admin dashboard widget | Web | P0 |
| Tenant security report — distribution of shield levels across users | Web | P1 |
| Method usage analytics — which variants are most/least used | Web | P1 |
| Deprecation manager UI — manage variant lifecycle | Web | P1 |

### Phase 5: Adaptive Context (Future)

| Task | Component | Priority |
|------|-----------|----------|
| Device trust scoring (fingerprint, cookie history) | Backend | P1 |
| IP reputation integration (threat intelligence feed) | Backend | P2 |
| Impossible travel detection (GeoIP + time delta) | Backend | P1 |
| Behavioral anomaly detection (unusual auth time/pattern) | Backend | P2 |
| Step-up authentication trigger (low context score -> require extra step) | Backend | P1 |
| Context modifier UI in flow builder | Web | P2 |

---

## 11. Pricing Model

### 11.1 Per-MAU Pricing (Monthly Active Users)

Industry standard (Auth0, Okta) is per-MAU, not per-authentication. Per-auth pricing
creates perverse incentives (tenants avoid re-authentication, weakening security).

| Tier | Max Shield | Methods Available | Price |
|------|-----------|-------------------|-------|
| **Free** | 3 (Strong) | Password + Email OTP + TOTP + QR | $0 (up to 1,000 MAU) |
| **Starter** | 4 (Very Strong) | + SMS, Voice, Face (passive), Fingerprint | $0.01/MAU |
| **Professional** | 5 (Maximum) | + Face (active), NFC, Hardware Key | $0.03/MAU |
| **Enterprise** | 5 + Adaptive | + Context modifiers, compliance templates, audit | Custom |

### 11.2 Add-on Costs

| Feature | Cost | Notes |
|---------|------|-------|
| SMS OTP delivery | ~$0.001/SMS (NetGSM) | Pass-through carrier cost |
| NFC document verification | Included | No external API needed |
| Compliance reporting | Enterprise only | Automated regulatory reports |
| Custom variant configuration | Professional+ | Modify config params per tenant |
| SLA (99.9% uptime) | Enterprise only | With dedicated support |

### 11.3 Key Difference from v2 Pricing

- **Free tier now includes TOTP** (shield 3) — competitive with Auth0/Okta free tiers
- Per-MAU instead of per-auth — aligns incentives (more auth = more secure, not more expensive)
- Enterprise tier includes adaptive scoring and compliance templates as differentiators

---

## 12. References

### Standards
- [NIST SP 800-63B rev 4](https://pages.nist.gov/800-63-4/sp800-63b.html) — Digital Identity Guidelines: Authentication and Lifecycle Management
- [eIDAS Regulation (EU 910/2014)](https://digital-strategy.ec.europa.eu/en/policies/eidas-regulation) — Electronic Identification and Trust Services
- [ISO/IEC 29115:2013](https://www.iso.org/standard/45138.html) — Entity Authentication Assurance Framework
- [PSD2 SCA (EU 2015/2366)](https://www.eba.europa.eu/regulation-and-policy/payment-services-and-electronic-money/) — Strong Customer Authentication
- [KVKK (6698)](https://www.kvkk.gov.tr/) — Turkish Personal Data Protection Law

### Protocols
- [FIDO2 / WebAuthn](https://fidoalliance.org/fido2/) — Web Authentication API
- [ICAO Doc 9303](https://www.icao.int/publications/pages/publication.aspx?docnum=9303) — Machine Readable Travel Documents
- [RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238) — TOTP: Time-Based One-Time Password
- [RFC 8176](https://datatracker.ietf.org/doc/html/rfc8176) — Authentication Method Reference Values

### Security Research
- [MIFARE Classic Vulnerabilities (Garcia et al.)](https://www.cs.bham.ac.uk/~garciafj/publications/Attack.MIFARE.pdf) — Darkside attack on MIFARE Classic
- [Presentation Attack Detection (ISO 30107)](https://www.iso.org/standard/53227.html) — Biometric PAD standards

### Competitive Analysis
- Auth0: Per-MAU pricing, adaptive MFA, 20+ social connections
- Okta: Per-user licensing, Adaptive SSO, device trust, risk engine
- Ping Identity: Per-user, DaVinci orchestration, risk signals
- **FIVUCSAS differentiation**: NFC government document verification, granular variant scoring, Turkish market focus (KVKK, NetGSM, TC Kimlik)

---

## Appendix A: Changelog

| Version | Date | Changes |
|---------|------|---------|
| v1 | 2026-04-08 | Initial draft: 10 methods, 30 variants, shield system |
| v2 | 2026-04-08 | Added data model, implementation phases, pricing |
| v3 | 2026-04-08 | Professional rewrite: fixed AAL compliance (NFC->AAL2, FACE->AAL2), added `auth_method_types` lookup table, fixed base/max score constraint (both 1-5), added `verifier_impersonation_resistant` property, added `security_score_audit_log`, added `compliance_templates` table, fixed flow score formula (weakest link + multi-step bonus), added variant lifecycle (deprecated/sunset/removed), added context modifiers design (Phase 5), switched pricing to per-MAU, added TOTP to free tier, added compliance preset templates, added security properties matrix, added weakest-link warnings |
