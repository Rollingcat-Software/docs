# FIVUCSAS — System Architecture & Deployment Diagrams

> All diagrams below reflect the **real** deployed system (verified against the parent
> `CLAUDE.md`, `identity-core-api/CLAUDE.md`, `infra/traefik/config/*.yml`, the prod
> compose files, and the actual Java/Python package trees on `HEAD`, 2026-06-02).
>
> **Honesty notes that shaped these diagrams:**
> - **Tenant isolation is application-layer**, not Postgres RLS — it is a Hibernate
>   `@Filter(tenantFilter)` (`@FilterDef` on `User` + 8 tenant-scoped entities) plus a
>   controller-level `TenantScopeResolver`. There is **no Postgres Row-Level Security**.
> - **GPU-less.** The Hetzner CX43 is CPU-only; `ALLOW_HEAVY_ML=false` (default) hard-blocks
>   GPU-class models (RetinaFace, YOLOv8/11/12, ArcFace, VGG-Face, GhostFaceNet) at boot.
> - **Object storage is NOT MinIO.** The biometric-processor persists uploads via
>   `LocalFileStorage` onto the `biometric_uploads` Docker volume. (`FileStorage` is a
>   port, so S3/MinIO is *possible*, but the only shipped adapter is local-FS.) The
>   diagrams show the real local-volume store.
> - **DB image** is pinned `pgvector/pgvector:pg16` in compose; the docs text says
>   "PostgreSQL 17 + pgvector". Diagrams label it "PostgreSQL + pgvector" to avoid asserting
>   a version the compose file contradicts.
> - **Flyway migrations are at V76** in `identity-core-api/CLAUDE.md` (the brief said "V79";
>   the *parent* roadmap references V79 — the API repo's own migration ledger documents
>   through V76, with V73–V76 applied on the 2026-05-31 rebuild). Labeled as such.
> - The **biometric-processor has no public route** — it is reachable only on the internal
>   Docker `backend` network, on port 8001, behind an `X-API-Key`.

---

## 1. System Context + Container Diagram

How the clients, the edge, the two backend services, and the data/3rd-party dependencies
fit together. The biometric processor is internal-only (Docker network + `X-API-Key`); the
two external comms providers (Twilio SMS, Hostinger SMTP) are called only by the Spring API.

```mermaid
C4Container
    title FIVUCSAS — Container Diagram (real deployment)

    Person(enduser, "End User", "Logs in / enrolls biometrics via browser or mobile")
    Person(tenantdev, "Tenant Developer", "Integrates via hosted OIDC + SDK")

    System_Boundary(clients, "Clients") {
        Container(web, "Web Dashboard", "React 18 + TS + Vite", "app.fivucsas.com — admin & self-service (Hostinger static)")
        Container(verify, "Hosted Login + Auth Widget", "React build + nginx", "verify.fivucsas.com — OIDC universal login + step-up MFA iframe (Docker)")
        Container(mobile, "Mobile App", "Kotlin Multiplatform / Compose", "Android · iOS · Desktop — AppAuth OIDC")
        System_Ext(thirdparty, "Third-Party App", "Tenant relying party — redirective OIDC via FivucsasAuth SDK")
    }

    Container(traefik, "Traefik v3.6", "Reverse proxy", "TLS (Let's Encrypt), HTTP→HTTPS, routing, rate-limit, admin-IP allowlist")

    System_Boundary(backend, "Backend (Docker, Hetzner CX43)") {
        Container(api, "Identity Core API", "Spring Boot 3.4.7 / Java 21 :8080", "Auth, OAuth2/OIDC, MFA, RBAC, multi-tenancy (Hibernate @Filter), 29 controllers, hexagonal")
        Container(bio, "Biometric Processor", "FastAPI / Python 3.12 :8001 — INTERNAL ONLY, X-API-Key", "Face/voice embeddings, liveness, anti-spoof, NFC eMRTD passive-auth (CPU-only, ALLOW_HEAVY_ML=false)")
    }

    System_Boundary(data, "Data Stores (Docker volumes)") {
        ContainerDb(pg, "PostgreSQL + pgvector", "pgvector/pgvector:pg16", "Identity/tenant/audit tables + HNSW vector store for face & voice embeddings")
        ContainerDb(redis, "Redis 7", "redis:7-alpine", "OTP, MFA sessions, QR/approve-login, rate-limit, TOTP replay markers, ShedLock")
        ContainerDb(files, "Local File Storage", "biometric_uploads volume", "Uploaded images/audio — LocalFileStorage adapter (NOT MinIO)")
    }

    System_Ext(twilio, "Twilio", "SMS OTP + Verify")
    System_Ext(smtp, "Hostinger SMTP", "smtp.hostinger.com:587 — email OTP, guest invites")

    Rel(enduser, web, "Uses", "HTTPS")
    Rel(enduser, verify, "Logs in", "HTTPS")
    Rel(enduser, mobile, "Uses")
    Rel(tenantdev, thirdparty, "Builds")

    Rel(web, traefik, "REST /api/v1", "HTTPS")
    Rel(verify, traefik, "REST + OAuth2", "HTTPS")
    Rel(mobile, traefik, "OIDC + REST", "HTTPS")
    Rel(thirdparty, traefik, "OIDC redirect + /oauth2/token", "HTTPS")

    Rel(traefik, api, "Routes api.fivucsas.com + verify origin", "HTTP :8080")
    Rel(api, bio, "Biometric ops", "HTTP :8001 + X-API-Key")

    Rel(api, pg, "JDBC / JPA")
    Rel(api, redis, "Lettuce")
    Rel(bio, pg, "asyncpg — embeddings (pgvector)")
    Rel(bio, files, "Read/write uploads")

    Rel(api, twilio, "Send SMS", "HTTPS API")
    Rel(api, smtp, "Send email", "SMTP/TLS")
```

---

## 2. Deployment & Domain Map

Every public domain and **how it is served**. The hard split is **Hostinger static hosting**
(landing, dashboard, BYS demo, amispoof, links) vs **Docker-behind-Traefik** (API, hosted
login, docs). `api.fivucsas.com` has path-specific behavior: root is `401` by design,
Swagger/actuator/`api-docs` are admin-IP-gated (`403` for the public), OIDC discovery is
public (`200`).

```mermaid
flowchart TB
    subgraph clients["Clients"]
        U["Browsers / Mobile / 3rd-party RPs"]
    end

    U -->|HTTPS| DNS{{"DNS · *.fivucsas.com"}}

    subgraph hostinger["HOSTINGER — static hosting (SFTP deploy, NOT Docker)"]
        direction TB
        H1["fivucsas.com<br/>Landing site"]
        H2["app.fivucsas.com<br/>React Dashboard (dist/)"]
        H3["demo.fivucsas.com<br/>BYS Demo (static HTML)"]
        H4["amispoof.fivucsas.com<br/>Browser anti-spoof tester (TS bundle)"]
        H5["links.fivucsas.com<br/>Hub (single index.html)"]
    end

    subgraph hetzner["HETZNER CX43 — Docker + Traefik v3.6 (TLS / routing)"]
        direction TB
        TR["Traefik<br/>:80 → 301 :443 · Let's Encrypt"]

        subgraph dockersites["Docker containers via Traefik"]
            D1["verify.fivucsas.com<br/>Hosted login + Auth widget<br/>(React build → nginx, framable)"]
            D2["docs.fivucsas.com<br/>fivucsas-docs container"]
            D3["status.fivucsas.com<br/>Uptime-Kuma"]
        end

        subgraph apinode["api.fivucsas.com (Spring :8080)"]
            A0["/ root → 401 (API origin, by design)"]
            A1["/oauth2/** · /auth/** · /api/v1/** → public (docker-label router)"]
            A2["/swagger-ui · /v3/api-docs · /actuator → 403 unless admin-IP<br/>(admin-whitelist@file)"]
            A3["/.well-known/openid-configuration → 200 public"]
        end

        TR --> D1
        TR --> D2
        TR --> D3
        TR --> apinode
    end

    DNS --> hostinger
    DNS --> TR

    subgraph redirects["301 Redirects (Traefik file-provider)"]
        R1["fivucsas.com.tr / .online / .info / www → fivucsas.com"]
        R2["rollingcatsoftware.com → fivucsas.com"]
        R3["ica-fivucsas.rollingcatsoftware.com → api.fivucsas.com"]
        R4["bys-demo.rollingcatsoftware.com → demo.fivucsas.com"]
    end
    TR -.->|"redirectRegex"| redirects

    classDef host fill:#fde68a,stroke:#b45309,color:#1f2937;
    classDef dock fill:#bfdbfe,stroke:#1d4ed8,color:#1f2937;
    classDef api fill:#bbf7d0,stroke:#15803d,color:#1f2937;
    class H1,H2,H3,H4,H5 host;
    class D1,D2,D3,TR dock;
    class A0,A1,A2,A3 api;
```

---

## 3. Hexagonal (Ports & Adapters) Architecture

Both services follow ports-and-adapters. **Left = driving (inbound) adapters → application
use-cases → domain; right = output ports realized by infrastructure adapters.** Names below
are the *actual* classes/dirs from the source trees.

### 3a. Identity Core API (Spring Boot / Java 21)

```mermaid
flowchart LR
    subgraph driving["Driving Side — controller/ (29 REST controllers)"]
        C1["AuthController · OAuth2Controller<br/>OpenIDConfigController · NfcController"]
        C2["WebAuthn · ApproveLogin · Qr<br/>Tenant · User · Role · Enrollment ..."]
    end

    subgraph app["application/"]
        UC["service/ + service/handler (10 auth-method handlers)<br/>service/mfa · service/nfc · service/verification"]
        PIN["port/input (use-case interfaces)"]
        POUT["port/output (output ports)"]
    end

    subgraph domain["domain/ (pure)"]
        DM["model: user · tenant · role · permission · auth<br/>NfcSerial · AuditAction · PkceFailureReason"]
        DR["repository (domain repo contracts)<br/>exception"]
    end

    subgraph infra["infrastructure/ (driven adapters)"]
        direction TB
        IA["adapter/ — *RepositoryAdapter (JPA)<br/>BiometricServiceAdapter · BiometricProcessorClient"]
        IMT["multitenancy/ — Hibernate @Filter(tenantFilter)<br/>TenantContext · TenantFilterBypass"]
        IO["oauth2 · webauthn · totp · otp · sms<br/>qrcode · approvelogin · stepup · email"]
        IPERS["persistence · audit · ratelimit · messaging · health"]
    end

    subgraph ext["External / Driven Systems"]
        PG[("PostgreSQL + pgvector")]
        RD[("Redis 7")]
        BIOX["Biometric Processor :8001 (X-API-Key)"]
        TW["Twilio"]
        SM["SMTP"]
    end

    C1 --> PIN
    C2 --> PIN
    PIN --> UC
    UC --> DM
    UC --> DR
    UC --> POUT
    POUT -. implemented by .-> IA
    POUT -. implemented by .-> IO
    POUT -. implemented by .-> IPERS
    IA --> IMT
    IA --> PG
    IPERS --> RD
    IA --> BIOX
    IO --> TW
    IO --> SM

    classDef d fill:#e9d5ff,stroke:#7c3aed,color:#1f2937;
    classDef a fill:#bbf7d0,stroke:#15803d,color:#1f2937;
    classDef i fill:#bfdbfe,stroke:#1d4ed8,color:#1f2937;
    class C1,C2 d;
    class UC,PIN,POUT,DM,DR a;
    class IA,IMT,IO,IPERS i;
```

### 3b. Biometric Processor (FastAPI / Python 3.12)

```mermaid
flowchart LR
    subgraph driving["Driving Side — api/routes/ (FastAPI, X-API-Key)"]
        R1["verification · enrollment · search<br/>liveness · live_analysis · quality"]
        R2["nfc · landmarks · multi_face · voice<br/>comparison · puzzle · proctor(_ws) · demographics"]
    end

    subgraph app["application/"]
        UCASE["use_cases/ — verify_face · enroll_face<br/>check_liveness · search_face · detect_card_type<br/>compare_faces · live_camera_analysis ..."]
        ASVC["services/ — active_liveness_manager<br/>flash_spoof_analyzer · occlusion_detector ..."]
    end

    subgraph domain["domain/ (pure)"]
        DENT["entities/ — face_embedding · liveness_report<br/>quality_assessment · proctor_session ..."]
        DIF["interfaces/ (PORTS) — embedding_extractor<br/>face_detector · liveness_detector · quality_assessor<br/>card_type_detector · embedding_repository · file_storage"]
        DSVC["services/ — emrtd_passive_auth · mrz_parser<br/>document_ocr · embedding_fusion"]
    end

    subgraph infra["infrastructure/ (driven adapters)"]
        ML["ml/ — detectors · extractors · landmarks<br/>liveness · quality · similarity · voice · card_type"]
        PERS["persistence/ — embedding_repository (pgvector, asyncpg)<br/>client_embedding_observation_repo"]
        STORE["storage/ — LocalFileStorage"]
        AUX["cache · auth (X-API-Key) · rate_limit · audit · webhooks"]
    end

    subgraph models["ML Models (CPU-only · ALLOW_HEAVY_ML=false)"]
        M1["DeepFace → Facenet512 (512-dim)"]
        M2["MTCNN (server detect) · MediaPipe FaceLandmarker"]
        M3["MiniFASNet v2 ONNX · UniFace passive liveness"]
        M4["Resemblyzer GE2E (256-dim voice)"]
    end

    R1 --> UCASE
    R2 --> UCASE
    R2 --> ASVC
    UCASE --> DENT
    UCASE --> DIF
    UCASE --> DSVC
    ASVC --> DIF
    DIF -. implemented by .-> ML
    DIF -. implemented by .-> PERS
    DIF -. implemented by .-> STORE
    ML --> M1
    ML --> M2
    ML --> M3
    ML --> M4
    PERS --> PGV[("PostgreSQL pgvector<br/>HNSW")]
    STORE --> VOL[("biometric_uploads volume")]

    classDef d fill:#e9d5ff,stroke:#7c3aed,color:#1f2937;
    classDef a fill:#bbf7d0,stroke:#15803d,color:#1f2937;
    classDef i fill:#bfdbfe,stroke:#1d4ed8,color:#1f2937;
    classDef m fill:#fecaca,stroke:#b91c1c,color:#1f2937;
    class R1,R2 d;
    class UCASE,ASVC,DENT,DIF,DSVC a;
    class ML,PERS,STORE,AUX i;
    class M1,M2,M3,M4 m;
```

---

## 4. Tech-Stack Layered Diagram

Top-to-bottom layers, each labeled with the concrete technologies in production, plus the
standards the platform implements. CPU-only ML is called out explicitly.

```mermaid
flowchart TB
    subgraph L1["① Frontend / Clients"]
        F["React 18 · TypeScript · Vite · InversifyJS DI · i18n (EN/TR)<br/>Kotlin Multiplatform / Compose (Android · iOS · Desktop) · AppAuth"]
    end

    subgraph L2["② Edge"]
        E["Traefik v3.6 — TLS (Let's Encrypt) · HTTP→HTTPS · routing<br/>rate-limit · secure-headers · admin-IP allowlist · nginx (verify/docs static)"]
    end

    subgraph L3["③ Backend Services"]
        B1["Identity Core API — Spring Boot 3.4.7 / Java 21 (:8080, Maven)<br/>Hexagonal · Hibernate @Filter multi-tenancy · Flyway V1–V76"]
        B2["Biometric Processor — FastAPI / Python 3.12 (:8001, internal, X-API-Key)<br/>Clean architecture · Pydantic · async · Alembic 0001–0005"]
    end

    subgraph L4["④ ML / Biometrics (CPU-only · ALLOW_HEAVY_ML=false)"]
        M["DeepFace → Facenet512 (512-dim) · MTCNN detect · MediaPipe FaceLandmarker (478pt)<br/>MiniFASNet v2 ONNX + UniFace passive liveness · Resemblyzer GE2E voice (256-dim)<br/>eMRTD passive-auth (EF.SOD → DS → CSCA, ICAO 9303)"]
    end

    subgraph L5["⑤ Data"]
        D["PostgreSQL + pgvector (pgvector/pgvector:pg16) — HNSW face & voice vectors<br/>Redis 7 (redis:7-alpine) — OTP / MFA sessions / rate-limit / ShedLock<br/>LocalFileStorage volume (biometric_uploads) — uploads (NOT MinIO)"]
    end

    subgraph L6["⑥ Infrastructure / Ops"]
        I["Docker + Compose · Hetzner CX43 (8 vCPU / 16 GB / CPU-only)<br/>GitHub Actions CI (ubuntu-latest + self-hosted hetzner-cx43 runner)<br/>Prometheus + Grafana · Uptime-Kuma · Hostinger SFTP (static sites)"]
    end

    subgraph L7["⑦ Standards & Protocols"]
        S["OAuth 2.0 / OIDC · PKCE (S256) · JWT RS256 · JWKS + discovery<br/>FIDO2 / WebAuthn (discoverable passkeys) · RFC 8176 amr · RFC 8252 native-app<br/>ICAO 9303 eMRTD · KVKK / GDPR (export + purge)"]
    end

    L1 --> L2 --> L3
    L3 --> L4
    L3 --> L5
    L3 -.runs on.-> L6
    L3 -.implements.-> L7

    classDef l1 fill:#e9d5ff,stroke:#7c3aed,color:#1f2937;
    classDef l2 fill:#fde68a,stroke:#b45309,color:#1f2937;
    classDef l3 fill:#bbf7d0,stroke:#15803d,color:#1f2937;
    classDef l4 fill:#fecaca,stroke:#b91c1c,color:#1f2937;
    classDef l5 fill:#bfdbfe,stroke:#1d4ed8,color:#1f2937;
    classDef l6 fill:#cbd5e1,stroke:#475569,color:#1f2937;
    classDef l7 fill:#fbcfe8,stroke:#be185d,color:#1f2937;
    class F l1;
    class E l2;
    class B1,B2 l3;
    class M l4;
    class D l5;
    class I l6;
    class S l7;
```
