# API Specification

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document specifies all new REST API endpoints required for the multi-modal authentication system. Endpoints are organized by controller. All endpoints use JSON request/response bodies unless otherwise noted.

**Base URL**: `/api/v1`
**Authentication**: Bearer JWT token (except where marked as public)
**Content-Type**: `application/json` (unless multipart)

---

## 2. Auth Method Controller

**Base Path**: `/api/v1/auth-methods`
**Required Permission**: `auth_method:read`

### 2.1 List All System Auth Methods

```
GET /api/v1/auth-methods

Response 200:
{
  "methods": [
    {
      "id": "uuid",
      "type": "FACE",
      "name": "Face Recognition",
      "description": "Biometric face verification",
      "category": "PREMIUM",
      "platforms": ["web", "android", "ios", "desktop"],
      "requiresEnrollment": true,
      "isActive": true,
      "configSchema": {}
    },
    ...
  ]
}
```

### 2.2 Get Auth Method by Type

```
GET /api/v1/auth-methods/{type}

Path: type = PASSWORD | FACE | FINGERPRINT | ... (AuthMethodType enum)

Response 200:
{
  "id": "uuid",
  "type": "FACE",
  "name": "Face Recognition",
  ...
}

Response 404: { "error": "AUTH_METHOD_NOT_FOUND" }
```

---

## 3. Tenant Auth Method Controller

**Base Path**: `/api/v1/tenants/{tenantId}/auth-methods`
**Required Permission**: `auth_method:read` (GET), `auth_method:configure` (PUT)

### 3.1 List Tenant's Auth Methods

```
GET /api/v1/tenants/{tenantId}/auth-methods

Response 200:
{
  "methods": [
    {
      "id": "uuid",
      "authMethod": {
        "id": "uuid",
        "type": "PASSWORD",
        "name": "Password",
        "category": "BASIC",
        "platforms": ["web", "android", "ios", "desktop"],
        "requiresEnrollment": true
      },
      "isEnabled": true,
      "config": {},
      "createdAt": "2026-02-17T10:00:00Z"
    },
    ...
  ]
}
```

### 3.2 Enable/Configure Auth Method for Tenant

```
PUT /api/v1/tenants/{tenantId}/auth-methods/{authMethodId}

Request:
{
  "isEnabled": true,
  "config": {
    "liveness_level": "passive",
    "quality_threshold": 70,
    "confidence_threshold": 0.6
  }
}

Response 200:
{
  "id": "uuid",
  "authMethod": { ... },
  "isEnabled": true,
  "config": { ... },
  "updatedAt": "2026-02-17T10:30:00Z"
}

Response 404: { "error": "TENANT_NOT_FOUND" }
Response 400: { "error": "INVALID_CONFIG", "message": "..." }
```

### 3.3 Bulk Enable/Disable Auth Methods

```
PUT /api/v1/tenants/{tenantId}/auth-methods

Request:
{
  "methods": [
    { "authMethodId": "uuid", "isEnabled": true, "config": {} },
    { "authMethodId": "uuid", "isEnabled": false }
  ]
}

Response 200:
{
  "updated": 2,
  "methods": [ ... ]
}
```

---

## 4. Auth Flow Controller

**Base Path**: `/api/v1/tenants/{tenantId}/auth-flows`
**Required Permissions**: `auth_flow:read`, `auth_flow:create`, `auth_flow:update`, `auth_flow:delete`

### 4.1 List Tenant's Auth Flows

```
GET /api/v1/tenants/{tenantId}/auth-flows
Query: ?operationType=APP_LOGIN (optional filter)

Response 200:
{
  "flows": [
    {
      "id": "uuid",
      "tenantId": "uuid",
      "name": "Standard Login",
      "description": "Password + Face verification",
      "operationType": "APP_LOGIN",
      "isDefault": true,
      "isActive": true,
      "stepCount": 2,
      "createdAt": "2026-02-17T10:00:00Z",
      "updatedAt": "2026-02-17T10:00:00Z"
    },
    ...
  ]
}
```

### 4.2 Get Auth Flow with Steps

```
GET /api/v1/tenants/{tenantId}/auth-flows/{flowId}

Response 200:
{
  "id": "uuid",
  "tenantId": "uuid",
  "name": "Standard Login",
  "description": "Password + Face verification",
  "operationType": "APP_LOGIN",
  "isDefault": true,
  "isActive": true,
  "steps": [
    {
      "id": "uuid",
      "stepOrder": 1,
      "authMethod": {
        "id": "uuid",
        "type": "PASSWORD",
        "name": "Password",
        "category": "BASIC"
      },
      "isRequired": true,
      "timeoutSeconds": 120,
      "maxAttempts": 5,
      "fallbackMethod": null,
      "allowsDelegation": false,
      "config": {}
    },
    {
      "id": "uuid",
      "stepOrder": 2,
      "authMethod": {
        "id": "uuid",
        "type": "FACE",
        "name": "Face Recognition",
        "category": "PREMIUM"
      },
      "isRequired": true,
      "timeoutSeconds": 60,
      "maxAttempts": 3,
      "fallbackMethod": {
        "id": "uuid",
        "type": "QR_CODE",
        "name": "QR Code"
      },
      "allowsDelegation": true,
      "config": {
        "liveness_challenge": "BLINK"
      }
    }
  ],
  "createdAt": "2026-02-17T10:00:00Z",
  "updatedAt": "2026-02-17T10:00:00Z"
}
```

### 4.3 Create Auth Flow

```
POST /api/v1/tenants/{tenantId}/auth-flows

Request:
{
  "name": "Office Door Access",
  "description": "Face + NFC for office entry",
  "operationType": "DOOR_ACCESS",
  "isDefault": true,
  "steps": [
    {
      "authMethodId": "uuid-for-FACE",
      "stepOrder": 1,
      "isRequired": true,
      "timeoutSeconds": 30,
      "maxAttempts": 3,
      "fallbackMethodId": null,
      "allowsDelegation": true,
      "config": {}
    },
    {
      "authMethodId": "uuid-for-NFC_DOCUMENT",
      "stepOrder": 2,
      "isRequired": true,
      "timeoutSeconds": 60,
      "maxAttempts": 3,
      "fallbackMethodId": "uuid-for-QR_CODE",
      "allowsDelegation": true,
      "config": {}
    }
  ]
}

Response 201:
{
  "id": "uuid",
  "name": "Office Door Access",
  ...steps...
}

Response 400: { "error": "INVALID_FLOW", "message": "At least one step required" }
Response 409: { "error": "DUPLICATE_FLOW_NAME" }
```

### 4.4 Update Auth Flow

```
PUT /api/v1/tenants/{tenantId}/auth-flows/{flowId}

Request: (same structure as create, all fields optional)
{
  "name": "Updated Name",
  "isDefault": false,
  "isActive": true
}

Response 200: { ...updated flow... }
```

### 4.5 Delete Auth Flow

```
DELETE /api/v1/tenants/{tenantId}/auth-flows/{flowId}

Response 204: No Content
Response 409: { "error": "FLOW_IN_USE", "message": "Active sessions reference this flow" }
```

### 4.6 Add Step to Flow

```
POST /api/v1/tenants/{tenantId}/auth-flows/{flowId}/steps

Request:
{
  "authMethodId": "uuid",
  "stepOrder": 3,
  "isRequired": true,
  "timeoutSeconds": 120,
  "maxAttempts": 3,
  "fallbackMethodId": null,
  "allowsDelegation": true,
  "config": {}
}

Response 201: { ...step... }
```

### 4.7 Update Step

```
PUT /api/v1/tenants/{tenantId}/auth-flows/{flowId}/steps/{stepId}

Request: (partial update)
{
  "isRequired": false,
  "timeoutSeconds": 180
}

Response 200: { ...updated step... }
```

### 4.8 Remove Step

```
DELETE /api/v1/tenants/{tenantId}/auth-flows/{flowId}/steps/{stepId}

Response 204: No Content
(Remaining steps are re-ordered automatically)
```

### 4.9 Reorder Steps

```
PUT /api/v1/tenants/{tenantId}/auth-flows/{flowId}/steps/reorder

Request:
{
  "stepOrder": [
    { "stepId": "uuid-step-A", "order": 1 },
    { "stepId": "uuid-step-B", "order": 2 },
    { "stepId": "uuid-step-C", "order": 3 }
  ]
}

Response 200: { ...flow with reordered steps... }
```

---

## 5. Auth Session Controller

**Base Path**: `/api/v1/auth/sessions`
**Authentication**: Mixed (some public, some authenticated)

### 5.1 Start Auth Session (Public)

```
POST /api/v1/auth/sessions

Request:
{
  "tenantSlug": "acme-corp",
  "operationType": "APP_LOGIN",
  "platform": "web",
  "deviceFingerprint": "sha256-device-id",
  "capabilities": ["camera", "microphone"],
  "email": "user@example.com"  // optional, for user identification
}

Response 201:
{
  "sessionId": "uuid",
  "status": "CREATED",
  "expiresAt": "2026-02-17T10:40:00Z",
  "flow": {
    "name": "Standard Login",
    "operationType": "APP_LOGIN",
    "totalSteps": 2
  },
  "steps": [
    {
      "stepId": "uuid",
      "stepOrder": 1,
      "method": "PASSWORD",
      "methodName": "Password",
      "isRequired": true,
      "timeoutSeconds": 120,
      "maxAttempts": 5,
      "status": "PENDING",
      "requiresEnrollment": true,
      "isEnrolled": true
    },
    {
      "stepId": "uuid",
      "stepOrder": 2,
      "method": "FACE",
      "methodName": "Face Recognition",
      "isRequired": true,
      "timeoutSeconds": 60,
      "maxAttempts": 3,
      "fallbackMethod": "QR_CODE",
      "allowsDelegation": true,
      "status": "PENDING",
      "requiresEnrollment": true,
      "isEnrolled": true
    }
  ],
  "currentStep": 1
}

Response 404: { "error": "FLOW_NOT_CONFIGURED", "message": "No auth flow for APP_LOGIN" }
Response 429: { "error": "TOO_MANY_SESSIONS", "message": "Max 3 concurrent sessions" }
```

### 5.2 Get Session Status

```
GET /api/v1/auth/sessions/{sessionId}

Response 200:
{
  "sessionId": "uuid",
  "status": "IN_PROGRESS",
  "currentStep": 2,
  "completedSteps": [
    {
      "stepOrder": 1,
      "method": "PASSWORD",
      "status": "COMPLETED",
      "completedAt": "2026-02-17T10:31:00Z"
    }
  ],
  "pendingSteps": [
    {
      "stepOrder": 2,
      "method": "FACE",
      "status": "PENDING"
    }
  ],
  "expiresAt": "2026-02-17T10:40:00Z"
}

Response 404: { "error": "SESSION_NOT_FOUND" }
Response 410: { "error": "SESSION_EXPIRED" }
```

### 5.3 Complete Auth Step

```
POST /api/v1/auth/sessions/{sessionId}/steps/{stepOrder}

Headers:
  X-Idempotency-Key: {sessionId}-step-{stepOrder}-attempt-{n}

Request (Password):
{
  "method": "PASSWORD",
  "data": {
    "email": "user@example.com",
    "password": "secret123"
  }
}

Request (Face):
{
  "method": "FACE",
  "data": {
    "image": "base64-encoded-jpeg"
  }
}

Request (TOTP):
{
  "method": "TOTP",
  "data": {
    "code": "123456"
  }
}

Request (QR Code):
{
  "method": "QR_CODE",
  "data": {
    "qrToken": "encrypted-qr-payload"
  }
}

Request (Fingerprint - WebAuthn Assertion):
{
  "method": "FINGERPRINT",
  "data": {
    "credentialId": "base64url",
    "authenticatorData": "base64url",
    "clientDataJSON": "base64url",
    "signature": "base64url"
  }
}

Request (Hardware Key - same as fingerprint):
{
  "method": "HARDWARE_KEY",
  "data": {
    "credentialId": "base64url",
    "authenticatorData": "base64url",
    "clientDataJSON": "base64url",
    "signature": "base64url"
  }
}

Request (Email/SMS OTP):
{
  "method": "EMAIL_OTP",
  "data": {
    "code": "123456"
  }
}

Request (Voice):
{
  "method": "VOICE",
  "data": {
    "audio": "base64-encoded-wav"
  }
}

Request (NFC Document):
{
  "method": "NFC_DOCUMENT",
  "data": {
    "documentType": "PASSPORT",
    "mrzData": "P<TURDOE<<JOHN...",
    "chipData": { ... },
    "selfieImage": "base64-jpeg"
  }
}

--- RESPONSES ---

Response 200 (step completed, more steps):
{
  "stepOrder": 1,
  "method": "PASSWORD",
  "status": "COMPLETED",
  "nextStep": 2,
  "sessionStatus": "IN_PROGRESS"
}

Response 200 (all steps completed - AUTH SUCCESS):
{
  "stepOrder": 2,
  "method": "FACE",
  "status": "COMPLETED",
  "sessionStatus": "COMPLETED",
  "authentication": {
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "eyJhbGciOi...",
    "expiresIn": 86400,
    "tokenType": "Bearer",
    "authLevel": 3,
    "methodsUsed": ["PASSWORD", "FACE"],
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "role": "ADMIN",
      "tenantId": "uuid"
    }
  }
}

Response 401 (step failed, retries remaining):
{
  "error": "AUTH_STEP_FAILED",
  "stepOrder": 2,
  "method": "FACE",
  "status": "FAILED",
  "attemptNumber": 1,
  "maxAttempts": 3,
  "attemptsRemaining": 2,
  "canRetry": true,
  "hasFallback": true,
  "fallbackMethod": "QR_CODE",
  "message": "Face verification failed: confidence too low"
}

Response 401 (step failed, no retries, fallback available):
{
  "error": "MAX_ATTEMPTS_EXCEEDED",
  "stepOrder": 2,
  "method": "FACE",
  "status": "FALLBACK_ACTIVATED",
  "fallbackMethod": "QR_CODE",
  "message": "Max attempts exceeded. Switching to QR Code."
}

Response 401 (step failed, no retries, no fallback):
{
  "error": "AUTH_SESSION_FAILED",
  "sessionStatus": "FAILED",
  "message": "Authentication failed"
}

Response 400: { "error": "STEP_OUT_OF_ORDER" }
Response 410: { "error": "SESSION_EXPIRED" }
Response 412: { "error": "METHOD_NOT_ENROLLED" }
```

### 5.4 Skip Optional Step

```
POST /api/v1/auth/sessions/{sessionId}/steps/{stepOrder}/skip

Response 200:
{
  "stepOrder": 2,
  "status": "SKIPPED",
  "nextStep": 3,
  "sessionStatus": "IN_PROGRESS"
}

Response 400: { "error": "STEP_NOT_OPTIONAL", "message": "Required steps cannot be skipped" }
```

### 5.5 Request OTP Delivery

```
POST /api/v1/auth/sessions/{sessionId}/steps/{stepOrder}/send-otp

Request:
{
  "method": "EMAIL_OTP",
  "email": "user@example.com"
}

Response 200:
{
  "delivered": true,
  "channel": "email",
  "maskedTarget": "u***@example.com",
  "expiresInSeconds": 300,
  "retryAfterSeconds": 60
}

Response 429: { "error": "OTP_RATE_LIMITED", "retryAfterSeconds": 45 }
```

### 5.6 Request Cross-Device Delegation

```
POST /api/v1/auth/sessions/{sessionId}/delegate

Request:
{
  "stepOrder": 2,
  "preferredDeviceId": "uuid"  // optional
}

Response 200:
{
  "delegationToken": "signed-jwt-delegation-token",
  "qrData": "fivucsas://delegate?session=uuid&step=2&token=xxx&server=api.fivucsas.com",
  "expiresAt": "2026-02-17T10:35:00Z",
  "websocketUrl": "wss://api.fivucsas.com/ws/auth-sessions/uuid"
}

Response 400: { "error": "DELEGATION_NOT_ALLOWED", "message": "This step doesn't allow delegation" }
```

### 5.7 Complete Delegated Step (Companion Device)

```
POST /api/v1/auth/sessions/{sessionId}/steps/{stepOrder}/delegate-complete

Request:
{
  "delegationToken": "signed-jwt-delegation-token",
  "method": "FINGERPRINT",
  "data": {
    "credentialId": "base64url",
    "authenticatorData": "base64url",
    "clientDataJSON": "base64url",
    "signature": "base64url"
  },
  "deviceFingerprint": "companion-device-hash"
}

Response 200:
{
  "stepOrder": 2,
  "status": "COMPLETED",
  "delegated": true,
  "companionDevice": "Samsung Galaxy S24"
}

Response 401: { "error": "DELEGATION_INVALID" }
Response 410: { "error": "DELEGATION_EXPIRED" }
```

### 5.8 Cancel Session

```
DELETE /api/v1/auth/sessions/{sessionId}

Response 204: No Content
```

---

## 6. Device Controller

**Base Path**: `/api/v1/devices`
**Required Permissions**: `device:read`, `device:register`, `device:delete`

### 6.1 Register Device

```
POST /api/v1/devices

Request:
{
  "deviceName": "Samsung Galaxy S24",
  "platform": "android",
  "deviceFingerprint": "sha256-of-device-identifiers",
  "capabilities": ["camera", "nfc", "fingerprint", "microphone", "bluetooth"],
  "pushToken": "firebase-cloud-messaging-token"
}

Response 201:
{
  "id": "uuid",
  "deviceName": "Samsung Galaxy S24",
  "platform": "android",
  "capabilities": ["camera", "nfc", "fingerprint", "microphone", "bluetooth"],
  "isTrusted": false,
  "registeredAt": "2026-02-17T10:00:00Z"
}

Response 409: { "error": "DEVICE_ALREADY_REGISTERED" }
```

### 6.2 List User's Devices

```
GET /api/v1/devices

Response 200:
{
  "devices": [
    {
      "id": "uuid",
      "deviceName": "Samsung Galaxy S24",
      "platform": "android",
      "capabilities": ["camera", "nfc", "fingerprint", "microphone", "bluetooth"],
      "isTrusted": true,
      "lastUsedAt": "2026-02-17T09:00:00Z",
      "registeredAt": "2026-02-01T10:00:00Z"
    },
    ...
  ]
}
```

### 6.3 Update Device

```
PUT /api/v1/devices/{deviceId}

Request:
{
  "deviceName": "My Phone",
  "isTrusted": true,
  "pushToken": "new-fcm-token"
}

Response 200: { ...updated device... }
```

### 6.4 Remove Device

```
DELETE /api/v1/devices/{deviceId}

Response 204: No Content
```

---

## 7. Enrollment Controller

**Base Path**: `/api/v1/users/{userId}/enrollments`
**Required Permissions**: `enrollment:read`, `enrollment:create`, `enrollment:delete` (or own user)

### 7.1 Get User's Enrollment Status

```
GET /api/v1/users/{userId}/enrollments

Response 200:
{
  "enrollments": [
    {
      "id": "uuid",
      "authMethodType": "PASSWORD",
      "status": "ENROLLED",
      "enrolledAt": "2026-01-15T10:00:00Z",
      "expiresAt": null
    },
    {
      "id": "uuid",
      "authMethodType": "FACE",
      "status": "ENROLLED",
      "enrolledAt": "2026-02-01T14:30:00Z",
      "enrollmentData": {
        "qualityScore": 85,
        "imageCount": 3,
        "model": "ArcFace"
      }
    },
    {
      "id": "uuid",
      "authMethodType": "FINGERPRINT",
      "status": "NOT_ENROLLED"
    },
    ...
  ],
  "summary": {
    "enrolled": ["PASSWORD", "FACE", "TOTP"],
    "notEnrolled": ["FINGERPRINT", "VOICE", "NFC_DOCUMENT", "HARDWARE_KEY", "QR_CODE"],
    "pending": [],
    "requiredByFlow": ["PASSWORD", "FACE"]
  }
}
```

### 7.2 Start Enrollment

```
POST /api/v1/users/{userId}/enrollments/{methodType}

methodType: TOTP | QR_CODE | FACE | FINGERPRINT | VOICE | NFC_DOCUMENT | HARDWARE_KEY | SMS_OTP

--- TOTP Response 200 ---
{
  "authMethodType": "TOTP",
  "status": "PENDING",
  "enrollmentChallenge": {
    "secret": "JBSWY3DPEHPK3PXP",
    "qrUri": "otpauth://totp/FIVUCSAS:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=FIVUCSAS&digits=6&period=30",
    "backupCodes": ["12345678", "23456789", ...]
  }
}

--- FINGERPRINT / HARDWARE_KEY Response 200 ---
{
  "authMethodType": "FINGERPRINT",
  "status": "PENDING",
  "enrollmentChallenge": {
    "challenge": "base64url-random-bytes",
    "rpId": "fivucsas.rollingcatsoftware.com",
    "rpName": "FIVUCSAS",
    "userId": "base64url-user-id",
    "userName": "user@example.com",
    "authenticatorSelection": {
      "authenticatorAttachment": "platform",
      "userVerification": "required"
    },
    "pubKeyCredParams": [
      { "type": "public-key", "alg": -7 },
      { "type": "public-key", "alg": -257 }
    ]
  }
}

--- QR_CODE Response 200 ---
{
  "authMethodType": "QR_CODE",
  "status": "PENDING",
  "enrollmentChallenge": {
    "qrToken": "encrypted-user-qr-token",
    "qrImageBase64": "base64-png-qr-image"
  }
}

Response 409: { "error": "ALREADY_ENROLLED" }
Response 400: { "error": "METHOD_NOT_ENABLED", "message": "FACE not enabled for this tenant" }
```

### 7.3 Complete Enrollment

```
PUT /api/v1/users/{userId}/enrollments/{methodType}/complete

--- TOTP Request ---
{
  "verificationCode": "123456"
}

--- FINGERPRINT / HARDWARE_KEY Request ---
{
  "credentialId": "base64url",
  "publicKey": "base64url-cose-key",
  "attestationObject": "base64url",
  "clientDataJSON": "base64url",
  "transports": ["internal"]
}

--- FACE Request ---
{
  "biometricProcessorConfirmation": true,
  "qualityScore": 85,
  "livenessScore": 0.92
}

--- QR_CODE Request ---
{
  "scannedToken": "encrypted-token-from-scanning-own-qr"
}

--- SMS_OTP Request ---
{
  "phoneNumber": "+905551234567",
  "verificationCode": "123456"
}

Response 200:
{
  "authMethodType": "TOTP",
  "status": "ENROLLED",
  "enrolledAt": "2026-02-17T10:30:00Z"
}

Response 400: { "error": "VERIFICATION_FAILED", "message": "Invalid TOTP code" }
```

### 7.4 Revoke Enrollment

```
DELETE /api/v1/users/{userId}/enrollments/{methodType}

Response 204: No Content
Response 400: { "error": "CANNOT_REVOKE_PASSWORD", "message": "Password enrollment cannot be revoked" }
```

---

## 8. WebSocket Endpoints

### 8.1 Auth Session Updates

```
WebSocket: wss://host/ws/auth-sessions/{sessionId}

// Server -> Client messages:

// Step completed
{
  "type": "STEP_COMPLETED",
  "stepOrder": 2,
  "method": "FINGERPRINT",
  "delegated": true,
  "companionDevice": "Samsung Galaxy S24",
  "timestamp": "2026-02-17T10:32:00Z"
}

// Session completed
{
  "type": "SESSION_COMPLETED",
  "authentication": {
    "accessToken": "...",
    "refreshToken": "...",
    ...
  }
}

// Session failed
{
  "type": "SESSION_FAILED",
  "reason": "MAX_ATTEMPTS_EXCEEDED",
  "stepOrder": 2
}

// Session expired
{
  "type": "SESSION_EXPIRED"
}

// Delegation status
{
  "type": "DELEGATION_STARTED",
  "stepOrder": 2,
  "companionDeviceConnected": true
}
```

### 8.2 Connection Protocol
1. Client connects: `wss://host/ws/auth-sessions/{sessionId}?token={delegationToken}`
2. Server validates session exists and token is valid
3. Server sends current session state
4. Server pushes real-time updates
5. Connection closes on session completion/failure/expiry

---

## 9. Error Response Format

All error responses follow this format:

```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable description",
  "details": {
    // Context-specific additional data
  },
  "timestamp": "2026-02-17T10:30:00Z",
  "path": "/api/v1/auth/sessions/uuid/steps/2"
}
```

### Error Codes Summary

| Code | HTTP | Context |
|---|---|---|
| `AUTH_METHOD_NOT_FOUND` | 404 | Unknown auth method type |
| `TENANT_NOT_FOUND` | 404 | Invalid tenant ID |
| `FLOW_NOT_CONFIGURED` | 404 | No auth flow for operation |
| `FLOW_NOT_FOUND` | 404 | Invalid flow ID |
| `DUPLICATE_FLOW_NAME` | 409 | Flow name already exists |
| `FLOW_IN_USE` | 409 | Cannot delete flow with active sessions |
| `SESSION_NOT_FOUND` | 404 | Invalid session ID |
| `SESSION_EXPIRED` | 410 | Session TTL exceeded |
| `SESSION_ALREADY_COMPLETED` | 409 | Session already finished |
| `STEP_OUT_OF_ORDER` | 400 | Wrong step attempted |
| `STEP_NOT_OPTIONAL` | 400 | Cannot skip required step |
| `AUTH_STEP_FAILED` | 401 | Method validation failed |
| `MAX_ATTEMPTS_EXCEEDED` | 429 | No retries left |
| `METHOD_NOT_ENROLLED` | 412 | User not enrolled |
| `METHOD_NOT_ENABLED` | 400 | Method not enabled for tenant |
| `DELEGATION_NOT_ALLOWED` | 400 | Step doesn't allow delegation |
| `DELEGATION_INVALID` | 401 | Invalid delegation token |
| `DELEGATION_EXPIRED` | 410 | Delegation token expired |
| `DEVICE_ALREADY_REGISTERED` | 409 | Device fingerprint exists |
| `ALREADY_ENROLLED` | 409 | User already enrolled |
| `CANNOT_REVOKE_PASSWORD` | 400 | Password is mandatory |
| `VERIFICATION_FAILED` | 400 | Enrollment verification failed |
| `OTP_RATE_LIMITED` | 429 | Too many OTP requests |
| `TOO_MANY_SESSIONS` | 429 | Max concurrent sessions |
| `INVALID_CONFIG` | 400 | Invalid method config |
| `SERVICE_UNAVAILABLE` | 503 | Biometric processor down |
