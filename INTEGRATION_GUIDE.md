# FIVUCSAS Developer Integration Guide

> Integrate biometric authentication into your application in 30 minutes.
>
> **Last updated**: 2026-04-13 | **API version**: v1 | **Widget**: verify.fivucsas.com

---

## Table of Contents

1. [Quick Start (5 minutes)](#1-quick-start-5-minutes)
2. [Register a Client Application](#2-register-a-client-application)
3. [OAuth 2.0 / OIDC Flow](#3-oauth-20--oidc-flow)
4. [Auth Widget Embed](#4-auth-widget-embed)
5. [postMessage Events Reference](#5-postmessage-events-reference)
6. [Tenant Configuration & Auth Flows](#6-tenant-configuration--auth-flows)
7. [Error Codes Reference](#7-error-codes-reference)
8. [Production Checklist](#8-production-checklist)

---

## 1. Quick Start (5 minutes)

Add FIVUCSAS biometric auth to any page with a single script tag.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>My App</title>
</head>
<body>
  <button id="login-btn">Log In with FIVUCSAS</button>

  <!-- 1. Load the SDK -->
  <script src="https://verify.fivucsas.com/sdk/fivucsas-auth.iife.js"></script>

  <script>
    // 2. Initialize with your client ID
    const auth = new FivucsasAuth({
      clientId: 'fiv_YOUR_CLIENT_ID',
      locale: 'en',
    });

    // 3. Trigger verification on click
    document.getElementById('login-btn').addEventListener('click', async () => {
      try {
        const result = await auth.verify({
          onStepChange: ({ method, progress, total }) => {
            console.log(`Step ${progress}/${total}: ${method}`);
          },
        });

        // result.sessionId, result.userId, result.completedMethods
        console.log('Authenticated!', result);
      } catch (err) {
        if (!err.message.includes('cancelled')) {
          console.error('Auth error:', err.message);
        }
      }
    });
  </script>
</body>
</html>
```

**What happens:** Clicking the button opens a modal overlay with the FIVUCSAS verification widget (in a sandboxed iframe). The user completes the configured auth steps (password, face, fingerprint, etc.). The SDK returns a `VerifyResult` via `postMessage` when all steps pass.

---

## 2. Register a Client Application

All integrations require a **client ID** and **client secret**, obtained from the Developer Portal.

### Via the Developer Portal (recommended)

1. Go to **https://app.fivucsas.com/developer-portal**
2. Sign in with your FIVUCSAS tenant account
3. Click **Register New App**
4. Fill in:
   - **Application Name** — human-readable name shown on the consent screen
   - **Redirect URIs** — comma-separated list of allowed callback URLs (exact match required)
   - **Scopes** — `openid`, `profile`, `email`, `auth` (select what your app needs)
5. Copy the `client_id` and `client_secret` shown **once** at creation time

> **Security:** The client secret is hashed server-side immediately after creation. Store it in an environment variable — never commit it to version control.

### Via REST API

```bash
POST https://api.fivucsas.com/api/v1/oauth2/clients
Authorization: Bearer <your-access-token>
Content-Type: application/json

{
  "appName": "My Integration",
  "redirectUris": "https://myapp.com/callback,https://localhost:3000/callback",
  "scopes": ["openid", "profile", "email"]
}
```

Response (secret shown **once**):
```json
{
  "id": "uuid",
  "appName": "My Integration",
  "clientId": "fiv_7a3b9c...",
  "clientSecret": "8f2e4a...",
  "redirectUris": ["https://myapp.com/callback", "https://localhost:3000/callback"],
  "scopes": ["openid", "profile", "email"],
  "status": "ACTIVE",
  "createdAt": "2026-04-13T10:00:00Z"
}
```

---

## 3. OAuth 2.0 / OIDC Flow

FIVUCSAS implements **Authorization Code Flow** (RFC 6749) with optional PKCE (RFC 7636) and OpenID Connect Core 1.0.

### Discovery

```
GET https://api.fivucsas.com/.well-known/openid-configuration
```

Key endpoints returned:

| Endpoint | URL |
|----------|-----|
| Authorization | `https://api.fivucsas.com/api/v1/oauth2/authorize` |
| Token | `https://api.fivucsas.com/api/v1/oauth2/token` |
| UserInfo | `https://api.fivucsas.com/api/v1/oauth2/userinfo` |
| JWKS | `https://api.fivucsas.com/.well-known/jwks.json` |

### Step 1 — Authorization Request

Call the authorize endpoint (from your server or a redirect). Generates a session for the user to authenticate through, or returns an `authorization_code` immediately if the user already has a valid session.

```
GET https://api.fivucsas.com/api/v1/oauth2/authorize
  ?client_id=fiv_YOUR_CLIENT_ID
  &redirect_uri=https://myapp.com/callback
  &response_type=code
  &scope=openid profile email
  &state=CSRF_RANDOM_TOKEN
  &code_challenge=BASE64URL_SHA256_OF_VERIFIER
  &code_challenge_method=S256
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `client_id` | Yes | Your registered client ID |
| `redirect_uri` | Yes | Must exactly match one of your registered URIs |
| `response_type` | Yes | Must be `code` |
| `scope` | No | Space-separated. Default: `openid profile email` |
| `state` | Recommended | Random value for CSRF protection — returned unchanged |
| `nonce` | No | OIDC nonce for ID token replay protection |
| `code_challenge` | No | PKCE: BASE64URL(SHA-256(code_verifier)) |
| `code_challenge_method` | No | `S256` (recommended) or `plain`. Default: `S256` |

**If user is already authenticated**, response:
```json
{
  "code": "eyJhbGciOiJIUzI1NiJ9...",
  "state": "CSRF_RANDOM_TOKEN",
  "redirect_uri": "https://myapp.com/callback"
}
```

**If user is not authenticated**, response (embed the widget to authenticate, then retry):
```json
{
  "action": "authenticate",
  "client_id": "fiv_YOUR_CLIENT_ID",
  "client_name": "My Integration",
  "scope": "openid profile email",
  "state": "CSRF_RANDOM_TOKEN",
  "redirect_uri": "https://myapp.com/callback"
}
```

When the user completes the widget flow, the widget sends `fivucsas:complete` via postMessage with an `authCode` field — use that as the `code` for Step 2.

### Step 2 — Token Exchange

Exchange the authorization code for tokens. **This must be done server-side** — never expose your `client_secret` to the browser.

```bash
POST https://api.fivucsas.com/api/v1/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=eyJhbGciOiJIUzI1NiJ9...
&redirect_uri=https://myapp.com/callback
&client_id=fiv_YOUR_CLIENT_ID
&client_secret=YOUR_CLIENT_SECRET
&code_verifier=PKCE_VERIFIER_IF_USED
```

Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "id_token": "eyJhbGciOiJIUzI1NiJ9...",
  "scope": "openid profile email"
}
```

> **Note:** The response includes `Cache-Control: no-store` and `Pragma: no-cache` headers per RFC 6749 §5.1.

### Step 3 — Get User Info

```bash
GET https://api.fivucsas.com/api/v1/oauth2/userinfo
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

Response:
```json
{
  "sub": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "email_verified": true,
  "name": "Jane Doe",
  "given_name": "Jane",
  "family_name": "Doe"
}
```

### PKCE Code Generation (JavaScript)

```js
// Generate verifier + challenge (for SPAs / mobile apps without a backend)
async function generatePkce() {
  const verifier = crypto.randomUUID().replace(/-/g, '') + crypto.randomUUID().replace(/-/g, '');
  const data = new TextEncoder().encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  const challenge = btoa(String.fromCharCode(...new Uint8Array(hash)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  return { verifier, challenge };
}

const { verifier, challenge } = await generatePkce();
sessionStorage.setItem('pkce_verifier', verifier);
// Use challenge in /authorize, verifier in /token
```

---

## 4. Auth Widget Embed

The auth widget (`verify.fivucsas.com`) runs in a sandboxed iframe and handles camera, microphone, and WebAuthn. Biometric data never leaves the iframe — only session tokens are returned to the host page.

### Option A — `@fivucsas/auth-js` (Vanilla JS)

**CDN (IIFE, zero dependencies):**
```html
<script src="https://verify.fivucsas.com/sdk/fivucsas-auth.iife.js"></script>
```

**ESM import:**
```js
import { FivucsasAuth } from 'https://verify.fivucsas.com/sdk/fivucsas-auth.esm.js';
```

**npm (if bundling):**
```bash
npm install @fivucsas/auth-js
```

**Usage:**

```js
const auth = new FivucsasAuth({
  clientId: 'fiv_YOUR_CLIENT_ID',
  // Optional:
  baseUrl: 'https://verify.fivucsas.com',       // widget URL
  apiBaseUrl: 'https://api.fivucsas.com/api/v1', // API URL
  locale: 'en',                                   // 'en' | 'tr'
  theme: { mode: 'light' },                       // 'light' | 'dark'
});

// Modal mode (default) — opens a centered overlay
const result = await auth.verify({
  flow: 'login',              // optional: auth flow name
  userId: 'user@example.com', // optional: pre-fill identity
  methods: ['PASSWORD', 'FACE'], // optional: restrict to specific methods
  onStepChange: ({ method, progress, total }) => {
    console.log(`${method}: step ${progress} of ${total}`);
  },
  onError: ({ code, message }) => {
    console.error(`[${code}] ${message}`);
  },
  onCancel: () => console.log('User cancelled'),
});

// result: { success, sessionId, userId, email, completedMethods, authCode, accessToken }

// Inline mode — embed within a container element
const result = await auth.verify({
  container: '#auth-container', // CSS selector or HTMLElement
});

// Cleanup when no longer needed
auth.destroy();
```

**`FivucsasConfig` properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `clientId` | `string` | Yes | — | Your registered client ID |
| `baseUrl` | `string` | No | `https://verify.fivucsas.com` | Widget origin |
| `apiBaseUrl` | `string` | No | `https://api.fivucsas.com/api/v1` | API origin |
| `locale` | `'en' \| 'tr'` | No | `'en'` | UI language |
| `theme` | `FivucsasTheme` | No | `{}` | Visual customization |

**`VerifyResult` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `success` | `boolean` | Always `true` on resolution |
| `sessionId` | `string` | Completed auth session ID |
| `userId` | `string?` | Authenticated user's UUID |
| `email` | `string?` | Authenticated user's email |
| `displayName` | `string?` | User's display name |
| `completedMethods` | `string[]` | e.g., `['PASSWORD', 'FACE']` |
| `authCode` | `string?` | OAuth 2.0 authorization code |
| `accessToken` | `string?` | JWT access token |
| `refreshToken` | `string?` | JWT refresh token |

### Option B — `@fivucsas/auth-react`

```bash
npm install @fivucsas/auth-react
```

**Wrap your app with `<FivucsasProvider>`:**

```tsx
import { FivucsasProvider } from '@fivucsas/auth-react';

function App() {
  return (
    <FivucsasProvider
      clientId="fiv_YOUR_CLIENT_ID"
      locale="en"
      theme={{ mode: 'light' }}
    >
      <Router>
        <Routes />
      </Router>
    </FivucsasProvider>
  );
}
```

**Use `<VerifyButton>` for a drop-in login button:**

```tsx
import { VerifyButton } from '@fivucsas/auth-react';

function LoginPage() {
  return (
    <VerifyButton
      flow="login"
      label="Log In"
      variant="contained"
      size="large"
      onComplete={(result) => {
        // Store result.accessToken, redirect, etc.
        console.log('Authenticated:', result.sessionId);
        navigate('/dashboard');
      }}
      onError={(error) => console.error(error)}
      onCancel={() => console.log('Cancelled')}
    />
  );
}
```

**Use `useVerification()` for custom UI:**

```tsx
import { useVerification } from '@fivucsas/auth-react';

function CustomLogin() {
  const { verify, isVerifying, result, error, reset } = useVerification();

  const handleLogin = async () => {
    try {
      const res = await verify({ flow: 'login' });
      navigate('/dashboard', { state: { userId: res.userId } });
    } catch (err) {
      if (!err.message.includes('cancelled')) {
        console.error(err);
      }
    }
  };

  return (
    <>
      <button onClick={handleLogin} disabled={isVerifying}>
        {isVerifying ? 'Verifying…' : 'Log In'}
      </button>
      {error && <p className="error">{error.message}</p>}
    </>
  );
}
```

**`useVerification()` return values:**

| Property | Type | Description |
|----------|------|-------------|
| `verify` | `(options?) => Promise<VerifyResult>` | Start verification |
| `isVerifying` | `boolean` | `true` while auth is in progress |
| `result` | `VerifyResult \| null` | Last successful result |
| `error` | `Error \| null` | Last error |
| `reset` | `() => void` | Clear result and error state |

### Option C — `@fivucsas/auth-elements` (Web Components — coming soon)

Declarative HTML, framework-agnostic:

```html
<script src="https://verify.fivucsas.com/sdk/fivucsas-auth-elements.js"></script>

<fivucsas-verify
  client-id="fiv_YOUR_CLIENT_ID"
  flow="login"
  locale="en"
  theme='{"mode":"light"}'
></fivucsas-verify>

<script>
  document.querySelector('fivucsas-verify')
    .addEventListener('fivucsas-complete', (e) => {
      console.log('Done:', e.detail.sessionId);
    });
</script>
```

### Option D — Raw iframe (no SDK)

Use this if you cannot load external scripts. Handle postMessage manually.

```html
<iframe
  id="fivucsas-frame"
  src="https://verify.fivucsas.com?client_id=fiv_YOUR_CLIENT_ID&mode=login&locale=en"
  allow="camera 'src'; microphone 'src'; publickey-credentials-get 'src'"
  sandbox="allow-scripts allow-forms allow-same-origin allow-popups allow-modals"
  style="width:100%;height:500px;border:none;"
></iframe>

<script>
  const iframe = document.getElementById('fivucsas-frame');

  window.addEventListener('message', (event) => {
    // ALWAYS validate origin
    if (event.origin !== 'https://verify.fivucsas.com') return;
    if (!event.data?.type?.startsWith('fivucsas:')) return;

    const { type, payload } = event.data;

    if (type === 'fivucsas:ready') {
      // Send config to the widget
      iframe.contentWindow.postMessage({
        type: 'fivucsas:config',
        payload: {
          theme: 'light',
          locale: 'en',
          apiBaseUrl: 'https://api.fivucsas.com/api/v1',
          allowedOrigin: window.location.origin,
        }
      }, 'https://verify.fivucsas.com');
    }

    if (type === 'fivucsas:complete') {
      console.log('Session:', payload.sessionId);
      console.log('Methods:', payload.completedMethods);
      // payload.authCode is the OAuth 2.0 code if the flow was OAuth-linked
    }

    if (type === 'fivucsas:error') {
      console.error(`[${payload.code}] ${payload.error}`);
    }

    if (type === 'fivucsas:resize') {
      iframe.style.height = payload.height + 'px';
    }
  });
</script>
```

---

## 5. postMessage Events Reference

All messages use the format `{ type: 'fivucsas:<event>', payload: { ... } }`.

### Widget → Host (outbound)

#### `fivucsas:ready`

Widget iframe has loaded and is ready to receive configuration.

```js
{ type: 'fivucsas:ready', payload: { version: '1.0.0', timestamp: 1744550000000 } }
```

**Action required:** Respond with `fivucsas:config` (see below).

#### `fivucsas:step-change`

User advanced to a new authentication step.

```js
{
  type: 'fivucsas:step-change',
  payload: {
    stepIndex: 1,          // 0-based index of current step
    methodType: 'FACE',    // auth method type
    totalSteps: 3          // total number of steps in the flow
  }
}
```

#### `fivucsas:complete`

All authentication steps passed successfully.

```js
{
  type: 'fivucsas:complete',
  payload: {
    sessionId: '550e8400-...',
    userId: 'a3f19c00-...',
    email: 'user@example.com',
    displayName: 'Jane Doe',
    completedMethods: ['PASSWORD', 'FACE'],
    authCode: 'eyJhbGciOi...',   // present if OAuth flow
    accessToken: 'eyJhbGciOi...',
    refreshToken: 'eyJhbGciOi...',
    timestamp: 1744550000000
  }
}
```

#### `fivucsas:error`

Authentication failed at a step.

```js
{
  type: 'fivucsas:error',
  payload: {
    code: 'FACE_MATCH_FAILED',
    error: 'Face verification did not match enrolled biometric',
    timestamp: 1744550000000
  }
}
```

#### `fivucsas:cancel`

User cancelled from within the widget.

```js
{ type: 'fivucsas:cancel', payload: { sessionId: '...', timestamp: 1744550000000 } }
```

#### `fivucsas:resize`

Widget content height changed (useful in inline / embedded mode).

```js
{ type: 'fivucsas:resize', payload: { height: 520 } }
```

### Host → Widget (inbound)

#### `fivucsas:config`

Sent in response to `fivucsas:ready`. Configures the widget's appearance and API target.

```js
iframe.contentWindow.postMessage({
  type: 'fivucsas:config',
  payload: {
    theme: 'light',           // 'light' | 'dark'
    locale: 'en',             // 'en' | 'tr'
    apiBaseUrl: 'https://api.fivucsas.com/api/v1',
    allowedOrigin: 'https://myapp.com',  // your page's origin
  }
}, 'https://verify.fivucsas.com');
```

> **Security:** Once `allowedOrigin` is received, the widget restricts all subsequent postMessage responses to that origin only.

---

## 6. Tenant Configuration & Auth Flows

### Auth Methods Available

FIVUCSAS supports 10 authentication methods. Tenants enable the methods they want and configure multi-step flows.

| Method | Enum | Description |
|--------|------|-------------|
| Password | `PASSWORD` | Standard username + password |
| Email OTP | `EMAIL_OTP` | 6-digit code sent to email |
| SMS OTP | `SMS_OTP` | 6-digit code sent to mobile (Twilio) |
| TOTP | `TOTP` | Time-based OTP (Google Authenticator, Authy) |
| Face | `FACE` | Face biometric (BlazeFace on-device detection + server match) |
| Voice | `VOICE` | Voice biometric (phrase + speaker verification) |
| Fingerprint | `FINGERPRINT` | WebAuthn platform authenticator (Touch ID, Windows Hello) |
| Hardware Key | `HARDWARE_KEY` | WebAuthn roaming authenticator (YubiKey, etc.) |
| QR Code | `QR_CODE` | Cross-device login via QR scan |
| NFC Document | `NFC_DOCUMENT` | NFC smart card / ID document |

### Configuring Flows

Flows define which methods are required and in what order. Configure them in the **Auth Flow Builder** at `https://app.fivucsas.com/auth-flow-builder`.

Example flows:
- **Login (standard):** `PASSWORD` → `EMAIL_OTP`
- **High security:** `PASSWORD` → `FACE` → `TOTP`
- **Biometric-only:** `FINGERPRINT` → `FACE`
- **Choice step:** `PASSWORD` → (user chooses `TOTP` or `EMAIL_OTP`)

To use a named flow in the widget:
```js
auth.verify({ flow: 'high-security' });
```

If `flow` is omitted, the tenant's default flow is used.

### Tenant-Level Settings

Tenant administrators manage these from the **Settings** page (`/settings`):

- Which auth methods are enrolled/active for users
- Default and named auth flows
- Session duration and token TTL
- Allowed redirect URIs per client application
- Whether to require biometric enrollment before first login

---

## 7. Error Codes Reference

### OAuth 2.0 Errors (RFC 6749 §5.2)

These are returned from `/oauth2/authorize` and `/oauth2/token`:

| `error` | HTTP | Cause |
|---------|------|-------|
| `unsupported_response_type` | 400 | `response_type` is not `code` |
| `unsupported_grant_type` | 400 | `grant_type` is not `authorization_code` |
| `invalid_request` | 400 | Missing or malformed parameter |
| `unauthorized_client` | 400 | `client_id` not found or not active |
| `invalid_grant` | 400 | Authorization code invalid, expired, or already used; PKCE verifier mismatch |
| `invalid_client` | 400 | `client_secret` incorrect |
| `invalid_scope` | 400 | Requested scope not allowed for this client |

Example:
```json
{
  "error": "invalid_grant",
  "error_description": "Authorization code has expired or already been used",
  "state": "your-state-value"
}
```

### UserInfo Errors (RFC 6750)

| Scenario | HTTP | Response |
|----------|------|----------|
| No `Authorization` header | 401 | `invalid_token` + `WWW-Authenticate` header |
| Expired or invalid token | 401 | `invalid_token` + `WWW-Authenticate` header |

### Widget postMessage Error Codes

These appear in `fivucsas:error` payload `.code` field:

| Code | Description |
|------|-------------|
| `AUTH_FAILED` | Generic authentication failure |
| `FACE_MATCH_FAILED` | Face biometric did not match enrolled face |
| `FACE_DETECTION_FAILED` | No face detected in the captured image |
| `VOICE_MATCH_FAILED` | Voice biometric did not match |
| `OTP_INVALID` | OTP code was incorrect |
| `OTP_EXPIRED` | OTP code has expired |
| `WEBAUTHN_FAILED` | WebAuthn assertion failed (fingerprint / hardware key) |
| `QR_EXPIRED` | QR code session timed out |
| `SESSION_EXPIRED` | Auth session timed out |
| `MAX_ATTEMPTS_EXCEEDED` | Too many failed attempts for this step |
| `ENROLLMENT_REQUIRED` | User has not enrolled the required biometric |
| `CLIENT_NOT_FOUND` | `client_id` not recognized |
| `FLOW_NOT_FOUND` | Named flow does not exist for this tenant |
| `UNKNOWN` | Unexpected server error |

### HTTP Status Codes (REST API)

| Status | Meaning |
|--------|---------|
| `200` | OK |
| `201` | Created (new OAuth2 client registered) |
| `204` | No Content (delete successful) |
| `400` | Bad request / validation error |
| `401` | Missing or invalid Bearer token |
| `403` | Insufficient permissions (wrong tenant, not admin) |
| `404` | Resource not found |
| `409` | Conflict (e.g., duplicate redirect URI) |
| `429` | Rate limit exceeded — back off and retry |
| `500` | Internal server error |

---

## 8. Production Checklist

Before going live, verify each of the following:

### Client Registration

- [ ] Client is registered with **production** redirect URIs only (no `localhost`)
- [ ] Client secret is stored as an environment variable — not in source code
- [ ] Only the minimum required scopes are requested
- [ ] Unused client applications are deleted or deactivated

### Security

- [ ] `state` parameter is used in every OAuth authorize request (random, cryptographically secure)
- [ ] `state` value is verified on callback before processing
- [ ] PKCE (`code_challenge` / `code_verifier`) is used for SPAs and mobile apps
- [ ] Token exchange (`/oauth2/token`) is done **server-side only** — client secret never exposed to browser
- [ ] Access tokens are stored in memory or `httpOnly` cookies — not `localStorage`
- [ ] Token expiration (`exp` claim) is checked before use
- [ ] Token refresh is implemented before expiration

### CORS

The FIVUCSAS API (`api.fivucsas.com`) is pre-configured to allow these origins:
- `https://app.fivucsas.com`
- `https://verify.fivucsas.com`
- `https://demo.fivucsas.com`

To allow **your** application's origin, contact your tenant administrator or submit a CORS origin allowlist request through the Developer Portal.

### Content Security Policy (CSP)

Add to your server's `Content-Security-Policy` header:

```
Content-Security-Policy:
  frame-src https://verify.fivucsas.com;
  connect-src https://api.fivucsas.com;
  script-src 'self' https://verify.fivucsas.com;
```

### Redirect URI Allowlist

- [ ] All redirect URIs registered are HTTPS (no HTTP in production)
- [ ] Redirect URIs are exact-match (no wildcards, no path prefix matching)
- [ ] Redirect URI is validated on your callback handler before redirecting

### Iframe / Widget

- [ ] Widget origin is validated in all `window.addEventListener('message', ...)` handlers
- [ ] Your page CSP allows `frame-src https://verify.fivucsas.com`
- [ ] Camera / microphone permissions are granted for the iframe (`allow` attribute)
- [ ] Inline widget containers have a defined height to avoid layout shift

### Error Handling

- [ ] `fivucsas:error` and `fivucsas:cancel` events are handled gracefully in UI
- [ ] `verify()` promise rejections are caught and user-friendly messages are shown
- [ ] `429` (rate limit) responses trigger exponential backoff
- [ ] Server-side token validation errors redirect to re-authentication, not a crash page

### Testing

- [ ] Tested with all auth methods your flow requires
- [ ] Tested on mobile (camera permission prompt, touch fingerprint)
- [ ] Tested Escape / backdrop click cancellation (should not cause errors)
- [ ] Tested token expiration and refresh
- [ ] Verified Swagger docs at https://api.fivucsas.com/swagger-ui.html for latest endpoint signatures

---

## Quick Reference

| Resource | URL |
|----------|-----|
| Identity API | https://api.fivucsas.com |
| Auth Widget | https://verify.fivucsas.com |
| Developer Portal | https://app.fivucsas.com/developer-portal |
| Widget Demo | https://app.fivucsas.com/widget-demo |
| Swagger UI | https://api.fivucsas.com/swagger-ui.html |
| OIDC Discovery | https://api.fivucsas.com/.well-known/openid-configuration |
| JWKS | https://api.fivucsas.com/.well-known/jwks.json |
| Auth Flow Builder | https://app.fivucsas.com/auth-flow-builder |
| Status Page | https://status.fivucsas.com |

---

## Support

- **Swagger UI**: Full endpoint documentation at https://api.fivucsas.com/swagger-ui.html
- **Widget Demo**: Live integration demo at https://app.fivucsas.com/widget-demo
- **Developer Portal**: Manage your apps at https://app.fivucsas.com/developer-portal
