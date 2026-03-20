# FIVUCSAS Mobile App (client-apps) - Comprehensive Investigation Report

**Date:** March 20, 2026
**Repository:** `Rollingcat-Software/client-apps`
**Platform:** Kotlin Multiplatform (Android + Desktop)
**Overall Status:** ~70% functionally complete - NOT production-ready

---

## Executive Summary

The client-apps repository is a Kotlin Multiplatform project targeting Android and Desktop (via Compose). It has made significant progress since the initial scaffolding (October 2025) but remains blocked from production by security gaps, missing API integrations, build configuration conflicts, and incomplete features. This report documents every known issue, bug, incomplete feature, and hardcoded value found in the codebase.

---

## 1. Build & Configuration Issues

### P0 - Blockers

| # | Issue | Details |
|---|-------|---------|
| 1 | **AGP Version Conflict** | `build.gradle.kts` declares conflicting Android Gradle Plugin versions: 8.9.2 vs 8.2.2. This will cause build failures or unpredictable behavior. |
| 2 | **Cleartext Traffic Enabled** | `android:usesCleartextTraffic="true"` in `AndroidManifest.xml` allows unencrypted HTTP traffic. Must be removed before production. |
| 3 | **Default Environment Set to PRODUCTION** | `ApiConfig.kt` line 21 defaults to `PRODUCTION`. Should default to `DEVELOPMENT` to prevent accidental production usage during development. |

### P1 - High Priority

| # | Issue | Details |
|---|-------|---------|
| 4 | **CameraX Version Mismatch** | shared module uses 1.3.1, androidApp uses 1.4.1. May cause runtime crashes. |
| 5 | **Koin Version Mismatch** | 3.5.0 vs 3.5.3 across modules. |
| 6 | **All Environment URLs Identical** | DEV, STAGING, and PRODUCTION all point to the same servers - no environment isolation. |

### P2 - Medium Priority

| # | Issue | Details |
|---|-------|---------|
| 7 | **ProGuard/R8 Disabled** | APK ships unobfuscated - code can be trivially reverse-engineered. |
| 8 | **Camera Hardware Required=true** | `uses-feature` blocks installation on devices without cameras. Should use `required="false"` with runtime checks. |

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
- Line 85: `onNavigateToGuestFaceCheck = { }` - empty lambda, guest face check not wired
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
- Line 166: `val activityItems = emptyList<ActivityItemData>()` - activity items never loaded from API
- Lines 245-256: Hardcoded warning message for non-tenant users
- Comment: "Activity items will be loaded from API when available; show empty state for now"

#### SettingsScreen.kt
`androidApp/src/main/kotlin/com/fivucsas/mobile/android/ui/screen/SettingsScreen.kt`

**Status:** Mostly Complete - Multiple issues

**Issues:**
- Line 405: `Button(onClick = { /* System settings save not yet implemented */ })` - TODO
- Line 78: Hardcoded mock state: `rateLimitInput = remember { mutableStateOf("120") }`
- **Settings are never persisted to backend** - no API calls for any settings modifications
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

**Status:** INCOMPLETE/STUB

**Issues:**
- Line 54: `val allTenants = remember { emptyList<TenantInfo>() }` - hardcoded empty list
- Comment: "Tenants will be loaded from API when endpoint is available"
- **Zero backend integration** - no API to fetch tenants, no submission to backend
- Line 170: Success message shown but no actual API call made

---

## 4. Mock Data & Hardcoded Values

| Location | Value/Pattern | Impact |
|----------|---------------|--------|
| `ApiConfig.kt` | All 3 environments use identical URLs | No environment isolation |
| `SettingsScreen.kt` | Rate limit "120", language text, category titles | Settings non-functional |
| `DashboardScreen.kt` | "You are not a tenant member yet..." warning | UX hardcoded |
| `RequestMembershipScreen.kt` | `emptyList<TenantInfo>()` | Feature non-functional |
| `RootScreens.kt` (9 instances) | `MockRootAdminRepository()` | Admin features use fake data |
| `RootDesktopScreens.kt` (8 instances) | `MockRootAdminRepository()` | Desktop admin uses fake data |
| `HomeScreen.kt` | All UI text hardcoded in English | No i18n |
| `SettingsScreen.kt:141` | Language display names hardcoded | No i18n |

**Total:** 17 instances of `MockRootAdminRepository` in production code paths (P0 blocker).

---

## 5. Incomplete Features & TODOs

| Feature | Location | Status | Notes |
|---------|----------|--------|-------|
| Settings Persistence | SettingsScreen.kt:405 | TODO | UI exists but no save() call |
| Export Functionality | AppNavigation.kt:637 | TODO | `onExport = { /* TODO: implement export */ }` |
| Delete Enrollment | desktopApp/Main.kt:303 | TODO | Not implemented |
| Filter Users | UsersTab.kt:87 | TODO | Empty lambda |
| Export Users | UsersTab.kt:88 | TODO | Empty lambda |
| Guest Face Check | LoginScreen | STUB | Empty lambda |
| Password Reset | ForgotPasswordScreen | INCOMPLETE | UI only, no email-based reset flow |
| Request Membership | RequestMembershipScreen.kt | STUB | Empty tenant list, no API |
| Activity History | DashboardScreen.kt:166 | STUB | Empty list, no API |
| RootAdminApi Implementation | (missing) | MISSING | Interface exists, no implementation class |

---

## 6. Missing Features (No Code Exists)

| Feature | Priority | Notes |
|---------|----------|-------|
| Auth Flow Configuration | P1 | Web-app has AuthFlowBuilder, client-apps has nothing |
| Device Management Page | P1 | No screens to list/manage registered devices |
| Auth Sessions Page | P1 | No UI to view active sessions |
| Multi-Step Auth UI | P1 | No UI for complex auth flows |
| TOTP Enrollment UI | P2 | No QR-based TOTP setup screen |
| WebAuthn Enrollment UI | P2 | No hardware key registration screen |
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
| `8e7b024f` | Kotlin/Native compatibility: `Math.PI` -> `kotlin.math.PI` |
| `1936f070` | Added Voice Verify, Face Liveness, Card Detection screens |
| `f1871737` | Fixed Android theme alignment with web-app design tokens |
| `9bb7e924` | Fixed DTO/API/screen verification: snake_case -> camelCase |
| `bd37e116` | Added encryption, token persistence, crash handlers |
| `1493823d` | Added iOS NFC binding, offline mode, analytics |

---

## 9. Recommended Action Plan (Priority Order)

### Phase 1 - Build & Security Fixes (Blockers)
1. Fix AGP version conflict (8.9.2 vs 8.2.2)
2. Remove `usesCleartextTraffic="true"` from AndroidManifest
3. Change default environment from PRODUCTION to DEVELOPMENT
4. Implement `RootAdminApiImpl` and replace all 17 `MockRootAdminRepository` instances
5. Encrypt desktop token storage
6. Persist refresh tokens to survive process death
7. Fix token refresh recursion risk

### Phase 2 - Core Feature Completion
8. Implement settings persistence (API integration)
9. Wire up password reset flow (email-based)
10. Implement request membership API integration
11. Connect activity history to API
12. Implement auth flow configuration (parity with web-app)
13. Add device management screens
14. Add auth sessions viewing

### Phase 3 - Quality & Compliance
15. Add certificate pinning
16. Enable ProGuard/R8 code obfuscation
17. Add root/jailbreak detection
18. Implement KVKK consent dialog
19. Complete i18n/localization system
20. Fix CameraX and Koin version mismatches
21. Add HTTP response caching
22. Fix NFC photo memory leak
23. Implement dark mode toggle

### Phase 4 - Feature Parity
24. TOTP enrollment UI
25. WebAuthn enrollment UI
26. Multi-step auth UI
27. Export functionality (users, data)
28. Guest face check flow
29. Deep link handling

---

## 10. Comparison with Web App

| Feature | Web App | Mobile App | Gap |
|---------|---------|------------|-----|
| Auth Flow Builder | Complete | Missing | Full feature missing |
| Device Management | Complete | Missing | Full feature missing |
| Session Management | Complete | Missing | Full feature missing |
| Settings Persistence | Complete | UI Only | No backend calls |
| i18n | Partial | None | All strings hardcoded |
| Dark Mode | Supported | Hardcoded off | Theme exists but unused |
| Password Reset | Complete | UI Only | No email flow |
| Export | Complete | TODO stubs | Empty lambdas |
| TOTP Setup | Complete | Missing | No screens |
| Root Admin | Complete | Mock Data | 17 mock repository instances |

---

*Report generated from comprehensive codebase analysis of client-apps repository.*
