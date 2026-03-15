# FIVUCSAS API Contract Analysis Report

**Date:** 2026-02-10
**Author:** Claude Code (Automated Audit)
**Scope:** Identity Core API (Backend) vs Web App (Frontend) Contract Alignment
**Severity Scale:** CRITICAL > HIGH > MEDIUM > LOW

---

## Executive Summary

The Identity Core API provides **60+ endpoints** across 12 controllers with solid hexagonal architecture. However, the frontend (web-app) was developed with **different assumptions** about the API contract. This report documents **14 mismatches** between what the backend actually returns and what the frontend expects to receive.

**Verdict:** The backend is architecturally complete (~85%), but **cannot serve the frontend correctly** in its current state due to DTO mismatches, field naming conflicts, and a broken production URL.

---

## Table of Contents

1. [Infrastructure Issues](#1-infrastructure-issues)
2. [User DTO Mismatch](#2-user-dto-mismatch)
3. [Tenant DTO Mismatch](#3-tenant-dto-mismatch)
4. [Enrollment DTO Mismatch](#4-enrollment-dto-mismatch)
5. [Settings DTO Mismatch](#5-settings-dto-mismatch)
6. [Create User Request Mismatch](#6-create-user-request-mismatch)
7. [Update User Request Mismatch](#7-update-user-request-mismatch)
8. [Create Tenant Request Mismatch](#8-create-tenant-request-mismatch)
9. [Update Tenant Request Mismatch](#9-update-tenant-request-mismatch)
10. [Auth Response Minor Issues](#10-auth-response-minor-issues)
11. [Status Enum Mismatches](#11-status-enum-mismatches)
12. [Audit Log DTO (Compatible)](#12-audit-log-dto-compatible)
13. [Statistics DTO (Compatible)](#13-statistics-dto-compatible)
14. [CORS Production Config](#14-cors-production-config)
15. [Solution Strategy](#15-solution-strategy)

---

## 1. Infrastructure Issues

### 1.1 Production API URL - BROKEN

**Severity: CRITICAL**

| Side | Value |
|------|-------|
| Frontend `.env.production` | `https://api-fivucsas.rollingcatsoftware.com/api/v1` |
| Backend actual location | `http://116.203.222.213:8080/api/v1` |

The domain `api-fivucsas.rollingcatsoftware.com` **does not exist**. The deployed frontend at `ica-fivucsas.rollingcatsoftware.com` should use `http://116.203.222.213:8080/api/v1` directly.

**Impact:** Frontend is completely non-functional in production.

### 1.2 CORS Not Configured for Production Frontend

**Severity: CRITICAL**

Backend CORS allowed origins (from `SecurityConfig.java:42`):
```
http://localhost:3000,http://localhost:4200,http://localhost:5173
```

Production frontend origin: `https://ica-fivucsas.rollingcatsoftware.com`

**Impact:** Even if the URL issue is fixed, CORS will block all requests from the production frontend.

---

## 2. User DTO Mismatch

**Severity: HIGH**

### Frontend Expects (`UserJSON` in `web-app/src/domain/models/User.ts`):
```typescript
{
  id: string
  email: string
  firstName: string
  lastName: string
  role: UserRole          // single enum: USER | ADMIN | TENANT_ADMIN | SUPER_ADMIN
  status: UserStatus      // 6 values: PENDING_ENROLLMENT | ACTIVE | INACTIVE | SUSPENDED | DELETED | LOCKED
  tenantId: string
  createdAt: string
  updatedAt: string
  lastLoginAt?: string    // optional
  lastLoginIp?: string    // optional
}
```

### Backend Returns (`UserDto` in `identity-core-api/.../dto/UserDto.java`):
```java
{
  id: String
  firstName: String
  lastName: String
  name: String            // EXTRA - frontend doesn't use
  email: String
  idNumber: String        // EXTRA - frontend doesn't use
  phoneNumber: String     // EXTRA - frontend doesn't use
  address: String         // EXTRA - frontend doesn't use
  status: UserStatus      // 3 values only: ACTIVE | INACTIVE | SUSPENDED
  role: String            // plain String, not enum
  roles: Set<String>      // EXTRA - frontend doesn't use
  tenantId: String
  isBiometricEnrolled: boolean  // EXTRA - frontend doesn't use
  enrolledAt: Instant           // EXTRA
  lastVerifiedAt: Instant       // EXTRA
  verificationCount: Integer    // EXTRA
  createdAt: Instant
  updatedAt: Instant
  // MISSING: lastLoginAt
  // MISSING: lastLoginIp
}
```

### Field-by-Field Comparison:

| Field | Frontend | Backend | Status |
|-------|----------|---------|--------|
| `id` | `string` | `String` | OK |
| `email` | `string` | `String` | OK |
| `firstName` | `string` | `String` | OK |
| `lastName` | `string` | `String` | OK |
| `role` | `UserRole` enum (4 values) | `String` (free text) | MISMATCH - Backend must return correct enum values |
| `status` | `UserStatus` enum (6 values) | `UserStatus` enum (3 values) | MISMATCH - Missing PENDING_ENROLLMENT, DELETED, LOCKED |
| `tenantId` | `string` | `String` | OK |
| `createdAt` | `string` (ISO) | `Instant` (ISO via Jackson) | OK |
| `updatedAt` | `string` (ISO) | `Instant` (ISO via Jackson) | OK |
| `lastLoginAt` | `string?` | **MISSING** | MISMATCH |
| `lastLoginIp` | `string?` | **MISSING** | MISMATCH |
| `name` | not expected | `String` | OK (ignored) |
| `idNumber` | not expected | `String` | OK (ignored) |
| `phoneNumber` | not expected | `String` | OK (ignored) |
| `address` | not expected | `String` | OK (ignored) |
| `isBiometricEnrolled` | not expected | `boolean` | OK (ignored) |
| `roles` | not expected | `Set<String>` | OK (ignored) |

### Issues:
1. **`role` value mapping**: Backend `role` field is a plain String. Must return one of: `USER`, `ADMIN`, `TENANT_ADMIN`, `SUPER_ADMIN`. Currently maps from internal role types (ROOT→SUPER_ADMIN, TENANT_ADMIN→TENANT_ADMIN, etc.) - needs verification.
2. **`status` enum gap**: Backend only has 3 statuses (ACTIVE, INACTIVE, SUSPENDED). Frontend expects 6. The statuses PENDING_ENROLLMENT, DELETED, LOCKED don't exist in backend.
3. **`lastLoginAt` missing**: Frontend uses this for display. Backend UserDto doesn't include it.
4. **`lastLoginIp` missing**: Frontend uses this for display. Backend UserDto doesn't include it.

---

## 3. Tenant DTO Mismatch

**Severity: HIGH**

### Frontend Expects (`TenantJSON` in `web-app/src/domain/models/Tenant.ts`):
```typescript
{
  id: string
  name: string
  domain: string          // <-- uses "domain"
  status: TenantStatus    // ACTIVE | TRIAL | SUSPENDED
  maxUsers: number
  currentUsers: number    // <-- expects current user count
  createdAt: string
  updatedAt: string
}
```

### Backend Returns (`TenantResponse` in `identity-core-api/.../dto/response/TenantResponse.java`):
```java
{
  id: String
  name: String
  slug: String            // <-- uses "slug" NOT "domain"
  description: String     // EXTRA
  contactEmail: String    // EXTRA
  contactPhone: String    // EXTRA
  status: String          // ACTIVE | INACTIVE | SUSPENDED | TRIAL | PENDING
  maxUsers: int
  biometricEnabled: boolean    // EXTRA
  sessionTimeoutMinutes: int   // EXTRA
  refreshTokenValidityDays: int // EXTRA
  mfaRequired: boolean         // EXTRA
  createdAt: Instant
  updatedAt: Instant
  // MISSING: currentUsers
  // MISSING: domain (has "slug" instead)
}
```

### Issues:
1. **`domain` vs `slug`**: Frontend reads `data.domain`, backend returns `slug`. Result: `domain` will be `undefined`.
2. **`currentUsers` missing**: Frontend reads `data.currentUsers` for usage percentage display. Backend doesn't return it.
3. **Status enum mismatch**: Frontend has `ACTIVE | TRIAL | SUSPENDED`. Backend has `ACTIVE | INACTIVE | SUSPENDED | TRIAL | PENDING`. Backend is actually a superset, but frontend TenantStatus enum doesn't include INACTIVE or PENDING.

---

## 4. Enrollment DTO Mismatch

**Severity: HIGH**

### Frontend Expects (`EnrollmentJSON` in `web-app/src/domain/models/Enrollment.ts`):
```typescript
{
  id: string
  userId: string
  tenantId: string
  status: EnrollmentStatus   // PENDING | PROCESSING | SUCCESS | FAILED
  faceImageUrl: string
  createdAt: string
  updatedAt: string
  qualityScore?: number
  livenessScore?: number
  errorCode?: string
  errorMessage?: string
  completedAt?: string
}
```

### Backend Returns (`EnrollmentDto` in `identity-core-api/.../dto/EnrollmentDto.java`):
```java
{
  id: String
  userId: String
  userName: String      // EXTRA - frontend doesn't use
  userEmail: String     // EXTRA - frontend doesn't use
  status: String        // hardcoded "COMPLETED"
  enrolledAt: Instant   // named differently
  // MISSING: tenantId
  // MISSING: faceImageUrl
  // MISSING: updatedAt
  // MISSING: qualityScore
  // MISSING: livenessScore
  // MISSING: errorCode
  // MISSING: errorMessage
  // MISSING: completedAt
  // MISSING: createdAt (has enrolledAt instead)
}
```

### Issues:
This is the **most severe DTO mismatch**. Backend EnrollmentDto has only 6 fields, frontend expects 12.

1. **`tenantId` missing**: Frontend needs it for multi-tenant display
2. **`faceImageUrl` missing**: Frontend expects image URL for display
3. **`status` hardcoded**: Backend always returns "COMPLETED", frontend expects 4 different statuses
4. **`createdAt`/`updatedAt` missing**: Backend has `enrolledAt` instead, named differently
5. **All biometric quality fields missing**: qualityScore, livenessScore, errorCode, errorMessage, completedAt

---

## 5. Settings DTO Mismatch

**Severity: HIGH**

### Frontend Expects (flat structure from `ISettingsRepository.ts`):
```typescript
{
  userId: string
  firstName: string
  lastName: string
  emailNotifications: boolean
  loginAlerts: boolean
  securityAlerts: boolean
  weeklyReports: boolean
  twoFactorEnabled: boolean
  sessionTimeoutMinutes: number
  darkMode: boolean
  compactView: boolean
}
```

### Backend Returns (nested Map from `UserSettingsController.java`):
```json
{
  "notifications": {
    "email": true,
    "push": true,
    "securityAlerts": true
  },
  "security": {
    "twoFactorEnabled": false,
    "sessionTimeout": 30
  },
  "appearance": {
    "theme": "light",
    "language": "en",
    "density": "comfortable"
  }
}
```

### Issues:
1. **Structure**: Frontend expects flat object, backend returns nested object
2. **Missing on backend**: `userId`, `firstName`, `lastName` not in settings response (these come from User entity)
3. **Field names differ for notifications**: Frontend sends `emailNotifications`/`loginAlerts`/`weeklyReports`, backend has `email`/`push` (no loginAlerts, no weeklyReports)
4. **Field names differ for security**: Frontend sends `sessionTimeoutMinutes`, backend has `sessionTimeout`
5. **Field names differ for appearance**: Frontend sends `darkMode`/`compactView`, backend has `theme`/`language`/`density`

### Sub-endpoint Mismatches:

| Endpoint | Frontend Sends | Backend Expects |
|----------|---------------|-----------------|
| `PUT .../notifications` | `{ emailNotifications, loginAlerts, securityAlerts, weeklyReports }` | `{ email, push, securityAlerts }` |
| `PUT .../security` | `{ twoFactorEnabled, sessionTimeoutMinutes }` | `{ twoFactorEnabled, sessionTimeout }` |
| `PUT .../appearance` | `{ darkMode, compactView }` | `{ theme, language, density }` |

---

## 6. Create User Request Mismatch

**Severity: HIGH**

### Frontend Sends (`CreateUserData` in `IUserRepository.ts`):
```typescript
{
  email: string
  firstName: string
  lastName: string
  password: string
  role: string        // frontend sends this
  tenantId: string    // frontend sends this
}
```

### Backend Expects (`CreateUserRequest` in `CreateUserRequest.java`):
```java
{
  firstName: String      // @NotBlank
  lastName: String       // @NotBlank
  email: String          // @NotBlank @Email
  password: String       // @NotBlank @Size(min=8)
  idNumber: String       // @Pattern(11 digits) - optional
  phoneNumber: String    // @Pattern(10-15 digits) - optional
  address: String        // @Size(max=500) - optional
  // DOES NOT ACCEPT: role
  // DOES NOT ACCEPT: tenantId
}
```

### Issues:
1. **`role` not accepted**: Frontend sends role assignment during user creation, but backend ignores it (no field for it). New users get default role only.
2. **`tenantId` not accepted**: Frontend sends tenant assignment, but backend ignores it. Users are assigned to hardcoded default tenant.
3. **`idNumber`, `phoneNumber`, `address` not sent**: Backend accepts these optional fields but frontend doesn't provide them.

---

## 7. Update User Request Mismatch

**Severity: MEDIUM**

### Frontend Sends (`UpdateUserData` in `IUserRepository.ts`):
```typescript
{
  email?: string
  firstName?: string
  lastName?: string
  role?: string       // frontend sends this
  status?: string
}
```

### Backend Expects (`UpdateUserRequest` in `UpdateUserRequest.java`):
```java
{
  firstName: String
  lastName: String
  email: String
  idNumber: String
  phoneNumber: String
  address: String
  status: UserStatus    // only ACTIVE | INACTIVE | SUSPENDED
  // DOES NOT ACCEPT: role
}
```

### Issues:
1. **`role` not accepted**: Frontend tries to change user role via update, backend doesn't support it. Role changes require the User Role Assignment endpoints (`/users/{id}/roles/{roleId}`).
2. **`status` enum mismatch**: Frontend may send PENDING_ENROLLMENT, DELETED, or LOCKED - backend will reject these.

---

## 8. Create Tenant Request Mismatch

**Severity: HIGH**

### Frontend Sends (`CreateTenantData` in `ITenantRepository.ts`):
```typescript
{
  name: string
  domain: string        // <-- frontend uses "domain"
  status: string
  maxUsers: number
  currentUsers?: number
}
```

### Backend Expects (`TenantController.CreateTenantRequest` inner class):
```java
{
  name: String
  slug: String           // <-- backend uses "slug"
  description: String
  contactEmail: String
  contactPhone: String
  maxUsers: Integer
  biometricEnabled: Boolean
  sessionTimeoutMinutes: Integer
  refreshTokenValidityDays: Integer
  mfaRequired: Boolean
  // DOES NOT ACCEPT: domain
  // DOES NOT ACCEPT: status (set internally)
  // DOES NOT ACCEPT: currentUsers (computed)
}
```

### Issues:
1. **`domain` vs `slug`**: Frontend sends `domain`, backend expects `slug`. Field will be null on backend.
2. **`status` not accepted**: Frontend sends status, backend sets it internally (new tenants start as ACTIVE or PENDING).
3. **`currentUsers` not accepted**: This is a computed field, not settable.
4. **Missing fields**: Frontend doesn't send description, contactEmail, contactPhone, biometricEnabled, sessionTimeoutMinutes, refreshTokenValidityDays, mfaRequired.

---

## 9. Update Tenant Request Mismatch

**Severity: HIGH**

Same issues as Create Tenant. Frontend sends `domain`/`status`/`currentUsers`, backend expects `slug` and different configuration fields.

---

## 10. Auth Response Minor Issues

**Severity: LOW**

### Frontend Expects:
```typescript
{ accessToken, refreshToken, expiresIn?, user: UserJSON }
```

### Backend Returns:
```java
{ accessToken, refreshToken, tokenType, expiresIn, user: UserDto }
```

- `tokenType` is extra (harmless, ignored by frontend)
- `expiresIn` is always present in backend (frontend treats as optional with fallback to 3600)
- `user` object has the UserDto mismatches from Section 2

**Impact:** Auth response structure is correct, but the nested `user` object carries all User DTO mismatches.

---

## 11. Status Enum Mismatches

**Severity: MEDIUM**

### UserStatus

| Value | Frontend | Backend |
|-------|----------|---------|
| `ACTIVE` | YES | YES |
| `INACTIVE` | YES | YES |
| `SUSPENDED` | YES | YES |
| `PENDING_ENROLLMENT` | YES | **NO** |
| `DELETED` | YES | **NO** |
| `LOCKED` | YES | **NO** |

### TenantStatus

| Value | Frontend | Backend |
|-------|----------|---------|
| `ACTIVE` | YES | YES |
| `SUSPENDED` | YES | YES |
| `TRIAL` | YES | YES |
| `INACTIVE` | NO | YES |
| `PENDING` | NO | YES |

### EnrollmentStatus

| Value | Frontend | Backend EnrollmentDto |
|-------|----------|-----------------------|
| `PENDING` | YES | NO (hardcoded "COMPLETED") |
| `PROCESSING` | YES | NO |
| `SUCCESS` | YES | NO |
| `FAILED` | YES | NO |

---

## 12. Audit Log DTO (Compatible)

**Severity: NONE**

### Frontend Expects:
```typescript
{ id, userId, tenantId, action, entityType, ipAddress?, userAgent?, details?, timestamp?, createdAt?, entityId? }
```

### Backend Returns:
```java
{ id, userId, tenantId, action, entityType, entityId, success, errorMessage, ipAddress, userAgent, details, timestamp }
```

**Status:** Compatible. Frontend handles both `timestamp` and `createdAt` as fallback. Extra fields (`success`, `errorMessage`) are ignored. Audit log pagination format (`{ content, totalElements, totalPages, page, size }`) is handled by frontend.

---

## 13. Statistics DTO (Compatible)

**Severity: NONE**

### Frontend Expects (all optional with `?? 0` defaults):
```typescript
{ totalUsers?, activeUsers?, inactiveUsers?, suspendedUsers?, biometricEnrolledUsers?, totalVerifications?, totalTenants?, pendingEnrollments?, successfulEnrollments?, failedEnrollments?, authSuccessRate?, verificationSuccessRate? }
```

### Backend Returns:
```java
{ totalUsers, activeUsers, inactiveUsers, suspendedUsers, biometricEnrolledUsers, totalVerifications, averageVerificationsPerUser, totalTenants, pendingEnrollments, successfulEnrollments, failedEnrollments, authSuccessRate, verificationSuccessRate }
```

**Status:** Compatible. All frontend-expected fields are present. Backend has extra `averageVerificationsPerUser` (ignored). Frontend uses `?? 0` fallback so all fields work.

---

## 14. CORS Production Config

**Severity: CRITICAL**

### Current CORS Config (`SecurityConfig.java:42`):
```java
@Value("${cors.allowed-origins:http://localhost:3000,http://localhost:4200,http://localhost:5173}")
private String allowedOrigins;
```

### Production CORS Requirement:
```
https://ica-fivucsas.rollingcatsoftware.com
```

The `cors.allowed-origins` property is configurable via environment variable, but it's **not set in the Hetzner VPS Docker deployment**. The default value only includes localhost origins.

---

## 15. Solution Strategy

### Principle: **Backend is the source of truth. Adapt BOTH sides to a shared contract.**

The professional approach is a **Backend-Driven Contract** where:
- Backend DTOs are enriched to include all data the frontend needs
- Frontend models are updated to match backend field names
- Both sides agree on enum values

### Priority Order:

#### P0 - CRITICAL (Frontend completely broken)
1. **Fix production API URL** - Either DNS record or `.env.production` update
2. **Fix CORS** - Add production origin to allowed origins env var

#### P1 - HIGH (Pages crash or show wrong data)
3. **Fix Tenant DTO** - Add `domain` alias or rename to `slug` on frontend
4. **Fix Enrollment DTO** - Enrich backend with missing fields
5. **Fix User DTO** - Add `lastLoginAt`/`lastLoginIp` to backend, align status enums
6. **Fix Settings DTO** - Align structure (frontend adapts to backend's nested format)

#### P2 - HIGH (CRUD operations fail)
7. **Fix Create User Request** - Backend: accept `role` + `tenantId`, OR Frontend: use role assignment endpoint after creation
8. **Fix Update User Request** - Frontend: use role assignment endpoint, align status enum
9. **Fix Create/Update Tenant Request** - Frontend: use `slug` instead of `domain`

#### P3 - MEDIUM (Edge cases)
10. **Align status enums** - Decide on canonical set for UserStatus, TenantStatus, EnrollmentStatus

### Recommended Changes Per Side:

#### Backend Changes Needed:
| Change | File | Reason |
|--------|------|--------|
| Add `lastLoginAt`, `lastLoginIp` to UserDto | `UserDto.java` | Frontend displays these |
| Add `PENDING_ENROLLMENT`, `DELETED`, `LOCKED` to UserStatus | `UserStatus.java` | Frontend uses these statuses |
| Enrich EnrollmentDto with missing fields | `EnrollmentDto.java` | Frontend expects 12 fields, backend has 6 |
| Add `currentUsers` computation to TenantResponse | `TenantResponse.java` | Frontend displays usage percentage |
| Accept `role`+`tenantId` in CreateUserRequest OR return proper error | `CreateUserRequest.java` | Frontend sends these during user creation |
| Add production CORS origin | `application-prod.yml` or env var | Frontend blocked by CORS |

#### Frontend Changes Needed:
| Change | File | Reason |
|--------|------|--------|
| Map `slug` to `domain` in Tenant.fromJSON() | `Tenant.ts` | Backend uses `slug`, not `domain` |
| Use `slug` in Create/Update Tenant requests | `ITenantRepository.ts`, `TenantRepository.ts` | Backend expects `slug` |
| Adapt Settings to nested structure | `SettingsRepository.ts`, `ISettingsRepository.ts` | Backend uses nested `{ notifications: {}, security: {}, appearance: {} }` |
| Map setting field names | `SettingsRepository.ts` | `emailNotifications`→`email`, `sessionTimeoutMinutes`→`sessionTimeout`, `darkMode`→`theme` |
| Fix `.env.production` API URL | `.env.production` | Points to non-existent domain |
| Handle role assignment via separate endpoint | `UserRepository.ts` | Backend doesn't accept `role` in create user |

---

## Appendix: Complete Endpoint Inventory

### Backend Provides (60+ endpoints):
| Controller | Count | Endpoints |
|-----------|-------|-----------|
| AuthController | 6 | register, login, refresh, logout, me, health |
| UserController | 7 | list, get, create, update, delete, change-password, search |
| TenantController | 8 | create, get, get-by-slug, list, update, activate, suspend, delete |
| RoleController | 8 | list, get, by-tenant, create, update, delete, assign-perm, revoke-perm |
| PermissionController | 3 | list, get, by-resource |
| UserRoleController | 4 | list, assign, revoke, users-by-role |
| BiometricController | 2 | enroll, verify |
| EnrollmentController | 4 | list, get, retry, delete |
| GuestController | 6 | invite, accept, list, count, revoke, extend |
| AuditLogController | 2 | list (paginated), get |
| StatisticsController | 1 | get |
| UserSettingsController | 8 | get/update all, get/update notifications, get/update security, get/update appearance |

### Frontend Uses (28 endpoints):
| Feature | Count | Endpoints |
|---------|-------|-----------|
| Auth | 4 | login, logout, refresh, me |
| Users | 5 | list, get, create, update, delete |
| Tenants | 5 | list, get, create, update, delete |
| Enrollments | 4 | list, get, retry, delete |
| Audit Logs | 2 | list, get |
| Statistics | 1 | get |
| Settings | 7 | get, update-profile, update-notifications, update-security, update-appearance, change-password, (get sub-sections) |

### Backend Features NOT Used by Frontend:
- Role Management (8 endpoints)
- Permission Management (3 endpoints)
- User Role Assignment (4 endpoints)
- Guest Management (6 endpoints)
- Biometric Operations (2 endpoints)
- Tenant activate/suspend/get-by-slug (3 endpoints)
- User search (1 endpoint)

These 27 unused endpoints are **not wasted** - they will be needed by mobile/desktop clients and future admin features.
