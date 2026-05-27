# FIVUCSAS Embeddable Auth Widget Architecture

> Created: 2026-03-28 | Status: Research Complete, Ready for Implementation

## The Idea

FIVUCSAS provides embeddable auth components that **our own apps AND third-party websites** use — like how e-Devlet provides login to all government sites, or reCAPTCHA embeds in any website.

## Reference Implementations Analyzed

| Provider | Embed Type | Security | Biometric Support | DX (lines) |
|----------|-----------|----------|-------------------|------------|
| Auth0 Lock | Redirect (recommended) | Custom domain required | None | 10-20 |
| Google Identity | Script + FedCM | Browser-native | None | 5-8 |
| Keycloak | Redirect + themes | Server-hosted pages | None | 15 |
| Firebase Auth UI | Script, in-page | None | None | 15-20 |
| reCAPTCHA | Script, invisible | Internal iframes | None | 3-5 |
| e-Devlet | OAuth 2.0 redirect | Server-hosted | None | 10 |
| **Stripe Elements** | **Script + iframes** | **Cross-origin iframes** | **N/A** | **15-20** |
| Web Components | Custom Element | Style only (Shadow DOM) | Possible | 2-3 |

**Key insight:** No existing auth provider handles embedded biometric capture (camera, microphone). FIVUCSAS is unique here.

## Recommended Architecture: "Stripe Elements for Biometrics"

### Three-Layer Design

```
Layer 1: Developer API (Web Component)
  <fivucsas-verify client-id="..." flow="login" />

Layer 2: Orchestration (OAuth 2.0 + postMessage)
  Creates/manages auth sessions via FIVUCSAS API
  Coordinates multi-step flow via postMessage with iframe

Layer 3: Secure Capture (iframe from verify.fivucsas.com)
  Camera, microphone, WebAuthn run inside the iframe
  Biometric data NEVER leaves the iframe
  Only tokens/session IDs returned to host via postMessage
```

### Why This Approach

1. **Camera/microphone must run in an iframe** — cannot redirect away (user needs to see camera feed)
2. **Biometric data isolation** — face images, voice recordings are as sensitive as credit card numbers → Stripe's iframe model
3. **Multi-step flows** — face + OTP + TOTP needs orchestration → OAuth 2.0
4. **Framework agnostic** — must work in React, Vue, Angular, vanilla JS, KMP WebView → Web Components

### Integration Code (What Developers Write)

**Option A: Script Tag (simplest, like reCAPTCHA)**
```html
<script src="https://cdn.fivucsas.com/auth-elements@1/fivucsas.min.js"></script>

<fivucsas-verify
  client-id="fiv_live_abc123"
  flow="login"
  theme="auto"
  lang="tr"
  on-complete="handleVerified">
</fivucsas-verify>

<script>
function handleVerified(event) {
  const { authCode, userId } = event.detail;
  fetch('/api/auth/fivucsas-callback', {
    method: 'POST',
    body: JSON.stringify({ code: authCode })
  });
}
</script>
```

**Option B: React**
```tsx
import { FivucsasProvider, VerifyButton } from '@fivucsas/auth-react';

function App() {
  return (
    <FivucsasProvider clientId="fiv_live_abc123">
      <VerifyButton
        flow="login"
        onComplete={({ authCode }) => { /* exchange code */ }}
      />
    </FivucsasProvider>
  );
}
```

**Option C: Programmatic**
```typescript
import { FivucsasAuth } from '@fivucsas/auth-js';

const auth = new FivucsasAuth({ clientId: 'fiv_live_abc123' });
const result = await auth.verify({
  flow: 'login',
  methods: ['FACE', 'TOTP'],
  container: '#auth-container',
  theme: { primaryColor: '#6366f1' },
  locale: 'tr',
});

if (result.success) {
  const tokens = await auth.exchangeCode(result.authCode);
}
```

### Communication Flow

```
Third-Party Site                    verify.fivucsas.com (iframe)         FIVUCSAS API
     |                                      |                                |
     |  1. <fivucsas-verify> creates iframe |                                |
     |     allow="camera;microphone"  ──────>|                                |
     |                                      |                                |
     |  2. postMessage("ready")  <──────────|                                |
     |  3. postMessage("config",{theme})───>|                                |
     |                                      |  4. POST /auth/sessions         |
     |                                      |────────────────────────────────>|
     |                                      |  {flowSteps, sessionId}        |
     |                                      |<────────────────────────────────|
     |                                      |                                |
     |  5. postMessage("step-change",       |                                |
     |     {step:"FACE",progress:2/4}) <────|                                |
     |                                      |  [camera, face capture]        |
     |                                      |  6. POST /sessions/{id}/steps  |
     |                                      |────────────────────────────────>|
     |                                      |                                |
     |  7. postMessage("complete",          |                                |
     |     {authCode:"abc123"})  <──────────|                                |
     |                                      |                                |
     |  8. Exchange authCode for tokens ────────────────────────────────────>|
     |  {access_token, id_token, refresh}  <────────────────────────────────|
```

### iframe Configuration

```html
<iframe
  src="https://verify.fivucsas.com/embed?client_id=xxx&flow=login"
  sandbox="allow-scripts allow-forms allow-same-origin"
  allow="camera 'src'; microphone 'src'; publickey-credentials-get 'src'"
  style="width: 100%; height: 600px; border: none;"
></iframe>
```

### Mapping to Existing Codebase (90% Already Built!)

| Existing Code | Becomes | Notes |
|---------------|---------|-------|
| `web-app/src/features/auth/components/MultiStepAuthFlow.tsx` | `verify-app` main component | Already orchestrates 10 auth methods |
| `web-app/src/features/auth/components/steps/*` (10 files) | `verify-app` step components | Already work independently |
| `web-app/src/lib/biometric-engine/` (42 files, 6,500 lines) | `verify-app` biometric engine | Already has IIFE adapter build |
| `web-app/src/core/repositories/AuthSessionRepository.ts` | `verify-app` API layer | Already talks to Identity Core API |
| `web-app/vite.adapter.config.ts` | Basis for `verify-app` build | Already produces IIFE bundles |

### What Needs to Be Built NEW

- `@fivucsas/auth-js` — lightweight SDK (~800 lines): iframe creation, postMessage bridge, token management
- `@fivucsas/auth-elements` — Web Components (Lit): `<fivucsas-verify>`, `<fivucsas-button>`
- `@fivucsas/auth-react` — React bindings: `FivucsasProvider`, `VerifyButton`, `useVerification`
- `verify-app` — extract MultiStepAuthFlow + steps from web-app, deploy to `verify.fivucsas.com`
- OAuth 2.0 endpoints on identity-core-api: `/oauth2/authorize`, `/oauth2/token`, `/oauth2/userinfo`, `/.well-known/openid-configuration`

### Package Structure

```
@fivucsas/
  auth-js/           Core SDK (~15KB)
  auth-elements/     Web Components (~8KB)
  auth-react/        React bindings (~3KB)
  auth-kotlin/       KMP SDK
  verify-app/        Hosted iframe app (extracted from web-app)
  biometric-engine/  Already exists (42 files, 6,500 lines)
  shared-types/      Shared TypeScript types
```

### Mobile (KMP) & Desktop Integration

- KMP apps use native WebView to load `verify.fivucsas.com/embed`
- postMessage bridge works identically in WebView
- For platform-specific biometrics (native fingerprint, NFC), KMP handles natively and submits to auth session API directly
- `@fivucsas/auth-kotlin` SDK wraps WebView + native biometric coordination

### Security Model

| Concern | Solution |
|---------|----------|
| Biometric data isolation | Cross-origin iframe — host cannot access |
| Camera/mic permissions | `allow="camera 'src'; microphone 'src'"` |
| Clickjacking | CSP `frame-ancestors` whitelist per client |
| Token theft | Auth code flow — tokens never exposed to host JS |
| Replay attacks | Nonce in auth session, 30s auth codes |
| CSRF | `state` parameter in OAuth flow |

### Implementation Phases

| Phase | Duration | Work |
|-------|----------|------|
| 1. Extract verify-app | 2 weeks | Extract MultiStepAuthFlow + steps into standalone page at verify.fivucsas.com |
| 2. Build auth-js SDK | 2 weeks | Iframe creation, postMessage handling, token management |
| 3. Build auth-elements | 1 week | Web Components with Lit, CSS Custom Properties theming |
| 4. Build auth-react | 1 week | React bindings wrapping auth-elements |
| 5. OAuth 2.0 endpoints | 2 weeks | Authorization server on identity-core-api |
| 6. Developer portal | 1 week | Docs, client registration UI, API key management |
| **Total** | **~9 weeks** | |

### FIVUCSAS Dogfooding

Our own apps use the same widget:
- **web-app** (admin dashboard): Uses `@fivucsas/auth-react` with first-party flag
- **client-apps** (KMP mobile/desktop): Uses `@fivucsas/auth-kotlin` with WebView
- **landing-website**: Uses `<fivucsas-verify>` Web Component for demo
- This proves the platform works and serves as a live integration example
