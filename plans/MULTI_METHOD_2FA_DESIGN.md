# Adaptive Multi-Factor Authentication Engine

**Author:** FIVUCSAS Engineering  
**Date:** 2026-04-05  
**Version:** 2.0  
**Status:** Final Design  
**Scope:** Backend (identity-core-api), Frontend (web-app), Widget SDK, Admin UI

---

## 1. Problem Statement

### 1.1 Current Limitations

The authentication system has three fundamental rigidity issues:

**A) Password is hardcoded as step 1.** The backend assumes `stepOrder == 1` is always PASSWORD. Tenants cannot configure passwordless flows (e.g., Face-only access for a smart building) or biometric-first flows.

**B) Only one 2FA method per flow.** The system extracts a single `twoFactorMethod` from `stepOrder == 2`. Users get no choice. Tenant admins must create separate flows for each method.

**C) Maximum 2 steps.** The architecture assumes `Password → One 2FA`. There's no support for 3FA (e.g., Password → TOTP → Face for high-security operations like financial transactions).

### 1.2 Target State

A fully flexible **Multi-Factor Authentication Engine** where:

- Tenant admins configure **1 to N stages** (not limited to 2)
- Each stage is either **SEQUENTIAL** (one fixed method) or **CHOICE** (user picks from multiple methods)
- **No method is hardcoded** — PASSWORD is just another auth method, not special
- A 3FA flow is possible: `Face → Fingerprint → Voice` (no password at all)
- Users see only methods they've **enrolled in** and can set a **preferred method** per stage

### 1.3 Real-World Flow Examples

| Scenario | Flow Configuration | MFA Level |
|----------|-------------------|-----------|
| Simple login | `PASSWORD` | 1FA |
| Standard 2FA | `PASSWORD → CHOICE[EMAIL_OTP, TOTP]` | 2FA |
| Biometric-first | `FACE → PASSWORD` | 2FA |
| Passwordless | `CHOICE[FACE, FINGERPRINT, HARDWARE_KEY]` | 1FA |
| High security | `PASSWORD → CHOICE[TOTP, EMAIL_OTP] → FACE` | 3FA |
| Exam proctoring | `FACE → VOICE → NFC_DOCUMENT` | 3FA |
| Smart building | `FINGERPRINT` | 1FA |
| Financial txn | `PASSWORD → TOTP → CHOICE[FACE, VOICE]` | 3FA |

---

## 2. Architecture

### 2.1 Core Concept: Steps and Choices

```
AuthFlow
  └─ Step 1 (order=1, type=SEQUENTIAL|CHOICE)
  │    ├─ [SEQUENTIAL] → exactly one AuthMethod
  │    └─ [CHOICE]     → multiple AuthMethods, user picks one
  │
  └─ Step 2 (order=2, type=SEQUENTIAL|CHOICE)
  │    └─ ...
  │
  └─ Step N (order=N, max 5)
       └─ ...
```

**Rules:**
1. A flow has 1–5 steps (configurable max, default 3)
2. Each step has a `step_type`: `SEQUENTIAL` or `CHOICE`
3. `SEQUENTIAL` step → one required method
4. `CHOICE` step → multiple methods, user picks one they've enrolled in
5. Each step has an optional `fallback_method_id` for when the user has no enrollment
6. Steps execute in order; all must pass for authentication to succeed

### 2.2 No Hardcoded PASSWORD

PASSWORD becomes a regular auth method in the `auth_methods` table. It has:
- `requires_enrollment: false` (everyone has a password by default)
- `category: BASIC`
- `platforms: [WEB, ANDROID, IOS, DESKTOP]`

A tenant that wants passwordless login simply doesn't include PASSWORD in any step.

### 2.3 Login Flow (New)

```
CLIENT: POST /auth/login
  body: { email: "user@example.com" }      ← Note: NO password in initial request

SERVER:
  1. Look up user by email
  2. Find default APP_LOGIN flow for tenant
  3. Build step chain:
     
     For each step (ordered by step_order):
       if SEQUENTIAL:
         method = step.authMethod
         check user enrollment → add to required steps
       if CHOICE:
         methods = step.alternativeMethods
         filter by user enrollments → add available methods per step
  
  4. Return step chain to client:
     {
       "sessionToken": "temp-session-abc",
       "steps": [
         {
           "stepNumber": 1,
           "stepType": "SEQUENTIAL",
           "method": { "type": "PASSWORD", "name": "Password" },
           "status": "PENDING"
         },
         {
           "stepNumber": 2,
           "stepType": "CHOICE",
           "availableMethods": [
             { "type": "TOTP", "name": "Authenticator App", "enrolled": true, "preferred": true },
             { "type": "EMAIL_OTP", "name": "Email OTP", "enrolled": true },
             { "type": "FACE", "name": "Face Recognition", "enrolled": false }
           ],
           "status": "PENDING"
         },
         {
           "stepNumber": 3,
           "stepType": "SEQUENTIAL",
           "method": { "type": "FACE", "name": "Face Verification" },
           "status": "PENDING"
         }
       ],
       "totalSteps": 3,
       "currentStep": 1
     }

CLIENT: Steps through each one:
  Step 1 → POST /auth/step/verify { sessionToken, step: 1, method: "PASSWORD", data: { password: "..." } }
  Step 2 → POST /auth/step/verify { sessionToken, step: 2, method: "TOTP", data: { code: "123456" } }
  Step 3 → POST /auth/step/verify { sessionToken, step: 3, method: "FACE", data: { image: "base64..." } }

SERVER: After all steps pass → issue JWT tokens
  { accessToken, refreshToken, expiresIn, user }
```

### 2.4 Session-Based Step Verification

Instead of verifying everything in one request, use a **session-based step chain**:

```
AuthSession (Redis, TTL 10 minutes)
  ├── sessionToken: "temp-abc-123"
  ├── userId: UUID
  ├── flowId: UUID
  ├── steps: [
  │     { order: 1, method: "PASSWORD", status: "COMPLETED", verifiedAt: "..." },
  │     { order: 2, method: null, status: "PENDING" },       ← CHOICE, not yet selected
  │     { order: 3, method: "FACE", status: "PENDING" }
  │   ]
  ├── currentStep: 2
  ├── createdAt: timestamp
  └── expiresAt: timestamp (createdAt + 10min)
```

**Security:** The session token is short-lived (10 min), bound to the user+flow, and stored in Redis. Each step verification updates the session. Tokens are only issued when ALL steps are COMPLETED.

---

## 3. Database Changes

### 3.1 Migration V30: Adaptive MFA

```sql
-- 1. Add step_type to auth_flow_steps
ALTER TABLE auth_flow_steps 
    ADD COLUMN step_type VARCHAR(20) NOT NULL DEFAULT 'SEQUENTIAL';

ALTER TABLE auth_flow_steps 
    ADD CONSTRAINT chk_step_type CHECK (step_type IN ('SEQUENTIAL', 'CHOICE'));

-- 2. Join table for CHOICE step methods
CREATE TABLE auth_flow_step_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    step_id UUID NOT NULL REFERENCES auth_flow_steps(id) ON DELETE CASCADE,
    auth_method_id UUID NOT NULL REFERENCES auth_methods(id) ON DELETE CASCADE,
    display_order INTEGER NOT NULL DEFAULT 0,
    UNIQUE(step_id, auth_method_id)
);

CREATE INDEX idx_step_methods_step ON auth_flow_step_methods(step_id);

-- 3. User preferred method per step position
ALTER TABLE users ADD COLUMN preferred_2fa_method VARCHAR(30);

-- 4. Increase max steps (relax any 2-step assumptions)
-- The unique constraint (auth_flow_id, step_order) already supports N steps.
-- Just ensure step_order allows 1-5:
ALTER TABLE auth_flow_steps DROP CONSTRAINT IF EXISTS chk_step_order;
ALTER TABLE auth_flow_steps 
    ADD CONSTRAINT chk_step_order CHECK (step_order >= 1 AND step_order <= 5);

-- 5. Auth session tracking (for step-by-step verification)
CREATE TABLE auth_sessions_mfa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_token VARCHAR(128) NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    flow_id UUID NOT NULL REFERENCES auth_flows(id),
    current_step INTEGER NOT NULL DEFAULT 1,
    total_steps INTEGER NOT NULL,
    steps_data JSONB NOT NULL DEFAULT '[]',
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_mfa_session_token ON auth_sessions_mfa(session_token);
CREATE INDEX idx_mfa_session_expiry ON auth_sessions_mfa(expires_at) 
    WHERE completed_at IS NULL;

-- 6. Seed a CHOICE flow for Marmara tenant
INSERT INTO auth_flows (id, tenant_id, name, description, flow_type, operation_type, is_default, is_active)
VALUES (
    'f0000002-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    'Marmara Adaptive Login',
    'Password + user-selectable 2FA from multiple options',
    'AUTHENTICATION', 'APP_LOGIN', false, true
);

-- Step 1: Password (SEQUENTIAL)
INSERT INTO auth_flow_steps (id, auth_flow_id, auth_method_id, step_order, step_type, is_required)
SELECT gen_random_uuid(), 'f0000002-0000-0000-0000-000000000001', id, 1, 'SEQUENTIAL', true
FROM auth_methods WHERE type = 'PASSWORD';

-- Step 2: CHOICE of multiple 2FA methods
INSERT INTO auth_flow_steps (id, auth_flow_id, auth_method_id, step_order, step_type, is_required)
VALUES ('a0000002-0000-0000-0000-000000000001',
        'f0000002-0000-0000-0000-000000000001',
        (SELECT id FROM auth_methods WHERE type = 'EMAIL_OTP'), -- primary/fallback
        2, 'CHOICE', true);

-- Populate CHOICE alternatives
INSERT INTO auth_flow_step_methods (step_id, auth_method_id, display_order)
SELECT 'a0000002-0000-0000-0000-000000000001', id, 
       CASE type 
         WHEN 'TOTP' THEN 1
         WHEN 'EMAIL_OTP' THEN 2
         WHEN 'FACE' THEN 3
         WHEN 'SMS_OTP' THEN 4
         WHEN 'FINGERPRINT' THEN 5
         WHEN 'HARDWARE_KEY' THEN 6
         WHEN 'VOICE' THEN 7
         WHEN 'QR_CODE' THEN 8
         WHEN 'NFC_DOCUMENT' THEN 9
       END
FROM auth_methods 
WHERE type IN ('TOTP','EMAIL_OTP','FACE','SMS_OTP','FINGERPRINT','HARDWARE_KEY','VOICE','QR_CODE','NFC_DOCUMENT');
```

### 3.2 Data Model

```
AuthFlow
  ├── id, tenant_id, name, operation_type
  ├── is_default, is_active
  └── steps: List<AuthFlowStep> (ordered by step_order)

AuthFlowStep
  ├── id, auth_flow_id
  ├── step_order: 1..5
  ├── step_type: SEQUENTIAL | CHOICE
  ├── auth_method_id (primary method / fallback for CHOICE)
  ├── is_required: boolean
  ├── timeout_seconds: 120
  ├── max_attempts: 3
  ├── fallback_method_id (optional)
  └── alternativeMethods: List<AuthMethod>  ← via auth_flow_step_methods
        ↓ only populated when step_type = CHOICE

AuthMethod
  ├── id, type, name, description
  ├── category: BASIC | STANDARD | PREMIUM | ENTERPRISE
  ├── platforms: [WEB, ANDROID, IOS, DESKTOP]
  ├── requires_enrollment: boolean
  └── is_active: boolean

User
  ├── ...existing fields...
  └── preferred_2fa_method: VARCHAR(30)  ← NEW

UserEnrollment
  ├── user_id, auth_method_type, status (ENROLLED/PENDING/...)
  └── enrollment_data (JSONB)
```

---

## 4. API Design

### 4.1 Login Initiation (Changed)

**POST /api/v1/auth/login**

Request:
```json
{ "email": "user@example.com" }
```

Response (MFA required):
```json
{
  "mfaRequired": true,
  "sessionToken": "mfa_abc123def456",
  "expiresIn": 600,
  "steps": [
    {
      "stepNumber": 1,
      "stepType": "SEQUENTIAL",
      "status": "PENDING",
      "method": {
        "type": "PASSWORD",
        "name": "Password",
        "enrolled": true
      }
    },
    {
      "stepNumber": 2,
      "stepType": "CHOICE",
      "status": "LOCKED",
      "availableMethods": [
        { "type": "TOTP", "name": "Authenticator App", "enrolled": true, "preferred": true },
        { "type": "EMAIL_OTP", "name": "Email OTP", "enrolled": true },
        { "type": "FACE", "name": "Face Recognition", "enrolled": true },
        { "type": "SMS_OTP", "name": "SMS OTP", "enrolled": false }
      ]
    }
  ],
  "currentStep": 1,
  "totalSteps": 2
}
```

Response (single-factor, no MFA):
```json
{
  "mfaRequired": false,
  "accessToken": "eyJ...",
  "refreshToken": "...",
  "expiresIn": 3600,
  "user": { ... }
}
```

### 4.2 Step Verification

**POST /api/v1/auth/step/verify**

Request:
```json
{
  "sessionToken": "mfa_abc123def456",
  "stepNumber": 1,
  "method": "PASSWORD",
  "data": {
    "password": "user_password_here"
  }
}
```

Response (step passed, more steps remaining):
```json
{
  "stepCompleted": true,
  "currentStep": 2,
  "totalSteps": 2,
  "nextStep": {
    "stepNumber": 2,
    "stepType": "CHOICE",
    "status": "PENDING",
    "availableMethods": [
      { "type": "TOTP", "name": "Authenticator App", "enrolled": true, "preferred": true },
      { "type": "EMAIL_OTP", "name": "Email OTP", "enrolled": true }
    ]
  }
}
```

Response (final step passed, auth complete):
```json
{
  "stepCompleted": true,
  "authComplete": true,
  "accessToken": "eyJ...",
  "refreshToken": "...",
  "expiresIn": 3600,
  "user": { ... }
}
```

Response (step failed):
```json
{
  "stepCompleted": false,
  "error": "Invalid verification code",
  "attemptsRemaining": 2
}
```

### 4.3 Backward Compatibility

The existing `POST /auth/login` with `{ email, password }` remains supported:

- If the flow has PASSWORD as step 1, the backend auto-verifies it in the login request
- If step 2+ exists, returns `twoFactorRequired: true` with `availableMethods[]`
- Old clients that only read `twoFactorMethod` (singular) still work — it's set to the preferred/first enrolled method

### 4.4 Admin: Configure Auth Flow

**PUT /api/v1/auth-flows/{flowId}/steps**

```json
{
  "steps": [
    {
      "stepOrder": 1,
      "stepType": "SEQUENTIAL",
      "authMethodType": "PASSWORD"
    },
    {
      "stepOrder": 2,
      "stepType": "CHOICE",
      "methods": ["TOTP", "EMAIL_OTP", "FACE", "SMS_OTP"],
      "fallbackMethod": "EMAIL_OTP",
      "timeoutSeconds": 120,
      "maxAttempts": 3
    },
    {
      "stepOrder": 3,
      "stepType": "SEQUENTIAL",
      "authMethodType": "FACE",
      "timeoutSeconds": 60
    }
  ]
}
```

---

## 5. Frontend: Step-Based Auth UI

### 5.1 Step Progress Indicator

```
┌─────────────────────────────────────────┐
│  ● Step 1    ○ Step 2    ○ Step 3       │  ← progress dots
│  Password    2FA         Face           │
├─────────────────────────────────────────┤
│                                         │
│  [Current step content here]            │
│                                         │
└─────────────────────────────────────────┘
```

### 5.2 Method Picker (for CHOICE steps)

```
┌─────────────────────────────────────────┐
│  Step 2 of 3: Choose Verification       │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ 🔑  Authenticator App        ★   │  │  ← preferred (star)
│  │     Enter 6-digit code from app  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ ✉️  Email OTP                     │  │
│  │     Code sent to a***@gmail.com  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ 👤  Face Recognition              │  │
│  │     Verify with your camera      │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ 📱  SMS OTP              ⚠️      │  │  ← not enrolled
│  │     Not set up — go to Settings  │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### 5.3 Component Architecture

```
LoginPage / WidgetAuthPage
  └─ StepAuthFlow (new orchestrator component)
       ├─ StepProgressBar (dots: ● ○ ○)
       ├─ if currentStep.type === 'CHOICE':
       │    └─ MethodPickerStep (cards for each method)
       │         └─ on select → render appropriate input component
       ├─ if currentStep.type === 'SEQUENTIAL':
       │    └─ render method component directly
       │
       ├─ Method Components (existing, reused):
       │    ├─ PasswordStep
       │    ├─ TotpStep
       │    ├─ EmailOtpStep
       │    ├─ SmsOtpStep
       │    ├─ FaceCaptureStep
       │    ├─ VoiceStep
       │    ├─ FingerprintStep
       │    ├─ HardwareKeyStep
       │    ├─ QrCodeStep
       │    └─ NfcStep
       │
       └─ on all steps complete → receive tokens → redirect/postMessage
```

---

## 6. Widget Responsiveness Fix

### 6.1 Root Causes

| Problem | File | Line(s) |
|---------|------|---------|
| `minHeight: '100vh'` inside 540px iframe | WidgetAuthPage.tsx | 861 |
| Same in 2FA components | TwoFactorVerification.tsx, TwoFactorDispatcher.tsx | 124, 189 |
| Fixed iframe height `540px` | bys-demo/index.html | — |
| `overflow: hidden` clips content | bys-demo CSS | — |
| Inconsistent maxWidth (360–480px) | Multiple components | — |

### 6.2 Fixes

**A) Iframe detection + adaptive layout:**
```tsx
const isInIframe = window !== window.parent

<Box sx={{ 
    bgcolor: 'background.default', 
    minHeight: isInIframe ? 'auto' : '100vh',
    height: isInIframe ? '100%' : 'auto',
    overflowY: 'auto',
}}>
```

**B) Dynamic iframe resizing via postMessage:**
```tsx
useEffect(() => {
    if (isInIframe) {
        const height = document.documentElement.scrollHeight
        window.parent.postMessage({
            type: 'fivucsas:resize',
            payload: { height: Math.min(height, 700) }
        }, '*')
    }
}, [currentStep, selectedMethod, loading, error])
```

**C) Overlay container — allow scroll:**
```css
.fivucsas-overlay-inner {
    overflow-y: auto;   /* was: hidden */
    max-height: min(90vh, 640px);
}
```

**D) Standardize component widths:**
```tsx
const WIDGET_CONTENT_MAX_WIDTH = 400  // single source of truth
```

---

## 7. Admin UI: Flow Builder

### 7.1 Visual Step Builder

The Auth Flows admin page gets a drag-and-drop step builder:

```
┌─ Flow: Marmara Adaptive Login ─────────────────┐
│  Operation: APP_LOGIN  |  ● Active  ● Default   │
├──────────────────────────────────────────────────┤
│                                                  │
│  Step 1                                    [×]   │
│  ┌──────────────────────────────────────┐       │
│  │ Type: ● Sequential  ○ Choice        │       │
│  │ Method: [PASSWORD ▼]                 │       │
│  └──────────────────────────────────────┘       │
│                                                  │
│  Step 2                                    [×]   │
│  ┌──────────────────────────────────────┐       │
│  │ Type: ○ Sequential  ● Choice        │       │
│  │ Methods:                             │       │
│  │   [x] EMAIL_OTP                      │       │
│  │   [x] TOTP                           │       │
│  │   [x] FACE                           │       │
│  │   [ ] SMS_OTP                        │       │
│  │   [x] FINGERPRINT                   │       │
│  │   [x] HARDWARE_KEY                  │       │
│  │   [ ] VOICE                          │       │
│  │ Fallback: [EMAIL_OTP ▼]             │       │
│  └──────────────────────────────────────┘       │
│                                                  │
│  [+ Add Step]                                    │
│                                                  │
│  ────────────────────────────────────────        │
│  Preview: PASSWORD → CHOICE[6 methods] (2FA)     │
│                                                  │
│  [Save Flow]                   [Cancel]          │
└──────────────────────────────────────────────────┘
```

---

## 8. Implementation Plan

### Phase A: Widget Responsiveness (0.5 session)

| # | Task | Files |
|---|------|-------|
| A1 | Add `isInIframe` detection + adaptive min-height | WidgetAuthPage.tsx |
| A2 | Remove `minHeight: '100vh'` from 2FA components | TwoFactorVerification.tsx, TwoFactorDispatcher.tsx |
| A3 | Add postMessage resize on state changes | WidgetAuthPage.tsx |
| A4 | Fix overlay CSS (`overflow-y: auto`) | bys-demo/index.html |
| A5 | Standardize maxWidth to 400px | All widget components |
| A6 | Test in iframe (BYS demo) + standalone | Manual |

### Phase B: Backend Multi-Step MFA (1 session)

| # | Task | Files |
|---|------|-------|
| B1 | Flyway V30 migration | V30__adaptive_mfa.sql |
| B2 | Add `StepType` enum + update `AuthFlowStep` entity | StepType.java, AuthFlowStep.java |
| B3 | Create `AuthStepSession` entity (Redis/DB) | AuthStepSession.java |
| B4 | Create `AvailableTwoFactorMethod` DTO | AvailableTwoFactorMethod.java |
| B5 | Refactor `AuthenticateUserService` — build step chain | AuthenticateUserService.java |
| B6 | New endpoint: `POST /auth/step/verify` | AuthController.java |
| B7 | Update login response (availableMethods, steps) | AuthResponse.java |
| B8 | Backward compat: old login with password still works | AuthController.java |
| B9 | Seed CHOICE flow for Marmara tenant | V30 migration |
| B10 | Add `preferred_2fa_method` endpoint | AuthController.java |

### Phase C: Frontend Multi-Step (1 session)

| # | Task | Files |
|---|------|-------|
| C1 | Create `StepAuthFlow` orchestrator component | StepAuthFlow.tsx |
| C2 | Create `StepProgressBar` component | StepProgressBar.tsx |
| C3 | Create `MethodPickerStep` component | MethodPickerStep.tsx |
| C4 | Update `LoginPage` to use `StepAuthFlow` | LoginPage.tsx |
| C5 | Update `WidgetAuthPage` to use `StepAuthFlow` | WidgetAuthPage.tsx |
| C6 | Admin: Flow Builder with CHOICE step UI | AuthFlowsPage.tsx |
| C7 | Settings: preferred 2FA method selector | SettingsPage.tsx |
| C8 | i18n: method picker strings (EN + TR) | en.json, tr.json |

---

## 9. Security Considerations

1. **Step order enforcement:** Backend rejects step N verification if step N-1 is not COMPLETED
2. **Method validation:** Chosen method must be (a) in the flow step AND (b) enrolled by the user
3. **Session expiry:** MFA sessions expire in 10 minutes; abandoned sessions auto-cleanup
4. **Rate limiting:** Per-method limits (EMAIL_OTP: 5 sends/10min, PASSWORD: 5 attempts/15min)
5. **Audit trail:** Log each step completion with method, IP, user-agent, timestamp
6. **No downgrade:** If a flow requires 3 steps, all 3 must pass; client cannot skip steps
7. **Fallback security:** Fallback methods (e.g., EMAIL_OTP when TOTP fails) count as the same step — not a bypass
8. **Enrollment check:** Methods with `requires_enrollment: true` are only offered if the user has `status: ENROLLED`
9. **Replay prevention:** Each step verification token is single-use; session state tracks completed steps

---

## 10. Migration & Backward Compatibility

### 10.1 Zero-Downtime Migration

1. V30 migration adds columns with defaults — no breaking change
2. Existing flows remain `SEQUENTIAL` at all steps — behavior unchanged
3. Old `POST /auth/login { email, password }` auto-resolves PASSWORD as step 1
4. Old `twoFactorMethod` field remains in response alongside new `availableMethods[]`
5. Clients that don't understand `availableMethods` fall back to single `twoFactorMethod`

### 10.2 Gradual Rollout

1. Deploy backend changes → old flows work identically
2. Create new CHOICE flows → activate for specific tenants
3. Deploy frontend changes → method picker appears
4. Set CHOICE flow as default → users see new UI
5. Remove old single-method flows → cleanup
