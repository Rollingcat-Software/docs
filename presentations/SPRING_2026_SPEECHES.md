# FIVUCSAS Spring 2026 — Speaker Notes

**Date:** Spring 2026 (TBD)
**Duration:** 15 minutes + 5 minutes Q&A
**Total Slides:** 18

---

## Presenter Distribution

| Presenter | Slides | Time |
|-----------|--------|------|
| **Aysenur Arici** | 1-6 | ~5:00 |
| **Ahmet Abdullah Gultekin** | 7-12 | ~5:00 |
| **Ayse Gulsum Eren** | 13-18 | ~5:00 |

---

# AYSENUR ARICI (Slides 1-6)

---

## SLIDE 1: Title (25 sec)

```
Good morning everyone. We are presenting the final defense of FIVUCSAS —
Face and Identity Verification Using Cloud-Based SaaS Models.

I am Aysenur Arici. With me are Ahmet Abdullah Gultekin and Ayse Gulsum
Eren. Our project advisor is Associate Professor Doctor Mustafa Agaoglu.

This is our second semester defense for CSE4197 Engineering Project 2.
```

---

## SLIDE 2: Outline (25 sec)

```
Our presentation covers three sections.

First, I will recap our first semester work and present the multi-modal
authentication architecture, anti-spoofing system, and ML pipeline.

Then Ahmet will demonstrate the Identity Core API, web dashboard, and
deployment infrastructure with a live demo.

Finally, Gulsum will cover the mobile application, NFC readers, testing
strategy, and future work.
```

---

## SLIDE 3: First Semester Recap (45 sec)

```
In our first semester, we built the core platform components.

The Biometric Processor API with 46 endpoints and 9 machine learning
models was completed. We built 14 interactive demo pages with Next.js.

The database schema with PostgreSQL and pgvector for face embeddings
was finalized with 14 Flyway migrations.

The Identity Core API was at 85 percent — basic JWT auth and RBAC
were working, but the multi-modal auth system was not yet implemented.

For the second semester, our focus was: complete the auth system,
deploy everything to production, add comprehensive testing, and
integrate the mobile application.
```

---

## SLIDE 4: Multi-Modal Auth Architecture (60 sec)

```
The centerpiece of our second semester work is the multi-modal
authentication system.

We implemented 10 authentication methods — from password and face
recognition to hardware keys and NFC documents.

The key innovation is tenant-configurable auth flows. Each
organization using our platform can define their own authentication
steps for different operations.

For example, a bank's APP_LOGIN might require password plus face
verification, while their DOOR_ACCESS might only need a hardware key.

We enforce device constraints — PASSWORD is mandatory as the first
step for APP_LOGIN and API_ACCESS operations. But for physical
operations like DOOR_ACCESS, tenants have full freedom.

The system uses the Strategy pattern — each auth method is a separate
handler class. Adding a new method requires just one new class and
registering it in the enum. Zero changes to existing code.
```

---

## SLIDE 5: Anti-Spoofing & Liveness (50 sec)

```
Anti-spoofing is critical for any biometric system.

Our Biometric Puzzle is an active liveness detection algorithm. It
generates a random sequence of facial actions — blink, smile, look
left, look right. The user must perform these actions in the correct
order, proving they are live and present.

On the passive side, we upgraded to DeepFace version 0.0.98 which
includes built-in anti-spoofing. It detects texture patterns,
color distributions, and moire patterns from photos of screens.

A significant addition this semester is browser-side face detection
using Google's MediaPipe Tasks API. Before the user even captures
their photo, the browser detects if a face is present, centered,
and well-lit. This improves user experience and reduces server load.
```

---

## SLIDE 6: ML Pipeline (45 sec)

```
Our system integrates 9 machine learning models.

For face recognition, we support FaceNet, ArcFace, VGG-Face, and the
newly added GhostFaceNet — which is lightweight enough for our 4GB
GPU.

For detection, we use RetinaFace as the default, with MTCNN, YOLO v8
through v12, and CenterFace as alternatives.

The vector search pipeline works as follows: a face is detected,
anti-spoofing is checked, an embedding is extracted, and then stored
or compared using PostgreSQL pgvector with HNSW indexing.

Verification takes approximately 200 milliseconds on our GTX 1650.

Now I will hand over to Ahmet for the Identity Core API and live demo.
```

---

# AHMET ABDULLAH GULTEKIN (Slides 7-12)

---

## SLIDE 7: Identity Core API (50 sec)

```
Thank you Aysenur.

The Identity Core API is built with Spring Boot 3.2 and Java 21,
following hexagonal architecture with ports and adapters.

It provides JWT authentication with HS512, role-based access control
with PreAuthorize annotations, and multi-tenant isolation via
tenant ID foreign keys on every table.

The database has 16 Flyway migrations creating over 20 tables. The
V16 migration alone added 8 tables for the configurable auth flow
system — auth methods, tenant auth methods, auth flows, auth flow
steps, auth sessions, session steps, user devices, and enrollments.

We have 508 unit tests passing. The API is deployed and running on
a Google Cloud Platform virtual machine in the Europe Central 2 region.
```

---

## SLIDE 8: 10 Auth Handlers (50 sec)

```
All 10 authentication handlers are implemented and tested.

Password uses BCrypt with Spring Security. Face verification calls
our biometric processor via REST. Email OTP sends codes via SMTP
with a 5-minute expiry in Redis.

QR Code authentication uses WebSocket delegation — the user scans
a QR on their phone, and the desktop session updates in real-time.

TOTP wraps the samstevens library and stores secrets in Redis.
SMS OTP uses an abstracted SmsService interface — currently using
a no-op implementation, but Twilio integration code is ready.

Fingerprint and Voice verification route through the
BiometricServicePort adapter to our FastAPI service.

Hardware Key uses the Yubico WebAuthn library version 2.5.2 for
FIDO2 challenge-response authentication.

NFC Document is a stub handler awaiting physical hardware integration.
```

---

## SLIDE 9: Web Dashboard (45 sec)

```
The web admin dashboard is built with React 18, TypeScript, and
Material UI 5.

It features a dashboard with real-time statistics, users CRUD with
role assignment, tenant management, and an audit log viewer with
filters.

The Auth Flow Builder is a visual tool where administrators can
create authentication flows. They select an operation type, add
steps like password, face, and OTP, and the system enforces
constraints automatically.

The Multi-Step Authentication UI has 10 step components. The Face
Capture step uses WebRTC for camera access and MediaPipe for
browser-side face detection.

The dashboard supports dark mode, internationalization in Turkish
and English, and is deployed to Hostinger at the URL shown.
```

---

## SLIDE 10: Deployment & CI/CD (45 sec)

```
Our deployment uses three hosting platforms.

The web dashboard and landing page are on Hostinger with static
file hosting. The Identity Core API runs on a GCP virtual machine
with Docker — alongside PostgreSQL and Redis containers.

The biometric processor runs on my laptop GPU through a Cloudflare
Tunnel, making it accessible via HTTPS from anywhere.

Our CI/CD pipeline uses GitHub Actions with three parallel jobs —
Java 21 for the backend, Python 3.11 for the biometric processor,
and Node 20 for the web dashboard. Each push triggers automated
builds and tests.
```

---

## SLIDE 11: Live Demo (2-3 min)

```
Let me show you the live system.

[Navigate to ica-fivucsas.rollingcatsoftware.com]

This is the login page. I will sign in with the admin account.

[Login and show dashboard]

The dashboard shows our platform statistics — total users, active
users, tenants, biometric enrollment rates, and authentication
success rates.

[Navigate to Users]

Here we can manage users — create, edit, assign roles and tenants.

[Navigate to Auth Flows]

This is the Auth Flow Builder. Let me create a new flow for
APP_LOGIN. Notice how PASSWORD is automatically added as the
first step — this is our device constraint enforcement.

[Navigate to Audit Logs]

All operations are logged. I can filter by action type, user,
and date range.

[Show Swagger UI]

Finally, the full API documentation is available at swagger-ui.

Now I hand over to Gulsum.
```

---

# AYSE GULSUM EREN (Slides 13-18)

---

## SLIDE 12: Mobile & Desktop App (50 sec)

```
Thank you Ahmet.

Our mobile and desktop applications are built with Kotlin
Multiplatform and Compose Multiplatform.

On Android, we have Login, Register, Home, Enroll, and Verify
screens with CameraX integration for face capture.

The Desktop application includes a Welcome screen with mode
selection, self-service enrollment and verification screens,
and a full admin dashboard with tabs for users, analytics,
security, and settings.

The architecture uses Clean Architecture with MVVM pattern,
Koin for dependency injection, and Ktor for HTTP communication.

We achieve 90 percent code sharing across platforms through the
shared module, which contains 10 use cases, 5 view models, and
all API contracts. Production API URLs are configured and ready
for integration testing.
```

---

## SLIDE 13: NFC Document Verification (45 sec)

```
We built two NFC reader implementations.

The Universal NFC Reader supports over 10 card types — Turkish
national ID cards, e-Passports, Istanbulkart transit cards,
various MIFARE cards, and generic NFC tags.

For identity documents, we implement BAC authentication using
MRZ data, then read personal data from DG1 and extract the
photo from DG2 in JPEG2000 format.

Security features include PIN and password memory-only handling,
two-phase memory wipe, 3DES encryption for secure messaging,
and SOD signature validation using Bouncy Castle.

The dedicated Turkish eID Reader is fully functional with
Material Design 3 UI and full compliance with ISO 14443 and
ICAO Document 9303 standards.
```

---

## SLIDE 14: Testing Strategy (50 sec)

```
Our testing strategy covers multiple layers.

At the unit level, we have 508 tests for the identity core API
using JUnit 5 and Mockito. All 10 auth handlers have dedicated
test classes with over 30 test methods total.

For integration testing, we use TestContainers with a real
PostgreSQL 16 database — because H2 cannot handle PostgreSQL-
specific types like text arrays and JSONB that our auth entities
use.

End-to-end testing uses Playwright against our production
deployment. 14 tests pass covering login, users CRUD, auth flow
builder, and multi-step authentication.

A key innovation in our E2E tests is the auth setup pattern.
We login once and save the session, then inject it into all
subsequent tests. This eliminates rate limiting issues that
caused failures when each test file logged in independently.
```

---

## SLIDE 15: Challenges (45 sec)

```
We encountered and solved several significant challenges.

The H2 database limitation was the most impactful — our auth
entities use PostgreSQL-specific column types that H2 cannot
handle. TestContainers solved this by spinning up a real
PostgreSQL instance for each test run.

Rate limiting in end-to-end tests was tricky — our production
API limits login attempts, and multiple test files each logging
in caused 429 errors. The auth setup pattern fixed this elegantly.

The 4GB VRAM constraint on our GPU required careful model
selection. GhostFaceNet and RetinaFace are lightweight enough
to run face verification in 200 milliseconds while staying
under 2GB GPU memory.

Virtual camera injection is a real threat for browser-based
face verification. Our mitigation is multi-factor authentication —
even if someone bypasses face detection, they still need
password or OTP verification.
```

---

## SLIDE 16: Lessons Learned (40 sec)

```
Several key lessons emerged from this project.

Hexagonal architecture truly pays off. When we added Twilio SMS
integration, we wrote one new adapter class with zero changes
to the domain layer.

The strategy pattern for auth handlers was the right choice.
Adding a new authentication method is one class and one enum value.

Browser-side machine learning is viable for production use.
MediaPipe runs face detection at 30 frames per second entirely
in the browser.

And multi-tenant design must be done from day one. Retrofitting
tenant isolation after the fact would have been extremely costly.
```

---

## SLIDE 17: Future Work (40 sec)

```
Looking ahead, several enhancements are planned.

High priority items include full Cloudflare Tunnel deployment
for the biometric processor and mobile app integration testing.

Medium priority includes activating the Twilio SMS gateway in
production and adding TOTP enrollment with QR codes in the
dashboard.

For longer term, we want real-time admin notifications via
Server-Sent Events, advanced analytics with trend charts,
and full WebAuthn CBOR attestation for hardware keys.

The project currently stands at approximately 98 percent
complete, with over 400 source files, 76 endpoints, 9 ML models,
10 auth methods, and 522 tests.
```

---

## SLIDE 18: Thank You & Q&A (25 sec)

```
Thank you for your attention.

FIVUCSAS is a live, deployed system. You can access the web
dashboard, API documentation, and landing page at the URLs
shown on screen.

We are happy to answer any questions.
```
