# Database Schema

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document defines all new database tables required for the multi-modal authentication system. These will be created as Flyway migration `V16__auth_flow_system.sql` in the identity-core-api.

### Existing Tables (Reference)
The current database has 12 tables created by migrations V0-V15:
- `tenants`, `users`, `roles`, `permissions`, `role_permissions`, `user_roles`
- `biometric_data`, `refresh_tokens`, `audit_logs`, `user_settings`
- `guest_invitations`, `rate_limit_bucket`

### New Tables (This Migration)
8 new tables will be added:
1. `auth_methods` - System-wide auth method definitions
2. `tenant_auth_methods` - Per-tenant method enablement and config
3. `auth_flows` - Authentication flow definitions
4. `auth_flow_steps` - Steps within auth flows
5. `auth_sessions` - Runtime auth session tracking
6. `auth_session_steps` - Per-step execution records
7. `user_devices` - Registered device inventory
8. `user_enrollments` - Per-user, per-method enrollment status

---

## 2. Entity Relationship Diagram (Text)

```
tenants ──────< tenant_auth_methods >────── auth_methods
   |                                              |
   |                                              |
   ├──────< auth_flows                            |
   |           |                                  |
   |           └──────< auth_flow_steps >─────────┘
   |                       |          |
   |                       |          └── (fallback_method_id) ──> auth_methods
   |                       |
   |           ┌───────────┘
   |           |
   ├──────< auth_sessions
   |           |
   |           └──────< auth_session_steps >────── auth_flow_steps
   |
   ├──────< user_devices >────── users
   |
   └──────< user_enrollments >── users
```

---

## 3. Table Definitions

### 3.1 `auth_methods`

System-wide authentication method definitions. Pre-populated with 10 methods.

```sql
CREATE TABLE auth_methods (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type            VARCHAR(30)    NOT NULL UNIQUE,
    name            VARCHAR(100)   NOT NULL,
    description     TEXT,
    category        VARCHAR(20)    NOT NULL,
    platforms       TEXT[]         NOT NULL,
    requires_enrollment BOOLEAN    NOT NULL DEFAULT false,
    is_active       BOOLEAN        NOT NULL DEFAULT true,
    config_schema   JSONB          DEFAULT '{}',
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Constraints
ALTER TABLE auth_methods ADD CONSTRAINT chk_auth_method_type
    CHECK (type IN (
        'PASSWORD', 'EMAIL_OTP', 'SMS_OTP', 'TOTP', 'QR_CODE',
        'FACE', 'FINGERPRINT', 'VOICE', 'NFC_DOCUMENT', 'HARDWARE_KEY'
    ));

ALTER TABLE auth_methods ADD CONSTRAINT chk_auth_method_category
    CHECK (category IN ('BASIC', 'STANDARD', 'PREMIUM', 'ENTERPRISE'));

-- Index
CREATE INDEX idx_auth_methods_type ON auth_methods(type);
CREATE INDEX idx_auth_methods_active ON auth_methods(is_active) WHERE is_active = true;
```

**Column Details:**

| Column | Type | Description |
|---|---|---|
| `id` | UUID | Primary key |
| `type` | VARCHAR(30) | Unique method identifier (PASSWORD, FACE, etc.) |
| `name` | VARCHAR(100) | Display name |
| `description` | TEXT | Method description |
| `category` | VARCHAR(20) | BASIC, STANDARD, PREMIUM, ENTERPRISE |
| `platforms` | TEXT[] | Supported platforms: {web, android, ios, desktop} |
| `requires_enrollment` | BOOLEAN | Whether user must enroll before using |
| `is_active` | BOOLEAN | Globally active/inactive |
| `config_schema` | JSONB | JSON Schema for method-specific configuration |
| `created_at` | TIMESTAMPTZ | Record creation time |
| `updated_at` | TIMESTAMPTZ | Last update time |

### 3.2 `tenant_auth_methods`

Per-tenant enablement and configuration of auth methods.

```sql
CREATE TABLE tenant_auth_methods (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID           NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    auth_method_id  UUID           NOT NULL REFERENCES auth_methods(id) ON DELETE CASCADE,
    is_enabled      BOOLEAN        NOT NULL DEFAULT true,
    config          JSONB          DEFAULT '{}',
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_tenant_auth_method UNIQUE (tenant_id, auth_method_id)
);

-- Indexes
CREATE INDEX idx_tenant_auth_methods_tenant ON tenant_auth_methods(tenant_id);
CREATE INDEX idx_tenant_auth_methods_enabled ON tenant_auth_methods(tenant_id, is_enabled)
    WHERE is_enabled = true;
```

**Config JSONB Examples:**
```json
// Face Recognition config
{
  "liveness_level": "passive",        // passive | active | both
  "quality_threshold": 70,            // 0-100
  "confidence_threshold": 0.6,        // 0-1
  "max_enrollment_images": 3
}

// TOTP config
{
  "issuer_name": "MyCompany",
  "digits": 6,
  "period": 30,
  "algorithm": "SHA1"
}

// SMS OTP config
{
  "code_length": 6,
  "expiry_seconds": 180,
  "max_daily_sends": 10
}
```

### 3.3 `auth_flows`

Authentication flow definitions per tenant, per operation type.

```sql
CREATE TABLE auth_flows (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID           NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name            VARCHAR(100)   NOT NULL,
    description     TEXT,
    operation_type  VARCHAR(30)    NOT NULL,
    is_default      BOOLEAN        NOT NULL DEFAULT false,
    is_active       BOOLEAN        NOT NULL DEFAULT true,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_auth_flow_name UNIQUE (tenant_id, name)
);

-- Constraints
ALTER TABLE auth_flows ADD CONSTRAINT chk_operation_type
    CHECK (operation_type IN (
        'APP_LOGIN', 'DOOR_ACCESS', 'BUILDING_ACCESS', 'API_ACCESS',
        'TRANSACTION', 'ENROLLMENT', 'GUEST_ACCESS', 'EXAM_PROCTORING', 'CUSTOM'
    ));

-- Indexes
CREATE INDEX idx_auth_flows_tenant ON auth_flows(tenant_id);
CREATE INDEX idx_auth_flows_tenant_operation ON auth_flows(tenant_id, operation_type);
CREATE INDEX idx_auth_flows_default ON auth_flows(tenant_id, operation_type, is_default)
    WHERE is_default = true;

-- Partial unique: only one default flow per tenant+operation
CREATE UNIQUE INDEX uq_auth_flow_default
    ON auth_flows(tenant_id, operation_type)
    WHERE is_default = true AND is_active = true;
```

### 3.4 `auth_flow_steps`

Ordered steps within an auth flow.

```sql
CREATE TABLE auth_flow_steps (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_flow_id        UUID           NOT NULL REFERENCES auth_flows(id) ON DELETE CASCADE,
    auth_method_id      UUID           NOT NULL REFERENCES auth_methods(id),
    step_order          INTEGER        NOT NULL,
    is_required         BOOLEAN        NOT NULL DEFAULT true,
    timeout_seconds     INTEGER        NOT NULL DEFAULT 120,
    max_attempts        INTEGER        NOT NULL DEFAULT 3,
    fallback_method_id  UUID           REFERENCES auth_methods(id),
    allows_delegation   BOOLEAN        NOT NULL DEFAULT true,
    config              JSONB          DEFAULT '{}',

    CONSTRAINT uq_flow_step_order UNIQUE (auth_flow_id, step_order),
    CONSTRAINT chk_step_order_positive CHECK (step_order > 0),
    CONSTRAINT chk_timeout_positive CHECK (timeout_seconds > 0 AND timeout_seconds <= 600),
    CONSTRAINT chk_max_attempts CHECK (max_attempts > 0 AND max_attempts <= 10),
    CONSTRAINT chk_no_self_fallback CHECK (auth_method_id != fallback_method_id)
);

-- Indexes
CREATE INDEX idx_auth_flow_steps_flow ON auth_flow_steps(auth_flow_id);
CREATE INDEX idx_auth_flow_steps_order ON auth_flow_steps(auth_flow_id, step_order);
```

**Step Config JSONB Examples:**
```json
// Face step with active liveness
{
  "liveness_challenge": "BLINK",
  "min_confidence": 0.8
}

// QR Code step
{
  "qr_ttl_seconds": 60,
  "allow_printed_badge": true
}
```

### 3.5 `auth_sessions`

Runtime tracking of multi-step authentication attempts.

```sql
CREATE TABLE auth_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID           REFERENCES users(id),
    tenant_id           UUID           NOT NULL REFERENCES tenants(id),
    auth_flow_id        UUID           NOT NULL REFERENCES auth_flows(id),
    operation_type      VARCHAR(30)    NOT NULL,
    status              VARCHAR(20)    NOT NULL DEFAULT 'CREATED',
    current_step_order  INTEGER        NOT NULL DEFAULT 1,
    client_platform     VARCHAR(20),
    client_device_id    VARCHAR(255),
    ip_address          VARCHAR(45),
    user_agent          TEXT,
    started_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMP WITH TIME ZONE,
    expires_at          TIMESTAMP WITH TIME ZONE NOT NULL,
    metadata            JSONB          DEFAULT '{}'
);

-- Constraints
ALTER TABLE auth_sessions ADD CONSTRAINT chk_session_status
    CHECK (status IN ('CREATED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'EXPIRED', 'CANCELLED'));

-- Indexes
CREATE INDEX idx_auth_sessions_user ON auth_sessions(user_id, status);
CREATE INDEX idx_auth_sessions_tenant ON auth_sessions(tenant_id, status);
CREATE INDEX idx_auth_sessions_expires ON auth_sessions(expires_at)
    WHERE status IN ('CREATED', 'IN_PROGRESS');
CREATE INDEX idx_auth_sessions_created ON auth_sessions(started_at DESC);

-- Cleanup index for expired sessions
CREATE INDEX idx_auth_sessions_cleanup ON auth_sessions(expires_at, status)
    WHERE status IN ('CREATED', 'IN_PROGRESS');
```

**Metadata JSONB:**
```json
{
  "auth_level": 3,
  "methods_completed": ["PASSWORD", "FACE"],
  "total_duration_ms": 45000,
  "delegation_used": false
}
```

### 3.6 `auth_session_steps`

Per-step execution records within an auth session.

```sql
CREATE TABLE auth_session_steps (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID           NOT NULL REFERENCES auth_sessions(id) ON DELETE CASCADE,
    auth_flow_step_id   UUID           NOT NULL REFERENCES auth_flow_steps(id),
    method_type         VARCHAR(30)    NOT NULL,
    status              VARCHAR(20)    NOT NULL DEFAULT 'PENDING',
    attempt_count       INTEGER        NOT NULL DEFAULT 0,
    delegated           BOOLEAN        NOT NULL DEFAULT false,
    delegation_token    VARCHAR(255),
    delegation_device_id VARCHAR(255),
    delegation_expires  TIMESTAMP WITH TIME ZONE,
    started_at          TIMESTAMP WITH TIME ZONE,
    completed_at        TIMESTAMP WITH TIME ZONE,
    result              JSONB          DEFAULT '{}',

    CONSTRAINT uq_session_step UNIQUE (session_id, auth_flow_step_id),
    CONSTRAINT chk_step_status CHECK (status IN (
        'PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'SKIPPED', 'DELEGATED'
    ))
);

-- Indexes
CREATE INDEX idx_auth_session_steps_session ON auth_session_steps(session_id);
CREATE INDEX idx_auth_session_steps_delegation ON auth_session_steps(delegation_token)
    WHERE delegation_token IS NOT NULL;
```

**Result JSONB Examples:**
```json
// Password step result
{
  "verified": true,
  "email_matched": "admin@fivucsas.local"
}

// Face step result
{
  "verified": true,
  "confidence": 0.95,
  "liveness_score": 0.88,
  "quality_score": 82
}

// Delegation result
{
  "verified": true,
  "delegated_from": "desktop",
  "delegated_to": "android",
  "companion_device": "Samsung Galaxy S24"
}
```

### 3.7 `user_devices`

Registered devices per user for capability tracking and delegation.

```sql
CREATE TABLE user_devices (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id           UUID           NOT NULL REFERENCES tenants(id),
    device_name         VARCHAR(100),
    platform            VARCHAR(20)    NOT NULL,
    device_fingerprint  VARCHAR(255)   NOT NULL,
    capabilities        TEXT[]         NOT NULL DEFAULT '{}',
    push_token          TEXT,
    is_trusted          BOOLEAN        NOT NULL DEFAULT false,
    last_used_at        TIMESTAMP WITH TIME ZONE,
    registered_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_device UNIQUE (user_id, device_fingerprint),
    CONSTRAINT chk_device_platform CHECK (platform IN ('web', 'android', 'ios', 'desktop'))
);

-- Indexes
CREATE INDEX idx_user_devices_user ON user_devices(user_id);
CREATE INDEX idx_user_devices_tenant ON user_devices(tenant_id);
CREATE INDEX idx_user_devices_trusted ON user_devices(user_id, is_trusted) WHERE is_trusted = true;
CREATE INDEX idx_user_devices_push ON user_devices(user_id, push_token) WHERE push_token IS NOT NULL;
```

**Capabilities Array Values:**
`camera`, `nfc`, `fingerprint`, `microphone`, `bluetooth`, `usb`, `gps`, `accelerometer`

### 3.8 `user_enrollments`

Tracks enrollment status for each auth method per user.

```sql
CREATE TABLE user_enrollments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID           NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id           UUID           NOT NULL REFERENCES tenants(id),
    auth_method_type    VARCHAR(30)    NOT NULL,
    status              VARCHAR(20)    NOT NULL DEFAULT 'NOT_ENROLLED',
    enrollment_data     JSONB          DEFAULT '{}',
    enrolled_at         TIMESTAMP WITH TIME ZONE,
    expires_at          TIMESTAMP WITH TIME ZONE,
    revoked_at          TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_enrollment UNIQUE (user_id, auth_method_type),
    CONSTRAINT chk_enrollment_status CHECK (status IN (
        'NOT_ENROLLED', 'PENDING', 'ENROLLED', 'FAILED', 'REVOKED', 'EXPIRED'
    )),
    CONSTRAINT chk_enrollment_method CHECK (auth_method_type IN (
        'PASSWORD', 'EMAIL_OTP', 'SMS_OTP', 'TOTP', 'QR_CODE',
        'FACE', 'FINGERPRINT', 'VOICE', 'NFC_DOCUMENT', 'HARDWARE_KEY'
    ))
);

-- Indexes
CREATE INDEX idx_user_enrollments_user ON user_enrollments(user_id);
CREATE INDEX idx_user_enrollments_user_status ON user_enrollments(user_id, status);
CREATE INDEX idx_user_enrollments_tenant ON user_enrollments(tenant_id);
CREATE INDEX idx_user_enrollments_method ON user_enrollments(auth_method_type, status);
```

**Enrollment Data JSONB Examples:**

```json
// FACE enrollment
{
  "quality_score": 85,
  "liveness_score": 0.92,
  "embedding_dimension": 512,
  "model": "ArcFace",
  "image_count": 3,
  "biometric_processor_user_id": "uuid-in-bp-db"
}

// FINGERPRINT enrollment (FIDO2)
{
  "credential_id": "base64url-credential-id",
  "public_key_cose": "base64url-public-key",
  "sign_count": 0,
  "aaguid": "authenticator-guid",
  "transports": ["internal"],
  "device_name": "Samsung Galaxy S24"
}

// TOTP enrollment
{
  "secret_encrypted": "AES-256-encrypted-base32",
  "algorithm": "SHA1",
  "digits": 6,
  "period": 30,
  "backup_codes_hash": ["hash1", "hash2", "..."]
}

// NFC_DOCUMENT enrollment
{
  "document_type": "PASSPORT",
  "document_number_hash": "sha256-hash",
  "nationality": "TR",
  "expiry_date": "2030-01-01",
  "face_match_score": 0.94,
  "chip_authenticated": true,
  "passive_auth": true,
  "active_auth": true
}

// QR_CODE enrollment
{
  "qr_token_encrypted": "AES-256-encrypted-token",
  "issued_at": "2026-02-17T10:30:00Z",
  "rotated_count": 0
}

// HARDWARE_KEY enrollment
{
  "credential_id": "base64url-credential-id",
  "public_key_cose": "base64url-public-key",
  "sign_count": 5,
  "aaguid": "authenticator-guid",
  "transports": ["usb", "nfc"],
  "key_name": "YubiKey 5 NFC"
}

// VOICE enrollment
{
  "samples_count": 3,
  "avg_snr": 22.5,
  "model": "ECAPA-TDNN",
  "embedding_dimension": 192,
  "biometric_processor_user_id": "uuid-in-bp-db"
}
```

---

## 4. Seed Data

### 4.1 Auth Methods (10 records)

```sql
INSERT INTO auth_methods (type, name, description, category, platforms, requires_enrollment, is_active) VALUES
('PASSWORD',     'Password',           'Traditional password authentication',        'BASIC',      '{web,android,ios,desktop}', true,  true),
('EMAIL_OTP',    'Email OTP',          'One-time password sent via email',           'BASIC',      '{web,android,ios,desktop}', false, true),
('SMS_OTP',      'SMS OTP',            'One-time password sent via SMS',             'STANDARD',   '{web,android,ios,desktop}', true,  true),
('TOTP',         'Authenticator App',  'Time-based OTP via authenticator app',       'STANDARD',   '{web,android,ios,desktop}', true,  true),
('QR_CODE',      'QR Code',            'Scan QR code for authentication',            'STANDARD',   '{web,android,ios,desktop}', true,  true),
('FACE',         'Face Recognition',   'Biometric face verification',                'PREMIUM',    '{web,android,ios,desktop}', true,  true),
('FINGERPRINT',  'Fingerprint',        'Biometric fingerprint verification',         'PREMIUM',    '{android,ios,desktop}',     true,  true),
('VOICE',        'Voice Recognition',  'Biometric voice verification',               'PREMIUM',    '{web,android,ios,desktop}', true,  false),
('NFC_DOCUMENT', 'NFC Document',       'ID document verification via NFC',           'ENTERPRISE', '{android,ios}',             true,  true),
('HARDWARE_KEY', 'Hardware Key',       'FIDO2/WebAuthn hardware security key',       'ENTERPRISE', '{web,android,ios,desktop}', true,  true);
```

### 4.2 System Tenant Default Auth Flow

```sql
-- Enable Password for system tenant
INSERT INTO tenant_auth_methods (tenant_id, auth_method_id, is_enabled)
SELECT t.id, am.id, true
FROM tenants t, auth_methods am
WHERE t.slug = 'system' AND am.type = 'PASSWORD';

-- Create default APP_LOGIN flow for system tenant
INSERT INTO auth_flows (tenant_id, name, description, operation_type, is_default, is_active)
SELECT t.id, 'Default Login', 'Standard password authentication', 'APP_LOGIN', true, true
FROM tenants t WHERE t.slug = 'system';

-- Add password step
INSERT INTO auth_flow_steps (auth_flow_id, auth_method_id, step_order, is_required, timeout_seconds, max_attempts)
SELECT af.id, am.id, 1, true, 120, 5
FROM auth_flows af
JOIN tenants t ON af.tenant_id = t.id
JOIN auth_methods am ON am.type = 'PASSWORD'
WHERE t.slug = 'system' AND af.name = 'Default Login';

-- Create PASSWORD enrollment for existing admin user
INSERT INTO user_enrollments (user_id, tenant_id, auth_method_type, status, enrolled_at)
SELECT u.id, u.tenant_id, 'PASSWORD', 'ENROLLED', u.created_at
FROM users u WHERE u.email = 'admin@fivucsas.local';
```

---

## 5. Migration Script Header

```sql
-- V16__auth_flow_system.sql
-- Multi-Modal Authentication Flow System
--
-- New tables:
--   auth_methods           - System-wide auth method definitions (10 pre-populated)
--   tenant_auth_methods    - Per-tenant method enablement and config
--   auth_flows             - Authentication flow definitions per tenant
--   auth_flow_steps        - Ordered steps within auth flows
--   auth_sessions          - Runtime auth session tracking
--   auth_session_steps     - Per-step execution records
--   user_devices           - Registered device inventory
--   user_enrollments       - Per-user enrollment status per method
--
-- Dependencies: V15 (latest existing migration)
-- Author: FIVUCSAS Team
-- Date: 2026-02
```

---

## 6. Backward Compatibility

### 6.1 Existing `biometric_data` Table
The existing `biometric_data` table (from V4) stores face embeddings directly in the identity-core-api database. This table remains unchanged. The new `user_enrollments` table with `auth_method_type = 'FACE'` serves as a metadata layer on top, tracking enrollment status and linking to the biometric processor's data.

### 6.2 Existing `Tenant` Columns
The `tenants.biometric_enabled` and `tenants.mfa_required` columns remain for backward compatibility. New code should use `tenant_auth_methods` for method-specific configuration. A future migration can deprecate these columns.

### 6.3 Existing Login Flow
The current `POST /api/v1/auth/login` endpoint continues to work as-is (password-only). The new multi-step auth session system is exposed via `POST /api/v1/auth/sessions`. Clients can gradually migrate to the new system.

---

## 7. Performance Considerations

### 7.1 Expected Data Volumes (per tenant)
| Table | Records | Growth Rate |
|---|---|---|
| auth_methods | 10 (fixed) | Static |
| tenant_auth_methods | ~10 per tenant | Slow |
| auth_flows | 2-5 per tenant | Slow |
| auth_flow_steps | 5-15 per tenant | Slow |
| auth_sessions | 100-10,000/day | High (with cleanup) |
| auth_session_steps | 200-30,000/day | High (with cleanup) |
| user_devices | 1-5 per user | Slow |
| user_enrollments | 1-5 per user | Slow |

### 7.2 Cleanup Strategy
- `auth_sessions` older than 24 hours with terminal status: DELETE
- `auth_session_steps` cascade-deleted with sessions
- Scheduled job runs every hour
- Audit log preserves historical records separately

### 7.3 Index Strategy
- All foreign keys are indexed
- Composite indexes on frequently-queried combinations (tenant+status, user+method)
- Partial indexes where applicable (WHERE is_active = true, WHERE status IN (...))
- No full-text search needed on these tables
