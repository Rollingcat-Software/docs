# FIVUCSAS Gamma.app Presentation Guide

**Created:** December 27, 2025
**Purpose:** Complete guide for creating the January 7, 2026 graduation project presentation
**Tool:** Gamma.app

---

## 1. Gamma.app Settings

### Card Size
**Select:** `16:9 (Traditional)`

### Text Amount
**Select:** `Minimal` or `Low`

### Tone
**Select:** `Professional` or `Formal`

### Audience
**Select:** `Executives` or type `Academic/Professors`

### Language
**Select:** `English`

### Slide Count
**Set:** `16 slides`

### Image Art Style
**Select:** `Illustration`
- Clean, professional look for technical/academic presentations
- Works best for architecture diagrams, flowcharts, icons
- Not distracting like 3D or abstract

### Theme
Look for: `Midnight`, `Slate`, `Corporate`, or `Navy`
- Dark blue or navy primary color
- Clean, minimal design
- Professional appearance

---

## 2. Extra Keywords

```
biometric, facial recognition, cloud SaaS, identity verification, multi-tenant, liveness detection, biometric puzzle, NFC reader, Turkish eID, passport reader, MIFARE, machine learning, DeepFace, FaceNet, ArcFace, VGG-Face, MediaPipe, YOLOv8, facial landmarks, demographics analysis, age estimation, gender detection, emotion recognition, proctoring, WebSocket streaming, real-time verification, card type detection, document verification, Istanbulkart, pgvector, vector database, embeddings, similarity search, batch processing, webhooks, JWT authentication, RBAC, hexagonal architecture, Kotlin Multiplatform, Compose Multiplatform, FastAPI, Spring Boot, Next.js, cross-platform, kiosk mode, BAC authentication, SOD validation, ICAO Doc 9303, ISO 7816-4
```

---

## 3. Additional Instructions (Copy-Paste Ready)

### VERSION 2: Academic Engineering Defense (Recommended)

```
Create a TECHNICAL ENGINEERING DEFENSE presentation for Computer Engineering professors at Marmara University. This is NOT a marketing pitch - it's a rigorous academic evaluation.

PROJECT: FIVUCSAS - Cloud-Native Face & Identity Verification SaaS
TEAM: Ahmet Abdullah Gultekin, Ayse Gulsum Eren, Aysenur Arici
ADVISOR: Assoc. Prof. Dr. Mustafa Agaoglu
SLIDE COUNT: Strictly 14-15 slides

SLIDE STRUCTURE (Follow Exactly):

SLIDE 1 - TITLE:
- FIVUCSAS: Cloud-Native Face & Identity Verification SaaS
- CSE4197 Engineering Project - Fall 2025
- Team names, Advisor with full academic title
- Marmara University, Computer Engineering Dept.

SLIDE 2 - OUTLINE:
1. Problem Statement & Motivation
2. Related Work & Gap Analysis
3. Scope & Engineering Constraints
4. System Architecture (Hexagonal DDD)
5. The Biometric Puzzle (Hybrid Liveness)
6. ML Pipeline & Vector Search
7. NFC & Standards Compliance
8. Tasks Accomplished
9. Technical Challenges & Solutions
10. Implementation Status
11. Future Work & B-Plan
12. References

SLIDE 3 - PROBLEM & MOTIVATION:
- Problem: Passive biometrics vulnerable to Deepfakes/Injection attacks; fragmented physical vs digital identity
- Motivation: Unified SaaS combining Physical NFC + Hybrid Liveness Detection
- Visual: Split comparison diagram "Traditional Weak Auth" vs "FIVUCSAS Cryptographic Proof"

SLIDE 4 - RELATED WORK & GAP ANALYSIS:
Create comparison table:
| Solution | Liveness | NFC | Deployment |
|----------|----------|-----|------------|
| AWS Rekognition | Passive Only | No | Public Cloud |
| Azure Face API | Passive Only | No | Expensive |
| Apple FaceID | Active (HW) | No | Not SaaS |
| FIVUCSAS | Hybrid (Active+Passive) | ICAO 9303 | Multi-tenant SaaS |
Key Differentiator: "The Biometric Puzzle" - Randomized Challenge-Response

SLIDE 5 - SCOPE & CONSTRAINTS:
In-Scope: Cloud-Native SaaS, Hybrid Liveness, NFC Document Reading, Multi-tenant Admin
Out-of-Scope: Hardware manufacturing, Custom camera firmware
Engineering Constraints:
- Camera: >480p required
- NFC: ISO 14443 compliance
- Latency: <200ms real-time verification

SLIDE 6 - SYSTEM ARCHITECTURE:
- Pattern: Domain-Driven Design + Hexagonal Architecture (Ports & Adapters)
- Components:
  * Identity Core (Spring Boot 3.2, Java 21): Tenants, Auth, Orchestration
  * Biometric Processor (FastAPI, Python 3.11): DeepFace/ArcFace inference
  * Communication: REST + WebSocket + Async events
- Visual: Hexagonal diagram with Core Domain isolated from API/Persistence layers

SLIDE 7 - THE BIOMETRIC PUZZLE (Liveness):
Algorithm Flow:
1. Server generates cryptographic random challenge (Blink Left/Smile/Turn Head)
2. Mobile Client captures stream, calculates Eye Aspect Ratio (EAR)
3. If EAR < 0.2 threshold → Blink verified
4. Parallel: Passive Texture Analysis (LBP/Frequency) detects screen spoofing
5. Combined score determines liveness
- Visual: Flowchart of Challenge-Response protocol

SLIDE 8 - ML PIPELINE & VECTOR SEARCH:
Models (9 Total): DeepFace, FaceNet-128D, FaceNet512, ArcFace-512D, VGG-Face-2622D, MediaPipe, Dlib, YOLOv8, Custom CNN
Storage Engineering:
- Database: PostgreSQL 16 + pgvector extension
- Indexing: IVFFlat for O(log n) approximate nearest neighbor
- Embeddings: 2622-dimensional vectors
- Visual: Pipeline diagram showing Face → Detection → Embedding → Vector DB → Search

SLIDE 9 - NFC & STANDARDS COMPLIANCE:
Standards: ICAO Doc 9303, ISO/IEC 14443, ISO 7816-4
Protocol Flow:
1. OCR extracts MRZ (Machine Readable Zone)
2. BAC (Basic Access Control) derives session keys from MRZ
3. 3DES Secure Messaging established
4. DG1 (Personal Data) + DG2 (HD Photo) extracted
5. SOD (Security Object Document) validates digital signature
- Visual: Handshake diagram Mobile NFC ↔ ID Card Chip

SLIDE 10 - TASKS ACCOMPLISHED:
- Biometric Processor: 46+ REST endpoints, 9 ML models integrated, Dockerized
- Demo Web GUI: 14 interactive pages (Next.js 14, TypeScript)
- Identity Core: JWT auth, Multi-tenancy, Hexagonal architecture
- NFC Readers: 60+ Kotlin files, 10+ card types supported
- Database: 6 Flyway migrations, pgvector, 14 tables
- Mobile/Desktop: KMP/CMP, 90% code sharing, 5 ViewModels

SLIDE 11 - TECHNICAL CHALLENGES & SOLUTIONS:
| Challenge | Solution |
|-----------|----------|
| Vector Search Latency | Migrated to IVFFlat indexing on pgvector |
| Cross-Platform HW Access | Abstracted with Kotlin Multiplatform |
| 9 ML Models in RAM | Containerized services with lazy loading |
| NFC Protocol Complexity | Modular reader architecture (7 specialized readers) |

SLIDE 12 - IMPLEMENTATION STATUS:
Show as visual progress bars/gauges:
- Biometric Processor API: 100% ████████████
- Web Dashboard (Next.js): 100% ████████████
- NFC Reader (Universal): 85% ██████████░░
- Identity Core API: 68% ████████░░░░
- Mobile/Desktop UI: 60% ███████░░░░░

SLIDE 13 - FUTURE WORK & B-PLAN:
Spring 2026 Timeline:
- February: Service integration (Identity Core ↔ Biometric)
- March: Full NFC Mobile integration
- April: Security penetration testing
- May: Production deployment

B-Plan (Contingency):
- If universal NFC parsing fails → Limit to Turkish ID only
- If WebSocket latency high → Fallback to REST polling
- If mobile integration delayed → Desktop-first deployment

SLIDE 14 - REFERENCES:
- Serengil, S. (2020). DeepFace: Hybrid Face Recognition Framework
- ICAO Doc 9303: Machine Readable Travel Documents
- ISO/IEC 14443: Contactless Smart Card Standards
- ISO/IEC 29794-5: Biometric Quality Metrics
- [Add 2-3 more relevant citations]

DESIGN REQUIREMENTS:
- NO marketing language - purely technical
- Use diagrams over bullet points where possible
- Show actual metrics (EAR < 0.2, 2622-D, O(log n))
- Professional dark blue theme
- Page numbers on every slide (1/14, 2/14, etc.)
- Figure captions for all diagrams
- Minimal text (max 25 words per slide body)
- Clean sans-serif fonts
```

---

### VERSION 1: Original Comprehensive (Backup)

<details>
<summary>Click to expand original prompt</summary>

```
Create a graduation project defense presentation for Computer Engineering professors at Marmara University. This is a comprehensive biometric identity verification platform called FIVUCSAS.

CRITICAL FEATURES TO INCLUDE:

BIOMETRIC PROCESSOR (100% Complete):
- 46+ REST API endpoints with FastAPI
- 9 ML models: DeepFace, FaceNet (128-D), FaceNet512 (512-D), ArcFace (512-D), VGG-Face (2622-D), MediaPipe, Dlib, YOLOv8, Custom CNN
- Face Enrollment (1:1), Face Verification (1:1), Face Search (1:N)
- Liveness Detection with HYBRID approach: Passive (texture/LBP, color distribution, frequency domain, moire pattern) + Active Biometric Puzzle (EAR blink, MAR smile, head pose pitch/yaw/roll)
- Quality Analysis with ISO/IEC 29794-5 metrics
- Demographics: Age, Gender, Emotion detection
- 468-point Facial Landmark detection with MediaPipe
- Card/Document Type Detection with YOLOv8
- Face Comparison and NxN Similarity Matrix with clustering
- Batch Operations for bulk processing
- Embeddings Export/Import
- Webhooks for event notifications
- Real-time Proctoring System with WebSocket streaming

DEMO WEB GUI (100% Complete):
- 14+ interactive pages: Dashboard, Enrollment, Verification, Search, Liveness, Quality, Demographics, Landmarks, Card Detection, Similarity Matrix, Batch Operations, Proctoring Session, Real-time Streaming, API Explorer
- Next.js 14, TypeScript, shadcn/ui, Tailwind CSS

IDENTITY CORE API (68% Complete):
- Spring Boot 3.2, Java 21
- JWT Authentication (HS512) with 7-day refresh tokens
- User Registration with BCrypt hashing
- Multi-Tenancy with row-level security
- Hexagonal Architecture (ports & adapters)
- 7 DDD Value Objects
- 25 Unit test files
- RBAC schema ready (enforcement pending)

MOBILE/DESKTOP APP (60% Complete - UI):
- Kotlin Multiplatform (KMP) + Compose Multiplatform
- 90% code sharing across Android, Desktop (JVM), iOS
- Android: Login, Register, Home, Biometric Enroll, Biometric Verify screens
- Desktop: Welcome, Enroll, Verify, Admin Dashboard (Users, Analytics, Security, Settings tabs)
- Kiosk mode for self-service terminals
- Clean Architecture with MVVM, Koin DI, Ktor HTTP client
- 10 Use Cases, 5 ViewModels

NFC READER - UNIVERSAL (85% Complete):
- 60+ Kotlin files with Hilt DI
- Supports 10+ card types: Turkish eID, e-Passport, Istanbulkart, MIFARE Classic 1K/4K, MIFARE DESFire, MIFARE Ultralight, NDEF tags, ISO 15693 (NfcV), Student Cards, Generic NFC-A/B/F
- BAC Authentication with MRZ parsing
- 3DES Secure Messaging
- SOD Signature Validation with Bouncy Castle
- DG1 (personal data) and DG2 (JPEG2000 photo) parsing
- Security: PIN memory-only handling, two-phase memory wipe, PII log redaction

NFC READER - TURKISH eID (100% Complete):
- Specialized for Turkish National ID Card
- 6-digit PIN verification
- Photo extraction from DG2 (JPEG2000)
- Material Design 3 UI
- Standards: ISO 14443-3/4, ISO 7816-4, ICAO Doc 9303

DATABASE SCHEMA (100% Complete):
- PostgreSQL 16 with pgvector extension
- 6 Flyway migrations
- Tables: tenants, users, permissions, roles, role_permissions, user_roles, biometric_data, liveness_attempts, verification_logs, audit_logs, refresh_tokens, active_sessions, password_history, security_events
- 2622-dimensional face embedding vectors with IVFFlat indexing
- Multi-tenant isolation, soft delete, comprehensive audit trail

ARCHITECTURE:
- Hexagonal/Clean Architecture across all components
- Domain-Driven Design with 22 entity classes
- 20+ use cases in application layer
- Microservices-ready design
- Docker and Kubernetes-ready infrastructure

DESIGN INSTRUCTIONS:
- Use large, clean icons instead of bullet points
- Show architecture diagrams with boxes and arrows
- Display progress bars for implementation status (100%, 85%, 68%, 60%)
- Include flowcharts for ML pipeline and liveness detection
- Visualize the 9 ML models as a connected diagram
- Show NFC card types as icon grid
- Keep text minimal (max 25 words per slide)
- Use professional blue color scheme
- Add subtle entrance animations
- Make scannable at a glance for 12-minute presentation
```

</details>

---

## 4. Image Strategy (Critical for High Grade)

### The "Proof of Life" Rule - Real Screenshots Required

Since there is NO live demo, screenshots are your ONLY evidence that the system works. AI-generated images will make professors assume you haven't written code.

#### MUST UPLOAD (Replace Gamma's AI Images):

| Slide | Required Screenshot | How to Get It |
|-------|---------------------|---------------|
| 6 | Swagger/API Docs | `http://localhost:8000/docs` - FastAPI automatic docs |
| 9 | NFC Scan Screen | Phone showing "Reading Chip..." OR photo of phone on ID card |
| 11 | Admin Dashboard | Next.js dashboard with graphs/verification list |
| 12 | GitHub/Project Board | GitHub insights, commits, or Trello/Jira board |

---

### Engineering Diagrams - MUST Draw Manually

**DO NOT let Gamma generate architecture diagrams** - AI cannot spell text correctly inside diagrams.

Use **Draw.io**, **Excalidraw**, or **PowerPoint** to create:

#### 1. Hexagonal Architecture (Slide 6)
```
                    ┌─────────────────┐
                    │   REST API      │
                    │   (Adapter)     │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        │    ┌───────────────▼───────────────┐    │
        │    │                               │    │
   ┌────┴────┤      DOMAIN CORE              ├────┴────┐
   │ Port    │   (Entities, Use Cases)       │  Port   │
   └────┬────┤                               ├────┬────┘
        │    └───────────────┬───────────────┘    │
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                    ┌────────┴────────┐
                    │   PostgreSQL    │
                    │   (Adapter)     │
                    └─────────────────┘
```

#### 2. Biometric Puzzle Flow (Slide 7)
```
┌──────────┐    1. Generate Challenge    ┌──────────┐
│  SERVER  │ ─────────────────────────▶  │  MOBILE  │
│          │    "Blink Left Eye"         │  CLIENT  │
│          │                             │          │
│          │  2. Capture Frame Stream    │          │
│          │ ◀─────────────────────────  │  Camera  │
│          │                             │          │
│ Calculate│  3. EAR = 0.18 < 0.2       │          │
│   EAR    │ ─────────────────────────▶  │  VERIFY  │
│          │    ✓ Blink Detected         │          │
│          │                             │          │
│ Parallel:│  4. LBP Texture Check       │          │
│ Passive  │ ─────────────────────────▶  │  PASS    │
│ Analysis │    ✓ Not a Screen           │          │
└──────────┘                             └──────────┘
```

#### 3. NFC Handshake (Slide 9)
```
┌──────────────┐                    ┌──────────────┐
│    MOBILE    │                    │   ID CARD    │
│    (NFC)     │                    │   (CHIP)     │
└──────┬───────┘                    └──────┬───────┘
       │                                   │
       │  1. SELECT AID (A00000016745)     │
       │ ─────────────────────────────────▶│
       │                                   │
       │  2. GET CHALLENGE                 │
       │ ─────────────────────────────────▶│
       │                                   │
       │  3. BAC: MRZ-derived Keys         │
       │ ◀────────────────────────────────▶│
       │     (3DES Session Established)    │
       │                                   │
       │  4. READ DG1 (Personal Data)      │
       │ ─────────────────────────────────▶│
       │                                   │
       │  5. READ DG2 (JPEG2000 Photo)     │
       │ ─────────────────────────────────▶│
       │                                   │
       │  6. VERIFY SOD (Digital Sig)      │
       │ ◀─────────────────────────────────│
       │     ✓ Document Authentic          │
       ▼                                   ▼
```

---

### What Gamma CAN Generate (Visual Metaphors Only)

For concept slides, use these specific prompts:

| Concept | Gamma Prompt |
|---------|--------------|
| Vector Search | "3D scatter plot of data points in vector space, mathematical, minimal, blue and white data visualization" |
| Liveness Detection | "Face with 3D mesh wireframe overlay, facial landmarks, biometric analysis, cyan neon lines, dark background" |
| NFC Security | "Isometric illustration of digital ID card floating with padlock and shield, minimal tech style" |
| Cloud Architecture | "Clean cloud infrastructure diagram, microservices boxes connected, blue gradient, no text" |

---

### RED FLAGS - What to AVOID

| Bad Image | Why It's Bad |
|-----------|--------------|
| Hacker in hoodie | Looks childish, cliché |
| Matrix code background | Adds no value, distracting |
| Robot shaking hands | Generic, proves nothing |
| AI-generated text in diagrams | Will be misspelled, looks careless |
| Stock photo of "diverse team" | Fake, professors see through it |
| Abstract data tunnels | Meaningless visual noise |

---

### Screenshot Checklist (Before Presentation)

- [ ] FastAPI Swagger UI (`/docs`) showing 46+ endpoints
- [ ] Next.js Dashboard with real data/graphs
- [ ] Mobile app NFC screen (or photo of phone on card)
- [ ] Liveness demo showing face mesh overlay
- [ ] GitHub repository insights (commits, contributors)
- [ ] pgAdmin showing biometric_data table structure
- [ ] Terminal showing Docker containers running

---

## 5. Card-by-Card Content Structure (14 Slides - Academic Defense)

| # | Slide Title | Key Content | Image Type |
|---|-------------|-------------|------------|
| 1 | Title & Team | Project name, team, advisor (full title), university | Marmara logo (upload) |
| 2 | Outline | 12-point presentation roadmap | None needed |
| 3 | Problem & Motivation | Deepfake vulnerability, identity silos | Gamma: comparison visual |
| 4 | Related Work & Gap | AWS/Azure/Apple comparison table, our differentiator | Table (no image) |
| 5 | Scope & Constraints | In/Out scope, engineering constraints (<200ms, >480p) | None needed |
| 6 | System Architecture | Hexagonal DDD, Identity Core + Biometric Processor | **UPLOAD: Draw.io diagram** |
| 7 | Biometric Puzzle | EAR < 0.2, Challenge-Response flow, Passive + Active | **UPLOAD: Sequence flowchart** |
| 8 | ML Pipeline | 9 models, pgvector, IVFFlat, 2622-D embeddings | Gamma: vector space visual |
| 9 | NFC Standards | ICAO 9303, BAC, 3DES, SOD validation | **UPLOAD: NFC handshake + phone photo** |
| 10 | Tasks Accomplished | 46+ endpoints, 14 pages, 60+ Kotlin files, 6 migrations | **UPLOAD: Swagger screenshot** |
| 11 | Challenges & Solutions | Latency, Cross-platform, RAM, Protocol complexity | Table (no image) |
| 12 | Implementation Status | Progress bars: 100%, 100%, 85%, 68%, 60% | **UPLOAD: Dashboard screenshot** |
| 13 | Future Work & B-Plan | Timeline + 3 contingency plans | Gamma: timeline visual |
| 14 | References | 5-6 academic citations | None needed |

**Legend:**
- **UPLOAD** = You MUST replace Gamma's image with real screenshot/diagram
- **Gamma** = Let Gamma generate using specific prompt from Section 4
- **None** = Text-only slide, no image needed

---

## 6. Presentation Review & Critique

### Version 3 Review (20 Slides) - December 27, 2025

#### Overall Score: 8/10 - Good Progress, Minor Fixes Needed

---

### CRITICAL ISSUES

#### 1. Slide Count: 20 slides (Exceeds 12-18 limit!)

**Action:** Delete 2-3 slides to reach 17-18 slides maximum.

#### 2. Slide 20 - DUPLICATE "The Challenge" Slide

The last slide is a duplicate of an earlier "Problem" slide showing the same content.

**Fix:** DELETE Slide 20 entirely.

#### 3. Slide 18 - Duplicate Thank You Content

Slide 18 contains Thank You content that duplicates Slide 17.

**Fix:** Either merge with Slide 17 or DELETE Slide 18.

#### 4. Slide 1 - Unfilled Advisor Placeholder

```
[Assoc. Prof. Dr. Name]  ← MUST BE FILLED
```

**Fix:** Replace with: `Assoc. Prof. Dr. Mustafa Agaoglu`

#### 5. Contact Information Still Fake

```
team@fivucsas.com     ← Does not exist
github.com/fivucsas   ← Incorrect
```

**Fix:** Replace with:
- Real GitHub: `github.com/ahabgultekin/FIVUCSAS` (or actual repo)
- University emails or remove contact section entirely

#### 6. AI-Generated Team Photos Still Present

The team photos are still AI-generated faces of random people.

**Fix:** Remove them completely OR add real team photos.

---

### MISSING REQUIREMENTS

#### Page Numbers - NOT PRESENT

Professor requires page numbers on all slides.

**Fix:** Add page numbers (e.g., "1/18", "2/18", etc.) to bottom of each slide.

#### Figure Captions - INCONSISTENT

Some figures have captions, others don't.

**Fix:** Add captions to all diagrams and images.

---

### MINOR ISSUES

| Slide | Issue | Fix |
|-------|-------|-----|
| 9 (ML Models) | One logo placeholder is blank/gray | Replace with proper model logo |
| 11 | Slide transition feels abrupt | Add connecting text |
| 17 | Thank You could include References | Add key references as required |

---

### POSITIVE IMPROVEMENTS (vs Version 1)

- All 8 required sections now present
- Outline slide added (Slide 2)
- Problem definition clear
- Scope and methodology covered
- Tasks accomplished detailed
- Difficulties encountered addressed
- Future work with timeline included
- Technology stack visualized
- Architecture diagrams proper (no more mountain scenery)
- Biometric Puzzle explained well
- NFC Reader and Mobile App slides added

---

### RECOMMENDED FINAL STRUCTURE (18 Slides)

After removing duplicates:

| # | Slide Title | Status |
|---|-------------|--------|
| 1 | Title (Team, Advisor, Project) | Fix advisor name |
| 2 | Outline | OK |
| 3 | Problem Definition | OK |
| 4 | Project Aims | OK |
| 5 | Related Work & Novelties | OK |
| 6 | Scope | OK |
| 7 | System Architecture | OK |
| 8 | Biometric Processor API | OK |
| 9 | ML Models (9 Total) | Fix blank logo |
| 10 | Biometric Puzzle (Liveness) | OK |
| 11 | Demo Web Interface | OK |
| 12 | Identity Core API | OK |
| 13 | Mobile/Desktop App | OK |
| 14 | NFC Reader | OK |
| 15 | Difficulties Encountered | OK |
| 16 | Implementation Progress | OK |
| 17 | Future Work & Timeline | OK |
| 18 | Thank You + References | Combine, fix contact |

**DELETE:** Slides 18 (duplicate Thank You) and 20 (duplicate Challenge)

---

### PREVIOUS VERSIONS

<details>
<summary>Version 1 Review (10 Slides) - Score: 6/10</summary>

**Issues Found:**
- Only 10 slides (6 missing)
- Architecture image showed mountains instead of technical diagram
- Missing: Mobile App, NFC Reader, Database, Tech Stack, Progress slides
- Fake contact info, AI-generated team photos
</details>

---

## 7. Action Items Checklist

### Critical (Must Fix Before Presentation)
- [ ] DELETE Slide 20 (duplicate "The Challenge")
- [ ] DELETE or merge Slide 18 (duplicate Thank You)
- [ ] Replace `[Assoc. Prof. Dr. Name]` with `Assoc. Prof. Dr. Mustafa Agaoglu`
- [ ] Add page numbers to all slides
- [ ] Final slide count: 17-18 slides

### Important (Should Fix)
- [ ] Fix or remove fake contact information
- [ ] Remove AI-generated team photos OR add real photos
- [ ] Fix blank logo placeholder in ML Models slide
- [ ] Add figure captions to all diagrams

### Nice to Have
- [ ] Add key references to Thank You slide
- [ ] Smooth slide transitions
- [ ] Practice timing: 12 minutes total, ~40 seconds per slide

---

## 8. Presentation Requirements (From Professor)

Source: `Fall2025_CSE4197-SunumToplantısı.pdf`

### Format Requirements
- **Duration:** 12 minutes + 3 minutes Q&A
- **Slides:** 12-18 slides required
- **Language:** English
- **Presenters:** All team members must present

### Required Slide Structure
| # | Requirement | Status |
|---|-------------|--------|
| 1 | Title: Team, Advisor (with title), Project Name | Fix advisor placeholder |
| 2 | Outline | OK |
| Last | References | Add to final slide |

### 8 Required Content Sections
1. Problem definition
2. Project aims
3. Related work and novelties
4. Scope
5. Methodology and technical approach
6. Tasks accomplished
7. Difficulties encountered
8. Tasks for semester 2 with timetable and B-plan

### Formatting Requirements
- [ ] Page numbers on all slides
- [ ] Figure captions for all diagrams
- [ ] Academic citation format for references

---

**Document Location:** `docs/GAMMA_PRESENTATION_GUIDE.md`
**Related Document:** `docs/IMPLEMENTATION_STATUS_REPORT.md`
**Last Updated:** December 27, 2025
