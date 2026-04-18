# FIVUCSAS — Security Incidents Log

Tracking known credential leaks, exposure incidents, and remediation status. Newest first.

---

## #29836028 — Android keystore password exposed (Generic Password)

| Field | Value |
|-------|-------|
| Detector | GitGuardian |
| Repository | `Rollingcat-Software/client-apps` (public) |
| Commit introducing | `db18fa7` — *Phase 3.2 Widget Demo + 3.7 release keystore + 3.1 Dev Portal* |
| Tag reachable | `v3.0.0` |
| File | `androidApp/build.gradle.kts` |
| Secret value | `fivucsas2026` (used for both `storePassword` and `keyPassword`, alias `fivucsas`) |
| First leaked | 2026-04-04 |
| Detected | 2026-04-07 |
| Reported to maintainer | 2026-04-18 |
| Scaffolding fix | `cb6eab9` — 2026-04-18 — passwords now read from Gradle properties / env vars (`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEYSTORE_PATH`, `ANDROID_KEY_ALIAS`); CI workflow gates release signing behind `workflow_dispatch` + decodes keystore from `ANDROID_KEYSTORE_BASE64` secret into `$RUNNER_TEMP` with post-step wipe |
| Rotation | **PENDING — user action** |
| Assignee | Ahmet (has the `keystore/release.jks` file locally) |
| GitGuardian status | **Triggered** — to be marked resolved after rotation confirmed |

### Blast-radius assessment

The leaked password protected `keystore/release.jks`, which signs Play Store + sideloaded APKs for the FIVUCSAS mobile app. The `.jks` file itself is **not** in the repo (`.gitignore` has `*.jks` + `keystore/`), so an attacker needs both (a) the keystore file and (b) the password. The password alone is therefore not immediately weaponisable — but Play App Signing (if enrolled) re-signs uploads, which reduces impact; if self-signed distribution is in use anywhere, an attacker who obtains the `.jks` (via a device/laptop compromise) can now sign trojaned APKs indistinguishable from the legitimate app.

### Required remediation (one session, ~15 min)

```bash
# 1. Rotate store + key passwords on the local keystore
cd /path/to/release.jks/parent
keytool -storepasswd -keystore release.jks
# enter old password: fivucsas2026
# enter new password: <strong-random-pass-1>

keytool -keypasswd -alias fivucsas -keystore release.jks
# enter keystore password: <strong-random-pass-1>
# enter old key password: fivucsas2026
# enter new key password: <strong-random-pass-2>

# 2. Verify the key still signs
keytool -list -v -keystore release.jks -alias fivucsas
# should show the same SHA-1 + SHA-256 fingerprints as before

# 3. Base64 encode the rotated JKS for CI
base64 -w0 release.jks > release.jks.b64
# copy contents to GitHub → Rollingcat-Software/client-apps → Settings → Secrets and variables → Actions

# 4. Add/update three secrets
#    ANDROID_KEYSTORE_BASE64   = <contents of release.jks.b64>
#    ANDROID_KEYSTORE_PASSWORD = <strong-random-pass-1>
#    ANDROID_KEY_PASSWORD      = <strong-random-pass-2>
#    (ANDROID_KEY_ALIAS = fivucsas — set once, stays static)

# 5. Trigger a signed release build
gh workflow run android-build.yml -f build_type=release

# 6. Securely dispose of the base64 file
shred -u release.jks.b64

# 7. Mark GitGuardian incident #29836028 as resolved
#    https://dashboard.gitguardian.com/workspace/.../incidents/29836028
```

### Why we are not rewriting git history

History rewrite via `git filter-repo` would touch every commit since `db18fa7` (dozens), change every SHA downstream, break all existing clones + CI + any tag references, and force every contributor to re-clone. GitHub's cached views can persist for weeks and we have no control over forks. **Rotation makes the old password dead**, which is the primary defence anyway. Residual historical exposure of a *dead* password is acceptable risk. Push-protection + secret-scanning on `main` prevents recurrence.

### Rotation cadence

Per `client-apps/docs/RELEASE.md`: every 6 months or immediately on laptop/account compromise, employee offboarding, or leak re-detection.

---

## Related Phase C items (Wave 0 ops hardening — pending user sign-off)

`.env.prod` across identity-core-api, web-app, FIVUCSAS parent contains live DB / Redis / JWT signing key / Twilio / biometric API / Hostinger SMTP creds. These are committed in history. Rotation plan in `ROADMAP.md` Phase C1–C5.

This is a **separate** incident class from the keystore leak above — but needs the same playbook (rotate → scaffold env-var reads → mark GitGuardian incidents resolved).

Known constraint: JWT signing-key rotation invalidates every active session → signs every user out. Requires a scheduled maintenance window + status.fivucsas.com announcement.
