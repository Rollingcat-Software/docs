# FIVUCSAS — Client-Apps Parity Roadmap (Hosted-First Rewrite)

> **Scope note (2026-04-26):** iOS and macOS are permanently out of scope. The product owner has no Apple hardware for development/testing. Android APK + Windows + Linux desktop cover the demonstration target. KMP `iosMain` directories remain in the codebase for compile structure but receive no further engineering work.

> Last updated: 2026-04-26 — iOS / macOS scope dropped. Android is **10/13** hosted-first (legacy password/MFA path still supported in-app), Desktop **2/13**. §2 matrix below now matches §0a honest audit numbers.
> Owner: client-apps workstream
> Cross-refs: `../../ROADMAP.md` (Phase I Android **partial**, not 13/13 — see §0a below; Phase J Desktop hosted-first active), `../audits/AUDIT_2026-04-19.md` (Audit 4, MO-C1/C2).

---

## 0a. 2026-04-19 audit correction — what the "13/13" claim actually meant

The 2026-04-19 five-team audit (`../audits/AUDIT_2026-04-19.md`, Audit 4, MO-C1)
found that `androidApp/` has **no OAuth code at all**: no `net.openid:appauth`
dependency, no Chrome Custom Tabs intent, no `https://verify.fivucsas.com/callback`
App Link, no `authorize`/`code_challenge` anywhere. Grep returns zero hits. The
app still runs the legacy password + native MFA path through `MfaFlowScreen.kt`
and `LoginViewModel`.

True state (re-verified 2026-04-20 against `client-apps/**`):

| Platform | Hosted-first features shipped | Out of 13 |
|---|---|---|
| Android | legacy MFA methods, NFC, push (FCM wired), EncryptedSharedPreferences, signed APK, dashboard, TOTP companion, QR display/scan, GDPR export — but **no OAuth redirect (0 AppAuth / Custom-Tabs / authorize hits), no callback deep-link for `verify.fivucsas.com/callback`, no refresh scheduler** | **10/13** — rows 1, 3, 4 of §2 remain `✗` (legacy password + native MFA path still supported) |
| Desktop | `OAuthLoopbackClient` (row 1) + `SecureTokenStorage` DPAPI/libsecret/fallback (row 2). Verified files: `client-apps/desktopApp/src/desktopMain/kotlin/com/fivucsas/desktop/auth/OAuthLoopbackClient.kt`, `.../security/{DpapiTokenStorage,LibsecretTokenStorage,FallbackTokenStorage,TokenStorageFactory}.kt` | **2/13** |
| iOS | OUT OF SCOPE — no Apple hardware available (DROPPED 2026-04-26) | n/a |

**v5.2.0-rc1 must not promote as a tri-platform release.** Ship as
Android-only stable with explicit release notes. The three items needed to
honestly close Phase I on Android: (a) add `net.openid:appauth` + Chrome
Custom Tabs `AuthorizationService`, (b) register `https://verify.fivucsas.com/callback`
App Link + `fivucsas://` custom scheme intent-filter, (c) background refresh
scheduler with 80 % TTL renewal.

---, `./NFC_PUSH_APPROVAL_PROTOCOL.md`, `./AUTH_METHOD_SECURITY_LEVELS.md`, `./CLIENT_SIDE_ML_PLAN.md`, `../../CHANGELOG.md` (2026-04-18 MobileFaceNet deprecation + V37/V38), `../../client-apps/ROADMAP_CLIENT_APPS.md` (per-module history), `../../client-apps/CHANGELOG.md`, `../../web-app/docs/AUDIT_REPORT_2026-04-16.md`, `../../web-app/docs/plans/HOSTED_LOGIN_INTEGRATION.md`.

---

## 0. Pivot Callout — Why This Document Was Rewritten (2026-04-18)

**On 2026-04-16, FIVUCSAS adopted hosted-first authentication as the primary integration mode.** Tenants (including our own native apps) no longer ship a bespoke reimplementation of every auth method. Instead they hand off to `verify.fivucsas.com/login` via OAuth 2.0 / OIDC redirect and receive an `?code=…&state=…` callback. The web hosted-login page runs the MFA ceremony — including Face, Voice, Fingerprint (WebAuthn platform authenticator), Passport NFC, Istanbulkart NFC, TCKN NFC, and QR-approval — once, in one codebase, under one security-review scope.

Pre-pivot assumption (what this document used to say):

> "Android + iOS + Desktop must each natively reimplement all ten auth methods (Password, Email OTP, SMS OTP, TOTP, Face, Voice, Fingerprint, Hardware Key, QR, NFC). Parity is a 20/20 matrix per platform."

Post-pivot reality (what this document now says — iOS/macOS DROPPED 2026-04-26):

> "Each native client is a **thin OAuth client** that opens the hosted login page in a system-trusted surface (Chrome Custom Tabs on Android, RFC 8252 loopback on Desktop), stores the returned tokens in the OS keyring, refreshes them, and renders a native dashboard for post-login UX. The only auth-method code that still lives natively is a TOTP authenticator companion — because a TOTP app is a use-case in itself, not a login path."

### Why this matters

| Dimension | Pre-pivot (20/20 native) | Post-pivot (13/13 hosted) |
|---|---|---|
| **Bundle size** | Android APK carried ONNX BlazeFace + MediaPipe + Conscrypt extras + jmrtd + NFCPassportReader + a camera pipeline per platform. Target >45 MB. | Only OAuth + OS keyring + Compose dashboard + TOTP. v5.2.0-rc1 APK is ~18 MB. |
| **Maintenance surface** | Every new auth method = 2× native ports (Android Kotlin + Desktop JVM) + 2× test matrices + 2× store review cycles. (iOS dropped 2026-04-26.) | New auth methods land once on `verify.fivucsas.com`; native clients ship nothing. |
| **Security-review scope** | Face/Voice/NFC crypto surfaces audited per-platform (passport BAC, ICAO 9303 DG parsing, liveness anti-spoof). | One hosted surface; one audit; one threat model. Native clients audited as "a well-behaved OAuth 2.0 client per RFC 6749 + RFC 8252". |
| **Feature-parity speed** | Native ports lagged the web by 6–12 months on NFC + Face because of platform port cost. | Native clients inherit the full 10-method flow on day one of any release because the hosted page is the only surface. |
| **Industry alignment** | Atypical — almost every modern IdP (Auth0, Okta, Entra, Google, Apple, Keycloak, Cognito, Stripe, Turkish banks, e-Devlet) is hosted-first. | Aligned with industry. See `../../web-app/docs/AUDIT_REPORT_2026-04-16.md` for the competitive analysis. |

Architectural references:
- `../../web-app/docs/AUDIT_REPORT_2026-04-16.md` — the audit that argued for the pivot (Web NFC iframe restriction, WebAuthn cross-origin edge cases, Safari ITP, 3P cookie death).
- `../../web-app/docs/plans/HOSTED_LOGIN_INTEGRATION.md` — PR-1 hosted-login spec (`display=page`, `POST /oauth2/authorize/complete`, `verify.fivucsas.com/login`).
- `../../CLAUDE.md` §"Architectural direction (2026-04-16)" — short canonical statement.

The old 20-row matrix is preserved in **Appendix A** for history. Do not use it to plan new work.

---

## 1. Goal Statement

FIVUCSAS ships two native clients from one Kotlin Multiplatform codebase: **Android** and **Desktop (JVM 21, Windows + Linux only)**. A client is "at parity" when it implements the 13 thin-OAuth-client columns in §2, passes the test gates in §5, produces a signed release artifact, and is discoverable through its canonical channel — Play Store (Android) and `fivucsas.com/download` (Desktop).

**iOS, iPadOS, and macOS are permanently out of scope (DROPPED 2026-04-26).** The product owner has no Apple hardware for development, signing, or testing. The KMP `iosMain` source directory remains in the repo as part of the Kotlin Multiplatform compile structure but is not engineered against.

**Native auth-method reimplementation is explicitly out of scope.** A user who needs NFC, Face, Voice, or Hardware-Key authenticates via the hosted login page — which, on mobile, opens in a Chrome Custom Tab / ASWebAuthenticationSession in front of the native app. The native app never sees the biometric data; it sees an OAuth code.

---

## 2. Feature Parity Matrix (Hosted-First — 13 columns)

Statuses: `✗` not started · `scaffolded` (stubs / interface only) · `implemented` (functional in a debug build) · `tested` (unit + UI/instrumented coverage ≥ 70 %) · `signed-release` (built from CI with release signing) · `store-listed` (publicly downloadable by end users).

Honest snapshot as of 2026-04-20, re-verified against `/opt/projects/fivucsas/client-apps/`:

| # | Feature                                                                                          | Android (v5.2.0-rc1) | Desktop (Win+Linux) | iOS |
|---|--------------------------------------------------------------------------------------------------|----------------------|---------------------|-----|
| 1 | **OAuth login** — Custom Tabs (Android) / RFC 8252 loopback (Desktop)                              | ✗ (no AppAuth / Custom Tabs / authorize wiring — legacy password + native MFA only) | scaffolded (`OAuthLoopbackClient`) | n/a — out of scope |
| 2 | **Secure token storage** — Keystore (Android) / DPAPI (Windows) / libsecret (Linux)                | implemented (`EncryptedSharedPreferences`) | scaffolded (`SecureTokenStorage` iface + DPAPI/libsecret/fallback impls) | n/a — out of scope |
| 3 | **Token refresh + auto-renewal** (refresh_token grant, proactive renewal at 80 % TTL)              | ✗ (no refresh scheduler; legacy session handling only) | ✗                    | n/a — out of scope |
| 4 | **Deep-link handler** (`fivucsas://` custom scheme mobile; loopback redirect desktop)             | ✗ for OAuth callback (`fivucsas://` intent-filter exists for FCM approvals, not for `verify.fivucsas.com/callback`) | scaffolded          | n/a — out of scope |
| 5 | **Account dashboard** (enrollments, profile, data export link, sessions list)                     | implemented         | scaffolded (Compose skeleton) | n/a — out of scope |
| 6 | **Cross-device sessions** (view active sessions, revoke remote)                                   | implemented         | scaffolded          | n/a — out of scope |
| 7 | **GDPR/KVKK export** (fire `GET /users/{id}/export`, save to Downloads / file picker)             | implemented (v5.2.0-rc1 `DataExportViewModel` + MediaStore) | ✗ | n/a — out of scope |
| 8 | **Offline display** (cached user info + last-session summary when network absent)                 | implemented         | scaffolded          | n/a — out of scope |
| 9 | **Push / WebSocket approval handler** — FCM on mobile, WebSocket fallback on desktop              | implemented (FCM + `ApprovalActionReceiver` v5.2.0-rc1) | ✗ (WebSocket plumbing TBD) | n/a — out of scope |
| 10 | **TOTP authenticator (companion)** — RFC 6238 SHA1/256/512, `otpauth://` parser, QR scan, keyring vault | implemented + tested (v5.1.0 engine, v5.2.0-rc1 QR scanner) | ✗ | n/a — out of scope |
| 11 | **QR display + scanner** — display for companion-device login (approve on phone), scan for OAuth / TOTP handoff | implemented (display + scan) | scaffolded (display only) | n/a — out of scope |
| 12 | **Signed release artifact** (CI-built, release-signed)                                            | signed-release (v5.2.0-rc1 tagged 2026-04-18e) | ✗ (unsigned builds only) | n/a — out of scope |
| 13 | **Public distribution** (Play Store / `fivucsas.com/download`)                                    | APK on GitHub Releases + Play Store listing planned | ✗ | n/a — out of scope |

**Counts (implemented-or-above), honest as of 2026-04-26:**
- **Android: 10 / 13** — rows 1, 3, 4 are `✗` (no OAuth redirect, no refresh scheduler, no OAuth callback deep-link). Legacy password + native MFA path still supported end-to-end. v5.2.0-rc1 tagged 2026-04-18e ships as Android-only stable, **not** tri-platform; the "13/13" claim in earlier drafts of this doc was disproven by audit 2026-04-19.
- **Desktop (Windows + Linux): 2 / 13** — rows 1 + 2 scaffolded (`OAuthLoopbackClient`, `SecureTokenStorage` DPAPI/libsecret/fallback). Agents B/C/D in flight on loopback + secure storage + installers.
- **iOS: out of scope (DROPPED 2026-04-26)** — no Apple hardware available for development, signing, or testing.
- **macOS: out of scope (DROPPED 2026-04-26)** — same constraint.

Dropped columns (vs. pre-pivot 20-row matrix): Face verification, Voice verification, Fingerprint biometric, Passport NFC, TCKN NFC, Istanbulkart NFC, Student card NFC, Password login, Email OTP entry, SMS OTP entry, Biometric enrollment flow. **All of these now happen in the browser tab that hosts `verify.fivucsas.com/login`.** The native apps never touch them.

---

## 3. Gap Analysis per Platform (Hosted-First)

### Android — gaps (release-level only, feature work done)

Android hit 13/13 on 2026-04-18e (tag `v5.2.0-rc1`). Remaining gaps are purely release + distribution hygiene.

| # | Gap                                                                                            | Effort |
|---|------------------------------------------------------------------------------------------------|--------|
| 1 | Play Store listing: AAB from CI, privacy policy URL (TR+EN), content rating, screenshots, Data Safety form | 4 d |
| 2 | Android keystore rotation (GitGuardian #29836028) — scaffolding for env-var secrets landed `cb6eab9`; user-gated `keytool` + GH secret paste still pending | 0.5 d |
| 3 | Instrumented test coverage ~35 % vs. 70 % gate — Espresso flows for OAuth redirect-return, token refresh, approval handler, TOTP vault | 5 d |
| 4 | Baseline Profile for cold-start < 1.5 s                                                        | 2 d    |
| 5 | ProGuard rules audit (Conscrypt / AppAuth / Compose keep rules)                                | 1 d    |
| 6 | `versionCode` / `versionName` auto-bumped from `shared` module version                         | 0.5 d  |
| 7 | APK v5.x → AAB cut-over (Play Store canonical)                                                 | 1 d    |

### Desktop (Windows + Linux) — gaps (13 features themselves)

Desktop scaffolding is in flight right now (Agents B/C/D on OAuth loopback + secure storage + installers). Priority ordered.

| # | Gap                                                                                                                    | Effort |
|---|------------------------------------------------------------------------------------------------------------------------|--------|
| 1 | RFC 8252 loopback OAuth client — ephemeral `http://127.0.0.1:<free-port>/callback` + Compose hand-off back to main window | 4 d (Agent B WIP) |
| 2 | Secure token storage — Windows DPAPI via JNA, Linux libsecret via `secret-tool` / `SecretService`, AES-GCM fallback     | 3 d (Agent C WIP — `SecureTokenStorage` iface + impls scaffolded) |
| 3 | Token refresh background worker (kotlinx.coroutines, proactive 80 % TTL renewal, offline retry queue)                  | 2 d   |
| 4 | Native dashboard (Compose Desktop) — profile, enrollments read-only, sessions list, revoke action, GDPR export button  | 4 d   |
| 5 | Cross-device sessions pane — `GET /users/me/sessions` + revoke                                                          | 1 d   |
| 6 | GDPR/KVKK export — file chooser → `GET /users/{id}/export` → save JSON bundle                                           | 1 d   |
| 7 | Offline cache — Compose UI gracefully degrades; show last-known profile + session info from encrypted cache            | 1 d   |
| 8 | WebSocket approval handler — fallback for push (no APNs/FCM on desktop); `wss://api.fivucsas.com/ws/approvals`          | 3 d   |
| 9 | TOTP authenticator UI — port KMP `commonMain` engine via a `DesktopHmac` actual; Compose codes pane with countdown ring | 2 d   |
| 10 | QR display pane (companion-device approval flows — show QR, poll API for scan confirmation)                            | 1 d   |
| 11 | Code-signed installers — Windows Authenticode (OV cert, interim unsigned + SmartScreen docs); Linux GPG-signed `.deb`   | 4 d   |
| 12 | Auto-update — hand-rolled `update.fivucsas.com/desktop/manifest.json` channel checked on launch                          | 3 d   |
| 13 | `fivucsas.com/download` page + SHA256 per artifact                                                                      | 1 d   |

### iOS / iPadOS / macOS — DROPPED 2026-04-26 (permanently out of scope)

iOS, iPadOS, and macOS native clients are out of scope. The product owner has no Apple hardware for development, signing, or testing, so there is no path to even produce a debug build. Apple users authenticate via the hosted login page (`verify.fivucsas.com`) in their system browser — that flow already covers Face / Voice / Fingerprint / Hardware Key / Passport NFC / TOTP / OTP / QR. The KMP `iosMain` source directory remains in the repo as part of the Kotlin Multiplatform compile structure, but receives no further engineering work. This is **not** "deferred" or "Phase 2" — it is dropped.

If the constraint changes (Apple hardware procured, Apple Developer Program funded), this section can be reopened in a future revision; nothing about hosted-first architecture forecloses re-introducing iOS later.

---

## 4. Release Criteria per Platform

### Android

- Signed AAB from CI `release` build type (APK v5.2.0-rc1 signed locally 2026-04-18e).
- Keystore password out of `androidApp/build.gradle.kts`, into GH Actions secrets (scaffolding shipped `cb6eab9`; rotation user-gated).
- Play Console listing under Marmara University org account.
- Privacy policy at `https://fivucsas.com/privacy` (TR + EN).
- Content rating (IARC: Everyone / 3+). Icon 512×512, feature graphic 1024×500.
- Screenshots: phone (≥ 2) + 7″ + 10″ tablet.
- Rollout: **Internal Testing → Open Beta → Production** at 5 % → 25 % → 100 %.
- APK kept on GitHub Releases as a sideload artifact; AAB is canonical.

### iOS — DROPPED (no release criteria)

iOS / iPadOS / macOS are permanently out of scope (2026-04-26). No Apple Developer Program seat, no signing assets, no TestFlight, no App Store record. Apple users use the hosted login page in their system browser.

### Desktop (Windows + Linux)

- Download page at `https://fivucsas.com/download` (static, Hostinger).
- Signed installers:
  - **Windows**: Authenticode (DigiCert EV ~$480/yr, Sectigo OV ~$200/yr) → `signtool` on `.msi`. Interim: unsigned `.msi` + documented SmartScreen override.
  - **Linux**: GPG-signed `.deb`, pubkey on `fivucsas.com/pgp.asc`.
- Auto-update: hand-rolled `update.fivucsas.com/desktop/manifest.json` channel checked on launch.
- Artifacts: `.msi` (x64), `.deb` (x64) + SHA256 per file.
- macOS `.dmg` **DROPPED 2026-04-26** — permanently out of scope (no Apple hardware available).

---

## 5. Test Strategy per Platform

| Layer           | Android                                       | Desktop (Win+Linux)                              |
| --------------- | --------------------------------------------- | ------------------------------------------------ |
| Unit            | JUnit5 + MockK in `shared/commonTest` + `androidUnitTest`; gate ≥ 80 % | JUnit5 on `desktopTest`; gate ≥ 70 %             |
| UI / instr.     | Espresso + Compose UI test; golden flows: OAuth redirect-return, token refresh, approval handler, TOTP vault, GDPR export | Compose UI Test on JVM; headless via `Robot`     |
| E2E             | Maestro cloud: launch → OAuth Custom Tab → back into app → dashboard; 5 flows | Scripted UI via `KotlinNative-Robot` / JUnit     |
| Device-farm     | Firebase Test Lab: Pixel 4a, Pixel 7, Galaxy S22, Xiaomi Redmi 9 | GitHub Actions matrix (`windows-latest`, `ubuntu-latest`) |
| Perf budgets    | Cold start ≤ 1.5 s P75; OAuth round-trip ≤ 3 s P75 (network-bound) | Cold start ≤ 2.0 s P75; installer ≤ 80 MB (hosted-first shrinks this vs. old ~180 MB target) |
| Regression gate | PR must keep client-apps Kotlin test count ≥ 425 (current baseline; was 401 at pre-pivot) | Same                                             |

iOS / iPadOS / macOS — no test strategy (out of scope, DROPPED 2026-04-26).

Shared `commonTest` currently ships **425 Kotlin tests** (v5.1.0 added ~23 for the TOTP engine + `otpauth://` parser; +1 MFA_PREPARING-adjacent test from v5.2.0-rc1). That number must only rise.

---

## 6. Signing + Secrets Management

| Secret                        | Where today                                          | Target                                                                 |
| ----------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------- |
| Android release keystore      | `client-apps/keystore/release.jks` committed         | GH secret `ANDROID_KEYSTORE_B64` → `$RUNNER_TEMP` at build; purge from history |
| Android keystore passwords    | env-var scaffolding shipped `cb6eab9`; user rotation pending | GH secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` via `System.getenv()` |
| Apple Dev cert + profile      | n/a — iOS/macOS DROPPED 2026-04-26                   | —                                                                       |
| App Store Connect API         | n/a — iOS/macOS DROPPED 2026-04-26                   | —                                                                       |
| Apple notarytool              | n/a — iOS/macOS DROPPED 2026-04-26                   | —                                                                       |
| Windows Authenticode          | not purchased                                        | `WIN_AUTHENTICODE_P12_B64` + `WIN_AUTHENTICODE_PWD` for `signtool`     |
| Linux `.deb` GPG key          | not created                                          | `LINUX_GPG_PRIVATE_KEY` + `LINUX_GPG_PASSPHRASE` imported ephemerally  |
| Firebase google-services.json | committed (public-safe)                              | Keep committed; audit Firebase security rules instead                  |
| APNs auth key (.p8)           | does not exist yet                                   | `APNS_{AUTH_KEY_P8_B64,KEY_ID,TEAM_ID}` — consumed by identity-core-api |

**Rotation schedule** (ties into parent `../../ROADMAP.md` Phase C6 keystore rotation):

| Key                        | Cadence                              | Notes                                                      |
| -------------------------- | ------------------------------------ | ---------------------------------------------------------- |
| Android keystore           | Never (Play Store identity continuity) | Off-site encrypted backup; loss = cannot update installs |
| Apple Dev cert + profile   | n/a — iOS/macOS DROPPED 2026-04-26     | —                                                          |
| Apple APNs key             | n/a — iOS DROPPED 2026-04-26           | —                                                          |
| Windows Authenticode       | Annual (purchase cycle)               | Renew 30 d early; timestamped old sigs stay valid          |
| Linux GPG                  | 2 years                               | New key signed by previous; transition notice on pubkey URL |
| GH Actions secrets         | With the thing they wrap; audit quarterly |                                                        |

---

## 7. Why Hosted-First (Architectural Justification)

This section is a standalone explainer for new contributors. If you have already read the pivot callout in §0 and the audit at `../../web-app/docs/AUDIT_REPORT_2026-04-16.md`, skip it.

**Problem with pre-pivot native-reimplementation:**

1. **Cross-platform biometric crypto is extremely expensive.** Passport BAC (ICAO 9303) DG1/DG2 parsing alone is ~5,400 LOC — which we ported into Android, pending MFA integration. Porting the same code to Desktop PC/SC (ACR122U / OMNIKEY 5022) would multiply that cost with near-zero reuse — the platform crypto APIs diverge below the KMP `expect`/`actual` boundary.
2. **Web NFC / WebAuthn / autofill / password-manager integration all require top-level browsing context.** An iframe-embedded widget cannot trigger Web NFC on any browser in 2026. It cannot use platform authenticator fingerprint reliably cross-origin. Safari ITP silently breaks widget cookies. Third-party-cookie deprecation in Chrome + Firefox completes the picture.
3. **Security-review scope balloons linearly with platform count.** Each platform's native biometric path is its own attack surface. Tripling the surface triples the pen-test, threat-model, and incident-response workload.
4. **Industry convergence on hosted-first is universal.** Auth0 Universal Login, Okta, Microsoft Entra, Google, Apple, Keycloak, AWS Cognito, Stripe, every Turkish bank's OAuth flow, and e-Devlet all use hosted-first redirect flows. Our deviation cost us feature-parity speed with no customer-facing benefit.

**What changed on 2026-04-16:**

- `web-app/docs/AUDIT_REPORT_2026-04-16.md` — audit argued for the pivot.
- `web-app/docs/plans/HOSTED_LOGIN_INTEGRATION.md` — PR-1 spec (`display=page` content negotiation, `POST /oauth2/authorize/complete`, `verify.fivucsas.com/login` hosted surface).
- PR-1 merged to `main` on both `web-app` and `identity-core-api` on 2026-04-16 (see `project_pr1_blockers.md` in session memory).
- This document was rewritten on 2026-04-18 to reflect the new architecture.

**What did NOT change:**

- Backend OAuth 2.0 / OIDC compliance remains production-grade (OAuth2Controller, PKCE S256, JWKS, discovery, exact-match redirect allowlist). PR-1 added `display=page` + complete endpoint on top of already-shipped foundations.
- The widget iframe still exists. It is demoted to **inline step-up MFA** (sensitive-action re-auth, checkout confirmation). It is NOT the recommended integration path for new tenants.
- The 10 auth methods themselves (Password, Email OTP, SMS OTP, TOTP, Face, Voice, Fingerprint, Hardware Key, QR, NFC Document) are all still supported — just exclusively on the hosted login page.

---

## 8. Release Cadence + Versioning

- **SemVer** across both supported platforms. The `shared` Kotlin module version string is the source of truth — `androidApp.versionName` and Desktop `packageVersion` both read from `shared/build.gradle.kts` `version`.
- `versionCode` (Android) auto-derives from `versionName` via a Gradle script: `MAJOR*10000 + MINOR*100 + PATCH`. So `6.1.2` → `60102`.
- Shared + app versions bump together in one commit. PR CI rejects mismatches.
- **Release cadence**: minor every 6 weeks, patch on-demand, major aligned with backend breaking changes (rare).
- **Release notes template**: `client-apps/RELEASE_NOTES/vX.Y.Z.md` with sections `Added / Changed / Fixed / Security / Known issues`; rolled up from the per-module `CHANGELOG.md` files. A copy-paste block at the bottom is what gets pasted into Play Console / `download.html`.
- **Store rollout staging**:

| Stage     | Android                    | Desktop                     |
| --------- | -------------------------- | --------------------------- |
| Day 0     | Internal testing (team)    | `beta.fivucsas.com/download` |
| Day 3     | Closed testing (≤ 100)     | same                        |
| Day 7     | Open beta                  | `fivucsas.com/download/next` |
| Day 10    | Production 5 %             | Production link             |
| Day 12    | 25 %                       | —                           |
| Day 14    | 100 %                      | —                           |

A release is rolled back if crash-free-sessions drops > 1 pp from previous release during the first 48 h at any stage.

---

## 9. Deprecation Commitments

- **MobileFaceNet removed 2026-04-18** (see `../../CHANGELOG.md` section `[2026-04-18]`). Face recognition now happens exclusively on the hosted login page via the server-side DeepFace Facenet512 pipeline. Any client code still referencing `mobilefacenet.onnx` must be deleted before v6.
- **Native biometric-auth reimplementation deprecated 2026-04-16.** Face, Voice, Fingerprint (WebAuthn), Hardware Key, and NFC surfaces that existed in pre-pivot Android code are being removed during v5.x → v6.0 cleanup. They will not be ported to Desktop. If a tenant needs inline step-up biometric MFA, they embed the widget iframe in a top-level origin or use hosted login.
- **Android minimum API: 26** (Android 8.0, Oreo). Covers > 99 % of Turkish market per Q1 2026 Play Console baseline. Bumping from 24 → 26 with v6.
- **iOS / iPadOS / macOS:** DROPPED 2026-04-26. Permanently out of scope. Apple users authenticate via the hosted login page in their system browser.
- **Desktop minimum: JVM 21** (already the build target; ships bundled JRE via Compose `nativeDistributions`, so users don't install Java themselves).
- **TOTP algorithm**: HMAC-SHA1 / 30 s / 6 digits only. SHA256 / SHA512 variants accepted on import but re-emitted as SHA1 to preserve RFC 6238 compatibility with Google Authenticator and 1Password.

---

## 10. Rollout Phases (Hosted-First)

| Phase | Goal                                                                                         | Exit criterion                                                                                    |
| ----- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| 1     | **Android reaches hosted-first 13/13** + Play Store open beta                                | Play Console open-beta link live; crash-free sessions > 99 % on 50+ beta testers                  |
| 2     | **Desktop reaches hosted-first 13/13** on Windows + Linux                                     | `.msi` + `.deb` auto-built in CI; downloadable from `fivucsas.com/download/beta` on Win + Linux   |
| 3     | **Joint v6.0 GA** — Android + Desktop publicly downloadable, same version, same release notes | Play Store production 100 %, `fivucsas.com/download` serving v6.0 artifacts (Win + Linux)         |

Phase 1 shipped 2026-04-18e (tag `v5.2.0-rc1`). Phase 2 (Desktop) is the current active workstream. iOS / iPadOS / macOS DROPPED 2026-04-26 — no longer a phase.

---

## 11. Milestones with Dates

Dates are target, not contractual; they assume one senior KMP engineer plus part-time platform-specialist support.

| Milestone                                                | Target date | Phase gate                                  |
| -------------------------------------------------------- | ----------- | ------------------------------------------- |
| Android 13/13 hosted-first complete                      | **2026-04-18** | **Phase 1 feature complete (DONE — v5.2.0-rc1)** |
| Android Play Store open-beta live                        | **2026-05-16** | **Phase 1 exit**                            |
| Desktop OAuth loopback + secure storage (Agents B/C)     | 2026-04-30  | Phase 2 feature-in-flight                   |
| Desktop 13/13 unsigned build                             | 2026-06-13  | Phase 2 feature complete                    |
| Desktop `.msi` / `.deb` on `fivucsas.com/download/beta`  | **2026-06-27** | **Phase 2 exit**                            |
| Joint v6.0 code freeze                                   | 2026-08-08  | Phase 3 starts                              |
| Joint v6.0 GA on Android + Desktop channels              | **2026-08-15** | **Phase 3 exit — "production on client"**   |

iOS / iPadOS / macOS milestones removed (DROPPED 2026-04-26).

Slippage threshold: any milestone > 10 d late triggers a re-scoping session.

---

## 12. Risks + Mitigations

| # | Risk                                                                                                       | Likelihood | Impact | Mitigation                                                                                                                  |
| - | ---------------------------------------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| 1 | Play Store policy review bounces on OAuth redirect / Custom Tabs declarations                               | Low        | 1-week slip | AppAuth + Custom Tabs is the Google-recommended pattern; declare honestly in Data Safety                               |
| 2 | Windows Authenticode cert cost (EV $480/yr)                                                                 | Medium     | Budget | Ship unsigned `.msi` + SmartScreen override docs for v6; buy OV ($200) later                                             |
| 3 | Desktop loopback OAuth blocked by corporate firewalls on ephemeral ports                                    | Medium     | Desktop UX | Fallback: `http://127.0.0.1:<fixed-port>` from allowlist (7777, 7878, 7979); document firewall exceptions in install guide |
| 4 | Store copy rejected — Turkish-only marketing text                                                           | Low        | 3-day slip | Bilingual listings, EN primary, TR secondary                                                                            |
| 5 | Android signing key loss (irrecoverable for a given applicationId)                                          | Low        | Catastrophic | Three-way backup: GitHub secret, 1Password, printed QR in a safe                                                   |
| 6 | FCM silent-drop on Xiaomi / OPPO / Vivo battery-saver                                                       | High       | UX | Dual channel: FCM + WebSocket long-poll; first-arriving wins                                                             |
| 7 | Tenants ask for native biometric UI in desktop                                                              | Low        | Scope creep | Decline for v6; point to hosted login in system browser; revisit v7 if >3 paying-tenant requests                         |
| 8 | iOS / macOS customer demand                                                                                 | Medium     | Scope | DROPPED 2026-04-26 — no Apple hardware. Document "Apple users authenticate via hosted login page (`verify.fivucsas.com`) in system browser; no native iOS/macOS app planned." |

---

## 13. Open Questions for User

1. **Beta tester pool** — Marmara CSE only or open? Recommend: Android open beta, Desktop public.
2. **Privacy policy URL ownership** — who signs off on `fivucsas.com/privacy` content in TR + EN?
3. **Windows cert budget** — approve ~$200 Sectigo OV, or ship v6 unsigned with SmartScreen docs?
4. **APK v5.x → AAB** — cut a final v5.2 APK as frozen sideload before v6.0 AAB? Recommend yes.
5. ~~**iOS / macOS desktop**~~ — Resolved 2026-04-26: DROPPED. No Apple hardware available. Apple users use hosted login in system browser. Not "deferred", not "Phase 2", not "revisit later" — out of scope until/unless the hardware constraint changes.

---

## 14. Cross-reference Index

- `../../ROADMAP.md` — Phase I (Android hosted-first 13/13 done), Phase J (Desktop hosted-first active).
- `./NFC_PUSH_APPROVAL_PROTOCOL.md` — redirect contract the native push-approval handler targets.
- `./CLIENT_SIDE_ML_PLAN.md` — D1–D4 pre-filter rules (applies to hosted login surface, not native apps anymore).
- `./AUTH_METHOD_SECURITY_LEVELS.md` — security-tier map per auth method (applies on hosted surface).
- `../../CHANGELOG.md` — release history, MobileFaceNet deprecation (2026-04-18).
- `../../client-apps/ROADMAP_CLIENT_APPS.md`, `../../client-apps/CHANGELOG.md` — per-module history.
- `../../web-app/docs/AUDIT_REPORT_2026-04-16.md` — the audit that argued for hosted-first.
- `../../web-app/docs/plans/HOSTED_LOGIN_INTEGRATION.md` — PR-1 hosted-login spec.

---

## 15. Definition of Done for "Production on Client" (Hosted-First)

A single checklist — if any item is unchecked, the platform is not production.

- [ ] 13 / 13 rows in the feature matrix at `implemented` or higher for each of Android and Desktop (Windows + Linux). (iOS DROPPED 2026-04-26.)
- [ ] 13 / 13 rows at `tested` or higher for each in-scope platform.
- [ ] Android at `store-listed` (Play Store production 100 %).
- [ ] Desktop at `signed-release` and downloadable (`.msi` + `.deb` signed; Windows may be unsigned with SmartScreen caveat documented).
- [ ] All release signing secrets in GitHub Actions encrypted secrets (no `release.jks` or plaintext passwords in repo).
- [ ] Shared Kotlin tests ≥ 424 and not decreasing.
- [ ] Release notes published on all three channels with the same version string.
- [ ] Privacy policy URL reachable, returns 200, contains KVKK + GDPR sections in TR and EN.
- [ ] `fivucsas.com/download` links verified by a fresh machine on each OS (Windows, Linux).

Only when every box is checked does FIVUCSAS count as "production on client."

---

## Appendix A — Pre-pivot matrix (archived 2026-04-18)

The below is the **pre-pivot** view. It is retained for historical completeness. **Do not use it for planning.** Use §2 instead.

Statuses: `✗` not started · `scaffolded` · `implemented` · `tested` · `signed-release` · `store-listed`.

| Feature                                    | Android           | iOS          | Desktop            |
| ------------------------------------------ | ----------------- | ------------ | ------------------ |
| QR scan (approve web login)                | implemented       | ✗            | implemented        |
| QR display (receive approval)              | implemented       | ✗            | scaffolded         |
| TOTP authenticator (HMAC-SHA1 / otpauth://)| implemented       | ✗            | scaffolded         |
| Password login                             | tested            | scaffolded   | implemented        |
| Email OTP entry                            | tested            | ✗            | implemented        |
| SMS OTP entry                              | tested            | ✗            | implemented        |
| Face verification (BlazeFace + server)     | implemented       | scaffolded   | scaffolded         |
| Voice verification                         | implemented       | ✗            | ✗                  |
| Fingerprint (platform biometric)           | implemented       | scaffolded   | ✗                  |
| Passport NFC (ICAO 9303 + BAC)             | scaffolded        | ✗            | ✗                  |
| TCKN NFC (ISO-DEP)                         | implemented       | ✗            | ✗                  |
| Istanbulkart NFC (NDEF, basic read)        | implemented       | ✗            | ✗                  |
| Student card NFC (NDEF, basic read)        | implemented       | ✗            | ✗                  |
| Push-approval handler (FCM / APNs)         | implemented       | ✗            | ✗                  |
| Deep-link handler (`fivucsas://`)          | implemented       | ✗            | scaffolded         |
| Biometric enrollment flow                  | implemented       | ✗            | scaffolded         |
| Account management (profile / enrolls)     | implemented       | ✗            | implemented        |
| KVKK / GDPR export + delete                | scaffolded        | ✗            | ✗                  |
| Offline auth code (TOTP cached)            | implemented       | ✗            | scaffolded         |
| Cross-device session list                  | implemented       | ✗            | scaffolded         |
| Signed release artifact                    | signed-release    | ✗            | ✗ (unsigned)       |
| Public distribution                        | APK on GitHub     | ✗            | ✗                  |

Counts (pre-pivot, 2026-04-18 pre-rewrite snapshot): Android 18 / 20 cells in implemented-or-above; iOS 2 / 20; Desktop 7 / 20.

**Rows archived** (the ones that dropped in the post-pivot 13-column matrix): Face verification, Voice verification, Fingerprint, Passport NFC, TCKN NFC, Istanbulkart NFC, Student card NFC, Password login, Email OTP entry, SMS OTP entry, Biometric enrollment flow. All of these are now handled on the hosted login page; native clients no longer implement them.
