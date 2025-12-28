# Identity Core API - Security Analysis & Architectural Decision

**Date:** December 28, 2025
**Author:** Claude Code Analysis
**Status:** Critical Review for January 7, 2026 Defense

---

## Executive Summary

This document analyzes whether `identity-core-api` (Spring Boot) is necessary alongside `biometric-processor` (FastAPI), examining security implementations, gaps, and providing recommendations.

**Verdict:** Keep both services, but fix critical security gaps before production.

---

## 1. Architecture Overview

### Current Architecture
```
┌─────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Clients   │────>│  identity-core-api  │────>│  biometric-processor │
│  (Web/App)  │     │    (Spring Boot)    │     │      (FastAPI)       │
└─────────────┘     │       :8080         │     │        :8001         │
                    └──────────┬──────────┘     └──────────┬───────────┘
                               │                           │
                               └───────────┬───────────────┘
                                           │
                                    ┌──────▼──────┐
                                    │  PostgreSQL │
                                    │  + pgvector │
                                    └─────────────┘
```

### Service Responsibilities

| Service | Responsibility | Completion |
|---------|---------------|------------|
| **identity-core-api** | Authentication, Authorization, User Management | 68% |
| **biometric-processor** | Face Recognition, Liveness Detection, ML Processing | 100% |

---

## 2. identity-core-api Security Analysis

### 2.1 What's Implemented (Good)

#### JWT Authentication
- **Location:** `src/main/java/com/fivucsas/identity/security/JwtService.java`
- **Algorithm:** HMAC-SHA (HS512)
- **Access Token Expiry:** 24 hours
- **Refresh Token Expiry:** 7 days
- **Secret:** Base64-encoded, 256+ bits

#### Password Security
- **Location:** `src/main/java/com/fivucsas/identity/infrastructure/adapter/PasswordEncoderAdapter.java`
- **Algorithm:** BCrypt (Spring Security default strength)
- **Storage:** Hashed passwords only, never plaintext

#### Refresh Token Management
- **Location:** `src/main/java/com/fivucsas/identity/service/RefreshTokenService.java`
- **Features:**
  - Database-backed token storage
  - Token rotation on refresh
  - Revocation tracking
  - IP address and User-Agent logging
  - Automatic cleanup of expired tokens

#### Authentication Filter
- **Location:** `src/main/java/com/fivucsas/identity/security/JwtAuthenticationFilter.java`
- **Type:** OncePerRequestFilter
- **Flow:** Extract Bearer token → Validate → Load user → Set SecurityContext

### 2.2 Critical Security Gaps

#### GAP 1: No User Data Isolation (CRITICAL)
```java
// CURRENT: Any authenticated user can access ANY user's data
@GetMapping("/{id}")
public ResponseEntity<UserResponse> getUserById(@PathVariable UUID id) {
    return userService.findById(id)  // NO ownership check!
        .map(ResponseEntity::ok)
        .orElse(ResponseEntity.notFound().build());
}
```

**Impact:** User A can view/edit/delete User B's profile and biometric data.

#### GAP 2: No RBAC Implementation (CRITICAL)
```java
// CURRENT: All users get ROLE_USER
List<SimpleGrantedAuthority> authorities = Collections.singletonList(
    new SimpleGrantedAuthority("ROLE_USER")  // Hardcoded!
);
// TODO comments throughout codebase indicate RBAC not implemented
```

**Impact:** No admin vs user distinction. All authenticated users have same permissions.

#### GAP 3: No Multi-Tenancy Enforcement (HIGH)
- `X-Tenant-ID` header is configured in CORS but never processed
- No tenant filtering in database queries
- All data shared across what should be isolated tenants

**Impact:** In a multi-tenant deployment, tenants can see each other's data.

#### GAP 4: No Service-to-Service Authentication (MEDIUM)
```java
// BiometricServiceAdapter calls FastAPI with NO authentication
WebClient.builder()
    .baseUrl("http://localhost:8001")  // No API key, no JWT
    .build();
```

**Impact:** Anyone who can reach port 8001 can call biometric endpoints directly.

#### GAP 5: Biometric Endpoint Authorization (CRITICAL)
```java
// CURRENT: Any authenticated user can enroll biometrics for ANY user
@PostMapping("/enroll/{userId}")
public ResponseEntity<?> enrollBiometric(@PathVariable UUID userId, ...) {
    // NO check that authenticated user == userId
}
```

**Impact:** User A can enroll fake biometrics for User B.

### 2.3 Security Configuration Summary

| Feature | Status | Risk Level |
|---------|--------|------------|
| JWT Token Generation | ✅ Implemented | Low |
| JWT Token Validation | ✅ Implemented | Low |
| Password Hashing (BCrypt) | ✅ Implemented | Low |
| Refresh Token Storage | ✅ Implemented | Low |
| Token Revocation | ✅ Implemented | Low |
| CSRF Protection | ✅ Disabled (stateless API) | Low |
| CORS Configuration | ✅ Configured | Low |
| **User Data Isolation** | ❌ **NOT IMPLEMENTED** | **CRITICAL** |
| **RBAC** | ❌ **NOT IMPLEMENTED** | **CRITICAL** |
| **Multi-Tenancy** | ❌ **NOT IMPLEMENTED** | **HIGH** |
| **Service-to-Service Auth** | ❌ **NOT IMPLEMENTED** | **MEDIUM** |

---

## 3. biometric-processor Security Analysis

### 3.1 What's Implemented (Good)

#### API Key Authentication
- **Location:** `app/api/middleware/api_key_auth.py`
- **Method:** X-API-Key header
- **Storage:** SHA-256 hashed keys (plaintext never stored)
- **Features:** Key prefix tracking, expiration, soft delete

#### Security Headers (OWASP Compliant)
- **Location:** `app/api/middleware/security_headers.py`
- **Headers:**
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `X-XSS-Protection: 1; mode=block`
  - `Strict-Transport-Security` (HTTPS)
  - `Content-Security-Policy`
  - `Referrer-Policy`

#### Rate Limiting (Tier-Based)
- **Location:** `app/api/middleware/rate_limit.py`
- **Tiers:** Free (30/min), Standard (60/min), Premium (300/min), Unlimited
- **Per-Endpoint Limits:**
  - Enrollment: 10 req/min
  - Verification: 30 req/min
  - Search: 20 req/min
  - Batch: 5 req/min

#### Input Validation & Sanitization
- **Location:** `app/api/middleware/security.py`
- **Protection Against:**
  - SQL Injection patterns
  - XSS patterns
  - Path traversal attacks

#### CORS Configuration
- **Location:** `app/main.py`
- **Rule:** No wildcards allowed in production
- **Validation:** Runtime check prevents misconfiguration

### 3.2 Security Gaps

#### GAP 1: No User Model
- No dedicated Users table
- User IDs are just strings passed in requests
- No user authentication (relies on API keys)

#### GAP 2: Weak Tenant Isolation
- `tenant_id` exists in models but not enforced
- Developers must manually check tenant ownership
- No automatic tenant scoping in queries

#### GAP 3: Admin Routes Unprotected
- **Location:** `app/api/routes/admin.py`
- Admin endpoints exist but lack authorization decorators

### 3.3 Security Configuration Summary

| Feature | Status | Risk Level |
|---------|--------|------------|
| API Key Authentication | ✅ Implemented | Low |
| SHA-256 Key Hashing | ✅ Implemented | Low |
| Security Headers | ✅ Implemented | Low |
| Rate Limiting | ✅ Implemented | Low |
| Input Validation | ✅ Implemented | Low |
| CORS (No Wildcards) | ✅ Implemented | Low |
| Path Traversal Protection | ✅ Implemented | Low |
| **User Management** | ❌ **NO USER MODEL** | **HIGH** |
| **Tenant Isolation** | ⚠️ **WEAK** | **MEDIUM** |
| **Admin Authorization** | ⚠️ **INCOMPLETE** | **MEDIUM** |

---

## 4. Comparative Analysis

### Security Features Comparison

| Feature | identity-core-api | biometric-processor |
|---------|-------------------|---------------------|
| User Authentication | ✅ JWT | ✅ API Key |
| Password Management | ✅ BCrypt | ❌ None |
| Token Refresh/Revocation | ✅ DB-backed | ❌ None |
| Security Headers | ⚠️ Basic | ✅ OWASP |
| Rate Limiting | ❌ None | ✅ Tier-based |
| Input Validation | ⚠️ JPA only | ✅ Middleware |
| User Data Model | ✅ Full User entity | ❌ No user model |
| User Isolation | ❌ Not enforced | N/A |
| RBAC | ❌ Not implemented | ❌ Not implemented |
| Multi-Tenancy | ❌ Not implemented | ⚠️ Partial |

### What Each Service Provides Uniquely

**identity-core-api provides:**
- User registration and login flows
- Password hashing and verification
- JWT token lifecycle management
- Refresh token rotation and revocation
- User entity with profile data

**biometric-processor provides:**
- OWASP-compliant security headers
- Tier-based rate limiting
- SQL injection/XSS protection middleware
- API key management system
- All biometric ML functionality

---

## 5. Architectural Decision

### Question: Should We Remove identity-core-api?

### Answer: NO - Keep Both Services

**Rationale:**

1. **Separation of Concerns**
   - Authentication/Identity is a distinct domain from Biometric Processing
   - Different scaling requirements (auth is lightweight, ML is heavy)

2. **Technology Fit**
   - Spring Security is mature for enterprise authentication
   - FastAPI is optimal for ML/async processing

3. **Migration Risk**
   - Moving auth to FastAPI requires 2-3 days minimum
   - Risk of introducing bugs before defense deadline

4. **Academic Value**
   - Demonstrates microservices architecture
   - Shows polyglot programming (Java + Python)

### Alternative Considered: Merge into biometric-processor

**Would require adding to FastAPI:**
- User model and migrations
- JWT token generation/validation
- Password hashing (bcrypt)
- Refresh token management
- Login/Register endpoints

**Estimated effort:** 2-3 days
**Risk before deadline:** HIGH

---

## 6. TODO List - Security Fixes Required

### Priority 1: CRITICAL (Before Defense)

#### TODO 1.1: Add User Ownership Checks in identity-core-api
**Location:** All controller methods in `UserController.java`, `BiometricController.java`
**Effort:** 2-3 hours

```java
// Add to each endpoint that accesses user data
private void validateUserOwnership(UUID requestedUserId, Authentication auth) {
    User currentUser = (User) auth.getPrincipal();
    if (!currentUser.getId().equals(requestedUserId) &&
        !hasRole(auth, "ADMIN")) {
        throw new ForbiddenException("Cannot access other user's data");
    }
}
```

**Files to modify:**
- [ ] `UserController.java` - getUserById, updateUser, deleteUser
- [ ] `BiometricController.java` - enrollBiometric, verifyBiometric
- [ ] `StatisticsController.java` - restrict to admin only

#### TODO 1.2: Implement Basic RBAC
**Location:** `CustomUserDetailsService.java`, database schema
**Effort:** 4-6 hours

```sql
-- Add to Flyway migration
CREATE TABLE roles (
    id UUID PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id),
    role_id UUID REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);

INSERT INTO roles (id, name) VALUES
    (gen_random_uuid(), 'ROLE_USER'),
    (gen_random_uuid(), 'ROLE_ADMIN'),
    (gen_random_uuid(), 'ROLE_TENANT_ADMIN');
```

**Files to modify:**
- [ ] Add `V7__add_roles_table.sql` migration
- [ ] Create `Role.java` entity
- [ ] Update `User.java` with roles relationship
- [ ] Update `CustomUserDetailsService.java` to load roles
- [ ] Add `@PreAuthorize` annotations to controllers

#### TODO 1.3: Protect Admin Routes in biometric-processor
**Location:** `app/api/routes/admin.py`
**Effort:** 1 hour

```python
# Add to all admin endpoints
@router.get("/stats", dependencies=[Depends(RequireAPIKey(required_scope="admin"))])
async def get_stats():
    ...
```

### Priority 2: HIGH (Before Production)

#### TODO 2.1: Implement Multi-Tenancy in identity-core-api
**Effort:** 1-2 days

- [ ] Add `tenant_id` column to users table
- [ ] Create `TenantContext` thread-local holder
- [ ] Add tenant filter to all repository queries
- [ ] Extract tenant from JWT claims or header

#### TODO 2.2: Service-to-Service Authentication
**Effort:** 4-6 hours

- [ ] Generate API key for identity-core-api
- [ ] Add X-API-Key header to BiometricServiceAdapter
- [ ] Validate API key in biometric-processor for internal calls

#### TODO 2.3: Enforce Tenant Isolation in biometric-processor
**Effort:** 4-6 hours

- [ ] Create `TenantMiddleware` to extract tenant from API key
- [ ] Add automatic tenant filtering to repositories
- [ ] Validate tenant ownership on all data access

### Priority 3: MEDIUM (Future Enhancement)

#### TODO 3.1: Add Rate Limiting to identity-core-api
- [ ] Add Spring Boot rate limiting (bucket4j or resilience4j)
- [ ] Configure per-endpoint limits

#### TODO 3.2: Add Security Headers to identity-core-api
- [ ] Add OWASP security headers via Spring Security

#### TODO 3.3: Implement Audit Logging
- [ ] Replace SLF4J audit with database-backed audit log
- [ ] Track all security-relevant events

#### TODO 3.4: Add Email Verification
- [ ] Implement email sending service
- [ ] Add verification token flow

#### TODO 3.5: Add Password Reset
- [ ] Implement password reset token
- [ ] Add reset email flow

---

## 7. Summary

### Current State
- **identity-core-api:** Has auth infrastructure but critical security gaps
- **biometric-processor:** Has excellent middleware security but no user management

### Recommendation
1. **Keep both services** for defense
2. **Fix critical gaps** (user isolation, basic RBAC) - 1 day effort
3. **Document architecture** decision for presentation
4. **Plan post-defense** improvements for production readiness

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| User data breach | HIGH (current) | CRITICAL | Implement TODO 1.1 |
| Privilege escalation | HIGH (current) | HIGH | Implement TODO 1.2 |
| Cross-tenant data leak | MEDIUM | HIGH | Implement TODO 2.1 |
| Direct API bypass | LOW | MEDIUM | Implement TODO 2.2 |

---

## 8. Files Examined

### identity-core-api (47 files)
- `src/main/java/com/fivucsas/identity/config/SecurityConfig.java`
- `src/main/java/com/fivucsas/identity/security/JwtService.java`
- `src/main/java/com/fivucsas/identity/security/JwtAuthenticationFilter.java`
- `src/main/java/com/fivucsas/identity/security/CustomUserDetailsService.java`
- `src/main/java/com/fivucsas/identity/service/RefreshTokenService.java`
- `src/main/java/com/fivucsas/identity/controller/UserController.java`
- `src/main/java/com/fivucsas/identity/controller/BiometricController.java`
- `src/main/java/com/fivucsas/identity/infrastructure/adapter/BiometricServiceAdapter.java`
- And 39 more...

### biometric-processor (Key files)
- `app/api/middleware/api_key_auth.py`
- `app/api/middleware/security_headers.py`
- `app/api/middleware/rate_limit.py`
- `app/api/middleware/security.py`
- `app/core/config.py`
- `app/infrastructure/database/models.py`
- `app/api/routes/admin.py`

---

**Document Version:** 1.0
**Last Updated:** December 28, 2025
**Next Review:** After January 7, 2026 Defense
