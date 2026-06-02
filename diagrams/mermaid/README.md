# FIVUCSAS — Architecture & Flow Diagrams (Mermaid)

GitHub-renderable Mermaid diagrams of the whole platform, generated and **verified against the real source code** (not stock boilerplate). 33 diagrams across 4 files.

| File | Diagrams |
|------|----------|
| [01 — Architecture & Deployment](01-architecture-deployment.md) | System context + container (C4), the public-domain/deployment map (Docker-vs-Hostinger, Traefik routing), hexagonal ports & adapters (api + bio), tech-stack layers |
| [02 — Auth · OAuth2 · OIDC · MFA](02-auth-oauth-mfa.md) | The "Login with FIVUCSAS" OIDC round-trip (hero), the N-step MFA engine + session state, Email/SMS/TOTP OTP, QR + approve-login, WebAuthn/passkey, refresh-token rotation + reuse-revocation, account lockout, overall login activity |
| [03 — Biometric Pipelines](03-biometric-pipelines.md) | Face enroll + verify, voice, NFC two rails + passive-auth, liveness (passive + 23-puzzle active), spoof-detector session verdict, fingerprint→WebAuthn |
| [04 — Data Model · Use-Cases · RBAC](04-data-model-usecase-rbac.md) | ER diagrams (identity/tenancy/RBAC + auth/enrollment), domain class diagram, use-case diagram (5 actors), the two-axis RBAC model |

**Accuracy notes baked in:** tenant isolation is application-layer Hibernate `@Filter` (not Postgres RLS); file storage is `LocalFileStorage` (not MinIO); DB is `pgvector/pgvector:pg16`; the stack is GPU-less (`ALLOW_HEAVY_ML=false`); embeddings are Facenet-512 (face) / Resemblyzer 256-dim (voice); PKCE S256 is mandatory for public clients; tokens are RS256 with pinned `iss`/`aud`.

> Rendered natively by GitHub. To view inline, open any file above.
