# Tenant Admin UX Design

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document describes the web dashboard UX for tenant admins to configure authentication methods, build authentication flows, manage user enrollments, and monitor authentication activity.

**Target Users**: Tenant administrators accessing the web dashboard at `app.fivucsas.com`

---

## 2. Navigation Updates

### 2.1 New Sidebar Items

The existing sidebar (Sidebar.tsx) needs these additions:

```
Dashboard
Users
Tenants
Roles
Enrollments         ← ENHANCED (enrollment management per user)
──────────────────
Auth Methods        ← NEW (enable/configure methods for tenant)
Auth Flows          ← NEW (build authentication flows)
Devices             ← NEW (registered device management)
──────────────────
Audit Logs
Settings
```

### 2.2 New Routes

| Route | Page | Description |
|---|---|---|
| `/auth-methods` | AuthMethodsPage | Enable/configure methods for tenant |
| `/auth-flows` | AuthFlowsListPage | List all configured flows |
| `/auth-flows/create` | AuthFlowCreatePage | Create new flow with builder |
| `/auth-flows/:id/edit` | AuthFlowEditPage | Edit existing flow |
| `/devices` | DevicesPage | View registered devices |
| `/enrollments/wizard` | EnrollmentWizardPage | Self-service enrollment |
| `/users/:id/enrollments` | UserEnrollmentsPage | Admin view of user enrollments |

---

## 3. Auth Methods Page

### 3.1 Purpose
Tenant admins enable or disable auth methods for their tenant and configure method-specific settings.

### 3.2 Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Authentication Methods                                      │
│  Configure which authentication methods are available         │
│  for your tenant.                                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌── BASIC ──────────────────────────────────────────────┐  │
│  │                                                        │  │
│  │  [✓] Password          Free        [Configure]        │  │
│  │      Traditional password login                        │  │
│  │      Platforms: Web, Mobile, Desktop                   │  │
│  │                                                        │  │
│  │  [✓] Email OTP         Free        [Configure]        │  │
│  │      One-time code sent via email                      │  │
│  │      Platforms: Web, Mobile, Desktop                   │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌── STANDARD ───────────────────────────────────────────┐  │
│  │                                                        │  │
│  │  [ ] SMS OTP           $50/mo      [Configure]        │  │
│  │  [✓] Authenticator App $50/mo      [Configure]        │  │
│  │  [✓] QR Code           $75/mo      [Configure]        │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌── PREMIUM ────────────────────────────────────────────┐  │
│  │                                                        │  │
│  │  [✓] Face Recognition  $200/mo     [Configure]        │  │
│  │  [ ] Fingerprint       $150/mo     [Configure]        │  │
│  │  [ ] Voice Recognition $250/mo     [Coming Soon]      │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌── ENTERPRISE ─────────────────────────────────────────┐  │
│  │                                                        │  │
│  │  [ ] NFC Document      $500/mo     [Configure]        │  │
│  │  [ ] Hardware Key      $100/mo     [Configure]        │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Monthly Total: $325/mo                    [Save Changes]   │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 Configuration Dialog (per method)

Clicking "Configure" opens a dialog with method-specific settings:

**Face Recognition Config:**
```
┌── Face Recognition Settings ─────────────────────┐
│                                                    │
│  Liveness Detection Level:                         │
│  ○ Passive (texture analysis only)                 │
│  ● Active (blink/smile challenges)                 │
│  ○ Both (passive + active)                         │
│                                                    │
│  Quality Threshold:     [70] / 100                │
│  Confidence Threshold:  [0.6] / 1.0              │
│  Max Enrollment Images: [3]                        │
│                                                    │
│              [Cancel]  [Save]                      │
└────────────────────────────────────────────────────┘
```

**TOTP Config:**
```
┌── Authenticator App Settings ────────────────────┐
│                                                    │
│  Issuer Name: [My Company]                        │
│  Code Digits: ○ 6  ○ 8                           │
│  Time Period: [30] seconds                        │
│  Generate Backup Codes: [✓]                       │
│                                                    │
│              [Cancel]  [Save]                      │
└────────────────────────────────────────────────────┘
```

---

## 4. Auth Flow Builder Page (Enhanced)

### 4.1 Current State
The existing `AuthFlowBuilder.tsx` (632 lines) already has:
- Drag-and-drop step reordering (Framer Motion Reorder)
- Method picker grid (9 active methods)
- Required/Optional toggle per step
- Cost summary panel
- Flow preview panel
- Flow name and description fields
- "Set as default" toggle

### 4.2 Enhancements Needed

#### A. Operation Type Selector
Add a prominent dropdown at the top:

```
┌── Operation Type ────────────────────────────────┐
│                                                    │
│  What is this flow for?                           │
│                                                    │
│  [▼ Application Login                            ]│
│     ├─ Application Login                          │
│     ├─ Door Access                                │
│     ├─ Building Access                            │
│     ├─ Transaction Approval                       │
│     ├─ Guest Access                               │
│     ├─ Exam Proctoring                            │
│     └─ Custom                                     │
│                                                    │
└────────────────────────────────────────────────────┘
```

#### B. Step Settings Dialog
The existing Settings icon (gear) on each step should open a dialog:

```
┌── Step Settings: Face Recognition ───────────────┐
│                                                    │
│  Required:        [✓]                             │
│  Timeout:         [60] seconds                    │
│  Max Attempts:    [3]                             │
│  Allow Delegation:[✓] (cross-device)              │
│                                                    │
│  Fallback Method:                                 │
│  [▼ QR Code                                     ]│
│     ├─ None                                       │
│     ├─ Password                                   │
│     ├─ QR Code                                    │
│     ├─ Email OTP                                  │
│     └─ Authenticator App                          │
│                                                    │
│  Method-Specific:                                 │
│  Liveness Challenge: [▼ Blink]                   │
│  Min Confidence:     [0.8]                        │
│                                                    │
│              [Cancel]  [Apply]                    │
└────────────────────────────────────────────────────┘
```

#### C. Platform Compatibility Warnings
When a method is added, show warnings if it's not available on all platforms:

```
⚠ Fingerprint is not available on Web. Users on web will need to
  delegate this step to their phone.

⚠ NFC Document is only available on Android and iOS. Desktop and
  web users will need to delegate to their phone.
```

#### D. Enrollment Status Indicator
Show how many users are enrolled for each method in the flow:

```
Step 2: Face Recognition  ✓ 45/60 users enrolled (75%)
                          ⚠ 15 users need face enrollment
```

#### E. API Integration
Replace the `console.log('Saving flow with steps:', steps)` stub with actual API calls:
- `POST /api/v1/tenants/{tenantId}/auth-flows` (create)
- `PUT /api/v1/tenants/{tenantId}/auth-flows/{id}` (update)
- `GET /api/v1/tenants/{tenantId}/auth-flows/{id}` (load for edit)

#### F. Test Flow Button
The "Test Flow" button simulates the auth flow in-browser:
1. Opens a dialog simulating each step
2. Admin walks through the flow as if authenticating
3. Shows timing, success/failure scenarios
4. Validates the flow is completable

---

## 5. Auth Flows List Page

### 5.1 Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Authentication Flows                       [+ Create Flow]  │
│  Manage authentication sequences for different operations    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Filter: [All Operations ▼]  [Active ▼]  [Search...]       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ⭐ Standard Login                        APP_LOGIN     │  │
│  │    Password → Face Recognition                         │  │
│  │    2 steps | Default | Active            [Edit] [···]  │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │    Office Door Access                    DOOR_ACCESS    │  │
│  │    Face → NFC Document (fallback: QR)                  │  │
│  │    2 steps | Default | Active            [Edit] [···]  │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │    High Security Transaction             TRANSACTION    │  │
│  │    Password → Face → Hardware Key                      │  │
│  │    3 steps | Active                      [Edit] [···]  │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │    Guest Check-In                        GUEST_ACCESS   │  │
│  │    QR Code                                             │  │
│  │    1 step | Default | Active             [Edit] [···]  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Showing 4 flows                                            │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Flow Card Actions (···)
- Edit flow
- Duplicate flow
- Set as default (for operation type)
- Activate/Deactivate
- Delete flow
- View usage statistics

---

## 6. User Enrollments Management

### 6.1 Admin View: User Detail → Enrollments Tab

When viewing a user's details, a new "Enrollments" tab shows:

```
┌─────────────────────────────────────────────────────────────┐
│  User: John Doe (john@example.com)                          │
│  [Profile] [Roles] [Enrollments] [Activity] [Settings]      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Authentication Method Enrollments                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 🔒 Password              ENROLLED ✓                 │    │
│  │    Enrolled: Jan 15, 2026                           │    │
│  │                               [Reset Password]      │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 😀 Face Recognition       ENROLLED ✓                │    │
│  │    Quality: 85/100 | Liveness: 92%                  │    │
│  │    Enrolled: Feb 1, 2026   [Re-enroll] [Revoke]     │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 📱 Authenticator App      ENROLLED ✓                │    │
│  │    Enrolled: Feb 5, 2026                            │    │
│  │    Backup codes: 8/10 remaining [Revoke]            │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 🔑 Fingerprint            NOT ENROLLED              │    │
│  │    Required by: Office Door Access flow             │    │
│  │                               [Send Reminder]       │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 🎤 Voice                  NOT ENROLLED              │    │
│  │    Not required by any active flow                  │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 📄 NFC Document           NOT ENROLLED              │    │
│  │    Not required by any active flow                  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  Required Enrollments Missing: 1                            │
│  [Send Enrollment Reminder Email]                           │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Bulk Enrollment Overview

A dashboard widget showing enrollment coverage:

```
┌── Enrollment Coverage ───────────────────────────┐
│                                                    │
│  Password:        ████████████████████ 60/60 100% │
│  Face:            ███████████████░░░░░ 45/60  75% │
│  TOTP:            ██████████░░░░░░░░░░ 30/60  50% │
│  Fingerprint:     ████░░░░░░░░░░░░░░░░ 12/60  20% │
│  QR Code:         ██░░░░░░░░░░░░░░░░░░  6/60  10% │
│                                                    │
│  Users needing enrollment:                         │
│  Face: 15 users | Fingerprint: 48 users           │
│                                                    │
│  [Send Bulk Enrollment Reminders]                 │
└────────────────────────────────────────────────────┘
```

---

## 7. Device Management Page

### 7.1 Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Registered Devices                                          │
│  Manage devices registered by your tenant's users            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Filter: [All Platforms ▼]  [All Users ▼]  [Search...]      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 📱 Samsung Galaxy S24                    android       │  │
│  │    User: John Doe                                      │  │
│  │    Capabilities: Camera, NFC, Fingerprint, Mic, BLE   │  │
│  │    Trusted: ✓  |  Last used: 2 hours ago              │  │
│  │                                          [···]         │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ 💻 Chrome on Windows                    web            │  │
│  │    User: John Doe                                      │  │
│  │    Capabilities: Camera, Mic                           │  │
│  │    Trusted: ✗  |  Last used: 1 day ago                │  │
│  │                                          [···]         │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ 🖥 Desktop App - MacBook Pro            desktop        │  │
│  │    User: Jane Smith                                    │  │
│  │    Capabilities: Camera, Mic, USB                     │  │
│  │    Trusted: ✓  |  Last used: 3 hours ago              │  │
│  │                                          [···]         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  Total: 24 devices | 15 trusted | 9 untrusted              │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Device Actions (···)
- Trust/Untrust device
- Rename device
- View auth history for device
- Remove device (forces re-registration)

---

## 8. Self-Service Enrollment Wizard (Member View)

### 8.1 Access
Members access via their profile settings or a dedicated enrollment page.

### 8.2 Flow

```
Step 1: Method Selection Grid
┌─────────────────────────────────────────────────────────────┐
│  Set Up Your Authentication Methods                          │
│                                                              │
│  Your tenant requires these methods for login:              │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │    🔒         │  │    😀         │  │    📱         │     │
│  │  Password    │  │    Face      │  │    TOTP      │     │
│  │  ✓ Set up    │  │  ⚠ Required  │  │  ○ Optional  │     │
│  │              │  │  [Set Up →]  │  │  [Set Up →]  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  Additional methods available:                              │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │    🔑         │  │    📄         │                        │
│  │  Fingerprint │  │  QR Code     │                        │
│  │  ○ Optional  │  │  ○ Optional  │                        │
│  │  [Set Up →]  │  │  [Set Up →]  │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘

Step 2: Method-specific enrollment (see 03-ENROLLMENT_FLOWS.md)

Step 3: Confirmation
┌─────────────────────────────────────────────────────────────┐
│  ✓ Face Recognition Enrolled Successfully!                   │
│                                                              │
│  Quality Score: 85/100                                      │
│  Liveness Score: 92%                                        │
│  Enrolled: February 17, 2026 at 10:30 AM                   │
│                                                              │
│  [Continue to next method]  [Back to methods]               │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Dashboard Enhancements

### 9.1 New Dashboard Widgets

Add to the existing dashboard:

**Auth Method Distribution:**
```
┌── Authentication Methods ─────────────────────┐
│                                                │
│  Most used: Password + Face (42%)             │
│  Password only: 35%                           │
│  Face only: 15%                               │
│  Other combinations: 8%                       │
│                                                │
│  ██████████████████████░░░░░░░░░░ 42% P+F     │
│  █████████████████░░░░░░░░░░░░░░░ 35% P       │
│  ███████░░░░░░░░░░░░░░░░░░░░░░░░ 15% F       │
│  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░  8% Other   │
└────────────────────────────────────────────────┘
```

**Enrollment Coverage:**
```
┌── Enrollment Status ──────────────────────────┐
│                                                │
│  Fully Enrolled:     45/60 (75%)              │
│  Partially Enrolled: 10/60 (17%)              │
│  Not Enrolled:        5/60 (8%)               │
│                                                │
│  Most needed: Face (15 users need enrollment) │
└────────────────────────────────────────────────┘
```

**Recent Auth Activity:**
```
┌── Auth Activity (24h) ────────────────────────┐
│                                                │
│  Successful logins: 342                       │
│  Failed attempts:    23                       │
│  Delegations used:    8                       │
│  Accounts locked:     2                       │
│                                                │
│  Auth Level Distribution:                     │
│  L1: 15%  L2: 40%  L3: 35%  L4: 8%  L5: 2%  │
└────────────────────────────────────────────────┘
```

---

## 10. Responsive Design Notes

All new pages must support:
- Desktop (1200px+): Full sidebar + content
- Tablet (768-1199px): Collapsible sidebar + content
- Mobile (320-767px): Bottom nav + full-width content

The Auth Flow Builder should degrade gracefully on mobile:
- Drag-and-drop becomes tap-to-reorder with up/down arrows
- Method picker becomes a vertical list instead of grid
- Preview panel moves below the builder
