# EU AI Act Compliance Analysis
## FIVUCSAS - Face and Identity Verification Using Cloud-Based SaaS

**Document Version:** 1.0
**Date:** February 20, 2026
**Project:** FIVUCSAS Biometric Authentication Platform
**Organization:** Marmara University - Computer Engineering Department
**Course:** CSE4297/CSE4197 Engineering Project
**Team:** Ahmet Abdullah Gultekin, Ayse Gulsum Eren, Aysenur Arici
**Advisor:** Assoc. Prof. Dr. Mustafa Agaoglu

---

## Table of Contents

1. [Introduction and Scope](#1-introduction-and-scope)
2. [Classification Under the EU AI Act](#2-classification-under-the-eu-ai-act)
3. [Data Minimization](#3-data-minimization)
4. [Purpose Limitation](#4-purpose-limitation)
5. [Right to Erasure](#5-right-to-erasure)
6. [Transparency and User Notification](#6-transparency-and-user-notification)
7. [Technical Security Measures](#7-technical-security-measures)
8. [Human Oversight and Governance](#8-human-oversight-and-governance)
9. [Risk Assessment](#9-risk-assessment)
10. [Documentation and Record-Keeping](#10-documentation-and-record-keeping)
11. [Compliance Summary Matrix](#11-compliance-summary-matrix)
12. [Limitations and Academic Context](#12-limitations-and-academic-context)
13. [References](#13-references)

---

## 1. Introduction and Scope

### 1.1 Document Purpose

This document analyses the FIVUCSAS platform against the requirements of **Regulation (EU) 2024/1689 of the European Parliament and of the Council**, commonly known as the **EU Artificial Intelligence Act (EU AI Act)**, which entered into force on August 1, 2024, with phased application dates through 2026–2027.

The analysis covers all system components that process biometric data:

- **Identity Core API** — Spring Boot 3.2 / Java 21, deployed on Hetzner VPS (116.203.222.213:8080)
- **Biometric Processor** — FastAPI / Python, using DeepFace for face recognition
- **Web Admin Dashboard** — React 18 / TypeScript, deployed at ica-fivucsas.rollingcatsoftware.com
- **Client Applications** — Kotlin Multiplatform (Android, Desktop)
- **PostgreSQL 16 + pgvector** — Embedding storage layer

### 1.2 What FIVUCSAS Does

FIVUCSAS is a multi-tenant, cloud-based biometric authentication platform that enables organizations (tenants) to authenticate their users through configurable multi-step authentication flows. Supported authentication methods include:

| Method | Category | Biometric? |
|--------|----------|------------|
| Password | Basic | No |
| Email OTP | Standard | No |
| SMS OTP | Standard | No |
| TOTP (Authenticator app) | Standard | No |
| QR Code | Standard | No |
| Face Recognition | Premium | **Yes** |
| Fingerprint | Premium | **Yes** |
| Voice | Enterprise | **Yes** |
| Hardware Key (WebAuthn) | Enterprise | No |
| NFC Document | Enterprise | No |

Biometric methods — face, fingerprint, and voice — are the components that bring the system within scope of the EU AI Act's high-risk provisions.

---

## 2. Classification Under the EU AI Act

### 2.1 Regulatory Classification: High-Risk AI System

FIVUCSAS falls within the **high-risk** category as defined by **Article 6** and **Annex III** of the EU AI Act.

**Relevant provision — Annex III, Point 1(a):**

> "AI systems intended to be used for biometric identification of natural persons, with the exception of AI systems intended to be used for the verification or authentication of natural persons for the sole purpose of confirming that a specific natural person is who this person claims to be."

FIVUCSAS operates in **verification mode (1:1 matching)** rather than remote biometric identification mode (1:N identification against an unknown population), which places it closer to the exception carved out in Annex III. However, the system also supports **1:N face search** (`POST /api/v1/search`) through the Biometric Processor, which is the more regulated use case.

**Classification determination:**

| Use Case | Classification | Basis |
|----------|---------------|-------|
| 1:1 face verification for login | High-Risk (borderline exception) | Annex III, Point 1(a) — verification for authentication |
| 1:N face search | High-Risk | Annex III, Point 1(a) — identification in real environments |
| Liveness detection | Supporting component | Part of the biometric pipeline |
| Fingerprint / Voice verification | High-Risk | Annex III, Point 1(a) — biometric authentication |

**Conservative approach:** This document treats the entire FIVUCSAS biometric pipeline as **high-risk** to ensure full compliance with Chapter III, Section 2 of the EU AI Act.

### 2.2 Obligations for High-Risk AI Systems

Under Article 16 of the EU AI Act, providers of high-risk AI systems must:

1. Establish a quality management system (Article 17)
2. Draw up technical documentation (Article 11)
3. Keep logs automatically generated (Article 12)
4. Ensure transparency and provide instructions for use (Article 13)
5. Ensure human oversight measures (Article 14)
6. Achieve required levels of accuracy, robustness, and cybersecurity (Article 15)
7. Conduct a conformity assessment before placing on the market (Article 43)

The sections below address how FIVUCSAS meets each obligation.

---

## 3. Data Minimization

### 3.1 Principle (GDPR Article 5(1)(c) + EU AI Act Article 10)

FIVUCSAS applies strict data minimization: **only mathematical vector representations (embeddings) of biometric features are stored, not the original biometric images.**

### 3.2 Face Recognition — Embedding-Only Storage

The biometric data pipeline is:

```
User presents face to camera
         |
         v
DeepFace extracts embedding vector
(FaceNet512: 512 dimensions, ArcFace: 512 dimensions, FaceNet: 128 dimensions)
         |
         v
Raw image is discarded from memory (never persisted)
         |
         v
Embedding vector stored in PostgreSQL via pgvector extension
```

This is enforced at the database schema level. The `biometric_data` table (Flyway migration V4) stores only:

```sql
embedding vector(512), -- pgvector embedding (no raw image)
embedding_model VARCHAR(50),
embedding_dimension INTEGER,
quality_score FLOAT,
liveness_verified BOOLEAN,
-- Image metadata only (not the image itself):
image_width INTEGER,
image_height INTEGER,
image_format VARCHAR(10),
face_detected_confidence FLOAT
```

The schema comment explicitly states: `-- Original image metadata (not storing actual image for privacy)`.

### 3.3 Why Embeddings Cannot Reconstruct Original Faces

Face embeddings are the output of a one-way mathematical transformation:

- A 512-dimensional vector represents distances in a learned feature space
- The transformation is **not invertible** — there is no mathematical function to reverse a 512-float array back to a recognizable face image
- Different faces can produce similar distances in embedding space, making reconstruction ambiguous even in theory
- The models (FaceNet512, ArcFace) are trained for discrimination, not reconstruction

This is analogous to a cryptographic hash: the output reveals nothing about the input other than a similarity metric when compared to another embedding.

### 3.4 Supported Embedding Models and Dimensions

| Model | Dimensions | Purpose |
|-------|-----------|---------|
| FaceNet | 128 | Default, fast matching |
| FaceNet512 | 512 | High accuracy |
| ArcFace | 512 | State-of-the-art accuracy |
| VGG-Face | 2622 | Alternative model |

All model outputs are stored as `vector(n)` types in PostgreSQL using the pgvector extension, enabling efficient cosine similarity search without storing any image data.

### 3.5 Fingerprint and Voice Data

The same principle applies to fingerprint and voice biometrics. The `biometric_type` field in `biometric_data` supports `FACE`, `FINGERPRINT`, `VOICE`, and `IRIS` types. In all cases, only the embedding representation is stored, not audio recordings or fingerprint images.

---

## 4. Purpose Limitation

### 4.1 Principle (GDPR Article 5(1)(b) + EU AI Act Article 10)

Biometric data collected by FIVUCSAS is used **exclusively for authentication** of users who have explicitly enrolled. The system has no capability for surveillance, tracking, or profiling.

### 4.2 Authentication-Only Design

The authentication flow is initiated **by the user** through one of:

- Mobile application (Kotlin Multiplatform)
- Desktop kiosk application (Kotlin Multiplatform)
- Web application

In all cases, the user actively initiates an authentication attempt. The system never passively captures or processes biometric data from individuals who have not enrolled and are not actively authenticating.

**No continuous monitoring:** FIVUCSAS does not run persistent background processes that capture or analyze biometric data. All biometric processing is **request-scoped** — it starts when an authentication request arrives and ends when the response is returned.

### 4.3 Multi-Tenant Isolation

The `biometric_data` table enforces tenant-level isolation through:

```sql
tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE
```

Combined with **row-level security** patterns and JWT-scoped authorization (`@PreAuthorize` on all endpoints), it is architecturally impossible for:

- One tenant's users to access another tenant's biometric data
- Cross-tenant face searches to occur
- A user's biometric data to be used for purposes other than their own authentication

### 4.4 No Profiling Capabilities

While the Biometric Processor includes a demographics analysis endpoint (`POST /api/v1/demographics/analyze` — providing age, gender, and emotion estimates), this endpoint:

- Is part of the **research and demonstration** capability of the biometric library
- Is **not integrated** into the Identity Core API authentication pipeline
- Is not accessible to end users through any client application
- Is documented as a biometric processing research tool, not an authentication feature

The core authentication endpoints (`POST /api/v1/auth/login`, biometric verification steps) do not invoke demographics analysis.

---

## 5. Right to Erasure

### 5.1 Principle (GDPR Article 17 + EU AI Act Article 12)

Data subjects have the right to request deletion of their biometric data. FIVUCSAS implements this at both the API level and database level.

### 5.2 API-Level Deletion Endpoints

The Identity Core API exposes dedicated endpoints for biometric data management:

```
DELETE /api/v1/enrollments/{enrollmentId}
```

This endpoint:
- Requires authentication (JWT bearer token)
- Validates that the requesting user owns the enrollment or has admin privileges
- Performs a **soft delete** by setting `deleted_at = CURRENT_TIMESTAMP` on the `biometric_data` record
- Excludes soft-deleted records from all active indexes and queries via partial index conditions (`WHERE deleted_at IS NULL`)

The partial unique index `uq_biometric_user_tenant_type` uses `WHERE deleted_at IS NULL`, ensuring that deleted records are logically invisible to all application queries.

### 5.3 Cascade Deletion on User Account Deletion

The database enforces cascading deletion:

```sql
user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
```

When a user account is deleted, all associated biometric data is automatically and irrevocably deleted by the database engine. This ensures that no orphaned biometric embeddings remain after account deletion.

### 5.4 Tenant Account Deletion

Similarly:

```sql
tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE
```

Deleting a tenant removes all users and all biometric data for that tenant in a single transaction.

### 5.5 Audit Trail for Deletion Events

All deletion operations are recorded in the `audit_logs` table:

```sql
CREATE TABLE audit_logs (
    action VARCHAR(100) NOT NULL,      -- 'BIOMETRIC_ENROLLMENT_DELETED'
    resource_type VARCHAR(100) NOT NULL, -- 'biometric_data'
    resource_id UUID,                  -- ID of deleted enrollment
    user_id UUID,                      -- Who requested deletion
    old_values JSONB,                  -- Previous state (without embedding data)
    success BOOLEAN NOT NULL,
    ip_address VARCHAR(45),
    created_at TIMESTAMP NOT NULL
);
```

Deletion audit logs are retained for one year per the `cleanup_old_audit_logs()` database function, satisfying accountability requirements while not retaining the biometric data itself indefinitely.

---

## 6. Transparency and User Notification

### 6.1 Principle (EU AI Act Articles 13 and 52)

**Article 52** of the EU AI Act requires that users be informed when they are interacting with an AI system, particularly when that system processes biometric data or generates/manipulates content.

**Article 13** requires high-risk AI systems to be sufficiently transparent to enable users to interpret and use the system's output correctly.

### 6.2 Explicit Biometric Step Disclosure

The multi-step authentication UI (implemented in both the React web dashboard and Kotlin Multiplatform client apps) presents each authentication step explicitly to the user before biometric capture begins.

The step-progress component shows:
- Which step the user is currently on (e.g., "Step 2 of 3: Face Verification")
- What biometric modality is required
- Clear visual instructions for how to position for face capture

Users are **never surprised** by biometric capture — each biometric step is a discrete, user-initiated action.

### 6.3 Active Consent Through Action

FIVUCSAS does not use passive biometric capture. Face recognition requires the user to:

1. Read the step instruction ("Position your face in the camera frame")
2. Actively position themselves in front of the camera
3. Observe real-time feedback as the face is detected
4. Receive confirmation when verification succeeds or a retry prompt when it fails

This constitutes **informed, active participation** in biometric processing rather than background surveillance.

### 6.4 Enrollment Transparency

During biometric enrollment, users are presented with:
- Explicit notification that a face embedding will be stored
- Information about the purpose (authentication only)
- The ability to cancel enrollment at any point

The enrollment UI (`BiometricEnrollScreen` in the Android app, the kiosk enrollment screen in the desktop app) makes the process visible step by step.

### 6.5 Liveness Detection Disclosure

The liveness detection challenge (biometric puzzle) is a visible, interactive process:

- Users are shown a sequence of head movements or blink prompts
- The system explains why liveness detection is required (anti-spoofing)
- Completion is confirmed with visual feedback

This transparency prevents users from being confused about why a simple photo does not suffice for authentication.

---

## 7. Technical Security Measures

### 7.1 Overview (EU AI Act Article 15 — Accuracy, Robustness, and Cybersecurity)

Article 15 requires high-risk AI systems to achieve an appropriate level of accuracy and to be resilient against attempts by unauthorized third parties to alter their use or outputs. The following measures address these requirements.

### 7.2 Encryption

| Data Type | Protection Mechanism | Standard |
|-----------|---------------------|----------|
| Biometric embeddings at rest | PostgreSQL table encryption | AES-256 |
| Sensitive fields (ID numbers, etc.) | Application-level AES-256 encryption before storage | AES-256 |
| Passwords | BCrypt hashing | BCrypt, work factor 12 |
| Data in transit | TLS 1.2+ (HTTPS/NGINX) | TLS 1.2+ |
| JWT tokens | HS512 signing | HMAC-SHA512 |
| Refresh tokens | SHA-256 hashed before storage | SHA-256 |

Passwords are never stored in plaintext. BCrypt with work factor 12 means each hash computation takes approximately 250–500ms, making brute-force attacks computationally infeasible at scale.

### 7.3 Authentication and Authorization

- **JWT access tokens** with short expiry (configurable per tenant, default 30 minutes)
- **Refresh token rotation** — each use of a refresh token issues a new token and invalidates the previous one
- **Role-Based Access Control (RBAC)** — `@PreAuthorize` annotations on all endpoints; no endpoint is publicly accessible without appropriate authorization
- **Multi-tenant JWT claims** — tokens are scoped to a specific tenant and cannot be used cross-tenant

### 7.4 Rate Limiting

A persistent token-bucket rate limiting system (Flyway migration V9) protects all biometric endpoints:

| Endpoint Category | Burst Limit | Sustained Rate |
|-------------------|-------------|---------------|
| `POST /api/auth/login` | 100 requests | 5 req/sec |
| `POST /api/auth/register` | 50 requests | 2 req/sec |
| Global API | 10,000 requests | 100 req/sec |
| Biometric enrollment | Configurable | ~10 req/min per user |
| Biometric verification | Configurable | ~30 req/min per user |

Rate limits are enforced using an atomic PostgreSQL function (`consume_rate_limit_tokens`) and supported by Redis caching. Blocked requests receive `HTTP 429 Too Many Requests` with a `Retry-After` header.

### 7.5 Anti-Spoofing and Liveness Detection

The biometric processor implements multiple layers of spoofing defence, addressing EU AI Act Article 15's robustness requirements:

**Passive Liveness Analysis:**
- Texture analysis using Local Binary Patterns (LBP)
- Color distribution analysis (screen-displayed photos have different color profiles)
- Frequency domain analysis (Moire pattern detection from printed photos)
- Custom CNN model for passive liveness scoring

**Active Liveness Challenge (Biometric Puzzle):**
- Eye Aspect Ratio (EAR) measurement for blink detection
- Mouth Aspect Ratio (MAR) measurement for smile/mouth movement detection
- Head pose estimation (pitch, yaw, roll) requiring random head movements
- Random challenge sequence generation — attackers cannot replay a recorded challenge response

The liveness verification status is stored per enrollment:

```sql
liveness_verified BOOLEAN DEFAULT FALSE,
liveness_score FLOAT,
liveness_method VARCHAR(50) DEFAULT 'BIOMETRIC_PUZZLE'
```

All liveness attempts are logged in the `liveness_attempts` table regardless of success or failure, providing a complete audit trail of spoof attempts.

### 7.6 Vector Similarity Index

Face matching uses cosine similarity on the embedding vectors via pgvector:

```sql
-- IVFFlat index for approximate nearest neighbor search
CREATE INDEX idx_biometric_embedding_ivfflat
    ON biometric_data
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
    WHERE deleted_at IS NULL AND is_active = TRUE;
```

The system is also configured to support HNSW (Hierarchical Navigable Small World) indexing, which provides higher accuracy at the cost of greater memory usage. The chosen threshold for matching is configurable per tenant, allowing organizations to tune the security/convenience tradeoff based on their use case.

### 7.7 Security Event Logging

A dedicated `security_events` table captures high-severity security incidents:

```sql
event_type VARCHAR(100) NOT NULL, -- 'LOGIN_FAILED', 'ACCOUNT_LOCKED', 'SUSPICIOUS_ACTIVITY'
severity VARCHAR(20) NOT NULL,    -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
```

Unresolved security events are tracked and can be reviewed by administrators through the web dashboard.

---

## 8. Human Oversight and Governance

### 8.1 Principle (EU AI Act Article 14)

Article 14 requires that high-risk AI systems be designed and developed in such a way as to allow natural persons to effectively oversee the system during use. This includes the ability to interrupt, override, or correct the system's output.

### 8.2 Administrative Dashboard

The web admin dashboard (`https://ica-fivucsas.rollingcatsoftware.com`) provides full human oversight capabilities to authorized administrators:

| Capability | Dashboard Feature |
|-----------|------------------|
| Monitor all authentication events | Audit Logs page with filters |
| Review all biometric enrollments | Enrollments admin page |
| Suspend or deactivate users | Users CRUD with status management |
| Revoke biometric enrollments | Delete enrollment per user |
| View active auth sessions | Auth Sessions page |
| Manage registered devices | Devices admin page |
| Configure authentication flows | Auth Flow Builder |
| Review security events | Security events audit trail |

### 8.3 Configurable Auth Flow Override

Administrators can modify authentication flows at any time through the Auth Flow Builder. This means:

- Biometric steps can be **removed from a flow** at any time (e.g., if the system is experiencing high error rates)
- Alternative authentication methods can be enabled as fallbacks
- Tenant administrators can configure flows appropriate to their users' demographics and accessibility needs

This configurability directly satisfies the "ability to override the AI system's decision" requirement of Article 14.

### 8.4 Audit Log Completeness

Every biometric operation generates an audit log entry with:

- The action taken (`BIOMETRIC_ENROLLMENT_CREATED`, `BIOMETRIC_VERIFICATION_ATTEMPTED`, `BIOMETRIC_ENROLLMENT_DELETED`)
- Whether the action succeeded or failed
- The identity of the user and administrator involved
- Timestamp, IP address, and device information
- Old and new values for change operations (excluding raw biometric data)

Audit logs are retained for one year and are queryable through the admin dashboard with filters for action type, user, date range, and success status.

### 8.5 Oversight of Automated Decisions

Biometric verification results in an automated accept/reject decision. The following oversight mechanisms apply:

- **Verification logs** are stored in `biometric_verification_logs`, including the confidence score, similarity distance, and threshold used
- Administrators can review failed verification attempts to identify systemic accuracy issues
- Users who are repeatedly rejected by biometric authentication retain the ability to use alternative authentication methods (if configured in the auth flow)
- Account lockout policies (configurable per tenant) prevent the automated system from permanently blocking a user without human review

---

## 9. Risk Assessment

### 9.1 Principle (EU AI Act Article 9 — Risk Management System)

Article 9 requires that providers of high-risk AI systems establish, implement, document, and maintain a risk management system throughout the AI system's lifecycle.

### 9.2 False Acceptance Rate (FAR)

**Definition:** FAR is the probability that the system incorrectly accepts an unauthorized person as the genuine user.

| Scenario | Risk Level | Mitigation |
|----------|-----------|-----------|
| Identical twins attempting each other's accounts | High | Multi-factor authentication; tenants can require additional steps |
| High-quality 3D mask attacks | Medium | Liveness detection (active puzzle + passive CNN) |
| Deepfake video attacks | Medium | Texture and frequency analysis in liveness detection |
| Threshold set too low (permissive) | High | Configurable per-tenant threshold with admin oversight |

**Mitigation strategy:** The system is designed so that face recognition is **one step** in a configurable multi-step flow. Tenants handling high-stakes access (financial transactions, secure facilities) can configure two or more biometric steps plus a knowledge factor. No single biometric failure mode results in unauthorized access if the flow requires multiple independent factors.

### 9.3 False Rejection Rate (FRR)

**Definition:** FRR is the probability that the system incorrectly rejects a genuine user.

| Scenario | Impact | Mitigation |
|----------|--------|-----------|
| Poor lighting conditions during verification | User cannot authenticate | Quality analysis endpoint provides real-time feedback; UI guidance on lighting |
| Significant appearance changes (hair, glasses, beard) | User rejected | Periodic re-enrollment recommended; alternative auth methods available |
| Medical conditions affecting facial appearance | User permanently rejected | Admin can disable biometric requirement; fallback methods enforced |
| Camera quality variance across devices | Inconsistent results | Quality score threshold enforced during enrollment (stored in `quality_score` field) |

**Mitigation strategy:** The `quality_score` field ensures that only enrollments meeting a minimum quality threshold are stored. Low-quality enrollments are rejected at enrollment time rather than causing repeated verification failures.

### 9.4 Demographic Bias Considerations

Face recognition systems have documented performance disparities across:
- Skin tone (historically higher error rates for darker skin tones with older models)
- Age (lower accuracy for very young children and elderly users)
- Gender (some models have higher error rates for women)

**FIVUCSAS mitigations:**

1. **Model selection:** ArcFace is among the models with the best-documented cross-demographic performance in academic literature
2. **Quality threshold:** Requiring minimum enrollment quality reduces the impact of poor-quality captures that disproportionately affect certain demographics under specific conditions
3. **Multi-factor fallback:** Users experiencing consistent false rejections can authenticate via password, OTP, or other non-biometric methods
4. **Administrator awareness:** Admins can monitor FRR per user group and adjust thresholds or disable biometric requirements for specific user populations

**Acknowledged limitation:** FIVUCSAS has not conducted its own large-scale demographic bias evaluation. For production deployment, such evaluation is strongly recommended per EU AI Act Article 9(7).

### 9.5 Privacy Risk from Embedding Leakage

**Threat:** If the `biometric_data` table were exfiltrated, could attackers use the embeddings maliciously?

| Attack Vector | Feasibility | Status |
|--------------|-------------|--------|
| Replay attack (submit stolen embedding as API input) | None | API accepts image input, not raw embeddings; embedding extraction happens server-side |
| Reconstruct face from embedding | Near-zero | One-way transformation; no inverse function exists |
| Cross-system use (matching embedding against another system's database) | Low | Embedding format is model-specific and not interoperable across different model architectures |
| Brute-force image synthesis to match embedding | Very high computational cost | 512-dimensional cosine space; enumeration is computationally infeasible |

**Conclusion:** Even in the event of a database breach, the stored embeddings provide minimal actionable biometric information to an attacker compared to storing raw images.

### 9.6 Multi-Factor Risk Reduction Summary

The most significant architectural risk mitigation is the **multi-factor authentication flow**. By treating biometric verification as one factor among several:

- A compromised biometric factor does not alone grant access
- A system error in the biometric subsystem does not prevent all authentication
- Users retain autonomy to choose whether to enroll in biometric authentication
- Tenants can calibrate the security-convenience balance for their specific user base

---

## 10. Documentation and Record-Keeping

### 10.1 Principle (EU AI Act Articles 11 and 12)

Article 11 requires technical documentation to be drawn up before the high-risk AI system is placed on the market. Article 12 requires that high-risk AI systems automatically generate logs that allow traceability of operation.

### 10.2 API Documentation

Complete API documentation is maintained and publicly accessible:

| Documentation | Location | Format |
|--------------|----------|--------|
| Identity Core API | http://116.203.222.213:8080/swagger-ui.html | OpenAPI 3.0 / Swagger UI |
| Biometric Processor API | https://bpa-fivucsas.rollingcatsoftware.com/docs | FastAPI auto-generated OpenAPI |
| Architecture Documentation | `docs/02-architecture/` | Markdown, C4 model diagrams |
| API Services Overview | `docs/04-api/SERVICES_OVERVIEW.md` | Markdown |

### 10.3 Architecture Documentation

The `docs/` directory (git submodule) contains:

```
docs/
├── 00-meta/         - Project metadata and module design
├── 01-getting-started/ - Developer onboarding
├── 02-architecture/ - C4 model, UML, system design
├── 03-development/  - Implementation guides, technology decisions
├── 04-api/          - API specifications and service overview
├── 05-testing/      - Test guides and coverage reports
├── 06-deployment/   - Deployment procedures
├── 07-status/       - Implementation status reports
└── 09-auth-flows/   - Multi-modal auth flow documentation (10 documents)
```

### 10.4 Automated Operational Logs

FIVUCSAS automatically generates the following logs relevant to Article 12:

| Log Type | Table | Retention | Content |
|----------|-------|-----------|---------|
| All API operations | `audit_logs` | 1 year | Action, user, resource, outcome, IP, timestamp |
| Biometric verifications | `biometric_verification_logs` | Indefinite | Model used, confidence score, similarity distance, threshold, outcome |
| Liveness attempts | `liveness_attempts` | Indefinite | Puzzle steps, completion time, success/failure, IP |
| Security events | `security_events` | Indefinite | Event type, severity, action taken, resolution status |
| Authentication sessions | `auth_session_steps` | Session lifetime + archive | Each authentication step's status and timestamp |

### 10.5 Database Migration History

All database schema changes are version-controlled through Flyway migrations:

| Migration | Description | Compliance Relevance |
|-----------|-------------|---------------------|
| V0 | Enable extensions (uuid, pgvector) | Foundation for embedding storage |
| V1 | Tenants table | Multi-tenant isolation |
| V2 | Users table | Data subject records |
| V3 | Roles and permissions | Access control foundation |
| V4 | Biometric tables | Embedding storage (privacy-by-design) |
| V5 | Audit and session tables | Operational log generation |
| V6 | Refresh tokens | Session security |
| V7 | Performance indexes | Operational efficiency |
| V8 | Audit log enhancements | Extended compliance logging |
| V9 | Rate limiting table | Protection against attacks |
| V10 | RBAC and guest lifecycle | Access control refinement |
| V11-V14 | User settings and schema fixes | Ongoing compliance refinement |
| V15 | Sample data seeding | Testing and demonstration |
| V16 | Multi-modal auth flow system | Configurable oversight mechanisms |

This migration history constitutes a documented record of how the system's data handling has evolved, as required by Article 11(1)(e).

### 10.6 Test Coverage Documentation

The Identity Core API maintains **508 unit tests** that pass continuously, covering:
- Auth handler behaviour under valid and invalid inputs
- Multi-step auth flow constraint enforcement
- RBAC enforcement across all endpoints
- Biometric service port behaviour

Test results are generated as part of the CI/CD pipeline (GitHub Actions) on every commit, providing continuous verification of system correctness.

---

## 11. Compliance Summary Matrix

| EU AI Act Requirement | Article | Status | Evidence |
|----------------------|---------|--------|---------|
| High-risk classification acknowledged | Art. 6, Annex III | Addressed | Section 2 of this document |
| Quality management system | Art. 17 | Partial | CI/CD pipeline, 508 tests, Flyway migrations |
| Technical documentation | Art. 11 | Addressed | Swagger UI, docs/ submodule, this document |
| Automatic log generation | Art. 12 | Addressed | audit_logs, biometric_verification_logs, liveness_attempts |
| Transparency to users | Art. 13 | Addressed | Step-by-step auth UI, explicit biometric disclosure |
| Human oversight | Art. 14 | Addressed | Admin dashboard, configurable auth flows, user suspension |
| Accuracy and robustness | Art. 15 | Addressed | Liveness detection, rate limiting, configurable thresholds |
| Data governance | Art. 10 | Addressed | Embedding-only storage, purpose limitation, multi-tenant isolation |
| Risk management system | Art. 9 | Partial | Section 9 of this document; formal bias evaluation pending |
| Conformity assessment | Art. 43 | Pending | University project; formal certification not in scope |
| Right to erasure | GDPR Art. 17 | Addressed | DELETE /enrollments/{id}, CASCADE deletion |
| Data minimization | GDPR Art. 5(1)(c) | Addressed | Embeddings only, raw images discarded |
| Purpose limitation | GDPR Art. 5(1)(b) | Addressed | Authentication only, no profiling |
| User notification (biometric AI) | Art. 52 | Addressed | Explicit step disclosure, active consent by action |

**Legend:**
- **Addressed** — Requirement is fully implemented
- **Partial** — Requirement is partially met; gaps identified and documented
- **Pending** — Requirement is not applicable at university project scale but would be required for commercial deployment

---

## 12. Limitations and Academic Context

### 12.1 University Project Scope

FIVUCSAS is developed as a **Marmara University engineering capstone project** (CSE4297/CSE4197). Several EU AI Act requirements that would apply to a commercial deployment are acknowledged but not fully implemented within the academic scope:

| Requirement | Commercial Expectation | Current Status |
|------------|----------------------|----------------|
| Formal conformity assessment (Art. 43) | Third-party or self-assessment with notified body | Not conducted |
| CE marking | Required for EU market placement | Not applicable (academic) |
| Registration in EU database (Art. 51) | Required before deployment | Not applicable (academic) |
| Post-market monitoring plan (Art. 72) | Systematic monitoring of deployed system | Partially addressed through audit logs |
| Large-scale demographic bias testing | Cross-demographic FAR/FRR evaluation on diverse datasets | Not conducted; acknowledged as a gap |
| Data Protection Impact Assessment (DPIA) | Required under GDPR Art. 35 for systematic biometric processing | Not formally conducted |

### 12.2 Recommended Steps for Commercial Deployment

If FIVUCSAS were to be developed into a commercial product, the following additional compliance steps would be mandatory:

1. **Conduct a formal DPIA** under GDPR Article 35 before any production deployment with real users
2. **Commission independent demographic bias evaluation** across a diverse face dataset
3. **Engage a legal counsel** to determine whether the system falls under the Annex III exception for pure verification systems or requires full conformity assessment
4. **Implement a post-market monitoring system** with defined KPIs for FAR, FRR, and user complaint tracking
5. **Register the system** in the EU AI Act database (Article 51) if determined to be a non-excepted high-risk system
6. **Draft user-facing documentation** in plain language as required by Article 13(3)
7. **Appoint a Data Protection Officer (DPO)** if processing biometric data at scale

### 12.3 Production Deployment Note

The current deployment at `116.203.222.213:8080` processes biometric data in a **controlled research environment** with a small number of known test users. This does not constitute large-scale commercial biometric processing and falls within the typical academic research exception considered under the EU AI Act's proportionality provisions.

---

## 13. References

### EU Regulatory References

| Document | Citation |
|---------|---------|
| EU AI Act | Regulation (EU) 2024/1689 of the European Parliament and of the Council, OJ L, 2024/1689, 12.7.2024 |
| GDPR | Regulation (EU) 2016/679 of the European Parliament and of the Council (General Data Protection Regulation) |
| EU AI Act Annex III | High-risk AI systems referred to in Article 6(2) |
| EU AI Act Article 6 | Classification rules for high-risk AI systems |
| EU AI Act Article 9 | Risk management system |
| EU AI Act Article 10 | Data and data governance |
| EU AI Act Article 11 | Technical documentation |
| EU AI Act Article 12 | Record-keeping |
| EU AI Act Article 13 | Transparency and provision of information to deployers |
| EU AI Act Article 14 | Human oversight |
| EU AI Act Article 15 | Accuracy, robustness, and cybersecurity |
| EU AI Act Article 52 | Transparency obligations for certain AI systems |

### Technical References

| Technology | Reference |
|-----------|---------|
| DeepFace | Serengil, S.I. and Ozpinar, A. (2020). LightFace: A Hybrid Deep Face Recognition Framework. IEEE ASYU 2020 |
| FaceNet | Schroff, F., Kalenichenko, D., Philbin, J. (2015). FaceNet: A Unified Embedding for Face Recognition and Clustering. CVPR 2015 |
| ArcFace | Deng, J. et al. (2019). ArcFace: Additive Angular Margin Loss for Deep Face Recognition. CVPR 2019 |
| pgvector | PostgreSQL extension for vector similarity search. https://github.com/pgvector/pgvector |
| WebAuthn | W3C Web Authentication API. https://www.w3.org/TR/webauthn-3/ |
| MiniFASNet | Yu, Z. et al. (2020). Searching Central Difference Convolutional Networks for Face Anti-Spoofing. CVPR 2020 |

### Project Internal References

| Document | Path |
|---------|------|
| Implementation Status Report | `docs/IMPLEMENTATION_STATUS_REPORT.md` |
| Architecture Analysis | `docs/02-architecture/ARCHITECTURE_ANALYSIS.md` |
| API Services Overview | `docs/04-api/SERVICES_OVERVIEW.md` |
| Database Schema — Biometric Tables | `identity-core-api/src/main/resources/db/migration/V4__create_biometric_tables.sql` |
| Database Schema — Audit Tables | `identity-core-api/src/main/resources/db/migration/V5__create_audit_and_session_tables.sql` |
| Database Schema — Rate Limiting | `identity-core-api/src/main/resources/db/migration/V9__add_rate_limiting_table.sql` |
| Database Schema — Auth Flows | `identity-core-api/src/main/resources/db/migration/V16__auth_flow_system.sql` |
| Auth Flow Documentation | `docs/09-auth-flows/` (10 documents) |

---

*This document was prepared for the CSE4297/CSE4197 Engineering Project presentation at Marmara University, Computer Engineering Department, February 2026. It reflects the state of the FIVUCSAS platform as of the document date and is intended as a good-faith analysis of compliance considerations, not as a legal opinion or formal conformity assessment.*
