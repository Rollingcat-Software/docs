# FIVUCSAS Presentation - Slide Content (18 Slides)

> Copy each slide section directly into PowerPoint

---

# SLIDE 1 - TITLE

**Face and Identity Verification Using Cloud-based SaaS Models**
**(FIVUCSAS)**

CSE4297 Engineering Project 1

━━━━━━━━━━━━━━━━━━━━━━━━

**Team:**
• Ahmet Abdullah Gültekin
• Ayşe Gülsüm Eren
• Ayşenur Arıcı

**Advisor:** Assoc. Prof. Dr. Mustafa Ağaoğlu

Marmara University • Faculty of Technology
Department of Computer Engineering

January 7, 2026

---

# SLIDE 2 - OUTLINE

**Presentation Outline**

1. Problem Definition
2. Project Aims
3. Related Work
4. Scope
5. Methodology & Technical Approach
6. Tasks Accomplished
7. Difficulties Encountered
8. Second Semester Tasks

---

# SLIDE 3 - PROBLEM DEFINITION

**The Authentication Security Challenge**

| Problem | Impact |
|---------|--------|
| Password-only auth | 81% of breaches |
| Static biometrics | Vulnerable to spoofing |
| Complex MFA | Poor user adoption |
| Document fraud | Rising synthetic identity crimes |

**The Gap:**
No unified platform combining face recognition, liveness detection, and document verification with both security AND usability.

---

# SLIDE 4 - PROBLEM IMPACT

**Why This Matters**

• Average data breach cost: **$4.45M**
• Face spoofing attacks: **+50%** since 2020
• Organizations lacking proper biometric security: **73%**

**Target Users:**
• Financial institutions (KYC)
• Educational platforms (proctoring)
• Enterprise access control
• Government services

[Figure 1: Attack vector distribution]

---

# SLIDE 5 - PROJECT AIMS

**Four Main Objectives**

| # | Objective |
|---|-----------|
| 1 | **Biometric Puzzle** - Novel liveness detection using random challenge sequences |
| 2 | **SaaS Platform** - Multi-tenant cloud biometric service |
| 3 | **Cross-Platform App** - Mobile/desktop application |
| 4 | **Document Verification** - ICAO-compliant NFC reading |

**Success Metrics:**
• Face accuracy: >98%
• Spoof rejection: >99%
• Response time: <500ms

---

# SLIDE 6 - RELATED WORK

**Existing Solutions Analysis**

| Solution | Strength | Limitation |
|----------|----------|------------|
| DeepFace | Open-source | No liveness |
| FaceNet | 99.63% accuracy | Single model |
| ArcFace | State-of-art | Heavy compute |
| AWS Rekognition | Scalable | Vendor lock-in |
| Apple Face ID | Great UX | Device-only |

**Our Differentiation:**
✓ 9 ML models • ✓ Active+Passive liveness
✓ Self-hosted • ✓ NFC integration

---

# SLIDE 7 - SCOPE

**Project Deliverables**

| Component | Technology | Status |
|-----------|------------|--------|
| Biometric API | FastAPI | ✅ 100% |
| Identity API | Spring Boot | 🔄 68% |
| Web Dashboard | Next.js | ✅ 100% |
| Mobile/Desktop | Kotlin MP | 🔄 60% |
| NFC Reader | Android SDK | ✅ PoC |
| Database | PostgreSQL + pgvector | ✅ 100% |

**Out of Scope:** Hardware development, custom ML training

---

# SLIDE 8 - ARCHITECTURE

**System Architecture**

```
        ┌─────────────────────────────────┐
        │         CLIENT LAYER            │
        │  Android • Desktop • Web Admin  │
        └───────────────┬─────────────────┘
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌───────────────────┐     ┌───────────────────┐
│ Identity Core API │────▶│ Biometric Processor│
│  (Spring Boot)    │     │    (FastAPI)       │
│ • Authentication  │     │ • Face Recognition │
│ • User Management │     │ • Liveness         │
└─────────┬─────────┘     └─────────┬──────────┘
          └────────────┬────────────┘
                       ▼
            ┌───────────────────┐
            │ PostgreSQL        │
            │ + pgvector        │
            └───────────────────┘
```

[Figure 2: Microservices architecture]

---

# SLIDE 9 - METHODOLOGY: BIOMETRIC PUZZLE

**Novel Liveness Detection Algorithm**

**Random Challenge Sequence:**
```
Actions = {blink, smile, turn_left, turn_right, nod}
Sequence = random_sample(k=3)
Example: smile → turn_left → blink
```

**MediaPipe Detection Metrics:**

| Metric | Action | Threshold |
|--------|--------|-----------|
| EAR | Blink | < 0.21 |
| MAR | Smile | > 0.60 |
| Head Pose | Turn/Nod | ±15° |

**Advantage:** Cannot predict sequence → defeats replay attacks

[Figure 3: 468-point facial landmarks]

---

# SLIDE 10 - METHODOLOGY: FACE RECOGNITION

**Multi-Model Face Recognition Pipeline**

```
Image → Detection → Alignment → Embedding → Matching
         RetinaFace   MediaPipe   FaceNet512   Cosine
```

**Supported Models:**

| Model | Dimensions | Accuracy |
|-------|------------|----------|
| FaceNet | 128-D | 99.63% |
| FaceNet512 | 512-D | 99.65% |
| ArcFace | 512-D | 99.82% |
| VGG-Face | 2622-D | 98.78% |

**Matching:** cos(θ) ≥ 0.68 → Match

[Figure 4: Recognition pipeline]

---

# SLIDE 11 - TASKS: BIOMETRIC API

**Biometric Processor API (100% Complete)**

**46+ Endpoints:**

| Category | Endpoints |
|----------|-----------|
| Enrollment | /enroll, /enrollments/{id} |
| Verification | /verify (1:1) |
| Search | /search (1:N) |
| Liveness | /liveness, /challenge |
| Quality | /quality/analyze |
| Demographics | Age, gender, emotion |
| Landmarks | 468 facial points |
| Batch | Bulk operations |
| Proctoring | WebSocket streaming |

**Metrics:** 100+ Python files • 85% test coverage

---

# SLIDE 12 - TASKS: WEB DASHBOARD

**Demo GUI (100% Complete)**

**14+ Interactive Pages:**

| Page | Features |
|------|----------|
| Dashboard | Analytics, charts |
| Enrollment | Camera capture |
| Verification | 1:1 matching |
| Liveness | Biometric Puzzle demo |
| Quality | Image metrics |
| Demographics | Age/gender/emotion |
| Landmarks | 468-point visualization |
| Similarity | NxN heatmap |
| Proctoring | Real-time session |

**Stack:** Next.js 14 • TypeScript • shadcn/ui

[Figure 5: Dashboard screenshot]

---

# SLIDE 13 - TASKS: IDENTITY & MOBILE

**Supporting Components**

**Identity Core API (68%):**
• ✅ User Registration
• ✅ JWT Authentication (HS512)
• ✅ Refresh Token Management
• ✅ BCrypt Password Hashing
• ✅ Hexagonal Architecture
• 🔄 RBAC Enforcement (in progress)

**Client Applications (60%):**
• ✅ Android UI Complete
• ✅ Desktop UI Complete
• 🔄 Backend Integration Pending

**NFC Reader (85%):** Turkish eID + Passport PoC

---

# SLIDE 14 - DIFFICULTIES

**Technical Challenges**

| Challenge | Solution |
|-----------|----------|
| Model loading (30s+) | Lazy loading + caching |
| Large embeddings (2622-D) | pgvector + IVFFlat index |
| WebSocket drops | Heartbeat + reconnection |
| Cross-platform camera | Platform abstraction |
| Security gaps | Ownership validation |

**Lessons Learned:**
1. Design security architecture first
2. Model selection impacts performance
3. Real-time needs careful buffering
4. Cross-platform needs clear abstractions

---

# SLIDE 15 - ARCHITECTURE DECISIONS

**Key Decisions Made**

**Decision: Keep Two APIs**

| Option | Verdict |
|--------|---------|
| Merge to FastAPI | Lose Spring Security |
| Merge to Spring | Poor ML support |
| **Keep Both** | ✅ Best of both |

**Decision: Kotlin MP over Flutter**

| Factor | KMP | Flutter |
|--------|-----|---------|
| Native performance | ✅ Better | Lower |
| Android integration | ✅ Seamless | Bridge |

Changed mid-project for NFC/CameraX requirements

---

# SLIDE 16 - SECOND SEMESTER

**Remaining Tasks**

**Priority 1 - Critical (Weeks 1-4):**
• User data isolation fix (4h)
• RBAC enforcement (8h)
• Service-to-service auth (6h)
• Mobile-Backend integration (2w)

**Priority 2 - High (Weeks 5-8):**
• NFC reader integration (1w)
• Multi-tenancy enforcement (2d)
• End-to-end testing (2w)

**Priority 3 - Production (Weeks 9-14):**
• Docker/K8s deployment (1w)
• Performance optimization (1w)
• Documentation (1w)

---

# SLIDE 17 - CONCLUSION

**Summary**

**Achievements:**
✅ Complete biometric API (46+ endpoints)
✅ 9 ML models integrated
✅ Novel Biometric Puzzle liveness
✅ Interactive web dashboard
✅ Cross-platform app UI
✅ NFC passport/ID reader PoC

**Innovation:**
• Biometric Puzzle - Random challenge sequences
• Multi-model fusion - Flexible model selection
• Self-hosted SaaS - Full control, no vendor lock-in

**DEMO**

---

# SLIDE 18 - REFERENCES

**References**

1. Schroff, F. et al. (2015). *FaceNet: A unified embedding for face recognition*. CVPR.

2. Deng, J. et al. (2019). *ArcFace: Additive angular margin loss*. CVPR.

3. Lugaresi, C. et al. (2019). *MediaPipe: Building perception pipelines*. arXiv.

4. ICAO Doc 9303 (2021). *Machine Readable Travel Documents*. 8th Ed.

5. Soukupová, T. & Čech, J. (2016). *Real-time eye blink detection*. CVWW.

6. ISO/IEC 19795-1:2021. *Biometric performance testing*.

7. OWASP (2023). *Top 10 Web Application Security Risks*.

---

## Speaker Notes Summary

| Slide | Time | Key Points |
|-------|------|------------|
| 1-2 | 30s | Title, outline |
| 3-4 | 1.5m | Problem urgency |
| 5 | 1m | 4 objectives |
| 6 | 1m | Competition |
| 7 | 45s | What we deliver |
| 8-10 | 2.5m | Tech deep-dive |
| 11-13 | 2.5m | Demo each component |
| 14-15 | 1.5m | Honest challenges |
| 16 | 1m | Clear plan |
| 17 | 45s | Strong finish + demo |

**Total: 12 minutes**
