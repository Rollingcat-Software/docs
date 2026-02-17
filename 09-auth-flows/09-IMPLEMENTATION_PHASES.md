# Implementation Phases

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document provides a phased implementation roadmap with file-level specificity for all 4 services: Identity Core API (Java), Web App (React), Client Apps (Kotlin), and Biometric Processor (Python).

---

## 2. Phase Summary

| Phase | Focus | Key Deliverables |
|---|---|---|
| **Phase 1** | Backend Foundation | DB migration, entities, auth flow CRUD, basic session flow |
| **Phase 2** | Core Auth Handlers | Password, Face, Email OTP, QR Code handlers |
| **Phase 3** | Advanced Auth Handlers | TOTP, Fingerprint (FIDO2), SMS OTP, Hardware Key |
| **Phase 4** | Cross-Device Delegation | WebSocket, QR bridge, companion device flow |
| **Phase 5** | Web App Admin UI | Auth methods page, flow builder, enrollment wizard |
| **Phase 6** | Client Apps Integration | Multi-step auth, device registration, NFC/fingerprint |
| **Phase 7** | Voice Recognition | Biometric processor voice endpoints, enrollment flow |
| **Phase 8** | Testing & Polish | Integration tests, load tests, UX refinement |

---

## 3. Phase 1: Backend Foundation

### 3.1 Flyway Migration

**File**: `identity-core-api/src/main/resources/db/migration/V16__auth_flow_system.sql`

Content: All 8 new tables + indexes + constraints + seed data (see 04-DATABASE_SCHEMA.md)

### 3.2 New Enums

```
identity-core-api/src/main/java/com/fivucsas/identity/domain/model/auth/
├── AuthMethodType.java          // PASSWORD, FACE, FINGERPRINT, etc.
├── OperationType.java           // APP_LOGIN, DOOR_ACCESS, etc.
├── AuthSessionStatus.java       // CREATED, IN_PROGRESS, COMPLETED, etc.
├── AuthStepStatus.java          // PENDING, IN_PROGRESS, COMPLETED, etc.
├── EnrollmentStatus.java        // NOT_ENROLLED, PENDING, ENROLLED, etc.
└── DevicePlatform.java          // WEB, ANDROID, IOS, DESKTOP
```

### 3.3 New Entities

```
identity-core-api/src/main/java/com/fivucsas/identity/entity/
├── AuthMethod.java              // System auth method definition
├── TenantAuthMethod.java        // Per-tenant method config
├── AuthFlow.java                // Auth flow definition
├── AuthFlowStep.java            // Step within flow
├── AuthSession.java             // Runtime auth session
├── AuthSessionStep.java         // Per-step execution record
├── UserDevice.java              // Registered device
└── UserEnrollment.java          // Per-user enrollment status
```

### 3.4 New Repositories

```
identity-core-api/src/main/java/com/fivucsas/identity/repository/
├── AuthMethodRepository.java
├── TenantAuthMethodRepository.java
├── AuthFlowRepository.java
├── AuthFlowStepRepository.java
├── AuthSessionRepository.java
├── AuthSessionStepRepository.java
├── UserDeviceRepository.java
└── UserEnrollmentRepository.java
```

### 3.5 New Ports (Use Cases)

```
identity-core-api/src/main/java/com/fivucsas/identity/application/port/input/
├── ManageAuthMethodUseCase.java        // List/configure auth methods
├── ManageAuthFlowUseCase.java          // CRUD auth flows
├── ExecuteAuthSessionUseCase.java      // Start/step/complete sessions
├── ManageDeviceUseCase.java            // Register/list/remove devices
└── ManageEnrollmentUseCase.java        // Start/complete/revoke enrollments
```

### 3.6 New DTOs

```
identity-core-api/src/main/java/com/fivucsas/identity/application/dto/
├── command/
│   ├── CreateAuthFlowCommand.java
│   ├── UpdateAuthFlowCommand.java
│   ├── StartAuthSessionCommand.java
│   ├── CompleteAuthStepCommand.java
│   ├── RegisterDeviceCommand.java
│   └── StartEnrollmentCommand.java
├── response/
│   ├── AuthMethodResponse.java
│   ├── TenantAuthMethodResponse.java
│   ├── AuthFlowResponse.java
│   ├── AuthFlowStepResponse.java
│   ├── AuthSessionResponse.java
│   ├── StepResultResponse.java
│   ├── DeviceResponse.java
│   └── EnrollmentResponse.java
└── request/
    ├── CreateAuthFlowRequest.java
    ├── StartAuthSessionRequest.java
    ├── CompleteStepRequest.java
    ├── RegisterDeviceRequest.java
    └── DelegationRequest.java
```

### 3.7 New Services

```
identity-core-api/src/main/java/com/fivucsas/identity/application/service/
├── ManageAuthMethodService.java
├── ManageAuthFlowService.java
├── ExecuteAuthSessionService.java      // Core session orchestration
├── ManageDeviceService.java
├── ManageEnrollmentService.java
└── AuthMethodHandlerRegistry.java      // Strategy dispatcher
```

### 3.8 New Controllers

```
identity-core-api/src/main/java/com/fivucsas/identity/controller/
├── AuthMethodController.java           // GET /api/v1/auth-methods
├── TenantAuthMethodController.java     // /api/v1/tenants/{id}/auth-methods
├── AuthFlowController.java             // /api/v1/tenants/{id}/auth-flows
├── AuthSessionController.java          // /api/v1/auth/sessions
├── DeviceController.java               // /api/v1/devices
└── EnrollmentManagementController.java // /api/v1/users/{id}/enrollments
```

### 3.9 Modified Files

| File | Change |
|---|---|
| `entity/Tenant.java` | Add `@OneToMany` to `TenantAuthMethod` |
| `entity/User.java` | Add `@OneToMany` to `UserEnrollment`, `UserDevice` |
| `config/SecurityConfig.java` | Add security rules for new endpoints |
| `config/WebMvcConfig.java` | Register new interceptors |

### 3.10 New RBAC Permissions (Seed in V16)

```sql
INSERT INTO permissions (name, description, resource) VALUES
('auth_flow:read', 'Read auth flows', 'auth_flow'),
('auth_flow:create', 'Create auth flows', 'auth_flow'),
('auth_flow:update', 'Update auth flows', 'auth_flow'),
('auth_flow:delete', 'Delete auth flows', 'auth_flow'),
('auth_method:read', 'Read auth methods', 'auth_method'),
('auth_method:configure', 'Configure auth methods', 'auth_method'),
('device:read', 'Read devices', 'device'),
('device:register', 'Register devices', 'device'),
('device:delete', 'Delete devices', 'device'),
('enrollment:read', 'Read enrollments', 'enrollment'),
('enrollment:create', 'Create enrollments', 'enrollment'),
('enrollment:delete', 'Delete enrollments', 'enrollment');
```

---

## 4. Phase 2: Core Auth Method Handlers

### 4.1 Handler Interface

```
identity-core-api/src/main/java/com/fivucsas/identity/application/service/handler/
├── AuthMethodHandler.java              // Interface
├── PasswordAuthHandler.java            // BCrypt validation
├── EmailOtpAuthHandler.java            // OTP generation + validation
├── FaceAuthHandler.java                // Delegate to BiometricServicePort
└── QrCodeAuthHandler.java              // QR token validation
```

### 4.2 Supporting Infrastructure

```
identity-core-api/src/main/java/com/fivucsas/identity/infrastructure/
├── otp/
│   ├── OtpService.java                 // Generate/validate OTP codes
│   └── OtpStore.java                   // Redis-backed OTP storage
├── qrcode/
│   ├── QrCodeService.java              // Generate/validate QR tokens
│   └── QrTokenEncryptor.java           // AES-256-GCM encryption
└── email/
    └── EmailService.java               // Send OTP emails
```

### 4.3 Modified Auth Flow

Refactor `AuthenticateUserService.java`:
- Keep existing password-only login path for backward compatibility
- Add new multi-step path that delegates to `AuthMethodHandlerRegistry`
- The existing `POST /auth/login` continues working
- New `POST /auth/sessions` uses the multi-step flow

---

## 5. Phase 3: Advanced Auth Handlers

### 5.1 New Handlers

```
identity-core-api/src/main/java/com/fivucsas/identity/application/service/handler/
├── TotpAuthHandler.java                // RFC 6238 validation
├── SmsOtpAuthHandler.java              // SMS OTP (same as email but SMS)
├── FingerprintAuthHandler.java         // WebAuthn assertion validation
├── HardwareKeyAuthHandler.java         // WebAuthn assertion validation
├── NfcDocumentAuthHandler.java         // Document hash validation
└── VoiceAuthHandler.java               // Delegate to BiometricServicePort
```

### 5.2 WebAuthn Library

Add dependency to `pom.xml`:
```xml
<dependency>
    <groupId>com.yubico</groupId>
    <artifactId>webauthn-server-core</artifactId>
    <version>2.5.0</version>
</dependency>
```

### 5.3 TOTP Library

Add dependency to `pom.xml`:
```xml
<dependency>
    <groupId>dev.samstevens.totp</groupId>
    <artifactId>totp</artifactId>
    <version>1.7.1</version>
</dependency>
```

---

## 6. Phase 4: Cross-Device Delegation

### 6.1 WebSocket Support

```
identity-core-api/src/main/java/com/fivucsas/identity/infrastructure/websocket/
├── WebSocketConfig.java                // @EnableWebSocket configuration
├── AuthSessionWebSocketHandler.java    // Handle session update broadcasts
├── WebSocketSessionManager.java        // Track connected clients per session
└── DelegationService.java              // Delegation token management
```

Add dependency to `pom.xml`:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-websocket</artifactId>
</dependency>
```

### 6.2 Delegation Token Service

```
identity-core-api/src/main/java/com/fivucsas/identity/infrastructure/delegation/
├── DelegationTokenService.java         // Generate/validate delegation JWTs
└── DelegationTokenClaims.java          // Token payload structure
```

### 6.3 Session Cleanup Scheduler

```
identity-core-api/src/main/java/com/fivucsas/identity/infrastructure/scheduler/
└── AuthSessionCleanupScheduler.java    // @Scheduled: expire + cleanup sessions
```

---

## 7. Phase 5: Web App Admin UI

### 7.1 New Features/Services

```
web-app/src/features/
├── authMethods/
│   ├── components/AuthMethodsPage.tsx      // Method enable/disable/configure
│   ├── hooks/useAuthMethods.ts             // State management
│   └── services/AuthMethodService.ts       // API calls
├── authFlows/ (EXISTING - ENHANCE)
│   ├── components/
│   │   ├── AuthFlowBuilder.tsx             // MODIFY: add operation type, step settings, API calls
│   │   ├── AuthFlowsPage.tsx              // MODIFY: list flows, CRUD
│   │   ├── AuthFlowsListPage.tsx          // NEW: flow list with cards
│   │   └── StepSettingsDialog.tsx         // NEW: per-step configuration dialog
│   ├── hooks/useAuthFlows.ts              // NEW: state management
│   └── services/AuthFlowService.ts        // NEW: API calls
├── devices/
│   ├── components/DevicesPage.tsx          // Device list and management
│   ├── hooks/useDevices.ts
│   └── services/DeviceService.ts
└── enrollments/ (EXISTING - ENHANCE)
    ├── components/
    │   ├── EnrollmentWizardPage.tsx        // NEW: self-service enrollment
    │   ├── FaceEnrollment.tsx             // NEW: camera-based face capture
    │   ├── TotpEnrollment.tsx             // NEW: QR code + verification
    │   ├── QrEnrollment.tsx               // NEW: QR badge generation
    │   └── UserEnrollmentsTab.tsx         // NEW: admin enrollment view
    ├── hooks/useEnrollments.ts            // MODIFY: enrollment management
    └── services/EnrollmentService.ts      // MODIFY: enrollment API calls
```

### 7.2 New Repositories

```
web-app/src/core/repositories/
├── AuthMethodRepository.ts
├── AuthFlowRepository.ts
├── DeviceRepository.ts
└── EnrollmentRepository.ts             // MODIFY: add enrollment management
```

### 7.3 New Domain Models

```
web-app/src/domain/models/
├── AuthMethod.ts                       // MODIFY: add OperationType, enrollment status
├── AuthFlow.ts                         // NEW: AuthFlow, AuthFlowStep interfaces
├── AuthSession.ts                      // NEW: AuthSession, StepResult
├── Device.ts                           // NEW: UserDevice interface
└── Enrollment.ts                       // MODIFY: add enrollment management types
```

### 7.4 New DI Registrations

```
web-app/src/core/di/container.ts        // Register new services
```

### 7.5 Route Changes

```
web-app/src/App.tsx                     // Add new routes
web-app/src/components/Sidebar.tsx      // Add nav items
```

---

## 8. Phase 6: Client Apps Integration

### 8.1 New Platform Interfaces

```
client-apps/shared/src/commonMain/kotlin/com/fivucsas/shared/platform/
├── ICameraService.kt                   // EXISTS - pattern to follow
├── INfcService.kt                      // NEW: NFC reading abstraction
├── IFingerprintService.kt              // NEW: biometric prompt abstraction
├── IQrCodeService.kt                   // NEW: QR scan/generate
├── IAudioService.kt                    // NEW: microphone/voice capture
└── IDeviceInfo.kt                      // NEW: device capability reporting
```

### 8.2 Android Implementations

```
client-apps/androidApp/src/main/kotlin/com/fivucsas/mobile/android/platform/
├── AndroidCameraService.kt             // EXISTS
├── AndroidNfcService.kt                // NEW: NfcAdapter + IsoDep
├── AndroidFingerprintService.kt        // NEW: BiometricPrompt
├── AndroidQrCodeService.kt             // NEW: CameraX + ML Kit barcode
├── AndroidAudioService.kt              // NEW: AudioRecord
└── AndroidDeviceInfo.kt                // NEW: device capabilities
```

### 8.3 Desktop Implementations

```
client-apps/desktopApp/src/desktopMain/kotlin/com/fivucsas/desktop/platform/
├── DesktopCameraService.kt             // EXISTS
├── DesktopQrCodeService.kt             // NEW: OpenCV + ZXing
├── DesktopAudioService.kt              // NEW: javax.sound.sampled
└── DesktopDeviceInfo.kt                // NEW: device capabilities
```

### 8.4 Shared Domain Models

```
client-apps/shared/src/commonMain/kotlin/com/fivucsas/shared/domain/model/
├── AuthFlow.kt                         // NEW
├── AuthSession.kt                      // NEW
├── AuthStep.kt                         // NEW
├── UserDevice.kt                       // NEW
└── UserEnrollment.kt                   // NEW
```

### 8.5 Shared Use Cases

```
client-apps/shared/src/commonMain/kotlin/com/fivucsas/shared/domain/usecase/
├── ExecuteAuthFlowUseCase.kt           // NEW: multi-step auth orchestration
├── RegisterDeviceUseCase.kt            // NEW: device capability registration
├── EnrollBiometricUseCase.kt           // NEW: enrollment flows
└── DelegateAuthStepUseCase.kt          // NEW: cross-device delegation
```

### 8.6 New Screens

```
client-apps/shared/src/commonMain/kotlin/com/fivucsas/shared/ui/screen/
├── MultiStepAuthScreen.kt              // NEW: step-by-step auth UI
├── CrossDeviceDelegationScreen.kt      // NEW: QR display + WebSocket wait
├── EnrollmentWizardScreen.kt           // NEW: guided enrollment
├── DeviceRegistrationScreen.kt         // NEW: register + report capabilities
└── NfcReadScreen.kt                    // NEW: NFC document reading UI
```

### 8.7 New ViewModels

```
client-apps/shared/src/commonMain/kotlin/com/fivucsas/shared/presentation/viewmodel/
├── AuthFlowViewModel.kt                // NEW
├── EnrollmentViewModel.kt              // NEW
├── DelegationViewModel.kt              // NEW
└── DeviceViewModel.kt                  // NEW
```

---

## 9. Phase 7: Voice Recognition

### 9.1 Biometric Processor New Endpoints

```
biometric-processor/app/api/routes/
├── voice_routes.py                     // NEW: voice endpoints
```

Endpoints:
```
POST /api/v1/voice/enroll/sample        // Submit single voice sample
POST /api/v1/voice/enroll/finalize      // Finalize enrollment (combine samples)
POST /api/v1/voice/verify               // 1:1 voice verification
POST /api/v1/voice/search               // 1:N voice identification
DELETE /api/v1/voice/enrollments/{id}    // Delete voice enrollment
```

### 9.2 Voice Processing Infrastructure

```
biometric-processor/app/
├── domain/
│   ├── entities/voice_embedding.py     // NEW
│   └── interfaces/voice_port.py        // NEW
├── application/
│   ├── usecases/voice_enroll.py        // NEW
│   └── usecases/voice_verify.py        // NEW
├── infrastructure/
│   ├── ml/voice_model.py              // NEW: ECAPA-TDNN model
│   └── db/voice_repository.py         // NEW: pgvector storage
└── api/
    └── schemas/voice_schemas.py        // NEW: Pydantic schemas
```

### 9.3 ML Model

- **Model**: ECAPA-TDNN (Emphasized Channel Attention, Propagation and Aggregation in TDNN)
- **Embedding**: 192-dimensional speaker embedding
- **Framework**: SpeechBrain or PyAnnote
- **Training**: Pre-trained on VoxCeleb2
- **Storage**: pgvector (same as face embeddings)

See `10-VOICE_RECOGNITION_DESIGN.md` for full details.

---

## 10. Phase 8: Testing & Polish

### 10.1 Backend Tests

```
identity-core-api/src/test/java/com/fivucsas/identity/
├── application/service/
│   ├── ManageAuthFlowServiceTest.java
│   ├── ExecuteAuthSessionServiceTest.java
│   ├── handler/
│   │   ├── PasswordAuthHandlerTest.java
│   │   ├── FaceAuthHandlerTest.java
│   │   ├── TotpAuthHandlerTest.java
│   │   ├── QrCodeAuthHandlerTest.java
│   │   └── FingerprintAuthHandlerTest.java
│   └── AuthMethodHandlerRegistryTest.java
├── controller/
│   ├── AuthFlowControllerTest.java
│   ├── AuthSessionControllerTest.java
│   └── EnrollmentManagementControllerTest.java
└── integration/
    ├── AuthFlowIntegrationTest.java
    ├── MultiStepAuthIntegrationTest.java
    └── CrossDeviceDelegationIntegrationTest.java
```

### 10.2 Web App Tests

- Component tests for AuthFlowBuilder
- Hook tests for useAuthFlows, useAuthMethods
- Service tests for API calls
- E2E flow: create flow -> test flow -> save

### 10.3 Client App Tests

- ViewModel tests for AuthFlowViewModel
- UseCase tests for ExecuteAuthFlowUseCase
- Platform abstraction mock tests
- Integration tests with backend

### 10.4 Load Tests

```
load-tests/
├── auth-session-load-test.js           // k6 script: concurrent auth sessions
├── face-verification-load-test.js      // Concurrent face verifications
└── websocket-delegation-load-test.js   // WebSocket connection stress test
```

---

## 11. Dependency Summary

### 11.1 New Maven Dependencies (identity-core-api)

```xml
<!-- WebSocket -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-websocket</artifactId>
</dependency>

<!-- WebAuthn / FIDO2 -->
<dependency>
    <groupId>com.yubico</groupId>
    <artifactId>webauthn-server-core</artifactId>
    <version>2.5.0</version>
</dependency>

<!-- TOTP -->
<dependency>
    <groupId>dev.samstevens.totp</groupId>
    <artifactId>totp</artifactId>
    <version>1.7.1</version>
</dependency>
```

### 11.2 New NPM Dependencies (web-app)

```json
{
  "qrcode.react": "^3.1.0",
  "jsqr": "^1.4.0"
}
```

### 11.3 New Gradle Dependencies (client-apps)

```kotlin
// ML Kit Barcode (Android)
implementation("com.google.mlkit:barcode-scanning:17.2.0")

// ZXing (Desktop QR)
implementation("com.google.zxing:core:3.5.2")

// OkHttp WebSocket
implementation("com.squareup.okhttp3:okhttp:4.12.0")
```

### 11.4 New Python Dependencies (biometric-processor)

```
speechbrain>=1.0.0        # Voice recognition
torchaudio>=2.0.0         # Audio processing
librosa>=0.10.0           # Audio feature extraction
```

---

## 12. Deployment Order

```
1. identity-core-api V16 migration    → Apply to GCP PostgreSQL
2. identity-core-api new code         → Build JAR → Deploy to GCP VM
3. biometric-processor voice          → Deploy when Cloudflare Tunnel ready
4. web-app                           → Build → Upload to Hostinger
5. client-apps                       → Build APK/Desktop binary
```

Each phase should be deployable independently. Phase 1-4 (backend) must complete before Phase 5-7 (frontend/clients) can fully integrate.
