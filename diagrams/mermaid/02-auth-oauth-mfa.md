# FIVUCSAS — Authentication / OAuth2 / OIDC / MFA / OTP Flows

GitHub-renderable Mermaid diagrams, grounded in the real code:

- `identity-core-api/.../controller/AuthController.java` — `/auth/login`, `/auth/mfa/step`, `/auth/mfa/send-otp`, `/auth/login/preflight`, `/auth/login/begin`, `/auth/login-config`
- `application/service/AuthenticateUserService.java` — legacy password login + config-driven Layer-1 + MFA-session creation
- `application/service/mfa/VerifyMfaStepService.java` — the N-step MFA engine
- `application/service/OAuth2Service.java` + `controller/OAuth2Controller.java` — `/oauth2/authorize`, `/authorize/complete`, `/oauth2/token`, PKCE `validateAuthorizeRequest`
- `security/JwtService.java` (RS256 prod, `aud`/`iss` pinned), `service/RefreshTokenService.java` (rotation + `RefreshTokenFamilyRevoker`)
- `infrastructure/otp/OtpService.java` (NIST 5-strike), `infrastructure/totp/TotpService.java` (RFC 6238 + replay marker), `infrastructure/webauthn/WebAuthnService.java`
- `controller/QrController.java`, `controller/ApproveLoginController.java`, `controller/DeviceController.java` (WebAuthn / passkey)
- SDK: `verify-widget/html/fivucsas-auth.js` (`loginRedirect` → S256 → `handleRedirectCallback` → `/oauth2/token`)

**Honesty invariants baked into these diagrams:**
- PKCE **S256 is mandatory** for public clients (`OAuth2Controller.validateAuthorizeRequest`); `plain` is rejected for public clients.
- Access + ID tokens are **RS256** in prod (`JwtService.assertProdAlgoIsRs256`), carry pinned `iss` + `aud`.
- Refresh-token **reuse triggers whole-family revocation** in a `REQUIRES_NEW` transaction (survives the rollback-on-throw).
- Authorization codes are **single-use**, 10-minute TTL in Redis; the MFA session is **consumed + deleted** when minting the code.

---

## 1. HERO — OIDC "Login with FIVUCSAS" full round-trip (redirective, hosted login)

The primary integration mode. The tenant app uses the SDK (`FivucsasAuth.loginRedirect`) which generates a PKCE verifier/challenge (S256), `state` (CSRF) and `nonce` (OIDC replay), sends the browser to `/oauth2/authorize?display=page`, which 302-redirects to `verify.fivucsas.com/login` (the hosted surface). The example shows **Marmara's 2-step flow: PASSWORD then EMAIL_OTP**. After MFA completes, the hosted page trades the completed `MfaSession` for a single-use auth code at `/oauth2/authorize/complete`, the browser returns to the tenant with `?code&state`, and the SDK exchanges the code (with `code_verifier`) at `/oauth2/token`.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as Tenant App
    participant SDK as FIVUCSAS SDK<br/>(fivucsas-auth.js)
    participant Verify as verify.fivucsas.com<br/>(hosted login)
    participant API as api.fivucsas.com<br/>(/api/v1)

    User->>App: Click "Login with FIVUCSAS"
    App->>SDK: loginRedirect({redirectUri, scope})
    Note over SDK: verifier = random(32)<br/>challenge = base64url(SHA-256(verifier))  (S256)<br/>state = random(32), nonce = random(32)<br/>sessionStorage: pkce / state / nonce / redirect_uri
    SDK->>API: GET /oauth2/authorize?client_id&redirect_uri<br/>&response_type=code&scope=openid profile email<br/>&state&nonce&code_challenge&code_challenge_method=S256<br/>&display=page&ui_locales
    Note over API: validateClient(client_id, redirect_uri) exact-match<br/>validateScopes() · display=page ⇒ hosted redirect
    API-->>SDK: 302 Location: verify.fivucsas.com/login?...(all params)
    SDK->>Verify: browser follows redirect

    Verify->>API: GET /auth/login-config?clientId=...
    Note over API: resolve tenant via oauth2_clients →<br/>Layer-1 methods + step count (engineActive)
    API-->>Verify: { layer1:[PASSWORD], totalSteps:2, ... }
    Verify-->>User: Render Marmara login screen (step 1/2)

    rect rgb(235,245,255)
    Note over User,API: Step 1 — PASSWORD (Layer-1)
    User->>Verify: email + password
    Verify->>API: POST /auth/login { email, password, clientId }
    Note over API: AuthenticateUserService.execute()<br/>tenant ACTIVE? lockout? tenant-lock?<br/>verify password → create MfaSession(step=2,<br/>completed=[PASSWORD], clientId-bound, TTL 10m)
    API-->>Verify: 200 { mfaSessionToken, totalSteps:2,<br/>currentStep:2, availableMethods:[EMAIL_OTP] }
    end

    rect rgb(235,255,240)
    Note over User,API: Step 2 — EMAIL_OTP
    Verify->>API: POST /auth/mfa/send-otp { sessionToken, method:EMAIL_OTP }
    API->>User: 📧 6-digit code (5-min TTL)
    User->>Verify: enter code
    Verify->>API: POST /auth/mfa/step { sessionToken, method:EMAIL_OTP, data:{code} }
    Note over API: VerifyMfaStepService: lock row, account-guard,<br/>method-permitted-for-step, OTP validate (5-strike)<br/>advanceStep → allStepsCompleted
    API-->>Verify: 200 { status:AUTHENTICATED, ... }
    end

    Verify->>API: POST /oauth2/authorize/complete<br/>{ mfaSessionToken, clientId, redirectUri, scope,<br/>state, nonce, codeChallenge, codeChallengeMethod }
    Note over API: session completed & not consumed?<br/>clientId binding matches? PKCE S256 + tenant guard<br/>consumeMfaSessionAndMintCode (consume+mint+DELETE, atomic)
    API-->>Verify: 200 { code, redirect_uri, state }
    Verify-->>SDK: browser → tenant redirect_uri?code=...&state=...

    App->>SDK: handleRedirectCallback()
    Note over SDK: state === stored state? (CSRF)<br/>read code_verifier from sessionStorage
    SDK->>API: POST /oauth2/token (x-www-form-urlencoded)<br/>grant_type=authorization_code, code, redirect_uri,<br/>client_id, code_verifier
    Note over API: code single-use (Redis del) · client_id+redirect_uri match<br/>PKCE: SHA-256(verifier)==stored challenge<br/>mint RS256 access_token + id_token (iss/aud/nonce/sub)
    API-->>SDK: 200 { access_token, id_token, token_type, expires_in, scope }
    Note over SDK: verify id_token.nonce === stored nonce (replay guard)<br/>decode sub/email/name/amr · optional GET /oauth2/userinfo
    SDK-->>App: { success, userId, email, accessToken, idToken, completedMethods }
    App-->>User: Logged in ✅
```

**Caption.** The hero round-trip: PKCE S256 throughout, `state` for CSRF, `nonce` echoed into the id_token and verified client-side, single-use authorization code, RS256 tokens. The hosted page never sees the tenant's `code_verifier` — only the SDK does, at `/oauth2/token`.

---

## 2. N-step MFA engine

### 2a. Sequence — `POST /auth/mfa/step` orchestration (`VerifyMfaStepService`)

Every step posts `{ sessionToken, method, data }`. The service pessimistically locks the session row, enforces account state + tenant method policy + per-step method binding, dispatches to the per-method `VerifyMfaStepHandler`, accumulates RFC 8176 `amr`, and **only mints the JWT on the final step**.

```mermaid
sequenceDiagram
    autonumber
    participant C as Client (hosted/widget)
    participant Ctrl as AuthController<br/>/auth/mfa/step
    participant Svc as VerifyMfaStepService
    participant H as VerifyMfaStepHandler<br/>(per method)
    participant Guard as LoginAccountStateGuard
    participant DB as mfa_sessions (locked row)

    C->>Ctrl: POST /auth/mfa/step { sessionToken, method, data }
    Ctrl->>Svc: execute(VerifyMfaStepRequest)
    Svc->>DB: findBySessionTokenForUpdate (pessimistic lock)
    alt missing / expired / completed
        Svc-->>Ctrl: 401 invalid-or-expired / 400 already-completed
    end
    Svc->>Guard: enforceLoginAllowed(user) — 423 locked / 403 not-active
    Svc->>Svc: tenantAuthMethodPolicy.isLoginMethodAllowedForTenant?
    Svc->>Svc: method ∈ current-step permitted set? (bind to step)
    alt method already used elsewhere & not expected here
        Svc-->>Ctrl: 409 METHOD_ALREADY_USED
    end
    alt data.action == "challenge" (WebAuthn 2-phase)
        Svc->>H: verify() → CHALLENGE
        H-->>Svc: challengeResponse
        Svc-->>Ctrl: 200 passthrough(challenge)
    else verification
        Svc->>H: verify(session, user, data)
        alt invalid
            Svc->>Guard: recordFailedAttempt() (REQUIRES_NEW — survives rollback)
            Svc-->>Ctrl: 401 { status:FAILED, currentStep, completedMethods }
        else valid
            Svc->>Guard: recordSuccess() (reset strike counter)
            Svc->>DB: addCompletedMethod + advanceStep + save
            alt all steps complete
                Note over Svc: amr = map(completedMethods) RFC 8176<br/>mint RS256 access_token + refresh token
                Svc-->>Ctrl: 200 { status:AUTHENTICATED, accessToken, refreshToken, user }
            else more steps
                Svc-->>Ctrl: 200 { status:STEP_COMPLETED, currentStep, availableMethods }
            end
        end
    end
    Ctrl-->>C: HTTP (OK / 400 / 401 / 409)
```

### 2b. State — the MFA session lifecycle (`mfa_sessions`)

```mermaid
stateDiagram-v2
    [*] --> PENDING : AuthenticateUserService creates MfaSession<br/>(currentStep, totalSteps, TTL 10m)
    PENDING --> STEP_N : /auth/mfa/step valid → advanceStep()
    STEP_N --> STEP_N : valid intermediate step (currentStep++)
    STEP_N --> STEP_N : invalid factor → recordFailedAttempt (no advance)
    PENDING --> FAILED : invalid factor
    STEP_N --> COMPLETED : allStepsCompleted() → complete() → mint JWT
    PENDING --> LOCKED : account 5-strike lock (423) / cancelled
    STEP_N --> LOCKED : account 5-strike lock (423) / DELETE /mfa/session
    PENDING --> EXPIRED : expiresAt passed (deleted on next touch)
    STEP_N --> EXPIRED : expiresAt passed
    COMPLETED --> CONSUMED : /oauth2/authorize/complete mints code,<br/>session consumed + deleted (single-use)
    COMPLETED --> [*]
    CONSUMED --> [*]
    FAILED --> [*]
    LOCKED --> [*]
    EXPIRED --> [*]
```

**Caption.** The session starts `PENDING` at the first unsatisfied step (step 2 when PASSWORD is the verified Layer-1, step 1 for identifier-first). Each valid step advances `currentStep`; the final step flips to `COMPLETED` and mints the JWT (widget) or is later `CONSUMED` by `/oauth2/authorize/complete` (hosted). Lockout (5 strikes / 15 min) and expiry (10 min) are terminal.

---

## 3. OTP factors — Email OTP, SMS OTP (Twilio Verify), TOTP (RFC 6238)

### 3a. Email OTP (`OtpService`, Redis-backed, NIST 5-strike)

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant API as AuthController
    participant OTP as OtpService (Redis)
    participant Mail as EmailService (SMTP)

    C->>API: POST /auth/mfa/send-otp { sessionToken, method:EMAIL_OTP }
    API->>OTP: generate("2fa-login:<userId>")
    Note over OTP: 6-digit, 5-min TTL · clears stale :attempts counter
    OTP-->>API: code
    API->>Mail: sendOtp(email, code)
    Mail-->>C: 📧 verification code
    C->>API: POST /auth/mfa/step { sessionToken, method:EMAIL_OTP, data:{code} }
    API->>OTP: validateWithResult(key, code)
    alt match
        OTP-->>API: VALID (deletes code + counter)
        API-->>C: 200 STEP_COMPLETED / AUTHENTICATED
    else mismatch (< 5)
        OTP-->>API: INVALID (remaining = 5 - attempts)
        API-->>C: 401 Verification failed
    else 5th wrong guess
        OTP-->>API: EXHAUSTED (code burned)
        API-->>C: 429 OTP_ATTEMPTS_EXHAUSTED + Retry-After (resend)
    end
```

### 3b. SMS OTP (Twilio Verify — `VerifiableSmsService`, no local code store)

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant API as AuthController
    participant SMS as SmsService
    participant Twilio as Twilio Verify API

    C->>API: POST /auth/mfa/send-otp { sessionToken, method:SMS_OTP }
    Note over API: phone on file? key = "2fa-sms:<userId>"
    alt VerifiableSmsService (Twilio Verify)
        API->>Twilio: start verification (Twilio owns code + retries)
        Twilio-->>C: 📱 SMS code
    else generic SmsService
        API->>SMS: sendOtp(phone, OtpService.generate(...))
        SMS-->>C: 📱 SMS code
    end
    C->>API: POST /auth/mfa/step { sessionToken, method:SMS_OTP, data:{code} }
    alt VerifiableSmsService
        API->>Twilio: verifyCode(phone, code)
        Twilio-->>API: approved / denied
    else generic
        API->>SMS: otpService.validateWithResult("2fa-sms:<userId>", code)
        Note over SMS: NIST 5-strike → OtpAttemptsExhaustedException → 429
    end
    API-->>C: 200 (advance/auth) or 401 / 429
```

### 3c. TOTP (RFC 6238 — `TotpService`, SHA-1 / 30s / 6-digit + S13 replay marker)

```mermaid
sequenceDiagram
    autonumber
    participant C as Client (authenticator app)
    participant API as AuthController / MFA step
    participant T as TotpService
    participant Redis as Redis (totp:used:*)

    Note over C,API: Enrollment once: generateSecret() → otpauth:// QR<br/>secret stored encrypted (enc:v1) + Redis cache
    C->>API: POST /auth/mfa/step { method:TOTP, data:{code} }
    API->>API: resolveTotpSecret(user) — Redis cache → DB decryptIfNeeded
    API->>T: verifyCodeForUser(userId, secret, code)
    Note over T: findMatchingTimeStep over [-1,+1] drift (±30s)<br/>SHA1, 6 digits, period 30 (RFC 6238)
    alt no matching step
        T-->>API: false (invalid)
    else matched step
        T->>Redis: SET totp:used:<userId>:<step> 1 EX 120 NX (atomic)
        alt first use
            Redis-->>T: set ✔
            T-->>API: true
        else replay of same code in-window
            Redis-->>T: not set
            T-->>API: false (S13 replay rejected)
        end
    end
    API-->>C: 200 (advance/auth) or 401
```

**Caption.** Email OTP and the generic SMS path enforce the NIST 800-63B 5-strike counter in Redis (5th wrong guess → 429 + Retry-After). Twilio Verify owns its own code lifecycle. TOTP is RFC 6238 (SHA-1, 30s step, ±1 drift); login/MFA verification additionally writes a short-TTL `totp:used:(userId,step)` marker so a captured code cannot be replayed inside its ~90s window.

---

## 4. Cross-device — QR-code login & Approve-login (number-matching, Redis-backed)

### 4a. QR-code login (`QrController` + `QrSessionService`)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Desk as Desktop (browser)
    participant API as api.fivucsas.com
    participant Phone as Phone (authenticated app)

    Desk->>API: POST /auth/qr/session { platform }
    API-->>Desk: { sessionId, qr token, status:PENDING } (Redis, TTL)
    Desk->>Desk: render QR · begin polling
    loop poll
        Desk->>API: GET /auth/qr/session/{sessionId}
        API-->>Desk: { status:PENDING }
    end
    User->>Phone: scan QR (already logged in on phone)
    Phone->>API: POST /auth/qr/session/{sessionId}/approve (Bearer)
    Note over API: bind approver userId → session status APPROVED
    API-->>Phone: { status:APPROVED }
    Desk->>API: GET /auth/qr/session/{sessionId}
    API-->>Desk: { status:APPROVED, tokens / mfaSessionToken }
    Desk-->>User: Logged in ✅
    Note over Desk,API: As an MFA step instead:<br/>/auth/mfa/qr-generate → /auth/mfa/step {method:QR_CODE, data:{token}}<br/>(QrCodeService.validateToken)
```

### 4b. Approve-login — number matching (`ApproveLoginController` + `ApproveLoginService`)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant New as New device (anonymous)
    participant API as api.fivucsas.com
    participant Approver as Trusted device (authenticated)

    New->>API: POST /auth/approve-login/session { email }
    Note over API: matchNumber = "%02d" (ZERO-PADDED STRING e.g. "07")<br/>store in Redis · unknown email → decoy session (no oracle)
    API-->>New: { sessionId, matchNumber:"07", status:PENDING }
    New-->>User: show "07", poll
    Approver->>API: GET /auth/approve-login/pending (Bearer)
    API-->>Approver: [ { sessionId, matchNumber:"07" } ]
    User->>Approver: confirm the number shown is "07"
    Approver->>API: POST /auth/approve-login/session/{id}/decide<br/>{ decision:"allow", matchNumber:"07" } (Bearer)
    Note over API: session belongs to approver? matchNumber equals stored?<br/>allow → mint tokens (like QR approve) · deny → close
    API-->>Approver: { status:APPROVED }
    loop poll
        New->>API: GET /auth/approve-login/session/{sessionId}
    end
    API-->>New: { status:APPROVED, tokens }
    New-->>User: Logged in ✅
```

**Caption.** Both cross-device flows are Redis-backed poll loops. The new/desktop device starts an anonymous session; an already-authenticated device approves it. Approve-login adds a two-digit **`matchNumber` (a zero-padded STRING, e.g. `"07"`)** the user must match between devices, and returns a **decoy session for unknown emails** so it is not an account-existence oracle.

---

## 5. WebAuthn / Passkey / Fingerprint (`DeviceController` + `WebAuthnService`)

### 5a. Registration (attestation) + Authentication (assertion) + usernameless passkey

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Br as Browser (navigator.credentials)
    participant API as DeviceController (/webauthn)
    participant WAS as WebAuthnService (Redis challenge)

    rect rgb(235,245,255)
    Note over User,WAS: Registration — create a discoverable passkey
    Br->>API: POST /webauthn/register-options (Bearer)
    Note over API: residentKey=required, UV=required,<br/>userHandle = encode(userId), excludeCredentials
    API->>WAS: generateChallenge(sessionId) → Redis (5m TTL)
    API-->>Br: { sessionId, challenge, rpId, userHandle, ... }
    Br->>User: navigator.credentials.create() → attestation
    Br->>API: POST /webauthn/register { sessionId, credentialId, publicKey, clientDataJSON }
    API->>WAS: validateRegistrationChallenge(sessionId, clientDataJSON)
    Note over WAS: type=="webauthn.create", challenge match,<br/>origin ∈ allowlist (exact-match) · consume challenge
    API-->>Br: 201 { credentialId } (discoverable, userHandle stored)
    end

    rect rgb(235,255,240)
    Note over User,WAS: Authentication — assertion (email-bound)
    Br->>API: POST /webauthn/authenticate-options { email }
    API->>WAS: generateChallenge(sessionId)
    API-->>Br: { sessionId, challenge, allowCredentials:[creds] }
    Br->>User: navigator.credentials.get() → assertion
    Br->>API: POST /webauthn/authenticate { sessionId, credentialId,<br/>authenticatorData, clientDataJSON, signature }
    API->>WAS: verifyAssertion(...)
    Note over WAS: clientData type=="webauthn.get" + challenge + origin allowlist<br/>authData: rpIdHash==SHA-256(rpId), UP flag set<br/>ECDSA SHA256withECDSA verify · signCount > stored (clone check)
    WAS-->>API: true
    API-->>Br: session / tokens
    end

    rect rgb(255,245,235)
    Note over User,WAS: Usernameless passkey — EMPTY allowCredentials
    Br->>API: POST /webauthn/passkey/authenticate-options (no email)
    API-->>Br: { sessionId, challenge, allowCredentials:[] }
    Br->>User: navigator.credentials.get() (platform offers any resident passkey)
    Br->>API: POST /webauthn/passkey/authenticate { ..., userHandle }
    Note over API: resolve user from userHandle · verify assertion + signCount<br/>bridge passkey as Layer-1 → tokens or MFA-pending
    API-->>Br: tokens / mfaSessionToken
    end
```

**Caption.** FINGERPRINT is delivered as a WebAuthn platform authenticator (no separate biometric path). Registration produces a **discoverable** passkey (resident key + UV required) carrying a `userHandle = encode(userId)`. The email-bound assertion sends a populated `allowCredentials`; the **usernameless passkey** flow sends an **empty `allowCredentials`** and resolves the account from the asserted `userHandle`. Every assertion validates challenge freshness, exact-match origin allowlist, RP-ID hash, the UP flag, the ECDSA signature, and a monotonic sign-counter (clone detection).

---

## 6. Refresh-token rotation + reuse detection (`RefreshTokenService` + `RefreshTokenFamilyRevoker`)

### 6a. Sequence — happy rotation, then a stolen-token replay kills the family

Wire format is `<id>.<secret>`; only `sha256(secret)` is stored (`token_secret_hash`, V55/V60 — plaintext column dropped). Every token from one login shares a `family_id` (V50).

```mermaid
sequenceDiagram
    autonumber
    participant Client
    participant API as AuthController /auth/refresh
    participant RTS as RefreshTokenService
    participant Rev as RefreshTokenFamilyRevoker<br/>(REQUIRES_NEW)
    participant DB as refresh_tokens

    Note over Client,DB: Login minted R1 (family F, id.secret · only sha256 stored)
    Client->>API: POST /auth/refresh { refreshToken: R1 }
    API->>RTS: findByToken(R1) → verifyExpiration(R1)
    RTS->>DB: lookup id, constant-time compare sha256(secret)
    alt R1 valid & not revoked
        RTS->>DB: revoke R1 · mint R2 in SAME family F
        RTS-->>API: R2 (+ new access token)
        API-->>Client: 200 { accessToken, refreshToken: R2 }
    end

    Note over Client,DB: Attacker replays the already-rotated R1
    Client->>API: POST /auth/refresh { refreshToken: R1 (revoked) }
    API->>RTS: verifyExpiration(R1)
    RTS->>RTS: R1.isRevoked() == true → REUSE DETECTED
    RTS->>Rev: revokeFamily(F) (separate committed tx)
    Rev->>DB: revoke EVERY token in family F (incl. live R2)
    RTS->>RTS: throw TokenRevokedException (rolls back outer tx ·<br/>family revoke already committed)
    API-->>Client: 401 — whole family dead, user must re-login
```

### 6b. Flowchart — rotation + reuse decision

```mermaid
flowchart TD
    A[POST /auth/refresh with token T] --> B{well-formed id.secret<br/>& sha256 matches row?}
    B -- no --> X[401 TokenRevokedException<br/>not found / wrong secret]
    B -- yes --> C{T expired?}
    C -- yes --> D[delete T → 401 TokenExpired]
    C -- no --> E{T revoked?}
    E -- no --> F[revoke T<br/>mint T' in same family<br/>→ 200 access + T']
    E -- yes --> G[REUSE DETECTED<br/>RFC 6749 §10.4]
    G --> H[familyRevoker.revokeFamily<br/>REQUIRES_NEW — survives rollback]
    H --> I[audit REFRESH_TOKEN_REUSE_DETECTED]
    I --> J[401 — entire family revoked]
```

**Caption.** Normal refresh rotates `R1 → R2` (old revoked, successor inherits the family). Presenting an already-revoked `R1` is **reuse**: the entire rotation family — including the legitimate `R2` — is revoked in a **`REQUIRES_NEW`** transaction so it commits even though the request itself throws and rolls back. A wrong secret for a real id is treated as "not found" (404-shaped), **not** reuse — only an explicitly revoked-and-presented token triggers family revocation.

---

## 7. Account lockout + overall login activity

### 7a. Account lockout — 5 strikes → 423, 15-minute window (`LoginAccountStateGuard`)

```mermaid
flowchart TD
    A[Login factor submitted] --> B{account locked?}
    B -- yes --> C{lockedUntil passed?}
    C -- yes --> D[auto-clear lock<br/>reset counter] --> E
    C -- no --> Z[423 AccountLocked<br/>+ remaining seconds]
    B -- no --> E{account ACTIVE?}
    E -- no --> Y[403 AccountNotActive<br/>SUSPENDED / INACTIVE]
    E -- yes --> F{factor valid?}
    F -- yes --> G[recordSuccess<br/>reset failed_login_attempts] --> H[proceed / mint token]
    F -- no --> I[recordFailedAttempt<br/>REQUIRES_NEW — survives rollback]
    I --> J{attempts >= 5?}
    J -- no --> K[401 invalid<br/>attempt n/5]
    J -- yes --> L[lockAccount 15 min] --> M[423 AccountLocked]
```

### 7b. Overall login activity — picking the path (legacy vs config-driven vs cross-device)

```mermaid
flowchart TD
    Start([User wants to log in]) --> Mode{Integration mode}

    Mode -- Redirective OIDC --> R1[SDK loginRedirect: PKCE S256 + state + nonce]
    R1 --> R2[/oauth2/authorize display=page → verify.fivucsas.com/]
    R2 --> Cfg[GET /auth/login-config → Layer-1 + steps]

    Mode -- Identifier-first --> P1[POST /auth/login/preflight email+clientId]
    P1 --> P2{tenant eligible?}
    P2 -- no --> P3[403 TENANT_MISMATCH<br/>'not a tenant member']
    P2 -- yes --> Cfg

    Mode -- Cross-device --> XD[QR / Approve-login session<br/>approved on trusted device] --> Done

    Cfg --> L1{Layer-1 method}
    L1 -- PASSWORD --> PW[POST /auth/login → AuthenticateUserService<br/>guard: tenant ACTIVE, lockout, tenant-lock, verify password]
    L1 -- identifier-first<br/>FACE/TOTP/EMAIL_OTP/... --> IF[POST /auth/login/begin<br/>open MfaSession at step 1]

    PW --> S{more steps?}
    IF --> S
    S -- no (single factor) --> Tok[mint RS256 access + refresh]
    S -- yes --> MFA[loop POST /auth/mfa/step<br/>VerifyMfaStepService until COMPLETED]
    MFA --> Hosted{hosted OIDC?}
    Hosted -- yes --> AC[POST /oauth2/authorize/complete → code]
    AC --> TK[POST /oauth2/token + code_verifier → tokens]
    Hosted -- no --> Tok
    TK --> Done([Authenticated])
    Tok --> Done
```

**Caption.** The strike counter and account-status gate are path-independent (`LoginAccountStateGuard`) and run on **both** the legacy `/auth/login` path and the live `/auth/mfa/step` engine; the 5th failed factor locks the account for 15 minutes (HTTP 423). The activity overview shows the three entry modes (redirective OIDC, identifier-first, cross-device) converging on the same MFA engine and, for hosted OIDC, the `authorize/complete → token` code exchange.
