# ADR 0006: V53 BEFORE-DELETE trigger to forbid hard-deletes on `users` and `tenants`

**Status**: Accepted
**Date**: 2026-04-30
**Deciders**: Backend, data, security

## Context

The `users` table is the centre of an FK web. As of 2026-04-30 it is referenced by ~13 child tables — `user_enrollments`, `face_embeddings`, `voice_enrollments`, `webauthn_credentials`, `nfc_cards`, `totp_secrets`, `devices`, `mfa_sessions`, `refresh_tokens`, `audit_logs`, plus assorted bridge tables. Most of those FKs are `ON DELETE CASCADE`.

A `DELETE FROM users WHERE id = ?` therefore wipes:

- All MFA enrollments (face, voice, TOTP, NFC, WebAuthn).
- All audit history.
- All refresh tokens and active sessions.

This actually happened in production. The 2026-04-28 session captured a wiped `ahabgu` user incident (the user's TOTP / WebAuthn / NFC were all gone after an operator ran an apparently-innocent `DELETE`). The user-facing memory rule `feedback_no_hard_delete_users` was written off the back of that incident: **patch `findByEmail` with `deletedAt IS NULL`, never `DELETE FROM users`.**

The application-level fix (soft delete: set `deleted_at`, never `DELETE`) was already in place via `User.softDelete()` and the GDPR `SoftDeletePurgeJob`. But there was no schema-level guard. A direct `psql` session, a misconfigured ORM, or a future contributor who did not read the memo could still trigger a hard delete.

The same logic applies to `tenants`. Hard-deleting a tenant cascades through every user in that tenant, every flow, every enrollment.

## Decision

Add a Postgres `BEFORE DELETE` trigger on both `users` and `tenants` (Flyway V53) that raises an exception:

```sql
CREATE TRIGGER trg_users_forbid_hard_delete
  BEFORE DELETE ON users
  FOR EACH ROW EXECUTE FUNCTION forbid_hard_delete();
-- forbid_hard_delete() raises 'hard-delete forbidden, use soft delete (set deleted_at)'
```

Soft delete goes through `UPDATE ... SET deleted_at = NOW()`, which the trigger does not block. The GDPR retention job (`SoftDeletePurgeJob`) does the eventual genuine deletion after the retention window — but that job runs in a special context (`SET LOCAL session_replication_role = replica` or equivalent) so it can bypass the trigger when actually purging expired soft-deleted rows.

## Consequences

**Positive**
- Defence in depth: even a manual `psql` session against prod (or a misconfigured tool) cannot wipe a user.
- The error message is loud and actionable: "use soft delete (set deleted_at)".
- Catches misuse during code review *and* at runtime.

**Negative**
- JPA `userRepository.delete(user)` started 5xx'ing because Hibernate generated a literal `DELETE` SQL. Resolved in PR #70 (`fix/user-soft-delete-jpa-restriction`, 2026-05-04) by adding `@SQLDelete(sql = "UPDATE users SET deleted_at = NOW() WHERE id = ?")` + `@SQLRestriction("deleted_at IS NULL")` to the `User` entity. All nine `findBy*` methods now auto-filter the retention window; `findPurgeCandidates` is `nativeQuery=true` so it can still see deleted rows.
- The GDPR purge job needs explicit privilege escalation to actually purge. That is fine — it should be auditable.

**Neutral**
- The same pattern applies to `tenants`. A separate `TenantSoftDeleteAnnotationsTest` (and the parallel `UserSoftDeleteAnnotationsTest` added in PR #70) enforce the annotations at compile time via ArchUnit-style reflection assertions.

## Alternatives considered

- **Application-only rule, no schema guard.** Rejected: the 2026-04-28 incident proved application-only rules are not sufficient under operator pressure.
- **Revoke `DELETE` privilege from the application's database role.** Rejected: would also block legitimate `DELETE` on other tables (refresh tokens, mfa_sessions, etc.). Per-table privilege management is operationally fiddly compared to a trigger.
- **Foreign-key `ON DELETE RESTRICT` everywhere instead of `CASCADE`.** Rejected: would make legitimate cascade cleanup of an orphaned tenant (during demo cleanup, dev resets, etc.) painful. The trigger is the surgical answer.
- **Application-level `@PreRemove` that throws.** Rejected: JPA-only; bypassed by direct SQL, by other applications connecting to the same DB, by future migrations.

## References

- Parent `CHANGELOG.md` 2026-04-30 senior-review remediation entries.
- `MEMORY.md` `feedback_no_hard_delete_users` — the rule of thumb that produced this ADR.
- 2026-04-28 session post-mortem (`MEMORY.md` recent-sessions entry).
- `identity-core-api/CLAUDE.md` Flyway listing — V53.
- PR #70 (`fix/user-soft-delete-jpa-restriction`) — JPA-side companion fix.
