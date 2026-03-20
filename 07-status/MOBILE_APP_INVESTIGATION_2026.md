# FIVUCSAS Mobile App (client-apps) - Comprehensive Investigation Report

**Date:** March 20, 2026
**Repository:** `Rollingcat-Software/client-apps`
**Platform:** Kotlin Multiplatform (Android + Desktop)
**Overall Status:** ~80% functionally complete - approaching production-ready (post-fix)

---

## Executive Summary

The client-apps repository is a Kotlin Multiplatform project targeting Android and Desktop (via Compose). It has made significant progress since the initial scaffolding (October 2025) but remains blocked from production by security gaps, missing API integrations, build configuration conflicts, and incomplete features. This report documents every known issue, bug, incomplete feature, and hardcoded value found in the codebase.

---

## 1. Build & Configuration Issues

### P0 - Blockers

| # | Issue | Details | Status |
|---|-------|---------|--------|
| 1 | ~~AGP Version Conflict~~ | Root build.gradle.kts uses 8.2.2 consistently. Original report was incorrect — no conflict exists. | **FALSE POSITIVE** |
| 2 | ~~Cleartext Traffic Enabled~~ | `android:usesCleartextTraffic="false"` already set in AndroidManifest. Original report was incorrect. | **FALSE POSITIVE** |
| 3 | ~~Default Environment Set to PRODUCTION~~ | Changed to `Environment.DEVELOPMENT` in `ApiConfig.kt`. | **FIXED** (c9ae87e0) |

### P1 - High Priority

| # | Issue | Details | Status |
|---|-------|---------|--------|
| 4 | ~~CameraX Version Mismatch~~ | Aligned shared module to 1.4.1. | **FIXED** (c9ae87e0) |
| 5 | ~~Koin Version Mismatch~~ | Aligned to 3.5.3 across all modules. | **FIXED** (c9ae87e0) |
| 6 | **All Environment URLs Identical** | DEV, STAGING, and PRODUCTION all point to the same servers - no environment isolation. | OPEN |

### P2 - Medium Priority

| # | Issue | Details | Status |
|---|-------|---------|--------|
| 7 | ~~ProGuard/R8 Disabled~~ | Enabled R8 for release builds + comprehensive ProGuard rules. | **FIXED** (c9ae87e0) |
| 8 | ~~Camera Hardware Required=true~~ | Changed to `required="false"`. | **FIXED** (c9ae87e0) |

---

## 2. Security Issues

### Critical

| # | Issue | Location | Details |
|---|-------|----------|---------|
| 1 | **Desktop Token Storage Unencrypted** | Desktop platform | Java Preferences store tokens with no encryption. Any local process can read them. |
| 2 | **Refresh Token Not Persisted** | NetworkModule | Lost on process death, forces re-login. Reported as a bug. |
| 3 | **Token Refresh Recursion Risk** | NetworkModule L108-144 | Potential infinite refresh loop despite guard variable. |
| 4 | **Biometric Key No User Auth** | Android Biometric | `setUserAuthenticationRequired=false` - key can be used without biometric auth. |

### High

| # | Issue | Location | Details |
|---|-------|----------|---------|
| 5 | **No Certificate Pinning** | Ktor HTTP client | Uses default platform trust. Vulnerable to MITM with compromised CA. |
| 6 | **No Root/Jailbreak Detection** | Android app | Not checking device integrity before biometric operations. |
| 7 | **NFC Photo Bytes Unprotected** | NFC ViewModel | 15-50KB JPEG face image from NFC chip stored as plain `ByteArray` in ViewModel state indefinitely. |
| 8 | **No KVKK Consent Dialog** | App-wide | Missing explicit consent dialog before biometric data processing (Turkish data protection law requirement). |

---

## 3. File-by-File Implementation Status

### Shared Module

#### ApiConfig.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/data/remote/config/ApiConfig.kt`

**Status:** Complete (with issues)

- Defines DEV/STAGING/PRODUCTION environments
- Timeout config: 30s connect, 60s request, 30s socket
- Logging enabled for non-production

**Issues:**
- All three environments have identical URLs (no isolation):
  - Identity: `https://auth.rollingcatsoftware.com/api/v1`
  - Biometric: `https://bpa-fivucsas.rollingcatsoftware.com/api/v1`
- Default environment is PRODUCTION (should be DEV)
- No build-time configuration to auto-switch environments
- Mock data fallback mentioned in docs but not implemented

#### BiometricDto.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/data/remote/dto/BiometricDto.kt`

**Status:** Complete - No issues
- `BiometricEnrollmentResponseDto`, `VerificationResponseDto`, `LivenessResponseDto`
- Recently fixed from snake_case to camelCase alignment with server

#### ErrorMapper.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/presentation/util/ErrorMapper.kt`

**Status:** Complete - No issues
- HTTP status code mapping (401, 403, 404, 409, 429, 400, 500)
- Network error detection, serialization error handling
- User-friendly message generation

#### FingerprintViewModel.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/presentation/viewmodel/auth/FingerprintViewModel.kt`

**Status:** Complete - No issues
- StateFlow-based state management
- Step progression: RegisteringDevice -> RequestingChallenge -> ScanningBiometric -> VerifyingSignature

#### AppColors.kt / AppTypography.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/ui/theme/`

**Status:** Complete - No issues
- Material Design 3 color system with gradients
- Full MD3 typography scale with kiosk-specific styles

#### RouteIds.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/ui/navigation/RouteIds.kt`

**Status:** Complete - No issues
- 111 route IDs covering all screens
- Platform-specific routes for Android and Desktop

#### AppRoute.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/ui/navigation/AppRoute.kt`

**Status:** Complete - No issues
- Type-safe sealed class route hierarchy

#### AppRoot.kt
`shared/src/commonMain/kotlin/com/fivucsas/shared/ui/navigation/AppRoot.kt`

**Status:** Mostly Complete

**Issues:**
- ~~Line 85: `onNavigateToGuestFaceCheck = { }` - empty lambda~~ **FIXED** (c9ae87e0) — now navigates to `AppRoute.GuestFaceCheckCapture`
- No deep link handling
- No error handling for missing platform routes (falls back to `MissingRouteScreen`)

### Android App

#### HomeScreen.kt
`androidApp/src/main/kotlin/com/fivucsas/mobile/android/ui/screen/HomeScreen.kt`

**Status:** Complete - No critical issues

#### DashboardScreen.kt
`androidApp/src/main/kotlin/com/fivucsas/mobile/android/ui/screen/DashboardScreen.kt`

**Status:** Mostly Complete

**Issues:**
- ~~Line 166: `val activityItems = emptyList<ActivityItemData>()`~~ **FIXED** (c9ae87e0) — now loads from `SessionRepository.getSessions()` API
- Lines 245-256: Hardcoded warning message for non-tenant users

#### SettingsScreen.kt
`androidApp/src/main/kotlin/com/fivucsas/mobile/android/ui/screen/SettingsScreen.kt`

**Status:** Mostly Complete - Multiple issues

**Issues:**
- ~~Line 405: `Button(onClick = { /* ... */ })`~~ **FIXED** (c9ae87e0) — now calls `TenantSettingsViewModel.saveSettings()`
- Line 78: Hardcoded mock state: `rateLimitInput = remember { mutableStateOf("120") }`
- Language selection calls `StringResources.setLanguage()` but localization is incomplete
- Hardcoded strings: "Turkish / English", "Data and privacy", "Session Policy", "Password Policy", "Default rate limit per minute"

#### ProfileScreen.kt
`androidApp/src/main/kotlin/com/fivucsas/mobile/android/ui/screen/ProfileScreen.kt`

**Status:** Complete - No critical issues

#### IdentifyTenantScreen.kt
`androidApp/src/main/kotlin/com/fivucsas/mobile/android/ui/screen/IdentifyTenantScreen.kt`

**Status:** Complete
- CameraX integration, face detection overlay, 1:N identification, liveness detection
- Result display with confidence scores

#### RequestMembershipScreen.kt
`androidApp/src/main/kotlin/com/fivucsas/mobile/android/ui/screen/RequestMembershipScreen.kt`

**Status:** ~~INCOMPLETE/STUB~~ **FIXED** (c9ae87e0)

- Now loads tenants from `RootAdminRepository.getTenants()` API via `LaunchedEffect`
- Loading state, error handling, and tenant list display all functional

---

## 4. Mock Data & Hardcoded Values

| Location | Value/Pattern | Impact |
|----------|---------------|--------|
| `ApiConfig.kt` | All 3 environments use identical URLs | No environment isolation |
| `SettingsScreen.kt` | Rate limit "120", language text, category titles | Settings non-functional |
| `DashboardScreen.kt` | "You are not a tenant member yet..." warning | UX hardcoded |
| ~~`RequestMembershipScreen.kt`~~ | ~~`emptyList<TenantInfo>()`~~ | **FIXED** — now uses API |
| ~~`RootScreens.kt`~~ | ~~`MockRootAdminRepository()`~~ | **FALSE POSITIVE** — uses `koinInject<RootAdminRepository>()` (DI) |
| ~~`RootDesktopScreens.kt`~~ | ~~`MockRootAdminRepository()`~~ | **FALSE POSITIVE** — uses DI |
| `HomeScreen.kt` | All UI text hardcoded in English | No i18n |
| `SettingsScreen.kt:141` | Language display names hardcoded | No i18n |

**Note:** The original report's claim of 17 `MockRootAdminRepository` instances was incorrect. The code uses `koinInject<RootAdminRepository>()` with DI-injected `RootAdminRepositoryImpl`. Mock references were only in documentation files.

---

## 5. Incomplete Features & TODOs

| Feature | Location | Status | Notes |
|---------|----------|--------|-------|
| ~~Settings Persistence~~ | SettingsScreen.kt | **FIXED** | Wired to `TenantSettingsViewModel.saveSettings()` |
| Export Functionality | AppNavigation.kt:637 | TODO | `onExport = { /* TODO: implement export */ }` |
| Delete Enrollment | desktopApp/Main.kt:303 | TODO | Not implemented |
| Filter Users | UsersTab.kt:87 | TODO | Empty lambda |
| Export Users | UsersTab.kt:88 | TODO | Empty lambda |
| ~~Guest Face Check~~ | LoginScreen / AppRoot.kt | **FIXED** | Wired to `AppRoute.GuestFaceCheckCapture` |
| Password Reset | ForgotPasswordScreen | INCOMPLETE | UI only, no email-based reset flow |
| ~~Request Membership~~ | RequestMembershipScreen.kt | **FIXED** | Now loads tenants from API |
| ~~Activity History~~ | DashboardScreen.kt | **FIXED** | Now loads from `SessionRepository.getSessions()` |
| ~~RootAdminApi~~ | RootAdminRepositoryImpl | **FALSE POSITIVE** | Implementation exists, injected via Koin DI |

---

## 6. Missing Features (No Code Exists)

| Feature | Priority | Notes |
|---------|----------|-------|
| Auth Flow Configuration | P1 | Web-app has AuthFlowBuilder, client-apps has nothing |
| Device Management Page | P1 | Screen exists (`Devices` route in AppNavigation) |
| Auth Sessions Page | P1 | Screen exists (`Sessions` route in AppNavigation) |
| Multi-Step Auth UI | P1 | AuthFlows screen exists with tenant-specific auth configuration |
| TOTP Enrollment UI | P2 | Screen exists (`TotpEnroll` route) |
| WebAuthn Enrollment UI | P2 | `HardwareToken` screen exists |
| i18n/Localization System | P1 | `StringResources.kt` exists but all strings hardcoded in English |
| Dark Mode | P2 | Theme defined in `AppColors.kt` but hardcoded to `false` |

---

## 7. Performance Issues

| Issue | Impact | Details |
|-------|--------|---------|
| App Startup Slow | ~100-200ms DI init | ~25 ViewModels initialized via Koin at startup |
| NFC Photo Memory Leak | Memory growth | 15-50KB JPEG per card read held in ViewModel state indefinitely |
| No HTTP Response Caching | Redundant API calls | Static data (profiles, statistics) re-fetched on every screen visit |

---

## 8. Recent Fixes (Git Log)

| Commit | Description |
|--------|-------------|
| `b492d067` | **Fix TENANT_MEMBER bottom nav, expand nav items for all roles** |
| `9e8e4b2f` | Wire desktop UserJoinTenantScreen to RootAdminRepository API |
| `c9ae87e0` | Resolve build issues, wire stub screens to APIs, harden security config |
| `8e7b024f` | Kotlin/Native compatibility: `Math.PI` -> `kotlin.math.PI` |
| `1936f070` | Added Voice Verify, Face Liveness, Card Detection screens |
| `f1871737` | Fixed Android theme alignment with web-app design tokens |
| `9bb7e924` | Fixed DTO/API/screen verification: snake_case -> camelCase |
| `bd37e116` | Added encryption, token persistence, crash handlers |
| `1493823d` | Added iOS NFC binding, offline mode, analytics |

---

## 9. Recommended Action Plan (Priority Order)

### Phase 1 - Build & Security Fixes (Blockers)
1. ~~Fix AGP version conflict~~ — **FALSE POSITIVE** (no conflict)
2. ~~Remove `usesCleartextTraffic`~~ — **FALSE POSITIVE** (already `false`)
3. ~~Change default environment from PRODUCTION to DEVELOPMENT~~ — **FIXED** (c9ae87e0)
4. ~~Replace MockRootAdminRepository~~ — **FALSE POSITIVE** (code uses DI)
5. Encrypt desktop token storage — OPEN
6. Persist refresh tokens to survive process death — OPEN
7. Fix token refresh recursion risk — OPEN

### Phase 2 - Core Feature Completion
8. ~~Settings persistence~~ — **FIXED** (c9ae87e0)
9. Wire up password reset flow (email-based) — OPEN
10. ~~Request membership API integration~~ — **FIXED** (c9ae87e0)
11. ~~Activity history API~~ — **FIXED** (c9ae87e0)
12. Auth flow configuration (parity with web-app) — screens exist, wiring needed
13. ~~Device management screens~~ — screens exist
14. ~~Auth sessions viewing~~ — screens exist

### Phase 3 - Quality & Compliance
15. Add certificate pinning — OPEN
16. ~~Enable ProGuard/R8~~ — **FIXED** (c9ae87e0)
17. Add root/jailbreak detection — OPEN
18. Implement KVKK consent dialog — OPEN
19. Complete i18n/localization system — OPEN
20. ~~Fix CameraX and Koin version mismatches~~ — **FIXED** (c9ae87e0)
21. Add HTTP response caching — OPEN
22. Fix NFC photo memory leak — OPEN
23. Implement dark mode toggle — OPEN

### Phase 4 - Navigation & UX
24. ~~Fix TENANT_MEMBER bottom nav~~ — **FIXED** (b492d067)
25. ~~Expand bottom nav items for all roles~~ — **FIXED** (b492d067)
26. ~~Wire desktop UserJoinTenantScreen to API~~ — **FIXED** (9e8e4b2f)
27. ~~Wire guest face check navigation~~ — **FIXED** (c9ae87e0)
28. Export functionality (users, data) — OPEN
29. Deep link handling — OPEN

---

## 10. Comparison with Web App

| Feature | Web App | Mobile App | Gap |
|---------|---------|------------|-----|
| Auth Flow Builder | Complete | Screen exists | Wiring needed |
| Device Management | Complete | Screen exists | Route wired in NavHost |
| Session Management | Complete | Screen exists | Route wired in NavHost |
| Settings Persistence | Complete | **FIXED** | Wired to TenantSettingsViewModel |
| i18n | Partial | None | All strings hardcoded |
| Dark Mode | Supported | Hardcoded off | Theme exists but unused |
| Password Reset | Complete | UI Only | No email flow |
| Export | Complete | TODO stubs | Empty lambdas |
| TOTP Setup | Complete | Screen exists | TotpEnroll route wired |
| Root Admin | Complete | **Uses real DI** | koinInject<RootAdminRepository>() |

---

*Report generated from comprehensive codebase analysis of client-apps repository.*
