# Path to 20/20 — Android Feature Parity Close-out Plan

> Last updated: 2026-04-18e — Canonical plan for closing the five remaining gaps between the FIVUCSAS Android client (v5.1.0) and the web-app 20/20 reference. Total estimate: ~8 engineer-days, fully parallelizable across five code agents (20A–20E). This file supersedes per-gap notes scattered across `client-apps/docs/TODO.md`, `CLIENT_APPS_PARITY.md`, and `NFC_PUSH_APPROVAL_PROTOCOL.md` for the Android-only 20/20 push.

## Context

Cross-platform deep review (2026-04-18e) confirmed:

- **KMP genuineness.** 337 files under `client-apps/shared/src/commonMain/` totalling ~11,500 LOC of real domain / data / presentation code. This is not a shared-scaffold + per-platform-fork project.
- **Android baseline: ~15/20 feature parity** against web. The previously circulated 13/20 figure underweighted the already-ported NFC infrastructure.
- **NFC crypto already ported.** 5,447 LOC under `client-apps/androidApp/src/main/kotlin/com/fivucsas/mobile/android/data/nfc/`: `PassportNfcReader` (873), `TurkishEidReader` (457), `BacAuthentication` (502), `SecureMessaging` (470), plus Dg1/Dg2/MRZ parsers and `CardReaderFactory`. `NfcReadScreen.kt` (642 LOC, MRZ input UI + `koinInject<INfcService>`) exists. **The gap is integration only**: `MfaFlowScreen.kt:324` still dispatches `NFC_DOCUMENT` to `GenericMethodStepInput` placeholder.
- **Ship A** (Wave A prod fixes — CORS preflight, verify-widget ORT 404, BlazeFace singleton, `dropConsole`, i18n banner) verified in prod.
- **Ship D** (Android TOTP authenticator v5.1.0 — RFC 6238 engine in commonMain, `EncryptedSharedPreferences` vault, Compose Material 3 UI) tagged and shipped. QR-scan follow-up = Gap #5.

The five gaps below are what stand between Android v5.1.0 and 20/20.

## The five gaps

| # | Gap | Current state (commit/line references) | Work to do | Files new | Files modified | Days |
|---|-----|-----------------------------------------|------------|-----------|----------------|------|
| **1** | **Passport BAC MFA integration** | NFC crypto stack (5,447 LOC) already under `androidApp/data/nfc/`. `NfcReadScreen.kt` exists (MRZ input UI + `koinInject<INfcService>`). `MfaFlowScreen.kt:324` still routes `NFC_DOCUMENT` → `GenericMethodStepInput` placeholder. MRZ camera capture does not exist on Android (only on `practice-and-test/UniversalNfcReader`). | Port `MrzScannerScreen.kt` from `practice-and-test/UniversalNfcReader` (CameraX preview + OCR via ML Kit text recognition + ICAO MRZ line regex). Create `NfcStepScreen.kt` that hosts `MrzScannerScreen` → BAC key derivation → `PassportNfcReader.read()` → DG1/DG2 parse → server `/api/v1/mfa/nfc/verify`. Replace the `GenericMethodStepInput` dispatch at `MfaFlowScreen.kt:324`. | `NfcStepScreen.kt`, `MrzScannerScreen.kt`, `NfcStepViewModel.kt`, `MrzScannerViewModel.kt` | `MfaFlowScreen.kt` (dispatcher), `AndroidManifest.xml` (camera permission already present — verify), `strings.xml` + `en.json`/`tr.json` (MRZ capture copy) | ~2 |
| **2** | **GDPR/KVKK export mobile UI** | Backend `GET /users/{id}/export` shipped 2026-04-16b. Web-app wired 2026-04-18 on `MyProfilePage`. Android has **zero UI**. | New `GdprRepository` in `data/repository/` hitting the `/export` endpoint; `GdprViewModel` in `shared/presentation/viewmodel/`; "Download my data" row on `ProfileScreen` with DataStore-gated rate-limit; Android `DownloadManager` integration to save the returned JSON to Downloads; 8 i18n keys covering button label, confirmation dialog, success toast, error toast, "Download started" notification, file-name template, rate-limit message, KVKK disclosure. | `GdprRepository.kt`, `GdprViewModel.kt`, `GdprExportButton.kt` (Compose row) | `ProfileScreen.kt` (add row), `AppModule.kt` (DI), `en.json` + `tr.json` (8 keys), `AndroidManifest.xml` (WRITE permission if scoped-storage path chosen) | ~2 |
| **3** | **FCM action buttons + `fivucsas://` deep-link** | `FivucsasFirebaseMessagingService` currently shows plain notifications. `AndroidManifest.xml` has only the `TECH_DISCOVERED` intent-filter (NFC tag discovery). No Allow/Deny actions, no deep-link scheme, no `onNewIntent` handler. Protocol spec already exists in `docs/plans/NFC_PUSH_APPROVAL_PROTOCOL.md`. | Add Allow / Deny `NotificationCompat.Action` buttons on push notifications built in `FivucsasFirebaseMessagingService`; create `ApprovalActionReceiver` (BroadcastReceiver) to POST the signed approval to `/api/v1/nfc/approve` or `/deny`; add `fivucsas://nfc-session` custom scheme to `AndroidManifest.xml` with `android:autoVerify="false"`; wire `MainActivity.onNewIntent` to parse the session-id path segment + hop to `NfcStepScreen`; Ed25519 signature per protocol spec. | `ApprovalActionReceiver.kt`, `NfcSessionDeepLinkHandler.kt` | `FivucsasFirebaseMessagingService.kt`, `AndroidManifest.xml`, `MainActivity.kt`, `AppModule.kt` | ~2 |
| **4** | **Dark mode toggle in Settings** | `AppColors.kt` already exposes both palettes (light + dark). Theme is driven by `isSystemInDarkTheme()` with no user override. Settings has no theme row. | Add `ThemeMode { SYSTEM, LIGHT, DARK }` enum in `shared/presentation/state/`. New `ThemePreferences` backed by DataStore. Expose via `CompositionLocalOf<ThemeMode>` so `FivucsasTheme` can resolve. Add a 3-radio row on `SettingsScreen` ("Follow system / Light / Dark") with live preview. | `ThemeMode.kt`, `ThemePreferences.kt`, `ThemeModeRow.kt` | `FivucsasTheme.kt`, `SettingsScreen.kt`, `SettingsViewModel.kt`, `AppModule.kt`, `en.json` + `tr.json` (4 keys) | ~1 |
| **5** | **Authenticator QR scanner** | v5.1.0 shipped manual entry only. The "Scan QR" bottom-sheet entry is currently a `Toast` redirecting users to manual entry. Existing `QrScannerScreen` (CameraX + ML Kit barcode) is already in the codebase for the QR-code auth method. `OtpauthUri.parse()` is already implemented in `shared/commonMain/.../authenticator/totp/`. | Create `OtpQrScannerScreen.kt` that reuses the existing `QrScannerScreen` CameraX + ML Kit pipeline but filters `BARCODE_FORMAT_QR_CODE`, pipes raw text through `OtpauthUri.parse()`, and dispatches a `ScannedAccount` event up to `AuthenticatorViewModel.addAccount()`. Replace the `Toast` fallback in the "Scan QR" bottom-sheet branch with a navigation call. | `OtpQrScannerScreen.kt`, `OtpQrScannerViewModel.kt` | `AuthenticatorScreen.kt` (bottom-sheet branch), `NavGraph.kt`, `en.json` + `tr.json` (3 keys) | ~1 |

**Total: ~8 engineer-days, fully parallelizable.**

## Implementation sequencing

### Wave 1 — Documentation (1 agent, ~1 hour)

Update the eight documentation files listed in the 2026-04-18e CHANGELOG entry. Blocks nothing but unblocks Wave 2 agents by publishing the canonical plan (this file).

**Verification:** `git diff --stat` shows 8 files touched; `grep "2026-04-18e" ROADMAP.md CHANGELOG.md CLAUDE.md` returns matches; new `docs/plans/PATH_TO_20_20.md` exists.

### Wave 2 — Five parallel code agents (20A–20E, ~8 engineer-days in parallel wall-clock)

- **Agent 20A** — Gap #1 (NFC MFA integration). Owns `NfcStepScreen.kt` + `MrzScannerScreen.kt` + `MfaFlowScreen.kt:324` dispatcher change.
- **Agent 20B** — Gap #2 (GDPR export UI). Owns `GdprRepository` + `GdprViewModel` + `ProfileScreen` row + `DownloadManager` hook.
- **Agent 20C** — Gap #3 (FCM actions + deep link). Owns `ApprovalActionReceiver` + `fivucsas://` scheme + `onNewIntent` handler.
- **Agent 20D** — Gap #4 (Dark mode toggle). Owns `ThemeMode` enum + `ThemePreferences` + `SettingsScreen` row.
- **Agent 20E** — Gap #5 (QR scanner). Owns `OtpQrScannerScreen` + `AuthenticatorScreen` bottom-sheet branch.

Agents work on separate feature branches off `main` to avoid collisions. `AppModule.kt`, `en.json`, and `tr.json` are the only commonly touched files; each agent lands their strings/DI wiring in a dedicated section with clear markers to reduce merge friction.

### Wave 3 — Held on user input (queued)

- **Ship B** (Android keystore rotation execution) — user-gated per GitGuardian #29836028 / `docs/SECURITY_INCIDENTS.md`. Scaffolding already shipped in commit `cb6eab9` 2026-04-18.
- **Ship C** (Phase C Wave 0 ops hardening — PostgreSQL + Redis + JWT + Twilio + biometric `X-API-Key` + Hostinger SMTP rotation + `.env.prod` history purge) — requires scheduled 2-hour maintenance window (JWT rotation signs everyone out).

### Wave 4 — Consolidation + v5.2.0 tag

After Wave 2 agents merge:

1. Rebase all five branches onto `main`; resolve `AppModule.kt` + `en.json` + `tr.json` merges manually (expected).
2. `./gradlew :shared:test :androidApp:assembleDebug :androidApp:testDebugUnitTest` — expect all green except the pre-existing `BiometricViewModelTest.enrollFace` failure (tracked under Phase D of `client-apps/docs/TODO.md`).
3. Manual smoke tests on an Android device:
   - Passport BAC → MRZ scanner captures, DG1/DG2 read, server accepts (Gap #1).
   - Profile → Download my data → JSON lands in Downloads (Gap #2).
   - FCM Allow action POSTs signed approval; `fivucsas://nfc-session/<id>` deep-link opens app on correct screen (Gap #3).
   - Settings → Theme → Light/Dark/System radio flips palette live (Gap #4).
   - Authenticator → Scan QR → ML Kit reads `otpauth://totp/...` QR, account added (Gap #5).
4. Update `client-apps/CHANGELOG.md` `[Unreleased] — v5.2.0 planning` section to `[5.2.0] — <date>` with done items checked off.
5. Tag `v5.2.0` on `client-apps` submodule. Build signed release APK via `./gradlew :androidApp:assembleRelease` (requires `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD` — see `client-apps/docs/RELEASE.md`).
6. Update parent `CHANGELOG.md` with the v5.2.0 shipping entry; bump submodule pointer.

## Verification per wave

| Wave | Command | Expected |
|------|---------|----------|
| 1 | `git diff --stat` on parent repo | 8 files changed (plus the new `PATH_TO_20_20.md`). |
| 2 (all 5) | `./gradlew :shared:test` | 424 + new tests green. |
| 2 (all 5) | `./gradlew :androidApp:assembleDebug` | APK produced. |
| 2 (all 5) | `./gradlew :androidApp:testDebugUnitTest` | Green except `BiometricViewModelTest.enrollFace` (pre-existing). |
| 4 | `./gradlew :androidApp:assembleRelease` | Signed release APK with the rotated keystore credentials. |
| 4 | Manual device smoke (5 flows above) | All five flows succeed end-to-end. |

## Out of scope

- **iOS / macOS parity.** DROPPED 2026-04-26 — permanently out of scope. The product owner has no Apple hardware for development, signing, or testing. Android APK + Windows + Linux desktop cover the demonstration target. Pre-existing KMP `iosMain` directories remain in the codebase for compile structure but receive no further engineering work.
- **Desktop NFC + installer signing.** PC/SC NFC stack and Windows Authenticode are Phase 3 of `CLIENT_APPS_PARITY.md`. macOS notarization is dropped (no Mac hardware). Tracked under `client-apps/docs/TODO.md` Phase C.
- **GitGuardian #29836028 keystore rotation.** User-gated; full playbook in `docs/SECURITY_INCIDENTS.md`. Rotation scaffolding already shipped (`cb6eab9`), but actual `keytool -storepasswd` + `keytool -keypasswd` + GitHub-secret paste is a manual operator action.
- **Phase C Wave 0 secret rotation.** PostgreSQL / Redis / JWT / Twilio / biometric / Hostinger SMTP rotation + `.env.prod` history purge requires a scheduled 2-hour maintenance window. Tracked as Phase C1–C5 in parent `ROADMAP.md`.
- **Biometric-processor 79 CVE triage.** Separate workstream; independent of client-apps 20/20 push.
- **Pre-existing `BiometricViewModelTest.enrollFace` failure.** Known red test on `client-apps`; does not block 20/20 or v5.2.0 tag. Tracked under Phase D of `client-apps/docs/TODO.md`.

## Cross-references

- [`docs/plans/CLIENT_APPS_PARITY.md`](./CLIENT_APPS_PARITY.md) — feature matrix; Phase 2 (Desktop Win+Linux) roadmap. iOS dropped 2026-04-26.
- [`docs/plans/NFC_PUSH_APPROVAL_PROTOCOL.md`](./NFC_PUSH_APPROVAL_PROTOCOL.md) — cross-device NFC handoff spec; `fivucsas://nfc-session` deep link, Ed25519 device registration, FCM/APNS push payload, V39 migration sketch, 13-threat security review.
