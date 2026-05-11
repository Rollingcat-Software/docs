# ADR 0005: RFC 6749 §10.4 refresh-token family-revoke (V50)

**Status**: Accepted
**Date**: 2026-04-30
**Deciders**: Backend security, identity

## Context

RFC 6749 §10.4 ("Refresh Tokens — Security Considerations") and the OAuth 2.0 Security Best Current Practice draft both call for **refresh-token rotation with reuse detection**. The mechanism:

- A refresh token is single-use. Exchanging it at `/oauth2/token` (`grant_type=refresh_token`) mints a *new* refresh token; the old one is marked rotated.
- If the platform ever sees the *old* (rotated) refresh token re-presented, that means either an attacker stole it pre-rotation, or the legitimate client misused it. Either way, the platform cannot tell whose token is the real one, so the safe action is to revoke **the entire family** descended from the original mint and force the user to log in again.

Before V50 we had refresh-token rotation but no family tracking. Detecting reuse required walking a chain of `parent_id` references, which gets ugly at scale and during concurrent refreshes from two browser tabs.

## Decision

Add `refresh_tokens.family_id UUID` (Flyway V50). All refresh tokens minted from the same originating login share a `family_id`. Rotation keeps the `family_id`; a *new login* generates a new `family_id`.

When a rotated (already-consumed) token is presented:

1. Look up its `family_id`.
2. Revoke every row with that `family_id` — the entire family is gone.
3. Return `invalid_grant` per RFC 6749 §5.2.
4. Emit an audit event so security can review.

## Consequences

**Positive**
- Constant-time reuse detection (one `UPDATE refresh_tokens SET revoked_at = NOW() WHERE family_id = ?`) instead of recursive parent chasing.
- Matches RFC 6749 §10.4 and OAuth 2.0 BCP guidance.
- Closes a real threat: stolen refresh tokens are short-lived in practice — first use either rotates them (attacker wins the race only once) or trips family-revoke (legitimate user notices their session died and re-authenticates).

**Negative**
- **Concurrent-tab refreshes can family-revoke a legitimate user.** Two tabs open the same SPA, both notice the access token expired, both refresh with the same refresh token. One wins, one loses, and the loser trips reuse detection. Mitigated client-side by serializing refreshes through an in-memory promise in `@fivucsas/auth-js` and `@fivucsas/auth-react`. Documented in the tenant-onboarding playbook ("Common gotchas").
- Audit-log growth: family-revoke events are loud, by design.

**Neutral**
- The V50 migration is forward-only. Existing refresh tokens at migration time get a `family_id` defaulted at write; any in-flight token without one is implicitly first-of-family.
- This sits alongside V55 (refresh-token hash + dual-read for at-rest plaintext removal — P1-1) and V56 (placeholder for the future plaintext-column drop). The two are orthogonal: V50 is about *which* tokens to revoke; V55/V56 are about *how* tokens are stored.

## Alternatives considered

- **`parent_id` chain.** Rejected: O(chain-length) revocation, edge-case-y under concurrent refreshes, painful to query in audit tooling.
- **No reuse detection (rotation only).** Rejected: leaves stolen refresh tokens usable indefinitely until natural expiry. RFC 6749 §10.4 explicitly recommends against this.
- **Bind the refresh token to a device fingerprint and refuse cross-device reuse.** Rejected for v1: fingerprints drift (browser updates, IP changes), would generate a stream of false-positive revocations. Future enhancement: bind refresh tokens to a DPoP key per RFC 9449.

## Consequences for tenants

A senior DB review (`SENIOR_DB_REVIEW_2026-05-04.md`) and a 2026-04-30 evening review surfaced a rollback bug in the V50 family-revoke path that was subsequently patched. Tenants that observed elevated "user must log in again" rates around that window were the canary. The fix is in production; see the parent `CHANGELOG.md` follow-ups under `[2026-04-30]`.

## References

- RFC 6749 §10.4 — Refresh Tokens.
- OAuth 2.0 Security BCP — refresh-token rotation + reuse detection.
- `identity-core-api/CLAUDE.md` Flyway listing — V50, V55, V56.
- ADR 0007 — `Persistable<UUID>` wire format (separate bug fix, same table family).
