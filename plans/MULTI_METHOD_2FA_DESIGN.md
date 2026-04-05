# Multi-Method 2FA & Widget Responsiveness Design

**Author:** FIVUCSAS Engineering  
**Date:** 2026-04-05  
**Status:** Draft  
**Scope:** Backend (identity-core-api), Frontend (web-app), Widget SDK

---

## 1. Problem Statement

### 1.1 Single-Method 2FA Limitation

The current authentication flow is **rigid**: each tenant has one default APP_LOGIN flow with a single 2FA method at step 2. The backend query:

```java
authFlowRepository.findByTenantIdAndIsDefaultTrueAndIsActiveTrueAndOperationType(tenantId, APP_LOGIN)
```

Returns **one** flow, extracts **one** method from `stepOrder == 2`, and returns a single `twoFactorMethod` string to the client.

**Real-world expectation:** Tenant admins enable multiple 2FA methods (e.g., TOTP + EMAIL_OTP + FACE), and users choose from their enrolled methods at login time. This is how Google, GitHub, and Microsoft implement MFA.

### 1.2 Widget Responsiveness Issues

The widget auth page (`WidgetAuthPage.tsx`) renders inside a **540px fixed-height iframe** but uses `minHeight: '100vh'` at multiple nesting levels. This causes:

- Content overflows the iframe container
- `overflow: hidden` on the overlay clips bottom content
- 2FA/biometric steps (face camera, QR code) exceed available height
- Inconsistent `maxWidth` values (360px, 400px, 440px, 480px) across components
- No dynamic iframe resizing based on content

---

## 2. Architecture: Multi-Method 2FA

### 2.1 New Concept: Choice Steps

Introduce a `step_type` column on `auth_flow_steps` to support branching:

| StepType | Behavior |
|----------|----------|
| `SEQUENTIAL` | Single method, must pass (current behavior) |
| `CHOICE` | User picks one from multiple enrolled methods |

A CHOICE step groups multiple auth methods at the same `step_order`. The tenant admin configures which methods are available; the user sees only methods they've enrolled in.

### 2.2 Database Changes

#### Migration V30: Add step_type and choice methods

```sql
-- Add step type to existing steps
ALTER TABLE auth_flow_steps 
  ADD COLUMN step_type VARCHAR(20) NOT NULL DEFAULT 'SEQUENTIAL';

-- Table for CHOICE step alternatives (many-to-many: step -> auth_methods)
CREATE TABLE auth_flow_step_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    step_id UUID NOT NULL REFERENCES auth_flow_steps(id) ON DELETE CASCADE,
    auth_method_id UUID NOT NULL REFERENCES auth_methods(id),
    display_order INTEGER NOT NULL DEFAULT 0,
    UNIQUE(step_id, auth_method_id)
);

CREATE INDEX idx_step_methods_step ON auth_flow_step_methods(step_id);

-- Add preferred 2FA method to users
ALTER TABLE users
  ADD COLUMN preferred_2fa_method VARCHAR(30);
```

**Backward compatible:** All existing steps default to `SEQUENTIAL`, so nothing breaks.

### 2.3 Domain Model Changes

#### AuthFlowStep.java — add stepType + alternative methods

```java
@Enumerated(EnumType.STRING)
@Column(name = "step_type", nullable = false, length = 20)
@Builder.Default
private StepType stepType = StepType.SEQUENTIAL;

@ManyToMany(fetch = FetchType.EAGER)
@JoinTable(
    name = "auth_flow_step_methods",
    joinColumns = @JoinColumn(name = "step_id"),
    inverseJoinColumns = @JoinColumn(name = "auth_method_id")
)
@OrderColumn(name = "display_order")
private List<AuthMethod> alternativeMethods = new ArrayList<>();

/** 
 * Returns all available methods for this step.
 * For SEQUENTIAL: just the primary auth_method.
 * For CHOICE: the alternatives list.
 */
public List<AuthMethod> getAvailableMethods() {
    if (stepType == StepType.CHOICE && !alternativeMethods.isEmpty()) {
        return alternativeMethods;
    }
    return List.of(authMethod);
}
```

#### New DTO: AvailableTwoFactorMethod.java

```java
@Data @Builder
public class AvailableTwoFactorMethod {
    private String methodType;      // "TOTP", "EMAIL_OTP", etc.
    private String name;            // "Authenticator App"
    private String category;        // "STANDARD"
    private boolean enrolled;       // user has active enrollment
    private boolean preferred;      // user's preferred method
    private boolean requiresEnrollment; // needs setup first
}
```

### 2.4 API Response Changes

#### Current login response:

```json
{
  "accessToken": "...",
  "twoFactorRequired": true,
  "twoFactorMethod": "EMAIL_OTP"
}
```

#### New login response:

```json
{
  "accessToken": "...",
  "twoFactorRequired": true,
  "twoFactorMethod": "TOTP",
  "availableMethods": [
    { "methodType": "TOTP", "name": "Authenticator App", "enrolled": true, "preferred": true },
    { "methodType": "EMAIL_OTP", "name": "Email OTP", "enrolled": true, "preferred": false },
    { "methodType": "FACE", "name": "Face Recognition", "enrolled": true, "preferred": false },
    { "methodType": "SMS_OTP", "name": "SMS OTP", "enrolled": false, "preferred": false }
  ]
}
```

- `twoFactorMethod` is kept for backward compatibility (set to preferred or first enrolled)
- `availableMethods` is the new field — clients that support it show a method picker
- `enrolled: false` methods are shown greyed out ("Set up in Settings")

### 2.5 Service Logic: AuthenticateUserService

```java
// Current: extract single method from step 2
// New: extract all available methods, filter by user enrollments

AuthFlowStep step2 = flow.getSteps().stream()
    .filter(s -> s.getStepOrder() == 2)
    .findFirst().orElse(null);

if (step2 == null) {
    twoFactorRequired = false;
} else {
    List<AuthMethod> methods = step2.getAvailableMethods();
    
    // Get user's active enrollments
    List<UserEnrollment> enrollments = userEnrollmentRepository
        .findAllByUserId(user.getId());
    Set<String> enrolledTypes = enrollments.stream()
        .filter(UserEnrollment::isEnrolled)
        .map(e -> e.getAuthMethodType().name())
        .collect(Collectors.toSet());
    
    // Build available methods list
    List<AvailableTwoFactorMethod> available = methods.stream()
        .map(m -> AvailableTwoFactorMethod.builder()
            .methodType(m.getType().name())
            .name(m.getName())
            .category(m.getCategory().name())
            .enrolled(enrolledTypes.contains(m.getType().name()))
            .preferred(m.getType().name().equals(user.getPreferred2faMethod()))
            .requiresEnrollment(m.isRequiresEnrollment())
            .build())
        .collect(Collectors.toList());
    
    // Primary method = user's preferred (if enrolled) or first enrolled
    String primaryMethod = available.stream()
        .filter(AvailableTwoFactorMethod::isPreferred)
        .filter(AvailableTwoFactorMethod::isEnrolled)
        .map(AvailableTwoFactorMethod::getMethodType)
        .findFirst()
        .orElseGet(() -> available.stream()
            .filter(AvailableTwoFactorMethod::isEnrolled)
            .map(AvailableTwoFactorMethod::getMethodType)
            .findFirst().orElse("EMAIL_OTP"));
    
    twoFactorRequired = true;
    twoFactorMethod = primaryMethod;
    // Store available in response
}
```

### 2.6 Admin UI: Auth Flow Configuration

The Auth Flows admin page needs a new UI for CHOICE steps:

```
Flow: "Marmara Multi-Factor Login"
  Step 1: PASSWORD (Sequential)
  Step 2: [CHOICE] ← New toggle
    [x] EMAIL_OTP
    [x] TOTP
    [x] FACE
    [ ] SMS_OTP (disabled - Twilio not configured)
    [ ] VOICE
    [ ] FINGERPRINT
    [x] HARDWARE_KEY
    [ ] NFC_DOCUMENT
    [ ] QR_CODE
```

### 2.7 Frontend: Method Picker

When `availableMethods.length > 1`, show a method selection screen:

```
┌─────────────────────────────────┐
│  Choose Verification Method     │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 🔑 Authenticator App    │   │ ← preferred (highlighted)
│  │   Enter 6-digit code    │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │ ✉️  Email OTP            │   │
│  │   Code sent to a***@... │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 👤 Face Recognition     │   │
│  │   Use your camera       │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 📱 SMS OTP              │   │ ← greyed out
│  │   Not enrolled           │   │
│  └─────────────────────────┘   │
│                                 │
│  [Skip to preferred method →]   │
└─────────────────────────────────┘
```

---

## 3. Widget Responsiveness Fix

### 3.1 Root Causes

| Problem | Location | Fix |
|---------|----------|-----|
| `minHeight: '100vh'` in iframe context | WidgetAuthPage.tsx:861, TwoFactorVerification.tsx:124, TwoFactorDispatcher.tsx:189 | Replace with `minHeight: 'auto'` or `height: '100%'` |
| Fixed iframe height `540px` | bys-demo/index.html | Use dynamic height via postMessage resize |
| `overflow: hidden` clips content | bys-demo `.fivucsas-overlay-inner` | Change to `overflow-y: auto` |
| Inconsistent maxWidth (360/400/440/480px) | Multiple components | Standardize to `maxWidth: 400px` |
| No responsive container in iframe | WidgetAuthPage.tsx | Add `overflow-y: auto` + `maxHeight: 100%` |

### 3.2 Widget Page Changes

**WidgetAuthPage.tsx root wrapper:**

```tsx
// BEFORE (broken in iframe)
<Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>

// AFTER (works in both standalone and iframe)
<Box sx={{ 
    bgcolor: 'background.default', 
    minHeight: isInIframe ? 'auto' : '100vh',
    height: isInIframe ? '100%' : 'auto',
    overflowY: 'auto',
}}>
```

Add iframe detection:
```tsx
const isInIframe = window !== window.parent
```

**All 2FA sub-components** — remove `minHeight: '100vh'`, use `flex: 1`:

```tsx
// TwoFactorVerification.tsx, TwoFactorDispatcher.tsx
<Box sx={{ 
    display: 'flex', 
    flexDirection: 'column',
    alignItems: 'center',
    flex: 1,
    p: { xs: 2, sm: 3 },
}}>
```

### 3.3 Dynamic Iframe Sizing

The BYS demo already listens for `fivucsas:resize` messages. The widget should send content height after each render:

```tsx
// In WidgetAuthPage.tsx, after each state change
useEffect(() => {
    if (isInIframe) {
        const height = document.documentElement.scrollHeight
        window.parent.postMessage({
            type: 'fivucsas:resize',
            payload: { height: Math.min(height, 700) }
        }, '*')
    }
}, [step, twoFactorMethod, loading, error])
```

### 3.4 Overlay Container Fix

**bys-demo/index.html:**

```css
.fivucsas-overlay-inner {
    /* ... existing ... */
    overflow-y: auto;              /* was: hidden — allows scrolling */
    max-height: min(90vh, 640px);  /* cap height */
}

.fivucsas-iframe {
    height: 520px;                 /* default, resized by postMessage */
    max-height: 85vh;
    transition: height 0.2s ease;
}
```

### 3.5 Consistent Component Sizing

Standardize all widget-mode components to:

```tsx
const WIDGET_MAX_WIDTH = 400  // single constant

// Use everywhere:
<Box sx={{ width: '100%', maxWidth: WIDGET_MAX_WIDTH }}>
```

---

## 4. Implementation Plan

### Phase A: Widget Responsiveness (1 session)

| Step | Task | Files |
|------|------|-------|
| A1 | Add `isInIframe` detection | WidgetAuthPage.tsx |
| A2 | Replace `minHeight: '100vh'` with flex layout | WidgetAuthPage.tsx, TwoFactorVerification.tsx, TwoFactorDispatcher.tsx |
| A3 | Add postMessage resize on state changes | WidgetAuthPage.tsx |
| A4 | Fix overlay CSS (overflow-y: auto) | bys-demo/index.html |
| A5 | Standardize maxWidth to 400px | All widget components |
| A6 | Test in iframe + standalone | Manual |

### Phase B: Multi-Method 2FA Backend (1 session)

| Step | Task | Files |
|------|------|-------|
| B1 | Flyway V30 migration (step_type, step_methods table, preferred_2fa) | V30__multi_method_2fa.sql |
| B2 | Update AuthFlowStep entity (stepType, alternativeMethods) | AuthFlowStep.java |
| B3 | Create AvailableTwoFactorMethod DTO | AvailableTwoFactorMethod.java |
| B4 | Update AuthenticateUserService (multi-method logic) | AuthenticateUserService.java |
| B5 | Update AuthResponse DTO (availableMethods field) | AuthResponse.java |
| B6 | Seed CHOICE flow for Marmara tenant | V30 migration data |
| B7 | Add /users/me/preferred-2fa-method endpoint | AuthController.java |

### Phase C: Multi-Method 2FA Frontend (1 session)

| Step | Task | Files |
|------|------|-------|
| C1 | Create MethodPickerStep component | features/auth/components/steps/MethodPickerStep.tsx |
| C2 | Update LoginPage 2FA flow | LoginPage.tsx |
| C3 | Update WidgetAuthPage 2FA flow | WidgetAuthPage.tsx |
| C4 | Update Auth Flows admin page (CHOICE step UI) | AuthFlowsPage.tsx |
| C5 | Add preferred method to Settings | SettingsPage.tsx |
| C6 | i18n for method picker (EN + TR) | en.json, tr.json |

---

## 5. Data Model Summary

```
Tenant
  └─ AuthFlow (name, operation_type, is_default, is_active)
       └─ AuthFlowStep (step_order, step_type: SEQUENTIAL|CHOICE)
            ├─ authMethod (primary, for SEQUENTIAL)
            └─ alternativeMethods[] (for CHOICE)
                 └─ AuthMethod (type, name, category, platforms)

User
  ├─ preferred_2fa_method (nullable)
  └─ UserEnrollment[] (auth_method_type, status: ENROLLED|PENDING|...)

Login Flow:
  1. Password check passes
  2. Find default APP_LOGIN flow for tenant
  3. Get step 2 → if CHOICE, get all alternativeMethods
  4. Cross-reference with user's ENROLLED enrollments
  5. Return availableMethods[] (enrolled ones active, others greyed)
  6. User picks method → verify → complete auth
```

---

## 6. Security Considerations

1. **Method validation:** Backend MUST verify the chosen method is both (a) in the flow's step and (b) enrolled by the user. Never trust client-side method selection alone.
2. **Rate limiting:** Apply per-method rate limits (e.g., EMAIL_OTP max 5 sends/10min).
3. **Audit trail:** Log which method was used for each 2FA completion.
4. **Enrollment requirement:** CHOICE methods with `requiresEnrollment=true` should not be offered if the user hasn't enrolled.
5. **Fallback:** If user has zero enrolled methods from the CHOICE list, fall back to `fallback_method_id` (typically EMAIL_OTP).
