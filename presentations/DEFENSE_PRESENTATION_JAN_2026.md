# FIVUCSAS - CSE4297 Engineering Project 1 Defense Presentation

**Date:** January 7, 2026
**Duration:** 12 minutes + 3 minutes Q&A
**Language:** English

---

## Slide 1: Title Slide (Page 1)

### Face and Identity Verification Using Cloud-based SaaS Models (FIVUCSAS)

**CSE4297 Engineering Project 1**

**Team Members:**
- Ahmet Abdullah Gültekin
- Ayşe Gülsüm Eren
- Ayşenur Arıcı

**Advisor:** Assoc. Prof. Dr. Mustafa Ağaoğlu

**Marmara University - Faculty of Technology**
Department of Computer Engineering

January 7, 2026

---

## Slide 2: Outline (Page 2)

### Presentation Outline

1. **Problem Definition** - Authentication security challenges
2. **Project Aims** - Four main objectives
3. **Related Work** - Existing solutions and gaps
4. **Scope** - Project boundaries and deliverables
5. **Methodology & Technical Approach** - Architecture and algorithms
6. **Tasks Accomplished** - First semester achievements
7. **Difficulties Encountered** - Challenges and solutions
8. **Second Semester Tasks** - Remaining work

---

## Slide 3: Problem Definition (Page 3)

### The Authentication Security Problem

**Current Challenges:**

| Challenge | Impact |
|-----------|--------|
| Password-only authentication | 81% of breaches involve weak credentials |
| Static biometric systems | Vulnerable to spoofing attacks (photos, videos) |
| Complex multi-factor auth | Poor user adoption due to friction |
| Identity document fraud | Increasing synthetic identity crimes |

**The Gap:**
- Existing solutions either sacrifice **security** for usability or **usability** for security
- No unified platform combining face recognition, liveness detection, and document verification

---

## Slide 4: Problem Definition - Real World Impact (Page 4)

### Why This Matters

**Industry Statistics:**
- Average cost of data breach: **$4.45M** (IBM, 2023)
- Face spoofing attacks increased **50%** since 2020
- **73%** of organizations lack proper biometric security

**Target Users:**
1. Financial institutions (KYC compliance)
2. Educational platforms (exam proctoring)
3. Enterprise access control
4. Government services (e-ID verification)

*Figure 1: Authentication vulnerability attack vectors*

---

## Slide 5: Project Aims (Page 5)

### Four Main Objectives

| # | Objective | Description |
|---|-----------|-------------|
| 1 | **Biometric Puzzle** | Novel liveness detection algorithm using random challenge sequences |
| 2 | **SaaS Platform** | Multi-tenant cloud-based biometric authentication service |
| 3 | **Cross-Platform App** | Mobile/desktop application with integrated biometrics |
| 4 | **Document Verification** | ICAO-compliant NFC passport/ID card reading |

**Success Metrics:**
- Face recognition accuracy: >98%
- Liveness detection spoof rejection: >99%
- API response time: <500ms
- Multi-platform support: Android, iOS, Desktop

---

## Slide 6: Related Work (Page 6)

### Existing Solutions Analysis

| Solution | Strengths | Limitations |
|----------|-----------|-------------|
| **DeepFace** | Multiple models, open-source | No liveness detection |
| **FaceNet** | 99.63% LFW accuracy | Single embedding model |
| **ArcFace** | State-of-art accuracy | Computationally heavy |
| **AWS Rekognition** | Cloud-scalable | Expensive, vendor lock-in |
| **Apple Face ID** | Excellent UX | Device-specific, not SaaS |

**Our Differentiation:**
- **Multi-model fusion** (9 ML models)
- **Active + Passive liveness** (Biometric Puzzle)
- **Self-hosted SaaS** (no vendor lock-in)
- **NFC document integration**

---

## Slide 7: Scope (Page 7)

### Project Scope & Deliverables

**In Scope:**

| Component | Technology | Status |
|-----------|------------|--------|
| Biometric API | FastAPI + DeepFace | ✅ Complete |
| Identity API | Spring Boot + JWT | 🔄 68% |
| Web Dashboard | Next.js + shadcn/ui | ✅ Complete |
| Mobile/Desktop | Kotlin Multiplatform | 🔄 60% |
| NFC Reader | Android NFC SDK | ✅ PoC Complete |
| Database | PostgreSQL + pgvector | ✅ Complete |

**Out of Scope:**
- Hardware development (dedicated biometric sensors)
- Custom ML model training (using pre-trained models)
- ISO/IEC 30107 certification (future work)

---

## Slide 8: System Architecture (Page 8)

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ Android App  │  │ Desktop App  │  │  Web Admin   │              │
│  │   (Kotlin)   │  │   (Kotlin)   │  │  (Next.js)   │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         API GATEWAY                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│   Identity Core API     │───▶│  Biometric Processor    │
│     (Spring Boot)       │    │      (FastAPI)          │
│  • Authentication       │    │  • Face Recognition     │
│  • User Management      │    │  • Liveness Detection   │
│  • Multi-Tenancy        │    │  • Quality Analysis     │
└───────────┬─────────────┘    └───────────┬─────────────┘
            │                              │
            └──────────────┬───────────────┘
                           ▼
              ┌─────────────────────────┐
              │   PostgreSQL + pgvector │
              │   (Face Embeddings)     │
              └─────────────────────────┘
```

*Figure 2: FIVUCSAS microservices architecture*

---

## Slide 9: Methodology - Biometric Puzzle Algorithm (Page 9)

### Novel Liveness Detection: Biometric Puzzle

**Challenge Sequence Generation:**
```
Actions = {blink, smile, turn_left, turn_right, nod}
Sequence = random_sample(Actions, k=3)
Example: [smile → turn_left → blink]
```

**Detection Metrics (MediaPipe):**

| Metric | Formula | Threshold |
|--------|---------|-----------|
| Eye Aspect Ratio (EAR) | (p2-p6 + p3-p5) / (2×p1-p4) | < 0.21 = blink |
| Mouth Aspect Ratio (MAR) | (p14-p18) / (p12-p16) | > 0.60 = smile |
| Head Pose | pitch, yaw, roll angles | ±15° threshold |

**Advantages over Passive-Only:**
- Defeats photo/video replay attacks
- Cannot be predicted (random sequence)
- Natural user interaction

*Figure 3: 468-point MediaPipe facial landmarks*

---

## Slide 10: Methodology - Face Recognition Pipeline (Page 10)

### Multi-Model Face Recognition

**Pipeline Stages:**

```
Image Input → Detection → Alignment → Embedding → Matching
     │            │           │           │           │
     │       RetinaFace    MediaPipe   FaceNet512   Cosine
     │       or MTCNN      landmarks    or ArcFace  Similarity
```

**Supported Models (9 Total):**

| Model | Embedding Dim | Accuracy (LFW) |
|-------|---------------|----------------|
| FaceNet | 128-D | 99.63% |
| FaceNet512 | 512-D | 99.65% |
| ArcFace | 512-D | 99.82% |
| VGG-Face | 2622-D | 98.78% |

**Similarity Calculation:**
```
cos(θ) = (A · B) / (||A|| × ||B||)
Match if: cos(θ) ≥ τ (τ = 0.68 default)
```

*Figure 4: Face recognition pipeline flow*

---

## Slide 11: Tasks Accomplished - Biometric Processor (Page 11)

### First Semester: Biometric Processor API (100%)

**46+ Endpoints Implemented:**

| Category | Endpoints | Status |
|----------|-----------|--------|
| Face Enrollment | `/enroll`, `/enrollments/{id}` | ✅ |
| Verification (1:1) | `/verify` | ✅ |
| Search (1:N) | `/search` | ✅ |
| Liveness Detection | `/liveness`, `/liveness/challenge` | ✅ |
| Quality Analysis | `/quality/analyze` | ✅ |
| Demographics | `/demographics/analyze` | ✅ |
| Landmarks | `/landmarks/detect` (468 points) | ✅ |
| Batch Operations | `/batch/*` | ✅ |
| Proctoring | `/proctoring/*`, WebSocket | ✅ |
| Admin | `/admin/*` | ✅ |

**Code Metrics:**
- Python files: 100+
- Test coverage: 85%
- Lines of code: 15,000+

---

## Slide 12: Tasks Accomplished - Web Dashboard (Page 12)

### First Semester: Demo GUI (100%)

**14+ Interactive Pages:**

| Page | Features |
|------|----------|
| Dashboard | Analytics overview, charts |
| Enrollment | Camera capture, real-time preview |
| Verification | 1:1 matching with confidence scores |
| Liveness | Biometric Puzzle demo |
| Quality | Image quality metrics visualization |
| Demographics | Age, gender, emotion analysis |
| Landmarks | 468-point interactive visualization |
| Similarity | NxN matrix clustering heatmap |
| Proctoring | Session management, WebSocket |

**Technology Stack:**
- Next.js 14 (App Router)
- TypeScript
- shadcn/ui components
- TailwindCSS

*Figure 5: Demo GUI screenshot - Dashboard*

---

## Slide 13: Tasks Accomplished - Identity API & Mobile (Page 13)

### First Semester: Supporting Components

**Identity Core API (68%):**

| Feature | Status |
|---------|--------|
| User Registration | ✅ Complete |
| JWT Authentication (HS512) | ✅ Complete |
| Refresh Token Management | ✅ Complete |
| BCrypt Password Hashing | ✅ Complete |
| Hexagonal Architecture | ✅ Complete |
| Database Schema (6 migrations) | ✅ Complete |
| RBAC Enforcement | 🔄 In Progress |

**Client Applications (60%):**

| Platform | UI | Backend Integration |
|----------|-----|---------------------|
| Android | ✅ Complete | 🔄 Pending |
| Desktop | ✅ Complete | 🔄 Pending |
| iOS | 📋 Ready | 🔄 Pending |

**NFC Reader (85%):** Turkish eID + Passport reading PoC

---

## Slide 14: Difficulties Encountered (Page 14)

### Technical Challenges & Solutions

| Challenge | Impact | Solution |
|-----------|--------|----------|
| **Model Loading Time** | 30s+ cold start | Lazy loading + model caching |
| **Large Embedding Storage** | 2622-D vectors expensive | pgvector + IVFFlat indexing |
| **WebSocket Stability** | Connection drops | Heartbeat + reconnection logic |
| **Cross-Platform Camera** | Different APIs | Platform abstraction layer |
| **Security Gaps** | Authorization bypass | Added ownership validation |

**Lessons Learned:**
1. Start with security architecture, not as afterthought
2. Model selection significantly impacts performance
3. Real-time streaming requires careful buffer management
4. Cross-platform development needs clear abstraction boundaries

---

## Slide 15: Difficulties Encountered - Architecture Decisions (Page 15)

### Key Architecture Decisions

**Decision 1: Keep Two APIs (Spring Boot + FastAPI)**

| Option | Pros | Cons |
|--------|------|------|
| Merge into FastAPI | Simpler deployment | Lose Spring Security |
| Merge into Spring | Single language | Poor ML support |
| **Keep Both** | Best of both | More complexity |

**Rationale:** Separation of concerns, technology fit, academic value

**Decision 2: Kotlin Multiplatform over Flutter**

| Factor | KMP | Flutter |
|--------|-----|---------|
| Native performance | ✅ Better | ❌ Lower |
| Android integration | ✅ Seamless | ❌ Bridge |
| Code sharing | 90% | 95% |

**Changed during implementation** due to NFC/CameraX requirements

---

## Slide 16: Second Semester Tasks (Page 16)

### Remaining Work (Semester 2)

**Priority 1: Critical (Weeks 1-4)**

| Task | Effort | Owner |
|------|--------|-------|
| User data isolation (security fix) | 4h | All |
| RBAC enforcement | 8h | Abdullah |
| Service-to-service auth | 6h | Gülsüm |
| Mobile-Backend integration | 2w | Ayşenur |

**Priority 2: High (Weeks 5-8)**

| Task | Effort | Owner |
|------|--------|-------|
| NFC reader integration | 1w | Ayşenur |
| Multi-tenancy enforcement | 2d | Abdullah |
| End-to-end testing | 2w | All |

**Priority 3: Production (Weeks 9-14)**

| Task | Effort | Owner |
|------|--------|-------|
| Docker/Kubernetes deployment | 1w | Gülsüm |
| Performance optimization | 1w | All |
| Documentation finalization | 1w | All |

---

## Slide 17: Conclusion & Demo (Page 17)

### Summary

**Achievements:**
- ✅ Complete biometric API with 46+ endpoints
- ✅ 9 ML models integrated
- ✅ Novel Biometric Puzzle liveness detection
- ✅ Interactive web dashboard
- ✅ Cross-platform app UI (Android + Desktop)
- ✅ NFC passport/ID reader proof-of-concept

**Innovation:**
- **Biometric Puzzle** - Random challenge sequences for liveness
- **Multi-model fusion** - Flexible model selection per use case
- **Self-hosted SaaS** - No vendor lock-in, full control

**Demo:** Live demonstration of enrollment, verification, and liveness detection

---

## Slide 18: References (Page 18)

### References

1. Schroff, F., Kalenichenko, D., & Philbin, J. (2015). *FaceNet: A unified embedding for face recognition and clustering*. CVPR.

2. Deng, J., Guo, J., & Zafeiriou, S. (2019). *ArcFace: Additive angular margin loss for deep face recognition*. CVPR.

3. Lugaresi, C., et al. (2019). *MediaPipe: A framework for building perception pipelines*. arXiv.

4. ICAO Doc 9303 (2021). *Machine Readable Travel Documents*. 8th Edition.

5. Soukupová, T., & Čech, J. (2016). *Real-time eye blink detection using facial landmarks*. 21st Computer Vision Winter Workshop.

6. ISO/IEC 19795-1:2021. *Biometric performance testing and reporting*.

7. OWASP (2023). *Top 10 Web Application Security Risks*.

---

## Backup Slides

### B1: API Endpoint Details

```
Biometric Processor API (FastAPI)
├── /api/v1/enroll          POST   # Face enrollment
├── /api/v1/verify          POST   # 1:1 verification
├── /api/v1/search          POST   # 1:N search
├── /api/v1/liveness        POST   # Passive liveness
├── /api/v1/liveness/challenge GET # Get challenge
├── /api/v1/quality/analyze POST   # Quality metrics
├── /api/v1/demographics    POST   # Age/gender/emotion
├── /api/v1/landmarks       POST   # 468 facial points
├── /api/v1/batch/*         POST   # Bulk operations
├── /api/v1/proctoring/*    WS     # Real-time session
└── /api/v1/admin/*         *      # Administration
```

### B2: Database Schema (pgvector)

```sql
CREATE TABLE biometric_data (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    tenant_id UUID REFERENCES tenants(id),
    embedding VECTOR(2622),  -- pgvector type
    model_used VARCHAR(50),
    quality_score DECIMAL(5,4),
    created_at TIMESTAMP
);

CREATE INDEX embedding_idx ON biometric_data
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
```

### B3: Security Analysis Summary

| Gap | Risk | Mitigation |
|-----|------|------------|
| No user isolation | CRITICAL | Add ownership checks |
| No RBAC | CRITICAL | Implement role system |
| No S2S auth | MEDIUM | Add API key to internal calls |
| Weak multi-tenancy | HIGH | Enforce tenant_id in queries |

---

## Presentation Notes

**Slide Timing (12 minutes):**
- Slides 1-2: 30 seconds
- Slides 3-4: 1.5 minutes (Problem)
- Slide 5: 1 minute (Aims)
- Slide 6: 1 minute (Related Work)
- Slide 7: 45 seconds (Scope)
- Slides 8-10: 2.5 minutes (Methodology)
- Slides 11-13: 2.5 minutes (Tasks)
- Slides 14-15: 1.5 minutes (Difficulties)
- Slide 16: 1 minute (Future)
- Slide 17: 45 seconds (Conclusion)

**Key Points to Emphasize:**
1. Biometric Puzzle is our novel contribution
2. 46+ working endpoints with demo
3. Multi-model approach for flexibility
4. Honest about security gaps and plan to fix

**Demo Preparation:**
- Start biometric-processor beforehand
- Have test images ready
- Test WebSocket connection
- Prepare backup video if live demo fails
