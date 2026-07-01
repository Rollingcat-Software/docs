# ADD Fixes for Word Document

This document contains the corrected sections for your ADD. Copy and paste the content below into your Word document (`ADD_2402.docx`).

---

## 0. Character Encoding Fixes (Title Page & General)

Please manually correct these names in your document if they appear corrupted:

*   **Ahmet Abdullah Gültekin**
*   **Ayşe Gülsüm Eren**
*   **Ayşenur Arıcı**
*   **Assoc. Prof. Dr. Mustafa Ağaoğlu**
*   **moiré** (in Section 2.3 and 6.1)

---

## 1. Replacement for Section 3.1 (Functional Requirements)

*Replace the entire content of Section 3.1 with the following structure:*

### 3.1 Functional Requirements

The following functional requirements are described with specific inputs, processing steps, outputs, and error handling mechanisms.

#### 3.1.1 Identity and Access Management (FR-1)

**3.1.1.1 Description**
The system shall provide a secure mechanism for authenticating users and managing administrative accounts within strictly isolated tenant boundaries.

**3.1.1.2 Inputs**
*   User credentials (email, password)
*   Tenant identifiers
*   Session-related metadata (IP, User-Agent)

**3.1.1.3 Processing**
1.  Validate credential formats (RFC 5322 for email).
2.  Enforce user uniqueness within the specified tenant.
3.  Verify password against stored BCrypt hash.
4.  Generate signed JWT access and refresh tokens.

**3.1.1.4 Outputs**
*   Authentication tokens (Access, Refresh)
*   User profile object
*   Session expiration details

**3.1.1.5 Error/Data Handling**
*   **Invalid Credentials:** Returns HTTP 401 Unauthorized.
*   **Duplicate User:** Returns HTTP 409 Conflict during registration.
*   **Locked Account:** Returns HTTP 423 Locked after max failed attempts.

#### 3.1.2 Biometric Enrollment (FR-2)

**3.1.2.1 Description**
The system shall support the secure enrollment of facial biometric data after verifying both image quality and user liveness.

**3.1.2.2 Inputs**
*   Live facial image stream or captured frame
*   User identifier

**3.1.2.3 Processing**
1.  Detect face using MediaPipe/OpenCV.
2.  Assess image quality (brightness, blur, pose).
3.  Validate liveness via "Biometric Puzzle" challenge.
4.  Generate standardized face embedding (vector).

**3.1.2.4 Outputs**
*   Unique enrollment identifier
*   Quality confidence score
*   Success/Failure status

**3.1.2.5 Error/Data Handling**
*   **No Face Detected:** Returns HTTP 400 Bad Request.
*   **Liveness Failed:** Returns HTTP 403 Forbidden with specific failure reason (e.g., "Spoof Detected").
*   **Low Quality:** Prompts user to retry with lighting/pose guidance.

#### 3.1.3 Biometric Verification (FR-3)

**3.1.3.1 Description**
The system shall verify user identity by comparing live facial biometric samples against previously enrolled biometric templates, with optional liveness validation.

**3.1.3.2 Inputs**
*   Live facial image
*   Claimed identity (User ID) or Search Context

**3.1.3.3 Processing**
1.  Generate embedding for the input image.
2.  Retrieve enrolled reference template(s) from vector database.
3.  Compute Cosine Similarity score.
4.  Compare score against the acceptance threshold (default: 0.6).

**3.1.3.4 Outputs**
*   Verification Decision (Match/No Match)
*   Similarity Confidence Score (0.0 - 1.0)

**3.1.3.5 Error/Data Handling**
*   **User Not Found:** Returns HTTP 404 Not Found.
*   **Verification Failed:** Returns HTTP 401 Unauthorized if score < threshold.

#### 3.1.4 Multi-Tenant Management (FR-4)

**3.1.4.1 Description**
The system shall support isolated configurations for multiple tenants, enabling independent management of quotas, limits, and operational settings.

**3.1.4.2 Inputs**
*   Tenant metadata (Organization Name, Domain)
*   Configuration parameters (Max Users, Quotas)

**3.1.4.3 Processing**
1.  Validate tenant identifier uniqueness.
2.  Provision tenant-specific database partition or identifier.
3.  Apply default resource quotas and rate limits.

**3.1.4.4 Outputs**
*   Unique Tenant Identifier (UUID)
*   Tenant API Keys/Credentials

**3.1.4.5 Error/Data Handling**
*   **Quota Exceeded:** Returns HTTP 429 Too Many Requests when tenant limits are reached.
*   **Duplicate Tenant:** Returns HTTP 409 Conflict.

#### 3.1.5 Authorization & Role Based Access Control (FR-5)

**3.1.5.1 Description**
The system shall enforce role-based access control to regulate access to protected resources based on assigned permissions.

**3.1.5.2 Inputs**
*   User Identity (from JWT)
*   Target Resource URI
*   Requested Operation (GET, POST, DELETE)

**3.1.5.3 Processing**
1.  Decode JWT to extract User Roles.
2.  Map Roles to Permissions.
3.  Evaluate if User Permissions include the Requested Operation on the Target Resource.

**3.1.5.4 Outputs**
*   Authorization Decision (Allow/Deny)

**3.1.5.5 Error/Data Handling**
*   **Insufficient Permissions:** Returns HTTP 403 Forbidden.
*   **Invalid Token:** Returns HTTP 401 Unauthorized.

#### 3.1.6 Auditing & Compliance (FR-6)

**3.1.6.1 Description**
The system shall record and expose immutable audit logs and verification histories to support security monitoring and compliance.

**3.1.6.2 Inputs**
*   Event details (User, Action, Resource, Timestamp)
*   Request Context (IP, Device)

**3.1.6.3 Processing**
1.  Sanitize input data to remove sensitive credentials.
2.  Append timestamp and tenant context.
3.  Write immutable record to audit log storage.

**3.1.6.4 Outputs**
*   Paginated Audit Record List
*   Verification History Reports

**3.1.6.5 Error/Data Handling**
*   **Access Denied:** Only Tenant Admins can view audit logs (HTTP 403).
*   **Write Failure:** Critical system alert if audit logging fails.

---

## 2. Replacement for Section 6.2 (Task Log)

*Replace Section 6.2 with this version which includes duration hours.*

### 6.2 Task Log

**Meeting 1 - 12.09.2025 (Duration: 3 Hours)**
*   Final Engineering Project topic (FIVUCSAS) was selected and approved.
*   Team roles and responsibilities were assigned.
*   Project scope and core scenarios were defined.
*   Initial literature sources on face recognition and biometric systems were identified.

**Meeting 2 - 26.09.2025 (Duration: 3 Hours)**
*   System architecture and microservice structure were designed.
*   Backend, frontend, and database technologies were selected.
*   Face recognition and liveness detection literature was reviewed.
*   Commercial biometric solutions were analyzed for comparison.

**Meeting 3 - 10.10.2025 (Duration: 4 Hours)**
*   Database schema and multi-tenancy strategy were finalized.
*   Biometric data storage using face embeddings was defined.
*   Vector similarity search techniques were evaluated.
*   Literature on biometric template protection was reviewed.

**Meeting 4 - 24.10.2025 (Duration: 3 Hours)**
*   Identity Core API design and security architecture were reviewed.
*   Authentication and authorization mechanisms were finalized.
*   Secure biometric authentication studies were analyzed.
*   API versioning and documentation strategy were defined.

**Meeting 5 - 07.11.2025 (Duration: 5 Hours)**
*   DeepFace-based biometric processing prototype was implemented.
*   Biometric enrollment and verification workflows were defined.
*   Image quality assessment criteria were established.
*   Performance optimization strategies were discussed.

**Meeting 6 - 14.11.2025 (Duration: 4 Hours)**
*   Mid-semester system demo was conducted.
*   Project progress was evaluated against the timeline.
*   Integration and performance risks were identified.
*   Accuracy metrics evaluation approach was defined.

**Meeting 7 - 28.11.2025 (Duration: 5 Hours)**
*   Biometric Puzzle liveness detection algorithm evaluated.
*   Active and passive liveness detection methods were combined.
*   MediaPipe facial landmark detection was integrated.
*   Mobile liveness processing strategy was defined.

**Meeting 8 - 05.12.2025 (Duration: 4 Hours)**
*   Web dashboard feature set was discussed.
*   Mobile application screen flows were discussed.
*   Desktop application modes were defined.
*   UI/UX consistency across platforms was established.

**Meeting 9 - 12.12.2025 (Duration: 6 Hours)**
*   Identity Core and Biometric Processor integration strategy was completed.
*   API contracts and standardized error responses were finalized.
*   Integration and end-to-end testing plan was defined.

**Meeting 10 - 26.12.2025 (Duration: 3 Hours)**
*   Documentation was reviewed and revised.
*   Completed system components were demonstrated.
*   Performance metrics were identified.
*   Spring semester focus areas were clarified.

**Meeting 11 - 09.01.2026 (Duration: 4 Hours)**
*   Fall semester retrospective was conducted.
*   Spring semester goals and priorities were defined.
*   Service integration tasks were prioritized.
*   ADD document requirements were reviewed with the advisor.
*   Mandatory diagrams and performance metrics were clarified.

---

## 3. Replacement for Section 6.3 (Task Plan)

*Replace the tables in Section 6.3 with these versions containing the "Expected Output" column. Please also insert a Gantt Chart image below these tables if possible.*

### 6.3 Task Plan

#### 6.3.1 Fall Semester Timeline

| Task No. | Task Description | Expected Output | Sep | Oct | Nov | Dec | Jan |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **F-1** | Project Initialization & Setup | Git Repository, CI/CD Pipeline, Initial Docs | X | | | | |
| **F-2** | Database Schema Design | ER Diagram, SQL Scripts, pgvector setup | X | X | | | |
| **F-3** | Identity Core - Base Implementation | User Auth API, JWT Handling | | X | X | | |
| **F-4** | Biometric Processor - Core API | Face Detection & Embedding endpoints | | X | X | | |
| **F-5** | Liveness Detection Algorithm | Working Biometric Puzzle Algorithm | | | X | X | |
| **F-6** | Web Admin Dashboard | React UI Codebase, Basic Dashboard | | | X | X | |
| **F-7** | Service Integration | Integrated Microservices (Identity + Biometric) | | | | X | X |
| **F-8** | Mobile App | Basic Android App with Camera access | | | | X | X |
| **F-9** | Desktop App | Kiosk Mode Prototype | | | | | X |
| **F-10** | NFC Reader | NFC Reading Module (Passport/ID) | | | | | X |

*(Note: In your Word document, please ensure the timeline cells (Sep-Jan) are shaded to represent the Gantt chart visualization).*

#### 6.3.2 Spring Semester Timeline

| Task No. | Task Description | Expected Output | Feb | Mar | Apr | May | Jun |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **S-1** | RBAC Implementation | Full Role/Permission System | X | | | | |
| **S-2** | Service Integration - Complete | Webhooks, Inter-service Events | X | X | | | |
| **S-3** | Mobile App - Production Ready | Complete UI, App Store Ready Build | X | X | | | |
| **S-4** | Desktop App - Production Ready | Admin Dashboard on Desktop | | X | X | | |
| **S-5** | End-to-End Testing | Playwright/Appium Test Suites | | X | X | | |
| **S-6** | Performance Optimization | Load Test Reports, Cache Tuning | | | X | X | |
| **S-7** | Security Audit | Pen-test Report, Security Fixes | | | | X | X |

*(Note: Insert a Gantt Chart image here illustrating these timelines).*
