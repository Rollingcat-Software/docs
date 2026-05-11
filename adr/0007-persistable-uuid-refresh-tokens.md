# ADR 0007: `Persistable<UUID>` wire format for refresh tokens (PR #71)

**Status**: Accepted
**Date**: 2026-05-04
**Deciders**: Backend

## Context

Hibernate's default insert-vs-update detection asks the entity: "is your `@Id` field null?" — if null, it is new (insert); if non-null, it is presumed-existing (merge / update). That heuristic breaks for entities whose `@Id` is **manually assigned** by the application before persist, which is exactly what `RefreshToken` does — we mint a `UUID.randomUUID()` at construction time so the value can be used in audit events and returned to the client before the JPA flush.

Symptom in production (2026-05-04 06:34–06:38 UTC): six consecutive `MFA_STEP_FAILED` audit log rows for `ahabgu@gmail.com`. Investigation showed:

1. `RefreshTokenService` constructed a `RefreshToken` with a manually-assigned UUID.
2. `entityManager.persist(token)` was called.
3. Hibernate noticed the UUID was non-null, classified the entity as "existing", routed through `merge()` instead of `persist()`, **and silently issued no SQL**.
4. The subsequent `findById(id)` returned empty.
5. The whole MFA step path went sideways from there.

We had no observable failure at the JPA layer — the entity manager genuinely thought it had done its job. The only signal was the downstream audit log.

This is a known Hibernate trap. Documented under "Persistable" in the Spring Data and Hibernate reference manuals.

## Decision

`RefreshToken` (and similar entities with manually-assigned UUID primary keys — to be evaluated case by case) `implements org.springframework.data.domain.Persistable<UUID>` with an explicit `isNew()` flag:

```java
@Entity
public class RefreshToken implements Persistable<UUID> {
    @Id private UUID id;

    @Transient private boolean newEntity = true;

    @Override public UUID getId()      { return id; }
    @Override public boolean isNew()   { return newEntity; }

    @PrePersist
    @PostLoad
    void markNotNew() { this.newEntity = false; }
}
```

After `@PrePersist` (insert path) or `@PostLoad` (entity loaded from DB), the flag flips off and subsequent saves correctly use `update`. Spring Data Repository implementations consult `Persistable.isNew()` before deciding `persist` vs `merge`, so the silent-NOOP path is closed.

Shipped as PR #71 (`fix/refresh-token-persistable-isnew`, commit `a77c844`, 2026-05-04). Closed the six MFA_STEP_FAILED rows above; deployed to prod (image `e9a33cef`, recreated 2026-05-04 12:01 UTC).

## Consequences

**Positive**
- `entityManager.persist(refreshToken)` and `repository.save(refreshToken)` both reliably issue an INSERT.
- The same pattern is portable: any entity with an application-assigned `@Id` can adopt it.
- No change to wire format, table schema, or migration — pure Java-side fix.

**Negative**
- Adds a `@Transient boolean` to the entity. Two extra lifecycle methods per affected entity. Slightly more code; the alternative is silent data loss, so we accept it.
- Easy to forget on future similar entities. Mitigation: when reviewing PRs that add an entity with manually-assigned `@Id`, ask "does this need `Persistable<UUID>`?". Eventually we will codify that with an ArchUnit test.

**Neutral**
- Spring Data already supports this contract; we are using the framework as intended rather than fighting it.

## Alternatives considered

- **Switch to `@GeneratedValue` UUID.** Rejected: we need the UUID at construction time for audit-event emission *before* the persist completes. Generated UUIDs come back from the database after insert.
- **Use `Long` auto-increment instead of UUID.** Rejected: UUIDs are the wire format clients see; changing them is a public API break. They also fix a horizontal-scaling issue we have not had to solve yet (no auto-increment contention across replicas).
- **Always call `entityManager.persist()` explicitly.** Rejected: Spring Data `save()` is used in many places; auditing every call site is fragile. The `Persistable` contract fixes it at the entity, where the invariant lives.
- **Custom Hibernate `IdentifierGenerator`.** Rejected: more moving parts than the `Persistable` flag for the same effect.

## References

- Parent `CHANGELOG.md` `[2026-05-04]` operator-day entry — full bug timeline.
- `identity-core-api/CHANGELOG.md` `PR #71` — code-level detail.
- `identity-core-api/CLAUDE.md` "2026-05-04 highlights" — operator note.
- Spring Data Reference, "Detecting If an Entity Is New".
- Hibernate User Guide, "Persistable".
