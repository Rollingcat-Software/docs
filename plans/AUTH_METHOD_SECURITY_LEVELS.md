# Auth Method Security Levels — Design Document

**Status**: DRAFT
**Author**: Ahmet Abdullah Gultekin + Claude
**Date**: 2026-04-08
**Related**: NIST SP 800-63B, ISO/IEC 29115, eIDAS

---

## 1. Problem Statement

All 10 authentication methods are currently treated equally in the UI and backend.
A password and a hardware security key appear identical to users and tenant admins.
This causes:

- **Users** don't understand why they should enable biometrics over SMS
- **Tenant admins** can't make informed decisions when building auth flows
- **Pricing** can't differentiate (biometric processing costs more than password check)
- **Compliance** can't be validated (e.g., "PSD2 SCA requires AAL2+")
- **Risk assessment** is impossible without method-level metadata

## 2. Goals

1. Categorize each method by security strength (backed by standards)
2. Communicate security levels to users in plain language (no jargon)
3. Help tenant admins build appropriate auth flows for their use case
4. Enable tiered pricing based on method security/cost
5. Support compliance reporting (NIST AAL, eIDAS LoA)

## 3. Security Classification

### 3.1 Standards Mapping

Each method is classified against three frameworks:

| Framework | Levels | Description |
|-----------|--------|-------------|
| **NIST SP 800-63B** | AAL1 / AAL2 / AAL3 | US Digital Identity Guidelines |
| **eIDAS** | Low / Substantial / High | EU Electronic Identification |
| **Internal Score** | 1-5 (shields) | User-facing simplification |

### 3.2 Method Classification

| Method | Factor | Attack Vectors | Shields | NIST AAL | eIDAS | Cost to Operate |
|--------|--------|---------------|---------|----------|-------|-----------------|
| PASSWORD | Knowledge | Phishing, brute force, credential stuffing, keyloggers | ⬣ (1) | AAL1 | Low | Free |
| EMAIL_OTP | Possession (weak) | Email compromise, phishing, delay | ⬣⬣ (2) | AAL1 | Low | Free (SMTP) |
| SMS_OTP | Possession (weak) | SIM swap, SS7 interception, social engineering | ⬣⬣ (2) | AAL1* | Low | ~$0.01/SMS |
| QR_CODE | Possession | Screen capture, shoulder surfing, session fixation | ⬣⬣ (2) | AAL1 | Low | Free |
| TOTP | Possession (crypto) | Device theft, seed extraction, phishing | ⬣⬣⬣ (3) | AAL2 | Substantial | Free |
| VOICE | Inherence | Deepfake, recording replay, environmental noise | ⬣⬣⬣ (3) | AAL2 | Substantial | ~$0.005/verify |
| FACE | Inherence | Deepfake, photo attack (mitigated by liveness) | ⬣⬣⬣⬣ (4) | AAL2 | Substantial | ~$0.01/verify |
| FINGERPRINT | Inherence+Possession | Device theft + biometric spoof (very hard) | ⬣⬣⬣⬣ (4) | AAL2-3 | High | Free (WebAuthn) |
| HARDWARE_KEY | Possession (crypto) | Physical theft only (phishing-proof) | ⬣⬣⬣⬣⬣ (5) | AAL3 | High | Free (WebAuthn) |
| NFC_DOCUMENT | Possession (gov't) | Physical theft + BAC crack (near impossible) | ⬣⬣⬣⬣⬣ (5) | AAL3 | High | Free (NFC) |

*NIST SP 800-63B Section 5.1.3.3 explicitly restricts SMS OTP use

### 3.3 Shield System (User-Facing)

Instead of technical scores, users see **shield icons** (1-5):

| Shields | Label (EN) | Label (TR) | Description (EN) | Description (TR) |
|---------|-----------|-----------|-------------------|-------------------|
| ⬣ (1) | Basic | Temel | Protects against casual access | Yetkisiz girişe karşı temel koruma |
| ⬣⬣ (2) | Standard | Standart | Adds a second verification step | İkinci bir doğrulama adımı ekler |
| ⬣⬣⬣ (3) | Strong | Güçlü | Resistant to common attacks | Yaygın saldırılara karşı dayanıklı |
| ⬣⬣⬣⬣ (4) | Advanced | İleri | Biometric or cryptographic verification | Biyometrik veya kriptografik doğrulama |
| ⬣⬣⬣⬣⬣ (5) | Maximum | Maksimum | Government-grade, phishing-proof | Devlet düzeyinde, oltalamaya karşı korumalı |

### 3.4 Combined Flow Score

When a tenant builds an auth flow (e.g., Password + Face), the combined score is:
- **Sum of unique factor types** (knowledge + inherence = 2 factors)
- **Highest individual shield** determines the flow's assurance level
- **Minimum flow score** can be enforced per tenant (e.g., "Banking tenants require 3+ shields")

Example flows and their assurance:

| Flow | Shields | Combined | Use Case |
|------|---------|----------|----------|
| Password only | ⬣ | Basic (AAL1) | Internal tools, low-risk |
| Password + Email OTP | ⬣⬣ | Standard (AAL1) | Consumer apps |
| Password + TOTP | ⬣⬣⬣ | Strong (AAL2) | Business apps |
| Password + Face | ⬣⬣⬣⬣ | Advanced (AAL2) | Financial, healthcare |
| Password + Face + Hardware Key | ⬣⬣⬣⬣⬣ | Maximum (AAL3) | Government, military |

## 4. Data Model Changes

### 4.1 Database (Flyway migration V32)

```sql
ALTER TABLE auth_methods ADD COLUMN security_score SMALLINT NOT NULL DEFAULT 1;
ALTER TABLE auth_methods ADD COLUMN security_tier VARCHAR(20) NOT NULL DEFAULT 'BASIC';
ALTER TABLE auth_methods ADD COLUMN nist_aal VARCHAR(10) NOT NULL DEFAULT 'AAL1';
ALTER TABLE auth_methods ADD COLUMN eidas_loa VARCHAR(20) NOT NULL DEFAULT 'LOW';
ALTER TABLE auth_methods ADD COLUMN factor_type VARCHAR(20) NOT NULL DEFAULT 'KNOWLEDGE';
ALTER TABLE auth_methods ADD COLUMN phishing_resistant BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE auth_methods ADD COLUMN cost_per_use DECIMAL(10,4) NOT NULL DEFAULT 0.0000;
ALTER TABLE auth_methods ADD COLUMN requires_hardware BOOLEAN NOT NULL DEFAULT FALSE;

-- Seed values
UPDATE auth_methods SET security_score=1, security_tier='BASIC',    nist_aal='AAL1', eidas_loa='LOW',         factor_type='KNOWLEDGE',  phishing_resistant=FALSE WHERE method_type='PASSWORD';
UPDATE auth_methods SET security_score=2, security_tier='STANDARD', nist_aal='AAL1', eidas_loa='LOW',         factor_type='POSSESSION', phishing_resistant=FALSE WHERE method_type='EMAIL_OTP';
UPDATE auth_methods SET security_score=2, security_tier='STANDARD', nist_aal='AAL1', eidas_loa='LOW',         factor_type='POSSESSION', phishing_resistant=FALSE WHERE method_type='SMS_OTP';
UPDATE auth_methods SET security_score=2, security_tier='STANDARD', nist_aal='AAL1', eidas_loa='LOW',         factor_type='POSSESSION', phishing_resistant=FALSE WHERE method_type='QR_CODE';
UPDATE auth_methods SET security_score=3, security_tier='STRONG',   nist_aal='AAL2', eidas_loa='SUBSTANTIAL', factor_type='POSSESSION', phishing_resistant=FALSE WHERE method_type='TOTP';
UPDATE auth_methods SET security_score=3, security_tier='STRONG',   nist_aal='AAL2', eidas_loa='SUBSTANTIAL', factor_type='INHERENCE',  phishing_resistant=TRUE  WHERE method_type='VOICE';
UPDATE auth_methods SET security_score=4, security_tier='ADVANCED', nist_aal='AAL2', eidas_loa='SUBSTANTIAL', factor_type='INHERENCE',  phishing_resistant=TRUE  WHERE method_type='FACE';
UPDATE auth_methods SET security_score=4, security_tier='ADVANCED', nist_aal='AAL2', eidas_loa='HIGH',        factor_type='INHERENCE',  phishing_resistant=TRUE  WHERE method_type='FINGERPRINT';
UPDATE auth_methods SET security_score=5, security_tier='MAXIMUM',  nist_aal='AAL3', eidas_loa='HIGH',        factor_type='POSSESSION', phishing_resistant=TRUE, requires_hardware=TRUE WHERE method_type='HARDWARE_KEY';
UPDATE auth_methods SET security_score=5, security_tier='MAXIMUM',  nist_aal='AAL3', eidas_loa='HIGH',        factor_type='POSSESSION', phishing_resistant=TRUE, requires_hardware=TRUE WHERE method_type='NFC_DOCUMENT';

-- Cost per use (approximate, for pricing engine)
UPDATE auth_methods SET cost_per_use=0.0000 WHERE method_type IN ('PASSWORD','EMAIL_OTP','QR_CODE','TOTP','FINGERPRINT','HARDWARE_KEY','NFC_DOCUMENT');
UPDATE auth_methods SET cost_per_use=0.0100 WHERE method_type='SMS_OTP';
UPDATE auth_methods SET cost_per_use=0.0050 WHERE method_type='VOICE';
UPDATE auth_methods SET cost_per_use=0.0100 WHERE method_type='FACE';
```

### 4.2 Java Entity Update

```java
// In AuthMethod.java
@Column(name = "security_score")
private Integer securityScore;

@Column(name = "security_tier")
@Enumerated(EnumType.STRING)
private SecurityTier securityTier;

@Column(name = "nist_aal")
private String nistAal;

@Column(name = "factor_type")
@Enumerated(EnumType.STRING)
private FactorType factorType;

@Column(name = "phishing_resistant")
private Boolean phishingResistant;

@Column(name = "cost_per_use")
private BigDecimal costPerUse;

public enum SecurityTier {
    BASIC, STANDARD, STRONG, ADVANCED, MAXIMUM
}

public enum FactorType {
    KNOWLEDGE, POSSESSION, INHERENCE
}
```

### 4.3 API Response Enhancement

```json
// GET /api/v1/auth-methods
{
  "methods": [
    {
      "methodType": "FACE",
      "name": "Face Verification",
      "security": {
        "score": 4,
        "tier": "ADVANCED",
        "shields": 4,
        "label": "Advanced Protection",
        "description": "Biometric face verification with liveness detection",
        "nistAal": "AAL2",
        "eidasLoa": "SUBSTANTIAL",
        "factorType": "INHERENCE",
        "phishingResistant": true
      }
    }
  ]
}
```

## 5. UI Changes

### 5.1 Enrollment Page
- Each method card shows shield rating (1-5 filled shields)
- Tooltip explains: "4 shields — Advanced protection using biometric verification"
- Methods sorted by security score (highest first) or grouped by tier

### 5.2 Auth Flow Builder (Tenant Admin)
- Drag-and-drop methods show shield badges
- Flow summary shows combined assurance level
- Warning if flow is below recommended level for tenant industry:
  - Banking/Finance: minimum 3 shields (AAL2)
  - Healthcare: minimum 3 shields
  - Government: minimum 4 shields (AAL3)
  - Education: minimum 2 shields
  - General: minimum 1 shield
- Color coding: green (meets recommendation), yellow (below), red (critically low)

### 5.3 Login Page (End User)
- Method picker shows shield icons next to each option
- Brief description: "⬣⬣⬣⬣ Face — Advanced biometric protection"
- User can see why their admin chose these methods

### 5.4 Dashboard/Analytics (Tenant Admin)
- "Auth Security Overview" widget showing distribution of methods used
- Average assurance level across all users
- Users with only basic protection (action item)

## 6. Pricing Integration

### 6.1 Cost Model

| Component | Cost Driver | Approximate Cost |
|-----------|------------|-----------------|
| Password hash | CPU | ~$0.0001/auth |
| Email OTP send | SMTP | ~$0.0001/auth |
| SMS OTP send | Twilio | ~$0.01/auth |
| TOTP verify | CPU | ~$0.0001/auth |
| QR session | Redis | ~$0.0001/auth |
| Face verify | GPU/CPU + ML | ~$0.01/auth |
| Voice verify | CPU + ML | ~$0.005/auth |
| Fingerprint (WebAuthn) | CPU | ~$0.0001/auth |
| Hardware Key (WebAuthn) | CPU | ~$0.0001/auth |
| NFC Document | CPU | ~$0.0001/auth |

### 6.2 Pricing Tiers (Future)

| Tier | Methods | Shields | Target | Price |
|------|---------|---------|--------|-------|
| **Free** | Password, Email OTP | ⬣-⬣⬣ | Developers, testing | $0 |
| **Starter** | + SMS, TOTP, QR | ⬣⬣-⬣⬣⬣ | Small business | $0.01/user/mo |
| **Professional** | + Face, Voice | ⬣⬣⬣-⬣⬣⬣⬣ | Enterprise | $0.05/user/mo |
| **Enterprise** | + Fingerprint, Hardware Key, NFC | ⬣⬣⬣⬣-⬣⬣⬣⬣⬣ | Government, finance | Custom |

## 7. Implementation Phases

### Phase 1: Data Model + API (Backend, ~1 session)
1. Flyway V32 migration with security metadata
2. Update AuthMethod entity with new fields
3. Update API DTOs to include security info
4. Seed data for all 10 methods

### Phase 2: UI — Enrollment + Method Picker (~1 session)
1. Shield component (reusable, 1-5 shields with color)
2. Enrollment page: show shields per method
3. Login method picker: show shields + descriptions
4. i18n labels (EN + TR) for all tiers and descriptions

### Phase 3: Auth Flow Builder (~1 session)
1. Show security badges in flow builder drag-and-drop
2. Combined assurance level calculator
3. Industry-specific minimum recommendations
4. Compliance warnings (below AAL2 for banking, etc.)

### Phase 4: Analytics + Pricing (~1 session)
1. Dashboard security overview widget
2. Tenant admin security report
3. Cost calculation engine
4. Pricing tier enforcement (future)

## 8. i18n Strings (EN + TR)

```json
{
  "security": {
    "shields": {
      "1": { "label": "Basic", "labelTr": "Temel", "desc": "Protects against unauthorized access", "descTr": "Yetkisiz erişime karşı koruma" },
      "2": { "label": "Standard", "labelTr": "Standart", "desc": "Adds a second verification step", "descTr": "İkinci bir doğrulama adımı ekler" },
      "3": { "label": "Strong", "labelTr": "Güçlü", "desc": "Resistant to common attacks", "descTr": "Yaygın saldırılara karşı dayanıklı" },
      "4": { "label": "Advanced", "labelTr": "İleri", "desc": "Biometric or cryptographic verification", "descTr": "Biyometrik veya kriptografik doğrulama" },
      "5": { "label": "Maximum", "labelTr": "Maksimum", "desc": "Government-grade, phishing-proof security", "descTr": "Devlet düzeyinde, oltalamaya karşı korumalı" }
    },
    "factors": {
      "KNOWLEDGE": { "label": "Something you know", "labelTr": "Bildiğiniz bir şey" },
      "POSSESSION": { "label": "Something you have", "labelTr": "Sahip olduğunuz bir şey" },
      "INHERENCE": { "label": "Something you are", "labelTr": "Sizin bir parçanız" }
    },
    "flowWarning": {
      "belowRecommended": "This flow's security level is below the recommended minimum for {{industry}}",
      "belowRecommendedTr": "Bu akışın güvenlik seviyesi {{industry}} için önerilen minimumun altındadır"
    }
  }
}
```

## 9. References

- [NIST SP 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html) — Digital Identity Guidelines: Authentication and Lifecycle Management
- [eIDAS Regulation](https://digital-strategy.ec.europa.eu/en/policies/eidas-regulation) — EU Electronic Identification
- [ISO/IEC 29115](https://www.iso.org/standard/45138.html) — Entity Authentication Assurance Framework
- [FIDO Alliance](https://fidoalliance.org/) — WebAuthn/FIDO2 specifications
- [PSD2 SCA](https://www.eba.europa.eu/regulation-and-policy/payment-services-and-electronic-money/regulatory-technical-standards-on-strong-customer-authentication-and-common-and-secure-communication) — Strong Customer Authentication requirements
