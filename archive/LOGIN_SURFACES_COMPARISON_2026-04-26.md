# FIVUCSAS Login Surfaces — Comparison & Convergence Analysis

> 2026-04-26 audit of the three production login UIs and what they share / where they diverge. Generated from live HTML probing + source-tree review.

## TL;DR

We have **three** sign-in surfaces, only **two** share the modern login engine:

| Surface | URL | Source | Login engine | OIDC-aware? | Multi-tenant branded? |
|---|---|---|---|---|---|
| **Admin Dashboard** | `app.fivucsas.com/login` | `src/features/auth/components/LoginPage.tsx` | `TwoFactorDispatcher` (legacy) | ❌ | ❌ (admin SPA = single-tenant context) |
| **Hosted Login** | `verify.fivucsas.com/login` | `src/verify-app/HostedLoginApp.tsx` | **`LoginMfaFlow`** (modern) | ✅ | ✅ (tenant branding from `oauth2_clients.tenant_name`) |
| **Embeddable Widget** | `verify.fivucsas.com/?session_id=…` (iframe) | `src/verify-app/VerifyApp.tsx` | **`LoginMfaFlow`** OR `MultiStepAuthFlow` | partial | ✅ |

The two `verify.fivucsas.com` surfaces share the same React bundle (built via `vite.verify.config.ts` → `dist-verify/`, deployed to Hostinger at `verify.fivucsas.com`). The admin surface is a separate bundle (the main SPA at `dist/`).

## Build pipelines

```
src/main.tsx  (full SPA)          →  vite.config.ts          →  dist/             →  app.fivucsas.com/
src/verify-app/main.tsx           →  vite.verify.config.ts   →  dist-verify/      →  verify.fivucsas.com/
src/verify-app/sdk/index.ts       →  vite.sdk.config.ts      →  dist-sdk/         →  npm @fivucsas/auth-js
src/verify-app/elements/index.ts  →  vite.config.elements.ts →  dist-elements/    →  Web Components bundle
src/verify-app/adapter/index.ts   →  vite.adapter.config.ts  →  dist-adapter/     →  hosted iframe adapter
```

## Surface-by-surface walkthrough

### 1) `app.fivucsas.com/login` — admin sign-in (LoginPage.tsx)

**Audience**: SUPER_ADMIN, TENANT_ADMIN, internal staff. Single-tenant session context (the admin's home tenant).

**Visual**: Bespoke glassmorphism + framer-motion animations. Floating gradient orbs, staggered entrance, backdrop-blur cards. ~870 LOC component.

**Auth flow**:
- email + password TextField (zod-validated)
- POST `/api/v1/auth/login`
- If 200 with `mfaSessionToken` → `<TwoFactorDispatcher>` renders the next step (legacy MFA path)
- Optional Face login via `<FaceVerificationFlow>` dialog (separate, hardcoded entry button)
- Forgot password / reset password dialogs inline

**Limitations / divergence**:
- Hardcoded password-first — does NOT call `/auth-flows?operationType=APP_LOGIN` to discover the active flow per tenant. Tenants who configured EMAIL_OTP or FACE as primary still get the password form.
- No OIDC parameters consumed — won't redirect to a `redirect_uri`. This is fine because the admin SPA *is* the destination; no external redirect needed.
- `TwoFactorDispatcher` is the older MFA component; the newer `LoginMfaFlow` is not used. Step components (PasswordStep, TotpStep, FaceCaptureStep, etc.) are still shared.

### 2) `verify.fivucsas.com/login` — hosted OAuth / OIDC sign-in (HostedLoginApp.tsx)

**Audience**: end-users of integrated tenants. Reads OAuth params from URL (`client_id`, `redirect_uri`, `state`, `code_challenge`, `code_challenge_method`, `scope`, `nonce`, `ui_locales`).

**Visual**: MUI Paper card centered on a soft gradient. Uses the same `createAppTheme()` factory as the admin SPA but renders **tenant branding** (logo + name) fetched from `/api/v1/oauth2/clients/{clientId}/public-meta` before showing the form.

**Auth flow**:
- Pre-screen: validate URL params. Show "tenant not found" if metadata fetch fails.
- email + password (or whatever the tenant's `auth-flow` discovery returns; `LoginMfaFlow` does the discovery internally on first paint)
- POST `/api/v1/auth/login` → if MFA required, `LoginMfaFlow` chains the steps (TotpStep, SmsOtpStep, FaceCaptureStep, …)
- On completion: POST `/api/v1/oauth2/authorize/complete` → mints authorization code → redirects to the tenant's `redirect_uri` with `?code=…&state=…`
- Single-step optimization: if the flow has only PASSWORD (e.g., Marmara Simple Login), skip MFA chaining and go straight to OAuth code mint.

**Strengths**:
- OIDC-correct (PKCE, exact-match `redirect_uri`, BCP47 `ui_locales`)
- Tenant-branded
- Adaptive MFA via flow discovery
- ~545 LOC component but most of the UI logic lives in the shared `LoginMfaFlow` (~410 LOC) and shared step components

### 3) `verify.fivucsas.com/?session_id=…` — embeddable widget (VerifyApp.tsx)

**Audience**: tenants who want to embed FIVUCSAS auth in their own page (Stripe-Elements style).

**Visual**: Same `dist-verify` bundle as #2 — branding/styling identical, but renders inside an iframe so the parent page controls outer chrome (modal, drawer, full-page).

**Two modes**:
- **session mode** (`session_id` param): wraps `MultiStepAuthFlow` against a pre-created backend auth session. Used when the tenant has already POSTed `/api/v1/auth/sessions` server-to-server and just needs the user to complete it.
- **login mode** (`client_id` only, no `session_id`): same `LoginMfaFlow` as #2 but without the OAuth code-mint redirect. Posts the result back to the parent page via `postMessage` (sendComplete / sendCancel / sendError).

**postMessage protocol** (from `postMessageBridge.ts`): `ready`, `step-change`, `complete`, `cancel`, `error`, `resize` events. Parent origin validation enforced (`setParentOrigin`).

## What's shared (good)

- `createAppTheme(theme)` — light/dark MUI theme factory
- All step components (PasswordStep, TotpStep, SmsOtpStep, EmailOtpMfaStep, FaceCaptureStep, VoiceStep, FingerprintStep, QrCodeStep, HardwareKeyStep, NfcStep, GestureLivenessStep, MethodPickerStep)
- i18n keys (`liveness.gesture.*`, `auth.*`, `mfa.*`, etc.) — both en.json + tr.json fully populated
- WebAuthn utils, formatApiError, AuthRepository, BiometricService, IHttpClient
- StepProgress component (for hosted + widget; LoginPage uses inline progress bar instead)

## What's divergent (gap)

| Concern | LoginPage (app) | HostedLoginApp (verify hosted) | VerifyApp (verify widget) |
|---|---|---|---|
| Flow discovery (`/auth-flows?operationType`) | ❌ never calls | ✅ via `LoginMfaFlow.loadActiveFlow()` | ✅ |
| MFA chaining engine | `TwoFactorDispatcher` (legacy) | `LoginMfaFlow` (modern) | `LoginMfaFlow` or `MultiStepAuthFlow` |
| Tenant branding | n/a (single tenant) | `client_meta` fetch + Paper card header | same as hosted |
| OAuth/OIDC params | n/a | full PKCE + state + ui_locales | partial (client_id only) |
| Redirect / completion | navigate('/dashboard') | 302 to `redirect_uri` with `?code=...&state=...` | postMessage to parent |
| Forgot/reset password dialog | inline | n/a (admin-only feature) | n/a |
| Face login button on initial card | yes (opens FaceVerificationFlow dialog) | no (face is offered via flow steps if enabled) | no |
| Animations | framer-motion glassmorphism | minimal MUI transitions | minimal MUI transitions |

## Recommendations

### R1 — Adopt `LoginMfaFlow` in `LoginPage.tsx` (P2, ~1-2 days)

The biggest divergence is the MFA chaining engine. `TwoFactorDispatcher` is older and lacks the flow-discovery + adaptive-MFA path. Migrate `LoginPage.tsx` to call `LoginMfaFlow` after successful password to standardize behaviour.

**Trade-off**: `LoginPage`'s glassmorphism/framer-motion intro is a brand asset; only the *post-login* MFA section needs to adopt the unified engine. Wrap `<LoginMfaFlow>` inside the existing CardContent.

**Benefit**: TENANT_ADMIN / SUPER_ADMIN tenants who want non-password primary methods (e.g., FACE-first for biometric labs) will work out of the box.

### R2 — Document the `app.fivucsas.com` admin login is intentionally OIDC-free (P3, ~30 min)

If R1 is rejected (because admin login is supposed to be vanilla), add a top-of-file doc-comment in `LoginPage.tsx` explaining "admin SPA is single-tenant, OIDC redirects deliberately disabled". This prevents future confusion.

### R3 — Visual convergence pass (P3, ~half day)

Bring the verify hosted/widget surface up to the admin's polish level (or vice-versa). Currently:
- Admin: glassmorphism, gradient orbs, staggered animations
- Hosted/widget: minimal MUI Paper card

The asymmetry is intentional (widget needs to be "embeddable" → restrained styling), but the **hosted** surface (own page, full viewport) could afford to look closer to the admin polish for parity. Decide: should `verify.fivucsas.com/login` look like a flagship-grade page, or is the spartan look the desired vendor-platform aesthetic?

### R4 — Consolidate forgot-password into the hosted surface (P3, ~half day)

Currently only the admin has forgot/reset password dialogs. End-users at `verify.fivucsas.com/login` have no UI to recover passwords. If a tenant offers password-based login, this is a real gap.

### R5 — Add a `/login` route under verify.fivucsas (currently 200 by SPA fallback) explicitly (already true; verify-app's index.html catches all paths)

No code change — just ensure SEO `noindex` is set (it is) and that the `verify.fivucsas.com/login?…` URL pattern is documented as the canonical OIDC entry in tenant integration guides.

## Verification commands

```bash
# Live probe
curl -sS -o /dev/null -w "%{http_code}\n" https://app.fivucsas.com/login           # 200
curl -sS -o /dev/null -w "%{http_code}\n" https://verify.fivucsas.com/login        # 200
curl -sS -o /dev/null -w "%{http_code}\n" https://verify.fivucsas.com/             # 200 (widget root)

# Title tags (different per surface)
curl -sS https://app.fivucsas.com/    | grep -oE '<title>[^<]+</title>'
# → <title>FIVUCSAS — Sign in · Biometric Identity Verification Platform</title>
curl -sS https://verify.fivucsas.com/ | grep -oE '<title>[^<]+</title>'
# → <title>FIVUCSAS Verify</title>

# Auth API contract (same for all 3)
curl -sS -X POST https://api.fivucsas.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"x@y.z","password":"WrongPassword"}'
# → 401 INVALID_CREDENTIALS — same for all surfaces
```

## Source files quick map

```
src/features/auth/components/LoginPage.tsx           — admin login (Card + framer-motion + TwoFactorDispatcher)
src/features/auth/components/TwoFactorDispatcher.tsx — legacy MFA engine (admin only)
src/features/auth/components/MultiStepAuthFlow.tsx   — session-mode MFA engine (widget)
src/verify-app/HostedLoginApp.tsx                    — hosted OAuth login
src/verify-app/VerifyApp.tsx                         — embeddable iframe widget
src/verify-app/LoginMfaFlow.tsx                      — modern login engine (hosted + widget login mode)
src/verify-app/postMessageBridge.ts                  — widget ↔ parent protocol
src/verify-app/sdk/                                  — npm @fivucsas/auth-js
src/verify-app/elements/                             — Web Components (deferred)
src/verify-app/adapter/                              — hosted iframe wrapper
```

## Backend contracts touched

- `POST /api/v1/auth/login` — used by all 3
- `POST /api/v1/auth/mfa/step` — used by all 3 (during MFA chaining)
- `GET /api/v1/auth-flows?operationType=APP_LOGIN&tenantId=…` — used by hosted + widget login mode (NOT admin)
- `GET /api/v1/oauth2/clients/{clientId}/public-meta` — hosted only
- `POST /api/v1/oauth2/authorize/complete` — hosted only
- `POST /api/v1/auth/sessions` — widget session mode only

All endpoints are stable; the divergence is purely in the React-side composition.
