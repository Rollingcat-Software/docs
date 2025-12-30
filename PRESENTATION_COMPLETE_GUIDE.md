# FIVUCSAS Complete Presentation Guide

**Project:** Face and Identity Verification Using Cloud-Based SaaS Models
**Course:** CSE4197 Engineering Project - Fall 2025
**Date:** January 7, 2026
**Duration:** 12 minutes presentation + 3 minutes Q&A
**Team:** Ahmet Abdullah Gultekin, Ayse Gulsum Eren, Aysenur Arici
**Advisor:** Assoc. Prof. Dr. Mustafa Agaoglu

---

## Table of Contents

1. [Presentation Overview](#1-presentation-overview)
2. [Slide-by-Slide Guide](#2-slide-by-slide-guide)
3. [Presenter Assignments](#3-presenter-assignments)
4. [Technical Diagrams](#4-technical-diagrams)
5. [Q&A Preparation](#5-qa-preparation)
6. [Checklist Before Presentation](#6-checklist-before-presentation)

---

## 1. Presentation Overview

### Time Budget (12 minutes total)

| Section | Slides | Time | Presenter |
|---------|--------|------|-----------|
| Opening (Title + Outline) | 1-2 | 0:45 | Ahmet |
| Problem & Motivation | 3 | 0:45 | Ahmet |
| Related Work & Gap | 4 | 0:50 | Aysenur |
| Scope & Constraints | 5 | 0:40 | Aysenur |
| System Architecture | 6 | 1:00 | Ahmet |
| Biometric Puzzle (Liveness) | 7 | 1:00 | Aysenur |
| ML Pipeline & Vector Search | 8 | 0:50 | Aysenur |
| NFC & Standards | 9 | 0:45 | Gulsum |
| Tasks Accomplished | 10 | 1:00 | Gulsum |
| Challenges & Solutions | 11 | 0:50 | Ahmet |
| Implementation Status | 12 | 0:40 | Gulsum |
| Future Work & B-Plan | 13 | 0:50 | Ahmet |
| References & Thank You | 14 | 0:25 | All |
| **TOTAL** | **14** | **12:00** | |

### Slide Count Compliance
- Required: 12-18 slides
- Our count: 14 slides (within limit)

---

## 2. Slide-by-Slide Guide

---

### SLIDE 1: Title Slide

**Time:** 0:20
**Presenter:** Ahmet Abdullah Gultekin

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│     [Marmara University Logo - Top Left]                        │
│                                                                 │
│                         FIVUCSAS                                │
│     ─────────────────────────────────────────────               │
│     Face and Identity Verification Using                        │
│     Cloud-Based SaaS Models                                     │
│                                                                 │
│     CSE4197 Engineering Project - Fall 2025                     │
│                                                                 │
│     ┌─────────┐  ┌─────────┐  ┌─────────┐                       │
│     │  Photo  │  │  Photo  │  │  Photo  │                       │
│     │ Ahmet   │  │ Gulsum  │  │ Aysenur │                       │
│     └─────────┘  └─────────┘  └─────────┘                       │
│     150121025    150120005    150123825                         │
│                                                                 │
│     Supervisor: Assoc. Prof. Dr. Mustafa Agaoglu                │
│                                                                 │
│     Marmara University, Faculty of Engineering                  │
│     Computer Engineering Department                             │
│                                                                 │
│                                               1/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **Title:** FIVUCSAS (large, bold)
- **Subtitle:** Face and Identity Verification Using Cloud-Based SaaS Models
- **Course:** CSE4197 Engineering Project - Fall 2025
- **Team members:** Names with student IDs (use real photos or remove photos entirely)
- **Supervisor:** Full academic title required
- **Institution:** Marmara University, Faculty of Engineering, Computer Engineering Department
- **Page number:** 1/14 (bottom right)

#### Image Requirements
- Marmara University official logo (upload real logo)
- Team member photos (real photos or remove entirely - NO AI-generated faces)

#### Speech Script
```
"Good morning, distinguished professors. We are presenting FIVUCSAS -
Face and Identity Verification Using Cloud-Based SaaS Models.

I am Ahmet Abdullah Gultekin, and with me are my teammates Ayse Gulsum
Eren and Aysenur Arici. Our project is supervised by Associate Professor
Doctor Mustafa Agaoglu.

Today, we will present our cloud-native biometric authentication platform
designed to address critical security challenges in identity verification."
```

---

### SLIDE 2: Presentation Outline

**Time:** 0:25
**Presenter:** Ahmet Abdullah Gultekin

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│     OUTLINE                                                     │
│     ────────                                                    │
│                                                                 │
│     1. Problem Statement & Motivation                           │
│     2. Related Work & Gap Analysis                              │
│     3. Scope & Engineering Constraints                          │
│     4. System Architecture (Hexagonal DDD)                      │
│     5. The Biometric Puzzle (Hybrid Liveness)                   │
│     6. ML Pipeline & Vector Search                              │
│     7. NFC & Standards Compliance                               │
│     8. Tasks Accomplished                                       │
│     9. Technical Challenges & Solutions                         │
│     10. Implementation Status                                   │
│     11. Future Work & Contingency Plan                          │
│     12. References                                              │
│                                                                 │
│                                               2/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Clean numbered list (12 items)
- Use consistent formatting
- No images needed - text-only slide
- Page number: 2/14

#### Speech Script
```
"Our presentation follows this structure: We will begin with the problem
definition and motivation, then review related work and identify the gap
our system addresses.

We will explain our scope and constraints, followed by a detailed look at
our system architecture using Hexagonal Design principles.

The technical core - our Biometric Puzzle liveness detection, ML pipeline,
and NFC integration - will follow. We will then present our accomplishments,
challenges faced, current implementation status, and our plan for semester two."
```

---

### SLIDE 3: Problem Statement & Motivation

**Time:** 0:45
**Presenter:** Ahmet Abdullah Gultekin

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     PROBLEM STATEMENT & MOTIVATION                              │
│     ──────────────────────────────                              │
│                                                                 │
│  ┌─────────────────────┐    VS    ┌─────────────────────┐       │
│  │  TRADITIONAL AUTH   │          │    FIVUCSAS         │       │
│  │  ─────────────────  │          │    ────────         │       │
│  │                     │          │                     │       │
│  │  [Password Icon]    │          │  [Face + ID Icon]   │       │
│  │  • Stolen           │          │  • Cryptographic    │       │
│  │  • Phished          │          │  • Liveness-proven  │       │
│  │                     │          │                     │       │
│  │  [Card Icon]        │          │  [NFC Chip Icon]    │       │
│  │  • Cloned           │          │  • ICAO Validated   │       │
│  │  • Lost             │          │  • SOD Signed       │       │
│  │                     │          │                     │       │
│  │  [Photo Icon]       │          │  [Puzzle Icon]      │       │
│  │  • Deepfake bypass  │          │  • Active+Passive   │       │
│  │  • Photo spoofing   │          │  • Challenge-Response│      │
│  └─────────────────────┘          └─────────────────────┘       │
│                                                                 │
│  Figure 1: Traditional vs FIVUCSAS Authentication Approaches    │
│                                               3/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Split comparison diagram (Traditional vs FIVUCSAS)
- Three vulnerability categories:
  1. Passwords: stolen, phished
  2. Cards: cloned, lost
  3. Simple biometrics: deepfake bypass, photo spoofing
- Three FIVUCSAS solutions:
  1. Cryptographic proof with face verification
  2. ICAO-compliant NFC validation
  3. Hybrid Active+Passive liveness detection
- Figure caption required
- Page number: 3/14

#### Key Points to Emphasize
- Deepfakes and generative AI are now major threats
- Fragmented identity systems create security gaps
- Need for unified physical + digital authentication

#### Speech Script
```
"Authentication is everywhere - from e-government to banking to building access.
Yet traditional methods have critical vulnerabilities.

Passwords can be stolen or phished. Access cards can be cloned. And here is
the emerging threat: Generative AI now creates Deepfakes so realistic that
standard biometric systems cannot distinguish them from real humans.

Our motivation is to develop a unified platform that combines cryptographic
proof from NFC document chips with a novel hybrid liveness detection approach
we call the Biometric Puzzle. This addresses the gap between physical documents
and digital identity in a way current solutions do not achieve."
```

---

### SLIDE 4: Related Work & Gap Analysis

**Time:** 0:50
**Presenter:** Aysenur Arici

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     RELATED WORK & GAP ANALYSIS                                 │
│     ───────────────────────────                                 │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Feature        │ Azure │ AWS    │ Sodec │ BioGATE│ FIVUCSAS│ │
│  ├────────────────┼───────┼────────┼───────┼────────┼─────────┤ │
│  │ Open Source    │   ✗   │   ✗    │   ✗   │   ✗    │    ✓    │ │
│  │ Liveness       │   ✓   │   ✓    │   ✗   │   ✓    │    ✓    │ │
│  │ Offline Support│   ✗   │   ✗    │   ✓   │   ✗    │    ✓    │ │
│  │ Multi-Tenant   │   ✓   │   ✓    │   ✗   │   ✗    │    ✓    │ │
│  │ Multi-Platform │   ✓   │   ✓    │   ✓   │   ✗    │    ✓    │ │
│  │ NFC ICAO       │   ✗   │   ✗    │   ✗   │   ✓    │    ✓    │ │
│  │ Hybrid Liveness│   ✗   │   ✗    │   ✗   │   ✗    │    ✓    │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  KEY DIFFERENTIATOR:                                            │
│  "The Biometric Puzzle" - Randomized Active Challenge-Response  │
│  combined with Passive Texture Analysis                         │
│                                                                 │
│  Table 1: Comparison with Industrial Solutions                  │
│                                               4/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Comparison table with 5 competitors:
  - Azure Face Liveness
  - AWS Rekognition
  - Sodec Technologies
  - BioGATE Pass
  - FIVUCSAS (our system)
- Features compared:
  - Open Source
  - Liveness Detection
  - Offline Support
  - Multi-Tenant SaaS
  - Multi-Platform
  - NFC ICAO Compliance
  - Hybrid Liveness (Active + Passive)
- Key differentiator callout
- Table caption required
- Page number: 4/14

#### Speech Script
```
"We analyzed both academic literature and industrial solutions. Azure and AWS
offer PAD-compliant liveness but are proprietary and cloud-only with no offline
capability. Sodec provides regional ID verification but lacks advanced liveness.
BioGATE offers NFC compliance but not multi-tenant SaaS.

Our gap analysis reveals no existing solution combines ALL of: open-source
flexibility, hybrid active-plus-passive liveness, multi-tenant cloud architecture,
and ICAO-compliant NFC document verification.

Our key differentiator is the Biometric Puzzle - a randomized challenge-response
mechanism that prevents spoofing even from sophisticated deepfakes, because
attackers cannot predict which actions will be requested."
```

---

### SLIDE 5: Scope & Engineering Constraints

**Time:** 0:40
**Presenter:** Aysenur Arici

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     SCOPE & ENGINEERING CONSTRAINTS                             │
│     ───────────────────────────────                             │
│                                                                 │
│  IN SCOPE                          OUT OF SCOPE                 │
│  ────────                          ────────────                 │
│  ✓ Cloud-Native SaaS Platform      ✗ Hardware Manufacturing     │
│  ✓ Hybrid Liveness Detection       ✗ Custom Camera Firmware     │
│  ✓ NFC Document Reading            ✗ Fingerprint/Iris (MVP)     │
│  ✓ Multi-Tenant Admin Dashboard                                 │
│  ✓ Cross-Platform Mobile App                                    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              ENGINEERING CONSTRAINTS                        ││
│  │  ─────────────────────────────────────────────────────────  ││
│  │                                                             ││
│  │  [Camera Icon]     [Clock Icon]      [Document Icon]        ││
│  │  Image Quality     Latency           NFC Standard           ││
│  │  > 480p required   < 200ms target    ISO 14443              ││
│  │                                                             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Figure 2: Project Scope and Constraints                        │
│                                               5/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Two columns: In Scope / Out of Scope
- Three engineering constraints with icons:
  1. Image Quality: > 480p required for reliable face detection
  2. Latency: < 200ms target for real-time verification
  3. NFC Standard: ISO 14443 compliance required
- Figure caption required
- Page number: 5/14

#### Speech Script
```
"Our scope focuses on the Minimum Viable Product. We are building a cloud-native
SaaS platform with hybrid liveness detection, NFC document reading, and a
multi-tenant admin dashboard.

Hardware manufacturing is out of scope - we simulate edge devices using
Raspberry Pi. Fingerprint and iris recognition are planned for future versions.

Our engineering constraints are critical: images must exceed 480p for reliable
face detection, API response must be under 200 milliseconds for acceptable user
experience, and NFC operations must comply with ISO 14443 standards."
```

---

### SLIDE 6: System Architecture

**Time:** 1:00
**Presenter:** Ahmet Abdullah Gultekin

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     SYSTEM ARCHITECTURE                                         │
│     ───────────────────                                         │
│                                                                 │
│           ┌─────────────────────────────────────────┐           │
│           │            API GATEWAY (NGINX)          │           │
│           │         Rate Limiting, Routing          │           │
│           └─────────────────┬───────────────────────┘           │
│                             │                                   │
│         ┌───────────────────┴───────────────────┐               │
│         │                                       │               │
│         ▼                                       ▼               │
│  ┌─────────────────┐                 ┌─────────────────────┐    │
│  │  IDENTITY CORE  │◄───REST/Event──►│ BIOMETRIC PROCESSOR │    │
│  │  (Spring Boot)  │                 │     (FastAPI)       │    │
│  │                 │                 │                     │    │
│  │ • JWT Auth      │                 │ • 9 ML Models       │    │
│  │ • Multi-Tenant  │                 │ • Liveness          │    │
│  │ • RBAC          │                 │ • 46+ Endpoints     │    │
│  └────────┬────────┘                 └──────────┬──────────┘    │
│           │                                     │               │
│           └─────────────────┬───────────────────┘               │
│                             ▼                                   │
│           ┌─────────────────────────────────────────┐           │
│           │     PostgreSQL 16 + pgvector + Redis    │           │
│           │   2622-D Embeddings, IVFFlat Indexing   │           │
│           └─────────────────────────────────────────┘           │
│                                                                 │
│  Architecture: Hexagonal (Ports & Adapters) + DDD               │
│  Figure 3: High-Level System Architecture                       │
│                                               6/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Three-tier architecture diagram:
  1. API Gateway (NGINX) - rate limiting, routing
  2. Microservices layer:
     - Identity Core (Spring Boot 3.2, Java 21)
     - Biometric Processor (FastAPI, Python 3.11)
  3. Database layer (PostgreSQL 16 + pgvector + Redis)
- Key features for each service
- Architecture pattern: Hexagonal + DDD
- Figure caption required
- Page number: 6/14

#### Image Requirements
- **MUST CREATE MANUALLY** using Draw.io or similar
- Do NOT let Gamma generate this - text will be misspelled

#### Speech Script
```
"Our system follows a microservices architecture with Hexagonal design principles.

At the top, NGINX API Gateway handles rate limiting and request routing.

The Identity Core API, built with Spring Boot 3.2 and Java 21, manages
authentication, multi-tenancy, and role-based access control. It follows
Hexagonal Architecture to isolate business logic from infrastructure.

The Biometric Processor, implemented with FastAPI and Python 3.11, handles
compute-intensive ML operations. It integrates 9 face recognition models and
provides 46 REST endpoints for face enrollment, verification, and liveness detection.

Both services communicate via REST APIs and event-driven messaging through Redis.
The database layer uses PostgreSQL 16 with the pgvector extension for storing
2622-dimensional face embeddings with IVFFlat indexing for fast similarity search."
```

---

### SLIDE 7: The Biometric Puzzle (Liveness Detection)

**Time:** 1:00
**Presenter:** Aysenur Arici

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     THE BIOMETRIC PUZZLE - HYBRID LIVENESS DETECTION            │
│     ────────────────────────────────────────────────            │
│                                                                 │
│  ┌──────────────┐   1. Generate Challenge    ┌──────────────┐   │
│  │    SERVER    │ ─────────────────────────► │    MOBILE    │   │
│  │              │    "Blink Left Eye"        │    CLIENT    │   │
│  │              │                            │              │   │
│  │              │   2. Capture Stream        │              │   │
│  │              │ ◄───────────────────────── │   [Camera]   │   │
│  │              │                            │              │   │
│  │  Calculate   │   3. EAR = 0.18 < 0.2     │              │   │
│  │     EAR      │ ─────────────────────────► │   VERIFY     │   │
│  │              │      ✓ Blink Detected      │              │   │
│  │              │                            │              │   │
│  │   Passive    │   4. LBP Texture Check     │              │   │
│  │   Analysis   │ ─────────────────────────► │    PASS      │   │
│  │              │      ✓ Not a Screen        │              │   │
│  └──────────────┘                            └──────────────┘   │
│                                                                 │
│  ACTIVE: EAR (Eye Aspect Ratio), MAR (Mouth), Head Pose         │
│  PASSIVE: LBP Texture, Color Distribution, Frequency Domain     │
│                                                                 │
│  Figure 4: Biometric Puzzle Challenge-Response Protocol         │
│                                               7/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Sequence diagram showing challenge-response flow:
  1. Server generates cryptographic random challenge
  2. Mobile captures video stream
  3. EAR calculation (threshold < 0.2)
  4. Parallel passive texture analysis
- Two categories:
  - ACTIVE: EAR, MAR, Head Pose (pitch/yaw/roll)
  - PASSIVE: LBP texture, color distribution, frequency domain, moire pattern
- Figure caption required
- Page number: 7/14

#### Key Technical Metrics
- Eye Aspect Ratio threshold: EAR < 0.2
- 468 facial landmarks via MediaPipe
- On-device processing: ~50ms latency (vs 500ms cloud)

#### Speech Script
```
"The Biometric Puzzle is our original contribution to active liveness detection.

Here is how it works: The server generates a cryptographically random challenge -
for example, 'blink your left eye.' The attacker cannot predict which action will
be requested, making replay attacks impossible.

The mobile client captures a video stream and uses MediaPipe to track 468 facial
landmarks. We calculate the Eye Aspect Ratio - when EAR drops below 0.2, a blink
is detected.

Simultaneously, we run passive analysis - Local Binary Pattern texture analysis
and frequency domain checks detect if the face is displayed on a screen rather
than being a real person.

This hybrid approach combines the unpredictability of active challenges with the
spoofing detection of passive analysis, providing robust defense against deepfakes,
printed photos, and video replay attacks."
```

---

### SLIDE 8: ML Pipeline & Vector Search

**Time:** 0:50
**Presenter:** Aysenur Arici

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     ML PIPELINE & VECTOR SEARCH                                 │
│     ───────────────────────────                                 │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    RECOGNITION PIPELINE                     ││
│  │                                                             ││
│  │  [Input]     [Detect]    [Align]    [Extract]    [Search]   ││
│  │     │           │           │           │            │      ││
│  │     ▼           ▼           ▼           ▼            ▼      ││
│  │   Image  →  Face Box  →  Aligned  →  Embedding  →  Match   ││
│  │            MediaPipe    5-Point     2622-D        Cosine    ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  9 FACE RECOGNITION MODELS:                                     │
│  ┌────────────┬────────────┬────────────┬────────────┐          │
│  │ DeepFace   │ FaceNet128 │ FaceNet512 │  ArcFace   │          │
│  │ (4096-D)   │  (128-D)   │  (512-D)   │  (512-D)   │          │
│  ├────────────┼────────────┼────────────┼────────────┤          │
│  │ VGG-Face   │   Dlib     │  OpenFace  │   SFace    │          │
│  │ (2622-D)*  │  (128-D)   │  (128-D)   │  (128-D)   │          │
│  └────────────┴────────────┴────────────┴────────────┘          │
│  * Default model for production                                 │
│                                                                 │
│  VECTOR DATABASE: PostgreSQL + pgvector + IVFFlat → O(log n)    │
│                                                                 │
│  Figure 5: ML Pipeline and Model Architecture                   │
│                                               8/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Pipeline diagram: Input → Detection → Alignment → Extraction → Search
- Model grid showing 9 face recognition models with embedding dimensions
- Vector database specification:
  - PostgreSQL 16 + pgvector extension
  - IVFFlat indexing for O(log n) search
  - 2622-dimensional embeddings (VGG-Face default)
- Figure caption required
- Page number: 8/14

#### Speech Script
```
"Our ML pipeline processes face images through five stages: detection, alignment,
embedding extraction, and similarity search.

We integrated 9 face recognition models through the DeepFace framework. VGG-Face,
producing 2622-dimensional embeddings, is our default for production due to its
high accuracy. ArcFace and FaceNet provide alternative options optimized for
different scenarios.

For storage, we use PostgreSQL with the pgvector extension. The IVFFlat index
enables approximate nearest neighbor search in O(log n) time complexity, allowing
sub-millisecond queries even with large enrollment databases.

For 1:1 verification, we compute cosine distance - if the distance is below our
empirically optimized threshold of 0.68, verification succeeds. For 1:N search,
the vector index returns top-k candidates for identification."
```

---

### SLIDE 9: NFC & Standards Compliance

**Time:** 0:45
**Presenter:** Ayse Gulsum Eren

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     NFC & STANDARDS COMPLIANCE                                  │
│     ──────────────────────────                                  │
│                                                                 │
│  ┌──────────────┐                        ┌──────────────┐       │
│  │    MOBILE    │                        │   ID CARD    │       │
│  │    (NFC)     │                        │   (CHIP)     │       │
│  └──────┬───────┘                        └──────┬───────┘       │
│         │                                       │               │
│         │  1. SELECT AID                        │               │
│         │ ─────────────────────────────────────►│               │
│         │                                       │               │
│         │  2. GET CHALLENGE                     │               │
│         │ ─────────────────────────────────────►│               │
│         │                                       │               │
│         │  3. BAC: MRZ-derived Session Keys     │               │
│         │ ◄────────────────────────────────────►│               │
│         │     (3DES Secure Messaging)           │               │
│         │                                       │               │
│         │  4. READ DG1 (Personal Data)          │               │
│         │ ─────────────────────────────────────►│               │
│         │                                       │               │
│         │  5. READ DG2 (HD Photo - JPEG2000)    │               │
│         │ ─────────────────────────────────────►│               │
│         │                                       │               │
│         │  6. VERIFY SOD (Digital Signature)    │               │
│         │ ◄─────────────────────────────────────│               │
│         │      ✓ Document Authentic             │               │
│         ▼                                       ▼               │
│                                                                 │
│  STANDARDS: ICAO Doc 9303, ISO/IEC 14443, ISO 7816-4            │
│  CARDS: Turkish eID, e-Passport, 10+ card types                 │
│                                                                 │
│  Figure 6: NFC BAC Authentication Handshake                     │
│                                               9/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Sequence diagram: Mobile NFC ↔ ID Card Chip handshake
- Six steps:
  1. SELECT AID (Application Identifier)
  2. GET CHALLENGE
  3. BAC (Basic Access Control) with MRZ-derived keys
  4. READ DG1 (Personal Data)
  5. READ DG2 (High-resolution photo in JPEG2000)
  6. VERIFY SOD (Security Object Document) digital signature
- Standards listed: ICAO Doc 9303, ISO/IEC 14443, ISO 7816-4
- Supported cards: Turkish eID, e-Passport, 10+ card types
- Figure caption required
- Page number: 9/14

#### Speech Script
```
"Our NFC Reader module supports ICAO-compliant identity document verification.

The protocol starts by selecting the chip application, then establishing Basic
Access Control. The session keys are derived from the Machine Readable Zone -
the printed text on the document - ensuring only someone with physical access
to the document can read the chip.

Once 3DES secure messaging is established, we read Data Group 1 containing
personal information, and Data Group 2 containing a high-resolution JPEG2000
photograph - significantly better quality than the printed photo.

Finally, we verify the Security Object Document, a digital signature that
proves the data has not been tampered with since issuance.

Our reader supports Turkish National ID cards, e-Passports, and over 10 other
card types including MIFARE and NDEF tags, making it a universal solution."
```

---

### SLIDE 10: Tasks Accomplished

**Time:** 1:00
**Presenter:** Ayse Gulsum Eren

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     TASKS ACCOMPLISHED - FALL 2025                              │
│     ──────────────────────────────                              │
│                                                                 │
│  BIOMETRIC PROCESSOR (100%)                                     │
│  • 46+ REST API endpoints (FastAPI)                             │
│  • 9 ML models integrated via DeepFace                          │
│  • Hybrid liveness detection implemented                        │
│  • 254 Python source files                                      │
│                                                                 │
│  DEMO WEB GUI (100%)                                            │
│  • 14+ interactive pages (Next.js 14, TypeScript)               │
│  • Dashboard, Enrollment, Verification, Search, Liveness        │
│  • Real-time proctoring with WebSocket streaming                │
│                                                                 │
│  IDENTITY CORE API (68%)                                        │
│  • JWT authentication with refresh tokens (HS512)               │
│  • Multi-tenant architecture with row-level security            │
│  • Hexagonal architecture, 105 Java source files                │
│                                                                 │
│  NFC READER (85%)                                               │
│  • 60+ Kotlin files with Hilt DI                                │
│  • 10+ card types supported (Turkish eID, e-Passport, MIFARE)   │
│  • BAC authentication, SOD validation implemented               │
│                                                                 │
│  DATABASE (100%)                                                │
│  • 10 tables, 6 Flyway migrations                               │
│  • pgvector with IVFFlat indexing                               │
│                                                                 │
│                                              10/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Five component categories with completion percentages:
  1. Biometric Processor: 100%
  2. Demo Web GUI: 100%
  3. Identity Core API: 68%
  4. NFC Reader: 85%
  5. Database Schema: 100%
- Key metrics for each:
  - 46+ endpoints
  - 9 ML models
  - 14+ web pages
  - 60+ Kotlin files
  - 10 database tables
- Page number: 10/14

#### Speech Script
```
"Let me present what we have accomplished this semester.

The Biometric Processor is 100% complete with 46 REST API endpoints covering
face enrollment, verification, search, liveness detection, quality analysis,
and demographics. We integrated 9 face recognition models and have 254 Python
source files.

Our Demo Web GUI is also complete - 14 interactive pages built with Next.js
and TypeScript, including a real-time proctoring system using WebSocket streaming.

The Identity Core API is at 68% completion. JWT authentication with refresh
tokens works, and we have implemented multi-tenant row-level security following
Hexagonal Architecture principles.

Our NFC Reader is 85% complete - 60 Kotlin files supporting 10 card types with
BAC authentication and SOD validation.

The database schema is complete with 10 tables, 6 Flyway migrations, and pgvector
integration for efficient embedding storage and search."
```

---

### SLIDE 11: Technical Challenges & Solutions

**Time:** 0:50
**Presenter:** Ahmet Abdullah Gultekin

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     TECHNICAL CHALLENGES & SOLUTIONS                            │
│     ────────────────────────────────                            │
│                                                                 │
│  ┌─────────────────────────┬───────────────────────────────────┐│
│  │       CHALLENGE         │           SOLUTION                ││
│  ├─────────────────────────┼───────────────────────────────────┤│
│  │                         │                                   ││
│  │ Vector Search Latency   │ Migrated to IVFFlat indexing      ││
│  │ (High-dimensional       │ on pgvector → O(log n) ANN        ││
│  │  embedding queries)     │ with sub-ms query time            ││
│  │                         │                                   ││
│  ├─────────────────────────┼───────────────────────────────────┤│
│  │ Cross-Platform          │ Kotlin Multiplatform + Compose    ││
│  │ Hardware Access         │ with platform abstraction layer   ││
│  │ (Camera, NFC, Storage)  │ for Android/Desktop/iOS           ││
│  │                         │                                   ││
│  ├─────────────────────────┼───────────────────────────────────┤│
│  │ 9 ML Models in RAM      │ Containerized services with       ││
│  │ (Memory pressure on     │ lazy loading + model caching      ││
│  │  single server)         │ via Redis                         ││
│  │                         │                                   ││
│  ├─────────────────────────┼───────────────────────────────────┤│
│  │ NFC Protocol            │ Modular reader architecture       ││
│  │ Complexity              │ (7 specialized readers)           ││
│  │ (Different card types)  │ Factory pattern for card types    ││
│  │                         │                                   ││
│  └─────────────────────────┴───────────────────────────────────┘│
│                                                                 │
│  Table 2: Engineering Challenges and Solutions                  │
│                                              11/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Four-row table with Challenge | Solution columns
- Challenges:
  1. Vector search latency for high-dimensional embeddings
  2. Cross-platform hardware access (camera, NFC, storage)
  3. Multiple ML models consuming RAM
  4. Complex NFC protocols for different card types
- Solutions:
  1. IVFFlat indexing → O(log n) approximate nearest neighbor
  2. Kotlin Multiplatform with abstraction layer
  3. Containerized services with lazy loading
  4. Modular reader architecture with Factory pattern
- Table caption required
- Page number: 11/14

#### Speech Script
```
"We encountered several significant engineering challenges.

First, vector search latency - with 2622-dimensional embeddings, naive search
was too slow. We solved this by implementing IVFFlat indexing in pgvector,
achieving O(log n) approximate nearest neighbor search with sub-millisecond
query times.

Second, cross-platform hardware access - camera and NFC APIs differ across
Android, iOS, and Desktop. We used Kotlin Multiplatform with a platform
abstraction layer, sharing 90% of our codebase across platforms.

Third, memory management - loading 9 ML models simultaneously was infeasible.
We implemented lazy loading with Redis caching, loading models on-demand and
caching frequently used ones.

Fourth, NFC protocol complexity - different card types use different protocols.
We designed a modular reader architecture with 7 specialized readers and a
Factory pattern that selects the appropriate reader based on detected card type."
```

---

### SLIDE 12: Implementation Status

**Time:** 0:40
**Presenter:** Ayse Gulsum Eren

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     IMPLEMENTATION STATUS                                       │
│     ─────────────────────                                       │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                                                             ││
│  │  Biometric Processor API                                    ││
│  │  ████████████████████████████████████████████████  100%     ││
│  │                                                             ││
│  │  Demo Web GUI (Next.js)                                     ││
│  │  ████████████████████████████████████████████████  100%     ││
│  │                                                             ││
│  │  Database Schema + Migrations                               ││
│  │  ████████████████████████████████████████████████  100%     ││
│  │                                                             ││
│  │  NFC Reader (Universal)                                     ││
│  │  ██████████████████████████████████████████░░░░░░   85%     ││
│  │                                                             ││
│  │  Identity Core API                                          ││
│  │  ██████████████████████████████████░░░░░░░░░░░░░░   68%     ││
│  │                                                             ││
│  │  Mobile/Desktop App (UI)                                    ││
│  │  ████████████████████████████░░░░░░░░░░░░░░░░░░░░   60%     ││
│  │                                                             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  OVERALL PROJECT PROGRESS: ~85% MVP                             │
│                                                                 │
│  Figure 7: Component Implementation Progress                    │
│                                              12/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Six horizontal progress bars:
  1. Biometric Processor API: 100%
  2. Demo Web GUI: 100%
  3. Database Schema: 100%
  4. NFC Reader: 85%
  5. Identity Core API: 68%
  6. Mobile/Desktop App: 60%
- Overall progress indicator: ~85% MVP
- Figure caption required
- Page number: 12/14

#### Image Requirements
- **UPLOAD REAL SCREENSHOT** of dashboard or Swagger UI if possible
- Progress bars can be generated by Gamma or created manually

#### Speech Script
```
"Here is our current implementation status visualized as progress bars.

Three components are 100% complete: the Biometric Processor API with all 46
endpoints functional, the Demo Web GUI with 14 interactive pages, and our
database schema with all migrations applied.

The NFC Reader is at 85% - core functionality works, with some edge cases
remaining for less common card types.

The Identity Core API is at 68% - authentication and multi-tenancy work,
but RBAC enforcement is still being implemented.

The Mobile and Desktop application UI is 60% complete - screens are built,
but backend integration is at 30%.

Overall, we are approximately 85% toward our MVP goal, well-positioned to
complete integration in semester two."
```

---

### SLIDE 13: Future Work & Contingency Plan

**Time:** 0:50
**Presenter:** Ahmet Abdullah Gultekin

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     FUTURE WORK & CONTINGENCY PLAN (B-PLAN)                     │
│     ───────────────────────────────────────                     │
│                                                                 │
│  SPRING 2026 TIMELINE                                           │
│  ────────────────────                                           │
│                                                                 │
│  FEB ─────► Service Integration (Identity Core ↔ Biometric)     │
│             API contracts, event-driven messaging               │
│                                                                 │
│  MAR ─────► Full NFC Mobile Integration                         │
│             Complete card type support, UI polish               │
│                                                                 │
│  APR ─────► Security & Penetration Testing                      │
│             OWASP compliance, vulnerability assessment          │
│                                                                 │
│  MAY ─────► Production Deployment & Documentation               │
│             Cloud deployment, final documentation               │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  CONTINGENCY PLANS (B-PLAN)                                 ││
│  │  ──────────────────────────                                 ││
│  │  IF Universal NFC fails → Limit to Turkish eID only         ││
│  │  IF WebSocket latency high → Fallback to REST polling       ││
│  │  IF Mobile integration delayed → Desktop-first deployment   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Figure 8: Semester 2 Timeline and Contingency Plans            │
│                                              13/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Four-month timeline: February → May 2026
  - February: Service integration
  - March: NFC mobile integration
  - April: Security testing
  - May: Production deployment
- Three contingency plans (B-Plan):
  1. If universal NFC fails → Turkish eID only
  2. If WebSocket latency high → REST polling fallback
  3. If mobile delayed → Desktop-first deployment
- Figure caption required
- Page number: 13/14

#### Speech Script
```
"For semester two, we have a clear timeline with contingency plans.

In February, we focus on service integration - connecting Identity Core with
the Biometric Processor through well-defined API contracts and event-driven
messaging.

March is dedicated to completing NFC mobile integration with full card type
support and UI refinement.

In April, we conduct security and penetration testing to ensure OWASP compliance
and address any vulnerabilities.

May brings production deployment to a cloud environment and final documentation.

We have prepared contingency plans: If universal NFC parsing proves unreliable,
we will limit support to Turkish National ID only. If WebSocket streaming has
latency issues, we fall back to REST polling. If mobile integration is delayed,
we prioritize desktop deployment first. These plans ensure we deliver a working
product regardless of unforeseen obstacles."
```

---

### SLIDE 14: References & Thank You

**Time:** 0:25
**Presenter:** All Team Members

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     REFERENCES                                                  │
│     ──────────                                                  │
│                                                                 │
│  [1] Taigman et al. (2014). DeepFace: Closing the Gap to        │
│      Human-Level Performance. CVPR.                             │
│                                                                 │
│  [2] Schroff et al. (2015). FaceNet: Unified Embedding for      │
│      Face Recognition. IEEE CVPR.                               │
│                                                                 │
│  [3] Deng et al. (2019). ArcFace: Additive Angular Margin       │
│      Loss for Deep Face Recognition. CVPR.                      │
│                                                                 │
│  [4] ICAO Doc 9303: Machine Readable Travel Documents.          │
│      International Civil Aviation Organization.                 │
│                                                                 │
│  [5] ISO/IEC 14443: Contactless Smart Card Standards.           │
│                                                                 │
│  [6] ISO/IEC 30107-3: Presentation Attack Detection (PAD).      │
│                                                                 │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│                      THANK YOU                                  │
│                                                                 │
│           Questions & Discussion Welcome                        │
│                                                                 │
│  GitHub: github.com/[your-repo]/FIVUCSAS                        │
│                                                                 │
│                                              14/14              │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- 6 key references in academic format:
  1. DeepFace (Taigman et al., 2014)
  2. FaceNet (Schroff et al., 2015)
  3. ArcFace (Deng et al., 2019)
  4. ICAO Doc 9303
  5. ISO/IEC 14443
  6. ISO/IEC 30107-3 (PAD)
- Thank you message
- GitHub repository link (use real link)
- Page number: 14/14

#### Speech Script
```
"These are our key references - foundational papers on face recognition
including DeepFace, FaceNet, and ArcFace, along with the ICAO and ISO
standards that guide our NFC implementation and liveness detection compliance.

Thank you for your attention. We are now ready for questions and discussion.

Our code is available on GitHub, and we welcome any feedback on our technical
approach or implementation."
```

---

## 3. Presenter Assignments

### Time Distribution by Presenter

| Presenter | Slides | Total Time | Topics |
|-----------|--------|------------|--------|
| **Ahmet Abdullah** | 1, 2, 3, 6, 11, 13 | ~4:20 | Opening, Architecture, Challenges, Future |
| **Aysenur Arici** | 4, 5, 7, 8 | ~3:20 | Related Work, Scope, Liveness, ML Pipeline |
| **Ayse Gulsum** | 9, 10, 12 | ~2:25 | NFC, Tasks, Implementation Status |
| **All** | 14 | ~0:25 | References, Thank You |

### Transition Scripts

**Ahmet → Aysenur (after Slide 3):**
```
"Now Aysenur will present our analysis of related work and the gap we identified."
```

**Aysenur → Ahmet (after Slide 5):**
```
"Ahmet will now explain our system architecture in detail."
```

**Ahmet → Aysenur (after Slide 6):**
```
"Aysenur will present our key innovation - the Biometric Puzzle liveness detection."
```

**Aysenur → Gulsum (after Slide 8):**
```
"Gulsum will now cover our NFC implementation and standards compliance."
```

**Gulsum → Ahmet (after Slide 10):**
```
"Ahmet will discuss the technical challenges we faced and how we solved them."
```

**Ahmet → Gulsum (after Slide 11):**
```
"Gulsum will present our current implementation status."
```

**Gulsum → Ahmet (after Slide 12):**
```
"Finally, Ahmet will present our plan for semester two."
```

---

## 4. Technical Diagrams

### Diagrams to Create Manually

**CRITICAL:** Do NOT let Gamma.app generate these diagrams. Create them manually using Draw.io, Excalidraw, or PowerPoint.

#### 4.1 Hexagonal Architecture Diagram (Slide 6)

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

#### 4.2 Biometric Puzzle Flow (Slide 7)

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

#### 4.3 NFC Handshake (Slide 9)

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

### Screenshots to Capture

| Screenshot | Purpose | Where to Get |
|------------|---------|--------------|
| FastAPI Swagger UI | Proves 46+ endpoints exist | `http://localhost:8001/docs` |
| Web Dashboard | Shows working admin interface | Run Next.js app |
| NFC Scan Screen | Demonstrates NFC functionality | Mobile app or photo |
| Database Tables | Shows schema implementation | pgAdmin |

---

## 5. Q&A Preparation

### Likely Questions and Answers

#### Q1: "How does the Biometric Puzzle prevent deepfake attacks?"

**Answer:**
```
"Deepfakes are pre-generated content. Our Biometric Puzzle generates random
challenges in real-time - the attacker cannot know in advance whether we will
ask for a blink, smile, or head turn. Additionally, our passive analysis
checks for screen artifacts like moire patterns and unnatural color distribution
that deepfakes displayed on screens will exhibit."
```

#### Q2: "What is your verification accuracy?"

**Answer:**
```
"Using VGG-Face embeddings with a cosine distance threshold of 0.68 optimized
on the LFW dataset, we target False Acceptance Rate below 1% and False Rejection
Rate below 3%, giving an Equal Error Rate of approximately 3%. This is
comparable to commercial solutions."
```

#### Q3: "Why did you choose PostgreSQL with pgvector over dedicated vector databases?"

**Answer:**
```
"Three reasons: First, unified data management - user profiles and their
embeddings stay together with referential integrity. Second, transaction
support - enrollment is atomic. Third, operational simplicity - one database
to maintain instead of two. With IVFFlat indexing, query performance is
sufficient for our scale."
```

#### Q4: "How do you handle multi-tenancy security?"

**Answer:**
```
"We implement row-level security in PostgreSQL. Every user-scoped table has
a tenant_id column, and database policies ensure queries only return data
for the authenticated tenant. This is enforced at the database level, not
just application logic, providing defense in depth."
```

#### Q5: "What happens if the NFC chip reading fails?"

**Answer:**
```
"Our B-Plan addresses this. If universal NFC parsing proves unreliable, we
limit support to Turkish National ID cards only, which we have thoroughly
tested. The modular architecture allows us to disable specific card type
readers without affecting the rest of the system."
```

#### Q6: "How do you ensure KVKK/GDPR compliance?"

**Answer:**
```
"We implement data minimization - storing only embeddings, not original images.
We support the right to be forgotten through soft deletes. Biometric data is
encrypted at rest using AES-256, and all transmission uses TLS 1.3. Explicit
user consent is required before any biometric processing."
```

---

## 6. Checklist Before Presentation

### One Week Before

- [ ] Create all technical diagrams manually (Draw.io/Excalidraw)
- [ ] Capture required screenshots (Swagger, Dashboard, NFC)
- [ ] Upload Marmara University logo
- [ ] Replace team photos (use real photos or remove)
- [ ] Practice full presentation (target: under 12 minutes)

### Day Before

- [ ] Verify slide count: 14 slides
- [ ] Check page numbers on ALL slides (1/14 through 14/14)
- [ ] Verify figure captions on ALL diagrams
- [ ] Confirm advisor name: "Assoc. Prof. Dr. Mustafa Agaoglu"
- [ ] Remove any fake contact information
- [ ] Test presentation on projector/large screen
- [ ] Check font readability from back of room

### Morning Of

- [ ] Arrive 15 minutes early
- [ ] Test laptop-projector connection
- [ ] Have backup on USB drive
- [ ] Bring printed notes for each presenter
- [ ] Water bottles for presenters

### During Presentation

- [ ] Ahmet starts with slides 1-3, 6
- [ ] Aysenur covers slides 4-5, 7-8
- [ ] Gulsum presents slides 9-10, 12
- [ ] Ahmet handles slides 11, 13
- [ ] All together for slide 14 + Q&A
- [ ] Watch the clock - 12 minutes max
- [ ] ~40-50 seconds per slide average

---

## Key Numbers to Memorize

| Metric | Value | Context |
|--------|-------|---------|
| API Endpoints | 46+ | Biometric Processor |
| ML Models | 9 | Face recognition models |
| Embedding Dimensions | 2622-D | VGG-Face default |
| EAR Threshold | 0.2 | Blink detection |
| Cosine Threshold | 0.68 | Verification match |
| Facial Landmarks | 468 | MediaPipe Face Mesh |
| Python Files | 254 | Biometric Processor |
| Kotlin Files | 60+ | NFC Reader |
| Database Tables | 10 | Full schema |
| Flyway Migrations | 6 | Schema versioning |
| Target FAR | < 1% | False Acceptance Rate |
| Target FRR | < 3% | False Rejection Rate |

---

**Document Created:** December 30, 2025
**Last Updated:** December 30, 2025
**Author:** Generated for FIVUCSAS Team
**Purpose:** Complete Presentation Guide for January 7, 2026 Defense
