# Auth Method Security Levels — Design Document v2

**Status**: DRAFT v2
**Author**: Ahmet Abdullah Gultekin + Claude
**Date**: 2026-04-08
**Related**: NIST SP 800-63B, ISO/IEC 29115, eIDAS

---

## 1. Problem Statement

All 10 authentication methods are currently treated equally. But security varies
**within** each method type — not just between them:

- A TC Kimlik (NFC) and an İstanbulkart (NFC) are both "NFC" but worlds apart
- A 6-char password and a 20-char passphrase are both "PASSWORD" but not equal
- A face photo check and a face + active liveness + depth are both "FACE" but different
- A YubiKey 5 and a cheap U2F dongle are both "HARDWARE_KEY" but different assurance

The system must model **variants within each method** and compute security
dynamically based on configuration, not just method type.

## 2. Architecture: Method → Variant → Configuration

```
AUTH_METHOD (10 types)
  └── VARIANT (specific implementation/subtype)
       └── CONFIGURATION (tenant-configurable parameters that affect security)
            └── COMPUTED SCORE (dynamic, based on variant + config)
```

### Example:
```
NFC_DOCUMENT (method)
  ├── NFC_PASSPORT (variant)     → BAC + Active Auth → shields: 5
  ├── NFC_TCKN (variant)         → BAC + PACE → shields: 5
  ├── NFC_DESFIRE (variant)      → AES crypto → shields: 3
  ├── NFC_STUDENT_CARD (variant) → MIFARE Classic (broken crypto) → shields: 1
  └── NFC_ISTANBULKART (variant) → Serial number only → shields: 1
```

## 3. Complete Variant Classification

### 3.1 PASSWORD

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| WEAK_PASSWORD | No policy enforcement, any length | 1 | ⬣ | Brute force in seconds |
| BASIC_PASSWORD | 8+ chars, complexity rules | 2 | ⬣ | Dictionary attacks |
| STRONG_PASSWORD | 12+ chars, breach detection (HaveIBeenPwned), bcrypt cost 12+ | 3 | ⬣⬣ | Targeted attacks only |
| PASSPHRASE | 20+ chars, entropy-based validation | 4 | ⬣⬣ | Very resistant |

**Configuration parameters that affect score:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `minLength` | 6/8/12/16/20 | +0/+0/+1/+1/+2 |
| `requireComplexity` | true/false | +1/+0 |
| `breachDetection` | true/false | +1/+0 |
| `bcryptCost` | 10/12/14 | +0/+0/+1 |
| `maxAttempts` (lockout) | none/10/5/3 | +0/+0/+1/+1 |
| `historyCheck` (prevent reuse) | 0/3/5/10 | +0/+0/+1/+1 |

**Computed score formula:** `base(2) + config_bonuses (0-4)` → capped at 4 shields max

### 3.2 EMAIL_OTP

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| EMAIL_OTP_BASIC | 6-digit, 5 min expiry | 2 | ⬣⬣ | Email compromise |
| EMAIL_OTP_SECURE | 8-digit, 2 min expiry, single-use, IP binding | 3 | ⬣⬣ | Targeted email attack |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `codeLength` | 4/6/8 | -1/+0/+1 |
| `expirySeconds` | 600/300/120 | +0/+0/+1 |
| `maxAttempts` | none/5/3 | +0/+0/+1 |
| `ipBinding` | true/false | +1/+0 |

### 3.3 SMS_OTP

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| SMS_OTP_STANDARD | 6-digit via Twilio | 2 | ⬣⬣ | SIM swap, SS7 |
| SMS_OTP_VERIFIED | + number verification API, carrier lookup | 3 | ⬣⬣ | Sophisticated SIM swap |

**NIST warning**: SMS OTP is a "restricted authenticator" per SP 800-63B §5.1.3.3.
System should display warning to tenant admins choosing this method.

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `codeLength` | 4/6/8 | -1/+0/+1 |
| `expirySeconds` | 600/300/120 | +0/+0/+1 |
| `carrierVerification` | true/false | +1/+0 |

### 3.4 QR_CODE

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| QR_DISPLAY | Show QR, scan from mobile (cross-device) | 2 | ⬣⬣ | Screen capture, MITM |
| QR_SCAN | Scan QR from physical token/badge | 3 | ⬣⬣ | Physical proximity required |
| QR_MUTUAL | Bidirectional verification (both devices confirm) | 4 | ⬣⬣⬣ | Very resistant |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `expirySeconds` | 300/120/60/30 | +0/+0/+1/+1 |
| `singleUse` | true/false | +1/+0 |
| `proximityCheck` | true/false | +1/+0 |

### 3.5 TOTP

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| TOTP_STANDARD | 6-digit, 30s window (RFC 6238) | 3 | ⬣⬣⬣ | Device theft, seed phishing |
| TOTP_EXTENDED | 8-digit, 60s window | 4 | ⬣⬣⬣ | Same but harder brute force |
| TOTP_DEVICE_BOUND | + device attestation, seed never leaves hardware | 5 | ⬣⬣⬣⬣ | Physical device theft only |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `digits` | 6/8 | +0/+1 |
| `period` | 30/60 | +0/+0 |
| `algorithm` | SHA1/SHA256/SHA512 | +0/+0/+1 |
| `deviceAttestation` | true/false | +2/+0 |

### 3.6 VOICE

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| VOICE_TEXT_INDEPENDENT | Any speech, speaker embedding match | 3 | ⬣⬣⬣ | Recording replay, deepfake |
| VOICE_TEXT_DEPENDENT | Specific passphrase required | 4 | ⬣⬣⬣ | Targeted deepfake |
| VOICE_CHALLENGE_RESPONSE | Random phrase + anti-spoofing | 5 | ⬣⬣⬣⬣ | Real-time deepfake only |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `antiSpoofing` | none/basic/advanced | +0/+1/+2 |
| `minDuration` | 1s/3s/5s | +0/+0/+1 |
| `matchThreshold` | 0.3/0.5/0.7 | +0/+0/+1 |
| `challengeResponse` | true/false | +2/+0 |

### 3.7 FACE

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| FACE_PHOTO | Static photo comparison, no liveness | 2 | ⬣⬣ | Printed photo, screen replay |
| FACE_PASSIVE_LIVENESS | + passive liveness (texture analysis) | 4 | ⬣⬣⬣ | High-quality deepfake |
| FACE_ACTIVE_LIVENESS | + active liveness (head turn, blink, smile) | 5 | ⬣⬣⬣⬣ | Real-time deepfake |
| FACE_3D_DEPTH | + depth camera (IR/structured light) | 6 | ⬣⬣⬣⬣⬣ | Very sophisticated attack only |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `livenessMode` | none/passive/active | +0/+2/+3 |
| `depthCheck` | true/false | +2/+0 |
| `matchThreshold` | 0.4/0.6/0.8 | +0/+0/+1 |
| `multiAngle` | true/false | +1/+0 |
| `antiSpoofModel` | none/blazeface/mediapipe | +0/+1/+2 |

### 3.8 FINGERPRINT (WebAuthn)

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| PLATFORM_BASIC | Phone fingerprint, no attestation | 4 | ⬣⬣⬣⬣ | Device theft + biometric spoof |
| PLATFORM_ATTESTED | + attestation certificate verified | 5 | ⬣⬣⬣⬣ | Same, with known authenticator |
| CROSS_PLATFORM | External reader (USB fingerprint) | 4 | ⬣⬣⬣⬣ | Physical access to reader |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `attestation` | none/indirect/direct | +0/+1/+2 |
| `userVerification` | discouraged/preferred/required | -1/+0/+1 |
| `authenticatorAttachment` | any/platform/cross-platform | +0/+0/+0 |

### 3.9 HARDWARE_KEY (WebAuthn Roaming)

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| U2F_BASIC | Basic U2F dongle, no fingerprint | 4 | ⬣⬣⬣⬣ | Physical theft |
| FIDO2_STANDARD | FIDO2 key (e.g., YubiKey 5) | 5 | ⬣⬣⬣⬣⬣ | Physical theft + PIN |
| FIDO2_BIOMETRIC | FIDO2 + fingerprint on key (e.g., YubiKey Bio) | 6 | ⬣⬣⬣⬣⬣ | Physical theft + biometric |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `attestation` | none/indirect/direct | +0/+1/+2 |
| `residentKey` | discouraged/preferred/required | +0/+0/+1 |
| `userVerification` | discouraged/preferred/required | -1/+0/+1 |

### 3.10 NFC_DOCUMENT

| Variant | Description | Base Score | Shields | Attack Surface |
|---------|-------------|-----------|---------|----------------|
| NFC_GENERIC_NDEF | Generic NDEF tag, serial only | 1 | ⬣ | Trivially cloneable |
| NFC_ISTANBULKART | Transit card, DESFire serial | 1 | ⬣ | No crypto auth, serial only |
| NFC_STUDENT_CARD | MIFARE Classic student ID | 1 | ⬣ | Crypto broken (Darkside attack) |
| NFC_MIFARE_ULTRALIGHT | Simple NFC tag | 1 | ⬣ | No security |
| NFC_DESFIRE_EV2 | DESFire EV2 with AES-128 mutual auth | 3 | ⬣⬣⬣ | Key extraction (difficult) |
| NFC_PASSPORT | ICAO 9303, BAC + Active Authentication | 5 | ⬣⬣⬣⬣⬣ | Government-grade crypto |
| NFC_TCKN | Turkish eID, BAC + PACE + chip auth | 5 | ⬣⬣⬣⬣⬣ | Government-grade crypto |
| NFC_EIDAS_CARD | EU eID card with EAC/PACE | 5 | ⬣⬣⬣⬣⬣ | Government-grade crypto |

**Configuration parameters:**

| Parameter | Values | Score Impact |
|-----------|--------|-------------|
| `requireBAC` | true/false | +2/+0 |
| `requirePACE` | true/false | +1/+0 |
| `verifySOD` | true/false | +1/+0 |
| `checkExpiry` | true/false | +1/+0 |
| `extractPhoto` | true/false | +0/+0 (convenience, not security) |

## 4. Security Score Computation

### 4.1 Algorithm

```
effectiveScore = min(variant.baseScore + sum(config_bonuses), MAX_SHIELDS)
MAX_SHIELDS = 5
```

The score is **capped at 5** (Maximum). Even a perfect password can't exceed 4
because it's still a knowledge factor (phishable).

### 4.2 Factor-Type Ceiling

Each factor type has a **maximum possible score** regardless of configuration:

| Factor Type | Max Shields | Reasoning |
|-------------|------------|-----------|
| Knowledge (password) | 4 | Always phishable, always replayable |
| Possession-weak (email, SMS) | 3 | Channel can be compromised |
| Possession-crypto (TOTP, hardware) | 5 | Cryptographic proof |
| Possession-government (NFC passport) | 5 | State-issued, tamper-resistant |
| Inherence (biometric) | 5 | Cannot be shared (with proper liveness) |

### 4.3 Combined Flow Score

For a multi-step auth flow, the combined assurance level considers:

1. **Number of distinct factor types** used (multi-factor bonus)
2. **Highest individual shield** in the flow
3. **Weakest link penalty** — if any step is shields ≤ 1, warn

```
flowScore = max(step_scores) + factorDiversityBonus
factorDiversityBonus:
  1 factor type  → +0
  2 factor types → +0 (already counted in max)
  3 factor types → +1 (knowledge + possession + inherence)

flowAssurance:
  1-2 shields → BASIC (AAL1)
  3   shields → STANDARD (AAL2)
  4   shields → ADVANCED (AAL2+)
  5   shields → MAXIMUM (AAL3)
```

## 5. User-Facing Shield System

### 5.1 Shield Labels

| Shields | EN Label | TR Label | Color | Description (EN) | Description (TR) |
|---------|----------|----------|-------|-------------------|-------------------|
| ⬣ (1) | Basic | Temel | Gray #9CA3AF | Minimal protection. Easy to bypass. | Asgari koruma. Kolay atlatılabilir. |
| ⬣⬣ (2) | Standard | Standart | Blue #3B82F6 | Protects against casual unauthorized access. | Sıradan yetkisiz erişime karşı korur. |
| ⬣⬣⬣ (3) | Strong | Güçlü | Green #10B981 | Resistant to most common attacks. | Yaygın saldırıların çoğuna dayanıklı. |
| ⬣⬣⬣⬣ (4) | Very Strong | Çok Güçlü | Purple #8B5CF6 | Cryptographic or biometric verification. | Kriptografik veya biyometrik doğrulama. |
| ⬣⬣⬣⬣⬣ (5) | Maximum | Maksimum | Gold #F59E0B | Highest assurance. Phishing-proof. | En yüksek güvence. Oltalamaya karşı korumalı. |

### 5.2 Method Cards (User Sees)

Each method in enrollment/picker shows:

```
┌─────────────────────────────────────────────┐
│  🛡️🛡️🛡️🛡️ Very Strong                      │
│                                             │
│  👆 Fingerprint                              │
│  Unlock with your device's fingerprint      │
│  sensor. Cryptographically secure.          │
│                                             │
│  Factor: Something you are + have           │
│  Phishing-proof: Yes ✓                      │
└─────────────────────────────────────────────┘
```

### 5.3 Flow Builder (Admin Sees)

```
┌─ Auth Flow: Banking KYC ─────────────────────┐
│                                               │
│  Step 1: Password          ⬣⬣ Standard       │
│  Step 2: Face (active)     ⬣⬣⬣⬣ Very Strong  │
│  Step 3: NFC TC Kimlik     ⬣⬣⬣⬣⬣ Maximum     │
│                                               │
│  ─────────────────────────────────────────    │
│  Flow Assurance: ⬣⬣⬣⬣⬣ Maximum (AAL3)       │
│  Factor Types: Knowledge + Inherence + Poss.  │
│  Compliance: PSD2 ✓  KVKK ✓  eIDAS High ✓   │
│                                               │
│  ⚠️ Step 1 (Password) is the weakest link.    │
│     Consider upgrading to Passphrase or TOTP. │
└───────────────────────────────────────────────┘
```

## 6. Data Model

### 6.1 New Table: `auth_method_variants`

```sql
-- V32: Auth method security variants
CREATE TABLE auth_method_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    method_type VARCHAR(30) NOT NULL REFERENCES auth_methods(method_type),
    variant_code VARCHAR(50) NOT NULL UNIQUE,
    variant_name VARCHAR(100) NOT NULL,
    base_security_score SMALLINT NOT NULL CHECK (base_security_score BETWEEN 1 AND 6),
    max_security_score SMALLINT NOT NULL CHECK (max_security_score BETWEEN 1 AND 5),
    factor_type VARCHAR(20) NOT NULL CHECK (factor_type IN ('KNOWLEDGE','POSSESSION_WEAK','POSSESSION_CRYPTO','POSSESSION_GOVERNMENT','INHERENCE')),
    nist_aal VARCHAR(10) NOT NULL DEFAULT 'AAL1',
    eidas_loa VARCHAR(20) NOT NULL DEFAULT 'LOW',
    phishing_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    replay_resistant BOOLEAN NOT NULL DEFAULT FALSE,
    requires_hardware BOOLEAN NOT NULL DEFAULT FALSE,
    cost_per_use DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
    description_en TEXT,
    description_tr TEXT,
    attack_vectors TEXT[],
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    display_order SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_variants_method ON auth_method_variants(method_type);
```

### 6.2 New Table: `auth_method_config_params`

```sql
-- Configuration parameters that affect security score
CREATE TABLE auth_method_config_params (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_code VARCHAR(50) NOT NULL REFERENCES auth_method_variants(variant_code),
    param_name VARCHAR(50) NOT NULL,
    param_type VARCHAR(20) NOT NULL CHECK (param_type IN ('INTEGER','BOOLEAN','ENUM')),
    default_value VARCHAR(100) NOT NULL,
    score_impact JSONB NOT NULL DEFAULT '{}',
    -- score_impact example: {"8": 0, "12": 1, "16": 2} for minLength
    -- or {"true": 1, "false": 0} for boolean params
    description_en TEXT,
    description_tr TEXT,
    UNIQUE(variant_code, param_name)
);
```

### 6.3 Extend `auth_flow_steps`

```sql
-- Add variant and config to each step in a flow
ALTER TABLE auth_flow_steps ADD COLUMN variant_code VARCHAR(50)
    REFERENCES auth_method_variants(variant_code);
ALTER TABLE auth_flow_steps ADD COLUMN security_config JSONB DEFAULT '{}';
ALTER TABLE auth_flow_steps ADD COLUMN computed_score SMALLINT;
```

### 6.4 Seed Data (abbreviated, full in migration)

```sql
-- PASSWORD variants
INSERT INTO auth_method_variants (method_type, variant_code, variant_name, base_security_score, max_security_score, factor_type, nist_aal, eidas_loa, phishing_resistant, description_en, description_tr, is_default) VALUES
('PASSWORD', 'WEAK_PASSWORD',    'Weak Password',    1, 2, 'KNOWLEDGE', 'AAL1', 'LOW', FALSE, 'No enforcement, any password accepted', 'Kural yok, her şifre kabul edilir', FALSE),
('PASSWORD', 'BASIC_PASSWORD',   'Basic Password',   2, 3, 'KNOWLEDGE', 'AAL1', 'LOW', FALSE, '8+ characters with complexity rules', '8+ karakter, karmaşıklık kuralları', TRUE),
('PASSWORD', 'STRONG_PASSWORD',  'Strong Password',  3, 4, 'KNOWLEDGE', 'AAL1', 'LOW', FALSE, '12+ chars, breach detection, high bcrypt cost', '12+ karakter, sızıntı kontrolü, yüksek bcrypt', FALSE),

-- NFC variants
('NFC_DOCUMENT', 'NFC_GENERIC_NDEF',   'Generic NFC Tag',      1, 1, 'POSSESSION_WEAK',       'AAL1', 'LOW',         FALSE, 'Serial number only, no crypto', 'Sadece seri numarası, kriptografi yok', FALSE),
('NFC_DOCUMENT', 'NFC_ISTANBULKART',   'İstanbulkart',         1, 1, 'POSSESSION_WEAK',       'AAL1', 'LOW',         FALSE, 'Transit card serial, no authentication', 'Ulaşım kartı serisi, kimlik doğrulama yok', FALSE),
('NFC_DOCUMENT', 'NFC_STUDENT_CARD',   'Student Card',         1, 1, 'POSSESSION_WEAK',       'AAL1', 'LOW',         FALSE, 'MIFARE Classic, broken crypto', 'MIFARE Classic, kırılmış kriptografi', FALSE),
('NFC_DOCUMENT', 'NFC_DESFIRE_EV2',    'DESFire EV2 Card',     3, 4, 'POSSESSION_CRYPTO',     'AAL2', 'SUBSTANTIAL', FALSE, 'AES-128 mutual authentication', 'AES-128 karşılıklı kimlik doğrulama', FALSE),
('NFC_DOCUMENT', 'NFC_PASSPORT',       'Passport (ICAO)',      5, 5, 'POSSESSION_GOVERNMENT', 'AAL3', 'HIGH',        TRUE,  'ICAO 9303, BAC + Active Authentication', 'ICAO 9303, BAC + Aktif Doğrulama', FALSE),
('NFC_DOCUMENT', 'NFC_TCKN',           'TC Kimlik Kartı',      5, 5, 'POSSESSION_GOVERNMENT', 'AAL3', 'HIGH',        TRUE,  'Turkish eID with BAC + PACE + chip authentication', 'BAC + PACE + çip doğrulamalı TC Kimlik', TRUE),

-- FACE variants
('FACE', 'FACE_PHOTO',           'Photo Match',          2, 2, 'INHERENCE', 'AAL1', 'LOW',         FALSE, 'Static photo comparison only', 'Sadece fotoğraf karşılaştırma', FALSE),
('FACE', 'FACE_PASSIVE_LIVENESS','Passive Liveness',     4, 4, 'INHERENCE', 'AAL2', 'SUBSTANTIAL', TRUE,  'Photo match + texture-based liveness', 'Fotoğraf eşleme + doku bazlı canlılık', TRUE),
('FACE', 'FACE_ACTIVE_LIVENESS', 'Active Liveness',      5, 5, 'INHERENCE', 'AAL2', 'SUBSTANTIAL', TRUE,  'Head turn, blink, smile verification', 'Baş çevirme, göz kırpma, gülümseme', FALSE),
('FACE', 'FACE_3D_DEPTH',        '3D Depth Verification',6, 5, 'INHERENCE', 'AAL3', 'HIGH',        TRUE,  'IR/depth camera + active liveness', 'IR/derinlik kamera + aktif canlılık', FALSE),

-- FINGERPRINT variants
('FINGERPRINT', 'PLATFORM_BASIC',    'Device Fingerprint',    4, 4, 'INHERENCE', 'AAL2', 'SUBSTANTIAL', TRUE, 'Phone/laptop biometric sensor', 'Telefon/laptop biyometrik sensör', TRUE),
('FINGERPRINT', 'PLATFORM_ATTESTED', 'Attested Fingerprint',  5, 5, 'INHERENCE', 'AAL3', 'HIGH',        TRUE, 'With attestation certificate verification', 'Onay sertifikası doğrulamalı', FALSE),

-- HARDWARE_KEY variants
('HARDWARE_KEY', 'U2F_BASIC',       'U2F Security Key',     4, 4, 'POSSESSION_CRYPTO', 'AAL2', 'SUBSTANTIAL', TRUE, 'Basic U2F dongle', 'Temel U2F anahtarı', FALSE),
('HARDWARE_KEY', 'FIDO2_STANDARD',  'FIDO2 Security Key',   5, 5, 'POSSESSION_CRYPTO', 'AAL3', 'HIGH',        TRUE, 'FIDO2 key with PIN (e.g., YubiKey 5)', 'PIN korumalı FIDO2 anahtarı (ör. YubiKey 5)', TRUE),
('HARDWARE_KEY', 'FIDO2_BIOMETRIC', 'Biometric FIDO2 Key',  5, 5, 'POSSESSION_CRYPTO', 'AAL3', 'HIGH',        TRUE, 'FIDO2 + on-key fingerprint (e.g., YubiKey Bio)', 'Anahtar üzerinde parmak izi (ör. YubiKey Bio)', FALSE);

-- (EMAIL_OTP, SMS_OTP, QR_CODE, TOTP, VOICE variants follow same pattern)
```

## 7. Implementation Scope — What Gets Affected

### 7.1 Backend (identity-core-api)

| File/Area | Change | Phase |
|-----------|--------|-------|
| `V32__auth_method_security.sql` | New migration: tables + seed data | 1 |
| `AuthMethodVariant.java` | New JPA entity | 1 |
| `AuthMethodConfigParam.java` | New JPA entity | 1 |
| `SecurityScoreCalculator.java` | Score computation service | 1 |
| `AuthMethodVariantRepository.java` | Spring Data repo | 1 |
| `AuthFlowStep.java` | Add `variantCode`, `securityConfig`, `computedScore` | 1 |
| `AuthMethodController.java` | Return variants + security metadata | 1 |
| `ManageAuthFlowService.java` | Validate flow security, compute combined score | 2 |
| `AuthFlowStepDto.java` | Include security info in DTOs | 1 |
| `ComplianceValidator.java` | New: check flow meets industry minimums | 2 |

### 7.2 Frontend (web-app)

| File/Area | Change | Phase |
|-----------|--------|-------|
| `ShieldRating.tsx` | New reusable component (1-5 shields with color) | 2 |
| `MethodCard.tsx` | Add shield rating, factor type badge, description | 2 |
| `MethodPickerStep.tsx` | Show shields next to each method in MFA picker | 2 |
| `EnrollmentPage.tsx` | Sort by score, show variant details | 2 |
| `AuthFlowBuilder.tsx` | Security badges per step, combined score, warnings | 3 |
| `FlowSecuritySummary.tsx` | New: combined score, compliance check, weak link alert | 3 |
| `SecurityOverviewWidget.tsx` | New: dashboard widget for tenant admin | 4 |
| `en.json` / `tr.json` | i18n strings for all labels, descriptions, warnings | 2 |

### 7.3 Mobile (client-apps)

| File/Area | Change | Phase |
|-----------|--------|-------|
| `AuthMethodDto.kt` | Add security fields from API | 2 |
| `MfaFlowScreen.kt` | Show shields in method picker | 2 |
| `EnrollmentsScreen.kt` | Show shield rating per enrollment | 2 |
| `StringResources.kt` | i18n for security labels | 2 |

### 7.4 Widget (verify-app)

| File/Area | Change | Phase |
|-----------|--------|-------|
| `MethodPickerStep.tsx` | Show shields in embedded widget picker | 2 |
| `LoginMfaFlow.tsx` | Pass security metadata to method picker | 2 |

### 7.5 Biometric Processor

| File/Area | Change | Phase |
|-----------|--------|-------|
| No changes needed | Security classification is in identity-core-api | — |
| Future: liveness mode parameter | Accept `livenessMode` param to adjust processing | 3 |

### 7.6 Documentation

| File/Area | Change | Phase |
|-----------|--------|-------|
| `docs.fivucsas.com` | API docs showing security metadata | 2 |
| Widget SDK docs | Document security fields in verify result | 2 |
| `ARCHITECTURE.md` | Update with security level architecture | 1 |

### 7.7 Database

| Table | Change | Phase |
|-------|--------|-------|
| `auth_method_variants` | NEW table | 1 |
| `auth_method_config_params` | NEW table | 1 |
| `auth_flow_steps` | ADD columns: variant_code, security_config, computed_score | 1 |
| `auth_methods` | No change (variants are separate table) | — |

## 8. Implementation Phases

### Phase 1: Data Model + API (~1 session)
- Flyway V32 migration
- JPA entities for variants and config params
- SecurityScoreCalculator service
- API endpoints return security metadata
- Unit tests for score computation

### Phase 2: UI Shields (~1 session)
- ShieldRating component (React + KMP)
- Enrollment page shows shields per method
- MFA method picker shows shields
- Widget method picker shows shields
- i18n (EN + TR)

### Phase 3: Flow Builder Intelligence (~1 session)
- Combined flow score calculator
- Compliance validator (industry minimums)
- Weak link warnings in flow builder
- Variant selection per flow step

### Phase 4: Analytics + Pricing (~1 session)
- Security overview dashboard widget
- Tenant security report
- Cost calculation engine
- Usage-based pricing foundation

## 9. Pricing Model

### 9.1 Per-Authentication Cost

| Shield Level | Cost/Auth | Examples |
|-------------|-----------|---------|
| ⬣ (1) | Free | Weak password, generic NFC |
| ⬣⬣ (2) | Free | Basic password, email OTP |
| ⬣⬣⬣ (3) | $0.001 | TOTP, DESFire, voice basic |
| ⬣⬣⬣⬣ (4) | $0.005 | Face active liveness, attested fingerprint |
| ⬣⬣⬣⬣⬣ (5) | $0.01 | NFC passport/TCKN, FIDO2, face 3D |

### 9.2 Tenant Pricing Tiers

| Tier | Max Shield Level | Methods | Monthly |
|------|-----------------|---------|---------|
| Free | ⬣⬣ (2) | Password + Email OTP | $0 |
| Starter | ⬣⬣⬣ (3) | + SMS, TOTP, QR, basic voice | $X/user |
| Professional | ⬣⬣⬣⬣ (4) | + Face (active), fingerprint | $Y/user |
| Enterprise | ⬣⬣⬣⬣⬣ (5) | + NFC TCKN/passport, FIDO2, 3D face | Custom |

## 10. References

- [NIST SP 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html) — Digital Identity Guidelines
- [eIDAS Regulation](https://digital-strategy.ec.europa.eu/en/policies/eidas-regulation) — EU eID
- [ISO/IEC 29115](https://www.iso.org/standard/45138.html) — Entity Authentication Assurance
- [FIDO Alliance](https://fidoalliance.org/) — WebAuthn/FIDO2
- [ICAO Doc 9303](https://www.icao.int/publications/pages/publication.aspx?docnum=9303) — Machine Readable Travel Documents
- [PSD2 SCA](https://www.eba.europa.eu/regulation-and-policy/payment-services-and-electronic-money/) — Strong Customer Authentication
- [MIFARE Classic Vulnerabilities](https://www.cs.bham.ac.uk/~garciafj/publications/Attack.MIFARE.pdf) — Darkside attack
