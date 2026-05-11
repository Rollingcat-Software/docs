# ADR 0001: Hosted-first OIDC as the primary integration mode

**Status**: Accepted
**Date**: 2026-04-16
**Deciders**: Platform engineering, security

## Context

FIVUCSAS originally shipped as an embeddable iframe widget that tenants dropped into their site, with the user typing credentials and completing MFA inside the iframe. The widget proved brittle across the surfaces that real customers need to cover:

- **Web NFC** cannot be used inside a cross-origin iframe — the spec restricts the API to top-level browsing contexts. NFC-driven authentication (Turkish e-ID, MRZ-bearing documents) was effectively dead in-iframe.
- **WebAuthn / passkeys** suffer cross-origin edge cases. Cross-origin iframes carry restrictive Permissions Policy defaults, and even with `publickey-credentials-get` delegated, Safari and several embedded webviews refuse the request.
- **Safari ITP** and the broader death of third-party cookies broke the session-cookie handshake between the widget and `api.fivucsas.com` whenever the host site was not on the same registrable domain.
- **Camera + microphone** required explicit `Permissions-Policy: camera=(self "https://verify.fivucsas.com")` headers from every tenant. Hostinger's `.htaccess` quoting bug (2026-04-15) is one of several deployment-time landmines.

Every major comparable platform (Auth0 Universal Login, Okta, Microsoft Entra, Google, Apple, Keycloak, AWS Cognito, Stripe Checkout, Turkish banks, e-Devlet) had already converged on a hosted login page reached by redirect. We had been swimming upstream.

## Decision

The **primary** integration mode is redirective OIDC. Tenants call `FivucsasAuth.loginRedirect({...})`; the SDK navigates the browser to `https://verify.fivucsas.com/login?...`; the user completes the entire auth flow on that top-level page; the browser is redirected back to the tenant's `redirect_uri` with `?code=…&state=…`; the tenant exchanges the code at `/oauth2/token` (RFC 6749 §4.1 authorization code, with PKCE per RFC 7636 for public clients).

The iframe widget is retained — **but only for inline step-up MFA** within an already-authenticated session, where preserving page context matters more than supporting NFC. New tenant integrations default to hosted-first.

Platform coverage of the redirect flow:

| Surface | Mechanism |
|---------|-----------|
| Web (SPA + server-rendered) | Full-page navigation |
| iOS / iPadOS | `ASWebAuthenticationSession` |
| Android | Chrome Custom Tabs + AppAuth |
| Electron / desktop | Loopback redirect per RFC 8252 §7.3 (`http://127.0.0.1:*`) |
| CLI | Loopback redirect per RFC 8252 §7.3 |

## Consequences

**Positive**
- Web NFC, WebAuthn, camera, microphone all work because `verify.fivucsas.com` is the top-level origin.
- Third-party-cookie removal is irrelevant — the session lives on `verify.fivucsas.com`.
- Aligns with industry mental models; tenants who know Auth0 / Okta integrate quickly.
- Centralized: ship a UX or security fix once and every tenant gets it on next redirect.
- Supports identity providers we will federate to later (Google, banks) — they all use the same redirect pattern.

**Negative**
- A redirect always happens. Tenants who wanted users to stay on their domain have to accept the round-trip. (This is the same trade-off Auth0 Universal Login makes; it has not blocked adoption.)
- `verify.fivucsas.com` becomes a high-value target. We mitigate via dedicated rate-limit middleware, `noindex@file` Traefik middleware, and explicit allowlist of redirect URIs per OAuth2 client (RFC 6749 §3.1.2 strict matching).
- We now own the hosted page UX cross-locale (TR + EN), cross-platform, cross-flow. The team commitment is real.

**Neutral**
- Iframe widget code is retained for step-up; it is no longer the load-bearing path. Two SDK entry points coexist in `@fivucsas/auth-js`: `loginRedirect` (primary) and `mountStepUp` (secondary).

## Alternatives considered

- **Stay iframe-first.** Rejected: Web NFC death is structural, not a bug we can patch around. Safari ITP closed the third-party-cookie loophole the widget relied on.
- **Hybrid: iframe by default, redirect as opt-in.** Rejected: defaults shape adoption; tenants would have left their broken iframe integrations in place and complained later.
- **Custom-scheme deep links only (no hosted page in browser).** Rejected: works for native apps but doesn't address SaaS web tenants, who are the larger market.
- **Federate to Auth0 / Cognito as upstream IdP.** Rejected for a biometric product — the FIDO, NFC, voice, face, liveness pipeline is the product. Wrapping a generic IdP would force us to run our biometric step in a federated callback anyway, which would be the hosted page we are now building.

## References

- Parent `CHANGELOG.md` `[2026-04-16]` entry — initial PR-1 ship.
- `CHANGELOG.md` `[2026-04-18f]` — Hosted-first parity rewrite for native clients.
- `web-app/docs/plans/HOSTED_LOGIN_INTEGRATION.md` — implementation plan (PR-1).
- RFC 6749 §4.1 (authorization code grant), RFC 7636 (PKCE), RFC 8252 §7.3 (loopback IP).
