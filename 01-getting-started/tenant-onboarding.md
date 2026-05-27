# Tenant Onboarding Playbook

**Audience**: Developers integrating FIVUCSAS into a tenant application (web, mobile, desktop, CLI).
**Goal**: A working "Sign in with FIVUCSAS" button on your site in under 5 minutes of code time.
**Last updated**: 2026-05-11

---

## What you will have at the end

A button on your site that, when clicked, takes the user to `verify.fivucsas.com`, walks them through the auth flow you have configured for your tenant (password + face, password + TOTP, passwordless face + voice — whatever you picked in the admin console), and redirects back to your callback URL with a one-time code. Your backend exchanges that code at `/oauth2/token` for an access token + refresh token. From your application's perspective it is a standard OAuth 2.0 / OIDC authorization-code-with-PKCE flow — the FIVUCSAS-specific biometric, MFA, and step-up logic is fully encapsulated on the hosted login page.

---

## 5-minute quickstart

### 1. Install the SDK

```bash
npm install @fivucsas/auth-js
```

For React projects, `@fivucsas/auth-react` is also available with hooks and ready-made components — see the integration guide. The rest of this quickstart assumes vanilla JS.

### 2. Initiate the login

```ts
import { FivucsasAuth } from '@fivucsas/auth-js';

const auth = new FivucsasAuth({
  clientId: 'fiv_live_abc123',          // from app.fivucsas.com admin console
  redirectUri: 'https://yourapp.com/auth/callback',
  scope: 'openid profile email',
});

document.querySelector('#login-btn').addEventListener('click', () => {
  auth.loginRedirect({
    state: crypto.randomUUID(),         // SDK persists & checks this for you
    // PKCE code_verifier + code_challenge are generated automatically
  });
});
```

That is the entire client-side integration. `loginRedirect` does a full-page navigation to `https://verify.fivucsas.com/login?client_id=...&response_type=code&...`. The SDK stores the `state` and `code_verifier` in `sessionStorage` keyed by `state`.

### 3. Handle the callback

When the user finishes the auth flow on `verify.fivucsas.com`, the browser is redirected back to your `redirectUri` with `?code=...&state=...`.

```ts
// pages/auth/callback (vanilla JS — works on any framework)
import { FivucsasAuth } from '@fivucsas/auth-js';

const auth = new FivucsasAuth({ /* same config as above */ });
const params = new URLSearchParams(window.location.search);

const tokens = await auth.handleCallback({
  code:  params.get('code'),
  state: params.get('state'),
});
// tokens = { access_token, refresh_token, id_token, expires_in: 900, token_type: 'Bearer' }
```

`handleCallback` exchanges the code at `https://api.fivucsas.com/oauth2/token` using the stored `code_verifier`, validates the `state` matches, parses the ID token, and returns the token bundle. Persist the access token in memory (or an HTTP-only cookie via your own backend) and the refresh token in a secure store. Never put the refresh token in `localStorage` — see "Going to production" below.

### 4. Server-side exchange (optional — recommended for confidential clients)

If your client is **confidential** (web backend with a stored client secret, not a SPA), do the code exchange from your server instead of the SDK so the client secret never reaches the browser:

```bash
curl -X POST https://api.fivucsas.com/oauth2/token \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -d grant_type=authorization_code \
  -d code="$CODE" \
  -d redirect_uri="https://yourapp.com/auth/callback" \
  -d code_verifier="$CODE_VERIFIER"
```

SPAs are **public** clients (see ADR 0001 + V38). They MUST use PKCE and MUST NOT hold a client secret. The SDK uses the public-client path automatically when no `clientSecret` is configured.

---

## Step-by-step

### a. Request OIDC client provisioning

1. Email `support@fivucsas.com` or open a ticket from your admin dashboard at `https://app.fivucsas.com` asking for an OIDC client for your application.
2. Provide:
   - Your tenant ID (visible at the top of your admin dashboard).
   - Application name (shown on the consent screen).
   - **Redirect URIs** — list every URI your app will redirect to. Wildcards are NOT permitted.
   - Client type: `public` (SPA, mobile, desktop loopback, CLI) or `confidential` (server-side web app that can keep a secret).
3. Within one business day, you will receive a `client_id` (and a `client_secret` if `confidential`). The client is provisioned in `oauth2_clients` and bound to your tenant.

### b. Set redirect URIs

Acceptable redirect URI shapes (per RFC 6749 + RFC 8252):

| Shape | When to use |
|-------|-------------|
| `https://yourapp.com/auth/callback` | Standard web (TLS mandatory in production) |
| `http://127.0.0.1:NNNNN/callback`   | Desktop loopback (RFC 8252 §7.3) — port can be `*` |
| `com.yourcompany.app://callback`    | Mobile custom scheme (registered in iOS Info.plist / Android intent-filter) |
| `http://localhost:5173/callback`    | **Development only** — never accepted on prod tenants |

Each registered URI is enforced character-for-character; trailing slashes matter.

### c. Get your client_id (and secret if applicable)

- `client_id` is **not a secret** — it is safe to bundle into your SPA build.
- `client_secret`, if you have one, is a real secret. Never check it into git, never ship it to the browser. Use it only from server-side code with an environment variable.

### d. Install the SDK and wire `loginRedirect`

See the 5-minute quickstart above.

### e. Handle the code exchange

The SDK does this for SPAs. Confidential clients do it server-side with their `client_secret`. Either way, the response contains:

```json
{
  "access_token":  "eyJhbGciOiJSUzI1NiIsImtpZCI6InJzLTIwMjYtMDQiLCJ0eXAi...",
  "refresh_token": "rt_5f6b...",
  "id_token":      "eyJhbGciOiJSUzI1NiI...",
  "token_type":    "Bearer",
  "expires_in":    900
}
```

Validate the `id_token` (RS256, JWKS at `https://api.fivucsas.com/.well-known/jwks.json`), match the `nonce`, then create your session.

---

## MFA flow customization

Tenants choose which auth methods are required, in what order, with optional CHOICE branches — through the admin console at `https://app.fivucsas.com/auth-flows`. You do not change SDK code to switch from `PASSWORD + TOTP` to `PASSWORD + FACE`; the hosted login page reads your tenant's `auth_flows` row and walks the user through whatever you configured.

**Supported methods**: `PASSWORD`, `EMAIL_OTP`, `SMS_OTP`, `TOTP`, `FACE`, `VOICE`, `FINGERPRINT` (WebAuthn platform authenticator), `HARDWARE_KEY` (FIDO2 roaming), `QR_CODE` (cross-device), `NFC_DOCUMENT`.

**Step-up MFA inside an authenticated session** — for high-risk actions like changing a password or approving a transfer, embed the widget iframe for inline step-up so the user does not lose context:

```ts
const { tokens } = await auth.stepUp({ amrRequired: ['fpt'] });
// returns an elevated-privilege access token after a fresh fingerprint prompt
```

Step-up requires the user to already hold a session. See [`STEP_UP_AUTH_GUIDE.md`](STEP_UP_AUTH_GUIDE.md) for the mobile-native ECDSA P-256 path.

---

## End-user UX (what your users see)

1. User clicks your "Sign in with FIVUCSAS" button.
2. Browser navigates to `https://verify.fivucsas.com/login?...`. Top-level page (not an iframe), so passkeys, NFC, WebAuthn, and camera all work without third-party-cookie or cross-origin restrictions.
3. User enters their email (or their tenant has prefilled the hint from your `login_hint` param).
4. The hosted page walks them through the auth flow your tenant configured — for example: password → 6-digit TOTP → "we will send a code to your phone" → SMS OTP.
5. On success, the browser is redirected back to your `redirectUri` with `?code=...&state=...`.
6. Your app exchanges the code, gets tokens, and the user is signed in.

Users who land on `verify.fivucsas.com` directly (not via a `loginRedirect`) get a friendly "return to your application" page; the hosted page is never a SERP destination (it carries `<meta robots="noindex,nofollow">`).

---

## Common gotchas

- **CORS**: zero CORS configuration required on your side. `verify.fivucsas.com` is a top-level navigation; the only API call from the SDK is to `https://api.fivucsas.com/oauth2/token`, which is CORS-enabled for any redirect-URI-registered origin.
- **Redirect URI allowlist**: every redirect URI must be registered ahead of time. Use HTTPS (or `http://127.0.0.1:*` for desktop loopback per RFC 8252). `http://localhost` is accepted only on `dev`-profile tenants.
- **`state` parameter**: anti-CSRF. The SDK generates and validates it for you, but if you build your own client, generate a cryptographically random `state` per request, store it server-side or in `sessionStorage`, and reject the callback if `state` does not match.
- **PKCE `code_challenge`**: mandatory for public clients (SPA, mobile, desktop). The SDK generates `code_verifier` (43–128 chars), SHA-256 hashes it to `code_challenge`, sends `code_challenge_method=S256`. Confidential clients should still use PKCE.
- **Refresh-token rotation**: access tokens live 15 minutes, refresh tokens live 7 days and **rotate on every use** (RFC 6749 §10.4 reuse-detection family-revoke — see ADR 0005). If the platform observes the same refresh token reused after rotation, the **entire family is revoked** and the user has to log in again. This is intentional; treat refresh-token storage as security-critical.
- **`nonce` validation**: the SDK validates the `nonce` in the ID token against the one it sent. Do not skip this if you write your own client.
- **Family-revoke and concurrent tabs**: if your app refreshes the same token from two tabs at once, one tab will succeed and the other will trip family-revoke. Serialize refreshes through a single in-memory promise (`auth-js` does this for you).

---

## Going to production

### Required environment variables

| Var | Where | Notes |
|-----|-------|-------|
| `FIVUCSAS_CLIENT_ID` | Frontend + backend | Public |
| `FIVUCSAS_CLIENT_SECRET` | Backend only | Confidential clients only — never ship to browser |
| `FIVUCSAS_REDIRECT_URI` | Both | Must be in the registered allowlist |
| `FIVUCSAS_AUTH_BASE` | Both | `https://verify.fivucsas.com` |
| `FIVUCSAS_API_BASE` | Both | `https://api.fivucsas.com` |

### Token storage

- **Access token**: in memory or HTTP-only cookie from your backend. Never `localStorage`.
- **Refresh token**: HTTP-only `Secure` `SameSite=Strict` cookie set by your backend. Never expose to JS.
- **Mobile/desktop**: platform secure storage — Android Keystore, iOS Keychain, Windows DPAPI, macOS Keychain, Linux libsecret. The `client-apps` SDK ships `SecureTokenStorage` adapters for each.

### Monitoring

- Subscribe to webhook events at `https://app.fivucsas.com/integrations/webhooks` for `user.login_succeeded`, `user.login_failed`, `mfa.step_failed`, `session.revoked`, `account.locked`.
- Liveness / uptime: `https://status.fivucsas.com` (Uptime Kuma; 60s probe interval).
- Errors surface as standard OAuth 2.0 `error` + `error_description` per RFC 6749 §5.2; the SDK exposes them via `FivucsasAuthError` with a `code` field (`invalid_request`, `invalid_grant`, `account_locked`, `mfa_required`, `rate_limited`, ...). See [`INTEGRATION_GUIDE.md`](INTEGRATION_GUIDE.md) Appendix C.

### Operational tips

- Set a `prompt=login` query parameter on `loginRedirect` to force a fresh authentication (skip SSO).
- Set `login_hint=<email>` to prefill the email field for known users.
- Set `acr_values=mfa` to force MFA even if the tenant's default flow is single-factor (rarely needed; tenant admins normally configure flow at the tenant level).

---

## Reference documentation

- [`EMBEDDABLE_AUTH_WIDGET_ARCHITECTURE.md`](../02-architecture/EMBEDDABLE_AUTH_WIDGET_ARCHITECTURE.md) — full SDK architecture, package matrix, deployment topology.
- [`INTEGRATION_GUIDE.md`](INTEGRATION_GUIDE.md) — exhaustive integration recipes per framework (vanilla, React, Web Components, KMP).
- [`STEP_UP_AUTH_GUIDE.md`](STEP_UP_AUTH_GUIDE.md) — mobile-native ECDSA P-256 step-up flow (Aysenur's track).
- `09-auth-flows/` — the 10-document set covering platform capability matrix, session state machine, per-method enrollment flows, cross-device QR-bridge protocol.
- `adr/` — architectural decisions captured separately. Start with `0001-hosted-first-oidc.md`.
