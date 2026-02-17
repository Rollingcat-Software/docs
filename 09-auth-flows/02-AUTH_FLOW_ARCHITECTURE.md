# Authentication Flow Architecture

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document defines the multi-step authentication flow architecture. A tenant admin configures an **Authentication Flow** — an ordered sequence of authentication steps — that users must complete to gain access to a specific operation (app login, door access, etc.). The system orchestrates the flow via **Auth Sessions**, tracks each step's completion, and supports **cross-device delegation** when the user's primary device lacks required hardware.

---

## 2. Core Concepts

### 2.1 Authentication Flow
An **AuthFlow** is a tenant-scoped, ordered sequence of authentication steps bound to an **operation type**.

```
AuthFlow {
  id: UUID
  tenantId: UUID
  name: "Office Door Access"
  operationType: DOOR_ACCESS
  steps: [
    Step 1: Face Recognition (required, timeout: 30s)
    Step 2: NFC Document (required, timeout: 60s, fallback: QR Code)
  ]
  isDefault: true
  isActive: true
}
```

### 2.2 Operation Types
Each flow targets a specific operation type:

| Operation Type | Code | Description | Typical Flow |
|---|---|---|---|
| Application Login | `APP_LOGIN` | Login to web, mobile, or desktop app | Password + TOTP |
| Door Access | `DOOR_ACCESS` | Physical door/gate unlock | Face or NFC |
| Building Access | `BUILDING_ACCESS` | Building/apartment entry | NFC + Face |
| API Access | `API_ACCESS` | Programmatic API authentication | Hardware Key or TOTP |
| Transaction Approval | `TRANSACTION` | Approve sensitive operations | Password + Face |
| Biometric Enrollment | `ENROLLMENT` | Register biometric data | Password (pre-auth) |
| Guest Access | `GUEST_ACCESS` | Temporary visitor check-in | QR Code |
| Exam Proctoring | `EXAM_PROCTORING` | Identity verification for exams | Face (continuous) |
| Custom | `CUSTOM` | Tenant-defined operation | Configurable |

### 2.3 Auth Session
An **AuthSession** is a runtime instance of an AuthFlow execution. It tracks the user's progress through each step.

### 2.4 Auth Method Handler
Each auth method has a dedicated **handler** (Strategy Pattern) that knows how to validate that specific method's credentials.

---

## 3. Authentication Flow State Machine

### 3.1 Session States

```
                    +----------+
                    |  CREATED |
                    +----+-----+
                         |
                    (first step initiated)
                         |
                    +----v--------+
              +---->| IN_PROGRESS |<----+
              |     +----+--------+     |
              |          |              |
        (step failed,    |         (step completed,
        retries left)    |          more steps remain)
              |          |              |
              +----------+--------------+
                         |
              +----------+----------+
              |                     |
     (all steps completed)   (step failed, no retries,
              |               no fallback, OR timeout)
              |                     |
        +-----v-----+        +-----v----+
        | COMPLETED  |        |  FAILED  |
        +-----+------+        +----------+
              |
        (issue JWT tokens)
```

### 3.2 Step States

```
  +--------+
  | PENDING|
  +---+----+
      |
  (user begins step)
      |
  +---v--------+
  |IN_PROGRESS |
  +---+--------+
      |
  +---+---+----------+-----------+
  |       |          |           |
(pass) (fail,     (fail,      (timeout)
  |    retry)   no retry)       |
  |       |          |           |
  v       v          v           v
+----+ +------+ +--------+ +--------+
|DONE| |RETRY | | FAILED | |EXPIRED |
+----+ +------+ +--------+ +--------+
                     |
               (has fallback?)
                /          \
             YES            NO
              |              |
        +-----v------+  (session FAILED)
        |FALLBACK    |
        |INITIATED   |
        +-----+------+
              |
        (execute fallback method)
```

### 3.3 State Transition Rules

| Current State | Event | Next State | Condition |
|---|---|---|---|
| CREATED | First step initiated | IN_PROGRESS | - |
| IN_PROGRESS | Step completed | IN_PROGRESS | More steps remain |
| IN_PROGRESS | All steps completed | COMPLETED | No more required steps |
| IN_PROGRESS | Step failed | IN_PROGRESS | Retries remaining |
| IN_PROGRESS | Step failed, no retries | FAILED | No fallback method |
| IN_PROGRESS | Step failed, no retries | IN_PROGRESS | Fallback available, switch method |
| IN_PROGRESS | Session timeout | EXPIRED | Session TTL exceeded |
| IN_PROGRESS | User cancels | CANCELLED | User-initiated |
| COMPLETED | - | (terminal) | Issue tokens |
| FAILED | - | (terminal) | Log audit event |
| EXPIRED | - | (terminal) | Cleanup |
| CANCELLED | - | (terminal) | Cleanup |

---

## 4. Detailed Authentication Flow

### 4.1 Session Lifecycle

```
CLIENT                                    IDENTITY CORE API                      BIOMETRIC PROCESSOR
  |                                              |                                      |
  |  1. POST /auth/sessions                      |                                      |
  |    {tenantSlug, operationType, platform,      |                                      |
  |     deviceId, capabilities}                   |                                      |
  |--------------------------------------------->|                                      |
  |                                              |                                      |
  |                                    [Look up tenant's auth flow                      |
  |                                     for this operation type]                         |
  |                                              |                                      |
  |  2. Response: AuthSession                    |                                      |
  |    {sessionId, status: CREATED,              |                                      |
  |     steps: [{order:1, method:PASSWORD,       |                                      |
  |              required:true, timeout:120},     |                                      |
  |             {order:2, method:FACE,           |                                      |
  |              required:true, timeout:60,       |                                      |
  |              fallback: QR_CODE}],            |                                      |
  |     expiresAt: now+10min}                    |                                      |
  |<---------------------------------------------|                                      |
  |                                              |                                      |
  |  3. POST /auth/sessions/{id}/steps/1         |                                      |
  |    {method: PASSWORD,                        |                                      |
  |     data: {email, password}}                 |                                      |
  |--------------------------------------------->|                                      |
  |                                    [Validate password via                            |
  |                                     PasswordAuthHandler]                             |
  |                                              |                                      |
  |  4. Response: StepResult                     |                                      |
  |    {stepId:1, status: COMPLETED,             |                                      |
  |     nextStep: 2}                             |                                      |
  |<---------------------------------------------|                                      |
  |                                              |                                      |
  |  5. POST /auth/sessions/{id}/steps/2         |                                      |
  |    {method: FACE,                            |                                      |
  |     data: {image: base64}}                   |                                      |
  |--------------------------------------------->|                                      |
  |                                    [FaceAuthHandler delegates                        |
  |                                     to BiometricProcessor]                           |
  |                                              |  POST /api/v1/verify                  |
  |                                              |  {userId, image}                      |
  |                                              |------------------------------------->|
  |                                              |                                      |
  |                                              |  {verified: true,                     |
  |                                              |   confidence: 0.95}                   |
  |                                              |<-------------------------------------|
  |                                              |                                      |
  |  6. Response: SessionCompleted               |                                      |
  |    {sessionId, status: COMPLETED,            |                                      |
  |     accessToken, refreshToken,               |                                      |
  |     expiresIn: 86400}                        |                                      |
  |<---------------------------------------------|                                      |
```

### 4.2 Step Execution with Fallback

```
CLIENT                                    IDENTITY CORE API
  |                                              |
  |  POST /auth/sessions/{id}/steps/2            |
  |    {method: NFC_DOCUMENT, data: {...}}        |
  |--------------------------------------------->|
  |                                    [NFC validation fails]
  |                                    [Attempt 1 of 3]
  |  Response: StepFailed                        |
  |    {status: FAILED, attemptsRemaining: 2,    |
  |     canRetry: true}                          |
  |<---------------------------------------------|
  |                                              |
  |  POST /auth/sessions/{id}/steps/2            |
  |    {method: NFC_DOCUMENT, data: {...}}        |
  |--------------------------------------------->|
  |                                    [Attempt 2 fails]
  |                                    [Attempt 3 fails]
  |                                    [No retries left]
  |                                    [Check: has fallback?]
  |                                    [YES: fallback = QR_CODE]
  |                                              |
  |  Response: FallbackActivated                 |
  |    {status: FALLBACK,                        |
  |     originalMethod: NFC_DOCUMENT,            |
  |     fallbackMethod: QR_CODE,                 |
  |     message: "NFC failed. Scan QR instead."} |
  |<---------------------------------------------|
  |                                              |
  |  POST /auth/sessions/{id}/steps/2            |
  |    {method: QR_CODE, data: {qrToken: "..."}} |
  |--------------------------------------------->|
  |                                    [QR validation succeeds]
  |  Response: StepCompleted                     |
  |<---------------------------------------------|
```

### 4.3 Optional Steps

Steps marked `isRequired: false` can be skipped:

```
CLIENT                                    IDENTITY CORE API
  |                                              |
  |  (Step 2 is TOTP, optional)                  |
  |                                              |
  |  POST /auth/sessions/{id}/steps/2/skip       |
  |--------------------------------------------->|
  |                                    [Check: step is optional?]
  |                                    [YES: mark as SKIPPED]
  |  Response: StepSkipped                       |
  |    {nextStep: 3 (or COMPLETED if last)}      |
  |<---------------------------------------------|
```

---

## 5. Auth Method Handler Architecture (Strategy Pattern)

### 5.1 Handler Interface

```java
public interface AuthMethodHandler {
    AuthMethodType getMethodType();
    StepResult validate(AuthSession session, AuthFlowStep step, Map<String, Object> data);
    boolean requiresEnrollment();
    boolean supportsOffline();
    Set<String> requiredDataFields();
}
```

### 5.2 Handler Registry

```java
@Service
public class AuthMethodHandlerRegistry {
    private final Map<AuthMethodType, AuthMethodHandler> handlers;

    public AuthMethodHandlerRegistry(List<AuthMethodHandler> handlerList) {
        this.handlers = handlerList.stream()
            .collect(Collectors.toMap(AuthMethodHandler::getMethodType, h -> h));
    }

    public AuthMethodHandler getHandler(AuthMethodType type) {
        return Optional.ofNullable(handlers.get(type))
            .orElseThrow(() -> new UnsupportedAuthMethodException(type));
    }
}
```

### 5.3 Handler Implementations

| Handler | Method Type | Validation Logic | External Dependency |
|---|---|---|---|
| `PasswordAuthHandler` | PASSWORD | BCrypt hash comparison | UserRepository |
| `EmailOtpAuthHandler` | EMAIL_OTP | Verify 6-digit code against stored OTP | Email service + OTP store |
| `SmsOtpAuthHandler` | SMS_OTP | Verify 6-digit code against stored OTP | SMS gateway + OTP store |
| `TotpAuthHandler` | TOTP | RFC 6238 TOTP verification | User's TOTP secret |
| `QrCodeAuthHandler` | QR_CODE | Verify signed QR token | Token validation service |
| `FaceAuthHandler` | FACE | Delegate to biometric processor | BiometricServicePort |
| `FingerprintAuthHandler` | FINGERPRINT | WebAuthn assertion verification | FIDO2 credential store |
| `VoiceAuthHandler` | VOICE | Delegate to biometric processor | BiometricServicePort (voice endpoints) |
| `NfcDocumentAuthHandler` | NFC_DOCUMENT | Verify chip data + document hash | Document verification service |
| `HardwareKeyAuthHandler` | HARDWARE_KEY | WebAuthn assertion verification | FIDO2 credential store |

---

## 6. Session Management

### 6.1 Session Configuration

| Parameter | Default | Description |
|---|---|---|
| Session TTL | 10 minutes | Maximum time to complete all steps |
| Step timeout | Per-step config (30-120s) | Maximum time for individual step |
| Max concurrent sessions | 3 per user | Prevent session flooding |
| Session cleanup | Every 5 minutes | Remove expired sessions |

### 6.2 Session Storage

Auth sessions are stored in PostgreSQL with the following indexes for performance:

```sql
CREATE INDEX idx_auth_sessions_user_status ON auth_sessions(user_id, status);
CREATE INDEX idx_auth_sessions_tenant_status ON auth_sessions(tenant_id, status);
CREATE INDEX idx_auth_sessions_expires ON auth_sessions(expires_at) WHERE status IN ('PENDING', 'IN_PROGRESS');
```

### 6.3 Session Cleanup

A scheduled job runs every 5 minutes:
1. Find sessions where `expires_at < NOW()` and `status IN (PENDING, IN_PROGRESS)`
2. Set `status = EXPIRED`
3. Log audit events for expired sessions
4. Remove session data older than 24 hours

---

## 7. Token Issuance

When all required steps are completed:

1. Session status transitions to `COMPLETED`
2. Identity Core issues JWT access token + refresh token
3. Tokens include:
   - `sub`: User email
   - `tenant_id`: Tenant UUID
   - `auth_methods`: Array of methods used (e.g., `["PASSWORD", "FACE"]`)
   - `auth_session_id`: Session UUID
   - `auth_level`: Calculated security level (1-5)
   - `iat`, `exp`: Standard JWT timestamps
4. Audit log records successful authentication with all methods used

### 7.1 Auth Level Calculation

| Level | Methods | Access Tier |
|---|---|---|
| 1 | Single basic (Password only) | Low security |
| 2 | Basic + Standard (Password + TOTP) | Standard security |
| 3 | Basic + Premium (Password + Face) | Enhanced security |
| 4 | Multi-biometric (Face + Fingerprint) | High security |
| 5 | Three-factor (Password + Biometric + Hardware Key) | Maximum security |

Tenant admins can set minimum auth levels for different resources.

---

## 8. Error Handling

### 8.1 Error Response Format

```json
{
  "error": "AUTH_STEP_FAILED",
  "message": "Face verification failed: low confidence score",
  "details": {
    "stepOrder": 2,
    "method": "FACE",
    "attemptNumber": 2,
    "maxAttempts": 3,
    "attemptsRemaining": 1,
    "canRetry": true,
    "hasFallback": true,
    "fallbackMethod": "QR_CODE",
    "suggestion": "Ensure good lighting and face the camera directly"
  }
}
```

### 8.2 Error Categories

| Error Code | HTTP Status | Description |
|---|---|---|
| `SESSION_NOT_FOUND` | 404 | Invalid session ID |
| `SESSION_EXPIRED` | 410 | Session TTL exceeded |
| `SESSION_ALREADY_COMPLETED` | 409 | Session already completed |
| `STEP_OUT_OF_ORDER` | 400 | Attempted wrong step |
| `AUTH_STEP_FAILED` | 401 | Method validation failed |
| `MAX_ATTEMPTS_EXCEEDED` | 429 | No retries remaining |
| `METHOD_NOT_ENROLLED` | 412 | User not enrolled for this method |
| `UNSUPPORTED_METHOD` | 400 | Auth method not recognized |
| `DELEGATION_EXPIRED` | 410 | Delegation token expired |
| `DELEGATION_INVALID` | 401 | Invalid delegation token |
| `FLOW_NOT_CONFIGURED` | 404 | No auth flow for this operation |

### 8.3 Graceful Degradation

If the biometric processor is unavailable:
1. Face and Voice steps return `SERVICE_UNAVAILABLE` with retry-after header
2. If a fallback method is configured, automatically switch to fallback
3. If no fallback, inform the user and suggest trying again later
4. Log the outage in audit logs

---

## 9. Audit Trail

Every auth session event is recorded:

| Event | Data Logged |
|---|---|
| Session created | sessionId, tenantId, operationType, platform, deviceId, IP |
| Step attempted | sessionId, stepOrder, methodType, attemptNumber |
| Step completed | sessionId, stepOrder, methodType, duration, result metadata |
| Step failed | sessionId, stepOrder, methodType, error, attemptsRemaining |
| Fallback activated | sessionId, stepOrder, originalMethod, fallbackMethod |
| Delegation requested | sessionId, stepOrder, delegationTarget |
| Delegation completed | sessionId, stepOrder, companionDeviceId |
| Session completed | sessionId, allMethods, authLevel, totalDuration |
| Session failed | sessionId, failedStep, reason |
| Session expired | sessionId, lastCompletedStep |

---

## 10. Concurrency and Race Conditions

### 10.1 Pessimistic Locking
Auth session step completion uses pessimistic locking:
```sql
SELECT * FROM auth_sessions WHERE id = ? FOR UPDATE;
```
This prevents two concurrent step submissions from corrupting session state.

### 10.2 Idempotency
Each step submission includes an idempotency key:
```
X-Idempotency-Key: {sessionId}-step-{stepOrder}-attempt-{attemptNumber}
```
Duplicate submissions return the cached result.

### 10.3 Cross-Device Delegation Race
When delegation is active:
- Only the companion device can complete the delegated step
- Primary device cannot submit for the same step while delegation is active
- If delegation expires, primary device can retry or use a different method
