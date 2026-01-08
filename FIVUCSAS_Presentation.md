---
marp: true
theme: default
paginate: true
backgroundColor: #ffffff
color: #333333
style: |
  section {
    font-family: 'Segoe UI', sans-serif;
  }
  h1 {
    color: #1e3a5f;
    font-size: 2.2em;
  }
  h2 {
    color: #1e3a5f;
    font-size: 1.8em;
    border-bottom: 3px solid #f39c12;
    padding-bottom: 10px;
  }
  strong {
    color: #f39c12;
  }
  .accent {
    color: #f39c12;
  }
  .success {
    color: #27ae60;
  }
  .danger {
    color: #e74c3c;
  }
  table {
    font-size: 0.8em;
  }
  th {
    background-color: #1e3a5f;
    color: white;
  }
  code {
    background-color: #f5f5f5;
  }
---

<!-- _class: lead -->
<!-- _backgroundColor: #1e3a5f -->
<!-- _color: white -->

# FIVUCSAS

## Face and Identity Verification Using Cloud-Based SaaS Models

**CSE4197 Engineering Project - Fall 2025**

---

**Team:**
- Ahmet Abdullah Gultekin (150121025)
- Ayse Gulsum Eren (150120005)
- Aysenur Arici (150123825)

**Supervisor:** Assoc. Prof. Dr. Mustafa Agaoglu
**Marmara University - Computer Engineering**

<!-- 1/17 -->

---

## OUTLINE

### WHY THIS MATTERS
1. Problem Statement & Motivation
2. Related Work & Gap Analysis
3. Scope & Engineering Constraints

### HOW WE SOLVE IT
4. System Architecture
5. The Biometric Puzzle (Hybrid Liveness)
6. ML Pipeline & Vector Search
7. Card Detection & NFC Verification

### WHAT WE BUILT
8. Tasks Accomplished
9. Technical Challenges & Solutions
10. Future Work & Contingency Plan

<!-- 2/17 -->

---

## WHY THIS MATTERS

> **"2024: Deepfake CFO video call -> $25 Million stolen"**

<div style="display: flex; justify-content: space-around; margin-top: 40px;">

<div style="text-align: center; background: #f5f5f5; padding: 20px; border-radius: 10px; width: 25%;">
<h1 style="color: #1e3a5f; margin: 0;">$23B</h1>
<p>Identity Fraud Losses (2024)</p>
</div>

<div style="text-align: center; background: #f5f5f5; padding: 20px; border-radius: 10px; width: 25%;">
<h1 style="color: #1e3a5f; margin: 0;">+400%</h1>
<p>Deepfake Attacks (YoY)</p>
</div>

<div style="text-align: center; background: #f5f5f5; padding: 20px; border-radius: 10px; width: 25%;">
<h1 style="color: #1e3a5f; margin: 0;">1 in 4</h1>
<p>Cannot Detect Deepfakes</p>
</div>

</div>

<div style="background: #1e3a5f; color: white; padding: 15px; border-radius: 5px; margin-top: 30px; text-align: center;">
<strong>OUR GOAL:</strong> Prove LIVE + AUTHENTIC + IMPOSSIBLE to spoof
</div>

<!-- 3/17 -->

---

## RELATED WORK & GAP ANALYSIS

| Feature | Azure | AWS | Sodec | BioGATE | **FIVUCSAS** |
|---------|:-----:|:---:|:-----:|:-------:|:------------:|
| Open Source | X | X | X | X | **CHECK** |
| Liveness | CHECK | CHECK | X | CHECK | **CHECK** |
| Multi-Tenant | CHECK | CHECK | X | X | **CHECK** |
| Multi-Platform | CHECK | CHECK | CHECK | X | **CHECK** |
| NFC ICAO | X | X | X | CHECK | **CHECK** |
| Card Detection | X | X | X | X | **CHECK** |
| Hybrid Liveness | X | X | X | X | **CHECK** |

<div style="background: #e8f5e9; padding: 10px; border-radius: 5px; margin-top: 20px; text-align: center;">
<strong>GAP:</strong> No open-source solution with hybrid liveness + NFC + card detection
</div>

<!-- 4/17 -->

---

## SCOPE & ENGINEERING CONSTRAINTS

<div style="display: flex; gap: 40px;">

<div style="flex: 1;">

### IN SCOPE (MVP)
- CHECK Cloud-Native SaaS Platform
- CHECK Hybrid Liveness Detection
- CHECK Card Detection (ML Model)
- CHECK NFC Document Reading
- CHECK Multi-Tenant Admin Dashboard
- CHECK Cross-Platform Client Apps

</div>

<div style="flex: 1;">

### OUT OF SCOPE
- X Hardware Manufacturing

</div>

</div>

<div style="background: #f5f5f5; padding: 20px; border-radius: 10px; margin-top: 30px;">

### ENGINEERING CONSTRAINTS

| > 480p | < 200ms | ISO 14443 |
|:------:|:-------:|:---------:|
| Image Quality | API Latency | NFC Standard |

</div>

<!-- 5/17 -->

---

## SYSTEM ARCHITECTURE

<div style="text-align: center; background: #f39c12; padding: 15px; border-radius: 5px; color: white; margin-bottom: 20px;">
<strong>NGINX API GATEWAY</strong> - Rate Limiting | Routing | Load Balancing
</div>

<div style="display: flex; justify-content: space-around; gap: 20px;">

<div style="background: #f5f5f5; padding: 15px; border-radius: 5px; flex: 1;">
<h4 style="color: #1e3a5f;">IDENTITY CORE</h4>
<p style="color: #f39c12; font-size: 0.9em;">Spring Boot (Java 21)</p>
<ul style="font-size: 0.8em;">
<li>JWT Auth</li>
<li>Multi-Tenant</li>
<li>RBAC</li>
</ul>
</div>

<div style="background: #f5f5f5; padding: 15px; border-radius: 5px; flex: 1;">
<h4 style="color: #1e3a5f;">BIOMETRIC PROC.</h4>
<p style="color: #f39c12; font-size: 0.9em;">FastAPI (Python 3.11)</p>
<ul style="font-size: 0.8em;">
<li>Face Detection</li>
<li>40+ Endpoints</li>
<li>Liveness</li>
</ul>
</div>

<div style="background: #f5f5f5; padding: 15px; border-radius: 5px; flex: 1;">
<h4 style="color: #1e3a5f;">CLIENT APPS</h4>
<p style="color: #f39c12; font-size: 0.9em;">Kotlin Multiplatform</p>
<ul style="font-size: 0.8em;">
<li>Android/iOS/Desktop</li>
<li>Camera/NFC</li>
<li>Card Detect</li>
</ul>
</div>

</div>

<div style="background: #1e3a5f; padding: 15px; border-radius: 5px; color: white; margin-top: 20px; text-align: center;">
<strong>PostgreSQL 16 + pgvector</strong> | <strong>Redis</strong>
</div>

**Architecture: Hexagonal (Ports & Adapters) + DDD**

<!-- 6/17 -->

---

## THE BIOMETRIC PUZZLE - HYBRID LIVENESS

<div style="display: flex; gap: 30px;">

<div style="background: #1e3a5f; padding: 20px; border-radius: 10px; color: white; flex: 1;">
<h4>SERVER</h4>
<ol style="font-size: 0.85em;">
<li>Generate Challenge<br><em>"Blink Left Eye"</em></li>
<li>Calculate EAR<br><code>EAR = 0.18 < 0.2</code><br><span style="color: #27ae60;">CHECK Blink Detected</span></li>
<li>Passive Analysis<br>LBP Texture Check<br><span style="color: #27ae60;">CHECK Not a Screen</span></li>
</ol>
</div>

<div style="display: flex; flex-direction: column; justify-content: center;">
<p style="color: #f39c12; font-size: 1.2em;">Challenge >>>></p>
<p style="color: #f39c12; font-size: 1.2em;"><<<< Response</p>
</div>

<div style="background: #f5f5f5; padding: 20px; border-radius: 10px; flex: 1;">
<h4 style="color: #1e3a5f;">MOBILE CLIENT</h4>
<ul style="font-size: 0.85em;">
<li>Camera Capture</li>
<li>468 Landmarks (MediaPipe)</li>
<li>Real-time Processing</li>
<li style="color: #27ae60;"><strong>CHECK PASS</strong></li>
</ul>
</div>

</div>

<div style="display: flex; gap: 20px; margin-top: 20px;">
<div style="background: #e3f2fd; padding: 10px; border-radius: 5px; flex: 1;">
<strong>ACTIVE:</strong> EAR, MAR, Head Pose
</div>
<div style="background: #fce4ec; padding: 10px; border-radius: 5px; flex: 1;">
<strong>PASSIVE:</strong> LBP Texture, Color, Frequency
</div>
</div>

<!-- 7/17 -->

---

## BIOMETRIC PROCESSOR IN ACTION

<div style="display: flex; justify-content: space-around; gap: 20px;">

<div style="background: #f5f5f5; border: 2px solid #1e3a5f; border-radius: 10px; padding: 20px; text-align: center; flex: 1;">
<h4>[AHMET'S FACE with 468 MESH]</h4>
<div style="background: white; border: 2px solid #27ae60; border-radius: 5px; padding: 10px; margin-top: 10px;">
<p>EAR: 0.28</p>
<p>Quality: 94%</p>
<p style="color: #27ae60; font-weight: bold;">CHECK LIVE</p>
</div>
</div>

<div style="background: #f5f5f5; border: 2px solid #1e3a5f; border-radius: 10px; padding: 20px; text-align: center; flex: 1;">
<h4>[AYSENUR'S FACE with 468 MESH]</h4>
<div style="background: white; border: 2px solid #27ae60; border-radius: 5px; padding: 10px; margin-top: 10px;">
<p>EAR: 0.31</p>
<p>Quality: 96%</p>
<p style="color: #27ae60; font-weight: bold;">CHECK LIVE</p>
</div>
</div>

<div style="background: #f5f5f5; border: 2px solid #1e3a5f; border-radius: 10px; padding: 20px; text-align: center; flex: 1;">
<h4>[GULSUM'S FACE with 468 MESH]</h4>
<div style="background: white; border: 2px solid #27ae60; border-radius: 5px; padding: 10px; margin-top: 10px;">
<p>EAR: 0.29</p>
<p>Quality: 95%</p>
<p style="color: #27ae60; font-weight: bold;">CHECK LIVE</p>
</div>
</div>

</div>

<p style="text-align: center; color: #1e3a5f; margin-top: 20px;">
All team members verified with 468 facial landmarks + liveness detection
</p>

<!-- 8/17 -->

---

## ML PIPELINE & VECTOR SEARCH

<div style="background: #f5f5f5; padding: 20px; border-radius: 10px;">

### RECOGNITION PIPELINE

<div style="display: flex; justify-content: space-around; align-items: center; margin-top: 20px;">

<div style="background: #1e3a5f; color: white; padding: 15px; border-radius: 5px; text-align: center;">
<strong>Input</strong><br>Image
</div>

<span style="font-size: 1.5em; color: #f39c12;">></span>

<div style="background: #1e3a5f; color: white; padding: 15px; border-radius: 5px; text-align: center;">
<strong>Detect</strong><br>MediaPipe
</div>

<span style="font-size: 1.5em; color: #f39c12;">></span>

<div style="background: #1e3a5f; color: white; padding: 15px; border-radius: 5px; text-align: center;">
<strong>Align</strong><br>5-Point
</div>

<span style="font-size: 1.5em; color: #f39c12;">></span>

<div style="background: #1e3a5f; color: white; padding: 15px; border-radius: 5px; text-align: center;">
<strong>Extract</strong><br>Embedding
</div>

<span style="font-size: 1.5em; color: #f39c12;">></span>

<div style="background: #1e3a5f; color: white; padding: 15px; border-radius: 5px; text-align: center;">
<strong>Search</strong><br>Cosine
</div>

</div>

</div>

<div style="background: #1e3a5f; padding: 15px; border-radius: 5px; color: white; margin-top: 20px; text-align: center;">
<strong>VECTOR DATABASE:</strong> PostgreSQL + pgvector + IVFFlat -> O(log n) sub-ms queries
</div>

<div style="background: #27ae60; padding: 15px; border-radius: 5px; color: white; margin-top: 15px; text-align: center;">
<strong>Threshold: cosine distance < 0.68 = MATCH</strong>
</div>

<!-- 9/17 -->

---

## CARD DETECTION & NFC VERIFICATION

<div style="background: #f5f5f5; padding: 15px; border-radius: 10px; margin-bottom: 15px;">

### STEP 1: VISUAL CARD DETECTION (ML MODEL)

<p style="text-align: center; color: #f39c12;">[Camera] -> [Trained Model] -> [Card Type Detected]</p>

- Automatic ID type recognition (Turkish eID, Passport)
- Real-time detection via on-device ML
- Guides user for optimal card positioning

</div>

<div style="background: #f5f5f5; padding: 15px; border-radius: 10px;">

### STEP 2: NFC CHIP VERIFICATION (ICAO)

<p style="text-align: center; color: #f39c12;">[Mobile NFC] -> [BAC Handshake] -> [Read DG1/DG2] -> [SOD CHECK]</p>

- MRZ-derived session keys (3DES secure messaging)
- DG1: Personal data, DG2: High-res JPEG2000 photo
- Digital signature proves document authenticity

</div>

**STANDARDS:** ICAO Doc 9303, ISO/IEC 14443, ISO 7816-4
**CARDS:** Turkish eID, e-Passport, MIFARE, NDEF, 10+ types

<!-- 10/17 -->

---

## DOCUMENT VERIFICATION IN ACTION

<div style="display: flex; gap: 20px;">

<div style="background: #f5f5f5; padding: 15px; border-radius: 10px; flex: 1;">
<h4 style="color: #1e3a5f;">CARD DETECTION</h4>

<p>[TURKISH eID PHOTO]</p>
<p style="color: #27ae60;">Type: TURKISH_EID</p>
<p>Confidence: 97.3%</p>
<p style="color: #27ae60;">CHECK Ready for NFC</p>

<p>[E-PASSPORT PHOTO]</p>
<p>Type: E_PASSPORT | 98.1%</p>
</div>

<div style="background: #f5f5f5; padding: 15px; border-radius: 10px; flex: 1;">
<h4 style="color: #1e3a5f;">NFC CHIP READING</h4>

<p style="color: #27ae60;">CHECK BAC Authenticated</p>
<p style="color: #27ae60;">CHECK DG1 Personal Data</p>
<p style="color: #27ae60;">CHECK DG2 Photo Loaded</p>
<p style="color: #27ae60;">CHECK SOD Signature Valid</p>

<div style="background: white; border: 2px solid #27ae60; padding: 10px; border-radius: 5px; margin-top: 10px;">
<p>[HIGH-RES PHOTO FROM DG2 CHIP]</p>
<p style="font-size: 0.9em;">JPEG2000 Quality</p>
</div>
</div>

</div>

<p style="text-align: center; color: #1e3a5f; margin-top: 15px;">Left: ML model auto-detects | Right: NFC reads securely</p>

<!-- 11/17 -->

---

## WHAT WE BUILT - FALL 2025

<div style="display: flex; gap: 20px; font-size: 0.85em;">

<div style="flex: 1;">
<h4 style="color: #1e3a5f;">BIOMETRIC FEATURES</h4>

1. Face Detection (MediaPipe)
2. Face Enrollment
3. Face Verification (1:1)
4. Face Search (1:N)
5. Biometric Puzzle (Liveness)
6. Frame Quality Analysis
7. Demographic Analysis
8. Similarity Scoring
</div>

<div style="flex: 1;">
<h4 style="color: #1e3a5f;">DOCUMENT VERIFICATION</h4>

9. Visual Card Detection (ML)
10. NFC Document Reading
11. BAC Authentication
12. SOD Validation
13. MRZ Parsing
14. 10+ Card Types Support
</div>

<div style="flex: 1;">
<h4 style="color: #1e3a5f;">INFRASTRUCTURE</h4>

15. JWT Authentication
16. Multi-Tenant Architecture
17. 40+ REST API Endpoints
18. PostgreSQL + pgvector
19. IVFFlat Vector Indexing
20. Redis Caching
21. Flyway Migrations
22. Kotlin Multiplatform Apps
</div>

</div>

<div style="background: #f5f5f5; padding: 10px; border-radius: 5px; margin-top: 15px;">
<strong>WEB DEMO GUI:</strong> Dashboard, Enrollment, Verification, Search, Liveness, Quality
</div>

<!-- 12/17 -->

---

## TECHNICAL CHALLENGES

<div style="background: #f5f5f5; padding: 15px; border-radius: 10px; margin-bottom: 15px;">

### 1. NFC PASSPORT INTEGRATION

<span style="color: #e74c3c;">**Challenge:**</span> Complex ICAO protocols, BAC handshake, SOD parsing

<span style="color: #27ae60;">**Solution:**</span> Modular reader architecture with 7 specialized readers

</div>

<div style="background: #f5f5f5; padding: 15px; border-radius: 10px; margin-bottom: 15px;">

### 2. CARD DETECTION MODEL TRAINING

<span style="color: #e74c3c;">**Challenge:**</span> Dataset collection, model accuracy, real-time speed

<span style="color: #27ae60;">**Solution:**</span> Custom dataset + optimized on-device inference

</div>

<div style="background: #f5f5f5; padding: 15px; border-radius: 10px;">

### 3. CROSS-LANGUAGE MICROSERVICE COMMUNICATION

<span style="color: #e74c3c;">**Challenge:**</span> Java <-> Python service integration, type safety

<span style="color: #27ae60;">**Solution:**</span> REST APIs with OpenAPI contracts + Redis event bus

</div>

<!-- 13/17 -->

---

## SEMESTER 2 PLANS & B-PLAN

### SEMESTER 2 TIMELINE (Spring 2026)

| Month | Deliverable |
|:-----:|-------------|
| **FEB** | Service Integration + OCR Module |
| **MAR** | Real-Time Proctoring Module |
| **APR** | Security Testing + Mobile Polish |
| **MAY** | Production Deployment |

<div style="background: #fff3cd; padding: 15px; border-radius: 5px; margin-top: 20px;">

### CONTINGENCY PLAN (B-PLAN)
- IF NFC edge cases fail -> Focus on Turkish eID + e-Passport
- IF Integration delayed -> Web demo as primary deliverable

</div>

<div style="background: #f5f5f5; padding: 10px; border-radius: 5px; margin-top: 15px;">

### FUTURE RESEARCH
Offline mode | Fingerprint & iris | Embedded devices (Raspberry Pi)

</div>

<!-- 14/17 -->

---

<!-- _class: lead -->
<!-- _backgroundColor: #1e3a5f -->
<!-- _color: white -->

# THANK YOU

We thank our advisor, **Assoc. Prof. Dr. Mustafa Agaoglu**,
for his guidance throughout this project.

---

**GitHub:** github.com/Rollingcat-Software/FIVUCSAS

*(Will be released as open-source)*

<!-- 15/17 -->

---

## REFERENCES

[1] Taigman et al. (2014). **DeepFace: Closing the Gap to Human-Level
    Performance in Face Verification.** CVPR.

[2] Schroff et al. (2015). **FaceNet: A Unified Embedding for Face
    Recognition and Clustering.** IEEE CVPR.

[3] Deng et al. (2019). **ArcFace: Additive Angular Margin Loss for
    Deep Face Recognition.** CVPR.

[4] Lugaresi et al. (2019). **MediaPipe: A Framework for Building
    Perception Pipelines.** Google Research.

[5] **ICAO Doc 9303:** Machine Readable Travel Documents.

[6] **ISO/IEC 14443 & ISO 7816-4:** NFC Standards.

<!-- 16/17 -->

---

<!-- _class: lead -->
<!-- _backgroundColor: #1e3a5f -->
<!-- _color: white -->

# QUESTIONS & ANSWERS

We welcome your questions.

<!-- 17/17 -->
