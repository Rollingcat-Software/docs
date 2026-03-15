# FIVUCSAS API Contract Fix Plan

**Date:** 2026-02-10
**Prerequisite:** Read `API_CONTRACT_ANALYSIS.md` first
**Approach:** Backend-Driven Contract with Frontend Adaptation Layer

---

## Strategy: Why Fix Both Sides?

A professional solution doesn't just "make things work" - it establishes a **contract** that both sides respect. The strategy:

1. **Backend is the authority** for data shape, business logic, and enum values
2. **Frontend adapts** via a mapping layer in its repositories (already has `fromJSON()` pattern)
3. **Where backend is genuinely incomplete**, enrich it (missing fields, insufficient enums)
4. **Where frontend assumes wrong shape**, fix the mapping layer

This avoids hacks on either side and creates a clean, maintainable integration.

---

## Phase 0: Unblock Production (30 min)

These two fixes unblock the entire frontend immediately.

### Fix 0.1: Production API URL

**Side:** Frontend
**File:** `web-app/.env.production`

Change:
```
VITE_API_BASE_URL=https://api-fivucsas.rollingcatsoftware.com/api/v1
```
To:
```
VITE_API_BASE_URL=http://116.203.222.213:8080/api/v1
```

> **Note:** Later, when we set up a proper domain with HTTPS and reverse proxy, we'll change this to `https://api-fivucsas.rollingcatsoftware.com/api/v1`. For now, use the direct IP.

### Fix 0.2: CORS for Production

**Side:** Backend (Hetzner VPS environment variable)
**File:** Docker Compose or env vars on Hetzner VPS

Add to the `CORS_ALLOWED_ORIGINS` (or `cors.allowed-origins`) environment variable:
```
http://localhost:3000,http://localhost:4200,http://localhost:5173,https://ica-fivucsas.rollingcatsoftware.com
```

**Deployment:** Requires redeploying identity-core-api container on Hetzner VPS with updated env var.

---

## Phase 1: Backend DTO Enrichment (Backend Changes)

These changes make the backend return complete data that any client can use.

### Fix 1.1: Enrich UserDto

**File:** `identity-core-api/src/main/java/com/fivucsas/identity/dto/UserDto.java`

Add missing fields:
```java
private Instant lastLoginAt;
private String lastLoginIp;
```

**Also update** the mapper/service that builds UserDto to populate these fields from the User entity or active_sessions table.

### Fix 1.2: Expand UserStatus Enum

**File:** `identity-core-api/src/main/java/com/fivucsas/identity/entity/UserStatus.java`

Add missing values:
```java
public enum UserStatus {
    ACTIVE,
    INACTIVE,
    SUSPENDED,
    PENDING_ENROLLMENT,   // new - for users awaiting biometric enrollment
    DELETED,              // new - soft-deleted users
    LOCKED                // new - locked due to security (failed attempts, etc.)
}
```

**Migration:** Add Flyway migration V15 to update any CHECK constraints on the users table status column.

### Fix 1.3: Enrich EnrollmentDto

**File:** `identity-core-api/src/main/java/com/fivucsas/identity/dto/EnrollmentDto.java`

Replace minimal DTO with complete version:
```java
public class EnrollmentDto {
    private String id;
    private String userId;
    private String userName;
    private String userEmail;
    private String tenantId;         // ADD
    private String status;           // FIX: use actual status, not hardcoded "COMPLETED"
    private String faceImageUrl;     // ADD
    private Instant createdAt;       // ADD (was enrolledAt)
    private Instant updatedAt;       // ADD
    private Instant enrolledAt;      // KEEP
    private Double qualityScore;     // ADD
    private Double livenessScore;    // ADD
    private String errorCode;        // ADD
    private String errorMessage;     // ADD
    private Instant completedAt;     // ADD
}
```

**Also update** EnrollmentController to populate all fields from the biometric_data/enrollment entity.

### Fix 1.4: Add `currentUsers` to TenantResponse

**File:** `identity-core-api/src/main/java/com/fivucsas/identity/application/dto/response/TenantResponse.java`

Add:
```java
private final int currentUsers;  // computed from user count query
```

**Also update** the service that builds TenantResponse to count users per tenant.

### Fix 1.5: Accept `role` and `tenantId` in CreateUserRequest

**Option A (Recommended):** Add fields to CreateUserRequest:
```java
private String role;      // optional - assign role after creation
private String tenantId;  // optional - assign to tenant
```

Then in the CreateUser use case, after creating the user:
1. If `tenantId` provided, associate user with that tenant
2. If `role` provided, assign the corresponding role via UserRole service

**Option B:** Keep CreateUserRequest as-is, and make frontend call role assignment endpoint after user creation (2 API calls instead of 1).

**Recommendation:** Option A is cleaner for the frontend developer experience.

---

## Phase 2: Frontend Adaptation Layer (Frontend Changes)

These changes make the frontend correctly map backend responses to its domain models.

### Fix 2.1: Tenant Model - Map `slug` to `domain`

**File:** `web-app/src/domain/models/Tenant.ts`

Update `fromJSON()`:
```typescript
static fromJSON(data: any): Tenant {
    return new Tenant(
        data.id,
        data.name,
        data.slug ?? data.domain ?? '',    // backend sends "slug"
        data.status,
        data.maxUsers ?? 0,
        data.currentUsers ?? 0,
        new Date(data.createdAt),
        new Date(data.updatedAt)
    )
}
```

### Fix 2.2: Tenant Repository - Send `slug` instead of `domain`

**File:** `web-app/src/domain/interfaces/ITenantRepository.ts`

```typescript
export interface CreateTenantData {
    name: string
    slug: string          // changed from "domain"
    description?: string  // add optional backend fields
    contactEmail?: string
    maxUsers: number
}
```

**File:** `web-app/src/core/repositories/TenantRepository.ts`

Map frontend field to backend field in create/update calls.

### Fix 2.3: Settings Repository - Adapt to Nested Structure

**File:** `web-app/src/core/repositories/SettingsRepository.ts`

Add mapping layer in `getSettings()`:
```typescript
async getSettings(userId: string): Promise<UserSettings> {
    const response = await this.httpClient.get<any>(`/users/${userId}/settings`)
    const data = response.data

    // Also fetch user profile for firstName/lastName
    const userResponse = await this.httpClient.get<any>(`/users/${userId}`)

    // Map nested backend format to flat frontend format
    return {
        userId,
        firstName: userResponse.data.firstName ?? '',
        lastName: userResponse.data.lastName ?? '',
        emailNotifications: data.notifications?.email ?? true,
        loginAlerts: data.notifications?.push ?? true,
        securityAlerts: data.notifications?.securityAlerts ?? true,
        weeklyReports: false,  // not supported by backend
        twoFactorEnabled: data.security?.twoFactorEnabled ?? false,
        sessionTimeoutMinutes: data.security?.sessionTimeout ?? 30,
        darkMode: data.appearance?.theme === 'dark',
        compactView: data.appearance?.density === 'compact',
    }
}
```

Similarly, update `updateNotifications()`, `updateSecurity()`, `updateAppearance()` to map flat frontend fields to backend nested fields:
```typescript
async updateNotifications(userId: string, data: UpdateNotificationSettings): Promise<UserSettings> {
    await this.httpClient.put(`/users/${userId}/settings/notifications`, {
        email: data.emailNotifications,
        push: data.loginAlerts,
        securityAlerts: data.securityAlerts,
    })
    return this.getSettings(userId)
}
```

### Fix 2.4: User Model - Handle Role Mapping

**File:** `web-app/src/domain/models/User.ts`

Update `fromJSON()` to handle backend's role format:
```typescript
static fromJSON(data: any): User {
    // Backend sends role as string, map to enum
    const roleMap: Record<string, UserRole> = {
        'SUPER_ADMIN': UserRole.SUPER_ADMIN,
        'ROOT': UserRole.SUPER_ADMIN,
        'TENANT_ADMIN': UserRole.TENANT_ADMIN,
        'ADMIN': UserRole.ADMIN,
        'USER': UserRole.USER,
    }

    return new User(
        data.id,
        data.email,
        data.firstName,
        data.lastName,
        roleMap[data.role] ?? UserRole.USER,
        data.status ?? UserStatus.ACTIVE,
        data.tenantId,
        new Date(data.createdAt),
        new Date(data.updatedAt),
        data.lastLoginAt ? new Date(data.lastLoginAt) : undefined,
        data.lastLoginIp
    )
}
```

### Fix 2.5: Enrollment Model - Handle Backend Field Names

**File:** `web-app/src/domain/models/Enrollment.ts`

Update `fromJSON()`:
```typescript
static fromJSON(data: any): Enrollment {
    return new Enrollment(
        data.id,
        data.userId,
        data.tenantId ?? '',
        data.status ?? EnrollmentStatus.SUCCESS,
        data.faceImageUrl ?? '',
        new Date(data.createdAt ?? data.enrolledAt),
        new Date(data.updatedAt ?? data.enrolledAt),
        data.qualityScore,
        data.livenessScore,
        data.errorCode,
        data.errorMessage,
        data.completedAt ? new Date(data.completedAt) : undefined
    )
}
```

### Fix 2.6: User Create - Handle Role Assignment

**File:** `web-app/src/core/repositories/UserRepository.ts`

If backend Option A is implemented (accepts role+tenantId), no change needed.

If backend Option B (keep as-is):
```typescript
async create(data: CreateUserData): Promise<User> {
    // Step 1: Create user (without role/tenantId)
    const { role, tenantId, ...createPayload } = data
    const response = await this.httpClient.post<any>('/users', createPayload)
    const user = User.fromJSON(response.data)

    // Step 2: Assign role if specified
    if (role) {
        await this.httpClient.post(`/users/${user.id}/roles/${role}`, {})
    }

    return user
}
```

---

## Phase 3: Alignment Verification

### 3.1: Create API Integration Tests

For each frontend page, verify the full request/response cycle:

| Test | Endpoint | Verify |
|------|----------|--------|
| Login | POST /auth/login | Returns accessToken, refreshToken, user with correct fields |
| Get Users | GET /users | Returns array of UserDto with all expected fields |
| Create User | POST /users | Accepts role+tenantId (or frontend handles 2-step) |
| Get Tenants | GET /tenants | Returns array with slug mapped to domain, currentUsers present |
| Get Enrollments | GET /enrollments | Returns enriched DTOs with all 12 fields |
| Get Settings | GET /users/{id}/settings | Returns nested format, frontend maps correctly |
| Update Settings | PUT /users/{id}/settings/notifications | Backend accepts mapped field names |
| Get Statistics | GET /statistics | All fields present |
| Get Audit Logs | GET /audit-logs | Paginated format handled correctly |

### 3.2: End-to-End Smoke Test Checklist

- [ ] Login with admin@fivucsas.local / Test@123
- [ ] Dashboard shows statistics (numbers, not NaN or undefined)
- [ ] Users page lists users with correct roles and statuses
- [ ] Create user form works and user appears in list
- [ ] Edit user form populates correctly and saves
- [ ] Delete user works
- [ ] Tenants page lists tenants with correct domain/usage
- [ ] Create tenant form works
- [ ] Enrollments page shows enrollment data
- [ ] Audit logs page loads with pagination
- [ ] Settings page shows current values
- [ ] Change notification/security/appearance settings
- [ ] Change password works
- [ ] Logout works and redirects to login

---

## Implementation Order

```
Phase 0 (CRITICAL - do first)
├── Fix 0.1: Update .env.production API URL
└── Fix 0.2: Add CORS origin to Hetzner VPS deployment

Phase 1 (Backend enrichment)
├── Fix 1.1: Add lastLoginAt/lastLoginIp to UserDto
├── Fix 1.2: Expand UserStatus enum + migration
├── Fix 1.3: Enrich EnrollmentDto (biggest change)
├── Fix 1.4: Add currentUsers to TenantResponse
└── Fix 1.5: Accept role+tenantId in CreateUserRequest

Phase 2 (Frontend adaptation)
├── Fix 2.1: Tenant fromJSON slug→domain mapping
├── Fix 2.2: Tenant create/update use slug
├── Fix 2.3: Settings nested→flat mapping
├── Fix 2.4: User role string→enum mapping
├── Fix 2.5: Enrollment fromJSON field mapping
└── Fix 2.6: User create role assignment flow

Phase 3 (Verification)
├── API integration tests
└── End-to-end smoke test
```

---

## Estimated Scope

| Phase | Side | Files Changed | Complexity |
|-------|------|--------------|------------|
| Phase 0 | Both | 2 files | Low |
| Phase 1 | Backend | ~8-10 files | Medium |
| Phase 2 | Frontend | ~8-10 files | Medium |
| Phase 3 | Both | New test files | Medium |

**Total:** ~20 files changed across both projects.
