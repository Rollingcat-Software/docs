# ADD Gap Analysis & Improvement Recommendations

**Date:** January 24, 2026
**Purpose:** Comprehensive analysis to achieve 10/10 ADD score
**Deadline:** January 9, 2026 (ADD Submission)

---

## Executive Summary

This document analyzes the FIVUCSAS ADD against the official CSE4197 ADD Guide requirements and provides specific recommendations for improvement.

**Current Estimated Score:** 7/10
**Target Score:** 10/10
**Key Gaps:** Requirements formatting, measurable NFRs, test plan timeline

---

## Section-by-Section Analysis

### 1. Title Page ✅ (Should be complete)

**Required:**
- Project Name
- Team Members with Student IDs
- Advisor Name
- Date
- University Logo

**Verification Checklist:**
- [ ] All three team members listed with student IDs
- [ ] Advisor: Assoc.Prof.Dr. Mustafa Ağaoğlu
- [ ] Marmara University logo included
- [ ] Current date

---

### 2. Introduction (Section 1)

| Subsection | Required | Your Materials | Status |
|------------|----------|----------------|--------|
| Problem Description | ✅ | PSD Section 1.1 | Copy and refine |
| Scope | ✅ | PSD Section 3 (In/Out/Constraints) | Already well-defined |
| Definitions | ⚠️ | Scattered in docs | **Need consolidated glossary** |

#### Action: Create Glossary Table

| Term | Definition |
|------|------------|
| Biometric Puzzle | A liveness detection method using MediaPipe that asks users to perform specific facial movements to prove they are a real person |
| Face Embedding | A 512-dimensional vector representation of facial features extracted by deep learning models |
| pgvector | PostgreSQL extension enabling efficient vector similarity searches for face matching |
| Multi-tenancy | Architecture allowing multiple organizations to share a single system instance while keeping data isolated |
| RBAC | Role-Based Access Control - security model restricting system access based on user roles |
| JWT | JSON Web Token - compact, URL-safe means of representing claims for authentication |
| Cosine Similarity | Mathematical measure of similarity between two vectors, used for face matching |
| Liveness Detection | Process of determining whether a biometric sample comes from a live person |

---

### 3. Literature Survey (Section 2)

**Required:** Revised and extended from PSD with comparison table

**Current State:** PSD Section 2 has comparison with FaceID, BioID, Aware, Onfido/Jumio

**Gap:** ADD guide requires "revised and extended" literature survey

#### Action Items:

1. **Add 2-3 more recent competitors (2024-2025)**
   - Amazon Rekognition
   - Microsoft Azure Face API
   - Veriff

2. **Add academic citations for core technologies:**

```
@article{taigman2014deepface,
  title={DeepFace: Closing the Gap to Human-Level Performance in Face Verification},
  author={Taigman, Yaniv and Yang, Ming and Ranzato, Marc'Aurelio and Wolf, Lior},
  journal={CVPR},
  year={2014}
}

@inproceedings{schroff2015facenet,
  title={FaceNet: A Unified Embedding for Face Recognition and Clustering},
  author={Schroff, Florian and Kalenichenko, Dmitry and Philbin, James},
  booktitle={CVPR},
  year={2015}
}

@article{parkhi2015deep,
  title={Deep Face Recognition},
  author={Parkhi, Omkar M and Vedaldi, Andrea and Zisserman, Andrew},
  journal={BMVC},
  year={2015},
  note={VGG-Face model}
}

@misc{mediapipe2023,
  title={MediaPipe Face Mesh},
  author={Google},
  year={2023},
  howpublished={\url{https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker}}
}

@standard{iso30107,
  title={ISO/IEC 30107-3:2017 - Biometric presentation attack detection},
  organization={ISO/IEC},
  year={2017}
}
```

3. **Extended Comparison Table:**

| Feature | FIVUCSAS | FaceID | BioID | AWS Rekognition | Azure Face |
|---------|----------|--------|-------|-----------------|------------|
| Multi-tenant | ✅ | ❌ | ❌ | ✅ | ✅ |
| On-premise | ✅ | ❌ | ✅ | ❌ | ❌ |
| Liveness Detection | ✅ Puzzle | ✅ | ✅ | ✅ | ✅ |
| Open Source | ✅ | ❌ | ❌ | ❌ | ❌ |
| Cost | Free | N/A | $$$ | $$$ | $$$ |
| Cross-platform | ✅ | iOS only | Web | API | API |

---

### 4. Project Requirements (Section 3) ⚠️ CRITICAL

**This is where most ADDs lose points. The guide specifies exact format.**

#### 4.1 Functional Requirements Format

**Required Template:**
```
FR-XX: [Title]
Description: What the system shall do
Inputs: Specific input data
Processing: Step-by-step logic
Outputs: Expected results
Error Handling: Edge cases
Data Handling: Storage/retrieval
```

#### Sample Functional Requirements (Properly Formatted):

---

**FR-01: User Registration**

| Aspect | Details |
|--------|---------|
| **Description** | The system shall allow new users to create an account with their personal information and credentials |
| **Inputs** | Email address, password, first name, last name, phone number, national ID number |
| **Processing** | 1. Validate email format and uniqueness<br>2. Validate password strength (min 8 chars, uppercase, lowercase, number, special)<br>3. Validate national ID format (11 digits)<br>4. Hash password with BCrypt (work factor 12)<br>5. Generate UUID for user<br>6. Create user record with PENDING status |
| **Outputs** | User ID, confirmation message, JWT access token |
| **Error Handling** | E01: Invalid email format → Return 400 with message<br>E02: Email already exists → Return 409 Conflict<br>E03: Weak password → Return 400 with requirements<br>E04: Invalid ID number → Return 400 with format |
| **Data Handling** | User record stored in PostgreSQL `users` table with encrypted sensitive fields |

---

**FR-02: User Authentication (Login)**

| Aspect | Details |
|--------|---------|
| **Description** | The system shall authenticate users with email and password, returning JWT tokens |
| **Inputs** | Email address, password |
| **Processing** | 1. Find user by email<br>2. Verify password hash with BCrypt<br>3. Check user status is ACTIVE<br>4. Generate JWT access token (15 min expiry)<br>5. Generate refresh token (7 day expiry)<br>6. Log authentication event |
| **Outputs** | Access token, refresh token, user profile data |
| **Error Handling** | E01: User not found → Return 401 Unauthorized<br>E02: Invalid password → Return 401 (same message for security)<br>E03: Account suspended → Return 403 with reason<br>E04: Account not verified → Return 403 with instructions |
| **Data Handling** | Session stored in Redis with TTL, audit log entry created |

---

**FR-03: Face Enrollment**

| Aspect | Details |
|--------|---------|
| **Description** | The system shall capture and store a user's facial biometric data for future verification |
| **Inputs** | User ID, face image (JPEG/PNG, min 640x480, max 10MB) |
| **Processing** | 1. Validate image format and size<br>2. Detect face using OpenCV MTCNN<br>3. Check single face detected<br>4. Validate face quality (lighting, angle, blur)<br>5. Extract 512-dimensional embedding using VGG-Face<br>6. Encrypt embedding with AES-256<br>7. Store in biometric_enrollments table |
| **Outputs** | Enrollment ID, quality score, success confirmation |
| **Error Handling** | E01: No face detected → Return 400 with guidance<br>E02: Multiple faces → Return 400 "Single face required"<br>E03: Low quality → Return 400 with specific issue (lighting/angle/blur)<br>E04: User already enrolled → Return 409 Conflict |
| **Data Handling** | Embedding stored in PostgreSQL with pgvector, original image discarded after processing |

---

**FR-04: Face Verification with Liveness**

| Aspect | Details |
|--------|---------|
| **Description** | The system shall verify a user's identity by comparing live face capture against enrolled biometric |
| **Inputs** | User ID, face image, liveness challenge response |
| **Processing** | 1. Retrieve user's enrolled embedding<br>2. Validate liveness challenge completion<br>3. Extract embedding from verification image<br>4. Calculate cosine similarity<br>5. Compare against threshold (0.70)<br>6. Log verification attempt |
| **Outputs** | Match result (boolean), confidence score, verification ID |
| **Error Handling** | E01: User not enrolled → Return 404<br>E02: Liveness failed → Return 401 "Liveness check failed"<br>E03: No face detected → Return 400<br>E04: Below threshold → Return 401 "Verification failed" |
| **Data Handling** | Verification log stored in audit_logs, embedding not persisted |

---

**FR-05: Biometric Puzzle (Liveness Detection)**

| Aspect | Details |
|--------|---------|
| **Description** | The system shall verify user liveness through randomized facial movement challenges |
| **Inputs** | Video stream or sequential images, challenge sequence |
| **Processing** | 1. Generate random 3-step challenge (e.g., "turn left", "smile", "blink")<br>2. Track facial landmarks using MediaPipe (468 points)<br>3. Detect movement matching challenge<br>4. Verify movements completed in order<br>5. Timeout after 30 seconds |
| **Outputs** | Liveness result (pass/fail), challenge completion details |
| **Error Handling** | E01: Timeout → Return 408 "Challenge expired"<br>E02: Wrong sequence → Return 401 "Incorrect movement"<br>E03: No face tracking → Return 400 "Face not visible" |
| **Data Handling** | Challenge sequence and result logged, video frames not stored |

---

**Complete Functional Requirements List:**

| ID | Title | Priority |
|----|-------|----------|
| FR-01 | User Registration | High |
| FR-02 | User Authentication | High |
| FR-03 | Face Enrollment | High |
| FR-04 | Face Verification with Liveness | High |
| FR-05 | Biometric Puzzle (Liveness Detection) | High |
| FR-06 | Password Reset | Medium |
| FR-07 | User Profile Management | Medium |
| FR-08 | Tenant Creation | High |
| FR-09 | Tenant User Management | High |
| FR-10 | Role Assignment | High |
| FR-11 | Permission Management | Medium |
| FR-12 | Access Log Viewing | Medium |
| FR-13 | Biometric Re-enrollment | Medium |
| FR-14 | User Suspension/Activation | Medium |
| FR-15 | Dashboard Statistics | Low |
| FR-16 | Report Generation | Low |
| FR-17 | System Configuration | Medium |
| FR-18 | API Key Management | Medium |
| FR-19 | Webhook Configuration | Low |
| FR-20 | Audit Log Export | Medium |

---

#### 4.2 Non-Functional Requirements ⚠️ MUST HAVE METRICS

**The guide explicitly requires measurable metrics for each NFR.**

---

**NFR-01: Performance - Face Verification Response Time**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Time from image submission to verification result |
| **Target** | ≤ 2000ms for 95th percentile |
| **Current** | ~1500ms (tested on development environment) |
| **Verification Method** | Load testing with k6, 100 concurrent users |
| **Rationale** | User experience studies show 2-3 second tolerance for biometric operations |

---

**NFR-02: Performance - API Response Time**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Response time for non-biometric API calls |
| **Target** | ≤ 200ms for 95th percentile |
| **Current** | ~150ms average |
| **Verification Method** | Load testing with k6 |

---

**NFR-03: Performance - Concurrent Users**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Number of simultaneous users without degradation |
| **Target** | 500 concurrent users |
| **Current** | Tested up to 100 concurrent users |
| **Verification Method** | Load testing with gradual ramp-up |

---

**NFR-04: Reliability - System Availability**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Uptime percentage over 30-day period |
| **Target** | 99.9% availability (8.76 hours downtime/year) |
| **Current** | Development environment only |
| **Verification Method** | Monitoring with Prometheus/Grafana |

---

**NFR-05: Reliability - Face Recognition Accuracy**

| Aspect | Specification |
|--------|---------------|
| **Measure** | True Positive Rate at fixed False Positive Rate |
| **Target** | 99.5% TPR at 0.1% FPR |
| **Current** | Based on VGG-Face published benchmarks |
| **Verification Method** | Testing with LFW dataset |

---

**NFR-06: Security - Data Encryption**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Encryption standard for data at rest and in transit |
| **Target** | AES-256 for data at rest, TLS 1.3 for transit |
| **Current** | Implemented |
| **Verification Method** | Security audit, penetration testing |

---

**NFR-07: Security - Password Storage**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Password hashing algorithm and strength |
| **Target** | BCrypt with work factor 12 |
| **Current** | Implemented |
| **Verification Method** | Code review, security testing |

---

**NFR-08: Security - Authentication Token**

| Aspect | Specification |
|--------|---------------|
| **Measure** | JWT token security |
| **Target** | HS512 algorithm, 15-minute access token, 7-day refresh token |
| **Current** | Implemented |
| **Verification Method** | Security audit |

---

**NFR-09: Usability - Enrollment Time**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Time for new user to complete face enrollment |
| **Target** | ≤ 30 seconds for successful enrollment |
| **Current** | ~20 seconds in testing |
| **Verification Method** | User testing with 10 participants |

---

**NFR-10: Usability - Verification Time**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Time for user to complete verification with liveness |
| **Target** | ≤ 15 seconds including liveness challenge |
| **Current** | ~12 seconds in testing |
| **Verification Method** | User testing |

---

**NFR-11: Maintainability - Code Coverage**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Percentage of code covered by automated tests |
| **Target** | ≥ 80% line coverage |
| **Current** | ~65% (in progress) |
| **Verification Method** | JaCoCo for Java, pytest-cov for Python |

---

**NFR-12: Maintainability - Code Quality**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Static analysis score |
| **Target** | 0 critical/high issues, SonarQube Quality Gate pass |
| **Current** | Clean on major issues |
| **Verification Method** | SonarQube analysis |

---

**NFR-13: Portability - Platform Support**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Supported platforms and versions |
| **Target** | Android 8+, iOS 14+, Windows 10+, macOS 11+, Chrome/Firefox/Safari |
| **Current** | Android and Desktop verified |
| **Verification Method** | Testing on each platform |

---

**NFR-14: Scalability - Horizontal Scaling**

| Aspect | Specification |
|--------|---------------|
| **Measure** | Ability to scale services horizontally |
| **Target** | Stateless services, Kubernetes-ready |
| **Current** | Docker Compose, Kubernetes configs ready |
| **Verification Method** | Deployment testing |

---

**Complete Non-Functional Requirements Summary:**

| ID | Category | Metric | Target |
|----|----------|--------|--------|
| NFR-01 | Performance | Face verification time | ≤ 2000ms (95th) |
| NFR-02 | Performance | API response time | ≤ 200ms (95th) |
| NFR-03 | Performance | Concurrent users | 500 users |
| NFR-04 | Reliability | System availability | 99.9% |
| NFR-05 | Reliability | Face recognition accuracy | 99.5% TPR @ 0.1% FPR |
| NFR-06 | Security | Data encryption | AES-256 / TLS 1.3 |
| NFR-07 | Security | Password hashing | BCrypt (factor 12) |
| NFR-08 | Security | Token security | HS512, 15min/7day |
| NFR-09 | Usability | Enrollment time | ≤ 30 seconds |
| NFR-10 | Usability | Verification time | ≤ 15 seconds |
| NFR-11 | Maintainability | Code coverage | ≥ 80% |
| NFR-12 | Maintainability | Code quality | SonarQube pass |
| NFR-13 | Portability | Platform support | 5 platforms |
| NFR-14 | Scalability | Horizontal scaling | Kubernetes-ready |

---

### 5. System Design (Section 4)

#### 5.1 Use Case Diagrams ✅

**Available diagrams to include:**
- `docs/02-architecture/diagrams/end_user_use_cases.png`
- `docs/02-architecture/diagrams/system_admin_use_cases.png`
- `docs/02-architecture/diagrams/tenant_admin_use_cases.png`
- `docs/02-architecture/diagrams/external_system_use_cases.png`

**Action:** Include all four with actor descriptions.

#### 5.2 Class/ER Diagrams ✅

**Available diagrams:**
- `docs/02-architecture/diagrams/fivucsas_er_diagram.png` - Complete database ER
- `docs/02-architecture/diagrams/core_entities_er.png` - Core entities
- `docs/02-architecture/diagrams/domain_model.png` - Domain model
- `docs/02-architecture/diagrams/biometric_processor_classes.png` - Biometric processor classes

**Action:** Include ER diagram with table descriptions.

#### 5.3 Sequence Diagrams

**Available in ARCHITECTURE_ANALYSIS.md:**
- Face Enrollment sequence
- Face Verification sequence

**Action:** Export/render as images and include.

#### 5.4 User Interface Design ⚠️

**Gap:** Need UI mockups/screenshots

**Action:** Include screenshots from:
- Desktop App - Launcher screen
- Desktop App - Kiosk mode (enrollment, verification)
- Desktop App - Admin dashboard
- Web Dashboard - User management
- Web Dashboard - Analytics
- Mobile App (if available)

#### 5.5 Test Plan ⚠️ IMPORTANT

**Required:** Timeline-based test plan with phases

**Recommended Test Plan:**

| Phase | Date Range | Test Type | Components | Responsible |
|-------|------------|-----------|------------|-------------|
| Unit Testing | Jan 1-5 | Unit | All services | All team |
| Integration Testing | Jan 6-8 | Integration | API↔DB, API↔Biometric | Backend team |
| System Testing | Jan 9-12 | End-to-End | Full verification flow | Full team |
| Performance Testing | Jan 13-14 | Load/Stress | API endpoints | Backend team |
| Security Testing | Jan 15-16 | Penetration | Auth, data protection | Security review |
| User Acceptance | Jan 17-20 | UAT | Real user scenarios | External testers |

**Test Cases Summary:**

| Component | Unit Tests | Integration Tests | E2E Tests |
|-----------|------------|-------------------|-----------|
| Identity Core API | 45 | 12 | 5 |
| Biometric Processor | 30 | 8 | 3 |
| Web Dashboard | 25 | 5 | 4 |
| Mobile/Desktop App | 20 | 3 | 3 |
| **Total** | **120** | **28** | **15** |

---

### 6. Software Architecture (Section 5) ✅ Strong Materials Available

#### 6.1 High-Level Architecture

**Include:** C4 Context and Container diagrams from ARCHITECTURE_ANALYSIS.md

#### 6.2 Component Architecture

**Available diagrams:**
- `docs/02-architecture/diagrams/system_components.png`
- `docs/02-architecture/diagrams/service_layer.png`
- `docs/02-architecture/diagrams/identity_core_internal.png`
- `docs/02-architecture/diagrams/biometric_processor_internal.png`

#### 6.3 Technology Stack Summary

| Layer | Component | Technology | Purpose |
|-------|-----------|------------|---------|
| **Presentation** | Mobile/Desktop App | Kotlin Multiplatform + Compose | Native cross-platform UI |
| **Presentation** | Web Dashboard | React 18 + TypeScript | Admin interface |
| **API Gateway** | NGINX | NGINX 1.25 | Load balancing, SSL termination |
| **Application** | Identity Core API | Spring Boot 3.2 (Java 21) | Authentication, user management, RBAC |
| **Application** | Biometric Processor | FastAPI (Python 3.11) | Face detection, embedding, verification |
| **Data** | Primary Database | PostgreSQL 16 + pgvector | Relational data, vector search |
| **Data** | Cache/Session | Redis 7 | Session storage, caching |
| **ML** | Face Recognition | DeepFace + VGG-Face | 512-d embedding extraction |
| **ML** | Liveness Detection | MediaPipe | Facial landmark tracking |

#### 6.4 Data Flow Diagram

**Available:** `docs/02-architecture/diagrams/data_flow_verification.png`

#### 6.5 Deployment Architecture

**Available diagrams:**
- `docs/02-architecture/diagrams/development_deployment.png`
- `docs/02-architecture/diagrams/kubernetes_deployment.png`
- `docs/02-architecture/diagrams/ha_deployment.png`

---

### 7. Tasks Accomplished (Section 6) ⚠️ NEEDS UPDATE

#### 7.1 Current Project Status

| Component | Completion | Status |
|-----------|------------|--------|
| Identity Core API | 78% | In Progress - RBAC pending |
| Biometric Processor | 80% | Core complete, optimization pending |
| Web Dashboard | 100% | Complete |
| Mobile/Desktop App | 95% | UI complete, backend integration pending |
| Documentation | 100% | Complete |
| **Overall** | **~70%** | On track for completion |

#### 7.2 Task Log (Individual Contributions)

| Team Member | Primary Responsibilities | Key Deliverables |
|-------------|-------------------------|------------------|
| Ahmet Abdullah Gültekin | Architecture, Backend, DevOps | Spring Boot API, Docker setup, CI/CD |
| Ayşe Gülsüm Eren | ML/Biometric, Python | Face recognition, liveness detection |
| Ayşenur Arıcı | Frontend, Mobile | React dashboard, Kotlin apps |

#### 7.3 Gantt Chart

**Action:** Create updated Gantt chart showing:
1. Original planned timeline (from PSD)
2. Actual progress
3. Remaining tasks with realistic dates

**Key Milestones:**
- [x] Oct 2024: Project kickoff, PSD submission
- [x] Nov 2024: Architecture design complete
- [x] Dec 2024: Core API and Biometric processor MVP
- [x] Jan 2025: Web dashboard complete
- [ ] Jan 2026: Integration testing
- [ ] Feb 2026: Production deployment
- [ ] Mar 2026: Final presentation

---

### 8. References

#### Academic References

1. Taigman, Y., Yang, M., Ranzato, M., & Wolf, L. (2014). DeepFace: Closing the Gap to Human-Level Performance in Face Verification. *CVPR*.

2. Schroff, F., Kalenichenko, D., & Philbin, J. (2015). FaceNet: A Unified Embedding for Face Recognition and Clustering. *CVPR*.

3. Parkhi, O. M., Vedaldi, A., & Zisserman, A. (2015). Deep Face Recognition. *BMVC*.

4. ISO/IEC 30107-3:2017. Biometric presentation attack detection — Part 3: Testing and reporting.

5. Serengil, S. I., & Ozpinar, A. (2020). LightFace: A Hybrid Deep Face Recognition Framework. *ASYU*.

#### Technical Documentation

6. Spring Boot Reference Documentation. https://docs.spring.io/spring-boot/docs/current/reference/html/

7. FastAPI Documentation. https://fastapi.tiangolo.com/

8. Kotlin Multiplatform Documentation. https://kotlinlang.org/docs/multiplatform.html

9. PostgreSQL pgvector Extension. https://github.com/pgvector/pgvector

10. MediaPipe Face Mesh. https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker

---

## Priority Action Checklist

### High Priority (Must Complete Before Jan 9)

- [ ] Reformat ALL functional requirements to exact template format
- [ ] Add measurable metrics to ALL non-functional requirements
- [ ] Create Test Plan table with timeline
- [ ] Update Gantt chart with current status vs planned
- [ ] Add glossary/definitions section

### Medium Priority

- [ ] Include all available UML diagrams with proper captions
- [ ] Add UI screenshots/mockups (at least 6)
- [ ] Extend literature survey with academic references
- [ ] Add individual contribution table
- [ ] Include sequence diagrams for key flows

### Quick Wins

- [ ] Ensure consistent formatting throughout
- [ ] Add figure/table numbers (Figure 1, Table 1, etc.)
- [ ] Verify table of contents with page numbers
- [ ] Check all team member names and student IDs
- [ ] Add proper captions to all diagrams

---

## Diagrams Checklist

Include at minimum 10 of these diagrams:

**Must Include:**
- [ ] `fivucsas_er_diagram.png` - Database ER diagram
- [ ] `end_user_use_cases.png` - End-user use cases
- [ ] `system_admin_use_cases.png` - Admin use cases
- [ ] `system_components.png` - System architecture
- [ ] `data_flow_verification.png` - Verification data flow
- [ ] `face_enrollment_quality.png` - Enrollment process

**Should Include:**
- [ ] `user_state_machine.png` - User states
- [ ] `verification_state_machine.png` - Verification states
- [ ] `development_deployment.png` - Deployment diagram
- [ ] `service_layer.png` - Service architecture

---

## Final Notes

1. **Formatting matters** - Consistent heading styles, proper margins, professional appearance
2. **Diagrams need captions** - "Figure X: Description" format
3. **Tables need headers** - "Table X: Description" format
4. **Page numbers** - Include in footer
5. **Table of Contents** - Auto-generated with correct page references

---

**Document prepared for ADD review and improvement**
**FIVUCSAS Team - Marmara University**
**January 2026**
