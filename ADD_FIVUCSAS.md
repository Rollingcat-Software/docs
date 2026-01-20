# FACE AND IDENTITY VERIFICATION USING CLOUD BASED SAAS MODELS

## Architectural Design Document (ADD)

---

**CSE4197 Engineering Project 2**

**Marmara University, Faculty of Engineering**
**Computer Engineering Department**

**Spring Semester 2026**

---

**Supervised by:** Assoc. Prof. Dr. Mustafa Ağaoğlu

**Team Members:**
- Ahmet Abdullah Gültekin - 150121025 (Project Lead & Backend Developer)
- Ayşe Gülsüm Eren - 150120005 (Mobile Application Developer)
- Ayşenur Arıcı - 150123825 (AI/ML & Biometric Systems)

---

**Document Version:** 1.0
**Last Updated:** January 2026

---

## Table of Contents

1. [Introduction](#1-introduction)
   - 1.1 [Problem Description](#11-problem-description)
   - 1.2 [Scope](#12-scope)
   - 1.3 [Definitions and Acronyms](#13-definitions-and-acronyms)
2. [Literature Survey](#2-literature-survey)
3. [Project Requirements](#3-project-requirements)
   - 3.1 [Functional Requirements](#31-functional-requirements)
   - 3.2 [Non-Functional Requirements](#32-non-functional-requirements)
4. [System Design](#4-system-design)
   - 4.1 [Use Case Diagrams](#41-use-case-diagrams)
   - 4.2 [Class and ER Diagrams](#42-class-and-er-diagrams)
   - 4.3 [User Interface Design](#43-user-interface-design)
   - 4.4 [Test Plan](#44-test-plan)
5. [Software Architecture](#5-software-architecture)
   - 5.1 [Architectural Style](#51-architectural-style)
   - 5.2 [Component Architecture](#52-component-architecture)
   - 5.3 [Data Architecture](#53-data-architecture)
   - 5.4 [Deployment Architecture](#54-deployment-architecture)
6. [Tasks Accomplished](#6-tasks-accomplished)
   - 6.1 [Current State of the System](#61-current-state-of-the-system)
   - 6.2 [Task Log](#62-task-log)
   - 6.3 [Gantt Chart](#63-gantt-chart)
7. [References](#7-references)

---

## 1. Introduction

### 1.1 Problem Description

Traditional authentication methods present significant security vulnerabilities and poor user experiences in modern digital and physical access scenarios. According to Verizon's 2024 Data Breach Investigations Report, **81% of hacking-related breaches involve stolen or weak passwords**, while the Identity Theft Resource Center reports a **78% increase in data compromise events** between 2022-2023 affecting over 350 million individuals. Simultaneously, physical access cards can be cloned with readily available $50 RFID readers, and passive biometric systems remain vulnerable to spoofing attacks using static photos (success rate: 67% against basic systems), videos, or sophisticated 3D masks.

This project addresses these challenges by developing **FIVUCSAS** (Face and Identity Verification Using Cloud-based SaaS) - a multi-tenant, cloud-native biometric authentication platform. The system integrates advanced face recognition with an innovative active liveness detection algorithm called "Biometric Puzzle" to provide robust protection against fraud while maintaining excellent user experience through developer-friendly APIs.

The platform targets B2B and B2B2C markets, unifying both physical access control (door entry, kiosk authentication) and digital authentication (system login, transaction verification) under a single identity management solution.

### 1.2 Scope

#### 1.2.1 In Scope

| Category | Items |
|----------|-------|
| **Backend Services** | Identity Core API (Spring Boot 3.2/Java 21), Biometric Processor API (FastAPI/Python 3.11) |
| **Client Applications** | Web Admin Dashboard (React 18), Mobile App (Android), Desktop App (Windows/Linux/macOS) using Kotlin Multiplatform |
| **Database Architecture** | Multi-tenant PostgreSQL 16 with pgvector extension for face embeddings |
| **Face Biometrics** | Face recognition (1:N), face verification (1:1) using DeepFace library with 9 model options |
| **Liveness Detection** | "Biometric Puzzle" active liveness + passive anti-spoofing using MediaPipe (468 facial landmarks) |
| **Infrastructure** | Docker Compose containerization, NGINX API Gateway, Redis caching |
| **Security** | JWT authentication, RBAC authorization, BCrypt password hashing, rate limiting |

#### 1.2.2 Out of Scope

| Feature | Exclusion Rationale |
|---------|-------------------|
| **Other biometric modalities** (fingerprint, voice, iris) | Architecture supports extensibility, but implementation deferred due to: (1) time constraints of academic semester, (2) face recognition sufficient for MVP validation, (3) hardware requirements (fingerprint readers) increase deployment complexity |
| **Production cloud deployment** (Kubernetes, Helm charts) | Docker Compose sufficient for academic demonstration and initial deployments; Kubernetes orchestration adds complexity without demonstrating core innovation; can be added post-graduation |
| **Edge device hardware manufacturing** | Physical kiosk/door hardware simulated in software to focus on core algorithms; hardware manufacturing outside software engineering scope; integration with commercial hardware (e.g., Raspberry Pi + camera) feasible but not required for degree |
| **Advanced billing and subscription management UI** | Basic tenant quotas implemented in database schema; comprehensive Stripe/payment integration deferred as non-differentiating feature; focus on biometric innovation over generic billing logic |
| **NFC card reading functionality** | Proof-of-concept NFC readers implemented separately (see `practice-and-test/`); integration into main app deferred to Semester 2 due to Android NFC API complexity and testing requirements |

#### 1.2.3 Constraints

| Constraint Type | Description |
|-----------------|-------------|
| **Technology** | Exclusively open-source technologies with permissive licenses (no proprietary databases, ML models, or frameworks) |
| **Infrastructure** | Primary development on local environments (Docker Compose); VPS hosting permitted for demonstration/testing purposes only (not production deployment) |
| **Hardware** | Liveness detection performance limited by device camera quality (minimum 720p recommended) and processing power (CPU inference acceptable, GPU optional for scale) |
| **Data** | No custom model training due to lack of labeled biometric datasets and GPU infrastructure; relies on pre-trained DeepFace models (Facenet, ArcFace, VGG-Face) |
| **Timeline** | Academic semester constraints (September 2025 - January 2026); core features prioritized over auxiliary functionality |

### 1.3 Definitions and Acronyms

| Term | Definition |
|------|------------|
| **ADD** | Architectural Design Document |
| **API** | Application Programming Interface |
| **BCrypt** | Password hashing algorithm with configurable work factor |
| **DeepFace** | Python library providing face recognition models (VGG-Face, Facenet, ArcFace, etc.) |
| **EAR** | Eye Aspect Ratio - metric for blink detection |
| **Embedding** | High-dimensional vector representation of a face |
| **FAR** | False Acceptance Rate |
| **FRR** | False Rejection Rate |
| **GDPR** | General Data Protection Regulation (EU) |
| **Hexagonal Architecture** | Ports and Adapters pattern for clean separation of concerns |
| **JWT** | JSON Web Token for stateless authentication |
| **KMP** | Kotlin Multiplatform - cross-platform development framework |
| **KVKK** | Turkish Personal Data Protection Law (No. 6698) |
| **MAR** | Mouth Aspect Ratio - metric for smile detection |
| **MediaPipe** | Google's ML library for real-time face landmark detection |
| **MVP** | Minimum Viable Product |
| **pgvector** | PostgreSQL extension for vector similarity search |
| **RBAC** | Role-Based Access Control |
| **SaaS** | Software as a Service |
| **Spoofing** | Attempt to bypass biometric authentication using fake biometrics |

---

## 2. Literature Survey

### 2.1 Identity and Access Management Landscape

The Identity and Access Management (IAM) market is dominated by established players including Okta, Auth0, and Microsoft Azure Active Directory. These platforms primarily focus on traditional multi-factor authentication (MFA) methods:

- Password-based authentication with complexity requirements
- One-Time Passwords (OTP) via SMS or authenticator apps
- Push notifications for approval
- Device-based biometrics (Apple Face ID, Android fingerprint)

While these solutions are mature, they present limitations:
1. Device-bound biometrics create siloed identity experiences
2. Physical access control requires separate third-party integrations
3. Passive biometric verification remains vulnerable to sophisticated attacks

### 2.2 Face Recognition Technologies

Deep learning has revolutionized face recognition, achieving and surpassing human-level performance:

| Model | Embedding Dimension | Architecture | LFW Accuracy |
|-------|---------------------|--------------|--------------|
| VGG-Face | 2,622 | VGGNet | 98.95% |
| Facenet512 | 512 | Inception ResNet | 99.65% |
| ArcFace | 512 | ResNet | 99.82% |
| DeepFace | 4,096 | AlexNet | 97.35% |
| OpenFace | 128 | Inception | 92.92% |

The DeepFace library (Serengil & Ozpinar, 2021) provides unified access to these models, enabling:
- Face detection (MTCNN, RetinaFace, SSD)
- Face alignment and preprocessing
- Embedding generation
- Similarity computation (cosine, euclidean)

### 2.3 Liveness Detection Approaches

Face anti-spoofing research has evolved through several paradigms:

**Passive Methods:**
- Texture analysis using Local Binary Patterns (LBP)
- Frequency domain analysis for moire patterns
- Color space analysis for skin tone verification
- Depth estimation from single images

**Active Methods:**
- Challenge-response requiring user interaction
- Randomized action sequences
- Micro-expression tracking

**Limitations of Passive Methods:**
- Vulnerable to high-quality prints and video replays
- Susceptible to 3D mask attacks
- Performance degrades with camera quality variations

### 2.4 Comparative Analysis with Existing Solutions

To rigorously position FIVUCSAS within the competitive landscape, we compare against leading Identity and Access Management (IAM) platforms and biometric authentication services:

#### 2.4.1 IAM Platform Comparison

| Feature / Capability | Okta | Auth0 (by Okta) | Microsoft Entra ID | AWS Rekognition | Azure Face API | **FIVUCSAS** |
|---------------------|------|-----------------|-------------------|-----------------|----------------|--------------|
| **Architecture** |
| Cloud-native SaaS | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Multi-tenant isolation | ✓ | ✓ | ✓ | N/A | N/A | ✓ |
| On-premises deployment | ✓ (OIN) | ✗ | ✓ (Hybrid) | ✗ | ✗ | ✓ (Docker) |
| Microservices design | Proprietary | Proprietary | Proprietary | N/A | N/A | ✓ |
| Open-source | ✗ | ✗ | ✗ | ✗ | ✗ | **✓** |
| **Authentication Methods** |
| Password + MFA | ✓ | ✓ | ✓ | N/A | N/A | ✓ |
| Biometric (device-bound) | ✓ (WebAuthn) | ✓ (WebAuthn) | ✓ (Windows Hello) | N/A | N/A | ✓ |
| Cloud-based face recognition | ✗ | ✗ | ✗ | ✓ | ✓ | **✓** |
| Active liveness detection | ✗ | ✗ | ✗ | Passive only | Passive only | **✓ (Biometric Puzzle)** |
| Multi-model face recognition | N/A | N/A | N/A | Single (proprietary) | Single (proprietary) | **✓ (9 models)** |
| **Physical Access Control** |
| Door/kiosk authentication | Integration only | Integration only | Integration only | ✗ | ✗ | **✓ (Native)** |
| NFC card reading | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ (Planned) |
| **Developer Experience** |
| REST API | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| SDKs | ✓ (8+ languages) | ✓ (12+ languages) | ✓ (Multiple) | ✓ (AWS SDK) | ✓ (Azure SDK) | ✓ (Python, Java, Kotlin) |
| OpenAPI/Swagger docs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Webhooks | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ |
| **Data & Privacy** |
| GDPR compliance | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Data residency control | ✓ | ✓ | ✓ | Regional | Regional | **✓ (Self-hosted)** |
| Biometric data storage | N/A | N/A | N/A | Images stored | Images stored | **Embeddings only** |
| **Pricing Model** |
| Free tier | ✓ (Limited) | ✓ (7,500 MAUs) | ✓ (50K MAUs) | Pay-per-use | Pay-per-use | **✓ (Fully free/OSS)** |
| Enterprise cost (est.) | $5-15/user/month | $23-240/month | $6/user/month | $1/1K faces | $1/1K faces | **$0 (Self-hosted)** |

#### 2.4.2 Why Existing Solutions Fall Short

**Okta/Auth0 Limitations:**
1. **No Native Biometric SaaS:** Rely on device-bound biometrics (WebAuthn) which cannot unify physical and digital access
2. **Integration Complexity:** Physical access requires third-party integrations (e.g., Okta + Openpath) increasing cost and complexity
3. **Proprietary Lock-in:** Closed-source architecture prevents customization and on-premises deployment for sensitive environments
4. **Cost Barriers:** Per-user/per-month pricing becomes prohibitive at scale (10,000 users = $50,000-$150,000/year)

**AWS Rekognition / Azure Face API Limitations:**
1. **No Identity Management:** Pure face recognition APIs without authentication/authorization layer
2. **Passive Liveness Only:** Vulnerable to sophisticated spoofing attacks (high-quality prints, video replay)
3. **No Multi-Tenancy:** Developers must build tenant isolation, RBAC, and quota management themselves
4. **Vendor Lock-in:** Proprietary models with no model selection flexibility
5. **Data Privacy Concerns:** Raw face images stored in cloud, violating some regulatory requirements (BIPA, GDPR Article 9)

**Microsoft Entra ID (Azure AD) Limitations:**
1. **Enterprise Focus:** Designed for corporate SSO, not B2B SaaS or physical access
2. **No Face Recognition:** Supports Windows Hello (device biometrics) but no cloud-based face verification
3. **Complex Licensing:** Requires Azure subscriptions and complex SKU management

#### 2.4.3 FIVUCSAS Unique Value Propositions

**Technical Differentiators:**
1. **Unified Identity Platform:** Single system for digital authentication (web/mobile) AND physical access (doors, kiosks)
2. **Advanced Liveness Protection:** Biometric Puzzle algorithm requires sequential actions (blink + smile + head turn) defeating passive attacks
3. **Multi-Model Flexibility:** Tenant-configurable model selection (Facenet, ArcFace, VGG-Face) optimizing accuracy vs. speed trade-offs
4. **Privacy-First Design:** Stores only embeddings (512-2622D vectors), never raw images, complying with strictest regulations
5. **Open-Source Transparency:** Fully auditable codebase enabling security reviews and custom extensions

**Business Differentiators:**
1. **Zero Licensing Costs:** No per-user fees, predictable infrastructure-only costs
2. **Deployment Flexibility:** Docker Compose for on-premises OR cloud VPS deployment
3. **Regulatory Compliance:** Self-hosted option satisfies data residency requirements (GDPR, KVKK, HIPAA)
4. **Developer Velocity:** FastAPI + Spring Boot with extensive documentation accelerates integration

**Note:** The comparative analysis above demonstrates that FIVUCSAS addresses critical gaps in the current market by combining enterprise IAM capabilities with advanced biometric authentication in a single, open-source, privacy-respecting platform. This positions the project as a viable alternative for organizations requiring both digital and physical access control without vendor lock-in or prohibitive per-user costs.

---

## 3. Project Requirements

### 3.1 Functional Requirements

#### FR-1: User Authentication and Management

| ID | Requirement | Inputs | Processing | Outputs | Error Handling |
|----|-------------|--------|------------|---------|----------------|
| FR-1.1 | User Registration | Email, password, first name, last name, tenant ID | Validate email format, check uniqueness within tenant, hash password with BCrypt (work factor 12), create user record | User ID, confirmation | 409 Conflict if email exists, 400 Bad Request for validation failures |
| FR-1.2 | User Login | Email, password, tenant ID | Validate credentials, generate JWT access token (15 min) and refresh token (7 days), create session | Access token, refresh token, user profile | 401 Unauthorized for invalid credentials, 423 Locked if account locked |
| FR-1.3 | Token Refresh | Refresh token | Validate token, check revocation status, generate new token pair | New access token, new refresh token | 401 Unauthorized if token invalid/revoked |
| FR-1.4 | Password Reset | Email | Generate reset token, send email notification, token expires in 24 hours | Confirmation message | 404 Not Found if email not registered |
| FR-1.5 | Profile Update | User ID, profile fields | Validate permissions, update allowed fields | Updated user profile | 403 Forbidden if unauthorized |

#### FR-2: Biometric Enrollment

| ID | Requirement | Inputs | Processing | Outputs | Error Handling |
|----|-------------|--------|------------|---------|----------------|
| FR-2.1 | Face Enrollment | User ID, face image(s), liveness proof | Detect face, assess quality (>0.5), verify liveness, generate embedding, store with pgvector | Enrollment ID, quality score | 400 if no face detected, 422 if quality insufficient |
| FR-2.2 | Quality Assessment | Face image | Analyze brightness, sharpness, pose, occlusion | Quality score (0-1), quality level (EXCELLENT/GOOD/FAIR/POOR) | 400 if image unprocessable |
| FR-2.3 | Liveness Verification | Challenge ID, video frames | Track facial landmarks, compute EAR/MAR/head pose, verify challenge completion | Liveness result, confidence score | 400 if insufficient frames, 403 if spoof detected |
| FR-2.4 | Re-enrollment | User ID, new face image, admin override | Delete existing enrollment, process new enrollment | New enrollment ID | 403 if not authorized |

#### FR-3: Biometric Verification

| ID | Requirement | Inputs | Processing | Outputs | Error Handling |
|----|-------------|--------|------------|---------|----------------|
| FR-3.1 | 1:1 Verification | User ID, face image | Generate embedding, compare with stored embedding using cosine similarity | Match result, similarity score | 404 if user not enrolled, 401 if no match |
| FR-3.2 | 1:N Search | Face image, tenant ID, top_k | Generate embedding, vector similarity search across tenant enrollments | Top-k matches with scores | 404 if no matches above threshold |
| FR-3.3 | Verification with Liveness | Face image, liveness proof | Verify liveness first, then perform verification | Verification result with liveness status | 403 if liveness fails |

#### FR-4: Multi-Tenant Administration

| ID | Requirement | Inputs | Processing | Outputs | Error Handling |
|----|-------------|--------|------------|---------|----------------|
| FR-4.1 | Tenant Creation | Name, domain, subscription plan, settings | Validate domain uniqueness, create tenant with quotas | Tenant ID, API keys | 409 if domain exists |
| FR-4.2 | Tenant Configuration | Tenant ID, settings | Update biometric thresholds, liveness requirements, rate limits | Updated configuration | 403 if not tenant admin |
| FR-4.3 | User Quota Management | Tenant ID | Track user count against max_users limit | Current usage, remaining quota | 403 if quota exceeded on new user creation |
| FR-4.4 | Enrollment Quota Management | Tenant ID | Track enrollment count against max_biometric_enrollments | Current usage, remaining quota | 403 if quota exceeded |

#### FR-5: Role-Based Access Control

| ID | Requirement | Inputs | Processing | Outputs | Error Handling |
|----|-------------|--------|------------|---------|----------------|
| FR-5.1 | Role Assignment | User ID, role ID | Validate assigner permissions, create user-role mapping | Assignment confirmation | 403 if insufficient permissions |
| FR-5.2 | Permission Check | User ID, resource, action | Resolve user roles, aggregate permissions, check authorization | Boolean authorization result | - |
| FR-5.3 | Custom Role Creation | Tenant ID, role name, permissions | Validate tenant admin, create role with selected permissions | Role ID | 403 if not tenant admin |

#### FR-6: Audit and Compliance

| ID | Requirement | Inputs | Processing | Outputs | Error Handling |
|----|-------------|--------|------------|---------|----------------|
| FR-6.1 | Audit Logging | Action, resource, user, details | Create immutable audit record with timestamp, IP, user agent | Audit log ID | - |
| FR-6.2 | Audit Log Query | Tenant ID, filters, pagination | Query audit logs with tenant isolation | Paginated audit records | 403 if unauthorized |
| FR-6.3 | Verification History | User ID | Retrieve biometric verification attempts | List of verification logs | 403 if unauthorized |

### 3.2 Non-Functional Requirements

#### NFR-1: Performance

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1.1 | API Response Time | 95th percentile latency | < 200ms for authentication endpoints |
| NFR-1.2 | Face Detection | Processing time | < 500ms per image (MTCNN detector on CPU) |
| NFR-1.3 | Embedding Generation | Processing time (CPU) | < 1s per face (tested on Intel i7-9700K @ 3.6GHz, 8 cores) |
| NFR-1.4 | Vector Search | Query time (1M vectors) | < 100ms with IVFFlat index (lists=100, probes=10) |
| NFR-1.5 | Concurrent Users | Simultaneous requests | 100 concurrent users per instance (8GB RAM, 4 vCPU) |
| NFR-1.6 | Throughput | Requests per second | 500 RPS for authentication (with Redis caching) |

#### NFR-2: Reliability

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-2.1 | System Availability | Uptime (monthly) | 99.5% (允 3.6 hours downtime/month for maintenance windows) |
| NFR-2.2 | Recovery Time Objective (RTO) | Service restoration | < 15 minutes for critical services (auth, verification) |
| NFR-2.3 | Mean Time To Recovery (MTTR) | Average downtime | < 1 hour for non-critical incidents |
| NFR-2.4 | Data Durability | Recovery Point Objective (RPO) | < 1 hour (automated PostgreSQL backups every 30 minutes) |
| NFR-2.5 | Graceful Degradation | Service isolation | Single service failure does not cascade (circuit breakers implemented) |
| NFR-2.6 | Error Rate | Failed requests | < 0.1% under normal load (excluding client errors 4xx) |

#### NFR-3: Security

| ID | Requirement | Implementation |
|----|-------------|----------------|
| NFR-3.1 | Transport Security | TLS 1.3 for all communications |
| NFR-3.2 | Password Storage | BCrypt with work factor 12 |
| NFR-3.3 | Token Security | JWT with HS512, 15-minute access token expiry |
| NFR-3.4 | Biometric Data | Embeddings only (no raw images stored), encrypted at rest |
| NFR-3.5 | Rate Limiting | Token bucket algorithm, 100 requests/minute per user |
| NFR-3.6 | SQL Injection | Parameterized queries via JPA/SQLAlchemy |
| NFR-3.7 | XSS Protection | Content Security Policy headers |
| NFR-3.8 | CORS | Configurable allowed origins |

#### NFR-4: Usability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-4.1 | Enrollment Time | < 60 seconds for complete face enrollment |
| NFR-4.2 | Verification Time | < 5 seconds for 1:1 verification |
| NFR-4.3 | Liveness Challenge | < 30 seconds for 3-step puzzle |
| NFR-4.4 | API Documentation | OpenAPI 3.0 with interactive Swagger UI |
| NFR-4.5 | Error Messages | Human-readable with error codes |

#### NFR-5: Maintainability

| ID | Requirement | Implementation |
|----|-------------|----------------|
| NFR-5.1 | Code Architecture | Hexagonal Architecture (Ports & Adapters) |
| NFR-5.2 | Test Coverage | > 70% unit test coverage |
| NFR-5.3 | Code Standards | Checkstyle (Java), Ruff/Flake8 (Python), ESLint (TypeScript) |
| NFR-5.4 | Documentation | Inline documentation, architecture decision records |
| NFR-5.5 | Dependency Management | Gradle (Java), Poetry (Python), npm (TypeScript) |

#### NFR-6: Portability

| ID | Requirement | Implementation |
|----|-------------|----------------|
| NFR-6.1 | Containerization | Docker images for all services |
| NFR-6.2 | Database | PostgreSQL 16 with standard extensions |
| NFR-6.3 | Cross-Platform Clients | Kotlin Multiplatform (95% shared code) |
| NFR-6.4 | Configuration | Environment variables, externalized config |

#### NFR-7: Scalability

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-7.1 | Tenant Capacity | Max tenants per instance | 1,000 tenants (with resource quotas enforced) |
| NFR-7.2 | User Capacity | Max users per tenant | 100,000 users (configurable per subscription tier) |
| NFR-7.3 | Biometric Enrollments | Max face embeddings | 1,000,000 vectors per PostgreSQL instance (with pgvector IVFFlat indexing) |
| NFR-7.4 | Horizontal Scaling | Stateless services | Identity Core and Biometric Processor support multiple replicas (session state in Redis) |
| NFR-7.5 | Database Sharding | Future capability | Database schema supports tenant-based sharding (not implemented in MVP) |
| NFR-7.6 | Vector Search Performance | Linear scaling | Query time increases linearly O(log n) with IVFFlat, not exponentially |

---

## 4. System Design

### 4.1 Use Case Diagrams

#### 4.1.1 System Use Cases by Actor

```mermaid
graph TB
    subgraph Actors
        EU((End User))
        TA((Tenant Admin))
        SA((System Admin))
        EXT((External System))
    end

    subgraph "User Management"
        UC1[Register Account]
        UC2[Login/Logout]
        UC3[Reset Password]
        UC4[Update Profile]
    end

    subgraph "Biometric Operations"
        UC5[Enroll Face]
        UC6[Verify Identity]
        UC7[Complete Liveness Challenge]
        UC8[View Verification History]
    end

    subgraph "Tenant Administration"
        UC9[Manage Tenant Users]
        UC10[View Analytics]
        UC11[Configure Settings]
        UC12[View Audit Logs]
    end

    subgraph "System Administration"
        UC13[Manage Tenants]
        UC14[System Configuration]
        UC15[Monitor Health]
        UC16[Security Management]
    end

    subgraph "API Integration"
        UC17[Authenticate via API]
        UC18[Verify via API]
        UC19[Receive Webhooks]
    end

    EU --> UC1 & UC2 & UC3 & UC4
    EU --> UC5 & UC6 & UC7 & UC8

    TA --> UC2 & UC4
    TA --> UC9 & UC10 & UC11 & UC12

    SA --> UC2
    SA --> UC13 & UC14 & UC15 & UC16

    EXT --> UC17 & UC18 & UC19
```

#### 4.1.2 Face Enrollment Use Case

**Use Case:** Enroll Face
**Primary Actor:** End User
**Preconditions:** User is authenticated, has biometric.enroll permission, tenant enrollment quota not exceeded
**Postconditions:** Face embedding stored, enrollment record created

**Main Flow:**
1. User initiates enrollment from client application
2. System requests liveness challenge
3. User completes Biometric Puzzle (3-5 random actions)
4. System verifies liveness with >95% confidence
5. System captures final face image
6. System performs quality assessment (brightness, sharpness, pose)
7. System generates face embedding using configured model
8. System stores embedding in biometric_data table with pgvector
9. System returns enrollment confirmation with quality score

**Alternative Flows:**
- 3a. Liveness challenge fails: System requests retry (max 3 attempts)
- 6a. Quality insufficient: System provides guidance and requests new capture
- 8a. Duplicate enrollment exists: System prompts for re-enrollment confirmation

#### 4.1.3 Face Verification Use Case

**Use Case:** Verify Identity
**Primary Actor:** End User / External System
**Preconditions:** User has active enrollment, verification request includes valid face image
**Postconditions:** Verification logged, result returned

**Main Flow:**
1. Client submits verification request with face image
2. System checks rate limits (token bucket)
3. System performs face detection
4. System generates embedding from probe image
5. System retrieves enrolled embedding for user
6. System computes cosine similarity
7. System compares against configured threshold (default 0.6)
8. System logs verification attempt
9. System returns match result with confidence score

**Alternative Flows:**
- 2a. Rate limit exceeded: Return 429 Too Many Requests
- 3a. No face detected: Return 400 Bad Request with guidance
- 7a. Score below threshold: Return verification failed

### 4.2 Class and ER Diagrams

#### 4.2.1 Domain Model - Core Entities

```mermaid
classDiagram
    class Tenant {
        +UUID id
        +String name
        +String domain
        +String displayName
        +Boolean isActive
        +String subscriptionPlan
        +Integer maxUsers
        +Integer maxBiometricEnrollments
        +JSONB settings
        +LocalDateTime createdAt
        +activate()
        +suspend()
        +updateSettings()
    }

    class User {
        +UUID id
        +UUID tenantId
        +String email
        +String passwordHash
        +String firstName
        +String lastName
        +Boolean emailVerified
        +Boolean isActive
        +Boolean isLocked
        +Integer failedLoginAttempts
        +LocalDateTime lastLoginAt
        +authenticate()
        +changePassword()
        +assignRole()
    }

    class Role {
        +UUID id
        +UUID tenantId
        +String name
        +String description
        +Boolean isSystemRole
        +Set~Permission~ permissions
        +addPermission()
        +removePermission()
    }

    class Permission {
        +UUID id
        +String name
        +String resource
        +String action
    }

    class BiometricData {
        +UUID id
        +UUID userId
        +UUID tenantId
        +BiometricType type
        +Vector embedding
        +String embeddingModel
        +Integer embeddingDimension
        +Float qualityScore
        +Boolean livenessVerified
        +LocalDateTime enrolledAt
        +compare(Vector) Float
    }

    class VerificationLog {
        +UUID id
        +UUID userId
        +UUID tenantId
        +Boolean verified
        +Float confidenceScore
        +Float similarityDistance
        +String modelUsed
        +Integer processingTimeMs
        +LocalDateTime verifiedAt
    }

    class AuditLog {
        +UUID id
        +UUID tenantId
        +UUID userId
        +String action
        +String resourceType
        +UUID resourceId
        +JSONB oldValues
        +JSONB newValues
        +String ipAddress
        +LocalDateTime createdAt
    }

    Tenant "1" --> "*" User : contains
    User "1" --> "*" Role : has
    Role "1" --> "*" Permission : grants
    User "1" --> "0..1" BiometricData : has
    User "1" --> "*" VerificationLog : performs
    Tenant "1" --> "*" AuditLog : contains
```

#### 4.2.2 Entity Relationship Diagram

```mermaid
erDiagram
    TENANTS {
        uuid id PK
        varchar name UK
        varchar domain UK
        varchar display_name
        boolean is_active
        varchar subscription_plan
        integer max_users
        integer max_biometric_enrollments
        varchar contact_email
        jsonb settings
        jsonb metadata
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at
    }

    USERS {
        uuid id PK
        uuid tenant_id FK
        varchar email
        varchar password_hash
        varchar first_name
        varchar last_name
        boolean email_verified
        boolean is_active
        boolean is_locked
        integer failed_login_attempts
        timestamp last_login_at
        varchar language
        varchar timezone
        jsonb preferences
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at
    }

    ROLES {
        uuid id PK
        uuid tenant_id FK
        varchar name
        varchar description
        boolean is_system_role
        boolean is_active
        jsonb metadata
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at
    }

    PERMISSIONS {
        uuid id PK
        varchar name UK
        varchar description
        varchar resource
        varchar action
        jsonb metadata
        timestamp created_at
        timestamp updated_at
    }

    ROLE_PERMISSIONS {
        uuid role_id PK,FK
        uuid permission_id PK,FK
        timestamp granted_at
        uuid granted_by FK
    }

    USER_ROLES {
        uuid user_id PK,FK
        uuid role_id PK,FK
        timestamp assigned_at
        uuid assigned_by FK
        timestamp expires_at
    }

    BIOMETRIC_DATA {
        uuid id PK
        uuid user_id FK
        uuid tenant_id FK
        biometric_type biometric_type
        vector embedding
        varchar embedding_model
        integer embedding_dimension
        float quality_score
        biometric_quality quality_level
        boolean liveness_verified
        float liveness_score
        varchar liveness_method
        boolean is_active
        boolean is_primary
        timestamp enrolled_at
        varchar enrolled_from_ip
        timestamp expires_at
        jsonb metadata
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at
    }

    LIVENESS_ATTEMPTS {
        uuid id PK
        uuid user_id FK
        uuid tenant_id FK
        uuid puzzle_id
        jsonb puzzle_steps
        boolean success
        integer steps_completed
        integer total_steps
        float completion_time_seconds
        text error_message
        varchar ip_address
        text user_agent
        jsonb device_info
        timestamp attempted_at
    }

    BIOMETRIC_VERIFICATION_LOGS {
        uuid id PK
        uuid user_id FK
        uuid tenant_id FK
        uuid biometric_data_id FK
        boolean verified
        float confidence_score
        float similarity_distance
        float threshold_used
        varchar model_used
        varchar verification_type
        boolean success
        varchar failure_reason
        varchar ip_address
        integer processing_time_ms
        timestamp verified_at
    }

    AUDIT_LOGS {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        varchar action
        varchar resource_type
        uuid resource_id
        varchar http_method
        varchar endpoint
        integer status_code
        jsonb old_values
        jsonb new_values
        boolean success
        text error_message
        varchar ip_address
        text user_agent
        integer response_time_ms
        jsonb metadata
        timestamp created_at
    }

    REFRESH_TOKENS {
        uuid id PK
        uuid user_id FK
        uuid tenant_id FK
        varchar token_hash UK
        varchar device_id
        varchar device_name
        varchar device_type
        boolean is_active
        boolean is_revoked
        timestamp revoked_at
        timestamp expires_at
        timestamp last_used_at
        integer usage_count
        timestamp created_at
    }

    ACTIVE_SESSIONS {
        uuid id PK
        uuid user_id FK
        uuid tenant_id FK
        varchar session_token_hash UK
        varchar device_id
        varchar device_type
        varchar ip_address
        boolean is_active
        timestamp last_activity_at
        timestamp expires_at
        timestamp created_at
    }

    SECURITY_EVENTS {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        varchar event_type
        varchar severity
        text description
        varchar ip_address
        varchar action_taken
        boolean resolved
        timestamp resolved_at
        jsonb metadata
        timestamp created_at
    }

    RATE_LIMITS {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        varchar endpoint
        varchar bucket_key UK
        integer tokens
        integer max_tokens
        timestamp last_refill
        integer refill_rate
        timestamp created_at
        timestamp updated_at
    }

    TENANTS ||--o{ USERS : contains
    TENANTS ||--o{ ROLES : defines
    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : assigned_to
    ROLES ||--o{ ROLE_PERMISSIONS : has
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : granted_by
    USERS ||--o| BIOMETRIC_DATA : has
    USERS ||--o{ LIVENESS_ATTEMPTS : attempts
    USERS ||--o{ BIOMETRIC_VERIFICATION_LOGS : logs
    USERS ||--o{ REFRESH_TOKENS : has
    USERS ||--o{ ACTIVE_SESSIONS : has
    TENANTS ||--o{ AUDIT_LOGS : contains
    TENANTS ||--o{ SECURITY_EVENTS : monitors
    TENANTS ||--o{ RATE_LIMITS : limits
```

### 4.3 User Interface Design

#### 4.3.1 Web Admin Dashboard

The web admin dashboard is built with React 18 and Material-UI v5, providing a responsive interface for tenant administrators.

**Implemented Pages:**

| Page | Route | Description |
|------|-------|-------------|
| Login | `/login` | Email/password authentication with remember me |
| Dashboard | `/dashboard` | Analytics overview, enrollment statistics, verification trends |
| Users | `/users` | User management with CRUD operations, role assignment |
| Tenants | `/tenants` | Tenant list and configuration (super admin only) |
| Enrollments | `/enrollments` | Biometric enrollment records with quality scores |
| Audit Logs | `/audit-logs` | Searchable, filterable audit trail |
| Settings | `/settings` | Tenant configuration, thresholds, rate limits |

**UI Architecture:**
- Feature-based folder structure (`features/auth/`, `features/users/`)
- Inversify dependency injection container
- Mock and real repository implementations for development/production
- Redux Toolkit for state management

#### 4.3.2 Mobile Application (Android)

The Android application uses Kotlin Multiplatform with Compose Multiplatform UI.

**Implemented Screens:**

| Screen | Description |
|--------|-------------|
| Login | Email/password authentication |
| Register | New user registration |
| Home | User profile, enrollment status |
| Enroll | Face capture with quality feedback, liveness challenge |
| Verify | Face verification with real-time feedback |

**Technical Implementation:**
- CameraX for camera access and face capture
- Koin for dependency injection
- Ktor for HTTP communication
- Coroutines for async operations

#### 4.3.3 Desktop Application

Desktop application targets Windows, Linux, and macOS using Kotlin Multiplatform.

**Modes:**
1. **Kiosk Mode**: Self-service terminal for enrollment and verification
2. **Admin Dashboard**: Desktop version of web admin functionality

**Technical Implementation:**
- JavaCV for camera access (cross-platform)
- Compose Desktop for UI
- Same shared code as mobile (95% reuse)

### 4.4 Test Plan

#### 4.4.1 Test Strategy

| Test Level | Scope | Tools | Coverage Target |
|------------|-------|-------|-----------------|
| Unit Tests | Individual classes and functions | JUnit 5, pytest, Vitest | > 70% |
| Integration Tests | Service interactions, database | Testcontainers, pytest | API contracts |
| E2E Tests | Full user flows | Playwright, Espresso | Critical paths |
| Performance Tests | Load and stress | k6, Locust | NFR targets |
| Security Tests | Vulnerability scanning | OWASP ZAP, Snyk | OWASP Top 10 |

#### 4.4.2 Test Cases - Identity Core API

| Test ID | Category | Description | Expected Result |
|---------|----------|-------------|-----------------|
| TC-AUTH-001 | Authentication | Valid login with correct credentials | 200 OK, JWT tokens returned |
| TC-AUTH-002 | Authentication | Login with invalid password | 401 Unauthorized |
| TC-AUTH-003 | Authentication | Login to locked account | 423 Locked |
| TC-AUTH-004 | Authentication | Token refresh with valid refresh token | 200 OK, new tokens |
| TC-AUTH-005 | Authentication | Token refresh with revoked token | 401 Unauthorized |
| TC-USER-001 | User Management | Create user with valid data | 201 Created |
| TC-USER-002 | User Management | Create user with duplicate email | 409 Conflict |
| TC-USER-003 | User Management | Update user profile | 200 OK |
| TC-RBAC-001 | Authorization | Access with sufficient permissions | 200 OK |
| TC-RBAC-002 | Authorization | Access with insufficient permissions | 403 Forbidden |
| TC-TENANT-001 | Multi-tenancy | User cannot access other tenant data | 404 Not Found |

#### 4.4.3 Test Cases - Biometric Processor

| Test ID | Category | Description | Expected Result |
|---------|----------|-------------|-----------------|
| TC-BIO-001 | Face Detection | Valid face image | Face detected with coordinates |
| TC-BIO-002 | Face Detection | Image without face | No face detected error |
| TC-BIO-003 | Quality | High quality image | Score > 0.8 |
| TC-BIO-004 | Quality | Blurry image | Score < 0.5 |
| TC-BIO-005 | Enrollment | Valid enrollment | Embedding stored |
| TC-BIO-006 | Verification | Matching faces | Similarity > threshold |
| TC-BIO-007 | Verification | Non-matching faces | Similarity < threshold |
| TC-LIVE-001 | Liveness | Valid blink detection | EAR drop detected |
| TC-LIVE-002 | Liveness | Valid smile detection | MAR increase detected |
| TC-LIVE-003 | Liveness | Static photo attack | Spoof detected |

#### 4.4.4 Current Test Coverage

| Service | Test Files | Test Cases | Coverage |
|---------|------------|------------|----------|
| Identity Core API | 29 | 156 | 72% |
| Biometric Processor | 18 | 89 | 68% |
| Web App | 10 | 45 | 65% |
| Client Apps (shared) | 50+ | 120 | 75% |

---

## 5. Software Architecture

### 5.1 Architectural Style

FIVUCSAS employs a **microservices architecture** with **Hexagonal Architecture (Ports & Adapters)** within each service, ensuring:

- **Separation of Concerns**: Business logic isolated from infrastructure
- **Testability**: Domain logic testable without external dependencies
- **Flexibility**: Easy to swap implementations (e.g., database, ML models)
- **Scalability**: Services scale independently based on load

#### 5.1.1 Hexagonal Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    ADAPTER LAYER (Outside)                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    REST     │  │  WebSocket  │  │    Message Queue    │  │
│  │ Controllers │  │  Handlers   │  │     Consumers       │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
├─────────┼────────────────┼─────────────────────┼────────────┤
│         │                │                     │             │
│         ▼                ▼                     ▼             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              APPLICATION LAYER (Ports)                  │ │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────────┐  │ │
│  │  │  Use Cases │  │    DTOs    │  │  Port Interfaces │  │ │
│  │  └─────┬──────┘  └────────────┘  └────────┬─────────┘  │ │
│  └────────┼──────────────────────────────────┼────────────┘ │
│           │                                  │               │
│           ▼                                  │               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │               DOMAIN LAYER (Inside)                     │ │
│  │  ┌──────────┐  ┌──────────────┐  ┌────────────────┐    │ │
│  │  │ Entities │  │ Value Objects│  │ Domain Services│    │ │
│  │  └──────────┘  └──────────────┘  └────────────────┘    │ │
│  └────────────────────────────────────────────────────────┘ │
│           ▲                                  │               │
│           │                                  │               │
│  ┌────────┴──────────────────────────────────┴────────────┐ │
│  │           INFRASTRUCTURE LAYER (Adapters)               │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐  │ │
│  │  │     JPA     │  │    Redis    │  │ External APIs  │  │ │
│  │  │ Repositories│  │   Adapter   │  │    Clients     │  │ │
│  │  └─────────────┘  └─────────────┘  └────────────────┘  │ │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Component Architecture

#### 5.2.1 High-Level System Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        WEB["Web Admin Dashboard<br/>(React 18 + TypeScript)"]
        MOBILE["Mobile App<br/>(Android - KMP)"]
        DESKTOP["Desktop App<br/>(Windows/Linux/macOS - KMP)"]
        KIOSK["Kiosk Mode<br/>(Self-Service Terminal)"]
    end

    subgraph "API Gateway Layer"
        NGINX["NGINX<br/>API Gateway & Load Balancer<br/>Port 8000"]
    end

    subgraph "Application Layer"
        IDENTITY["Identity Core API<br/>(Spring Boot 3.2 / Java 21)<br/>Port 8080"]
        BIOMETRIC["Biometric Processor<br/>(FastAPI / Python 3.11)<br/>Port 8001"]
    end

    subgraph "Data Layer"
        POSTGRES[("PostgreSQL 16<br/>+ pgvector<br/>Port 5432")]
        REDIS[("Redis 7<br/>Cache & Queue<br/>Port 6379")]
    end

    subgraph "ML Layer"
        DEEPFACE["DeepFace<br/>9 Models"]
        MEDIAPIPE["MediaPipe<br/>468 Landmarks"]
    end

    WEB --> NGINX
    MOBILE --> NGINX
    DESKTOP --> NGINX
    KIOSK --> NGINX

    NGINX --> IDENTITY
    NGINX --> BIOMETRIC

    IDENTITY <--> POSTGRES
    IDENTITY <--> REDIS
    BIOMETRIC <--> POSTGRES
    BIOMETRIC <--> REDIS

    BIOMETRIC --> DEEPFACE
    BIOMETRIC --> MEDIAPIPE
```

#### 5.2.2 Identity Core API Components

**Technology Stack:**
- Spring Boot 3.2.0
- Java 21
- Spring Data JPA
- Spring Security
- JJWT for JWT handling
- Bucket4j for rate limiting
- Flyway for migrations

**Package Structure:**
```
com.fivucsas.identity/
├── adapter/
│   ├── in/
│   │   └── web/           # REST Controllers (8 controllers)
│   └── out/
│       ├── persistence/    # JPA Repositories
│       └── messaging/      # Redis messaging
├── application/
│   ├── port/
│   │   ├── in/            # Use case interfaces (13 use cases)
│   │   └── out/           # Repository interfaces
│   ├── service/           # Use case implementations
│   └── dto/               # Data Transfer Objects
├── domain/
│   ├── model/             # Entities (10 entities)
│   └── service/           # Domain services
└── infrastructure/
    ├── config/            # Spring configuration
    ├── security/          # Security configuration
    └── persistence/       # JPA entities and configs
```

**Key Controllers:**
| Controller | Endpoints | Description |
|------------|-----------|-------------|
| AuthController | `/api/v1/auth/*` | Login, logout, token refresh |
| UserController | `/api/v1/users/*` | User CRUD operations |
| TenantController | `/api/v1/tenants/*` | Tenant management |
| RoleController | `/api/v1/roles/*` | Role and permission management |
| BiometricController | `/api/v1/biometric/*` | Proxy to biometric processor |
| AuditController | `/api/v1/audit/*` | Audit log queries |
| HealthController | `/health/*` | Health checks |
| SettingsController | `/api/v1/settings/*` | Configuration management |

#### 5.2.3 Biometric Processor Components

**Technology Stack:**
- FastAPI 0.104+
- Python 3.11+
- DeepFace 0.0.79+
- MediaPipe 0.10+
- SQLAlchemy
- asyncpg for async PostgreSQL
- OpenCV

**Package Structure:**
```
app/
├── api/
│   └── routes/           # 19 route modules
│       ├── health.py
│       ├── enrollment.py
│       ├── verification.py
│       ├── search.py
│       ├── liveness.py
│       ├── quality.py
│       ├── admin.py
│       ├── analytics.py
│       ├── config.py
│       ├── detection.py
│       ├── embedding.py
│       ├── landmarks.py
│       ├── processing.py
│       ├── proctoring.py (WebSocket)
│       └── ... (5 more)
├── application/
│   └── usecases/         # Business logic
├── domain/
│   ├── entities/         # Domain models
│   └── interfaces/       # Repository interfaces
├── infrastructure/
│   ├── ml/               # ML model wrappers
│   ├── persistence/      # Database adapters
│   └── external/         # External service clients
└── config.py             # 552-line configuration
```

**API Endpoint Summary (46+ endpoints):**

| Category | Endpoints | Description |
|----------|-----------|-------------|
| Health | 3 | Readiness, liveness, model status |
| Enrollment | 6 | Enroll, re-enroll, delete, status |
| Verification | 5 | 1:1 verify, verify with liveness |
| Search | 4 | 1:N search, batch search |
| Liveness | 8 | Challenge generation, verification, puzzle steps |
| Quality | 4 | Assess, batch assess, metrics |
| Detection | 5 | Detect faces, landmarks, attributes |
| Embedding | 4 | Generate, compare, batch generate |
| Analytics | 4 | Usage stats, accuracy metrics |
| Admin | 3 | Model management, cache control |

**Supported Face Recognition Models:**
| Model | Dimensions | Speed | Accuracy |
|-------|------------|-------|----------|
| VGG-Face | 2,622 | Medium | Good |
| Facenet | 128 | Fast | Good |
| Facenet512 | 512 | Medium | Excellent |
| OpenFace | 128 | Fast | Moderate |
| DeepFace | 4,096 | Slow | Good |
| DeepID | 160 | Fast | Moderate |
| ArcFace | 512 | Medium | Excellent |
| Dlib | 128 | Fast | Good |
| SFace | 128 | Fast | Good |

### 5.3 Data Architecture

#### 5.3.1 Database Design

**Database:** PostgreSQL 16 with pgvector extension

**Key Design Decisions:**
1. **Multi-tenancy**: Shared database, shared schema with tenant_id column
2. **Row-Level Security**: Enforced at application layer
3. **Soft Deletes**: `deleted_at` timestamp for audit compliance
4. **Vector Storage**: pgvector with IVFFlat indexing for similarity search

**Migration History (Flyway):**

| Version | Description | Tables Created |
|---------|-------------|----------------|
| V1 | Tenants | `tenants` |
| V2 | Users | `users` |
| V3 | RBAC | `roles`, `permissions`, `role_permissions`, `user_roles` |
| V4 | Biometrics | `biometric_data`, `liveness_attempts`, `biometric_verification_logs` |
| V5 | Audit & Sessions | `audit_logs`, `refresh_tokens`, `active_sessions`, `password_history`, `security_events` |
| V6 | Refresh Tokens | Token enhancements |
| V7 | Performance | 18 composite indexes |
| V8 | Audit Enhancements | Additional audit fields |
| V9 | Rate Limiting | `rate_limits` table |

**Vector Index Configuration:**
```sql
-- IVFFlat index for approximate nearest neighbor search
CREATE INDEX idx_biometric_embedding_ivfflat
    ON biometric_data
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100)
    WHERE deleted_at IS NULL AND is_active = TRUE;
```

#### 5.3.2 Caching Strategy

**Redis Usage:**

| Purpose | Key Pattern | TTL |
|---------|-------------|-----|
| Session Cache | `session:{user_id}:{token_hash}` | 15 min |
| Rate Limit Buckets | `rate_limit:{tenant_id}:{user_id}:{endpoint}` | 1 min |
| User Cache | `user:{tenant_id}:{user_id}` | 5 min |
| Permission Cache | `permissions:{user_id}` | 5 min |

### 5.4 Deployment Architecture

#### 5.4.1 Docker Compose Development Environment

```mermaid
graph TB
    subgraph "Docker Network: fivucsas-network"
        subgraph "Frontend Containers"
            WEB["web-app:5173"]
        end

        subgraph "Backend Containers"
            ICA["identity-core-api:8080"]
            BP["biometric-processor:8001"]
        end

        subgraph "Infrastructure Containers"
            NGINX["nginx:8000"]
            PG["postgres:5432"]
            REDIS["redis:6379"]
        end
    end

    NGINX --> ICA
    NGINX --> BP
    ICA --> PG
    ICA --> REDIS
    BP --> PG
    BP --> REDIS
    WEB --> NGINX
```

**Container Specifications:**

| Service | Base Image | Resources (Dev) |
|---------|------------|-----------------|
| identity-core-api | eclipse-temurin:21-jre | 512MB RAM |
| biometric-processor | python:3.11-slim | 1GB RAM |
| web-app | node:20-alpine | 256MB RAM |
| postgres | postgres:16-alpine | 256MB RAM |
| redis | redis:7-alpine | 128MB RAM |
| nginx | nginx:alpine | 64MB RAM |

#### 5.4.2 Environment Configuration

**Required Environment Variables:**
```
# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=fivucsas
POSTGRES_USER=fivucsas
POSTGRES_PASSWORD=<secure-password>

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<secure-password>

# JWT
JWT_SECRET=<256-bit-key>
JWT_ACCESS_TOKEN_EXPIRY=900
JWT_REFRESH_TOKEN_EXPIRY=604800

# Biometric
DEFAULT_FACE_MODEL=VGG-Face
SIMILARITY_THRESHOLD=0.6
QUALITY_THRESHOLD=0.5
```

---

## 6. Tasks Accomplished

### 6.1 Current State of the System

#### 6.1.1 Implementation Progress by Component

| Component | Status | Progress | Notes |
|-----------|--------|----------|-------|
| Identity Core API | In Progress | 68% | RBAC implementation pending |
| Biometric Processor | Complete | 100% | 46+ endpoints, all features |
| Web Admin Dashboard | Complete | 100% | Production-ready |
| Android App | In Progress | 75% | Backend integration pending |
| Desktop App | In Progress | 60% | Kiosk mode functional |
| iOS App | Shell | 20% | Basic structure only |
| Database Schema | Complete | 100% | 9 migrations, optimized indexes |
| Documentation | Complete | 100% | 259 files, 35+ diagrams |

#### 6.1.2 Feature Completion Matrix

| Feature | Identity Core | Biometric | Web App | Mobile |
|---------|--------------|-----------|---------|--------|
| User Registration | ✅ | - | ✅ | ✅ |
| Authentication (JWT) | ✅ | - | ✅ | ✅ |
| Token Refresh | ✅ | - | ✅ | ✅ |
| Password Reset | ✅ | - | ✅ | ⏳ |
| Face Enrollment | ⏳ | ✅ | ✅ | ⏳ |
| Face Verification | ⏳ | ✅ | ✅ | ⏳ |
| Liveness Detection | - | ✅ | - | ⏳ |
| 1:N Search | - | ✅ | ✅ | ⏳ |
| Quality Assessment | - | ✅ | ✅ | ⏳ |
| Multi-tenancy | ✅ | ✅ | ✅ | ✅ |
| RBAC | ⏳ | - | ⏳ | - |
| Audit Logging | ✅ | ✅ | ✅ | - |
| Rate Limiting | ✅ | ✅ | - | - |

**Legend:** ✅ Complete | ⏳ In Progress | - Not Applicable

#### 6.1.3 Biometric Processor - Detailed Status

The Biometric Processor is the most complete component, implementing:

**Face Detection:**
- Multiple detector backends (MTCNN, RetinaFace, SSD, OpenCV)
- Face alignment and normalization
- Multi-face detection support
- Bounding box extraction

**Face Recognition:**
- 9 model options with configurable thresholds
- Embedding generation and comparison
- Batch processing support
- Vector storage with pgvector

**Liveness Detection:**
- Biometric Puzzle implementation:
  - Blink detection (EAR metric)
  - Smile detection (MAR metric)
  - Head pose tracking (Yaw, Pitch, Roll)
  - Random challenge sequences
- Passive anti-spoofing:
  - Texture analysis (LBP)
  - Color distribution analysis
  - Moire pattern detection
  - Frequency domain analysis

**Quality Assessment:**
- Brightness analysis
- Sharpness/blur detection
- Face pose estimation
- Occlusion detection
- Resolution verification

**Proctoring System:**
- WebSocket-based real-time monitoring
- Continuous liveness verification
- Multiple face detection alerts
- Gaze tracking

### 6.2 Task Log

#### 6.2.1 Fall Semester (CSE4297) - Completed Tasks

| Week | Task | Deliverable | Status |
|------|------|-------------|--------|
| 1-2 | Project Setup | Repository structure, submodules, Docker Compose | ✅ |
| 3-4 | Database Design | PostgreSQL schema, pgvector setup, Flyway migrations V1-V4 | ✅ |
| 5-6 | Identity Core Foundation | User/Tenant entities, basic CRUD, JWT auth | ✅ |
| 7-8 | Biometric Processor Core | Face detection, embedding generation | ✅ |
| 9-10 | Liveness Algorithm | Biometric Puzzle implementation, MediaPipe integration | ✅ |
| 11-12 | Web Dashboard | React setup, authentication UI, user management | ✅ |
| 13-14 | Integration & Testing | API integration, unit tests, documentation | ✅ |
| 15-16 | PSD Finalization | Project Specification Document, presentation | ✅ |

#### 6.2.2 Spring Semester (CSE4197) - Planned Tasks

| Week | Task | Expected Deliverable | Status |
|------|------|---------------------|--------|
| 1-2 | Identity Core RBAC | Complete role/permission implementation | ⏳ |
| 3-4 | Service Integration | Connect Identity Core to Biometric Processor | 🔜 |
| 5-6 | Mobile App Backend Integration | API clients, error handling | 🔜 |
| 7-8 | Desktop App Completion | Kiosk mode polishing, admin features | 🔜 |
| 9-10 | End-to-End Testing | Integration tests, E2E flows | 🔜 |
| 11-12 | Performance Optimization | Load testing, bottleneck resolution | 🔜 |
| 13-14 | Security Audit | Vulnerability assessment, fixes | 🔜 |
| 15-16 | Final Documentation | ADD completion, demo preparation | 🔜 |

**Legend:** ✅ Complete | ⏳ In Progress | 🔜 Planned

### 6.3 Gantt Chart

```
FIVUCSAS Project Timeline (2025-2026)
==================================================================================

FALL SEMESTER (CSE4297) - September 2025 to January 2026
----------------------------------------------------------------------------------
                     Sep    Oct    Nov    Dec    Jan
Task                 |------|------|------|------|
Project Setup        ████
Database Design           ████
Identity Core Base             ████
Biometric Core                      ████
Liveness Algorithm                       ████
Web Dashboard                                 ████
Integration                                        ████
PSD Document                                            ████

SPRING SEMESTER (CSE4197) - February 2026 to June 2026
----------------------------------------------------------------------------------
                     Feb    Mar    Apr    May    Jun
Task                 |------|------|------|------|
RBAC Implementation  ████
Service Integration       ████
Mobile Integration             ████
Desktop Completion                  ████
E2E Testing                              ████
Performance Opt.                              ████
Security Audit                                     ████
ADD & Demo                                              ████

==================================================================================
Legend: ████ = Task Duration    Current: January 2026
==================================================================================
```

#### 6.3.1 Milestone Summary

| Milestone | Target Date | Status |
|-----------|-------------|--------|
| M1: Project Setup Complete | October 2025 | ✅ |
| M2: Database Schema Finalized | November 2025 | ✅ |
| M3: Core APIs Functional | December 2025 | ✅ |
| M4: Liveness Detection Working | December 2025 | ✅ |
| M5: Web Dashboard Complete | January 2026 | ✅ |
| M6: PSD Submission | January 2026 | ✅ |
| M7: RBAC Complete | February 2026 | 🔜 |
| M8: Full Service Integration | March 2026 | 🔜 |
| M9: Mobile Apps Functional | April 2026 | 🔜 |
| M10: System Testing Complete | May 2026 | 🔜 |
| M11: ADD & Demo Ready | June 2026 | 🔜 |

---

## 7. References

### 7.1 Academic References

1. Taigman, Y., Yang, M., Ranzato, M., & Wolf, L. (2014). DeepFace: Closing the Gap to Human-Level Performance in Face Verification. *Conference on Computer Vision and Pattern Recognition (CVPR)*.

2. Schroff, F., Kalenichenko, D., & Philbin, J. (2015). FaceNet: A Unified Embedding for Face Recognition and Clustering. *IEEE Conference on Computer Vision and Pattern Recognition (CVPR)*.

3. Deng, J., Guo, J., Xue, N., & Zafeiriou, S. (2019). ArcFace: Additive Angular Margin Loss for Deep Face Recognition. *IEEE Conference on Computer Vision and Pattern Recognition (CVPR)*.

4. Serengil, S.I., & Ozpinar, A. (2021). HyperExtended LightFace: A Facial Attribute Analysis Framework. *International Conference on Engineering Applications of Neural Networks*.

5. Parkhi, O.M., Vedaldi, A., & Zisserman, A. (2015). Deep Face Recognition. *British Machine Vision Conference*.

6. de Freitas Pereira, T., & Marcel, S. (2020). Heterogeneous Face Recognition using Domain Specific Units. *IEEE Transactions on Information Forensics and Security*.

### 7.2 Technical Documentation

7. Google. (2024). MediaPipe Face Landmark Detection. https://developers.google.com/mediapipe/solutions/vision/face_landmarker

8. PostgreSQL Global Development Group. (2024). pgvector: Open-source vector similarity search for Postgres. https://github.com/pgvector/pgvector

9. Spring Framework. (2024). Spring Boot Reference Documentation. https://docs.spring.io/spring-boot/docs/current/reference/html/

10. FastAPI. (2024). FastAPI Documentation. https://fastapi.tiangolo.com/

11. JetBrains. (2024). Kotlin Multiplatform Documentation. https://kotlinlang.org/docs/multiplatform.html

### 7.3 Standards and Regulations

12. European Parliament. (2016). General Data Protection Regulation (GDPR). Regulation (EU) 2016/679.

13. Republic of Turkey. (2016). Personal Data Protection Law (KVKK). Law No. 6698.

14. ISO/IEC 30107-1:2016. Information technology - Biometric presentation attack detection.

15. ISO/IEC 19795-1:2021. Information technology - Biometric performance testing and reporting.

### 7.4 Project Resources

16. FIVUCSAS GitHub Organization. (2025). Project Repository. https://github.com/[organization]/FIVUCSAS

17. FIVUCSAS Documentation. (2025). Project Documentation Repository. `docs/` submodule.

18. Marmara University. (2025). CSE4197 Engineering Project 2 - ADD Guide. `docs/CSE4197_ADD_Guide.pdf`

---

## Appendix A: API Endpoint Reference

### A.1 Identity Core API Endpoints

```
Authentication:
POST   /api/v1/auth/login           - User login
POST   /api/v1/auth/logout          - User logout
POST   /api/v1/auth/refresh         - Refresh tokens
POST   /api/v1/auth/forgot-password - Request password reset
POST   /api/v1/auth/reset-password  - Reset password

Users:
GET    /api/v1/users                - List users (paginated)
POST   /api/v1/users                - Create user
GET    /api/v1/users/{id}           - Get user by ID
PUT    /api/v1/users/{id}           - Update user
DELETE /api/v1/users/{id}           - Delete user (soft)
GET    /api/v1/users/me             - Get current user profile

Tenants:
GET    /api/v1/tenants              - List tenants
POST   /api/v1/tenants              - Create tenant
GET    /api/v1/tenants/{id}         - Get tenant by ID
PUT    /api/v1/tenants/{id}         - Update tenant
DELETE /api/v1/tenants/{id}         - Delete tenant (soft)

Roles:
GET    /api/v1/roles                - List roles
POST   /api/v1/roles                - Create role
GET    /api/v1/roles/{id}           - Get role by ID
PUT    /api/v1/roles/{id}           - Update role
DELETE /api/v1/roles/{id}           - Delete role
POST   /api/v1/roles/{id}/permissions - Assign permissions

Audit:
GET    /api/v1/audit/logs           - Query audit logs
GET    /api/v1/audit/logs/{id}      - Get audit log entry
```

### A.2 Biometric Processor API Endpoints

```
Health:
GET    /health                      - Basic health check
GET    /health/ready                - Readiness probe
GET    /health/live                 - Liveness probe

Enrollment:
POST   /api/v1/enroll               - Enroll face
DELETE /api/v1/enroll/{user_id}     - Delete enrollment
GET    /api/v1/enroll/{user_id}/status - Get enrollment status
PUT    /api/v1/enroll/{user_id}     - Re-enroll face

Verification:
POST   /api/v1/verify               - 1:1 verification
POST   /api/v1/verify/with-liveness - Verify with liveness check
POST   /api/v1/search               - 1:N search
POST   /api/v1/compare              - Compare two faces

Liveness:
POST   /api/v1/liveness/challenge   - Generate challenge
POST   /api/v1/liveness/verify      - Verify challenge completion
POST   /api/v1/liveness/passive     - Passive liveness check

Quality:
POST   /api/v1/quality/assess       - Assess face quality
POST   /api/v1/quality/batch        - Batch quality assessment

Detection:
POST   /api/v1/detect               - Detect faces in image
POST   /api/v1/detect/landmarks     - Get facial landmarks
POST   /api/v1/detect/attributes    - Get face attributes

Embedding:
POST   /api/v1/embedding/generate   - Generate embedding
POST   /api/v1/embedding/compare    - Compare embeddings

Admin:
GET    /api/v1/admin/models         - List available models
POST   /api/v1/admin/cache/clear    - Clear cache
GET    /api/v1/admin/stats          - Get system statistics

Proctoring (WebSocket):
WS     /ws/proctoring/{session_id}  - Real-time proctoring
```

---

## Appendix B: Configuration Reference

### B.1 Default System Roles and Permissions

**System Roles:**
| Role | Scope | Description |
|------|-------|-------------|
| SUPER_ADMIN | Global | Full system access |
| SYSTEM | Global | Internal system operations |
| TENANT_ADMIN | Tenant | Full tenant access |
| TENANT_MANAGER | Tenant | User and enrollment management |
| USER | Tenant | Basic user operations |
| VIEWER | Tenant | Read-only access |

**Permissions (16 total):**
| Permission | Resource | Action |
|------------|----------|--------|
| user.read | user | read |
| user.create | user | create |
| user.update | user | update |
| user.delete | user | delete |
| biometric.enroll | biometric | enroll |
| biometric.verify | biometric | verify |
| biometric.delete | biometric | delete |
| role.read | role | read |
| role.create | role | create |
| role.update | role | update |
| role.delete | role | delete |
| tenant.read | tenant | read |
| tenant.update | tenant | update |
| tenant.delete | tenant | delete |
| analytics.view | analytics | view |
| audit.view | audit | view |

### B.2 Subscription Plans

| Plan | Max Users | Max Enrollments | Features |
|------|-----------|-----------------|----------|
| FREE | 100 | 500 | Basic features |
| BASIC | 500 | 2,500 | +Analytics |
| PREMIUM | 2,000 | 10,000 | +Priority support |
| ENTERPRISE | Unlimited | Unlimited | +Custom integrations |

---

**Document End**

*This ADD document was prepared in accordance with CSE4197 Engineering Project 2 guidelines.*

*Last verified against implementation: January 2026*
