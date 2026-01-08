# FIVUCSAS Presentation Speeches

**Date:** January 7, 2026
**Duration:** 12 minutes + 3 minutes Q&A
**Total Slides:** 18

---

## Presenter Distribution

| Presenter | Slides | Time | Content |
|-----------|--------|------|---------|
| **Aysenur Arici** | 1-6 | ~4:00 | Title, Outline, Problem, Related Work, Related Works Table, Scope |
| **Ahmet Abdullah Gultekin** | 7-13 | ~4:00 | Architecture, Biometric Puzzle, NFC, ML Pipeline, Demos |
| **Ayse Gulsum Eren** | 14-18 | ~4:00 | Tasks, Semester Plan, Challenges, References, Q&A |

---

# AYSENUR ARICI (Slides 1-6) — ~4 minutes

---

## SLIDE 1: Title Slide (25 sec)

```
Good morning everyone. We are presenting FIVUCSAS — Face and Identity
Verification Using Cloud-Based SaaS Models.

I am Aysenur Arici. With me are my teammates Ahmet Abdullah Gultekin and
Ayse Gulsum Eren. Our project supervisor is Associate Professor Doctor
Mustafa Agaoglu.
```

---

## SLIDE 2: Outline — WHY / HOW / WHAT (25 sec)

```
Our presentation follows three parts.

WHY — the problem, related work, and project scope.

HOW — system architecture, Biometric Puzzle, card and NFC verification,
machine learning pipeline, and live demos.

WHAT — tasks completed, semester two plan, challenges, and references.
```

---

## SLIDE 3: The Threat is Real (50 sec)

```
Identity fraud is exploding.

23 billion dollars lost to identity fraud in 2024. 400 percent increase
in deepfake attacks year over year. And 1 in 4 people cannot detect a
deepfake from a real person.

Deepfakes are the new weapon for fraudsters.

Our goal with FIVUCSAS is un-spoofable verification — proving the person
is live, present, and holding an authentic document.
```

---

## SLIDE 4: Related Work — Categories (40 sec)

```
We studied three areas of related work.

First, Deep Face Recognition — DeepFace, FaceNet, and ArcFace provide
embedding-based verification with high accuracy.

Second, Liveness Detection — existing solutions offer passive and active
methods for anti-spoofing, but they remain isolated.

Third, the Integration Gap — no solution offers multi-tenant support,
cloud-native deployment, and end-to-end verification in one system.

This gap leads us to FIVUCSAS.
```

---

## SLIDE 5: Related Works — Comparison Table (50 sec)

```
This table compares Azure Face Liveness, AWS Rekognition, Sodec
Technologies, FaceAuth Vision, BioGATE Pass, and FIVUCSAS.

For Open Source — only FaceAuth and FIVUCSAS provide it.

For Liveness Detection — Sodec and FaceAuth lack it entirely.

For Multi-Tenant SaaS — Sodec, FaceAuth, and BioGATE do not support it.

For PAD Compliance — Sodec and FaceAuth are missing.

The gap: Most solutions lack physical document verification through NFC
and rely on singular, predictable liveness checks.

Our advantage: We bridge the physical-digital gap with our unpredictable
Biometric Puzzle.
```

---

## SLIDE 6: Scope (40 sec)

```
Our project scope has three parts.

In scope — six core deliverables: face recognition, cloud database, NFC
reading, server infrastructure, mobile applications, and software platform.

Out of scope — hardware manufacturing. We focus purely on software.

Engineering constraints: Image quality over 100 kilobytes, API latency
under 200 milliseconds, and NFC following ICAO Document 9303 standards.

Now, Ahmet will explain how we built the solution.
```

---

# AHMET ABDULLAH GULTEKIN (Slides 7-13) — ~4 minutes

---

## SLIDE 7: System Architecture (45 sec)

```
Thank you Aysenur.

Client applications use Kotlin Multiplatform for Android, iOS, and Desktop.

Requests flow through NGINX as our API Gateway for load balancing and
rate limiting.

Identity Core — a Spring Boot application with 130 Java files handling
authentication, multi-tenancy, and role-based access control.

Biometric Processor — a FastAPI service with 254 Python files handling
face detection, liveness analysis, and embedding extraction.

PostgreSQL with pgvector provides vector similarity search using IVFFlat
indexing with O log n performance. Redis handles caching and event bus.

Architecture follows Hexagonal pattern with Domain-Driven Design.
```

---

## SLIDE 8: The Biometric Puzzle (45 sec)

```
The Biometric Puzzle is our key innovation — hybrid liveness detection.

The challenge-response protocol works in four steps:

Step 1 — Server generates a random challenge like "Blink Left Eye" or
"Turn Head Right." Unpredictable.

Step 2 — Client captures video and tracks 468 facial landmarks using
MediaPipe.

Step 3 — We calculate Eye Aspect Ratio. When EAR drops below 0.2, a
blink is detected.

Step 4 — Parallel passive texture analysis detects screens or printed
photos.

We detect four actions: neutral, blink, smile, and head turn. This
defeats deepfakes and replay attacks.
```

---

## SLIDE 9: Card Detection & NFC Verification (35 sec)

```
Document verification has two stages.

On-Device Card Detection — our trained model recognizes over 10 card
types including Turkish eID and passports. Automatic identification.

NFC Chip Verification — we perform BAC handshake using MRZ-derived keys,
read DG1 for personal data and DG2 for high-resolution photo, then verify
the SOD digital signature proving authenticity.
```

---

## SLIDE 10: ML Pipeline & Vector Search (35 sec)

```
Our machine learning pipeline has five stages.

Input — raw user image exceeding 480p resolution.

Detect — identify face region with bounding box.

Align — normalize orientation using facial landmarks.

Extract — convert to high-dimensional embedding vector.

Search — compare against database using vector search. With pgvector
and IVFFlat indexing, we achieve sub-millisecond queries.
```

---

## SLIDE 11: Live Demo — Team Recognition (25 sec)

```
Here is our system recognizing all three team members simultaneously.

The system tracks 468 facial landmarks per face with real-time metrics:
quality scores ranging from 75 to 100 percent, age estimation, mood
detection, and liveness percentage.

Each person is matched to their enrolled profile with confidence scores
from 64 to 84 percent at 13.4 frames per second.
```

---

## SLIDE 12: Live Demo — Passport Verification (25 sec)

```
This demo shows passport-to-face verification.

The passport photo shows Quality 100% but Liveness N — correctly
identifying it as a document photo.

The live person shows Liveness Y at 61%. Both faces match the same
enrolled person with 80% confidence.

This verifies a live person matches their identity document.
```

---

## SLIDE 13: Live Demo — Biometric Puzzle & Card Detection (25 sec)

```
Multiple features working together.

Biometric Puzzle challenge "Smile Wide, Show Teeth" with 97% hold progress.

Card detection recognizing a passport at 93% confidence.

Another challenge "Turn Head Left" — challenge 3 of 3 with 92% hold
progress.

Now Gulsum will present what we accomplished this semester.
```

---

# AYSE GULSUM EREN (Slides 14-18) — ~4 minutes

---

## SLIDE 14: Tasks Completed (55 sec)

```
Thank you Ahmet. Here is everything we built this semester.

Biometrics — Face Detection, Liveness Check with our Biometric Puzzle,
Face Mesh tracking 468 landmarks, Quality Score assessment, and
Anti-Spoofing detection.

Document Verification — ID Card recognition, NFC Read, Passport support,
and OCR Scan.

Infrastructure — Security with JWT authentication, Servers, Database with
PostgreSQL and pgvector, REST API, Cloud deployment, and Monitoring.

Summary: Full-stack system developed. Robust SaaS infrastructure built.
Core biometric pipeline complete. NFC reader module completed. Demo UI
completed.
```

---

## SLIDE 15: Second Semester Plan (45 sec)

```
For Spring 2026:

February to March — Complete Application Development.

March to April — Finalize Service-to-Service Integration.

April to May — Conduct End-to-End Security Testing and Penetration Testing.

May — Prepare for Production Deployment and Documentation.

Contingency Plans:

NFC Failure — scope narrows to Turkish eID only initially.

High WebSocket Latency — fallback to REST polling.

Mobile App Delayed — prioritize Desktop-first deployment.
```

---

## SLIDE 16: Technical Challenges (45 sec)

```
We faced two major technical challenges.

First — Training a performant on-device Card Detection Model. Our YOLO
model confused Marmara University student cards versus staff cards due
to minimal visual differences in color and layout. We collected more
training data and fine-tuned the model.

Second — Cross-Language Microservice Communication. Our Java Spring
service needed to communicate with Python FastAPI. We designed a robust
contract using REST APIs and implemented a shared Redis cache for state
management.
```

---

## SLIDE 17: References (20 sec)

```
Our key references:

DeepFace, FaceNet, and ArcFace for face recognition.
MediaPipe for facial landmark detection.
ISO standards for NFC implementation.
Azure Face Liveness and Amazon Rekognition for commercial benchmarking.
Sodec Technologies and BioGATE for Turkish market analysis.
```

---

## SLIDE 18: Thank You & Questions (10 sec + Q&A)

```
Thank you for your attention.

We welcome your questions.
```

---

# TRANSITIONS

**After Slide 6 (Aysenur → Ahmet):**
```
Aysenur: "Now, Ahmet will explain how we built the solution."
Ahmet: "Thank you Aysenur."
```

**After Slide 13 (Ahmet → Gulsum):**
```
Ahmet: "Now Gulsum will present what we accomplished this semester."
Gulsum: "Thank you Ahmet. Here is everything we built this semester."
```

---

# TIMING SUMMARY

| Presenter | Slides | Content | Target |
|-----------|--------|---------|--------|
| Aysenur | 1-6 | Title, Outline, Problem, Related Work x2, Scope | 4:00 |
| Ahmet | 7-13 | Architecture, Puzzle, NFC, ML, Demos x3 | 4:00 |
| Gulsum | 14-18 | Tasks, Plan, Challenges, Refs, Q&A | 4:00 |
| **TOTAL** | **18** | | **12:00** |

---

# KEY NUMBERS TO REMEMBER

| Metric | Value |
|--------|-------|
| Identity Fraud Losses | $23 Billion |
| Deepfake Attack Increase | +400% |
| Cannot Detect Deepfakes | 1 in 4 people |
| Facial Landmarks | 468 points |
| EAR Blink Threshold | < 0.2 |
| Java Files | 130 |
| Python Files | 254 |
| Supported Card Types | 10+ |
| Image Quality Requirement | > 100kb |
| Latency Requirement | < 200ms |

---

# Q&A PREPARATION

**Q: How does the Biometric Puzzle prevent deepfakes?**
```
Deepfakes are pre-generated. Our challenges are random and unpredictable —
the attacker cannot know if we will ask for a blink, smile, or head turn.
By the time they generate a response, the challenge expires. Plus, passive
texture analysis detects screen artifacts.
```

**Q: Why two programming languages (Java + Python)?**
```
Each language serves its optimal purpose. Python handles ML workloads
because MediaPipe, DeepFace, and OpenCV are Python-native. Java with
Spring Boot handles enterprise concerns — authentication, multi-tenancy,
RBAC. This enables independent scaling.
```

**Q: What is your verification accuracy?**
```
Using cosine similarity, we target False Acceptance Rate below 1% and
False Rejection Rate below 3%. Demo showed match confidences between
64% and 84% for enrolled users.
```

**Q: What happens if NFC reading fails?**
```
Our Plan B: If NFC proves unreliable across card types, we narrow scope
to Turkish eID only — which we have thoroughly tested.
```

**Q: What is PAD Compliance?**
```
PAD stands for Presentation Attack Detection — the ISO 30107 standard
for liveness detection. Our Biometric Puzzle provides PAD compliance
through unpredictable challenge-response testing.
```

---

**Document Updated:** January 3, 2026
**Based on:** FIVUCSAS-Pre.pdf — 18 slides
**Purpose:** January 7, 2026 Presentation Defense

