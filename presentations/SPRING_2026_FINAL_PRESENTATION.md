# FIVUCSAS - CSE4197 Engineering Project 2 Final Presentation

**Date:** Spring 2026 (TBD)
**Duration:** 15 minutes + 5 minutes Q&A
**Language:** English
**Course:** CSE4197 Engineering Project 2
**Last Updated:** 2026-03-28

---

## Presenter Distribution

| Presenter | Slides | Time | Content |
|-----------|--------|------|---------|
| **Aysenur Arici** | 1-6 | ~5:00 | Title, Outline, Recap, Multi-Modal Auth Architecture, Anti-Spoofing, ML Pipeline |
| **Ahmet Abdullah Gultekin** | 7-13 | ~5:30 | Identity Core API, Auth Handlers, Embeddable Widget, OAuth 2.0, Web Dashboard, Deployment, Live Demo |
| **Ayse Gulsum Eren** | 14-20 | ~5:30 | Mobile/Desktop App, NFC Integration, Testing, Platform Stats, Challenges, Future Work, Q&A |

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
| 6 | Embeddable Auth Widget — "Stripe Elements for Biometrics" | Ahmet |
| 7 | OAuth 2.0 / OIDC Standard Protocol Support | Ahmet |
| 8 | Web Admin Dashboard & Auth Flow Builder | Ahmet |
| 9 | Deployment, CI/CD & Infrastructure | Ahmet |
| 10 | Live System Demo | Ahmet |
| 11 | Mobile & Desktop Applications | Gulsum |
| 12 | NFC Document Verification | Gulsum |
| 13 | Testing Strategy & Platform Stats | Gulsum |
| 14 | Challenges, Lessons & Future Work | Gulsum |

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

**Semester 2 Focus:** Complete auth system, deploy to production, embeddable widget, OAuth 2.0, testing, mobile integration

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
| Auth Handlers | 10 methods (Password → NFC), all production-ready |
| OAuth 2.0 / OIDC | authorize, token, userinfo, discovery, JWKS |
| Database | PostgreSQL 16 + pgvector, 24 Flyway migrations (V1-V24) |
| Testing | 304 unit tests + 24 integration tests pass |
| API Docs | Swagger UI (OpenAPI 3.0) |

**Database Schema (V24):**
- 25+ tables across identity, auth, biometric, OAuth domains
- Auth flow system: 8 tables for configurable multi-step auth
- OAuth 2.0 tables: oauth2_clients, oauth2_authorization_codes (V24)
- Step-up auth: user_devices with ECDSA P-256 (V17)
- Sample data: 3 tenants, 8 users, audit log entries

**Deployed:** https://api.fivucsas.com (Hetzner CX43, 8CPU/16GB)

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
| 10 | NfcDocumentAuthHandler | Android NFC SDK (11K lines, 43 files) | Production |

**Design Pattern:** Strategy pattern — each handler implements `AuthHandler` interface with `authenticate(session, step, payload)` method. Selected at runtime based on `AuthMethod` enum.

---

# SLIDE 9 — EMBEDDABLE AUTH WIDGET (Ahmet)

**"Stripe Elements for Biometrics" — Embeddable Authentication**

**The Innovation:** No existing auth provider handles embedded biometric capture (camera, microphone). FIVUCSAS is the first to offer this as an embeddable widget.

**3-Layer Architecture:**

```
Layer 1: Developer API (Web Component)
  <fivucsas-verify client-id="..." flow="login" />

Layer 2: Orchestration (OAuth 2.0 + postMessage)
  Creates/manages auth sessions via FIVUCSAS API
  Coordinates multi-step flow via postMessage with iframe

Layer 3: Secure Capture (iframe from verify.fivucsas.com)
  Camera, microphone, WebAuthn run inside the iframe
  Biometric data NEVER leaves the iframe
  Only tokens/session IDs returned to host via postMessage
```

**Integration — Just 3 Lines (Script Tag):**
```html
<script src="https://cdn.fivucsas.com/auth-elements@1/fivucsas.min.js"></script>
<fivucsas-verify client-id="fiv_live_abc123" flow="login" theme="auto" />
```

**React Integration:**
```tsx
import { FivucsasProvider, VerifyButton } from '@fivucsas/auth-react';

function App() {
  return (
    <FivucsasProvider clientId="fiv_live_abc123">
      <VerifyButton flow="login" onComplete={({ authCode }) => { /* exchange */ }} />
    </FivucsasProvider>
  );
}
```

**KMP WebView Integration:**
- KMP apps load `verify.fivucsas.com/embed` in native WebView
- postMessage bridge works identically across Android/Desktop/iOS
- Native biometrics (fingerprint, NFC) handled natively, submitted to auth session API

**Security Model:**

| Concern | Solution |
|---------|----------|
| Biometric data isolation | Cross-origin iframe — host cannot access camera data |
| Token theft | Auth code flow — tokens never exposed to host JS |
| Clickjacking | CSP `frame-ancestors` whitelist per registered client |
| Replay attacks | Nonce in auth session, 30-second auth codes |
| CSRF | `state` parameter in OAuth 2.0 flow |

**Key Insight:** 90% of the code already exists in our web-app (MultiStepAuthFlow, 10 step components, biometric engine). The widget extracts and packages this into an embeddable SDK.

**Package Structure:**

| Package | Size | Purpose |
|---------|------|---------|
| `@fivucsas/auth-js` | ~9.5KB | Core SDK (iframe, postMessage, tokens) |
| `@fivucsas/auth-elements` | ~8KB | Web Components (Lit) |
| `@fivucsas/auth-react` | ~3KB | React bindings |
| `@fivucsas/auth-kotlin` | - | KMP SDK for mobile/desktop |

---

# SLIDE 10 — OAuth 2.0 / OIDC (Ahmet)

**Standard Protocol Support — OAuth 2.0 + OpenID Connect**

**Why OAuth 2.0?**
- Industry standard for authorization delegation
- Required for embeddable widget (third-party sites need token exchange)
- Enables FIVUCSAS as an Identity Provider (like e-Devlet, Google, Auth0)

**Endpoints Implemented:**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/oauth2/authorize` | GET | Authorization request (redirect or iframe) |
| `/oauth2/token` | POST | Token exchange (auth code -> access + id tokens) |
| `/oauth2/userinfo` | GET | User profile (OIDC standard claims) |
| `/.well-known/openid-configuration` | GET | OIDC Discovery document |
| `/.well-known/jwks.json` | GET | JSON Web Key Set for token verification |

**OIDC Discovery Document:**
```json
{
  "issuer": "https://api.fivucsas.com",
  "authorization_endpoint": "https://api.fivucsas.com/oauth2/authorize",
  "token_endpoint": "https://api.fivucsas.com/oauth2/token",
  "userinfo_endpoint": "https://api.fivucsas.com/oauth2/userinfo",
  "jwks_uri": "https://api.fivucsas.com/.well-known/jwks.json",
  "response_types_supported": ["code"],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["RS256"],
  "scopes_supported": ["openid", "profile", "email", "biometric"]
}
```

**Client Registration:**
- Developers register applications via Developer Portal
- Receive `client_id` and `client_secret`
- Configure redirect URIs and allowed scopes
- Per-client auth flow configuration (which biometric methods to require)

**Token Flow:**
```
1. Third-party redirects to /oauth2/authorize?client_id=...&scope=openid biometric
2. User completes multi-step auth (password + face + TOTP, etc.)
3. FIVUCSAS redirects back with authorization code
4. Third-party exchanges code for tokens via /oauth2/token
5. access_token grants API access, id_token contains user identity
```

---

# SLIDE 11 — WEB ADMIN DASHBOARD (Ahmet)

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
| Analytics | Pie, bar, area, radial charts (Recharts) |
| Auth Test | Live 11-section biometric auth test page |
| Widget Demo | Embeddable widget live preview |
| Developer Portal | SDK docs, integration guide, client registration |

**Multi-Step Auth UI:**
- 10 step components (Password, Face, Email OTP, SMS, TOTP, QR, Fingerprint, Voice, Hardware Key, NFC)
- FaceCaptureStep: WebRTC + MediaPipe Tasks API for browser-side face detection
- StepProgress: MUI Stepper with method icons and status colors
- i18n: Full Turkish/English bilingual UI (i18next)
- Real-time notification panel with audit log polling

**Deployed:** https://app.fivucsas.com

---

# SLIDE 12 — DEPLOYMENT & CI/CD (Ahmet)

**Production Infrastructure — Hetzner CX43 (8 CPU / 16GB RAM / 150GB SSD)**

```
┌──────────────────────┐     ┌──────────────────────────────────────┐
│   Hostinger           │     │  Hetzner VPS (CX43, Nuremberg)       │
│                       │     │                                      │
│  Web Dashboard        │────▶│  Identity Core API (port 8080)       │
│  Landing Website      │     │  Biometric API (port 8001, CPU mode) │
│  Auth-Test Page       │     │  PostgreSQL 16 + pgvector             │
│                       │     │  Redis 7                              │
└──────────────────────┘     │  NGINX API Gateway                    │
                              └──────────────────────────────────────┘
```

| Service | URL | Hosting |
|---------|-----|---------|
| Web Dashboard | https://app.fivucsas.com | Hostinger |
| Widget Demo | https://app.fivucsas.com/widget-demo | Hostinger |
| Developer Portal | https://app.fivucsas.com/developer-portal | Hostinger |
| Landing Page | https://fivucsas.com | Hostinger |
| Identity API | https://api.fivucsas.com | Hetzner VPS |
| Biometric API | https://bio.fivucsas.com | Hetzner VPS |
| OIDC Discovery | https://api.fivucsas.com/.well-known/openid-configuration | Hetzner VPS |
| API Health | https://api.fivucsas.com/actuator/health | Hetzner VPS |

**CI/CD:** GitHub Actions — 3 parallel jobs (Java 21 + Python 3.11 + Node 20) + Playwright E2E workflow
**Containers:** 12 Docker containers, all healthy (identity-core-api, biometric-api, postgres, redis, nginx, etc.)

---

# SLIDE 13 — LIVE DEMO (Ahmet)

**Demo Flow (2-3 minutes)**

1. **Login** — Navigate to https://app.fivucsas.com, login with admin credentials
2. **Dashboard** — Show real-time stats (users, tenants, verifications, success rates)
3. **Users CRUD** — Create a test user, show tenant assignment
4. **Auth Flow Builder** — Create an APP_LOGIN flow with PASSWORD + FACE steps
5. **Auth Test Page** — Demonstrate live biometric auth (face, voice, fingerprint, TOTP)
6. **Widget Demo** — Show embeddable widget at /widget-demo (3-line integration)
7. **Developer Portal** — Show SDK documentation and client registration at /developer-portal
8. **OIDC Discovery** — Show https://api.fivucsas.com/.well-known/openid-configuration
9. **Swagger UI** — Show API documentation at /swagger-ui.html
10. **Biometric API Health** — Show https://bio.fivucsas.com/api/v1/health

**Backup:** Screenshots embedded in slides in case of network issues

---

# SLIDE 14 — MOBILE & DESKTOP APP (Gulsum)

**Kotlin Multiplatform + Compose Multiplatform**

| Platform | Screens | Status |
|----------|---------|--------|
| Android | Login, Register, Home, Enroll, Verify, Voice, Face Liveness, Card Detection | UI Complete |
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
- Production URLs configured (Hetzner + Biometric processor endpoints)
- i18n support, mocks removed, 6 new screens added (March 2026)

**New Screens (March 2026):** VoiceVerifyScreen, FaceLivenessScreen, CardDetectionScreen

**WebView Widget Integration:** KMP apps load embeddable widget in native WebView for biometric auth

**Desktop Kiosk Mode:** Self-service enrollment/verification stations

---

# SLIDE 15 — NFC DOCUMENT VERIFICATION (Gulsum)

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
**NFC codebase:** 11,089 lines across 43 files (integrated into client-apps)

---

# SLIDE 16 — TESTING STRATEGY & PLATFORM STATS (Gulsum)

**Multi-Layer Testing**

| Layer | Framework | Count | Status |
|-------|-----------|-------|--------|
| Unit Tests (Backend) | JUnit 5 + Mockito | 304+ | All Pass |
| Auth Handler Tests | JUnit 5 | 30+ methods | All Pass |
| Constraint Tests | JUnit 5 | 4 tests | All Pass |
| Step-Up Auth Tests | JUnit 5 | 20 tests | All Pass |
| E2E Tests (Web) | Playwright | 247+ | 247 Pass, 7 Skipped |
| Integration Tests | TestContainers + PostgreSQL | 24 tests | All Pass |
| Vitest (Frontend) | Vitest | 171 tests | All Pass |
| Other Project Tests | Various | Sarnic 456, etc. | All Pass |

**E2E Test Strategy:**
- Auth setup pattern: Single login, sessionStorage injection via `addInitScript`
- Eliminates rate limiting (HTTP 429) from repeated login attempts
- Tests against production: https://app.fivucsas.com
- Playwright CI workflow integrated into GitHub Actions

**E2E Coverage (16+ spec files):**
- Login flow, Users CRUD, Auth Flow Builder, Multi-Step Auth
- Analytics page, Settings, Tenants, Roles, Devices
- Audit Logs, Enrollments, Auth Sessions, Auth Test page
- Widget Demo, Developer Portal

**Platform Stats:**

| Metric | Value |
|--------|-------|
| Auth methods production-ready | **10/10** |
| SDK size (auth-js) | **9.5KB**, zero dependencies |
| Unit tests passing | **304** |
| E2E tests passing | **247** |
| Frontend tests (Vitest) | **171** |
| OAuth 2.0 compliant | Yes (OIDC Discovery + JWKS) |
| Total lines of code | **~15,000+** across 4 repos |
| Docker containers (all healthy) | **12** |
| API endpoints | **46+** (Biometric) + **30+** (Identity) + **5** (OAuth) |
| Database migrations | **24** (V1-V24) |
| ML models integrated | **9** |
| Deployed services | **6** (Dashboard, Landing, Auth-Test, Identity API, Biometric API, OIDC) |
| Bilingual i18n | Turkish + English |

---

# SLIDE 17 — CHALLENGES & SOLUTIONS (Gulsum)

**Technical Challenges Encountered**

| Challenge | Solution |
|-----------|----------|
| H2 doesn't support PostgreSQL types (text[], jsonb) | TestContainers with real PostgreSQL |
| E2E rate limiting (429 errors) | Auth setup pattern — login once, inject session |
| Flyway checksum mismatch on redeployment | `validate-on-migrate: false` for Docker profile |
| Audit log infinite loop | Fixed @Transactional/@Async conflict |
| Mixed content (HTTP/HTTPS) on deployed dashboard | CSP headers + HTTPS enforcement |
| Virtual camera injection for face spoofing | Multi-factor auth + anti-spoofing pipeline |
| 4GB VRAM constraint (GTX 1650) | GhostFaceNet + RetinaFace (lightweight models); also CPU-mode deployment |
| Cross-platform code sharing (Android/Desktop/iOS) | Kotlin Multiplatform — 90% shared |
| Biometric data in embedded widget (cross-origin) | Stripe-style iframe isolation — data never leaves iframe |
| WebAuthn fingerprint vs hardware key confusion | Separate flows: credentials.get() for fingerprint, server challenge for hardware key |
| AuthSession step completion data format | { data } wrapper fix — resolved all secondary auth failures |
| Biometric API memory (3GB limit, 94% usage) | Upgraded Hetzner CX33 to CX43 (16GB RAM) |

---

# SLIDE 18 — LESSONS LEARNED (Gulsum)

**Key Takeaways**

1. **Hexagonal Architecture pays off** — Changing from NoOp SMS to Twilio requires zero domain code changes
2. **Strategy Pattern for auth handlers** — Adding a new auth method = 1 new class + register in enum
3. **Browser-side ML is viable** — MediaPipe Tasks API runs face detection at 30fps in-browser
4. **Multi-tenant design from day one** — Retrofitting tenant isolation is extremely costly
5. **E2E tests save deployment time** — Caught 3 production bugs before manual testing
6. **CI/CD is essential** — GitHub Actions catches build failures within minutes
7. **pgvector enables SQL-native ML** — No separate vector database needed
8. **Embed with iframes, not SDKs** — Stripe's iframe model is ideal for sensitive biometric data
9. **OAuth 2.0 is table stakes** — Every auth platform must support standard protocols for adoption
10. **Dogfooding validates architecture** — Using our own widget in our own dashboard proves it works

---

# SLIDE 19 — FUTURE WORK & CONCLUSION (Gulsum)

**Remaining & Future Enhancements**

| Priority | Task | Status |
|----------|------|--------|
| High | Web Components (`@fivucsas/auth-elements`) packaging | In Progress |
| High | Widget dogfooding — use own widget in web-app login | In Progress |
| High | Mobile app backend integration tests | URLs configured |
| Medium | SMS gateway (Twilio) production activation | Code ready |
| Medium | Client-side ONNX card detection (replacing server YOLO) | In Progress |
| Low | ISO/IEC 30107 compliance certification | Future |
| Low | Full WebAuthn attestation (CBOR) | Research |
| Future | iOS app UI implementation | Framework ready |
| Future | Multi-region deployment (HA) | Architecture designed |

**Final Project Metrics:**

| Metric | Value |
|--------|-------|
| Total source files | 400+ |
| Backend endpoints | 46+ (Biometric) + 30+ (Identity) + 5 (OAuth) |
| ML models integrated | 9 |
| Auth methods (all production-ready) | **10/10** |
| Database migrations | 24 (V1-V24) |
| Unit tests | 304 |
| E2E tests | 247 |
| Frontend tests (Vitest) | 171 |
| Docker containers (all healthy) | 12 |
| Deployed services | 6 (Dashboard, Landing, Auth-Test, Identity API, Biometric API, OIDC) |
| SDK size | 9.5KB, zero dependencies |
| Lines of code | ~15,000+ across 4 repos |
| OAuth 2.0 / OIDC | Fully compliant |
| i18n | Turkish + English |

---

# SLIDE 20 — THANK YOU & Q&A

**Thank You**

**FIVUCSAS** — Face and Identity Verification Using Cloud-Based SaaS Models

**Live System URLs:**

| Service | URL |
|---------|-----|
| Dashboard | https://app.fivucsas.com |
| Widget Demo | https://app.fivucsas.com/widget-demo |
| Developer Portal | https://app.fivucsas.com/developer-portal |
| Landing Page | https://fivucsas.com |
| API Health | https://api.fivucsas.com/actuator/health |
| Biometric API | https://bio.fivucsas.com/api/v1/health |
| OIDC Discovery | https://api.fivucsas.com/.well-known/openid-configuration |
| Swagger UI | https://api.fivucsas.com/swagger-ui.html |

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

### Q: How does the embeddable widget protect biometric data on third-party sites?
**A:** We use Stripe's iframe isolation model. The widget runs inside a cross-origin iframe from verify.fivucsas.com. Camera and microphone access is confined to the iframe. The host page never sees raw biometric data — only authorization codes are returned via postMessage. This is the same architecture Stripe uses to protect credit card numbers.

### Q: Why OAuth 2.0 instead of a custom token system?
**A:** OAuth 2.0 is the industry standard for authorization delegation. It enables FIVUCSAS to serve as a full Identity Provider — any third-party application can integrate using standard libraries (like passport.js, Spring Security OAuth). OIDC adds identity claims (who the user is). This makes adoption easy because developers already know the protocol.

### Q: How does the 9.5KB SDK compare to alternatives?
**A:** Auth0 Lock is ~400KB, Firebase Auth UI is ~100KB, Keycloak.js is ~20KB. Our SDK is 9.5KB with zero dependencies because we delegate all heavy work (UI, biometric capture, auth flow orchestration) to the hosted iframe. The SDK only handles iframe lifecycle and postMessage communication.

### Q: Can the widget handle all 10 auth methods?
**A:** Yes. The widget extracts the same MultiStepAuthFlow component and all 10 step components from our web-app. Face, voice, fingerprint (WebAuthn), hardware key, TOTP, QR code — they all work inside the iframe. The tenant's configured auth flow determines which steps appear.
