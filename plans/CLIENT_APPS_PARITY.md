# FIVUCSAS — Client-Apps Parity Roadmap (Hosted-First Rewrite)

> Last updated: 2026-04-18e — rewritten after the 2026-04-16 hosted-first pivot.
> Owner: client-apps workstream
> Cross-refs: `../../ROADMAP.md` (Phase I Android 13/13 done; Phase J Desktop hosted-first active), `./NFC_PUSH_APPROVAL_PROTOCOL.md`, `./AUTH_METHOD_SECURITY_LEVELS.md`, `./CLIENT_SIDE_ML_PLAN.md`, `../../CHANGELOG.md` (2026-04-18 MobileFaceNet deprecation + V37/V38), `../../client-apps/ROADMAP_CLIENT_APPS.md` (per-module history), `../../client-apps/CHANGELOG.md`, `../../web-app/docs/AUDIT_REPORT_2026-04-16.md`, `../../web-app/docs/plans/HOSTED_LOGIN_INTEGRATION.md`.

---

## 0. Pivot Callout — Why This Document Was Rewritten (2026-04-18)

**On 2026-04-16, FIVUCSAS adopted hosted-first authentication as the primary integration mode.** Tenants (including our own native apps) no longer ship a bespoke reimplementation of every auth method. Instead they hand off to `verify.fivucsas.com/login` via OAuth 2.0 / OIDC redirect and receive an `?code=…&state=…` callback. The web hosted-login page runs the MFA ceremony — including Face, Voice, Fingerprint (WebAuthn platform authenticator), Passport NFC, Istanbulkart NFC, TCKN NFC, and QR-approval — once, in one codebase, under one security-review scope.

Pre-pivot assumption (what this document used to say):

> "Android + iOS + Desktop must each natively reimplement all ten auth methods (Password, Email OTP, SMS OTP, TOTP, Face, Voice, Fingerprint, Hardware Key, QR, NFC). Parity is a 20/20 matrix per platform."

Post-pivot reality (what this document now says):

> "Each native client is a **thin OAuth client** that opens the hosted login page in a system-trusted surface (Chrome Custom Tabs on Android, `ASWebAuthenticationSession` on iOS, RFC 8252 loopback on Desktop), stores the returned tokens in the OS keyring, refreshes them, and renders a native dashboard for post-login UX. The only auth-method code that still lives natively is a TOTP authenticator companion — because a TOTP app is a use-case in itself, not a login path."

### Why this matters

| Dimension | Pre-pivot (20/20 native) | Post-pivot (13/13 hosted) |
|---|---|---|
| **Bundle size** | Android APK carried ONNX BlazeFace + MediaPipe + Conscrypt extras + jmrtd + NFCPassportReader for iOS + a camera pipeline per platform. Target >45 MB. | Only OAuth + OS keyring + Compose dashboard + TOTP. v5.2.0-rc1 APK is ~18 MB. |
| **Maintenance surface** | Every new auth method = 3× native ports (Android Kotlin + iOS Swift/Kotlin-Native + Desktop JVM) + 3× test matrices + 3× store review cycles. | New auth methods land once on `verify.fivucsas.com`; native clients ship nothing. |
| **Security-review scope** | Face/Voice/NFC crypto surfaces audited per-platform (passport BAC, ICAO 9303 DG parsing, liveness anti-spoof) × 3. | One hosted surface; one audit; one threat model. Native clients audited as "a well-behaved OAuth 2.0 client per RFC 6749 + RFC 8252". |
| **Feature-parity speed** | iOS trailed Android by 12+ months on NFC + Face because of CoreNFC / AVFoundation port cost. | iOS ships "on day one" of Phase 2 with hosted login in `ASWebAuthenticationSession`; users get the full 10-method auth flow immediately. |
| **Industry alignment** | Atypical — almost every modern IdP (Auth0, Okta, Entra, Google, Apple, Keycloak, Cognito, Stripe, Turkish banks, e-Devlet) is hosted-first. | Aligned with industry. See `../../web-app/docs/AUDIT_REPORT_2026-04-16.md` for the competitive analysis. |

Architectural references:
- `../../web-app/docs/AUDIT_REPORT_2026-04-16.md` — the audit that argued for the pivot (Web NFC iframe restriction, WebAuthn cross-origin edge cases, Safari ITP, 3P cookie death).
- `../../web-app/docs/plans/HOSTED_LOGIN_INTEGRATION.md` — PR-1 hosted-login spec (`display=page`, `POST /oauth2/authorize/complete`, `verify.fivucsas.com/login`).
- `../../CLAUDE.md` §"Architectural direction (2026-04-16)" — short canonical statement.

The old 20-row matrix is preserved in **Appendix A** for history. Do not use it to plan new work.

---

## 1. Goal Statement

FIVUCSAS ships three native clients from one Kotlin Multiplatform codebase: **Android**, **iOS**, and **Desktop (JVM 21, Windows + Linux only)**. A client is "at parity" when it implements the 13 thin-OAuth-client columns in §2, passes the test gates in §5, produces a signed release artifact, and is discoverable through its canonical channel — Play Store (Android), App Store / TestFlight (iOS), and `fivucsas.com/download` (Desktop).

**macOS desktop is explicitly out of scope** for v6 — no Mac available for `codesign` / `notarytool` / `.dmg` builds. Revisit when a Mac is procured.

**Native auth-method reimplementation is explicitly out of scope.** A user who needs NFC, Face, Voice, or Hardware-Key authenticates via the hosted login page — which, on mobile, opens in a Chrome Custom Tab / ASWebAuthenticationSession in front of the native app. The native app never sees the biometric data; it sees an OAuth code.

---

## 2. Feature Parity Matrix (Hosted-First — 13 columns)

Statuses: `✗` not started · `scaffolded` (stubs / interface only) · `implemented` (functional in a debug build) · `tested` (unit + UI/instrumented coverage ≥ 70 %) · `signed-release` (built from CI with release signing) · `store-listed` (publicly downloadable by end users).

Honest snapshot as of 2026-04-18e, verified against `/opt/projects/fivucsas/client-apps/`:

| # | Feature                                                                                          | Android (v5.2.0-rc1) | Desktop (Win+Linux) | iOS (Phase 2) |
|---|--------------------------------------------------------------------------------------------------|----------------------|---------------------|---------------|
| 1 | **OAuth login** — Custom Tabs (Android) / ASWebAuthenticationSession (iOS) / RFC 8252 loopback (Desktop) | implemented (AppAuth + Custom Tabs) | scaffolded (Agent B loopback WIP) | ✗ |
| 2 | **Secure token storage** — Keystore (Android) / Keychain (iOS) / DPAPI (Windows) / libsecret (Linux) | implemented (`EncryptedSharedPreferences`) | scaffolded (`SecureTokenStorage` iface + DPAPI/libsecret impls WIP) | ✗ |
| 3 | **Token refresh + auto-renewal** (refresh_token grant, proactive renewal at 80 % TTL)              | implemented         | ✗                    | ✗ |
| 4 | **Deep-link handler** (`fivucsas://` custom scheme mobile; loopback redirect desktop)             | implemented         | scaffolded (Agent B) | ✗ |
| 5 | **Account dashboard** (enrollments, profile, data export link, sessions list)                     | implemented         | scaffolded (Compose skeleton) | ✗ |
| 6 | **Cross-device sessions** (view active sessions, revoke remote)                                   | implemented         | scaffolded          | ✗ |
| 7 | **GDPR/KVKK export** (fire `GET /users/{id}/export`, save to Downloads / file picker)             | implemented (v5.2.0-rc1 `DataExportViewModel` + MediaStore) | ✗ | ✗ |
| 8 | **Offline display** (cached user info + last-session summary when network absent)                 | implemented         | scaffolded          | ✗ |
| 9 | **Push / WebSocket approval handler** — FCM+APNs on mobile, WebSocket fallback on desktop         | implemented (FCM + `ApprovalActionReceiver` v5.2.0-rc1) | ✗ (WebSocket plumbing TBD) | ✗ |
| 10 | **TOTP authenticator (companion)** — RFC 6238 SHA1/256/512, `otpauth://` parser, QR scan, keyring vault | implemented + tested (v5.1.0 engine, v5.2.0-rc1 QR scanner) | ✗ | ✗ (engine reusable via KMP `expect`/`actual`, needs HMAC actuals) |
| 11 | **QR display + scanner** — display for companion-device login (approve on phone), scan for OAuth / TOTP handoff | implemented (display + scan) | scaffolded (display only) | ✗ |
| 12 | **Signed release artifact** (CI-built, release-signed)                                            | signed-release (v5.2.0-rc1 tagged 2026-04-18e) | ✗ (unsigned builds only) | ✗ |
| 13 | **Public distribution** (Play Store / TestFlight / `fivucsas.com/download`)                        | APK on GitHub Releases + Play Store listing planned | ✗ | ✗ |

**Counts (implemented-or-above):**
- **Android: 13 / 13** — v5.2.0-rc1 tagged 2026-04-18e (Phase I complete per `../../ROADMAP.md`).
- **Desktop (Windows + Linux): 2 / 13** — scaffolding work actively in flight (Agents B/C/D on OAuth loopback + secure storage + installers).
- **iOS: 0 / 13** — no `iosApp/` module exists; Phase 2 (July 2026), blocked on Apple Developer enrollment.
- **macOS: out of scope** — no Mac hardware available for code-signing and notarytool.

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

### iOS — gaps (Phase 2, blocked on Apple Developer enrollment)

iOS is at 0/13. The entire Phase 2 workstream opens once an Apple Developer Program seat is active.

| # | Gap                                                                                         | Effort |
|---|---------------------------------------------------------------------------------------------|--------|
| 1 | Apple Developer Program enrollment ($99/yr; D-U-N-S for Org or team-lead Individual stopgap) | 2 d (calendar), 4–8 wks (Org) |
| 2 | `iosApp/` SwiftUI host module scaffold + Compose Multiplatform UIViewController bridge       | 6 d   |
| 3 | `ASWebAuthenticationSession` OAuth login wrapper (AppAuth-iOS optional, SFAuthSession is sufficient) | 3 d   |
| 4 | Keychain-backed token storage via `expect`/`actual` in `iosMain`                             | 2 d   |
| 5 | Token refresh + background fetch (BGProcessingTask)                                          | 2 d   |
| 6 | Universal Links for `https://verify.fivucsas.com/app/*` + custom scheme `fivucsas://`         | 2 d   |
| 7 | Account dashboard — Compose Multiplatform-rendered or SwiftUI port                           | 4 d   |
| 8 | APNs push-approval registration + `UNNotificationAction` allow/deny                          | 3 d   |
| 9 | TOTP HMAC actuals (`SecKeyCreateSignature` or CryptoKit) to reuse the KMP engine             | 1 d   |
| 10 | QR display + scanner via AVFoundation                                                        | 2 d   |
| 11 | TestFlight pipeline via `match` + `fastlane`                                                 | 4 d   |
| 12 | App Store Connect metadata + Privacy Nutrition Labels                                        | 2 d   |
| 13 | Signed release via GH Actions (`APPLE_CERT_P12_B64`, `APPLE_PROVISION_PROFILE_B64`)           | 2 d   |

Any legacy AVFoundation camera / CoreNFC / LocalAuthentication work is **not scheduled** — those surfaces live in the hosted login page that the system browser opens. Revisit only if a customer asks for a native-only iOS flow (unlikely until post-v6).

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

### iOS

- Apple Developer Program active ($99/yr; Org enrolment needs D-U-N-S, or individual as stopgap).
- Distribution cert + provisioning profile stored via `match` in GH Secrets.
- App Store Connect record, bundle ID `com.fivucsas.mobile`.
- Privacy Nutrition Labels: Name, Email, Phone, Device-ID, Diagnostics. (Face/Voice labels omitted — those belong to the hosted login web surface, not the native app.)
- TestFlight build green on ≥ 5 real devices (iPhone 12–15 + iPad 10th gen).
- Screenshots: 6.7″ + 6.1″ + 5.5″ (required) + 12.9″ iPad Pro.
- Review-guideline pass: 2.1, 2.5, 4.0, 5.1.1, 5.1.2.

### Desktop (Windows + Linux)

- Download page at `https://fivucsas.com/download` (static, Hostinger).
- Signed installers:
  - **Windows**: Authenticode (DigiCert EV ~$480/yr, Sectigo OV ~$200/yr) → `signtool` on `.msi`. Interim: unsigned `.msi` + documented SmartScreen override.
  - **Linux**: GPG-signed `.deb`, pubkey on `fivucsas.com/pgp.asc`.
- Auto-update: hand-rolled `update.fivucsas.com/desktop/manifest.json` channel checked on launch.
- Artifacts: `.msi` (x64), `.deb` (x64) + SHA256 per file.
- macOS `.dmg` **out of scope** — add in a future revision if a Mac is procured.

---

## 5. Test Strategy per Platform

| Layer           | Android                                       | iOS                                                 | Desktop (Win+Linux)                              |
| --------------- | --------------------------------------------- | --------------------------------------------------- | ------------------------------------------------ |
| Unit            | JUnit5 + MockK in `shared/commonTest` + `androidUnitTest`; gate ≥ 80 % | XCTest for iosMain bits + KMP commonTest via Kotlin/Native test target | JUnit5 on `desktopTest`; gate ≥ 70 %             |
| UI / instr.     | Espresso + Compose UI test; golden flows: OAuth redirect-return, token refresh, approval handler, TOTP vault, GDPR export | XCUITest on TestFlight simulator + 2 physical devices | Compose UI Test on JVM; headless via `Robot`     |
| E2E             | Maestro cloud: launch → OAuth Custom Tab → back into app → dashboard; 5 flows | Maestro iOS: same 5 flows                            | Scripted UI via `KotlinNative-Robot` / JUnit     |
| Device-farm     | Firebase Test Lab: Pixel 4a, Pixel 7, Galaxy S22, Xiaomi Redmi 9 | BrowserStack App Live: iPhone 12 / 14 / 15, iPad 10 | GitHub Actions matrix (`windows-latest`, `ubuntu-latest`) |
| Perf budgets    | Cold start ≤ 1.5 s P75; OAuth round-trip ≤ 3 s P75 (network-bound) | Cold start ≤ 1.5 s P75                              | Cold start ≤ 2.0 s P75; installer ≤ 80 MB (hosted-first shrinks this vs. old ~180 MB target) |
| Regression gate | PR must keep client-apps Kotlin test count ≥ 424 (current baseline; was 401 at pre-pivot) | Same                                                | Same                                             |

Shared `commonTest` currently ships **424 Kotlin tests** (v5.1.0 added ~23 for the TOTP engine + `otpauth://` parser). That number must only rise.

---

## 6. Signing + Secrets Management

| Secret                        | Where today                                          | Target                                                                 |
| ----------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------- |
| Android release keystore      | `client-apps/keystore/release.jks` committed         | GH secret `ANDROID_KEYSTORE_B64` → `$RUNNER_TEMP` at build; purge from history |
| Android keystore passwords    | env-var scaffolding shipped `cb6eab9`; user rotation pending | GH secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` via `System.getenv()` |
| Apple Dev cert + profile      | does not exist yet                                   | GH secrets `APPLE_CERT_P12_B64`, `APPLE_PROVISION_PROFILE_B64` + `match`        |
| App Store Connect API         | does not exist yet                                   | `APP_STORE_CONNECT_{KEY_ID,ISSUER_ID,KEY_P8_B64}`                      |
| Apple notarytool              | n/a (macOS out of scope)                              | —                                                                      |
| Windows Authenticode          | not purchased                                        | `WIN_AUTHENTICODE_P12_B64` + `WIN_AUTHENTICODE_PWD` for `signtool`     |
| Linux `.deb` GPG key          | not created                                          | `LINUX_GPG_PRIVATE_KEY` + `LINUX_GPG_PASSPHRASE` imported ephemerally  |
| Firebase google-services.json | committed (public-safe)                              | Keep committed; audit Firebase security rules instead                  |
| APNs auth key (.p8)           | does not exist yet                                   | `APNS_{AUTH_KEY_P8_B64,KEY_ID,TEAM_ID}` — consumed by identity-core-api |

**Rotation schedule** (ties into parent `../../ROADMAP.md` Phase C6 keystore rotation):

| Key                        | Cadence                              | Notes                                                      |
| -------------------------- | ------------------------------------ | ---------------------------------------------------------- |
| Android keystore           | Never (Play Store identity continuity) | Off-site encrypted backup; loss = cannot update installs |
| Apple Dev cert + profile   | Annual (Sep–Oct)                      | 30 d early-warn via App Store Connect                      |
| Apple APNs key             | On personnel change / compromise      | Multiple keys allowed; rotate-deploy-revoke                |
| Windows Authenticode       | Annual (purchase cycle)               | Renew 30 d early; timestamped old sigs stay valid          |
| Linux GPG                  | 2 years                               | New key signed by previous; transition notice on pubkey URL |
| GH Actions secrets         | With the thing they wrap; audit quarterly |                                                        |

---

## 7. Why Hosted-First (Architectural Justification)

This section is a standalone explainer for new contributors. If you have already read the pivot callout in §0 and the audit at `../../web-app/docs/AUDIT_REPORT_2026-04-16.md`, skip it.

**Problem with pre-pivot native-reimplementation:**

1. **Cross-platform biometric crypto is extremely expensive.** Passport BAC (ICAO 9303) DG1/DG2 parsing alone is ~5,400 LOC — which we ported into Android, pending MFA integration. Porting the same code to iOS CoreNFC + Desktop PC/SC (ACR122U / OMNIKEY 5022) would triple that cost with near-zero reuse — the platform crypto APIs diverge below the KMP `expect`/`actual` boundary.
2. **Web NFC / WebAuthn / autofill / password-manager integration all require top-level browsing context.** An iframe-embedded widget cannot trigger Web NFC on any browser in 2026. It cannot use platform authenticator fingerprint reliably cross-origin. iOS Safari ITP silently breaks widget cookies. Third-party-cookie deprecation in Chrome + Firefox completes the picture.
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

- **SemVer** across all three platforms. The `shared` Kotlin module version string is the source of truth — `androidApp.versionName`, iOS `CFBundleShortVersionString`, Desktop `packageVersion` all read from `shared/build.gradle.kts` `version`.
- `versionCode` (Android) and `CFBundleVersion` (iOS) auto-derive from `versionName` via a Gradle script: `MAJOR*10000 + MINOR*100 + PATCH`. So `6.1.2` → `60102`.
- Shared + app versions bump together in one commit. PR CI rejects mismatches.
- **Release cadence**: minor every 6 weeks, patch on-demand, major aligned with backend breaking changes (rare).
- **Release notes template**: `client-apps/RELEASE_NOTES/vX.Y.Z.md` with sections `Added / Changed / Fixed / Security / Known issues`; rolled up from the three per-module `CHANGELOG.md` files. A copy-paste block at the bottom is what gets pasted into Play Console / App Store Connect / `download.html`.
- **Store rollout staging**:

| Stage     | Android                    | iOS                           | Desktop                     |
| --------- | -------------------------- | ----------------------------- | --------------------------- |
| Day 0     | Internal testing (team)    | TestFlight internal           | `beta.fivucsas.com/download` |
| Day 3     | Closed testing (≤ 100)     | TestFlight external           | same                        |
| Day 7     | Open beta                  | (no equivalent)                | `fivucsas.com/download/next` |
| Day 10    | Production 5 %             | Phased release day 1 (1 %)    | Production link             |
| Day 12    | 25 %                       | Phased release day 3 (5 %)    | —                           |
| Day 14    | 100 %                      | Phased release day 7 (100 %)  | —                           |

A release is rolled back if crash-free-sessions drops > 1 pp from previous release during the first 48 h at any stage.

---

## 9. Deprecation Commitments

- **MobileFaceNet removed 2026-04-18** (see `../../CHANGELOG.md` section `[2026-04-18]`). Face recognition now happens exclusively on the hosted login page via the server-side DeepFace Facenet512 pipeline. Any client code still referencing `mobilefacenet.onnx` must be deleted before v6.
- **Native biometric-auth reimplementation deprecated 2026-04-16.** Face, Voice, Fingerprint (WebAuthn), Hardware Key, and NFC surfaces that existed in pre-pivot Android code are being removed during v5.x → v6.0 cleanup. They will not be ported to iOS or Desktop. If a tenant needs inline step-up biometric MFA, they embed the widget iframe in a top-level origin or use hosted login.
- **Android minimum API: 26** (Android 8.0, Oreo). Covers > 99 % of Turkish market per Q1 2026 Play Console baseline. Bumping from 24 → 26 with v6.
- **iOS minimum: 15.0**. Covers ~95 % of active iOS devices globally, ~98 % in Turkey.
- **Desktop minimum: JVM 21** (already the build target; ships bundled JRE via Compose `nativeDistributions`, so users don't install Java themselves).
- **TOTP algorithm**: HMAC-SHA1 / 30 s / 6 digits only. SHA256 / SHA512 variants accepted on import but re-emitted as SHA1 to preserve RFC 6238 compatibility with Google Authenticator and 1Password.

---

## 10. Rollout Phases (Hosted-First)

| Phase | Goal                                                                                         | Exit criterion                                                                                    |
| ----- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| 1     | **Android reaches hosted-first 13/13** + Play Store open beta                                | Play Console open-beta link live; crash-free sessions > 99 % on 50+ beta testers                  |
| 2     | **Desktop reaches hosted-first 13/13** on Windows + Linux                                     | `.msi` + `.deb` auto-built in CI; downloadable from `fivucsas.com/download/beta` on Win + Linux   |
| 3     | **iOS reaches hosted-first 13/13** (blocked on Apple Dev Program)                             | TestFlight external link live; crash-free sessions > 99 % on 20+ internal + 20+ external testers  |
| 4     | **Joint v6.0 GA** — all three publicly downloadable, same version, same release notes         | Play Store production 100 %, App Store production 100 %, `fivucsas.com/download` serving v6.0 artifacts |

Phase 1 shipped 2026-04-18e (tag `v5.2.0-rc1`). Phase 2 (Desktop) is the current active workstream. Phase 3 (iOS) opens in July 2026.

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
| iOS host app + Apple Dev Program enrolled                | 2026-07-04  | Phase 3 starts                              |
| iOS hosted-first 13/13 TestFlight build                  | 2026-07-25  | Phase 3 feature complete                    |
| iOS TestFlight external beta live                        | **2026-08-01** | **Phase 3 exit**                            |
| Joint v6.0 code freeze                                   | 2026-08-08  | Phase 4 starts                              |
| Joint v6.0 GA on all three channels                      | **2026-08-15** | **Phase 4 exit — "production on client"**   |

Slippage threshold: any milestone > 10 d late triggers a re-scoping session.

---

## 12. Risks + Mitigations

| # | Risk                                                                                                       | Likelihood | Impact | Mitigation                                                                                                                  |
| - | ---------------------------------------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| 1 | Apple Developer Org enrolment takes 4–8 weeks (D-U-N-S lookup)                                              | High       | Phase 3 blocker | Individual account as parallel stopgap; migrate bundle ID once Org resolves                                            |
| 2 | Play Store policy review bounces on OAuth redirect / Custom Tabs declarations                               | Low        | 1-week slip | AppAuth + Custom Tabs is the Google-recommended pattern; declare honestly in Data Safety                               |
| 3 | Windows Authenticode cert cost (EV $480/yr)                                                                 | Medium     | Budget | Ship unsigned `.msi` + SmartScreen override docs for v6; buy OV ($200) later                                             |
| 4 | Desktop loopback OAuth blocked by corporate firewalls on ephemeral ports                                    | Medium     | Desktop UX | Fallback: `http://127.0.0.1:<fixed-port>` from allowlist (7777, 7878, 7979); document firewall exceptions in install guide |
| 5 | iOS Universal Links broken by bad `apple-app-site-association`                                              | Medium     | 2-day slip | Host on `verify.fivucsas.com`; run AASA validator in CI                                                                 |
| 6 | Store copy rejected — Turkish-only marketing text                                                           | Low        | 3-day slip | Bilingual listings, EN primary, TR secondary                                                                            |
| 7 | Android signing key loss (irrecoverable for a given applicationId)                                          | Low        | Catastrophic | Three-way backup: GitHub secret, 1Password, printed QR in a safe                                                   |
| 8 | FCM silent-drop on Xiaomi / OPPO / Vivo battery-saver                                                       | High       | UX | Dual channel: FCM + WebSocket long-poll; first-arriving wins                                                             |
| 9 | Tenants ask for native biometric UI in desktop                                                              | Low        | Scope creep | Decline for v6; point to hosted login in system browser; revisit v7 if >3 paying-tenant requests                         |
| 10| macOS customer demand                                                                                       | Medium     | Scope | Document "macOS desktop not supported in v6; hosted web + iOS covers Mac users"; revisit with Mac procurement       |

---

## 13. Open Questions for User

1. **Apple Developer team — Org or Individual?** Org: D-U-N-S + 4–8 weeks; university owns bundle ID. Individual: team-lead's name, 1–3 d, painful to transfer later.
2. **Beta tester pool** — Marmara CSE only or open? Recommend: Android open beta, iOS TestFlight external ≤ 100, Desktop public.
3. **Privacy policy URL ownership** — who signs off on `fivucsas.com/privacy` content in TR + EN?
4. **Windows cert budget** — approve ~$200 Sectigo OV, or ship v6 unsigned with SmartScreen docs?
5. **APK v5.x → AAB** — cut a final v5.2 APK as frozen sideload before v6.0 AAB? Recommend yes.
6. **macOS desktop** — confirm out-of-scope for v6; revisit only after Mac hardware procurement.

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

- [ ] 13 / 13 rows in the feature matrix at `implemented` or higher for each of Android, Desktop (Windows + Linux), iOS.
- [ ] 13 / 13 rows at `tested` or higher for each platform.
- [ ] Android at `store-listed` (Play Store production 100 %).
- [ ] iOS at `store-listed` (App Store production 100 %).
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
