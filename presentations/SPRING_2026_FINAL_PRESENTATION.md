# FIVUCSAS - CSE4197 Engineering Project 2 Final Presentation

**Date:** Spring 2026 (TBD)
**Duration:** 15 minutes + 5 minutes Q&A
**Language:** English
**Course:** CSE4197 Engineering Project 2

---

## Presenter Distribution

| Presenter | Slides | Time | Content |
|-----------|--------|------|---------|
| **Aysenur Arici** | 1-6 | ~5:00 | Title, Outline, Recap, Multi-Modal Auth Architecture, Anti-Spoofing, ML Pipeline |
| **Ahmet Abdullah Gultekin** | 7-12 | ~5:00 | Identity Core API, Auth Handlers, Web Dashboard, Deployment & CI/CD, Live Demo |
| **Ayse Gulsum Eren** | 13-18 | ~5:00 | Mobile/Desktop App, NFC Integration, Testing, Challenges, Future Work, Q&A |

---

# SLIDE 1 — TITLE

**Face and Identity Verification Using Cloud-based SaaS Models**
**(FIVUCSAS)**

CSE4197 Engineering Project 2 — Final Defense

---

**Team:**
- Ahmet Abdullah Gultekin (150121025)
- Ayse Gulsum Eren (150120005)
- Aysenur Arici (150123825)

**Advisor:** Assoc. Prof. Dr. Mustafa Agaoglu

Marmara University - Faculty of Technology
Department of Computer Engineering

Spring 2026

---

# SLIDE 2 — OUTLINE

**Presentation Outline**

| # | Topic | Presenter |
|---|-------|-----------|
| 1 | First Semester Recap | Aysenur |
| 2 | Multi-Modal Authentication Architecture | Aysenur |
| 3 | Anti-Spoofing & Liveness Detection | Aysenur |
| 4 | ML Pipeline & Face Recognition | Aysenur |
| 5 | Identity Core API — 10 Auth Handlers | Ahmet |
| 6 | Web Admin Dashboard & Auth Flow Builder | Ahmet |
| 7 | Deployment, CI/CD & Infrastructure | Ahmet |
| 8 | Live System Demo | Ahmet |
| 9 | Mobile & Desktop Applications | Gulsum |
| 10 | NFC Document Verification | Gulsum |
| 11 | Testing Strategy & Results | Gulsum |
| 12 | Challenges, Lessons & Future Work | Gulsum |

---

# SLIDE 3 — FIRST SEMESTER RECAP (Aysenur)

**What We Built in Semester 1 (CSE4297)**

| Component | Status | Key Achievement |
|-----------|--------|-----------------|
| Biometric Processor API | 100% | 46+ endpoints, 9 ML models |
| Demo GUI | 100% | 14 interactive pages (Next.js) |
| Database Schema | 100% | PostgreSQL + pgvector, 14 migrations |
| Identity Core API | 85% | JWT auth, RBAC, multi-tenancy |
| NFC Readers | 85% | Turkish eID + Universal reader |
| Mobile App | 50% | KMP shared logic + Android UI |
| Documentation | 100% | Architecture, API docs, guides |

**Semester 2 Focus:** Complete auth system, deploy to production, testing, mobile integration

---

# SLIDE 4 — MULTI-MODAL AUTH ARCHITECTURE (Aysenur)

**10-Method Authentication System**

```
┌─────────────────────────────────────────────────┐
│              Auth Flow Engine                      │
│                                                   │
│  Tenant-Configurable Multi-Step Authentication   │
│                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐     │
│  │ PASSWORD  │ │   FACE   │ │  EMAIL_OTP   │     │
│  └──────────┘ └──────────┘ └──────────────┘     │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐     │
│  │ SMS_OTP  │ │   TOTP   │ │   QR_CODE    │     │
│  └──────────┘ └──────────┘ └──────────────┘     │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐     │
│  │  FINGER  │ │  VOICE   │ │ HARDWARE_KEY │     │
│  └──────────┘ └──────────┘ └──────────────┘     │
│  ┌──────────────┐                                │
│  │ NFC_DOCUMENT │                                │
│  └──────────────┘                                │
└─────────────────────────────────────────────────┘
```

**Key Innovation:**
- Each tenant configures which auth methods to use per operation type
- 9 operation types: APP_LOGIN, API_ACCESS, DOOR_ACCESS, PAYMENT, etc.
- PASSWORD mandatory for APP_LOGIN/API_ACCESS (device constraint enforcement)
- Runtime flow validation at session start

---

# SLIDE 5 — ANTI-SPOOFING & LIVENESS (Aysenur)

**The Biometric Puzzle — Active Liveness Detection**

| Method | Technique | Purpose |
|--------|-----------|---------|
| Blink Detection | Eye Aspect Ratio (EAR) | Verify eye movement |
| Smile Detection | Mouth Aspect Ratio (MAR) | Verify facial control |
| Head Pose | Pitch, Yaw, Roll estimation | Verify 3D presence |
| Random Sequence | Challenge generation | Prevent replay attacks |

**Passive Anti-Spoofing (DeepFace 0.0.98):**
- Built-in anti-spoofing with configurable threshold
- Texture analysis (LBP patterns)
- Color distribution and frequency domain analysis
- Moire pattern detection for screen photos

**Browser-Side Face Detection (MediaPipe Tasks API):**
- Real-time face quality check before capture
- Bounding box guide, "Move closer" / "Better lighting" hints
- Face cropping before upload (smaller payload, better privacy)

---

# SLIDE 6 — ML PIPELINE & FACE RECOGNITION (Aysenur)

**9 Integrated ML Models**

| Model | Dimension | Purpose |
|-------|-----------|---------|
| FaceNet | 128-D | Default recognition |
| FaceNet512 | 512-D | High accuracy |
| ArcFace | 512-D | State-of-the-art |
| VGG-Face | 2622-D | High dimensional |
| GhostFaceNet | 512-D | Lightweight (new) |
| MediaPipe | 468 points | Facial landmarks |
| Dlib | 68 points | Alternative landmarks |
| YOLOv8 | - | Card/document detection |
| Custom CNN | - | Passive liveness |

**Vector Search Pipeline:**
1. Face detected (RetinaFace / MTCNN)
2. Anti-spoofing check (DeepFace built-in)
3. Embedding extracted (configurable model)
4. Stored in PostgreSQL pgvector (HNSW index)
5. 1:N search via cosine similarity

**Performance:** ~200ms per face verification on GTX 1650

---

# SLIDE 7 — IDENTITY CORE API (Ahmet)

**Spring Boot 3.2 + Java 21 — Production Ready**

| Feature | Details |
|---------|---------|
| Architecture | Hexagonal (Ports & Adapters) |
| Authentication | JWT (HS512) + Refresh Tokens |
| Authorization | RBAC with @PreAuthorize |
| Multi-Tenancy | Row-level security via tenant_id |
| Auth Handlers | 10 methods (Password → NFC) |
| Database | PostgreSQL 16 + pgvector, 16 Flyway migrations |
| Testing | 508+ unit tests pass |
| API Docs | Swagger UI (OpenAPI 3.0) |

**Database Schema (V16):**
- 20+ tables across identity, auth, biometric domains
- Auth flow system: 8 new tables for configurable multi-step auth
- Sample data: 3 tenants, 8 users, audit log entries

**Deployed:** GCP VM (34.116.233.134:8080)

---

# SLIDE 8 — 10 AUTH HANDLERS (Ahmet)

**Complete Implementation Details**

| # | Handler | Technology | Status |
|---|---------|-----------|--------|
| 1 | PasswordAuthHandler | BCrypt + Spring Security | Production |
| 2 | FaceAuthHandler | BiometricServicePort → FastAPI | Production |
| 3 | EmailOtpAuthHandler | SMTP + Redis (5-min TTL) | Production |
| 4 | QrCodeAuthHandler | WebSocket delegation | Production |
| 5 | TotpAuthHandler | dev.samstevens.totp + Redis | Production |
| 6 | SmsOtpAuthHandler | SmsService interface (Twilio ready) | Production |
| 7 | FingerprintAuthHandler | BiometricServicePort | Production |
| 8 | VoiceAuthHandler | BiometricServicePort | Production |
| 9 | HardwareKeyAuthHandler | com.yubico WebAuthn 2.5.2 | Production |
| 10 | NfcDocumentAuthHandler | Stub (needs physical hardware) | Stub |

**Design Pattern:** Strategy pattern — each handler implements `AuthHandler` interface with `authenticate(session, step, payload)` method. Selected at runtime based on `AuthMethod` enum.

---

# SLIDE 9 — WEB ADMIN DASHBOARD (Ahmet)

**React 18 + TypeScript + Material-UI 5**

| Page | Features |
|------|----------|
| Dashboard | Stats cards, system metrics, recent activity |
| Users | CRUD, role assignment, biometric status |
| Tenants | Create/edit, max users, contact info |
| Roles | Permission management |
| Auth Flows | Visual builder, operation type config, drag steps |
| Devices | User/tenant device listing |
| Enrollments | Biometric enrollment management |
| Audit Logs | Filterable by action, user, date range |
| Settings | Profile, security, notifications, appearance, i18n |

**Multi-Step Auth UI:**
- 10 step components (Password, Face, Email OTP, SMS, TOTP, QR, Fingerprint, Voice, Hardware Key, NFC)
- FaceCaptureStep: WebRTC + MediaPipe Tasks API for browser-side face detection
- StepProgress: MUI Stepper with method icons and status colors

**Deployed:** https://ica-fivucsas.rollingcatsoftware.com

---

# SLIDE 10 — DEPLOYMENT & CI/CD (Ahmet)

**Production Infrastructure**

```
┌─────────────────┐     ┌──────────────────────┐
│   Hostinger      │     │    GCP VM             │
│                  │     │    (europe-central2)   │
│  Web Dashboard   │────▶│  Identity Core API    │
│  Landing Website │     │  PostgreSQL + Redis    │
└─────────────────┘     └──────────┬───────────┘
                                    │ REST
                    ┌───────────────▼──────────────┐
                    │  Cloudflare Tunnel            │
                    │  (Laptop GPU — GTX 1650)      │
                    │  Biometric Processor (FastAPI)│
                    └──────────────────────────────┘
```

| Service | URL | Hosting |
|---------|-----|---------|
| Web Dashboard | ica-fivucsas.rollingcatsoftware.com | Hostinger |
| Landing Page | fivucsas.rollingcatsoftware.com | Hostinger |
| Identity API | 34.116.233.134:8080 | GCP VM |
| Biometric API | bpa-fivucsas.rollingcatsoftware.com | Cloudflare Tunnel |

**CI/CD:** GitHub Actions — 3 parallel jobs (Java 21 + Python 3.11 + Node 20)

---

# SLIDE 11 — LIVE DEMO (Ahmet)

**Demo Flow (2-3 minutes)**

1. **Login** — Navigate to ica-fivucsas.rollingcatsoftware.com, login with admin credentials
2. **Dashboard** — Show real-time stats (users, tenants, verifications, success rates)
3. **Users CRUD** — Create a test user, show tenant assignment
4. **Auth Flow Builder** — Create an APP_LOGIN flow with PASSWORD + FACE steps
5. **Audit Logs** — Filter by USER_LOGIN action, show recent events
6. **Multi-Step Auth** — Demonstrate 2-step login (Password → simulated Face capture)
7. **Swagger UI** — Show API documentation at /swagger-ui.html

**Backup:** Screenshots embedded in slides in case of network issues

---

# SLIDE 12 — MOBILE & DESKTOP APP (Gulsum)

**Kotlin Multiplatform + Compose Multiplatform**

| Platform | Screens | Status |
|----------|---------|--------|
| Android | Login, Register, Home, Enroll, Verify | UI Complete |
| Desktop | Welcome, Enroll, Verify, Admin Dashboard | UI Complete |
| iOS | Framework ready | Pending |

**Architecture:**
- Clean Architecture + MVVM
- Koin Dependency Injection
- Ktor HTTP Client
- 90% code sharing across platforms

**Shared Module:**
- 10 Use Cases (LoginUseCase, EnrollFaceUseCase, VerifyFaceUseCase, etc.)
- 5 ViewModels
- API contracts (AuthApi, BiometricApi, IdentityApi)
- Production URLs configured (GCP + Biometric processor endpoints)

**Desktop Kiosk Mode:** Self-service enrollment/verification stations

---

# SLIDE 13 — NFC DOCUMENT VERIFICATION (Gulsum)

**Two NFC Reader Implementations**

### UniversalNfcReader (60+ Kotlin files)
| Card Type | Authentication |
|-----------|---------------|
| Turkish eID | BAC with MRZ |
| e-Passport | BAC with TD3 MRZ |
| Istanbulkart | UID only |
| MIFARE Classic/DESFire/Ultralight | Key-based |
| NDEF Tags | Format-dependent |
| ISO 15693 (NfcV) | Varies |

### TurkishEidNfcReader (Dedicated)
- PIN Verification (6-digit)
- Personal Data (DG1) + Photo (DG2/JPEG2000)
- SOD Signature Validation (Bouncy Castle)
- Material Design 3 UI

**Standards:** ISO 14443-3/4, ISO 7816-4, ICAO Doc 9303

---

# SLIDE 14 — TESTING STRATEGY & RESULTS (Gulsum)

**Multi-Layer Testing**

| Layer | Framework | Count | Status |
|-------|-----------|-------|--------|
| Unit Tests (Backend) | JUnit 5 + Mockito | 508+ | All Pass |
| Auth Handler Tests | JUnit 5 | 30+ methods | All Pass |
| Constraint Tests | JUnit 5 | 4 tests | All Pass |
| E2E Tests (Web) | Playwright | 14 tests | All Pass |
| Integration Tests | TestContainers + PostgreSQL | 5+ tests | Ready |

**E2E Test Strategy:**
- Auth setup pattern: Single login, sessionStorage injection via `addInitScript`
- Eliminates rate limiting (HTTP 429) from repeated login attempts
- Tests against production: https://ica-fivucsas.rollingcatsoftware.com

**E2E Coverage:**
- Login flow (4 tests): page display, validation, credentials
- Users CRUD (3 tests): navigation, table, create form
- Auth Flow Builder (4 tests): navigation, create, PASSWORD constraint, DOOR_ACCESS
- Multi-Step Auth (2 tests): dashboard access, login rendering
- Auth Setup (1 test): session persistence

---

# SLIDE 15 — CHALLENGES & SOLUTIONS (Gulsum)

**Technical Challenges Encountered**

| Challenge | Solution |
|-----------|----------|
| H2 doesn't support PostgreSQL types (text[], jsonb) | TestContainers with real PostgreSQL |
| E2E rate limiting (429 errors) | Auth setup pattern — login once, inject session |
| Flyway checksum mismatch on redeployment | `validate-on-migrate: false` for Docker profile |
| Audit log infinite loop | Fixed @Transactional/@Async conflict |
| Mixed content (HTTP/HTTPS) on deployed dashboard | CSP headers + HTTPS enforcement |
| Virtual camera injection for face spoofing | Multi-factor auth + anti-spoofing pipeline |
| 4GB VRAM constraint (GTX 1650) | GhostFaceNet + RetinaFace (lightweight models) |
| Cross-platform code sharing (Android/Desktop/iOS) | Kotlin Multiplatform — 90% shared |

---

# SLIDE 16 — LESSONS LEARNED (Gulsum)

**Key Takeaways**

1. **Hexagonal Architecture pays off** — Changing from NoOp SMS to Twilio requires zero domain code changes
2. **Strategy Pattern for auth handlers** — Adding a new auth method = 1 new class + register in enum
3. **Browser-side ML is viable** — MediaPipe Tasks API runs face detection at 30fps in-browser
4. **Multi-tenant design from day one** — Retrofitting tenant isolation is extremely costly
5. **E2E tests save deployment time** — Caught 3 production bugs before manual testing
6. **CI/CD is essential** — GitHub Actions catches build failures within minutes
7. **pgvector enables SQL-native ML** — No separate vector database needed

---

# SLIDE 17 — FUTURE WORK & CONCLUSION (Gulsum)

**Remaining & Future Enhancements**

| Priority | Task | Status |
|----------|------|--------|
| High | Full Cloudflare Tunnel deployment | Scripts ready |
| High | Mobile app backend integration tests | URLs configured |
| Medium | SMS gateway (Twilio) production setup | Code ready |
| Medium | TOTP enrollment QR code in dashboard | Planned |
| Low | Real-time admin notifications (SSE) | Planned |
| Low | Advanced analytics charts | Planned |
| Future | Full WebAuthn attestation (CBOR) | Research |
| Future | iOS app UI implementation | Framework ready |

**Project Metrics:**

| Metric | Value |
|--------|-------|
| Total source files | 400+ |
| Backend endpoints | 46+ (Biometric) + 30+ (Identity) |
| ML models integrated | 9 |
| Auth methods supported | 10 |
| Database migrations | 16 |
| Unit tests | 508+ |
| E2E tests | 14 |
| Deployed services | 3 (Web, API, Landing) |

---

# SLIDE 18 — THANK YOU & Q&A

**Thank You**

**FIVUCSAS** — Face and Identity Verification Using Cloud-Based SaaS Models

**Live System:**
- Dashboard: https://ica-fivucsas.rollingcatsoftware.com
- Landing: https://fivucsas.rollingcatsoftware.com
- API Docs: http://34.116.233.134:8080/swagger-ui.html

**Repository:** github.com/Rollingcat-Software/FIVUCSAS

**Questions?**

---

## References

1. Schroff, F., Kalenichenko, D., & Philbin, J. (2015). FaceNet: A Unified Embedding for Face Recognition and Clustering. CVPR.
2. Deng, J., Guo, J., Xue, N., & Zafeiriou, S. (2019). ArcFace: Additive Angular Margin Loss for Deep Face Recognition. CVPR.
3. Serengil, S. I., & Ozpinar, A. (2024). A Benchmark of Facial Recognition Pipelines and Co-Usability Performances of Modules. Journal of Information Technologies.
4. ISO/IEC 30107-3:2023. Biometric presentation attack detection.
5. ICAO Doc 9303. Machine Readable Travel Documents.
6. Lugaresi, C., et al. (2019). MediaPipe: A Framework for Building Perception Pipelines. CVPR Workshop.
7. European Parliament. (2024). EU Artificial Intelligence Act. Regulation (EU) 2024/1689.
8. OWASP. (2023). OWASP Top 10 Web Application Security Risks.
9. Evans, C., et al. (2024). Spring Boot 3.2 Reference Documentation. VMware.
10. Tiangolo, S. (2024). FastAPI Documentation. https://fastapi.tiangolo.com

---

## Q&A Preparation — Anticipated Questions

### Q: How do you prevent deepfake attacks?
**A:** Multi-layered approach: (1) Active liveness — random facial action sequence (blink, smile, head turn), (2) Passive anti-spoofing — DeepFace 0.0.98 built-in detection, (3) Browser-side MediaPipe face detection for real-time quality checks, (4) Multi-factor auth makes face-only attacks insufficient.

### Q: Why not use a cloud biometric service (Azure, AWS)?
**A:** FIVUCSAS is designed as an open-source, self-hosted alternative. We integrate 9 ML models locally, giving full control over data privacy (no biometric data leaves the organization). Cloud services are vendor-locked and expensive at scale.

### Q: How does multi-tenancy work?
**A:** Every table includes a `tenant_id` foreign key. JPA queries are tenant-scoped. Each tenant can configure their own auth flows, user limits, and biometric settings independently. Row-level security ensures data isolation.

### Q: What's the face recognition accuracy?
**A:** Depends on model. ArcFace: 99.83% on LFW benchmark. FaceNet512: 99.65%. Our system uses cosine similarity with configurable thresholds (default 0.6 for verification, 0.4 for search).

### Q: Why Kotlin Multiplatform instead of Flutter?
**A:** KMP provides native performance on Android (direct JVM), shared business logic with type safety, and Compose Multiplatform offers native UI on both Android and Desktop. The 90% code sharing ratio is comparable to Flutter with better Android integration.

### Q: How do you handle the 4GB VRAM limitation?
**A:** We use lightweight models: GhostFaceNet for recognition (512-D, ~100MB), RetinaFace for detection (~30MB). Total GPU memory usage stays under 2GB, leaving headroom for concurrent requests.

### Q: What happens if the biometric processor is offline?
**A:** The Identity Core API returns a graceful error. Auth flows that include face verification will fail at that step, but password-based flows continue to work. The architecture is designed for service independence.

### Q: How do you ensure GDPR/KVKK compliance?
**A:** (1) Only embeddings stored, never raw images, (2) Existing delete endpoints for right to erasure, (3) Audit trail for all operations, (4) Multi-tenant isolation prevents cross-organization data access, (5) Purpose limitation — biometric data used only for authentication.
