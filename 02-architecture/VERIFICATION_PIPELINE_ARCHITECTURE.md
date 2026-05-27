# FIVUCSAS Verification Pipeline Architecture

> Created: 2026-03-28 | Status: Design Document (Pre-Implementation)
> Version: 1.0 | Next Migration: V26

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Unified Flow Engine Architecture](#3-unified-flow-engine-architecture)
4. [Verification Step Types](#4-verification-step-types)
5. [Industry Templates](#5-industry-templates)
6. [Database Schema Extension](#6-database-schema-extension)
7. [API Endpoints](#7-api-endpoints)
8. [Tenant Admin UI](#8-tenant-admin-ui)
9. [User-Facing Flow](#9-user-facing-flow)
10. [Integration with Existing Systems](#10-integration-with-existing-systems)
11. [Security and Compliance](#11-security-and-compliance)
12. [Implementation Roadmap](#12-implementation-roadmap)
13. [Existing Assets We Can Reuse](#13-existing-assets-we-can-reuse)

---

## 1. Executive Summary

### The Evolution

FIVUCSAS currently operates as a **multi-tenant biometric authentication platform** with 10 auth methods, configurable auth flows, and an embeddable auth widget. The platform answers one question: *"Is this person the registered user?"*

The next step is answering a harder question: *"Is this person who they claim to be in the real world?"*

This document defines the architecture for extending FIVUCSAS into a full **Identity Verification Platform (IVP)** that handles:

- **Authentication** (existing) -- prove you are the registered user
- **Verification** (new) -- prove your real-world identity against official documents
- **Enrollment** (new) -- register biometrics with identity verification in a single flow
- **Onboarding** (new) -- full customer lifecycle: verify + enroll + configure

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Extend existing `auth_flows` table with `flow_type` | Reuse the proven flow engine, avoid parallel systems |
| New verification step types alongside existing auth methods | Clean separation -- auth steps authenticate, verification steps verify identity |
| Industry templates as pre-built flow configurations | Rapid tenant onboarding for banks, hospitals, government, schools |
| Document images encrypted at rest, time-limited retention | GDPR/KVKK compliance from day one |
| Browser-first capture (camera, NFC) via existing widget | Consistent with FIVUCSAS browser-first architecture |

### What This Enables

```
Today:
  User registers → User sets password → User logs in with face+password
  (Self-attested identity. No proof.)

Tomorrow:
  User registers → Scans TC Kimlik → NFC chip read → Face matches document →
  Liveness check → Identity VERIFIED → Biometrics enrolled with verified identity
  (Government-grade identity assurance.)
```

---

## 2. Problem Statement

### Current State

The existing FIVUCSAS enrollment flow collects biometric data (face, voice, fingerprint) from users, but all identity information is **self-attested**:

```
Current Enrollment:
  1. User types name, email, etc.          ← Self-attested, unverified
  2. User enrolls face via camera           ← Biometric captured
  3. User enrolls voice via microphone      ← Biometric captured
  4. User sets password                     ← Credential created
  5. Done — user can authenticate

  Problem: We know this face belongs to "email@example.com"
           but we DON'T know if this face belongs to "Ahmet Yilmaz, TC 12345678901"
```

### What Is Missing

| Gap | Impact |
|-----|--------|
| No document scanning | Cannot capture official ID documents (TC Kimlik, passport, ehliyet) |
| No NFC chip verification | Cannot read cryptographic data from ID card chips |
| No face-to-document matching | Cannot compare live face against document photo |
| No OCR/data extraction | Cannot parse name, TC number, DOB from documents |
| No configurable verification pipelines | Cannot offer different verification levels per tenant/industry |
| No verification status tracking | Cannot mark a user as "identity verified" with confidence scores |

### Industry Requirements

Different industries need different verification levels:

| Industry | Verification Level | Regulatory Driver |
|----------|-------------------|-------------------|
| Banking (KYC) | Full: document + NFC + face + liveness + watchlist + address | BDDK, MASAK (AML/CFT) |
| Banking (light) | Medium: document + face + liveness | Remote account opening |
| Healthcare | Medium: document + face + liveness | KVKK, patient identity |
| Education | Light: document + face | Student identity verification |
| Government (e-KYC) | Full: NFC chip + face + liveness + fingerprint | e-Devlet integration |
| Retail | Minimal: document + age check | Age-restricted sales |
| Corporate | Medium: document + face + phone | Employee onboarding |
| Travel/Border | High: NFC + face + liveness + watchlist | INTERPOL, border control |
| Fintech | Full: document + face + liveness + credit + phone | BDDK, customer onboarding |

A single hardcoded pipeline cannot serve all of these. The flow engine must be configurable per tenant, per industry, per use case.

---

## 3. Unified Flow Engine Architecture

### Extending the Existing Flow Engine

The current `auth_flows` table (V16 migration) supports `operation_type` values like `APP_LOGIN`, `DOOR_ACCESS`, `ENROLLMENT`, etc. We extend this with a new column `flow_type` that distinguishes the *purpose* of the flow:

```
                     UNIFIED FLOW ENGINE
+================================================================+
|                                                                  |
|  flow_type: AUTHENTICATION (existing)                           |
|  ┌─────────────┐   ┌──────────┐   ┌──────────────┐            |
|  │  PASSWORD    │──→│  FACE    │──→│  COMPLETED   │            |
|  │  (step 1)   │   │ (step 2) │   │              │            |
|  └─────────────┘   └──────────┘   └──────────────┘            |
|                                                                  |
|  flow_type: VERIFICATION (new)                                  |
|  ┌──────────────┐  ┌────────────┐  ┌────────────┐  ┌────────┐|
|  │ DOCUMENT_SCAN│─→│ DATA_EXTRACT│─→│ FACE_MATCH │─→│LIVENESS│|
|  │  (step 1)   │  │  (step 2)  │  │  (step 3)  │  │(step 4)│|
|  └──────────────┘  └────────────┘  └────────────┘  └────────┘|
|                                                                  |
|  flow_type: ENROLLMENT (new)                                    |
|  ┌──────────────┐  ┌────────────┐  ┌────────────┐  ┌────────┐|
|  │ DOCUMENT_SCAN│─→│ FACE_MATCH │─→│ FACE_ENROLL│─→│PASSWORD│|
|  │  (verify)   │  │  (verify)  │  │ (register) │  │(create)│|
|  └──────────────┘  └────────────┘  └────────────┘  └────────┘|
|                                                                  |
|  flow_type: ONBOARDING (new)                                    |
|  ┌──────────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐|
|  │  FULL KYC    │─→│ ENROLL   │─→│ CONFIGURE│─→│  WELCOME   │|
|  │  PIPELINE    │  │ BIOMETRICS│  │ SETTINGS │  │  COMPLETE  │|
|  └──────────────┘  └──────────┘  └──────────┘  └────────────┘|
|                                                                  |
+================================================================+
```

### Flow Type Definitions

| Flow Type | Purpose | Example | Produces |
|-----------|---------|---------|----------|
| `AUTHENTICATION` | Prove you are the registered user | Login with face + password | JWT token, session |
| `VERIFICATION` | Prove your real-world identity | Scan TC Kimlik + face match | Verification result, confidence scores |
| `ENROLLMENT` | Register biometrics with identity verification | Verify ID then enroll face | Verified biometric enrollment |
| `ONBOARDING` | Full customer lifecycle | KYC + enroll + configure | Verified, enrolled, configured user |

### Step Category Model

The `auth_flow_steps` table already references `auth_methods` for authentication steps. For verification, we add new step types to `auth_methods` under a new category `VERIFICATION`:

```
auth_methods.category:
  BASIC       → PASSWORD, EMAIL_OTP                    (existing)
  STANDARD    → SMS_OTP, TOTP, QR_CODE                (existing)
  PREMIUM     → FACE, FINGERPRINT, VOICE              (existing)
  ENTERPRISE  → NFC_DOCUMENT, HARDWARE_KEY             (existing)
  VERIFICATION → DOCUMENT_SCAN, NFC_CHIP_READ,         (new)
                 DATA_EXTRACT, FACE_MATCH,
                 LIVENESS_CHECK, ADDRESS_PROOF,
                 WATCHLIST_CHECK, AGE_VERIFICATION,
                 CREDIT_CHECK, PHONE_VERIFICATION,
                 VIDEO_INTERVIEW
```

### Session Lifecycle

A verification session follows the same lifecycle as an auth session but produces richer output:

```
                    VERIFICATION SESSION LIFECYCLE

  ┌─────────┐     ┌─────────────┐     ┌────────────┐     ┌───────────┐
  │ CREATED │────→│ IN_PROGRESS │────→│ COMPLETED  │     │  EXPIRED  │
  └─────────┘     └─────────────┘     └────────────┘     └───────────┘
       │               │                    │                   ▲
       │               │                    ▼                   │
       │               │              ┌──────────┐              │
       │               └─────────────→│  FAILED  │              │
       │                              └──────────┘              │
       └────────────────────────────────────────────────────────┘
                         (timeout)

  Each step within the session:
  PENDING → IN_PROGRESS → COMPLETED | FAILED | SKIPPED

  Step result stored in auth_session_steps.result (JSONB):
  {
    "type": "DOCUMENT_SCAN",
    "documentType": "tc_kimlik",
    "confidence": 0.97,
    "extractedData": { ... },
    "processingTimeMs": 1245
  }
```

---

## 4. Verification Step Types

### DOCUMENT_SCAN

| Field | Value |
|-------|-------|
| **Purpose** | Detect and capture an official identity document from camera |
| **Input** | Camera frame (via browser MediaDevices API or mobile camera) |
| **Output** | Cropped document image, detected document type, bounding box coordinates |
| **Processing** | YOLO object detection (existing CardDetector) classifies document type |
| **Supported Documents** | `tc_kimlik` (Turkish ID), `passport`, `ehliyet` (driver's license), `ogrenci_karti` (student ID), `ikamet_izni` (residence permit) |
| **Threshold** | Detection confidence >= 0.85 |
| **Timeout** | 60 seconds |
| **Max Attempts** | 3 |

**Configuration Schema (JSONB):**
```json
{
  "acceptedDocuments": ["tc_kimlik", "passport", "ehliyet"],
  "minDetectionConfidence": 0.85,
  "requireBothSides": false,
  "captureMode": "auto",
  "imageQuality": "high"
}
```

### NFC_CHIP_READ

| Field | Value |
|-------|-------|
| **Purpose** | Read cryptographic data from the NFC chip embedded in identity documents |
| **Input** | NFC tap on device (Android/iOS only) |
| **Output** | MRZ (Machine Readable Zone) data, chip-stored photo, personal information, digital signature |
| **Processing** | Existing NFC reader library (11,089 lines, 43 files in client-apps) |
| **Supported Chips** | ICAO 9303 (passports), Turkish eID (TC Kimlik with chip) |
| **Verification** | Passive Authentication (PA) validates digital signature; Active Authentication (AA) proves chip is genuine |
| **Platforms** | Android, iOS (requires NFC hardware) |

**Configuration Schema:**
```json
{
  "requirePassiveAuth": true,
  "requireActiveAuth": false,
  "mrzInputMode": "ocr",
  "chipReadTimeout": 30,
  "acceptedDocTypes": ["passport", "tc_kimlik_chip"]
}
```

### DATA_EXTRACT

| Field | Value |
|-------|-------|
| **Purpose** | Extract structured data from a scanned document image via OCR |
| **Input** | Document image (from DOCUMENT_SCAN step) |
| **Output** | Structured personal data: full name, ID number (TC Kimlik No), date of birth, expiry date, nationality, gender, MRZ text |
| **Processing** | Tesseract OCR + custom MRZ parser, or Google Vision API (configurable) |
| **Confidence** | Per-field confidence scores; overall extraction confidence >= 0.80 |
| **Fallback** | Manual entry form if OCR confidence is below threshold |

**Configuration Schema:**
```json
{
  "ocrEngine": "tesseract",
  "language": "tur+eng",
  "minFieldConfidence": 0.80,
  "allowManualCorrection": true,
  "requiredFields": ["fullName", "idNumber", "dateOfBirth"],
  "mrzParsing": true
}
```

**Output Data Model:**
```json
{
  "fullName": "AHMET YILMAZ",
  "idNumber": "12345678901",
  "dateOfBirth": "1990-05-15",
  "expiryDate": "2030-12-31",
  "nationality": "TUR",
  "gender": "M",
  "documentNumber": "A12B34567",
  "mrz": "P<TURYILMAZ<<AHMET<<<<<<<<<<<<...",
  "fieldConfidences": {
    "fullName": 0.95,
    "idNumber": 0.98,
    "dateOfBirth": 0.92
  },
  "overallConfidence": 0.95
}
```

### FACE_MATCH

| Field | Value |
|-------|-------|
| **Purpose** | Compare a live face capture against the photo extracted from the identity document |
| **Input** | Live face image (camera) + document photo (from DOCUMENT_SCAN or NFC_CHIP_READ) |
| **Output** | Match score (0.0 - 1.0), match decision (MATCH / NO_MATCH / UNCERTAIN) |
| **Processing** | DeepFace verify (existing biometric-processor endpoint: `POST /verify`) |
| **Model** | Facenet512 (512-dimensional embeddings, cosine similarity) |
| **Threshold** | Match score >= 0.65 (configurable per tenant; stricter for banking: 0.75) |
| **Fallback** | If UNCERTAIN (0.55-0.65), escalate to VIDEO_INTERVIEW or manual review |

**Configuration Schema:**
```json
{
  "matchThreshold": 0.65,
  "uncertainRange": [0.55, 0.65],
  "model": "Facenet512",
  "distanceMetric": "cosine",
  "onUncertain": "escalate_to_review",
  "maxRetries": 2,
  "requireLivenessFirst": true
}
```

### LIVENESS_CHECK

| Field | Value |
|-------|-------|
| **Purpose** | Verify the person in front of the camera is a real, live human (not a photo/video/mask) |
| **Input** | Sequence of camera frames (video stream) |
| **Output** | Liveness score (0.0 - 1.0), liveness decision (LIVE / SPOOF / UNCERTAIN) |
| **Processing** | Passive liveness (texture analysis) + active liveness (BiometricPuzzle challenges) |
| **Passive Detection** | Anti-spoofing model analyzes texture, Moire patterns, reflection, depth cues |
| **Active Detection** | Challenge-response: head turns, blinks, smile — via existing BiometricPuzzle engine |
| **Threshold** | Passive score >= 0.70 AND active challenge completion required |

**Configuration Schema:**
```json
{
  "passiveThreshold": 0.70,
  "activeRequired": true,
  "activeChallengeCount": 3,
  "challengeTypes": ["HEAD_LEFT", "HEAD_RIGHT", "BLINK", "SMILE"],
  "maxAttempts": 3,
  "timeout": 60
}
```

### ADDRESS_PROOF

| Field | Value |
|-------|-------|
| **Purpose** | Verify residential address via utility bill, bank statement, or government letter |
| **Input** | Document image (utility bill, bank statement, government correspondence) |
| **Output** | Extracted address, address verification status, document date |
| **Processing** | OCR extraction + optional 3rd-party address verification API |
| **Accepted Documents** | Utility bills (< 3 months), bank statements (< 3 months), government letters |
| **Verification** | Address matched against user-provided address; date within acceptable range |

**Configuration Schema:**
```json
{
  "acceptedDocumentTypes": ["utility_bill", "bank_statement", "government_letter"],
  "maxDocumentAge": 90,
  "requireAddressMatch": true,
  "fuzzyMatchThreshold": 0.85,
  "ocrEngine": "tesseract"
}
```

### WATCHLIST_CHECK

| Field | Value |
|-------|-------|
| **Purpose** | Screen individual against sanctions lists, PEP (Politically Exposed Persons) databases, and adverse media |
| **Input** | Personal information (name, date of birth, nationality, ID number) from DATA_EXTRACT |
| **Output** | Screening result: CLEAR / FLAGGED / MATCH, matched list names, risk score |
| **Processing** | 3rd-party API integration (e.g., ComplyAdvantage, World-Check, MASAK list) |
| **Lists** | OFAC SDN, EU Sanctions, UN Consolidated, MASAK (Turkey), PEP databases |
| **On Match** | Flag for manual review; do NOT auto-reject (false positive rate is high) |

**Configuration Schema:**
```json
{
  "provider": "internal",
  "lists": ["MASAK", "OFAC_SDN", "EU_SANCTIONS", "UN_CONSOLIDATED"],
  "includePEP": true,
  "includeAdverseMedia": false,
  "fuzzyNameMatch": true,
  "matchThreshold": 0.85,
  "onMatch": "flag_for_review"
}
```

### AGE_VERIFICATION

| Field | Value |
|-------|-------|
| **Purpose** | Verify that the individual meets a minimum age requirement |
| **Input** | Date of birth (from DATA_EXTRACT or NFC_CHIP_READ) |
| **Output** | Calculated age, meets minimum age (boolean), age at reference date |
| **Processing** | Local calculation from extracted DOB |
| **Use Cases** | Alcohol/tobacco sales (18+), gambling (18+), vehicle rental (21+), senior discounts (65+) |

**Configuration Schema:**
```json
{
  "minimumAge": 18,
  "referenceDate": "today",
  "rejectOnFail": true,
  "showAgeToTenant": false
}
```

### CREDIT_CHECK

| Field | Value |
|-------|-------|
| **Purpose** | Query credit bureau for credit score and risk assessment |
| **Input** | Personal information (TC Kimlik No, full name) + explicit user consent |
| **Output** | Credit score, risk level (LOW / MEDIUM / HIGH / CRITICAL), summary |
| **Processing** | 3rd-party API integration (KKB - Kredi Kayit Burosu, Findeks) |
| **Consent** | Explicit opt-in required before query; consent record stored |
| **Data Retention** | Credit data NOT stored; only risk level and score retained |

**Configuration Schema:**
```json
{
  "provider": "kkb",
  "requireExplicitConsent": true,
  "minAcceptableScore": 1200,
  "riskLevelMapping": {
    "LOW": [1500, 1900],
    "MEDIUM": [1200, 1499],
    "HIGH": [800, 1199],
    "CRITICAL": [0, 799]
  },
  "rejectOnCritical": true,
  "retainScore": true,
  "retainDetails": false
}
```

### PHONE_VERIFICATION

| Field | Value |
|-------|-------|
| **Purpose** | Verify ownership of a phone number via SMS OTP |
| **Input** | Phone number (user-provided or extracted from document) |
| **Output** | Verified phone number, carrier info (optional) |
| **Processing** | Existing SmsService (Twilio gateway) sends OTP; user enters code |
| **Reuse** | Leverages existing SMS_OTP auth handler infrastructure |
| **Timeout** | OTP valid for 300 seconds; max 3 resend attempts |

**Configuration Schema:**
```json
{
  "otpLength": 6,
  "otpExpirySeconds": 300,
  "maxResendAttempts": 3,
  "resendCooldownSeconds": 60,
  "carrierLookup": false,
  "provider": "twilio"
}
```

### VIDEO_INTERVIEW

| Field | Value |
|-------|-------|
| **Purpose** | Record a short video of the user for human review (highest assurance level) |
| **Input** | Video stream from camera + microphone |
| **Output** | Video recording URL (encrypted storage), transcript (optional), agent review status |
| **Processing** | Video stored encrypted; human agent reviews asynchronously |
| **Use Cases** | High-value accounts, escalation from FACE_MATCH uncertainty, regulatory requirement |
| **Duration** | 15-60 seconds configurable |

**Configuration Schema:**
```json
{
  "minDurationSeconds": 15,
  "maxDurationSeconds": 60,
  "requireSpeech": true,
  "speechPrompt": "Please state your full name and date of birth",
  "recordingQuality": "720p",
  "storageEncryption": "AES-256",
  "retentionDays": 365,
  "autoTranscribe": false,
  "reviewRequired": true
}
```

### Step Compatibility Matrix

```
Step Type          │ WEB │ ANDROID │ iOS │ DESKTOP │ Requires 3rd Party │
───────────────────┼─────┼─────────┼─────┼─────────┼────────────────────┤
DOCUMENT_SCAN      │  Y  │    Y    │  Y  │    Y    │         No         │
NFC_CHIP_READ      │  N  │    Y    │  Y  │    N    │         No         │
DATA_EXTRACT       │  Y  │    Y    │  Y  │    Y    │     Optional       │
FACE_MATCH         │  Y  │    Y    │  Y  │    Y    │         No         │
LIVENESS_CHECK     │  Y  │    Y    │  Y  │    Y    │         No         │
ADDRESS_PROOF      │  Y  │    Y    │  Y  │    Y    │     Optional       │
WATCHLIST_CHECK    │  Y  │    Y    │  Y  │    Y    │        Yes         │
AGE_VERIFICATION   │  Y  │    Y    │  Y  │    Y    │         No         │
CREDIT_CHECK       │  Y  │    Y    │  Y  │    Y    │        Yes         │
PHONE_VERIFICATION │  Y  │    Y    │  Y  │    Y    │        Yes         │
VIDEO_INTERVIEW    │  Y  │    Y    │  Y  │    Y    │         No         │
```

---

## 5. Industry Templates

Industry templates are pre-configured verification flows that tenants can apply with one click. Each template defines an ordered sequence of steps with preconfigured thresholds.

### Template Definitions

#### BANKING_KYC (Full Know Your Customer)

```
Regulatory: BDDK, MASAK (AML/CFT)
Risk Level: HIGH
Steps: 7 | Estimated Time: 5-8 minutes

┌──────────────┐   ┌───────────────┐   ┌──────────────┐   ┌────────────┐
│ DOCUMENT_SCAN│──→│ NFC_CHIP_READ │──→│ DATA_EXTRACT │──→│ FACE_MATCH │
│ tc_kimlik    │   │ passive+active│   │ full fields  │   │ thresh 0.75│
└──────────────┘   └───────────────┘   └──────────────┘   └────────────┘
                                                                │
┌──────────────┐   ┌───────────────┐   ┌──────────────┐        │
│ADDRESS_PROOF │◄──│WATCHLIST_CHECK│◄──│LIVENESS_CHECK│◄───────┘
│ < 3 months   │   │ MASAK + OFAC  │   │ passive+active│
└──────────────┘   └───────────────┘   └──────────────┘
```

#### BANKING_LIGHT (Simplified Remote Onboarding)

```
Risk Level: MEDIUM
Steps: 3 | Estimated Time: 2-3 minutes

┌──────────────┐   ┌────────────┐   ┌──────────────┐
│ DOCUMENT_SCAN│──→│ FACE_MATCH │──→│LIVENESS_CHECK│
│ tc_kimlik    │   │ thresh 0.70│   │ passive only │
└──────────────┘   └────────────┘   └──────────────┘
```

#### HEALTHCARE (Patient Identity)

```
Regulatory: KVKK, Patient ID verification
Risk Level: MEDIUM
Steps: 4 | Estimated Time: 3-4 minutes

┌──────────────┐   ┌──────────────┐   ┌────────────┐   ┌──────────────┐
│ DOCUMENT_SCAN│──→│ DATA_EXTRACT │──→│ FACE_MATCH │──→│LIVENESS_CHECK│
│ tc_kimlik    │   │ name, TC, DOB│   │ thresh 0.65│   │ passive only │
└──────────────┘   └──────────────┘   └────────────┘   └──────────────┘
```

#### EDUCATION (Student Verification)

```
Risk Level: LOW
Steps: 3 | Estimated Time: 1-2 minutes

┌──────────────┐   ┌────────────┐   ┌──────────────┐
│ DOCUMENT_SCAN│──→│ FACE_MATCH │──→│LIVENESS_CHECK│
│ ogrenci_karti│   │ thresh 0.60│   │ passive only │
└──────────────┘   └────────────┘   └──────────────┘
```

#### CORPORATE_ONBOARD (Employee Onboarding)

```
Risk Level: MEDIUM
Steps: 4 | Estimated Time: 3-4 minutes

┌──────────────┐   ┌────────────┐   ┌──────────────┐   ┌──────────────────┐
│ DOCUMENT_SCAN│──→│ FACE_MATCH │──→│LIVENESS_CHECK│──→│PHONE_VERIFICATION│
│ tc_kimlik    │   │ thresh 0.65│   │ passive+active│   │ SMS OTP          │
└──────────────┘   └────────────┘   └──────────────┘   └──────────────────┘
```

#### GOVERNMENT_EKYC (Electronic Know Your Customer)

```
Regulatory: e-Devlet integration standards
Risk Level: HIGH
Steps: 5 | Estimated Time: 5-7 minutes

┌───────────────┐   ┌──────────────┐   ┌────────────┐   ┌──────────────┐   ┌─────────────┐
│ NFC_CHIP_READ │──→│ DATA_EXTRACT │──→│ FACE_MATCH │──→│LIVENESS_CHECK│──→│ FINGERPRINT │
│ passive+active│   │ full fields  │   │ thresh 0.75│   │ passive+active│   │ WebAuthn    │
└───────────────┘   └──────────────┘   └────────────┘   └──────────────┘   └─────────────┘
```

Note: FINGERPRINT here uses the existing `FINGERPRINT` auth method type (WebAuthn platform authenticator).

#### RETAIL_AGE (Age-Restricted Sales)

```
Risk Level: LOW
Steps: 3 | Estimated Time: 1-2 minutes

┌──────────────┐   ┌──────────────────┐   ┌────────────┐
│ DOCUMENT_SCAN│──→│ AGE_VERIFICATION │──→│ FACE_MATCH │
│ tc_kimlik    │   │ min age: 18      │   │ thresh 0.60│
└──────────────┘   └──────────────────┘   └────────────┘
```

#### TRAVEL_BORDER (Border Control)

```
Risk Level: HIGH
Steps: 4 | Estimated Time: 3-5 minutes

┌───────────────┐   ┌────────────┐   ┌──────────────┐   ┌───────────────┐
│ NFC_CHIP_READ │──→│ FACE_MATCH │──→│LIVENESS_CHECK│──→│WATCHLIST_CHECK│
│ passport chip │   │ thresh 0.75│   │ passive+active│   │ INTERPOL, OFAC│
└───────────────┘   └────────────┘   └──────────────┘   └───────────────┘
```

#### FINTECH_ONBOARD (Fintech Customer Onboarding)

```
Regulatory: BDDK (electronic money), PSD2
Risk Level: HIGH
Steps: 5 | Estimated Time: 5-7 minutes

┌──────────────┐   ┌──────────────┐   ┌────────────┐   ┌──────────────┐   ┌──────────────────┐
│ DOCUMENT_SCAN│──→│LIVENESS_CHECK│──→│ FACE_MATCH │──→│ CREDIT_CHECK │──→│PHONE_VERIFICATION│
│ tc_kimlik    │   │ passive+active│   │ thresh 0.70│   │ KKB/Findeks  │   │ SMS OTP          │
└──────────────┘   └──────────────┘   └────────────┘   └──────────────┘   └──────────────────┘
```

### Template Summary Table

| Template | Steps | Est. Time | 3rd Party | Risk Level |
|----------|-------|-----------|-----------|------------|
| BANKING_KYC | 7 | 5-8 min | Watchlist | HIGH |
| BANKING_LIGHT | 3 | 2-3 min | None | MEDIUM |
| HEALTHCARE | 4 | 3-4 min | None | MEDIUM |
| EDUCATION | 3 | 1-2 min | None | LOW |
| CORPORATE_ONBOARD | 4 | 3-4 min | SMS | MEDIUM |
| GOVERNMENT_EKYC | 5 | 5-7 min | None | HIGH |
| RETAIL_AGE | 3 | 1-2 min | None | LOW |
| TRAVEL_BORDER | 4 | 3-5 min | Watchlist | HIGH |
| FINTECH_ONBOARD | 5 | 5-7 min | Credit, SMS | HIGH |

---

## 6. Database Schema Extension

### V26 Migration: Verification Pipeline System

```sql
-- V26: Verification Pipeline System
-- Extends the auth flow engine to support identity verification pipelines
-- Adds verification-specific step types, templates, result tracking

-- ============================================================================
-- COLUMN: auth_flows.flow_type (extends existing table)
-- ============================================================================
ALTER TABLE auth_flows
    ADD COLUMN IF NOT EXISTS flow_type VARCHAR(20) NOT NULL DEFAULT 'AUTHENTICATION';

ALTER TABLE auth_flows
    DROP CONSTRAINT IF EXISTS chk_flow_type;
ALTER TABLE auth_flows
    ADD CONSTRAINT chk_flow_type
    CHECK (flow_type IN ('AUTHENTICATION', 'VERIFICATION', 'ENROLLMENT', 'ONBOARDING'));

-- ============================================================================
-- COLUMN: auth_flows.industry_template (template reference)
-- ============================================================================
ALTER TABLE auth_flows
    ADD COLUMN IF NOT EXISTS industry_template VARCHAR(50);

ALTER TABLE auth_flows
    DROP CONSTRAINT IF EXISTS chk_industry_template;
ALTER TABLE auth_flows
    ADD CONSTRAINT chk_industry_template
    CHECK (industry_template IS NULL OR industry_template IN (
        'BANKING_KYC', 'BANKING_LIGHT', 'HEALTHCARE', 'EDUCATION',
        'CORPORATE_ONBOARD', 'GOVERNMENT_EKYC', 'RETAIL_AGE',
        'TRAVEL_BORDER', 'FINTECH_ONBOARD'
    ));

CREATE INDEX IF NOT EXISTS idx_auth_flows_flow_type
    ON auth_flows(flow_type);
CREATE INDEX IF NOT EXISTS idx_auth_flows_industry_template
    ON auth_flows(industry_template) WHERE industry_template IS NOT NULL;

-- ============================================================================
-- UPDATE: auth_methods constraint to include verification step types
-- ============================================================================
ALTER TABLE auth_methods
    DROP CONSTRAINT IF EXISTS chk_auth_method_type;
ALTER TABLE auth_methods
    ADD CONSTRAINT chk_auth_method_type
    CHECK (type IN (
        -- Existing authentication methods
        'PASSWORD', 'EMAIL_OTP', 'SMS_OTP', 'TOTP', 'QR_CODE',
        'FACE', 'FINGERPRINT', 'VOICE', 'NFC_DOCUMENT', 'HARDWARE_KEY',
        -- New verification step types
        'DOCUMENT_SCAN', 'NFC_CHIP_READ', 'DATA_EXTRACT', 'FACE_MATCH',
        'LIVENESS_CHECK', 'ADDRESS_PROOF', 'WATCHLIST_CHECK',
        'AGE_VERIFICATION', 'CREDIT_CHECK', 'PHONE_VERIFICATION',
        'VIDEO_INTERVIEW'
    ));

-- ============================================================================
-- SEED: New verification step types in auth_methods
-- ============================================================================
INSERT INTO auth_methods (type, name, description, category, platforms, requires_enrollment, is_active)
VALUES
    ('DOCUMENT_SCAN',      'Document Scan',       'Detect and capture identity document',      'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('NFC_CHIP_READ',      'NFC Chip Read',       'Read NFC chip from identity document',      'VERIFICATION', '{ANDROID,IOS}',             false, true),
    ('DATA_EXTRACT',       'Data Extract',        'OCR/parse document data',                   'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('FACE_MATCH',         'Face Match',          'Compare live face vs document photo',        'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('LIVENESS_CHECK',     'Liveness Check',      'Verify person is real (not spoof)',          'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('ADDRESS_PROOF',      'Address Proof',       'Verify residential address',                 'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('WATCHLIST_CHECK',    'Watchlist Check',     'Screen against sanctions/PEP lists',         'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('AGE_VERIFICATION',   'Age Verification',    'Verify minimum age requirement',             'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('CREDIT_CHECK',       'Credit Check',        'Credit bureau verification',                 'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('PHONE_VERIFICATION', 'Phone Verification',  'Verify phone ownership via SMS OTP',         'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true),
    ('VIDEO_INTERVIEW',    'Video Interview',     'Recorded video for human review',            'VERIFICATION', '{WEB,ANDROID,IOS,DESKTOP}', false, true)
ON CONFLICT (type) DO NOTHING;

-- ============================================================================
-- TABLE: verification_results (stores pipeline execution results per user)
-- ============================================================================
CREATE TABLE IF NOT EXISTS verification_results (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id           UUID           NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    session_id          UUID           NOT NULL REFERENCES auth_sessions(id),
    flow_id             UUID           NOT NULL REFERENCES auth_flows(id),

    -- Overall result
    status              VARCHAR(20)    NOT NULL DEFAULT 'PENDING',
    overall_confidence  FLOAT,
    risk_level          VARCHAR(10),

    -- Identity data (extracted and verified)
    verified_name       VARCHAR(255),
    verified_id_number  VARCHAR(50),
    verified_dob        DATE,
    verified_nationality VARCHAR(10),
    document_type       VARCHAR(30),

    -- Flags
    identity_verified   BOOLEAN        NOT NULL DEFAULT false,
    watchlist_clear     BOOLEAN,
    liveness_confirmed  BOOLEAN,
    face_matched        BOOLEAN,

    -- Step-level scores
    step_scores         JSONB          NOT NULL DEFAULT '{}',

    -- Review
    reviewed_by         UUID           REFERENCES users(id),
    reviewed_at         TIMESTAMP WITH TIME ZONE,
    review_notes        TEXT,

    -- Retention
    expires_at          TIMESTAMP WITH TIME ZONE,
    purged_at           TIMESTAMP WITH TIME ZONE,

    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_verification_status
        CHECK (status IN ('PENDING', 'IN_PROGRESS', 'VERIFIED', 'REJECTED', 'REVIEW_REQUIRED', 'EXPIRED')),
    CONSTRAINT chk_risk_level
        CHECK (risk_level IS NULL OR risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_overall_confidence
        CHECK (overall_confidence IS NULL OR (overall_confidence >= 0 AND overall_confidence <= 1))
);

CREATE INDEX IF NOT EXISTS idx_verification_results_user
    ON verification_results(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_results_tenant
    ON verification_results(tenant_id);
CREATE INDEX IF NOT EXISTS idx_verification_results_session
    ON verification_results(session_id);
CREATE INDEX IF NOT EXISTS idx_verification_results_status
    ON verification_results(status);
CREATE INDEX IF NOT EXISTS idx_verification_results_verified
    ON verification_results(user_id, identity_verified) WHERE identity_verified = true;

-- ============================================================================
-- TABLE: verification_documents (stores scanned document metadata)
-- ============================================================================
CREATE TABLE IF NOT EXISTS verification_documents (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    verification_id     UUID           NOT NULL REFERENCES verification_results(id) ON DELETE CASCADE,
    user_id             UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id           UUID           NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    -- Document info
    document_type       VARCHAR(30)    NOT NULL,
    document_number     VARCHAR(100),
    issuing_country     VARCHAR(10),
    issue_date          DATE,
    expiry_date         DATE,

    -- Scan info
    scan_side           VARCHAR(10)    NOT NULL DEFAULT 'FRONT',
    image_reference     VARCHAR(255),
    image_hash          VARCHAR(128),
    detection_confidence FLOAT,

    -- OCR result
    extracted_data      JSONB          NOT NULL DEFAULT '{}',
    extraction_confidence FLOAT,
    mrz_data            TEXT,

    -- NFC data (if chip was read)
    nfc_passive_auth    BOOLEAN,
    nfc_active_auth     BOOLEAN,
    nfc_chip_data       JSONB          DEFAULT '{}',

    -- Encryption
    encryption_key_id   VARCHAR(100),
    encrypted           BOOLEAN        NOT NULL DEFAULT true,

    -- Retention
    expires_at          TIMESTAMP WITH TIME ZONE NOT NULL,
    purged_at           TIMESTAMP WITH TIME ZONE,

    -- Timestamps
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_document_type
        CHECK (document_type IN ('tc_kimlik', 'passport', 'ehliyet', 'ogrenci_karti', 'ikamet_izni', 'utility_bill', 'bank_statement', 'other')),
    CONSTRAINT chk_scan_side
        CHECK (scan_side IN ('FRONT', 'BACK', 'CHIP')),
    CONSTRAINT chk_detection_confidence
        CHECK (detection_confidence IS NULL OR (detection_confidence >= 0 AND detection_confidence <= 1))
);

CREATE INDEX IF NOT EXISTS idx_verification_documents_verification
    ON verification_documents(verification_id);
CREATE INDEX IF NOT EXISTS idx_verification_documents_user
    ON verification_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_documents_expiry
    ON verification_documents(expires_at) WHERE purged_at IS NULL;

-- ============================================================================
-- TABLE: verification_sessions (tracks pipeline execution state, extended view)
-- ============================================================================
CREATE TABLE IF NOT EXISTS verification_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_session_id     UUID           NOT NULL REFERENCES auth_sessions(id),
    verification_id     UUID           REFERENCES verification_results(id),
    tenant_id           UUID           NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id             UUID           REFERENCES users(id),

    -- Pipeline state
    template_used       VARCHAR(50),
    total_steps         INTEGER        NOT NULL,
    completed_steps     INTEGER        NOT NULL DEFAULT 0,
    current_step_type   VARCHAR(30),

    -- Collected data (intermediate state between steps)
    document_image_ref  VARCHAR(255),
    document_photo_ref  VARCHAR(255),
    extracted_data      JSONB          DEFAULT '{}',
    nfc_data            JSONB          DEFAULT '{}',

    -- Timing
    started_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMP WITH TIME ZONE,
    expires_at          TIMESTAMP WITH TIME ZONE NOT NULL,

    -- Client context
    client_platform     VARCHAR(20),
    client_ip           VARCHAR(45),
    client_user_agent   TEXT,

    CONSTRAINT chk_completed_steps
        CHECK (completed_steps >= 0 AND completed_steps <= total_steps)
);

CREATE INDEX IF NOT EXISTS idx_verification_sessions_auth_session
    ON verification_sessions(auth_session_id);
CREATE INDEX IF NOT EXISTS idx_verification_sessions_tenant
    ON verification_sessions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_verification_sessions_user
    ON verification_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_sessions_expires
    ON verification_sessions(expires_at) WHERE completed_at IS NULL;

-- ============================================================================
-- COLUMN: users.identity_verified (quick lookup flag)
-- ============================================================================
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS identity_verified BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS identity_verified_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS verification_level VARCHAR(10);

CREATE INDEX IF NOT EXISTS idx_users_identity_verified
    ON users(identity_verified) WHERE identity_verified = true;

-- ============================================================================
-- PERMISSIONS: verification management
-- ============================================================================
INSERT INTO permissions (name, description, resource, action) VALUES
    ('verification:read',       'Read verification results',    'verification', 'read'),
    ('verification:create',     'Start verification pipelines', 'verification', 'create'),
    ('verification:review',     'Review verification results',  'verification', 'review'),
    ('verification:configure',  'Configure verification flows', 'verification', 'configure'),
    ('verification:delete',     'Delete verification data',     'verification', 'delete'),
    ('template:read',           'Read industry templates',      'template',     'read'),
    ('template:apply',          'Apply templates to tenant',    'template',     'apply')
ON CONFLICT (name) DO NOTHING;

-- Triggers
CREATE TRIGGER update_verification_results_updated_at
    BEFORE UPDATE ON verification_results
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE verification_results IS 'Identity verification pipeline results per user';
COMMENT ON TABLE verification_documents IS 'Scanned document metadata (images stored encrypted externally)';
COMMENT ON TABLE verification_sessions IS 'Pipeline execution state tracking';
COMMENT ON COLUMN auth_flows.flow_type IS 'AUTHENTICATION (existing), VERIFICATION, ENROLLMENT, ONBOARDING';
COMMENT ON COLUMN auth_flows.industry_template IS 'Pre-built template identifier (e.g., BANKING_KYC)';
COMMENT ON COLUMN users.identity_verified IS 'True when user has passed a verification pipeline';
```

### Entity Relationship Diagram

```
┌──────────────┐         ┌──────────────┐         ┌──────────────────┐
│   tenants    │─1────N─→│  auth_flows  │─1────N─→│ auth_flow_steps  │
│              │         │  +flow_type  │         │                  │
│              │         │  +template   │         │ auth_method_id──→│──→ auth_methods
└──────────────┘         └──────┬───────┘         └──────────────────┘     (now includes
       │                        │                                          VERIFICATION
       │                        │                                          category)
       │                  ┌─────┴──────────┐
       │                  │ auth_sessions  │
       │                  │                │─1────N─→ auth_session_steps
       │                  └─────┬──────────┘              (step results)
       │                        │
       │                  ┌─────┴──────────────────┐
       │                  │ verification_sessions   │
       │                  │ (pipeline state)        │
       │                  └─────┬──────────────────┘
       │                        │
       │                  ┌─────┴──────────────────┐
       │           ┌──────│ verification_results    │──────┐
       │           │      │ (overall outcome)       │      │
       │           │      └────────────────────────┘      │
       │           │                                       │
       │     ┌─────┴──────────────────┐              ┌─────┴──────┐
       │     │ verification_documents │              │   users    │
       │     │ (scanned doc metadata) │              │ +identity  │
       │     └────────────────────────┘              │  _verified │
       │                                              └────────────┘
       └──────────────────────────────────────────────────┘
```

---

## 7. API Endpoints

### Verification Session Management

All endpoints are under `/api/v1/verification` and require JWT authentication.

#### POST /api/v1/verification/sessions

Start a new verification pipeline for the authenticated user.

**Request:**
```json
{
  "flowId": "uuid",
  "platform": "WEB",
  "deviceId": "optional-device-fingerprint",
  "metadata": {}
}
```

**Response (201 Created):**
```json
{
  "sessionId": "uuid",
  "verificationId": "uuid",
  "flowType": "VERIFICATION",
  "templateUsed": "BANKING_KYC",
  "totalSteps": 7,
  "currentStep": {
    "stepNumber": 1,
    "type": "DOCUMENT_SCAN",
    "name": "Document Scan",
    "config": {
      "acceptedDocuments": ["tc_kimlik", "passport"],
      "minDetectionConfidence": 0.85
    },
    "timeout": 60,
    "maxAttempts": 3
  },
  "steps": [
    { "stepNumber": 1, "type": "DOCUMENT_SCAN", "status": "IN_PROGRESS" },
    { "stepNumber": 2, "type": "NFC_CHIP_READ", "status": "PENDING" },
    { "stepNumber": 3, "type": "DATA_EXTRACT", "status": "PENDING" },
    { "stepNumber": 4, "type": "FACE_MATCH", "status": "PENDING" },
    { "stepNumber": 5, "type": "LIVENESS_CHECK", "status": "PENDING" },
    { "stepNumber": 6, "type": "WATCHLIST_CHECK", "status": "PENDING" },
    { "stepNumber": 7, "type": "ADDRESS_PROOF", "status": "PENDING" }
  ],
  "expiresAt": "2026-03-28T15:30:00Z"
}
```

#### POST /api/v1/verification/sessions/{sessionId}/steps/{stepNumber}

Submit result for a specific step in the pipeline.

**Request (example for DOCUMENT_SCAN):**
```json
{
  "type": "DOCUMENT_SCAN",
  "data": {
    "documentImage": "base64-encoded-image",
    "detectedType": "tc_kimlik",
    "boundingBox": { "x": 50, "y": 30, "width": 540, "height": 340 },
    "confidence": 0.97
  }
}
```

**Request (example for FACE_MATCH):**
```json
{
  "type": "FACE_MATCH",
  "data": {
    "liveFaceImage": "base64-encoded-image",
    "livenessScore": 0.95
  }
}
```

**Response (200 OK):**
```json
{
  "stepNumber": 1,
  "type": "DOCUMENT_SCAN",
  "status": "COMPLETED",
  "result": {
    "documentType": "tc_kimlik",
    "confidence": 0.97,
    "processingTimeMs": 1245
  },
  "nextStep": {
    "stepNumber": 2,
    "type": "NFC_CHIP_READ",
    "config": { ... }
  },
  "overallProgress": {
    "completedSteps": 1,
    "totalSteps": 7,
    "percentComplete": 14
  }
}
```

**Error Response (422 Unprocessable Entity):**
```json
{
  "stepNumber": 4,
  "type": "FACE_MATCH",
  "status": "FAILED",
  "error": {
    "code": "FACE_MATCH_BELOW_THRESHOLD",
    "message": "Face match score 0.52 is below threshold 0.65",
    "score": 0.52,
    "threshold": 0.65
  },
  "attemptsRemaining": 2,
  "canRetry": true
}
```

#### GET /api/v1/verification/sessions/{sessionId}

Get the current status of a verification pipeline session.

**Response (200 OK):**
```json
{
  "sessionId": "uuid",
  "verificationId": "uuid",
  "status": "IN_PROGRESS",
  "flowType": "VERIFICATION",
  "templateUsed": "BANKING_KYC",
  "currentStepNumber": 4,
  "totalSteps": 7,
  "completedSteps": 3,
  "steps": [
    {
      "stepNumber": 1,
      "type": "DOCUMENT_SCAN",
      "status": "COMPLETED",
      "completedAt": "2026-03-28T14:01:15Z",
      "result": { "documentType": "tc_kimlik", "confidence": 0.97 }
    },
    {
      "stepNumber": 2,
      "type": "NFC_CHIP_READ",
      "status": "COMPLETED",
      "completedAt": "2026-03-28T14:02:30Z",
      "result": { "passiveAuth": true, "activeAuth": true }
    },
    {
      "stepNumber": 3,
      "type": "DATA_EXTRACT",
      "status": "COMPLETED",
      "completedAt": "2026-03-28T14:02:45Z",
      "result": { "fullName": "AHMET YILMAZ", "overallConfidence": 0.95 }
    },
    {
      "stepNumber": 4,
      "type": "FACE_MATCH",
      "status": "IN_PROGRESS",
      "startedAt": "2026-03-28T14:03:00Z"
    },
    { "stepNumber": 5, "type": "LIVENESS_CHECK", "status": "PENDING" },
    { "stepNumber": 6, "type": "WATCHLIST_CHECK", "status": "PENDING" },
    { "stepNumber": 7, "type": "ADDRESS_PROOF", "status": "PENDING" }
  ],
  "startedAt": "2026-03-28T14:00:00Z",
  "expiresAt": "2026-03-28T15:30:00Z"
}
```

#### GET /api/v1/verification/templates

List all available industry templates. No authentication required (public).

**Response (200 OK):**
```json
{
  "templates": [
    {
      "id": "BANKING_KYC",
      "name": "Banking KYC (Full)",
      "description": "Complete Know Your Customer pipeline for banking compliance",
      "riskLevel": "HIGH",
      "steps": ["DOCUMENT_SCAN", "NFC_CHIP_READ", "DATA_EXTRACT", "FACE_MATCH", "LIVENESS_CHECK", "WATCHLIST_CHECK", "ADDRESS_PROOF"],
      "estimatedTime": "5-8 minutes",
      "requiresThirdParty": true,
      "industries": ["banking", "finance"]
    },
    {
      "id": "BANKING_LIGHT",
      "name": "Banking Light",
      "description": "Simplified remote onboarding for low-risk accounts",
      "riskLevel": "MEDIUM",
      "steps": ["DOCUMENT_SCAN", "FACE_MATCH", "LIVENESS_CHECK"],
      "estimatedTime": "2-3 minutes",
      "requiresThirdParty": false,
      "industries": ["banking", "fintech"]
    }
  ]
}
```

#### POST /api/v1/verification/templates/{templateId}/apply

Apply an industry template to a tenant, creating a new verification flow.

**Request:**
```json
{
  "tenantId": "uuid",
  "flowName": "KYC Verification",
  "overrides": {
    "FACE_MATCH": { "matchThreshold": 0.80 },
    "LIVENESS_CHECK": { "activeRequired": true }
  }
}
```

**Response (201 Created):**
```json
{
  "flowId": "uuid",
  "flowName": "KYC Verification",
  "flowType": "VERIFICATION",
  "industryTemplate": "BANKING_KYC",
  "steps": [
    { "stepNumber": 1, "type": "DOCUMENT_SCAN", "config": { ... } },
    { "stepNumber": 2, "type": "NFC_CHIP_READ", "config": { ... } },
    { "stepNumber": 3, "type": "DATA_EXTRACT", "config": { ... } },
    { "stepNumber": 4, "type": "FACE_MATCH", "config": { "matchThreshold": 0.80 } },
    { "stepNumber": 5, "type": "LIVENESS_CHECK", "config": { "activeRequired": true } },
    { "stepNumber": 6, "type": "WATCHLIST_CHECK", "config": { ... } },
    { "stepNumber": 7, "type": "ADDRESS_PROOF", "config": { ... } }
  ]
}
```

#### GET /api/v1/verification/results/{userId}

Get a user's verification status. Requires `verification:read` permission.

**Response (200 OK):**
```json
{
  "userId": "uuid",
  "identityVerified": true,
  "verificationLevel": "HIGH",
  "latestVerification": {
    "verificationId": "uuid",
    "status": "VERIFIED",
    "template": "BANKING_KYC",
    "overallConfidence": 0.94,
    "verifiedAt": "2026-03-28T14:10:00Z",
    "expiresAt": "2027-03-28T14:10:00Z",
    "verifiedData": {
      "fullName": "AHMET YILMAZ",
      "documentType": "tc_kimlik",
      "nationality": "TUR"
    },
    "stepScores": {
      "DOCUMENT_SCAN": 0.97,
      "NFC_CHIP_READ": 1.0,
      "DATA_EXTRACT": 0.95,
      "FACE_MATCH": 0.89,
      "LIVENESS_CHECK": 0.93,
      "WATCHLIST_CHECK": 1.0,
      "ADDRESS_PROOF": 0.90
    },
    "flags": {
      "watchlistClear": true,
      "livenessConfirmed": true,
      "faceMatched": true
    }
  },
  "previousVerifications": [
    {
      "verificationId": "uuid",
      "status": "REJECTED",
      "reason": "FACE_MATCH_BELOW_THRESHOLD",
      "createdAt": "2026-03-27T10:00:00Z"
    }
  ]
}
```

### Controller Structure

```
identity-core-api/
  src/main/java/com/fivucsas/identity/
    controller/
      VerificationController.java          ← Sessions + step submissions
      VerificationTemplateController.java  ← Template listing + apply
      VerificationResultController.java    ← Results + user status
    application/
      service/
        VerificationService.java           ← Pipeline orchestration
        VerificationStepExecutor.java      ← Dispatches to step handlers
        VerificationTemplateService.java   ← Template management
        handler/verification/
          DocumentScanHandler.java
          NfcChipReadHandler.java
          DataExtractHandler.java
          FaceMatchHandler.java
          LivenessCheckHandler.java
          AddressProofHandler.java
          WatchlistCheckHandler.java
          AgeVerificationHandler.java
          CreditCheckHandler.java
          PhoneVerificationHandler.java
          VideoInterviewHandler.java
      port/
        input/
          StartVerificationUseCase.java
          SubmitVerificationStepUseCase.java
          GetVerificationStatusUseCase.java
          ApplyVerificationTemplateUseCase.java
        output/
          VerificationResultRepositoryPort.java
          VerificationDocumentRepositoryPort.java
          VerificationSessionRepositoryPort.java
          OcrServicePort.java              ← OCR integration
          WatchlistServicePort.java        ← Sanctions screening
          CreditCheckServicePort.java      ← Credit bureau
    entity/
      VerificationResult.java
      VerificationDocument.java
      VerificationSession.java
    repository/
      VerificationResultRepository.java
      VerificationDocumentRepository.java
      VerificationSessionRepository.java
```

---

## 8. Tenant Admin UI

### Flow Builder Enhancement

The existing auth flow builder in the web-app dashboard (`AuthFlowBuilderPage.tsx`) is extended with a "Verification" tab alongside the existing "Authentication" tab.

```
┌─────────────────────────────────────────────────────────────────────┐
│ Flow Builder                                           [Save] [Test]│
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Authentication]  [Verification]  [Enrollment]  [Onboarding]       │
│                    ^^^^^^^^^^^^                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Industry Template: [BANKING_KYC          ▼]  [Apply]        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Pipeline Steps:                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 1. DOCUMENT_SCAN    [tc_kimlik, passport]  [Configure] [x] │    │
│  │ 2. NFC_CHIP_READ    [passive + active]     [Configure] [x] │    │
│  │ 3. DATA_EXTRACT     [full fields]          [Configure] [x] │    │
│  │ 4. FACE_MATCH       [threshold: 0.75]      [Configure] [x] │    │
│  │ 5. LIVENESS_CHECK   [passive + active]     [Configure] [x] │    │
│  │ 6. WATCHLIST_CHECK  [MASAK + OFAC]         [Configure] [x] │    │
│  │ 7. ADDRESS_PROOF    [< 3 months]           [Configure] [x] │    │
│  │                                                              │    │
│  │ [+ Add Step]                                                 │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Preview:                                                            │
│  DOCUMENT_SCAN → NFC_CHIP_READ → DATA_EXTRACT → FACE_MATCH →       │
│  LIVENESS_CHECK → WATCHLIST_CHECK → ADDRESS_PROOF                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Template Selector

```
┌─────────────────────────────────────────────────────────────────────┐
│ Choose Industry Template                                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  BANKING_KYC    │  │  BANKING_LIGHT  │  │   HEALTHCARE    │    │
│  │  ■■■■■■■ HIGH   │  │  ■■■■ MEDIUM    │  │  ■■■■ MEDIUM    │    │
│  │  7 steps        │  │  3 steps        │  │  4 steps        │    │
│  │  5-8 min        │  │  2-3 min        │  │  3-4 min        │    │
│  │  3rd party: Yes │  │  3rd party: No  │  │  3rd party: No  │    │
│  │  [Select]       │  │  [Select]       │  │  [Select]       │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │   EDUCATION     │  │ CORPORATE_ONBOARD│  │ GOVERNMENT_EKYC │    │
│  │  ■■ LOW         │  │  ■■■■ MEDIUM    │  │  ■■■■■■■ HIGH   │    │
│  │  3 steps        │  │  4 steps        │  │  5 steps        │    │
│  │  1-2 min        │  │  3-4 min        │  │  5-7 min        │    │
│  │  3rd party: No  │  │  3rd party: SMS │  │  3rd party: No  │    │
│  │  [Select]       │  │  [Select]       │  │  [Select]       │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Verification Dashboard

New admin page: `VerificationDashboardPage.tsx`

```
┌─────────────────────────────────────────────────────────────────────┐
│ Verification Dashboard                              [Export] [Filter]│
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐       │
│  │   1,247   │  │    89%    │  │     23    │  │    3.2m   │       │
│  │  Total    │  │ Completion│  │  Pending  │  │  Avg Time │       │
│  │  Pipelines│  │   Rate    │  │  Review   │  │           │       │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘       │
│                                                                      │
│  Step Pass Rates:                                                    │
│  DOCUMENT_SCAN    ████████████████████████ 98%                      │
│  NFC_CHIP_READ    ██████████████████████   95%                      │
│  DATA_EXTRACT     ████████████████████████ 97%                      │
│  FACE_MATCH       █████████████████████    91%                      │
│  LIVENESS_CHECK   ██████████████████████   94%                      │
│  WATCHLIST_CHECK  █████████████████████████ 99%                     │
│  ADDRESS_PROOF    ███████████████████      87%                      │
│                                                                      │
│  Recent Verifications:                                               │
│  ┌──────────┬──────────┬────────────┬──────────┬─────────┐         │
│  │ User     │ Template │ Status     │ Time     │ Actions │         │
│  ├──────────┼──────────┼────────────┼──────────┼─────────┤         │
│  │ A. Yilmaz│ BANK_KYC │ ✓ Verified │ 4m 12s  │ [View]  │         │
│  │ B. Demir │ BANK_KYC │ ! Review   │ 3m 45s  │ [Review]│         │
│  │ C. Kaya  │ HEALTHCARE│ ✓ Verified│ 2m 30s  │ [View]  │         │
│  │ D. Celik │ BANK_LITE│ ✗ Rejected │ 1m 15s  │ [View]  │         │
│  └──────────┴──────────┴────────────┴──────────┴─────────┘         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Frontend Components (web-app)

```
web-app/src/
  features/verification/
    pages/
      VerificationDashboardPage.tsx       ← Admin analytics
      VerificationFlowBuilderPage.tsx     ← Configure pipelines
      VerificationReviewPage.tsx          ← Review flagged cases
    components/
      VerificationStepCard.tsx            ← Single step display
      VerificationProgress.tsx            ← Step-by-step progress bar
      VerificationResultBadge.tsx         ← Verified/Rejected/Pending badge
      TemplateSelector.tsx                ← Industry template picker
      DocumentScanStep.tsx                ← Camera + YOLO detection
      NfcChipReadStep.tsx                 ← NFC tap UI
      DataExtractStep.tsx                 ← OCR results + manual correction
      FaceMatchStep.tsx                   ← Live face vs document comparison
      LivenessCheckStep.tsx               ← Liveness challenge UI
      AddressProofStep.tsx                ← Document upload
      StepConfigDialog.tsx                ← Per-step threshold configuration
    hooks/
      useVerificationSession.ts           ← Session management
      useVerificationStep.ts              ← Step submission
      useDocumentScan.ts                  ← Camera + YOLO integration
      useVerificationTemplates.ts         ← Template listing
    api/
      verificationApi.ts                  ← API client
    types/
      verification.ts                     ← TypeScript types
```

---

## 9. User-Facing Flow

### How a User Experiences the Verification Pipeline

The verification pipeline is presented as a step-by-step guided flow, similar to the existing multi-step authentication but with richer UI for document capture and biometric matching.

#### Entry Points

1. **Direct link**: `https://app.fivucsas.com/verify?flow=BANKING_KYC`
2. **QR code scan**: Tenant displays QR code at branch/office
3. **In-app**: Button in dashboard triggers verification
4. **Widget**: Third-party site embeds `<fivucsas-verify flow="kyc" />`
5. **Mobile app**: KMP WebView or native NFC flow

#### User Journey (BANKING_KYC example)

```
Step 1: Document Scan
┌─────────────────────────────────────────────┐
│          Scan Your ID Document              │
│                                              │
│  ┌──────────────────────────────────┐       │
│  │                                   │       │
│  │     [ Camera viewfinder ]         │       │
│  │     [ YOLO bounding box ]         │       │
│  │                                   │       │
│  │  "Hold your TC Kimlik steady"     │       │
│  └──────────────────────────────────┘       │
│                                              │
│  ● Document Scan  ○ NFC  ○ Face  ○ ...      │
│  [1/7]                                       │
└─────────────────────────────────────────────┘

Step 2: NFC Chip Read
┌─────────────────────────────────────────────┐
│          Tap Your ID on the Phone           │
│                                              │
│         ┌─────────────────────┐             │
│         │                     │             │
│         │   [ NFC animation ] │             │
│         │   "Hold card near   │             │
│         │    top of phone"    │             │
│         │                     │             │
│         └─────────────────────┘             │
│                                              │
│  ✓ Document  ● NFC  ○ Face  ○ ...           │
│  [2/7]                                       │
└─────────────────────────────────────────────┘

Step 3: Data Extraction (automatic)
┌─────────────────────────────────────────────┐
│          Verifying Document Data             │
│                                              │
│  Name:        AHMET YILMAZ         ✓ 95%   │
│  TC Kimlik:   12345678901          ✓ 98%   │
│  DOB:         15.05.1990           ✓ 92%   │
│  Expiry:      31.12.2030           ✓ 97%   │
│  Nationality: TUR                  ✓ 99%   │
│                                              │
│  [Edit]  If any field is incorrect           │
│                                              │
│  ✓ Document  ✓ NFC  ● Data  ○ Face  ○ ...  │
│  [3/7]                         [Continue]    │
└─────────────────────────────────────────────┘

Step 4: Face Match
┌─────────────────────────────────────────────┐
│          Match Your Face to Document        │
│                                              │
│  ┌──────────────┐  ┌──────────────┐         │
│  │              │  │              │         │
│  │ [Live camera]│  │ [Doc photo]  │         │
│  │              │  │              │         │
│  └──────────────┘  └──────────────┘         │
│                                              │
│  "Look directly at the camera"               │
│                                              │
│  Match: 89% ████████████████████░░  ✓       │
│                                              │
│  ✓ Doc  ✓ NFC  ✓ Data  ● Face  ○ ...       │
│  [4/7]                                       │
└─────────────────────────────────────────────┘

Step 5-7: Liveness → Watchlist → Address
(similar step-by-step progression)

Final: Verification Complete
┌─────────────────────────────────────────────┐
│          Identity Verified                   │
│                                              │
│              ✓                                │
│          VERIFIED                             │
│                                              │
│  Overall Confidence: 94%                     │
│                                              │
│  ✓ Document scanned (97%)                   │
│  ✓ NFC chip verified (100%)                 │
│  ✓ Data extracted (95%)                     │
│  ✓ Face matched (89%)                       │
│  ✓ Liveness confirmed (93%)                 │
│  ✓ Watchlist clear (100%)                   │
│  ✓ Address verified (90%)                   │
│                                              │
│  [Done]                                      │
└─────────────────────────────────────────────┘
```

---

## 10. Integration with Existing Systems

### Authentication Flows Remain Unchanged

Verification is a **separate flow type**, not a replacement for authentication. Existing auth flows (`flow_type = 'AUTHENTICATION'`) continue to work exactly as before. No breaking changes.

```
                    SEPARATION OF CONCERNS

  AUTHENTICATION                      VERIFICATION
  (existing, unchanged)               (new, parallel)
  ┌──────────────────┐               ┌──────────────────┐
  │ "Is this person  │               │ "Is this person  │
  │  the registered  │               │  who they claim  │
  │  user?"          │               │  to be in the    │
  │                  │               │  real world?"    │
  │ Input: biometrics│               │ Input: documents │
  │        + creds   │               │        + biometrics│
  │                  │               │        + databases │
  │ Output: JWT      │               │ Output: Verified │
  │         session  │               │         identity │
  └──────────────────┘               └──────────────────┘
           │                                   │
           └─────────┬─────────────────────────┘
                     │
              ┌──────┴──────┐
              │    users    │
              │  table row  │
              │             │
              │ auth: JWT   │
              │ identity:   │
              │  verified=T │
              └─────────────┘
```

### Post-Verification Actions

When a verification pipeline completes successfully:

1. **User flag updated**: `users.identity_verified = true`, `users.identity_verified_at = NOW()`
2. **Verification result stored**: `verification_results` row with all scores and data
3. **Auth flow prerequisite**: Auth flows can require `identityVerified = true`
4. **OAuth 2.0 scope**: Verification status accessible via `scope=identity_verified`
5. **Webhook notification**: Tenant receives webhook with verification outcome
6. **Audit log entry**: `IDENTITY_VERIFICATION_COMPLETED` audit event

### OAuth 2.0 Integration

The existing OAuth 2.0 endpoints (V24, OAuth2Controller) are extended to support verification scopes:

```
New OAuth 2.0 Scopes:
  identity_verified       → Boolean: is user identity verified?
  identity_level          → Verification level: LOW/MEDIUM/HIGH
  identity_document_type  → Document used for verification
  identity_verified_at    → When verification was completed

UserInfo Response (with identity scopes):
{
  "sub": "user-uuid",
  "email": "ahmet@example.com",
  "name": "Ahmet Yilmaz",
  "identity_verified": true,
  "identity_level": "HIGH",
  "identity_document_type": "tc_kimlik",
  "identity_verified_at": "2026-03-28T14:10:00Z"
}
```

### Embeddable Widget Integration

The existing auth widget (`<fivucsas-verify>`) gains a new `flow` attribute for verification:

```html
<!-- Existing: authentication -->
<fivucsas-verify client-id="..." flow="login" />

<!-- New: verification -->
<fivucsas-verify client-id="..." flow="kyc" template="BANKING_KYC" />

<!-- New: enrollment with verification -->
<fivucsas-verify client-id="..." flow="onboard" template="FINTECH_ONBOARD" />
```

### Biometric Processor Integration

The existing biometric-processor (FastAPI, port 8001) gains new endpoints:

| Existing Endpoint | Reused For |
|-------------------|------------|
| `POST /verify` (DeepFace) | FACE_MATCH step (live face vs document photo) |
| `POST /detect` (YOLO) | DOCUMENT_SCAN step (card detection) |
| `POST /liveness` | LIVENESS_CHECK step |

New endpoints needed on biometric-processor:

| New Endpoint | Purpose |
|-------------|---------|
| `POST /ocr/extract` | DATA_EXTRACT step (Tesseract OCR) |
| `POST /ocr/mrz` | MRZ parsing from document image |
| `POST /face/compare` | Face comparison (two images, not embedding DB) |

---

## 11. Security and Compliance

### Data Classification

| Data Type | Classification | Encryption | Retention | Storage |
|-----------|---------------|------------|-----------|---------|
| Document images | HIGHLY SENSITIVE | AES-256-GCM at rest | Configurable (default 30 days) | Encrypted blob storage |
| NFC chip data | HIGHLY SENSITIVE | AES-256-GCM at rest | Configurable (default 30 days) | Encrypted JSONB |
| Extracted personal data | SENSITIVE | AES-256 at DB level | Duration of user account | PostgreSQL encrypted columns |
| Face match scores | INTERNAL | Standard DB encryption | Duration of user account | verification_results.step_scores |
| Verification status | INTERNAL | Standard DB encryption | Duration of user account | verification_results.status |
| Video recordings | HIGHLY SENSITIVE | AES-256-GCM at rest | Configurable (default 365 days) | Encrypted blob storage |

### GDPR Compliance

| Requirement | Implementation |
|-------------|---------------|
| Right to access | `GET /api/v1/verification/results/{userId}` returns all stored data |
| Right to erasure | Document images and extracted data purged on request; verification status retained with anonymized reference |
| Data minimization | Only necessary fields extracted and stored; raw images deleted after configurable retention |
| Consent | Explicit consent collected before each verification step that processes personal data |
| Data portability | Export verification results in JSON format |
| Processing records | Full audit trail in `audit_logs` table |

### KVKK (Turkish Data Protection)

| Requirement | Implementation |
|-------------|---------------|
| Explicit consent for biometric data | Consent dialog before face capture and document scanning |
| Data controller registration | Tenant registered as data controller; FIVUCSAS as processor |
| Cross-border transfer | All data processed and stored on Hetzner (Germany, EU); no transfer to non-adequate countries |
| Data breach notification | 72-hour notification mechanism via webhook + email |
| Personal data inventory | Automated inventory via verification_documents + verification_results tables |

### PCI DSS

No credit card data is stored in FIVUCSAS. The CREDIT_CHECK step queries an external bureau and stores only the risk level and score — no financial instrument data.

### Encryption Architecture

```
                    ENCRYPTION LAYERS

  Layer 1: Transport (TLS 1.3)
  ┌──────────────────────────────────────────────┐
  │ Client ←──── HTTPS (TLS 1.3) ────→ Server   │
  └──────────────────────────────────────────────┘

  Layer 2: Application (AES-256-GCM)
  ┌──────────────────────────────────────────────┐
  │ Document images + video recordings           │
  │ Encrypted with per-tenant key before storage │
  │ Key management: AWS KMS / HashiCorp Vault    │
  └──────────────────────────────────────────────┘

  Layer 3: Database (PostgreSQL TDE)
  ┌──────────────────────────────────────────────┐
  │ All verification tables encrypted at rest    │
  │ via PostgreSQL transparent data encryption   │
  └──────────────────────────────────────────────┘

  Layer 4: Backup (GPG)
  ┌──────────────────────────────────────────────┐
  │ Database backups encrypted with GPG keys     │
  │ (existing infrastructure from server setup)  │
  └──────────────────────────────────────────────┘
```

### Audit Trail

Every verification action produces an audit log entry:

```
audit_logs entries for a single verification pipeline:
  VERIFICATION_SESSION_STARTED
  VERIFICATION_STEP_STARTED     (step: DOCUMENT_SCAN)
  VERIFICATION_STEP_COMPLETED   (step: DOCUMENT_SCAN, confidence: 0.97)
  VERIFICATION_STEP_STARTED     (step: NFC_CHIP_READ)
  VERIFICATION_STEP_COMPLETED   (step: NFC_CHIP_READ)
  VERIFICATION_STEP_STARTED     (step: DATA_EXTRACT)
  VERIFICATION_STEP_COMPLETED   (step: DATA_EXTRACT)
  VERIFICATION_STEP_STARTED     (step: FACE_MATCH)
  VERIFICATION_STEP_FAILED      (step: FACE_MATCH, attempt: 1, reason: BELOW_THRESHOLD)
  VERIFICATION_STEP_STARTED     (step: FACE_MATCH, attempt: 2)
  VERIFICATION_STEP_COMPLETED   (step: FACE_MATCH, score: 0.89)
  ...
  VERIFICATION_COMPLETED        (status: VERIFIED, confidence: 0.94)
  USER_IDENTITY_VERIFIED        (userId: ..., level: HIGH)
```

### Rate Limiting

| Endpoint | Rate Limit | Window |
|----------|-----------|--------|
| `POST /verification/sessions` | 5 | per hour per user |
| `POST /verification/sessions/{id}/steps/{n}` | 10 | per minute per session |
| `GET /verification/templates` | 60 | per minute per IP |
| `POST /verification/templates/{id}/apply` | 3 | per hour per tenant |

---

## 12. Implementation Roadmap

### Phase 8A: Schema + Core API (Week 1-2)

| Task | Deliverable | Effort |
|------|-------------|--------|
| V26 Flyway migration | New tables + columns | 1 day |
| JPA entities | VerificationResult, VerificationDocument, VerificationSession | 1 day |
| Spring Data repositories | 3 repositories with custom queries | 1 day |
| VerificationService | Pipeline orchestration logic | 2 days |
| VerificationController | 6 REST endpoints | 1 day |
| VerificationStepExecutor | Step dispatch + handler interface | 1 day |
| Unit tests | Service + controller tests | 2 days |
| **Total** | | **~9 days** |

### Phase 8B: Document Scan + OCR (Week 3-4)

| Task | Deliverable | Effort |
|------|-------------|--------|
| DocumentScanHandler | Integrates with existing YOLO CardDetector | 1 day |
| Tesseract OCR integration | New biometric-processor endpoint `/ocr/extract` | 2 days |
| MRZ parser | Parse Machine Readable Zone from documents | 1 day |
| DataExtractHandler | Orchestrates OCR + MRZ + field validation | 1 day |
| Browser DocumentScanStep | Camera UI + YOLO bounding box (reuse existing) | 2 days |
| DataExtractStep component | OCR results display + manual correction | 1 day |
| Integration tests | End-to-end document flow | 1 day |
| **Total** | | **~9 days** |

### Phase 8C: Face-to-Document Matching (Week 5-6)

| Task | Deliverable | Effort |
|------|-------------|--------|
| FaceMatchHandler | Calls biometric-processor `/face/compare` | 1 day |
| `/face/compare` endpoint | DeepFace comparison of two images (not DB lookup) | 1 day |
| LivenessCheckHandler | Reuses existing liveness infrastructure | 1 day |
| FaceMatchStep component | Side-by-side live face vs document photo | 2 days |
| LivenessCheckStep component | Reuses existing liveness puzzle UI | 1 day |
| Threshold tuning | Calibrate face match thresholds per document type | 2 days |
| **Total** | | **~8 days** |

### Phase 8D: Industry Templates + Admin UI (Week 7-8)

| Task | Deliverable | Effort |
|------|-------------|--------|
| VerificationTemplateService | Template definitions + apply logic | 2 days |
| VerificationTemplateController | Template listing + apply endpoints | 1 day |
| VerificationFlowBuilderPage | Flow builder with verification tab | 3 days |
| TemplateSelector component | Industry template picker with preview | 1 day |
| VerificationDashboardPage | Pipeline analytics dashboard | 2 days |
| VerificationReviewPage | Manual review for flagged cases | 2 days |
| **Total** | | **~11 days** |

### Phase 8E: External Integrations (Week 9-10)

| Task | Deliverable | Effort |
|------|-------------|--------|
| WatchlistCheckHandler | MASAK + sanctions list screening | 2 days |
| AddressProofHandler | Address document OCR + validation | 2 days |
| CreditCheckHandler | KKB/Findeks API integration | 2 days |
| PhoneVerificationHandler | Reuses existing SMS_OTP infrastructure | 1 day |
| AgeVerificationHandler | DOB calculation from extracted data | 0.5 days |
| VideoInterviewHandler | Video recording + encrypted storage | 2 days |
| NfcChipReadHandler | Bridges to existing KMP NFC library | 1.5 days |
| 3rd party API mocks | Mock services for development/testing | 1 day |
| **Total** | | **~12 days** |

### Phase Summary

| Phase | Duration | Key Output |
|-------|----------|------------|
| 8A: Schema + API | 2 weeks | V26 migration, 6 endpoints, pipeline engine |
| 8B: Document + OCR | 2 weeks | Document scanning, OCR, data extraction |
| 8C: Face Matching | 2 weeks | Face-to-document comparison, liveness |
| 8D: Templates + UI | 2 weeks | 9 templates, admin dashboard, flow builder |
| 8E: Integrations | 2 weeks | Watchlist, credit, address, phone, video |
| **Total** | **~10 weeks** | **Full verification platform** |

### Dependency Graph

```
Phase 8A ─────┬─────→ Phase 8B ─────→ Phase 8C
(Schema+API)  │       (Doc+OCR)       (Face Match)
              │                              │
              └─────→ Phase 8D ──────────────┘
                      (Templates+UI)         │
                                             │
                      Phase 8E ◄─────────────┘
                      (Integrations)
```

Phase 8A is the foundation. Phases 8B and 8D can start in parallel after 8A. Phase 8C requires 8B (needs document photos). Phase 8E requires 8C (needs face matching working).

---

## 13. Existing Assets We Can Reuse

One of FIVUCSAS's strengths is the large amount of existing infrastructure that the verification pipeline can build upon. This section maps existing components to their verification pipeline roles.

### Component Reuse Map

| Existing Component | Location | Verification Role | Reuse Level |
|-------------------|----------|-------------------|-------------|
| **YOLO CardDetector** | `biometric-processor/app/services/card_detector.py` | DOCUMENT_SCAN step | Direct reuse (already detects tc_kimlik, passport, etc.) |
| **NFC Reader Library** | `client-apps/shared/commonMain/.../nfc/` (11,089 lines, 43 files) | NFC_CHIP_READ step | Direct reuse (ICAO 9303 parsing, MRZ, chip auth) |
| **DeepFace Verification** | `biometric-processor/app/services/face_service.py` | FACE_MATCH step | Extend (need two-image compare, not DB lookup) |
| **Passive Liveness** | `biometric-processor/app/services/liveness_service.py` | LIVENESS_CHECK step | Direct reuse |
| **BiometricPuzzle** | `web-app/src/lib/biometric-engine/BiometricPuzzle.ts` | LIVENESS_CHECK (active) | Direct reuse (14-challenge puzzle system) |
| **SMS OTP Service** | `identity-core-api/.../SmsService.java` (Twilio) | PHONE_VERIFICATION step | Direct reuse |
| **Auth Flow Engine** | `identity-core-api/.../ManageAuthFlowService.java` | Pipeline orchestration | Extend (add flow_type routing) |
| **Auth Session Tracking** | `identity-core-api/.../AuthSessionService.java` | Session lifecycle | Extend (add verification result linking) |
| **Auth Flow Builder UI** | `web-app/src/features/auth-flows/` | Verification flow builder | Extend (add verification tab + step types) |
| **Multi-Step Auth UI** | `web-app/src/features/auth/components/MultiStepAuthFlow.tsx` | User-facing verification flow | Extend (add verification step components) |
| **FaceLandmarker** | `web-app/src/lib/biometric-engine/` (MediaPipe) | Face quality for FACE_MATCH | Direct reuse |
| **Embeddable Widget** | `verify-app/` + `@fivucsas/auth-js` | Widget-embedded verification | Extend (add verification flow types) |
| **OAuth 2.0 Endpoints** | `identity-core-api/.../OAuth2Controller.java` | Verification scope distribution | Extend (add identity scopes) |
| **Audit Logging** | `identity-core-api/.../AuditLogAdapter.java` | Verification audit trail | Direct reuse (add new action types) |
| **Rate Limiting** | `identity-core-api/.../RateLimitingService.java` | API rate limits | Direct reuse |

### New Components Required

| Component | Why New | Estimated Size |
|-----------|---------|----------------|
| Tesseract OCR integration | No existing OCR capability | ~500 lines (Python) |
| MRZ parser | Specialized passport/ID parsing | ~300 lines (Python) |
| Watchlist API client | No existing sanctions screening | ~400 lines (Java) |
| Credit bureau API client | No existing credit integration | ~400 lines (Java) |
| Video recording + storage | No existing video capture pipeline | ~600 lines (TS + Java) |
| Verification step components (11) | New UI for each verification step | ~2,000 lines (TSX) |
| VerificationService + handlers | Pipeline orchestration | ~1,500 lines (Java) |
| **Total new code estimate** | | **~5,700 lines** |

### Lines of Code Leverage

```
Reused existing code:    ~25,000 lines
  - NFC library:          11,089 lines
  - Biometric engine:      6,500 lines
  - Auth flow system:      3,000 lines
  - Face/liveness:         2,500 lines
  - SMS/OAuth/audit:       1,911 lines

New code:                 ~5,700 lines

Reuse ratio:              ~81% reuse, ~19% new
```

This high reuse ratio is possible because the verification pipeline is an extension of the existing flow engine rather than a parallel system. The key architectural decision -- extending `auth_flows` with `flow_type` instead of creating a separate `verification_flows` table -- enables this reuse.

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| **KYC** | Know Your Customer -- regulatory requirement for identity verification |
| **AML/CFT** | Anti-Money Laundering / Combating the Financing of Terrorism |
| **BDDK** | Banking Regulation and Supervision Agency (Turkey) |
| **MASAK** | Financial Crimes Investigation Board (Turkey) |
| **KVKK** | Personal Data Protection Law (Turkey, similar to GDPR) |
| **MRZ** | Machine Readable Zone -- text at bottom of passports/IDs |
| **ICAO 9303** | International standard for machine-readable travel documents |
| **PA** | Passive Authentication -- verifies document digital signature |
| **AA** | Active Authentication -- proves NFC chip is genuine (not cloned) |
| **PEP** | Politically Exposed Person -- individual with public function |
| **KKB** | Kredi Kayit Burosu -- Turkish credit bureau |
| **TC Kimlik** | Turkish national identity card |
| **Ehliyet** | Turkish driver's license |
| **IVP** | Identity Verification Platform |

## Appendix B: Configuration Defaults by Template

```json
{
  "BANKING_KYC": {
    "DOCUMENT_SCAN": { "acceptedDocuments": ["tc_kimlik", "passport"], "minDetectionConfidence": 0.85 },
    "NFC_CHIP_READ": { "requirePassiveAuth": true, "requireActiveAuth": false },
    "DATA_EXTRACT": { "ocrEngine": "tesseract", "minFieldConfidence": 0.80 },
    "FACE_MATCH": { "matchThreshold": 0.75, "distanceMetric": "cosine" },
    "LIVENESS_CHECK": { "passiveThreshold": 0.70, "activeRequired": true, "activeChallengeCount": 3 },
    "WATCHLIST_CHECK": { "lists": ["MASAK", "OFAC_SDN", "EU_SANCTIONS"], "includePEP": true },
    "ADDRESS_PROOF": { "maxDocumentAge": 90, "requireAddressMatch": true }
  },
  "BANKING_LIGHT": {
    "DOCUMENT_SCAN": { "acceptedDocuments": ["tc_kimlik", "passport"], "minDetectionConfidence": 0.80 },
    "FACE_MATCH": { "matchThreshold": 0.70, "distanceMetric": "cosine" },
    "LIVENESS_CHECK": { "passiveThreshold": 0.65, "activeRequired": false }
  },
  "HEALTHCARE": {
    "DOCUMENT_SCAN": { "acceptedDocuments": ["tc_kimlik"], "minDetectionConfidence": 0.80 },
    "DATA_EXTRACT": { "ocrEngine": "tesseract", "requiredFields": ["fullName", "idNumber", "dateOfBirth"] },
    "FACE_MATCH": { "matchThreshold": 0.65, "distanceMetric": "cosine" },
    "LIVENESS_CHECK": { "passiveThreshold": 0.65, "activeRequired": false }
  },
  "EDUCATION": {
    "DOCUMENT_SCAN": { "acceptedDocuments": ["ogrenci_karti", "tc_kimlik"], "minDetectionConfidence": 0.75 },
    "FACE_MATCH": { "matchThreshold": 0.60, "distanceMetric": "cosine" },
    "LIVENESS_CHECK": { "passiveThreshold": 0.60, "activeRequired": false }
  },
  "GOVERNMENT_EKYC": {
    "NFC_CHIP_READ": { "requirePassiveAuth": true, "requireActiveAuth": true },
    "DATA_EXTRACT": { "ocrEngine": "tesseract", "minFieldConfidence": 0.85 },
    "FACE_MATCH": { "matchThreshold": 0.75, "distanceMetric": "cosine" },
    "LIVENESS_CHECK": { "passiveThreshold": 0.75, "activeRequired": true, "activeChallengeCount": 5 }
  }
}
```
