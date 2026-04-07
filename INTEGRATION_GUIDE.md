# FIVUCSAS Integration Guide

> Comprehensive developer guide for integrating FIVUCSAS biometric authentication into your application.
>
> **Last updated**: 2026-03-28

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [JavaScript SDK](#2-javascript-sdk)
3. [React Integration](#3-react-integration)
4. [Web Component](#4-web-component)
5. [OAuth 2.0 / OIDC](#5-oauth-20--oidc)
6. [Direct REST API](#6-direct-rest-api)
7. [Webhook Events (postMessage)](#7-webhook-events-postmessage)
8. [Security Best Practices](#8-security-best-practices)

---

## 1. Quick Start

Add FIVUCSAS authentication to any website in under 5 minutes.

### Minimal HTML + JS Example

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>My App</title>
</head>
<body>
  <button id="login-btn">Log In with FIVUCSAS</button>
  <div id="result"></div>

  <!-- Load the SDK (IIFE bundle, 9.5KB) -->
  <script src="https://app.fivucsas.com/verify/sdk/fivucsas-auth.iife.js"></script>

  <script>
    // 1. Initialize with your client ID
    const auth = new FivucsasAuth({
      clientId: 'your-client-id',
      baseUrl: 'https://app.fivucsas.com/verify/',
      apiBaseUrl: 'https://api.fivucsas.com/api/v1',
      locale: 'en',
    });

    // 2. Trigger verification on button click
    document.getElementById('login-btn').addEventListener('click', async () => {
      try {
        const result = await auth.verify({
          flow: 'login',
          onStepChange: (step) => {
            console.log(`Step: ${step.method} (${step.progress}/${step.total})`);
          },
        });

        // 3. Use the result
        console.log('Authenticated!', result);
        document.getElementById('result').textContent =
          `Session: ${result.sessionId}, Methods: ${result.completedMethods.join(', ')}`;
      } catch (err) {
        console.error('Auth failed:', err.message);
      }
    });
  </script>
</body>
</html>
```

**What happens:** Clicking the button opens a modal overlay containing the FIVUCSAS authentication widget (loaded in an iframe). The user completes the configured auth steps (password, face, fingerprint, etc.), and the SDK returns a `VerifyResult` with the session ID, user ID, and completed methods.

---

## 2. JavaScript SDK

### Installation

**CDN (IIFE bundle):**
```html
<script src="https://app.fivucsas.com/verify/sdk/fivucsas-auth.iife.js"></script>
```

**ESM import (12KB):**
```js
import { FivucsasAuth } from 'https://app.fivucsas.com/verify/sdk/fivucsas-auth.esm.js';
```

### `FivucsasAuth` Constructor

```ts
const auth = new FivucsasAuth(config: FivucsasConfig);
```

#### `FivucsasConfig`

| Property     | Type                          | Required | Default | Description |
|-------------|-------------------------------|----------|---------|-------------|
| `clientId`  | `string`                      | Yes      | -       | Your application's client ID (registered in FIVUCSAS) |
| `baseUrl`   | `string`                      | No       | `https://verify.fivucsas.com` | URL of the verify-app widget |
| `apiBaseUrl`| `string`                      | No       | `https://api.fivucsas.com/api/v1` | Identity Core API base URL |
| `locale`    | `'en' \| 'tr'`                | No       | `'en'`  | UI language (English or Turkish) |
| `theme`     | `FivucsasTheme`               | No       | `{}`    | Visual customization |

#### `FivucsasTheme`

| Property       | Type                  | Description |
|---------------|-----------------------|-------------|
| `primaryColor` | `string`             | Primary brand color (CSS value) |
| `borderRadius` | `string`             | Border radius for UI elements |
| `fontFamily`   | `string`             | Font family |
| `mode`         | `'light' \| 'dark'`  | Light or dark mode |

### `auth.verify(options?)` — Start Authentication

Returns a `Promise<VerifyResult>` that resolves when authentication completes.

```ts
const result = await auth.verify(options?: VerifyOptions);
```

#### `VerifyOptions`

| Property       | Type                                | Description |
|---------------|-------------------------------------|-------------|
| `flow`        | `string`                            | Auth flow name (e.g., `'login'`, `'high-security'`) |
| `userId`      | `string`                            | Pre-fill user ID |
| `sessionId`   | `string`                            | Resume an existing auth session |
| `methods`     | `string[]`                          | Restrict to specific methods (e.g., `['PASSWORD', 'FACE']`) |
| `container`   | `string \| HTMLElement`             | CSS selector or element for inline mode (no modal) |
| `onStepChange`| `(step: StepInfo) => void`          | Called when the user advances to a new auth step |
| `onError`     | `(error: ErrorInfo) => void`        | Called on error |
| `onCancel`    | `() => void`                        | Called when the user cancels |

**Modal vs. Inline mode:**
- If `container` is omitted, the widget opens as a centered modal overlay with a close button.
- If `container` is provided, the widget is embedded inline within the specified element.

#### `StepInfo`

```ts
{ method: string; progress: number; total: number }
```

#### `ErrorInfo`

```ts
{ code: string; message: string }
```

#### `VerifyResult`

| Property           | Type       | Description |
|-------------------|------------|-------------|
| `success`         | `boolean`  | Always `true` on resolution |
| `sessionId`       | `string`   | The completed auth session ID |
| `userId`          | `string?`  | Authenticated user's ID (if available) |
| `completedMethods`| `string[]` | List of completed auth methods (e.g., `['PASSWORD', 'FACE']`) |
| `authCode`        | `string?`  | OAuth 2.0 authorization code (if OAuth flow) |

### `auth.destroy()` — Cleanup

Removes the iframe, overlay, and message listeners. Rejects any pending `verify()` promise.

```ts
auth.destroy();
```

### Error Handling

The `verify()` promise rejects with an `Error` in these cases:

| Error Message | Cause |
|--------------|-------|
| `FivucsasAuth: verification cancelled by user` | User clicked close or backdrop |
| `FivucsasAuth: verification cancelled` | Widget sent cancel event |
| `FivucsasAuth: verification already in progress` | Called `verify()` while another is active |
| `FivucsasAuth [CODE]: message` | Server-side error |
| `FivucsasAuth: destroyed` | `destroy()` called during verification |

---

## 3. React Integration

### Components

#### `<FivucsasProvider>`

Wraps your app (or part of it) to provide the SDK instance via React context.

```tsx
import { FivucsasProvider } from '@fivucsas/auth-react';

function App() {
  return (
    <FivucsasProvider
      clientId="your-client-id"
      baseUrl="https://app.fivucsas.com/verify/"
      apiBaseUrl="https://api.fivucsas.com/api/v1"
      locale="en"
      theme={{ mode: 'light' }}
    >
      <YourApp />
    </FivucsasProvider>
  );
}
```

**Props:** Same as `FivucsasConfig` plus `children: ReactNode`.

The provider creates a single `FivucsasAuth` instance and recreates it if config props change. It cleans up on unmount.

#### `<VerifyButton>`

A pre-built MUI button that triggers verification.

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
        console.log('Authenticated:', result.sessionId);
        // Redirect or update state
      }}
      onError={(error) => console.error(error)}
      onCancel={() => console.log('Cancelled')}
    />
  );
}
```

**Props:**

| Prop        | Type                              | Default            | Description |
|------------|-----------------------------------|--------------------|-------------|
| `flow`     | `string?`                         | -                  | Auth flow name |
| `userId`   | `string?`                         | -                  | Pre-fill user ID |
| `methods`  | `string[]?`                       | -                  | Restrict methods |
| `container`| `string \| HTMLElement?`          | -                  | Inline mount target |
| `variant`  | `'contained' \| 'outlined' \| 'text'` | `'contained'` | MUI button variant |
| `size`     | `'small' \| 'medium' \| 'large'` | `'medium'`         | Button size |
| `label`    | `string`                          | `'Verify Identity'`| Button text |
| `onComplete`| `(result: VerifyResult) => void` | -                  | Success callback |
| `onError`  | `(error: Error) => void`          | -                  | Error callback |
| `onCancel` | `() => void`                      | -                  | Cancel callback |
| `disabled` | `boolean`                         | `false`            | Disable button |

The button shows a spinner and "Verifying..." text while authentication is in progress.

### Hooks

#### `useVerification()`

Low-level hook for custom UI. Must be used within `<FivucsasProvider>`.

```tsx
import { useVerification } from '@fivucsas/auth-react';

function CustomAuthUI() {
  const { verify, isVerifying, result, error, reset } = useVerification();

  const handleLogin = async () => {
    try {
      const res = await verify({ flow: 'login' });
      console.log('Done:', res);
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div>
      <button onClick={handleLogin} disabled={isVerifying}>
        {isVerifying ? 'Verifying...' : 'Log In'}
      </button>
      {result && <p>Session: {result.sessionId}</p>}
      {error && <p>Error: {error.message}</p>}
      <button onClick={reset}>Reset</button>
    </div>
  );
}
```

**Return value:**

| Property      | Type                                          | Description |
|--------------|-----------------------------------------------|-------------|
| `verify`     | `(options?: Partial<VerifyOptions>) => Promise<VerifyResult>` | Start verification |
| `isVerifying`| `boolean`                                     | `true` while auth is in progress |
| `result`     | `VerifyResult \| null`                        | Last successful result |
| `error`      | `Error \| null`                               | Last error |
| `reset`      | `() => void`                                  | Clear result and error state |

#### `useFivucsasAuth()`

Access the raw `FivucsasAuth` instance from context.

```tsx
import { useFivucsasAuth } from '@fivucsas/auth-react';

const auth = useFivucsasAuth(); // FivucsasAuth instance
```

---

## 4. Web Component

The `<fivucsas-verify>` custom element wraps the SDK into a declarative HTML element. No framework required.

### Usage

```html
<!-- Load the SDK (registers the custom element automatically) -->
<script src="https://app.fivucsas.com/verify/sdk/fivucsas-auth.iife.js"></script>

<!-- Render a "Verify with FIVUCSAS" button -->
<fivucsas-verify
  client-id="your-client-id"
  flow="login"
  locale="en"
  base-url="https://app.fivucsas.com/verify/"
  api-base-url="https://api.fivucsas.com/api/v1"
  theme='{"mode":"light"}'
></fivucsas-verify>
```

### Attributes

| Attribute      | Type    | Required | Description |
|---------------|---------|----------|-------------|
| `client-id`   | string  | Yes      | Your client ID |
| `flow`        | string  | No       | Auth flow name |
| `user-id`     | string  | No       | Pre-fill user ID |
| `locale`      | string  | No       | `'en'` or `'tr'` |
| `base-url`    | string  | No       | Widget URL |
| `api-base-url`| string  | No       | API base URL |
| `theme`       | JSON    | No       | Theme object as JSON string |
| `auto-verify` | boolean | No       | Start verification immediately on mount |

### Events

Listen for custom events on the element:

```js
const el = document.querySelector('fivucsas-verify');

el.addEventListener('fivucsas-complete', (e) => {
  console.log('Success:', e.detail);
  // e.detail = { success, sessionId, userId, completedMethods, authCode }
});

el.addEventListener('fivucsas-error', (e) => {
  console.error('Error:', e.detail);
  // e.detail = { code, message }
});

el.addEventListener('fivucsas-cancel', () => {
  console.log('Cancelled');
});

el.addEventListener('fivucsas-step-change', (e) => {
  console.log('Step:', e.detail);
  // e.detail = { method, progress, total }
});
```

All events bubble and are composed (cross shadow DOM).

### Programmatic Control

```js
const el = document.querySelector('fivucsas-verify');

// Start verification programmatically
const result = await el.startVerification();
```

---

## 5. OAuth 2.0 / OIDC

FIVUCSAS implements the **Authorization Code Flow** per OAuth 2.0 (RFC 6749) with OpenID Connect discovery.

### Discovery

```
GET https://api.fivucsas.com/.well-known/openid-configuration
```

Returns:
```json
{
  "issuer": "https://api.fivucsas.com",
  "authorization_endpoint": "https://api.fivucsas.com/api/v1/oauth2/authorize",
  "token_endpoint": "https://api.fivucsas.com/api/v1/oauth2/token",
  "userinfo_endpoint": "https://api.fivucsas.com/api/v1/oauth2/userinfo",
  "jwks_uri": "https://api.fivucsas.com/.well-known/jwks.json",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code"],
  "scopes_supported": ["openid", "profile", "email", "phone"],
  "id_token_signing_alg_values_supported": ["HS256"],
  "claims_supported": ["sub", "iss", "aud", "exp", "iat", "email", "email_verified", "name", "given_name", "family_name", "phone_number", "phone_number_verified", "updated_at"]
}
```

### Authorization Code Flow

#### Step 1: Authorize

Redirect the user or call from your backend:

```
GET https://api.fivucsas.com/api/v1/oauth2/authorize
  ?client_id=your-client-id
  &redirect_uri=https://yourapp.com/callback
  &response_type=code
  &scope=openid profile email
  &state=random-csrf-token
```

**If the user is authenticated**, returns:
```json
{
  "code": "abc123...",
  "state": "random-csrf-token",
  "redirect_uri": "https://yourapp.com/callback"
}
```

**If the user is not authenticated**, returns:
```json
{
  "action": "authenticate",
  "client_id": "your-client-id",
  "client_name": "Your App",
  "scope": "openid profile email",
  "state": "random-csrf-token",
  "redirect_uri": "https://yourapp.com/callback"
}
```

At this point, embed the FIVUCSAS auth widget to authenticate the user, then retry the authorize call.

#### Step 2: Exchange Code for Tokens

```
POST https://api.fivucsas.com/api/v1/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=abc123...
&redirect_uri=https://yourapp.com/callback
&client_id=your-client-id
&client_secret=your-client-secret
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

#### Step 3: Get User Info

```
GET https://api.fivucsas.com/api/v1/oauth2/userinfo
Authorization: Bearer <access_token>
```

Response:
```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "email_verified": true,
  "name": "John Doe",
  "given_name": "John",
  "family_name": "Doe"
}
```

### JWKS

```
GET https://api.fivucsas.com/.well-known/jwks.json
```

Note: FIVUCSAS uses HMAC-SHA256 for token signing. The JWKS endpoint exposes key metadata but not the secret value. For token validation, use the userinfo endpoint or validate tokens server-side with your client secret.

---

## 6. Direct REST API

For backends that need to interact with FIVUCSAS directly without the widget.

### Authentication

#### Login

```bash
POST https://api.fivucsas.com/api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "UserPassword123"
}
```

Response:
```json
{
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe"
    }
  }
}
```

Use the `accessToken` as a Bearer token for subsequent requests.

#### Refresh Token

```bash
POST https://api.fivucsas.com/api/v1/auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```

Response:
```json
{
  "data": {
    "accessToken": "new-access-token",
    "refreshToken": "new-refresh-token"
  }
}
```

### Multi-Step Auth Sessions

For flows requiring multiple authentication methods (e.g., password + face + fingerprint).

#### Create Auth Session

```bash
POST https://api.fivucsas.com/api/v1/auth/sessions
Content-Type: application/json
Authorization: Bearer <accessToken>

{
  "operationType": "APP_LOGIN",
  "tenantId": "tenant-uuid"
}
```

Response:
```json
{
  "data": {
    "id": "session-uuid",
    "status": "PENDING",
    "steps": [
      { "stepNumber": 1, "methodType": "PASSWORD", "status": "PENDING" },
      { "stepNumber": 2, "methodType": "FACE", "status": "PENDING" }
    ],
    "currentStep": 1,
    "totalSteps": 2
  }
}
```

#### Execute Step

```bash
POST https://api.fivucsas.com/api/v1/auth/sessions/{sessionId}/steps/{stepNumber}
Content-Type: application/json
Authorization: Bearer <accessToken>

{
  "data": {
    "password": "UserPassword123"
  }
}
```

The `data` payload depends on the method type:

| Method      | Data Fields |
|------------|-------------|
| `PASSWORD` | `{ "password": "..." }` |
| `EMAIL_OTP`| `{ "code": "123456" }` |
| `SMS_OTP`  | `{ "code": "123456" }` |
| `TOTP`     | `{ "code": "123456" }` |
| `FACE`     | `{ "image": "base64..." }` |
| `VOICE`    | `{ "audio": "base64..." }` |
| `FINGERPRINT` | `{ "credentialId": "...", "authenticatorData": "...", "clientDataJSON": "...", "signature": "..." }` |
| `HARDWARE_KEY` | `{ "credentialId": "...", "authenticatorData": "...", "clientDataJSON": "...", "signature": "..." }` |
| `QR_CODE`  | `{ "token": "..." }` |
| `NFC_DOCUMENT` | `{ "cardId": "..." }` |

Response on step completion:
```json
{
  "data": {
    "id": "session-uuid",
    "status": "IN_PROGRESS",
    "currentStep": 2,
    "steps": [
      { "stepNumber": 1, "methodType": "PASSWORD", "status": "COMPLETED" },
      { "stepNumber": 2, "methodType": "FACE", "status": "PENDING" }
    ]
  }
}
```

When all steps are completed, `status` becomes `"COMPLETED"`.

### Common Headers

All authenticated requests require:
```
Authorization: Bearer <accessToken>
Content-Type: application/json
```

### Error Responses

```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable description"
}
```

Common error codes:
- `401` — Invalid or expired token
- `403` — Insufficient permissions
- `404` — Resource not found
- `429` — Rate limited

---

## 7. Webhook Events (postMessage)

The verify-app iframe communicates with the parent page via `window.postMessage`. All messages follow the format:

```ts
{
  type: 'fivucsas:<event-name>',
  payload: { ... }
}
```

The SDK handles these automatically. If you are building a custom integration without the SDK, listen for these events:

### Event Types

#### `fivucsas:ready`

Sent when the iframe has loaded and is ready to receive configuration.

```ts
{ type: 'fivucsas:ready', payload: {} }
```

**Your response:** Send a `fivucsas:config` message back to the iframe:

```ts
iframe.contentWindow.postMessage({
  type: 'fivucsas:config',
  payload: {
    theme: 'light',
    locale: 'en',
    apiBaseUrl: 'https://api.fivucsas.com/api/v1',
    allowedOrigin: window.location.origin,
  }
}, 'https://app.fivucsas.com');
```

#### `fivucsas:step-change`

Sent when the user advances to a new authentication step.

```ts
{
  type: 'fivucsas:step-change',
  payload: {
    methodType: 'FACE',
    stepIndex: 1,
    totalSteps: 3
  }
}
```

#### `fivucsas:complete`

Sent when all authentication steps are completed.

```ts
{
  type: 'fivucsas:complete',
  payload: {
    sessionId: 'uuid',
    userId: 'uuid',
    completedMethods: ['PASSWORD', 'FACE'],
    authCode: 'oauth-code-if-applicable'
  }
}
```

#### `fivucsas:error`

Sent when authentication fails.

```ts
{
  type: 'fivucsas:error',
  payload: {
    code: 'AUTH_FAILED',
    error: 'Face verification did not match'
  }
}
```

#### `fivucsas:cancel`

Sent when the user cancels authentication from within the widget.

```ts
{ type: 'fivucsas:cancel', payload: {} }
```

#### `fivucsas:resize`

Sent when the widget content height changes (for inline mode).

```ts
{
  type: 'fivucsas:resize',
  payload: { height: 520 }
}
```

### Origin Validation

Always validate `event.origin` before processing messages:

```js
window.addEventListener('message', (event) => {
  if (event.origin !== 'https://app.fivucsas.com') return;
  if (!event.data?.type?.startsWith('fivucsas:')) return;

  // Process event...
});
```

---

## 8. Security Best Practices

### CORS Configuration

If you host the widget on a different domain, ensure your server allows the widget origin:

```
Access-Control-Allow-Origin: https://app.fivucsas.com
```

### Content Security Policy (CSP)

Add the widget domain to your CSP headers:

```
Content-Security-Policy:
  frame-src https://app.fivucsas.com;
  connect-src https://api.fivucsas.com;
```

If using the SDK via CDN:
```
script-src https://app.fivucsas.com;
```

### Token Storage

| Approach | Recommended? | Notes |
|----------|-------------|-------|
| `httpOnly` cookie | Best | Not accessible to JS, prevents XSS |
| In-memory variable | Good | Lost on page refresh, safe from XSS |
| `sessionStorage` | Acceptable | Cleared when tab closes |
| `localStorage` | Avoid | Accessible to any JS on the page (XSS risk) |

### Token Validation

- Always validate tokens server-side before granting access
- Use the `/api/v1/oauth2/userinfo` endpoint to verify token validity
- Check `exp` (expiration) and `iss` (issuer) claims
- Implement token refresh before expiration

### Iframe Security

The SDK sets these iframe attributes automatically:
- `sandbox="allow-scripts allow-forms allow-same-origin allow-popups allow-modals"` — restricts iframe capabilities
- `allow="camera 'src'; microphone 'src'; publickey-credentials-get 'src'"` — grants access to biometric sensors

### State Parameter (OAuth)

Always use a cryptographically random `state` parameter in OAuth flows to prevent CSRF attacks:

```js
const state = crypto.randomUUID();
sessionStorage.setItem('oauth_state', state);
// Include state in authorize request, verify it in callback
```

### Rate Limiting

The FIVUCSAS API enforces rate limits on all endpoints. If you receive a `429 Too Many Requests` response, implement exponential backoff before retrying.

---

## Production URLs

| Resource | URL |
|----------|-----|
| Identity Core API | `https://api.fivucsas.com` |
| Auth Widget | `https://app.fivucsas.com/verify/` |
| OIDC Discovery | `https://api.fivucsas.com/.well-known/openid-configuration` |
| JWKS | `https://api.fivucsas.com/.well-known/jwks.json` |
| Swagger UI | `https://api.fivucsas.com/swagger-ui.html` |

---

## Support

- **Swagger UI**: https://api.fivucsas.com/swagger-ui.html
- **Developer Portal**: https://app.fivucsas.com/developer-portal
- **Widget Demo**: https://app.fivucsas.com/widget-demo
