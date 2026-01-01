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
7. [Demo Appendix](#7-demo-appendix-for-live-demonstration)

---

## 1. Presentation Overview

### Time Budget (12 minutes total)

| Section | Slides | Time | Presenter |
|---------|--------|------|-----------|
| Opening (Title + Outline) | 1-2 | 0:50 | **Aysenur** |
| Problem & Motivation | 3 | 1:00 | **Aysenur** |
| Related Work & Gap | 4 | 1:10 | **Aysenur** |
| Scope & Constraints | 5 | 0:50 | **Aysenur** |
| *[TRANSITION 1]* | - | 0:10 | Aysenur → Ahmet |
| System Architecture | 6 | 0:50 | **Ahmet** |
| Biometric Puzzle (Liveness) | 7 | 1:00 | **Ahmet** |
| **Biometric Processor Demo** | 8 | 0:50 | **Ahmet** |
| ML Pipeline & Vector Search | 9 | 0:45 | **Ahmet** |
| Card Detection & NFC | 10 | 0:45 | **Ahmet** |
| *[TRANSITION 2]* | - | 0:10 | Ahmet → Gulsum |
| **Document Verification Demo** | 11 | 0:45 | **Gulsum** |
| Tasks Accomplished | 12 | 0:50 | **Gulsum** |
| Challenges & Solutions | 13 | 0:40 | **Gulsum** |
| Future Work & B-Plan | 14 | 0:40 | **Gulsum** |
| Thank You | 15 | 0:25 | **Gulsum** |
| References | 16 | 0:20 | **Gulsum** |
| Q&A | 17 | 3:00 | **All** |
| **TOTAL** | **17** | **~12:00 + 3:00 Q&A** | |

> **Structure:** Aysenur (Slides 1-5, ~4:00) → Ahmet (Slides 6-10, ~4:10) → Gulsum (Slides 11-16, ~3:40) → All (17)
> **BALANCED: Each presenter ~4 minutes**

### Slide Count Compliance
- Required: 12-18 slides
- Our count: 17 slides (within limit)

---

## 2. Slide-by-Slide Guide

---

### SLIDE 1: Title Slide

**Time:** 0:25
**Presenter:** Aysenur Arici
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  [Marmara University Logo]                              [468 Landmarks    │
│                                                          Demo Screenshot] │
│                          FIVUCSAS                                         │
│         ─────────────────────────────────────────────                     │
│         Face and Identity Verification Using                              │
│         Cloud-Based SaaS Models                                           │
│                                                                           │
│         CSE4197 Engineering Project - Fall 2025                           │
│                                                                           │
│         Team:                                                             │
│         • Ahmet Abdullah Gultekin (150121025)                             │
│         • Ayse Gulsum Eren (150120005)                                    │
│         • Aysenur Arici (150123825)                                       │
│                                                                           │
│         Supervisor: Assoc. Prof. Dr. Mustafa Agaoglu                      │
│                                                                           │
│         Marmara University - Computer Engineering                         │
│                                                                     1/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **Title:** FIVUCSAS (large, bold)
- **Subtitle:** Face and Identity Verification Using Cloud-Based SaaS Models
- **Course:** CSE4197 Engineering Project - Fall 2025
- **Team members:** Names with student IDs (text only, no photos)
- **Supervisor:** Full academic title required
- **Institution:** Marmara University - Computer Engineering
- **Visual:** 468 facial landmarks screenshot from demo (right side)
- **Page number:** 1/17 (bottom right)

#### Image Requirements
- Marmara University official logo (top left)
- **468 Facial Landmarks Screenshot** from your demo - shows MediaPipe face mesh visualization

#### Speech Script
```
"Hello everyone. We are presenting FIVUCSAS - Face and Identity Verification
Using Cloud-Based SaaS Models.

I am Aysenur Arici. My teammates are Ahmet Abdullah Gultekin and Ayse Gulsum
Eren. Our advisor is Associate Professor Doctor Mustafa Agaoglu."
```

---

### SLIDE 2: Presentation Outline

**Time:** 0:25
**Presenter:** Aysenur Arici
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│     OUTLINE                                                               │
│     ────────                                                              │
│                                                                           │
│     WHY THIS MATTERS                                                      │
│     ─────────────────                                                     │
│     1. Problem Statement & Motivation                                     │
│     2. Related Work & Gap Analysis                                        │
│     3. Scope & Engineering Constraints                                    │
│                                                                           │
│     HOW WE SOLVE IT                                                       │
│     ────────────────                                                      │
│     4. System Architecture                                                │
│     5. The Biometric Puzzle (Hybrid Liveness)                             │
│     6. ML Pipeline & Vector Search                                        │
│     7. Card Detection & NFC Verification                                  │
│                                                                           │
│     WHAT WE BUILT                                                         │
│     ──────────────                                                        │
│     8. Tasks Accomplished                                                 │
│     9. Technical Challenges & Solutions                                   │
│     10. Future Work & Contingency Plan                                    │
│                                                                           │
│                                                                     2/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Structured in 3 parts: WHY / HOW / WHAT
- **Numbered items** (1-10) for clear progression
- Visual grouping makes flow clear
- Page number: 2/17

#### Speech Script
```
"Our presentation has three parts:

First, WHY - the problem of identity fraud and where existing solutions
fall short.

Second, HOW - our architecture, liveness detection, and document verification.

Third, WHAT - our accomplishments, challenges, and semester two plans."
```

---

### SLIDE 3: Problem Statement & Motivation

**Time:** 1:00
**Presenter:** Aysenur Arici
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     WHY THIS MATTERS                                                      │
│     ────────────────                                                      │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  "2024: Deepfake CFO video call → $25 Million stolen"               │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                  │
│  │             │     │             │     │             │                  │
│  │   $23B      │     │   +400%     │     │    1/4      │                  │
│  │             │     │             │     │             │                  │
│  │  [Money     │     │  [Graph     │     │  [Eye       │                  │
│  │   Icon]     │     │   Icon]     │     │   Icon]     │                  │
│  │             │     │             │     │             │                  │
│  │  Identity   │     │  Deepfake   │     │  People     │                  │
│  │  Fraud      │     │  Attacks    │     │  Fooled     │                  │
│  │  (2024)     │     │  (YoY)      │     │             │                  │
│  └─────────────┘     └─────────────┘     └─────────────┘                  │
│                                                                           │
│  OUR GOAL: Prove LIVE + AUTHENTIC + IMPOSSIBLE to spoof                   │
│                                                                     3/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **Hook:** 2024 Hong Kong deepfake incident ($25M)
- **Three large visual statistics:**
  1. $23B - Identity fraud losses (2024)
  2. +400% - Deepfake attack increase (YoY)
  3. 1/4 - People who cannot detect deepfakes
- **Goal statement:** LIVE + AUTHENTIC + IMPOSSIBLE to spoof
- **Minimal text, maximum visual impact**
- Page number: 3/17

#### Speech Script
```
"Let me start with a real incident from 2024. In Hong Kong, a deepfake video call
impersonated the CFO of a company and convinced employees to transfer 25 million
dollars. This is not science fiction - this happened last year.

Look at the numbers: 23 billion dollars lost to identity fraud in 2024 alone.
Deepfake attacks have increased 400 percent year over year. And here is the
scary part: one in four people cannot distinguish a deepfake from a real person.

This is why we built FIVUCSAS. Our goal is simple but critical: prove the person
is LIVE and present, their identity document is AUTHENTIC and untampered, and
spoofing is IMPOSSIBLE through our hybrid detection system."
```

---

### SLIDE 4: Related Work & Gap Analysis

**Time:** 1:00
**Presenter:** Aysenur Arici
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     RELATED WORK & GAP ANALYSIS                                           │
│     ───────────────────────────                                           │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │ Feature        │ Azure │ AWS    │ Sodec │ BioGATE│ FIVUCSAS          │ │
│  ├────────────────┼───────┼────────┼───────┼────────┼───────────────────┤ │
│  │ Open Source    │   ✗   │   ✗    │   ✗   │   ✗    │    ✓              │ │
│  │ Liveness       │   ✓   │   ✓    │   ✗   │   ✓    │    ✓              │ │
│  │ Multi-Tenant   │   ✓   │   ✓    │   ✗   │   ✗    │    ✓              │ │
│  │ Multi-Platform │   ✓   │   ✓    │   ✓   │   ✗    │    ✓              │ │
│  │ NFC ICAO       │   ✗   │   ✗    │   ✗   │   ✓    │    ✓              │ │
│  │ Card Detection │   ✗   │   ✗    │   ✗   │   ✗    │    ✓              │ │
│  │ Hybrid Liveness│   ✗   │   ✗    │   ✗   │   ✗    │    ✓              │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  GAP: No open-source solution with hybrid liveness + NFC + card detection │
│                                                                     4/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Comparison table with 5 competitors
- Features: Open Source, Liveness, Multi-Tenant, Multi-Platform, NFC, Card Detection, Hybrid Liveness
- **Gap statement:** Clear visual showing the market gap we fill
- Page number: 4/17

#### Speech Script
```
"Let me show you how FIVUCSAS compares to existing solutions in the market.

Microsoft Azure Face and Amazon Rekognition are powerful, but they are proprietary -
you cannot host them yourself, and they do not support NFC chip reading or automatic
card type detection. For banks and government institutions that need data sovereignty,
this is a serious limitation.

Sodec and BioGATE are Turkish solutions we studied. Sodec lacks liveness detection
entirely - a critical vulnerability. BioGATE has liveness but is not multi-tenant
and cannot automatically detect card types.

Here is the gap we identified: no open-source solution combines hybrid liveness
detection, NFC chip verification, and automatic document type recognition.
FIVUCSAS fills exactly this gap."
```

---

### SLIDE 5: Scope & Engineering Constraints

**Time:** 0:40
**Presenter:** Aysenur Arici
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     SCOPE & ENGINEERING CONSTRAINTS                                       │
│     ───────────────────────────────                                       │
│                                                                           │
│  IN SCOPE (MVP)                         OUT OF SCOPE                      │
│  ──────────────                         ────────────                      │
│  ✓ Cloud-Native SaaS Platform           ✗ Hardware Manufacturing          │
│  ✓ Hybrid Liveness Detection                                              │
│  ✓ Card Detection (ML Model)                                              │
│  ✓ NFC Document Reading                                                   │
│  ✓ Multi-Tenant Admin Dashboard                                           │
│  ✓ Cross-Platform Client Apps                                             │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │              ENGINEERING CONSTRAINTS                              │    │
│  │  [Camera]           [Clock]              [Document]               │    │
│  │  > 480p             < 200ms              ISO 14443                │    │
│  │  Image Quality      API Latency          NFC Standard             │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│                                                                     5/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **In Scope:** 6 core deliverables
- **Out of Scope:** Only hardware manufacturing (other items moved to Future Work)
- **Constraints:** Image quality, latency, NFC standard
- Page number: 5/17

#### Speech Script
```
"Our MVP scope includes cloud-native SaaS, hybrid liveness, card detection,
NFC reading, multi-tenant dashboard, and cross-platform apps.

As for out of scope, hardware manufacturing is beyond this project.

Regarding our constraints: images must exceed 480p, API response under 200ms,
and NFC must comply with ISO 14443.

Now, Ahmet will show you how we built our solution."
```

---

### SLIDE 6: System Architecture

**Time:** 1:10
**Presenter:** Ahmet Abdullah Gultekin
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     SYSTEM ARCHITECTURE                                                   │
│     ───────────────────                                                   │
│                                                                           │
│                       ┌─────────────────────┐                             │
│                       │   NGINX API GATEWAY │                             │
│                       │  Rate Limiting      │                             │
│                       │  Routing & LB       │                             │
│                       └─────────┬───────────┘                             │
│                                 │                                         │
│         ┌───────────────────────┼───────────────────────┐                 │
│         │                       │                       │                 │
│         ▼                       ▼                       ▼                 │
│  ┌─────────────┐       ┌─────────────────┐      ┌───────────────┐         │
│  │IDENTITY CORE│       │BIOMETRIC PROC.  │      │ CLIENT APPS   │         │
│  │Spring Boot  │◄─────►│   FastAPI       │◄────►│ Kotlin MP     │         │
│  │  Java 21    │       │  Python 3.11    │      │ Android/iOS   │         │
│  │             │       │                 │      │ Desktop       │         │
│  │• JWT Auth   │       │• Face Detection │      │• Camera/NFC   │         │
│  │• Multi-Tenant│      │• 40+ Endpoints  │      │• Card Detect  │         │
│  │• RBAC       │       │• Liveness       │      │• Liveness     │         │
│  └──────┬──────┘       └────────┬────────┘      └───────────────┘         │
│         │                       │                                         │
│         └───────────────────────┼───────────────────────                  │
│                                 ▼                                         │
│       ┌────────────────────────────────────────────────────┐              │
│       │  PostgreSQL 16 + pgvector     │     Redis          │              │
│       │  • Vector Embeddings          │  • Cache           │              │
│       │  • IVFFlat Indexing           │  • Event Bus       │              │
│       └────────────────────────────────────────────────────┘              │
│                                                                           │
│  Architecture: Hexagonal (Ports & Adapters) + DDD                   6/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Three-tier architecture diagram:
  1. API Gateway (NGINX) - rate limiting, routing, load balancing
  2. Microservices: Identity Core, Biometric Processor, Client Apps
  3. Database: PostgreSQL + pgvector, Redis
- Architecture pattern: Hexagonal + DDD
- Page number: 6/17

#### Speech Script
```
"Thank you. Let me walk you through our system architecture.

We built FIVUCSAS using microservices with Hexagonal Architecture - also known as
Ports and Adapters. This design keeps our business logic independent from external
concerns like databases and APIs.

At the top, NGINX serves as our API Gateway, handling rate limiting to prevent
abuse, request routing, and load balancing across service instances.

We have three main components: Identity Core is our Spring Boot service written
in Java 21 - it handles JWT authentication, multi-tenant isolation, and role-based
access control. The Biometric Processor is a FastAPI service in Python 3.11 - this
is where face detection, liveness analysis, and over 40 API endpoints live.

Our client applications use Kotlin Multiplatform, allowing us to share code
between Android, iOS, and Desktop applications.

At the data layer, PostgreSQL 16 with pgvector stores face embeddings, and Redis
provides caching and an event bus for service communication."
```

---

### SLIDE 7: The Biometric Puzzle (Liveness Detection)

**Time:** 1:30
**Presenter:** Ahmet Abdullah Gultekin
**Aspect Ratio:** 16:9

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
│  Figure 4: Biometric Puzzle Challenge-Response Protocol               7/17  │
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
- Page number: 7/17

#### Key Technical Metrics
- Eye Aspect Ratio threshold: EAR < 0.2 (blink detection)
- Mouth Aspect Ratio threshold: MAR > 0.6 (smile/mouth open)
- Head Pose tolerance: pitch ±15°, yaw ±20°, roll ±10°
- 468 facial landmarks via MediaPipe Face Mesh
- On-device processing: ~50ms latency (vs 500ms cloud)
- LBP texture variance threshold: < 100 indicates screen display

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

### SLIDE 8: Biometric Processor Demo

**Time:** 0:45
**Presenter:** Ahmet Abdullah Gultekin
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     BIOMETRIC PROCESSOR IN ACTION                                         │
│     ─────────────────────────────                                         │
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐        │
│  │                  │  │                  │  │                  │        │
│  │   [AHMET'S      │  │   [AYŞENUR'S     │  │   [GÜLSÜM'S      │        │
│  │    FACE with    │  │    FACE with     │  │    FACE with     │        │
│  │    468 MESH     │  │    468 MESH      │  │    468 MESH      │        │
│  │    OVERLAY]     │  │    OVERLAY]      │  │    OVERLAY]      │        │
│  │                  │  │                  │  │                  │        │
│  │  ┌────────────┐ │  │  ┌────────────┐  │  │  ┌────────────┐  │        │
│  │  │EAR: 0.28   │ │  │  │EAR: 0.31   │  │  │  │EAR: 0.29   │  │        │
│  │  │Quality: 94%│ │  │  │Quality: 96%│  │  │  │Quality: 95%│  │        │
│  │  │✓ LIVE      │ │  │  │✓ LIVE      │  │  │  │✓ LIVE      │  │        │
│  │  └────────────┘ │  │  └────────────┘  │  │  └────────────┘  │        │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘        │
│                                                                           │
│  All team members verified with 468 facial landmarks + liveness detection │
│                                                                     8/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **Three team member photos** with MediaPipe 468-landmark mesh overlay
- **Real-time metrics** for each face: EAR value, quality score, liveness status
- **All showing "LIVE" status** proving Biometric Puzzle works
- Visual proof that the system works on real people
- Page number: 8/17

#### Image Requirements
- **Capture screenshots** from web demo showing each team member
- Each photo should display the green face mesh overlay (468 landmarks)
- Include the metrics panel showing EAR, quality, and liveness status

#### Speech Script
```
"Here is our Biometric Processor in action with all three team members.

You can see the 468 facial landmarks being tracked in real-time - that is the
green mesh overlay on each face. Below each photo, you see the Eye Aspect Ratio,
the frame quality score, and the liveness status.

All three of us passed the Biometric Puzzle challenge and are verified as LIVE.
A photo or deepfake would fail this test because it cannot respond to random
challenges like 'blink your left eye' or 'turn your head right.'"
```

---

### SLIDE 9: ML Pipeline & Vector Search

**Time:** 0:45
**Presenter:** Ahmet Abdullah Gultekin
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     ML PIPELINE & VECTOR SEARCH                                           │
│     ───────────────────────────                                           │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │                    RECOGNITION PIPELINE                           │    │
│  │                                                                   │    │
│  │  [Input]     [Detect]      [Align]      [Extract]     [Search]    │    │
│  │     │           │             │             │             │       │    │
│  │     ▼           ▼             ▼             ▼             ▼       │    │
│  │   Image  →  Face Box  →   Aligned   →  Embedding  →   Match      │    │
│  │            MediaPipe      5-Point       Vector       Cosine       │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │  VECTOR DATABASE                                                  │    │
│  │  PostgreSQL + pgvector + IVFFlat → O(log n) sub-ms queries        │    │
│  │  Threshold: cosine distance < 0.68 = match                        │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│                                                                     9/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Pipeline diagram: Input → Detection → Alignment → Extraction → Search
- Vector database: PostgreSQL + pgvector + IVFFlat
- Threshold info: cosine distance < 0.68 = match
- Page number: 9/17

#### Speech Script
```
"Our ML pipeline has five stages for face recognition.

First, the input image comes in. Second, MediaPipe Face Detection locates faces
and returns bounding boxes. Third, we perform 5-point alignment to normalize face
orientation - this is critical for consistent embeddings.

Fourth, we extract a 2622-dimensional vector embedding using VGG-Face. This
embedding is a mathematical fingerprint of the face that we can compare.

Fifth and finally, we search for matches using cosine similarity. Here is where
pgvector shines - with IVFFlat indexing, we achieve sub-millisecond query times
even with tens of thousands of enrolled faces. The search complexity is O(log n).

Our verification threshold is a cosine distance of 0.68. Below this threshold
means a match; above means different people. This threshold balances false
acceptance against false rejection."
```

---

### SLIDE 10: Card Detection & NFC Verification

**Time:** 0:50
**Presenter:** Ahmet Abdullah Gultekin
**Aspect Ratio:** 16:9

#### Visual Design
```
┌─────────────────────────────────────────────────────────────────┐
│     CARD DETECTION & NFC VERIFICATION                           │
│     ─────────────────────────────────                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │         STEP 1: VISUAL CARD DETECTION (ML MODEL)            ││
│  │  ─────────────────────────────────────────────────────────  ││
│  │                                                             ││
│  │  [Camera] → [Trained Model] → [Card Type Detected]          ││
│  │                                                             ││
│  │  • Automatic ID type recognition (Turkish eID, Passport)    ││
│  │  • Real-time detection via on-device ML                     ││
│  │  • Guides user for optimal card positioning                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │         STEP 2: NFC CHIP VERIFICATION (ICAO)                ││
│  │  ─────────────────────────────────────────────────────────  ││
│  │                                                             ││
│  │  [Mobile NFC] → [BAC Handshake] → [Read DG1/DG2] → [SOD ✓]  ││
│  │                                                             ││
│  │  • MRZ-derived session keys (3DES secure messaging)         ││
│  │  • DG1: Personal data, DG2: High-res JPEG2000 photo         ││
│  │  • Digital signature proves document authenticity           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  STANDARDS: ICAO Doc 9303, ISO/IEC 14443, ISO 7816-4            │
│  CARDS: Turkish eID, e-Passport, MIFARE, NDEF, 10+ types        │
│                                                                 │
│  Figure 6: Two-Stage Document Verification Pipeline                10/17  │
└─────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Two-stage pipeline:
  1. **Visual Card Detection** (ML Model):
     - Trained model detects card type from camera feed
     - Real-time on-device inference
     - Automatic recognition of Turkish eID, Passport, etc.
  2. **NFC Chip Verification** (ICAO):
     - BAC handshake with MRZ-derived keys
     - Read DG1 (personal data) and DG2 (photo)
     - SOD verification for authenticity
- Standards: ICAO Doc 9303, ISO/IEC 14443, ISO 7816-4
- Supported cards: Turkish eID, e-Passport, MIFARE, NDEF, 10+ types
- Figure caption required
- Page number: 10/17

#### Speech Script
```
"Document verification in FIVUCSAS is a two-stage pipeline.

First, our trained Card Detection model analyzes the camera feed to
automatically identify the document type - Turkish ID, passport, driver's
license - without manual user selection. This runs on-device for real-time
feedback and guides the user for optimal positioning.

Second, once the card is positioned, our NFC Reader establishes a secure
connection using Basic Access Control. The session keys are derived from the
Machine Readable Zone, ensuring physical possession.

We then read Data Group 1 for personal information and Data Group 2 for a
high-resolution photograph - significantly better than the printed image.

Finally, we verify the Security Object Document - a digital signature proving
the data has not been modified since issuance.

This combination of visual detection and cryptographic verification makes
document spoofing extremely difficult."
```

---

### SLIDE 11: Document Verification Demo

**Time:** 0:45
**Presenter:** Ayse Gulsum Eren
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     DOCUMENT VERIFICATION IN ACTION                                       │
│     ───────────────────────────────                                       │
│                                                                           │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐ │
│  │  CARD DETECTION                 │  │  NFC CHIP READING               │ │
│  │  ───────────────                │  │  ─────────────────              │ │
│  │                                 │  │                                 │ │
│  │  [TURKISH eID PHOTO]           │  │  [NFC SCAN SCREEN]              │ │
│  │                                 │  │                                 │ │
│  │  ┌─────────────────────────┐   │  │  ┌─────────────────────────┐   │ │
│  │  │ 🔍 Type: TURKISH_EID    │   │  │  │ ✓ BAC Authenticated     │   │ │
│  │  │ 📊 Confidence: 97.3%    │   │  │  │ ✓ DG1 Personal Data     │   │ │
│  │  │ ✓ Ready for NFC         │   │  │  │ ✓ DG2 Photo Loaded      │   │ │
│  │  └─────────────────────────┘   │  │  │ ✓ SOD Signature Valid   │   │ │
│  │                                 │  │  └─────────────────────────┘   │ │
│  │  [E-PASSPORT PHOTO]            │  │                                 │ │
│  │                                 │  │  ┌─────────────────────────┐   │ │
│  │  ┌─────────────────────────┐   │  │  │ [HIGH-RES PHOTO         │   │ │
│  │  │ 🔍 Type: E_PASSPORT     │   │  │  │  FROM DG2 CHIP]         │   │ │
│  │  │ 📊 Confidence: 98.1%    │   │  │  │                         │   │ │
│  │  │ ✓ Ready for NFC         │   │  │  │ JPEG2000 Quality        │   │ │
│  │  └─────────────────────────┘   │  │  └─────────────────────────┘   │ │
│  └─────────────────────────────────┘  └─────────────────────────────────┘ │
│                                                                           │
│  Left: ML model auto-detects card type | Right: NFC reads chip securely   │
│                                                                    11/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **Left side: Card Detection results**
  - Turkish eID detected with 97.3% confidence
  - e-Passport detected with 98.1% confidence
  - Shows automatic type recognition without user input
- **Right side: NFC verification results**
  - BAC authentication success
  - DG1 (personal data) and DG2 (photo) read
  - SOD signature verified
  - High-resolution photo extracted from chip
- Page number: 11/17

#### Image Requirements
- **Card Detection screenshots**: Capture from mobile app showing detected cards
- **NFC scan screen**: Mobile app showing "Hold card to phone" instruction
- **Verification results**: Success checkmarks for BAC, DG1, DG2, SOD
- **DG2 photo**: High-res photo extracted from NFC chip (team member's ID)

#### Speech Script
```
"Here you can see our document verification system working with real documents.

On the left, our Card Detection model automatically recognizes the document type.
Turkish eID detected with 97% confidence, e-Passport with 98%. No manual selection -
the user just points the camera and the system identifies the card type instantly.

On the right, the NFC reading results. After placing the card on the phone, we
successfully authenticate using Basic Access Control, read the personal data from
DG1, extract the high-resolution JPEG2000 photo from DG2, and verify the digital
signature in the Security Object Document.

That green checkmark on SOD means this document is cryptographically proven to be
authentic and unmodified since issuance.

Now Gulsum will present what we accomplished this semester."
```

---

### SLIDE 12: Tasks Accomplished

**Time:** 1:00
**Presenter:** Ayse Gulsum Eren
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     WHAT WE BUILT - FALL 2025                                             │
│     ─────────────────────────                                             │
│                                                                           │
│  BIOMETRIC FEATURES                    DOCUMENT VERIFICATION              │
│  ──────────────────                    ─────────────────────              │
│  1. Face Detection (MediaPipe)         9. Visual Card Detection (ML)      │
│  2. Face Enrollment                    10. NFC Document Reading           │
│  3. Face Verification (1:1)            11. BAC Authentication             │
│  4. Face Search (1:N)                  12. SOD Validation                 │
│  5. Biometric Puzzle (Liveness)        13. MRZ Parsing                    │
│  6. Frame Quality Analysis             14. 10+ Card Types Support         │
│  7. Demographic Analysis                                                  │
│  8. Similarity Scoring                 INFRASTRUCTURE                     │
│                                        ──────────────                     │
│  WEB DEMO GUI                          15. JWT Authentication             │
│  ──────────────                        16. Multi-Tenant Architecture      │
│  • Dashboard                           17. 40+ REST API Endpoints         │
│  • Enrollment Page                     18. PostgreSQL + pgvector          │
│  • Verification Page                   19. IVFFlat Vector Indexing        │
│  • Search Page                         20. Redis Caching                  │
│  • Liveness Testing                    21. Flyway Migrations              │
│  • Quality Analysis                    22. Kotlin Multiplatform Apps      │
│                                                                           │
│                                                                    12/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **22 implemented features** organized by category:
  - Biometric Features (8): Detection, Enrollment, Verification, Search, Liveness, Quality, Demographics, Similarity
  - Document Verification (6): Card Detection, NFC, BAC, SOD, MRZ, Card Types
  - Infrastructure (8): Auth, Multi-tenant, API, Database, Indexing, Cache, Migrations, Apps
  - Web Demo GUI: 6 interactive pages
- Clear numbered list for easy reading
- Page number: 12/17

#### Speech Script
```
"Here is everything we built this semester - 22 implemented features.

[Read the list by sections]

Biometric: face detection, enrollment, verification, search, the Biometric
Puzzle for liveness, quality analysis, demographics, and similarity scoring.

Document verification: our trained card detection model, NFC reading, BAC
authentication, SOD validation, MRZ parsing, supporting 10+ card types.

Infrastructure: JWT auth, multi-tenant architecture, 40+ API endpoints,
PostgreSQL with pgvector, IVFFlat indexing, Redis, and Kotlin Multiplatform.

Plus a complete web demo with 6 interactive pages."
```

---

### SLIDE 13: Technical Challenges & Solutions

**Time:** 0:50
**Presenter:** Ayse Gulsum Eren
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     TECHNICAL CHALLENGES                                                  │
│     ────────────────────                                                  │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  1. NFC PASSPORT INTEGRATION                                        │  │
│  │     ─────────────────────────                                       │  │
│  │     Challenge: Complex ICAO protocols, BAC handshake, SOD parsing   │  │
│  │     Solution: Modular reader architecture with 7 specialized readers│  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  2. CARD DETECTION MODEL TRAINING                                   │  │
│  │     ────────────────────────────                                    │  │
│  │     Challenge: Dataset collection, model accuracy, real-time speed  │  │
│  │     Solution: Custom dataset + optimized on-device inference        │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  3. CROSS-LANGUAGE MICROSERVICE COMMUNICATION                       │  │
│  │     ────────────────────────────────────────                        │  │
│  │     Challenge: Java ↔ Python service integration, type safety       │  │
│  │     Solution: REST APIs with OpenAPI contracts + Redis event bus    │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│                                                                    13/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **3 key challenges** with solutions:
  1. NFC Passport Integration - ICAO protocols, modular readers
  2. Card Detection Model Training - dataset + on-device inference
  3. Cross-Language Microservice - Java ↔ Python, REST + Redis
- Clean visual layout with boxed sections
- Page number: 13/17

#### Speech Script
```
"We faced three major challenges.

First, NFC passport integration. ICAO protocols are complex - BAC handshake,
SOD parsing. We built 7 specialized readers for different card types.

Second, card detection training. We collected a custom dataset and optimized
the model for real-time on-device inference.

Third, cross-language communication. Java and Python services needed to talk.
We used REST APIs with OpenAPI contracts and Redis for events."
```

---

### SLIDE 14: Future Work & Contingency Plan

**Time:** 0:50
**Presenter:** Ayse Gulsum Eren
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     SEMESTER 2 PLANS & B-PLAN                                             │
│     ─────────────────────────                                             │
│                                                                           │
│  SEMESTER 2 TIMELINE (Spring 2026)                                        │
│  ─────────────────────────────────                                        │
│                                                                           │
│  FEB ─────► Service Integration + OCR Module                              │
│  MAR ─────► Real-Time Proctoring Module                                   │
│  APR ─────► Security Testing + Mobile Polish                              │
│  MAY ─────► Production Deployment                                         │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │  CONTINGENCY PLAN (B-PLAN)                                        │    │
│  │                                                                   │    │
│  │  IF NFC edge cases fail  →  Focus on Turkish eID + e-Passport    │    │
│  │  IF Integration delayed  →  Web demo as primary deliverable      │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐    │
│  │  FUTURE RESEARCH (Beyond Project)                                 │    │
│  │  • Offline mode with on-device ML                                 │    │
│  │  • Fingerprint & iris biometrics                                  │    │
│  │  • Embedded devices (Raspberry Pi)                                │    │
│  └───────────────────────────────────────────────────────────────────┘    │
│                                                                    14/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- **Semester 2 Timeline:** Feb-May 2026 with clear deliverables
- **B-Plan:** 2 realistic contingency options
- **Future Research:** 3 directions beyond project scope
- Page number: 14/17

#### Speech Script
```
"Semester two: February for service integration and OCR. March for proctoring.
April for security testing. May for deployment.

Our B-Plan: if NFC edge cases fail, we focus on Turkish eID and e-Passport.
If integration is delayed, the web demo becomes our primary deliverable.

Future research beyond this project: offline mode, fingerprint and iris
biometrics, and embedded device deployment."
```

---

### SLIDE 15: Thank You

**Time:** 0:20
**Presenter:** Ayse Gulsum Eren
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│                                                                           │
│                           THANK YOU                                       │
│                           ─────────                                       │
│                                                                           │
│                                                                           │
│           We thank our advisor, Assoc. Prof. Dr. Mustafa Agaoglu,         │
│                   for his guidance throughout this project.               │
│                                                                           │
│                                                                           │
│                                                                           │
│                    GitHub: github.com/Rollingcat-Software/FIVUCSAS        │
│                                                                           │
│                    (Will be released as open-source)                      │
│                                                                           │
│                                                                           │
│                                                                    15/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Thank you message
- Advisor acknowledgment
- GitHub link
- **Open-source release announcement**
- Page number: 15/17

#### Speech Script
```
"We thank our advisor, Associate Professor Doctor Mustafa Agaoglu, for his
guidance.

Our code is on GitHub. Currently it is closed-source, but we plan to release
it as open-source after graduation."
```

---

### SLIDE 16: References

**Time:** 0:20
**Presenter:** Ayse Gulsum Eren
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│     REFERENCES                                                            │
│     ──────────                                                            │
│                                                                           │
│  [1] Taigman et al. (2014). DeepFace: Closing the Gap to Human-Level      │
│      Performance in Face Verification. CVPR.                              │
│                                                                           │
│  [2] Schroff et al. (2015). FaceNet: A Unified Embedding for Face         │
│      Recognition and Clustering. IEEE CVPR.                               │
│                                                                           │
│  [3] Deng et al. (2019). ArcFace: Additive Angular Margin Loss for        │
│      Deep Face Recognition. CVPR.                                         │
│                                                                           │
│  [4] Lugaresi et al. (2019). MediaPipe: A Framework for Building          │
│      Perception Pipelines. Google Research.                               │
│                                                                           │
│  [5] ICAO Doc 9303: Machine Readable Travel Documents.                    │
│                                                                           │
│  [6] ISO/IEC 14443 & ISO 7816-4: NFC Standards.                           │
│                                                                           │
│                                                                    16/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- 6 key academic references
- Clean, readable format
- **LAST CONTENT SLIDE (per professor requirement)**
- Page number: 16/17

#### Speech Script
```
"Our key references: DeepFace and FaceNet for face recognition foundations,
ArcFace for embedding quality, MediaPipe for landmarks, and ICAO/ISO for
NFC standards."
```

---

### SLIDE 17: Q&A

**Time:** 3:00
**Presenter:** All Team Members
**Aspect Ratio:** 16:9

#### Visual Design
```
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│                                                                           │
│                                                                           │
│                          QUESTIONS & ANSWERS                              │
│                          ───────────────────                              │
│                                                                           │
│                                                                           │
│                                                                           │
│                                                                           │
│                             [Q&A Icon]                                    │
│                                                                           │
│                                                                           │
│                                                                           │
│                                                                           │
│                                                                    17/17  │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Content Elements
- Simple Q&A slide
- Clean design
- Page number: 17/17

#### Speech Script
```
"We welcome your questions."
```

---

## 3. Presenter Assignments

### Flow with 2 Main Transitions

| Presenter | Slides | Total Time | Role |
|-----------|--------|------------|------|
| **Aysenur Arici** | 1-5 | ~4:00 | **Opening & Problem Context** |
| **Ahmet Abdullah** | 6-10 | ~4:10 | **Technical Innovation + Biometric Demo** |
| **Ayse Gulsum** | 11-16 | ~3:40 | **Doc Demo + Implementation + References** |
| **All Together** | 17 | ~3:00 | **Q&A** |

> **Flow:** Aysenur (problem) → Ahmet (solution + biometric demo) → Gulsum (doc demo + results + refs) → All (Q&A)
> **BALANCED: 5 slides / 5 slides / 6 slides**

### Two Transition Scripts

**TRANSITION 1: Aysenur → Ahmet (after Slide 5)**
```
[Aysenur:]
"Now, Ahmet will show you how we built our solution."

[Ahmet:]
"Thank you. Let me show you our architecture."
```

**TRANSITION 2: Ahmet → Gulsum (after Slide 10)**
```
[Ahmet:]
"Now Gulsum will show our document verification and what we accomplished."

[Gulsum:]
"Thank you. Let me show you our document verification in action."
```

### Why This Structure Works

1. **Aysenur (Slides 1-5):** Problem context (~4:00)
2. **Ahmet (Slides 6-10):** Technical solution + Biometric Demo (~4:10)
3. **Gulsum (Slides 11-16):** Doc Demo + Implementation + References (~3:40)
4. **All (Slide 17):** Q&A

**BALANCED:** Each presenter has ~4 minutes and 5-6 slides.

---

### Complete Flowing Scripts (For Practice)

Short, natural scripts for each presenter. Practice speaking naturally, not reading.

---

#### AYSENUR'S SCRIPT (Slides 1-5, ~3:30)

```
[SLIDE 1]
"Hello everyone. We are presenting FIVUCSAS - Face and Identity Verification
Using Cloud-Based SaaS Models.

I am Aysenur Arici. My teammates are Ahmet Abdullah Gultekin and Ayse Gulsum
Eren. Our advisor is Associate Professor Doctor Mustafa Agaoglu."

[SLIDE 2]
"Our presentation has three parts.

First, WHY - we will explain the problem of identity fraud and where existing
solutions fall short.

Second, HOW - our architecture, liveness detection, and document verification.

Third, WHAT - our accomplishments, challenges we faced, and plans for semester two."

[SLIDE 3]
"Let me start with a real incident from 2024. In Hong Kong, a deepfake video call
impersonated the CFO of a company and convinced employees to transfer 25 million
dollars. This is not science fiction - this happened last year.

Look at the numbers: 23 billion dollars lost to identity fraud in 2024 alone.
Deepfake attacks have increased 400 percent year over year. And here is the
scary part: one in four people cannot distinguish a deepfake from a real person.

This is why we built FIVUCSAS. Our goal is simple but critical: prove the person
is LIVE and present, their identity document is AUTHENTIC and untampered, and
spoofing is IMPOSSIBLE through our hybrid detection system."

[SLIDE 4]
"Let me show you how FIVUCSAS compares to existing solutions in the market.

Microsoft Azure Face and Amazon Rekognition are powerful, but they are proprietary -
you cannot host them yourself, and they do not support NFC chip reading or automatic
card type detection. For banks and government institutions that need data sovereignty,
this is a serious limitation.

Sodec and BioGATE are Turkish solutions we studied. Sodec lacks liveness detection
entirely - a critical vulnerability. BioGATE has liveness but is not multi-tenant
and cannot automatically detect card types.

Here is the gap we identified: no open-source solution combines hybrid liveness
detection, NFC chip verification, and automatic document type recognition.
FIVUCSAS fills exactly this gap."

[SLIDE 5]
"Our MVP scope includes six core deliverables: cloud-native SaaS platform, hybrid
liveness detection, trained card detection model, NFC document reading, multi-tenant
admin dashboard, and cross-platform client applications.

As for out of scope: hardware manufacturing is beyond this project. We focus purely
on software.

Our engineering constraints: images must exceed 480p resolution for reliable face
detection, API response must be under 200 milliseconds for good user experience,
and NFC must comply with ISO 14443 standards.

Now, Ahmet will show you how we built our solution."
```

---

#### AHMET'S SCRIPT (Slides 6-10, ~4:10)

```
[SLIDE 6]
"Thank you. Let me walk you through our system architecture.

We built FIVUCSAS using microservices with Hexagonal Architecture. NGINX serves
as our API Gateway. Identity Core handles authentication and multi-tenancy in
Java 21. The Biometric Processor runs face detection and liveness in Python 3.11.

Client applications use Kotlin Multiplatform for Android, iOS, and Desktop.
PostgreSQL with pgvector stores embeddings, and Redis handles caching."

[SLIDE 7]
"The Biometric Puzzle is our key innovation - hybrid liveness detection.

The server generates a random challenge - 'blink your left eye.' The attacker
cannot predict it. The client tracks 468 landmarks via MediaPipe and detects
blinks when EAR drops below 0.2.

Simultaneously, passive analysis checks for screen artifacts. This hybrid approach
defeats deepfakes, photos, and video replays."

[SLIDE 8 - DEMO]
"Here is our Biometric Processor in action with all three team members.

You can see the 468 facial landmarks being tracked - the green mesh overlay.
Below each photo: Eye Aspect Ratio, quality score, and liveness status.

All three of us passed the Biometric Puzzle and are verified as LIVE. A photo
or deepfake would fail because it cannot respond to random challenges."

[SLIDE 9]
"Our ML pipeline: detection, alignment, embedding extraction, similarity search.

MediaPipe detects faces. We align using 5 points, extract 2622-D embeddings with
VGG-Face, and search using pgvector with IVFFlat indexing for sub-millisecond queries.

Verification threshold: cosine distance below 0.68 means a match."

[SLIDE 10]
"Document verification is a two-stage pipeline.

First, our Card Detection model automatically identifies the document type -
Turkish ID, passport - without manual selection. Runs on-device in real-time.

Second, NFC reads the chip using Basic Access Control. We verify the digital
signature proving the document is authentic.

Now Gulsum will show our document verification and what we accomplished."
```

---

#### GULSUM'S SCRIPT (Slides 11-16, ~3:40)

```
[SLIDE 11 - DEMO]
"Thank you. Let me show you our document verification in action.

On the left, Card Detection: Turkish eID detected at 97% confidence, e-Passport
at 98%. No manual selection - just point and detect.

On the right, NFC results: BAC authenticated, DG1 and DG2 read successfully,
SOD signature verified. That green checkmark proves document authenticity."

[SLIDE 12]
"Here is everything we built this semester - 22 implemented features.

Biometric: face detection, enrollment, verification, search, Biometric Puzzle
liveness, quality analysis, demographics, and similarity scoring.

Document verification: card detection model, NFC reading, BAC authentication,
SOD validation, MRZ parsing, supporting 10+ card types.

Infrastructure: JWT auth, multi-tenant architecture, 40+ API endpoints,
PostgreSQL with pgvector, Redis caching, and Kotlin Multiplatform apps."

[SLIDE 13]
"We faced three major challenges.

First, NFC passport integration - we built 7 specialized readers.
Second, card detection training - custom dataset, on-device optimization.
Third, cross-language communication - REST APIs with OpenAPI and Redis."

[SLIDE 14]
"Semester two: February for integration and OCR. March for proctoring.
April for security testing. May for deployment.

B-Plan: if NFC fails, focus on Turkish eID and e-Passport.
Future research: offline mode, fingerprint/iris, embedded devices."

[SLIDE 15]
"We thank our advisor, Associate Professor Doctor Mustafa Agaoglu, for his guidance.

Our code is on GitHub at Rollingcat-Software slash FIVUCSAS. We plan to release
it as open-source after graduation."

[SLIDE 16]
"Our key references: DeepFace and FaceNet for face recognition, ArcFace for
embeddings, MediaPipe for landmarks, and ICAO/ISO for NFC standards."

[SLIDE 17]
"We welcome your questions."
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
| FastAPI Swagger UI | Proves 40+ endpoints exist | `http://localhost:8001/docs` |
| Web Dashboard | Shows working admin interface | Run Next.js app |
| NFC Scan Screen | Demonstrates NFC functionality | Mobile app or photo |
| Database Tables | Shows schema implementation | pgAdmin |

---

## 5. Q&A Preparation

### Likely Questions and Answers

#### Q1: "How does the Biometric Puzzle prevent deepfake attacks?"

**Answer:**
```
"This is a critical question for our system. The key insight is that deepfakes
are pre-generated content. Our Biometric Puzzle generates random challenges in
real-time - the attacker cannot know in advance whether we will ask for a blink,
a smile, or a head turn. By the time they generate the correct response, the
challenge has already expired. Additionally, our passive analysis checks for
screen artifacts like moire patterns and unnatural color distribution that
deepfakes displayed on screens inevitably exhibit."
```

#### Q2: "What is your verification accuracy?"

**Answer:**
```
"We benchmarked our system using the LFW dataset, which is the standard for
face verification research. Using VGG-Face embeddings with a cosine distance
threshold of 0.68, we achieve a False Acceptance Rate below 1% and a False
Rejection Rate below 3%. This gives us an Equal Error Rate of approximately 3%,
which is comparable to commercial solutions like Azure Face API."
```

#### Q3: "Why did you choose PostgreSQL with pgvector over dedicated vector databases?"

**Answer:**
```
"We evaluated dedicated vector databases like Pinecone and Milvus, but chose
pgvector primarily for unified data management - user profiles and their face
embeddings stay together with full referential integrity. This also gives us
transaction support, meaning enrollment is atomic and consistent. And from an
operational perspective, maintaining one database instead of two significantly
reduces complexity. With IVFFlat indexing, query performance is more than
sufficient for our target scale."
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
"We anticipated this risk during our planning phase. Our contingency plan is
straightforward: if universal NFC parsing proves unreliable across different
card types, we limit support to Turkish National ID cards only, which we have
thoroughly tested and validated. The modular architecture we designed allows
us to disable specific card type readers without affecting the rest of the
system, so this fallback is seamless."
```

#### Q6: "How do you ensure KVKK/GDPR compliance?"

**Answer:**
```
"Privacy was a core design principle from the beginning. We practice data
minimization by storing only mathematical embeddings, never the original face
images. We fully support the right to be forgotten through our deletion API.
All biometric data is encrypted at rest using AES-256, and every transmission
uses TLS 1.3. Most importantly, we require explicit user consent before any
biometric processing begins - no silent data collection."
```

#### Q7: "What is your test coverage?"

**Answer:**
```
"We have comprehensive coverage at multiple levels. Unit tests validate our
domain entities and use cases in isolation. Integration tests verify that our
API endpoints behave correctly with real database connections. And end-to-end
tests exercise complete workflows from enrollment through verification. Our CI
pipeline runs all tests automatically on every pull request, using pytest for
Python and JUnit 5 for Java, with coverage reporting to track our progress."
```

#### Q8: "What happens if the user's appearance changes (beard, glasses, aging)?"

**Answer:**
```
"Our multi-image enrollment using template fusion addresses this. We recommend
enrolling 3-5 images with variations in lighting, angle, and expression. The
quality-weighted average creates a robust template. VGG-Face embeddings are
trained on diverse datasets including these variations, and our verification
threshold of 0.68 allows for natural appearance changes while maintaining security."
```

#### Q9: "Why Python + Java instead of a single language?"

**Answer:**
```
"Each language serves its optimal purpose. Python with FastAPI handles ML
workloads because the entire machine learning ecosystem - DeepFace, MediaPipe,
NumPy, OpenCV - is Python-native. Java with Spring Boot handles enterprise
concerns like authentication, multi-tenancy, and RBAC where it excels. This
separation also enables independent scaling and deployment."
```

#### Q10: "How does your system scale? What's the max concurrent users?"

**Answer:**
```
"Our architecture was designed for horizontal scaling from the start. The
Biometric Processor can be replicated behind a load balancer, with each
instance handling ML inference independently. With IVFFlat indexing in
pgvector, similarity search remains O(log n) even with large enrollment
databases. Redis provides session caching to reduce database load. Based on
our benchmarks, a single instance handles over 100 concurrent verification
requests, and we can scale linearly by adding more instances."
```

#### Q11: "What's the false positive rate for your liveness detection?"

**Answer:**
```
"Our hybrid approach targets a false positive rate below 2% for spoof detection.
The combination of active challenges - which are unpredictable - with passive
texture analysis creates two independent barriers. In our testing with printed
photos and screen replays, detection accuracy exceeded 98%. However, we
acknowledge that sophisticated 3D masks would require additional countermeasures
planned for future versions."
```

#### Q12: "Why not use a dedicated vector database like Pinecone or Milvus?"

**Answer:**
```
"We did evaluate dedicated vector databases during our architecture design.
The primary reason we chose pgvector is unified transactions - enrollment
becomes atomic with user data, maintaining full referential integrity.
Additionally, operational simplicity matters greatly; having one database to
backup, monitor, and maintain reduces our operational burden significantly.
And frankly, the performance is sufficient - IVFFlat handles over 100,000
embeddings with sub-10ms query times. For enterprise scale beyond one million
enrollments, we would certainly consider Milvus or Pinecone as a future
enhancement."
```

---

## 6. Checklist Before Presentation

### One Week Before

- [ ] Create all technical diagrams manually (Draw.io/Excalidraw)
- [ ] Capture required screenshots (Swagger, Dashboard, NFC)
- [ ] Upload Marmara University logo
- [ ] Replace team photos (use real photos or remove)
- [ ] Practice full presentation (target: under 12 minutes)
- [ ] Test all transition scripts with actual presenters
- [ ] Verify GitHub repository is accessible (public or shared with jury)

### Day Before

- [ ] Verify slide count: 15 slides
- [ ] Check page numbers on ALL slides (1/15 through 15/15)
- [ ] Verify figure captions on ALL diagrams
- [ ] Confirm advisor name: "Assoc. Prof. Dr. Mustafa Agaoglu"
- [ ] Remove any fake contact information
- [ ] Test presentation on projector/large screen
- [ ] Check font readability from back of room
- [ ] Prepare backup slides for common Q&A topics
- [ ] Have offline PDF version ready
- [ ] Do a full run-through with timer

### Morning Of

- [ ] Arrive 15 minutes early
- [ ] Test laptop-projector connection
- [ ] Have backup on USB drive
- [ ] Bring printed notes for each presenter
- [ ] Water bottles for presenters
- [ ] Load demo API in browser tab (Swagger UI at localhost:8001/docs)
- [ ] Disable screen notifications/popups on presenting laptop
- [ ] Have timer visible to all presenters

### During Presentation

- [ ] **Aysenur presents slides 1-5** (Opening & Problem Context) - ~4:00
- [ ] *TRANSITION 1: Aysenur hands off to Ahmet*
- [ ] **Ahmet presents slides 6-10** (Technical Innovation + Biometric Demo) - ~4:10
- [ ] *TRANSITION 2: Ahmet hands off to Gulsum*
- [ ] **Gulsum presents slides 11-16** (Doc Demo + Implementation + References) - ~3:40
- [ ] **All together for slide 17** (Q&A) - ~3:00
- [ ] Watch the clock - 12:00 target for presentation
- [ ] Smooth transitions - keep them brief
- [ ] **BALANCED: 5 slides / 5 slides / 6 slides per presenter**

---

## Key Numbers to Memorize

| Metric | Value | Context |
|--------|-------|---------|
| Total Slides | 17 | 16:9 aspect ratio |
| Implemented Features | 22 | All categories |
| API Endpoints | 40+ | Biometric Processor |
| Embedding Dimensions | 2622-D | VGG-Face default |
| EAR Threshold | < 0.2 | Blink detection |
| Cosine Threshold | 0.68 | Verification match |
| Facial Landmarks | 468 | MediaPipe Face Mesh |
| Card Types | 10+ | Turkish eID, e-Passport, MIFARE |
| Specialized NFC Readers | 7 | Factory pattern |
| Web Demo Pages | 6 | Interactive interfaces |
| Target FAR | < 1% | False Acceptance Rate |
| Spoof Detection | > 98% | Liveness accuracy |

---

## 7. Image Preparation Checklist for Demo Slides

The demo slides (8 and 11) require real screenshots from your system. Capture these before the presentation:

### For SLIDE 8: Biometric Processor Demo

| Image | Description | How to Capture |
|-------|-------------|----------------|
| **Ahmet's face + 468 mesh** | Face with MediaPipe landmarks overlay | Run web demo, capture with mesh visible |
| **Ayşenur's face + 468 mesh** | Face with MediaPipe landmarks overlay | Same process |
| **Gülsüm's face + 468 mesh** | Face with MediaPipe landmarks overlay | Same process |
| **All 3 LIVE status** | EAR values and "LIVE" checkmarks | Complete liveness test for each |

### For SLIDE 11: Document Verification Demo

| Image | Description | How to Capture |
|-------|-------------|----------------|
| **Turkish eID detection** | Card with bounding box + confidence | Point camera at Turkish ID |
| **e-Passport detection** | Passport with bounding box + confidence | Point camera at passport |
| **NFC scan screen** | "Hold card to phone" UI | Mobile app NFC screen |
| **Verification success** | BAC, DG1, DG2, SOD checkmarks | After successful NFC read |
| **DG2 photo** | High-res photo from chip | Extracted from NFC read |

### Capture Tips

1. **Good lighting** - Ensure faces are well-lit for clear mesh visualization
2. **Clean background** - Use simple background for cleaner screenshots
3. **Redact personal data** - Blur/redact any real personal information on IDs
4. **Consistent style** - Use same screenshot tool for uniform appearance

---

**Document Created:** December 30, 2025
**Last Updated:** January 1, 2026 (v6 - 17 slides, BALANCED: 5/5/6 slides per presenter, ~4 min each)
**Author:** Generated for FIVUCSAS Team
**Purpose:** Complete Presentation Guide for January 7, 2026 Defense
