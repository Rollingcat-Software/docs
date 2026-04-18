# FIVUCSAS — Client-Apps Parity Roadmap

> Last updated: 2026-04-18
> Owner: client-apps workstream
> Cross-refs: `../../ROADMAP.md` (Phase G2–G4 mobile items), `./NFC_PUSH_APPROVAL_PROTOCOL.md` (sibling doc; NFC redirect), `./AUTH_METHOD_SECURITY_LEVELS.md`, `./CLIENT_SIDE_ML_PLAN.md`, `../../CHANGELOG.md` (2026-04-18 MobileFaceNet deprecation + V37/V38), `../../client-apps/ROADMAP_CLIENT_APPS.md` (per-module history)

---

## 1. Goal Statement

FIVUCSAS ships three native clients from one Kotlin Multiplatform codebase: **Android**, **iOS**, and **Desktop (JVM 21)**. Parity across those three surfaces is a hard release gate — the platform is not considered "production on client" until all three reach identical feature coverage, equivalent test coverage, a signed release artifact, and a public distribution channel appropriate to the platform. "Same level" in this document means: (a) every feature in the parity matrix below is implemented and unit+UI-tested, (b) each platform has a signed, reproducible release pipeline in CI, and (c) each platform is discoverable through its canonical channel — Play Store (Android), App Store / TestFlight (iOS), and `fivucsas.com/download` (Desktop).

---

## 2. Feature Parity Matrix

Statuses: `✗` not started · `scaffolded` (stubs / interface only) · `implemented` (functional in a debug build) · `tested` (unit + UI/instrumented coverage ≥ 70 %) · `signed-release` (built from CI with release signing) · `store-listed` (publicly downloadable by end users).

Honest snapshot per `/opt/projects/fivucsas/client-apps/` as of 2026-04-18. Android sits around 70 % of the target; iOS is ~10 % (framework plumbing + a handful of `expect/actual` platform adapters, no UI); Desktop is ~25 % (Compose UI skeleton, camera via JavaCV, no NFC, no push).

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

Counts: Android 18 / 20 feature cells in implemented-or-above; iOS 2 / 20; Desktop 7 / 20.

---

## 3. Gap Analysis per Platform

Top 10 per platform, priority-ordered. Effort column uses engineer-days assuming one senior KMP engineer full-time.

### Android — gaps

| # | Gap                                                                                       | Effort |
| - | ----------------------------------------------------------------------------------------- | ------ |
| 1 | Passport NFC: DG1/DG2 parse + BAC key derivation is stubbed; needs jmrtd wiring + tests   | 6 d    |
| 2 | KVKK/GDPR export + delete flow missing; wire to `/api/v1/users/me/export` + `DELETE`       | 3 d    |
| 3 | Play Store listing: AAB build variant, privacy policy URL, content rating, screenshots    | 4 d    |
| 4 | Keystore secret currently hardcoded in `androidApp/build.gradle.kts` — move to CI secret  | 1 d    |
| 5 | Instrumented test coverage ~35 % against 70 % gate — add Espresso flows for 10 auth paths | 5 d    |
| 6 | FCM push-approval UX: missing allow/deny notification action buttons + deep-link back     | 2 d    |
| 7 | NFC redirect handler per `./NFC_PUSH_APPROVAL_PROTOCOL.md`                                | 3 d    |
| 8 | `versionCode` / `versionName` auto-bumped from `shared` module version                    | 0.5 d  |
| 9 | ProGuard rules audit — BouncyCastle, jmrtd, ONNX keep rules                               | 1 d    |
| 10| Baseline Profile for cold-start < 1.5 s                                                   | 2 d    |

### iOS — gaps

| # | Gap                                                                                       | Effort |
| - | ----------------------------------------------------------------------------------------- | ------ |
| 1 | SwiftUI host app doesn't exist; scaffold `iosApp/` with SceneDelegate + entry screen      | 5 d    |
| 2 | Compose Multiplatform iOS integration (`ComposeUIViewController`) or native SwiftUI port  | 8 d    |
| 3 | Apple Developer Program enrollment ($99/yr) — blocker for any signed build                | 2 d    |
| 4 | Camera + AVFoundation capture wired into `IosCameraService`                               | 4 d    |
| 5 | CoreNFC reader for ISO 14443-4 (TCKN) + NDEF (Istanbulkart) + NFCPassportReader for ICAO  | 10 d   |
| 6 | APNs push-approval registration + `UNNotificationAction` allow/deny                       | 3 d    |
| 7 | LocalAuthentication (FaceID/TouchID) in `FingerprintPlatform.ios.kt`                      | 1 d    |
| 8 | Universal Links for `fivucsas://` + `https://verify.fivucsas.com/app/...`                 | 2 d    |
| 9 | TOTP generator + keychain-backed seed storage via `IosSecureStorage`                      | 2 d    |
| 10| TestFlight pipeline + App Store Connect metadata                                          | 4 d    |

### Desktop — gaps

| # | Gap                                                                                       | Effort |
| - | ----------------------------------------------------------------------------------------- | ------ |
| 1 | No NFC support — decide: ACR122U USB reader (javax.smartcardio) or drop NFC on Desktop    | 8 d    |
| 2 | Push-approval: no native channel — fall back to WebSocket / SSE poll against IC API      | 4 d    |
| 3 | Code-signed installers: macOS `codesign + notarytool`, Windows Authenticode, Linux GPG    | 5 d    |
| 4 | Auto-update infra — Compose `PackageInstaller` plugin or Sparkle/winsparkle bridge        | 5 d    |
| 5 | QR display pane in `member/` UI tree (companion-device flow)                              | 1 d    |
| 6 | Voice verification: microphone capture via `javax.sound.sampled` + PCM → WAV 16 kHz      | 3 d    |
| 7 | Face verification: fold MediaPipe landmark-geometry (512-D) into `DesktopCameraService`   | 4 d    |
| 8 | KVKK/GDPR export + delete UI + API plumbing                                               | 2 d    |
| 9 | TOTP UI (clock-aware, drift tolerant ±30 s)                                               | 2 d    |
| 10| Offline token cache + secure storage hardening (Linux: libsecret; macOS: Keychain; Win: DPAPI) | 3 d |

---

## 4. Release Criteria per Platform

### Android

- Signed AAB from CI `release` build type (currently APK v5.0.0 signed locally).
- Keystore password out of `androidApp/build.gradle.kts`, into GH Actions secrets.
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
- Privacy Nutrition Labels: Name, Email, Phone, Face-data, Voice-data, Device-ID, Diagnostics.
- TestFlight build green on ≥ 5 real devices (iPhone 12–15 + iPad 10th gen).
- Screenshots: 6.7″ + 6.1″ + 5.5″ (required) + 12.9″ iPad Pro.
- Review-guideline pass: 2.1, 2.5, 4.0, 5.1.1, 5.1.2.

### Desktop

- Download page at `https://fivucsas.com/download` (static, Hostinger).
- Signed installers:
  - **macOS**: Developer ID cert → `codesign` → `notarytool` → staple → `.dmg`.
  - **Windows**: Authenticode (DigiCert EV ~$480/yr, Sectigo OV ~$200/yr) → `signtool` on `.msi`. Interim: unsigned `.msi` + documented SmartScreen override.
  - **Linux**: GPG-signed `.deb`, pubkey on `fivucsas.com/pgp.asc`.
- Auto-update: Compose `PackageInstaller` plugin or a hand-rolled `update.fivucsas.com/desktop/manifest.json` channel.
- Artifacts: `.dmg` (universal), `.msi` (x64), `.deb` (x64) + SHA256 per file.

---

## 5. Test Strategy per Platform

| Layer           | Android                                       | iOS                                                 | Desktop                                         |
| --------------- | --------------------------------------------- | --------------------------------------------------- | ----------------------------------------------- |
| Unit            | JUnit5 + MockK in `shared/commonTest` + `androidUnitTest`; gate ≥ 80 % | XCTest for iosMain bits + KMP commonTest via Kotlin/Native test target | JUnit5 on `desktopTest`; gate ≥ 70 %            |
| UI / instr.     | Espresso + Compose UI test; 10 flows × 1 golden device each            | XCUITest on TestFlight simulator + 2 physical devices | Compose UI Test on JVM; headless via `Robot`    |
| E2E             | Maestro cloud: scan-QR → face → approve; 5 flows              | Maestro iOS: same 5 flows                            | Scripted UI via `KotlinNative-Robot` / JUnit    |
| Device-farm     | Firebase Test Lab: Pixel 4a, Pixel 7, Galaxy S22, Xiaomi Redmi 9 (cheap Android NFC baseline) | BrowserStack App Live: iPhone 12 / 14 / 15, iPad 10 | GitHub Actions matrix (`macos-latest`, `windows-latest`, `ubuntu-latest`) |
| Perf budgets    | Cold start ≤ 1.5 s P75; face-step ≤ 3 s P75                            | Cold start ≤ 1.5 s P75                              | Cold start ≤ 2.0 s P75; installer ≤ 180 MB      |
| Regression gate | PR must keep client-apps Kotlin test count ≥ 401 (today's baseline)    | Same                                                | Same                                            |

Shared `commonTest` currently ships **401 Kotlin tests**. That number must only rise.

---

## 6. Signing + Secrets Management

| Secret                        | Where today                                          | Target                                                                 |
| ----------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------- |
| Android release keystore      | `client-apps/keystore/release.jks` committed         | GH secret `ANDROID_KEYSTORE_B64` → `$RUNNER_TEMP` at build; purge from history |
| Android keystore passwords    | plain text in `androidApp/build.gradle.kts`          | GH secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD` via `System.getenv()` |
| Apple Dev cert + profile      | does not exist yet                                   | GH secrets `APPLE_CERT_P12_B64`, `APPLE_PROVISION_PROFILE_B64` + `match`        |
| App Store Connect API         | does not exist yet                                   | `APP_STORE_CONNECT_{KEY_ID,ISSUER_ID,KEY_P8_B64}`                      |
| Apple notarytool              | does not exist yet                                   | `APPLE_NOTARY_{USER,TEAM_ID,APP_PWD}` (app-specific password)          |
| Windows Authenticode          | not purchased                                        | `WIN_AUTHENTICODE_P12_B64` + `WIN_AUTHENTICODE_PWD` for `signtool`     |
| Linux `.deb` GPG key          | not created                                          | `LINUX_GPG_PRIVATE_KEY` + `LINUX_GPG_PASSPHRASE` imported ephemerally  |
| Firebase google-services.json | committed (public-safe)                              | Keep committed; audit Firebase security rules instead                  |
| APNs auth key (.p8)           | does not exist yet                                   | `APNS_{AUTH_KEY_P8_B64,KEY_ID,TEAM_ID}` — consumed by identity-core-api |

**Rotation schedule** (ties into parent `ROADMAP.md` Task E keystore rotation):

| Key                        | Cadence                              | Notes                                                      |
| -------------------------- | ------------------------------------ | ---------------------------------------------------------- |
| Android keystore           | Never (Play Store identity continuity) | Off-site encrypted backup; loss = cannot update installs |
| Apple Dev cert + profile   | Annual (Sep–Oct)                      | 30 d early-warn via App Store Connect                      |
| Apple APNs key             | On personnel change / compromise      | Multiple keys allowed; rotate-deploy-revoke                |
| Windows Authenticode       | Annual (purchase cycle)               | Renew 30 d early; timestamped old sigs stay valid          |
| Linux GPG                  | 2 years                               | New key signed by previous; transition notice on pubkey URL |
| GH Actions secrets         | With the thing they wrap; audit quarterly |                                                        |

---

## 7. Release Cadence + Versioning

- **SemVer** across all three platforms. The `shared` Kotlin module version string is the source of truth — `androidApp.versionName`, iOS `CFBundleShortVersionString`, Desktop `packageVersion` all read from `shared/build.gradle.kts` `version`.
- `versionCode` (Android) and `CFBundleVersion` (iOS) auto-derive from `versionName` via a Gradle script: `MAJOR*10000 + MINOR*100 + PATCH`. So `6.1.2` → `60102`.
- Shared + app versions bump together in one commit. PR CI rejects mismatches.
- **Release cadence**: minor every 6 weeks, patch on-demand, major aligned with backend breaking changes (rare).
- **Release notes template**: `client-apps/RELEASE_NOTES/vX.Y.Z.md` with sections `Added / Changed / Fixed / Security / Known issues`; rolled up from the three per-module `CHANGELOG.md` files. A copy-paste block at the bottom is what gets pasted into Play Console / App Store Connect / `download.html`.
- **Store rollout staging**:

| Stage                  | Android               | iOS                     | Desktop                     |
| ---------------------- | --------------------- | ----------------------- | --------------------------- |
| Day 0                  | Internal testing (team) | TestFlight internal    | `beta.fivucsas.com/download` |
| Day 3                  | Closed testing (≤ 100) | TestFlight external    | same                        |
| Day 7                  | Open beta             | (no equivalent)          | `fivucsas.com/download/next` |
| Day 10                 | Production 5 %        | Phased release day 1 (1 %) | Production link             |
| Day 12                 | 25 %                  | Phased release day 3 (5 %) | —                          |
| Day 14                 | 100 %                 | Phased release day 7 (100 %) | —                        |

A release is rolled back if crash-free-sessions drops > 1 pp from previous release during the first 48 h at any stage.

---

## 8. Deprecation Commitments

- **MobileFaceNet removed 2026-04-18** (see `CHANGELOG.md` section `[2026-04-18]`). The canonical client-side face embedding is **`geometry-512`** — 512-D MediaPipe FaceLandmarker output. Server remains authoritative via DeepFace Facenet512 per the D2 log-only rule in `./CLIENT_SIDE_ML_PLAN.md`. Any client code still referencing `mobilefacenet.onnx` must be deleted before v6.
- **Android minimum API: 26** (Android 8.0, Oreo). Covers > 99 % of Turkish market per Q1 2026 Play Console baseline. `minSdk = 24` today in `androidApp/build.gradle.kts` → bumping to 26 with v6.
- **iOS minimum: 15.0**. Covers ~95 % of active iOS devices globally, ~98 % in Turkey. Drops iOS 14 because Compose Multiplatform iOS target now requires 15+.
- **Desktop minimum: JVM 21** (already the build target; ships bundled JRE via Compose `nativeDistributions`, so users don't install Java themselves).
- **`BouncyCastle` provider**: Desktop + iOS use BC 1.78; Android ships with the platform-bundled Conscrypt and explicitly excludes `bcprov-jdk15to18` to avoid duplicate-class conflicts. Keep exclusion until API 34 aligns signatures.
- **TOTP algorithm**: HMAC-SHA1 / 30 s / 6 digits only. SHA256 / SHA512 variants accepted on import but re-emitted as SHA1 to preserve RFC 6238 compatibility with Google Authenticator and 1Password.

---

## 9. Rollout Phases

| Phase | Goal                                          | Exit criterion                                                  |
| ----- | --------------------------------------------- | --------------------------------------------------------------- |
| 1     | **Android reaches full parity** (all 20 feature rows implemented + tested + signed + Play Store open beta) | Play Console open-beta link live; crash-free sessions > 99 % on 50+ beta testers |
| 2     | **iOS reaches Android parity** (same 20 rows) | TestFlight external link live; crash-free sessions > 99 % on 20+ internal + 20+ external testers |
| 3     | **Desktop reaches Android parity** (NFC scope decision made — see Open Question 2) | `.dmg` + `.msi` + `.deb` auto-built in CI, code-signed on macOS, downloadable from `fivucsas.com/download/beta` |
| 4     | **Joint v6.0 GA** — all three publicly downloadable, same version, same release notes | Play Store production 100 %, App Store production 100 %, `fivucsas.com/download` serving v6.0 artifacts |

A platform cannot skip ahead — iOS cannot enter GA without Android and Desktop also being at GA-ready quality for the same feature set.

---

## 10. Milestones with Dates

Dates are target, not contractual; they assume one senior KMP engineer plus part-time platform-specialist support (iOS native dev for Phase 2, Windows-cert sign-off for Phase 3).

| Milestone                                                | Target date | Phase gate                                  |
| -------------------------------------------------------- | ----------- | ------------------------------------------- |
| Android keystore secrets moved to CI                     | 2026-04-25  | Phase 1 blocker                             |
| Android Passport-NFC + GDPR flows complete + tested      | 2026-05-09  | Phase 1 feature complete                    |
| Android Play Store open-beta live                        | **2026-05-16** | **Phase 1 exit**                         |
| iOS host app + Apple Dev Program enrolled                | 2026-05-23  | Phase 2 starts                              |
| iOS full-feature TestFlight internal build               | 2026-06-13  | Phase 2 feature complete                    |
| iOS TestFlight external beta live                        | **2026-06-20** | **Phase 2 exit**                         |
| Desktop NFC scope decision + code-signing certs procured | 2026-06-27  | Phase 3 starts                              |
| Desktop full-feature unsigned build                      | 2026-07-11  | Phase 3 feature complete                    |
| Desktop `.dmg`/`.msi`/`.deb` on `fivucsas.com/download/beta` | **2026-07-18** | **Phase 3 exit**                     |
| Joint v6.0 code freeze                                   | 2026-07-25  | Phase 4 starts                              |
| Joint v6.0 GA on all three channels                      | **2026-08-01** | **Phase 4 exit — "production on client"** |

Slippage threshold: any milestone > 10 d late triggers a re-scoping session and a parity-waiver conversation with product.

---

## 11. Risks + Mitigations

| # | Risk                                                                                                       | Likelihood | Impact | Mitigation                                                                                                                  |
| - | ---------------------------------------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| 1 | Apple Developer Org enrolment takes 4–8 weeks (D-U-N-S lookup) | High  | Phase 2 blocker | Individual account as parallel stopgap; migrate bundle ID once Org resolves |
| 2 | Play Store policy review bounces on biometric / NFC declarations | Medium | 1-week slip | Declare all biometric + NFC usage honestly in Data Safety; dry-run against `Sensitive permissions` page |
| 3 | Passport NFC read failure on cheap Androids (weak antenna) | High | Parity asymmetry | Accept ≥ 85 % on tested cheap-device cohort; fallback UX to camera MRZ scan |
| 4 | Windows Authenticode cert cost (EV $480/yr) | Medium | Budget | Ship unsigned `.msi` + SmartScreen override docs for v6; buy OV ($200) later |
| 5 | Desktop NFC reader matrix (ACR122U, OMNIKEY 5022, HID Identiv — PC/SC quirks) | High | Phase 3 scope | Open Question 2 below. Default: **drop NFC on Desktop v6** |
| 6 | iOS Universal Links broken by bad `apple-app-site-association` | Medium | 2-day slip | Host on `verify.fivucsas.com`; run AASA validator in CI |
| 7 | Store copy rejected — Turkish-only marketing text | Low | 3-day slip | Bilingual listings, EN primary, TR secondary |
| 8 | Android signing key loss (irrecoverable for a given applicationId) | Low | Catastrophic | Three-way backup: GitHub secret, 1Password, printed QR in a safe |
| 9 | FCM silent-drop on Xiaomi / OPPO / Vivo battery-saver | High | UX | Dual channel: FCM + WebSocket long-poll; first-arriving wins |
| 10| `bcprov` duplicate-class regressions on KMP toolchain upgrade | Medium | Build break | Snapshot dep tree in CI; alert on new transitive `bcprov*` |

---

## 12. Open Questions for User

These are blockers that require a human decision before engineering work can proceed.

1. **Apple Developer team — Org or Individual?** Org: D-U-N-S + 4–8 weeks; university owns bundle ID. Individual: team-lead's name, 1–3 d, painful to transfer later.
2. **Desktop NFC — in scope for v6?** (a) drop; (b) only ACR122U on Win + Linux; (c) full reader matrix. Recommend (a), revisit v7.
3. **Beta tester pool** — Marmara CSE only or open? Recommend: Android open beta, iOS TestFlight external ≤ 100, Desktop public.
4. **Privacy policy URL ownership** — who signs off on `fivucsas.com/privacy` content in TR + EN?
5. **Windows cert budget** — approve ~$200 Sectigo OV, or ship v6 unsigned with SmartScreen docs? If yes, cert subject = "Marmara University" or team-lead?
6. **APK v5.x → AAB** — cut a final v5.1 APK as frozen sideload before v6.0 AAB? Recommend yes (permanent no-Google-Services path).

---

## Appendix A — Cross-reference Index

- `../../ROADMAP.md` Phase G2 / G3 / G4 — mobile QR, Android NFC, native-app SDK docs.
- `./NFC_PUSH_APPROVAL_PROTOCOL.md` — redirect contract NFC handlers target.
- `./CLIENT_SIDE_ML_PLAN.md` — D1–D4 pre-filter rules (face row).
- `./AUTH_METHOD_SECURITY_LEVELS.md` — security-tier map per feature row.
- `../../CHANGELOG.md` — release history, MobileFaceNet deprecation (2026-04-18).
- `../../client-apps/ROADMAP_CLIENT_APPS.md`, `../../client-apps/CHANGELOG.md` — per-module history.

## Appendix B — Definition of Done for "Production on Client"

A single checklist — if any item is unchecked, the platform is not production.

- [ ] 20 / 20 rows in the feature matrix at `implemented` or higher for each of Android, iOS, Desktop.
- [ ] 20 / 20 rows at `tested` or higher for each platform.
- [ ] One platform at `store-listed` (Android Play Store production 100 %).
- [ ] One platform at `store-listed` (iOS App Store production 100 %).
- [ ] One platform at `signed-release` and downloadable (Desktop `.dmg` + `.msi` + `.deb` signed on at least macOS; Windows may be unsigned with SmartScreen caveat documented).
- [ ] All release signing secrets in GitHub Actions encrypted secrets (no `release.jks` or plaintext passwords in repo).
- [ ] Shared Kotlin tests ≥ 401 and not decreasing.
- [ ] Release notes published on all three channels with the same version string.
- [ ] Privacy policy URL reachable, returns 200, contains KVKK + GDPR sections in TR and EN.
- [ ] `fivucsas.com/download` links verified by a fresh machine on each OS.

Only when every box is checked does FIVUCSAS count as "production on client."
