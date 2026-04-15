# SMS OTP Activation Plan — Twilio Integration

**Project**: FIVUCSAS Identity Core API  
**Date**: 2026-04-05  
**Status**: Infrastructure built, awaiting Twilio credentials  
**Author**: Ahmet Abdullah Gultekin

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Current State](#2-current-state)
3. [Activation Steps](#3-activation-steps)
4. [Alternative: Twilio Verify API](#4-alternative-twilio-verify-api)
5. [Future: Firebase Phone Auth](#5-future-firebase-phone-auth)
6. [Testing Plan](#6-testing-plan)
7. [Cost Estimation](#7-cost-estimation)

---

## 1. Architecture Overview

SMS OTP follows the project's hexagonal architecture (Ports and Adapters). The application
layer never touches Twilio directly — it depends only on the `SmsService` output port.

```
                        FIVUCSAS Identity Core API
    ┌──────────────────────────────────────────────────────────────┐
    │                                                              │
    │   ┌─────────────────────────────────────────────────────┐    │
    │   │              APPLICATION LAYER                       │    │
    │   │                                                     │    │
    │   │   OtpController ──> OtpService (Redis)              │    │
    │   │        │                  │                          │    │
    │   │        │            generate / validate              │    │
    │   │        │                  │                          │    │
    │   │   SmsOtpAuthHandler ─────┘                          │    │
    │   │        │                                            │    │
    │   │        │  depends on                                │    │
    │   │        ▼                                            │    │
    │   │   ┌─────────────┐                                   │    │
    │   │   │ SmsService  │  ◄── OUTPUT PORT (interface)      │    │
    │   │   └──────┬──────┘                                   │    │
    │   └──────────┼──────────────────────────────────────────┘    │
    │              │                                                │
    │   ┌──────────┼──────────────────────────────────────────┐    │
    │   │          │       INFRASTRUCTURE LAYER                │    │
    │   │          │                                           │    │
    │   │    ┌─────┴──────────────┐  ┌─────────────────────┐  │    │
    │   │    │  TwilioSmsService  │  │   NoOpSmsService    │  │    │
    │   │    │  (ADAPTER)         │  │   (ADAPTER)         │  │    │
    │   │    │                    │  │                     │  │    │
    │   │    │  sms.enabled=true  │  │  sms.enabled=false  │  │    │
    │   │    │  Sends real SMS    │  │  Logs OTP to stdout │  │    │
    │   │    └────────┬───────────┘  └─────────────────────┘  │    │
    │   │             │                                        │    │
    │   └─────────────┼────────────────────────────────────────┘    │
    │                 │                                              │
    └─────────────────┼──────────────────────────────────────────────┘
                      │
                      ▼
               ┌──────────────┐
               │  Twilio API  │  (external service)
               │  REST / SDK  │
               └──────────────┘
```

### Key Design Decisions

- **SmsService** is the output port (interface). The application layer only knows this contract.
- **TwilioSmsService** is the concrete adapter, activated via `@ConditionalOnProperty(name = "sms.enabled", havingValue = "true")`.
- **NoOpSmsService** is the fallback adapter, active when `sms.enabled=false` (or missing). Logs OTP codes to stdout for development.
- **OtpService** handles code generation, storage (Redis with 5-minute TTL), and validation. It is transport-agnostic — the same service is used for email OTP and SMS OTP.
- Swapping Twilio for another SMS provider requires only a new adapter implementing `SmsService`. Zero changes to application or domain layers.

---

## 2. Current State

Everything is built. The only missing piece is **Twilio account credentials**.

### Files and Their Roles

| File | Layer | Role |
|------|-------|------|
| `infrastructure/sms/SmsService.java` | Output Port | Interface: `void sendOtp(String phoneNumber, String code)` |
| `infrastructure/sms/TwilioSmsService.java` | Adapter | Real Twilio SDK integration (Twilio Java SDK 10.1.0) |
| `infrastructure/sms/NoOpSmsService.java` | Adapter | Dev/test fallback, logs OTP to console |
| `infrastructure/otp/OtpService.java` | Service | 6-digit code generation, Redis storage, 5-min TTL, validate-and-consume |
| `application/service/handler/SmsOtpAuthHandler.java` | App Service | Multi-step auth handler for SMS_OTP method type |
| `controller/OtpController.java` | Input Adapter | REST endpoints: `POST /api/v1/otp/sms/send/{userId}`, `POST /api/v1/otp/sms/verify/{userId}` |
| `resources/application.yml` | Config | `sms.enabled`, `sms.twilio.account-sid`, `sms.twilio.auth-token`, `sms.twilio.from-number` |
| `pom.xml` | Build | `com.twilio.sdk:twilio:10.1.0` dependency |
| `scripts/setup-twilio.sh` | DevOps | Interactive script: writes credentials to `.env.prod`, restarts container |
| `test/.../SmsOtpAuthHandlerTest.java` | Test | 7 unit tests for SmsOtpAuthHandler (send, verify, edge cases) |
| `test/.../TwilioSmsServiceTest.java` | Test | 2 unit tests for NoOpSmsService configuration |
| `resources/db/migration/V16__auth_flow_system.sql` | DB | SMS_OTP registered as auth method type, seeded in auth_methods table |

### Current Behavior (sms.enabled=false)

1. User triggers SMS OTP via auth flow or `/api/v1/otp/sms/send/{userId}`.
2. OtpService generates a 6-digit code and stores it in Redis with 5-minute TTL.
3. NoOpSmsService receives the code and **logs it to stdout** (no SMS sent).
4. In production logs: `SMS disabled - OTP for +905551234567: 482901`.
5. Verification works normally via `/api/v1/otp/sms/verify/{userId}` against Redis.

---

## 3. Activation Steps

### 3.1 GitHub Student Developer Pack

1. Go to https://education.github.com/pack
2. Verify student status (Marmara University email or student ID).
3. Once approved, navigate to **Twilio** in the partner list.
4. Click "Get access" to claim **$50 USD in Twilio credit**.

### 3.2 Twilio Account Setup

1. Sign up at https://www.twilio.com/try-twilio (use the GitHub Student Pack link for credit).
2. Verify your personal phone number (Twilio requires this for trial accounts).
3. From the **Twilio Console Dashboard** (https://console.twilio.com), note:
   - **Account SID** (starts with `AC`)
   - **Auth Token** (click "Show" to reveal)

### 3.3 Get a Twilio Phone Number

1. In Twilio Console, go to **Phone Numbers > Manage > Buy a Number**.
2. Select a number with **SMS capability** (US numbers are cheapest at $1.00/month).
3. For Turkey-originating messages, a US number works but the sender will show as a US number.
4. Note the number in **E.164 format**: `+1XXXXXXXXXX`.

> **Important**: Trial accounts can only send SMS to **verified phone numbers**. Add your
> test numbers at Console > Verified Caller IDs before testing. After upgrading to a paid
> account (or applying the $50 credit), this restriction is lifted.

### 3.4 Configure the Server

**Option A: Run the setup script (recommended)**

```bash
ssh deploy@116.203.222.213
cd /opt/projects/fivucsas
./scripts/setup-twilio.sh
```

The script will prompt for Account SID, Auth Token, and From Number, then write them to
`identity-core-api/.env.prod` and restart the container.

**Option B: Manual configuration**

Add these lines to `/opt/projects/fivucsas/identity-core-api/.env.prod`:

```env
# Twilio SMS OTP
SMS_ENABLED=true
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_FROM_NUMBER=+1XXXXXXXXXX
```

Then rebuild and restart:

```bash
cd /opt/projects/fivucsas/identity-core-api
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d identity-core-api
```

### 3.5 Verify Activation

Check the container logs for the initialization message:

```bash
docker logs identity-core-api --tail 20 | grep -i twilio
# Expected: "Twilio SMS service initialized with from-number: +1XXXXXXXXXX"
```

If you see `NoOpSmsService` in the logs instead, `SMS_ENABLED` is not reaching the container.
Verify with:

```bash
docker exec identity-core-api env | grep SMS
docker exec identity-core-api env | grep TWILIO
```

---

## 4. Alternative: Twilio Verify API

The current implementation uses the **Programmable Messaging API** (raw SMS). Twilio offers a
higher-level **Verify API** that handles OTP generation, delivery, rate limiting, retry logic,
and fraud detection out of the box.

### Why Upgrade

| Feature | Current (raw SMS) | Twilio Verify API |
|---------|-------------------|-------------------|
| OTP generation | Our OtpService (Redis) | Twilio-managed |
| Rate limiting | None (must build) | Built-in (5 attempts/10 min) |
| Retry on failure | None | Automatic fallback channels |
| Fraud detection | None | Twilio Fraud Guard |
| Delivery receipts | Not checked | Built-in status callbacks |
| Pricing | $0.0079/SMS segment | $0.05/verification (includes SMS cost) |
| International | Varies by country | Managed by Twilio |

### Recommendation

For a university project with low volume, the **current raw SMS approach is sufficient**.
However, if this were a production SaaS, upgrading to Verify API is strongly recommended for
the rate limiting and fraud detection alone.

### Code Changes for Twilio Verify API

Only the infrastructure adapter needs to change. The port stays the same.

**New adapter: `TwilioVerifySmsService.java`**

```java
package com.fivucsas.identity.infrastructure.sms;

import com.twilio.Twilio;
import com.twilio.rest.verify.v2.service.Verification;
import com.twilio.rest.verify.v2.service.VerificationCheck;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

/**
 * Twilio Verify API adapter.
 * Uses Twilio's managed OTP generation and delivery.
 *
 * Activate with: sms.provider=verify (vs sms.provider=raw for TwilioSmsService).
 *
 * NOTE: When using Verify API, OTP generation is handled by Twilio, not our OtpService.
 * The SmsService interface would need to be extended with a verify() method,
 * or a new VerifySmsService port should be created.
 */
@Service
@ConditionalOnProperty(name = "sms.provider", havingValue = "verify")
@Slf4j
public class TwilioVerifySmsService implements SmsService {

    @Value("${sms.twilio.account-sid}")
    private String accountSid;

    @Value("${sms.twilio.auth-token}")
    private String authToken;

    @Value("${sms.twilio.verify-service-sid}")
    private String verifyServiceSid;

    @PostConstruct
    void init() {
        Twilio.init(accountSid, authToken);
        log.info("Twilio Verify service initialized (SID: {})", verifyServiceSid);
    }

    @Override
    public void sendOtp(String phoneNumber, String code) {
        // NOTE: The 'code' parameter is ignored — Twilio Verify generates its own OTP.
        // This is a design trade-off to keep the SmsService interface unchanged.
        try {
            Verification verification = Verification.creator(
                    verifyServiceSid,
                    phoneNumber,
                    "sms"
            ).create();

            log.info("Twilio Verify sent to {} - SID: {}, status: {}",
                    phoneNumber, verification.getSid(), verification.getStatus());
        } catch (Exception e) {
            log.error("Twilio Verify failed for {}: {}", phoneNumber, e.getMessage());
            throw new RuntimeException("SMS verification delivery failed", e);
        }
    }

    /**
     * Verify a code using the Twilio Verify API.
     * This bypasses our Redis-based OtpService — Twilio manages the OTP lifecycle.
     *
     * NOTE: To use this, SmsOtpAuthHandler would need to call this method
     * instead of OtpService.validate(). Consider extending SmsService interface:
     *   boolean verifyOtp(String phoneNumber, String code);
     */
    public boolean verifyOtp(String phoneNumber, String code) {
        try {
            VerificationCheck check = VerificationCheck.creator(verifyServiceSid)
                    .setTo(phoneNumber)
                    .setCode(code)
                    .create();

            boolean approved = "approved".equals(check.getStatus());
            log.info("Twilio Verify check for {}: status={}", phoneNumber, check.getStatus());
            return approved;
        } catch (Exception e) {
            log.error("Twilio Verify check failed for {}: {}", phoneNumber, e.getMessage());
            return false;
        }
    }
}
```

**Interface extension (if adopting Verify API):**

```java
public interface SmsService {
    void sendOtp(String phoneNumber, String code);

    // Optional: server-side verification for Twilio Verify API
    default boolean verifyOtp(String phoneNumber, String code) {
        // Default: not supported (raw SMS adapters use OtpService + Redis)
        throw new UnsupportedOperationException("Use OtpService for verification");
    }
}
```

**Additional application.yml properties:**

```yaml
sms:
  provider: verify  # 'raw' for TwilioSmsService, 'verify' for TwilioVerifySmsService
  twilio:
    verify-service-sid: ${TWILIO_VERIFY_SERVICE_SID:}
```

**Setup in Twilio Console:**

1. Go to **Verify > Services** in the Twilio Console.
2. Create a new Verify Service (name: "FIVUCSAS Identity").
3. Copy the **Service SID** (starts with `VA`).
4. Add `TWILIO_VERIFY_SERVICE_SID=VAxxxxxxxx` to `.env.prod`.

---

## 5. Future: Firebase Phone Auth

### Why Firebase Phone Auth Is NOT a Good Fit

Firebase Phone Auth is designed for **client-side phone-based login** where Firebase controls
the entire authentication flow. This conflicts with FIVUCSAS's architecture:

| Concern | FIVUCSAS Requirement | Firebase Phone Auth |
|---------|---------------------|---------------------|
| OTP lifecycle | Server-controlled (Redis TTL, consume-on-use) | Firebase-controlled (client SDK) |
| Auth session | Managed by identity-core-api (AuthSession entity) | Firebase manages its own session |
| Multi-step flows | SMS OTP is one step in a configurable flow | Firebase is a standalone auth method |
| Token format | Our JWT with custom claims | Firebase ID Token (different format) |
| Backend verification | Our OtpService validates against Redis | Firebase Admin SDK verifies Firebase tokens |
| User store | PostgreSQL (users table, RLS) | Firebase Authentication user store |
| Tenant isolation | Multi-tenant with tenant_id scoping | No built-in multi-tenancy |

### When Firebase COULD Be Used

Firebase Phone Auth could serve as an **alternative adapter** for a simplified phone-based
login flow (not multi-step auth). The implementation would:

1. Create a `FirebasePhoneAuthAdapter` implementing a new `PhoneAuthService` port.
2. The client app calls Firebase SDK directly to get a Firebase ID Token.
3. The backend verifies the Firebase ID Token via Firebase Admin SDK.
4. Map the Firebase UID to a local user account.

This is a fundamentally different flow from SMS OTP within multi-step auth. It bypasses our
OtpService and SmsService entirely, acting as a standalone identity provider.

**Verdict**: Not recommended for FIVUCSAS. Twilio (raw or Verify API) is the correct choice
for server-controlled SMS OTP within hexagonal architecture. Firebase would introduce a
parallel auth system that doesn't integrate cleanly with the existing auth flow engine.

---

## 6. Testing Plan

### 6.1 Unit Tests (Already Passing)

| Test File | Tests | Status |
|-----------|-------|--------|
| `SmsOtpAuthHandlerTest.java` | 7 tests (send, verify valid/invalid, missing code, no user, no phone, method type) | PASSING |
| `TwilioSmsServiceTest.java` (SmsServiceConfigTest) | 2 tests (NoOp instanceof, no-throw) | PASSING |

### 6.2 Integration Test (Post-Activation)

After enabling Twilio, run this manual test sequence:

```bash
# 1. Login as admin to get JWT
TOKEN=$(curl -s -X POST https://api.fivucsas.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@fivucsas.com","password":"<ADMIN_PASSWORD>"}' \
  | jq -r '.token')

# 2. Ensure the target user has a phone number
# (set via user management or directly in DB)

# 3. Send SMS OTP
curl -X POST https://api.fivucsas.com/api/v1/otp/sms/send/{userId} \
  -H "Authorization: Bearer $TOKEN"
# Expected: {"success":true,"message":"OTP sent via SMS","expiresInSeconds":300}

# 4. Check your phone for the 6-digit code

# 5. Verify the OTP
curl -X POST https://api.fivucsas.com/api/v1/otp/sms/verify/{userId} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code":"XXXXXX"}'
# Expected: {"success":true,"message":"OTP verified successfully"}

# 6. Verify OTP is consumed (replay should fail)
curl -X POST https://api.fivucsas.com/api/v1/otp/sms/verify/{userId} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code":"XXXXXX"}'
# Expected: {"success":false,"message":"Invalid or expired OTP code"}
```

### 6.3 Multi-Step Auth Flow Test

1. Create an auth flow with SMS_OTP as a step (via Auth Flow Builder UI or API).
2. Start an auth session against that flow.
3. At the SMS_OTP step, send `{"action":"send"}` to trigger OTP delivery.
4. Submit the received code to complete the step.
5. Verify the session advances to the next step.

### 6.4 Edge Cases to Verify

- Invalid phone number format (non-E.164) returns Twilio error, caught by try-catch.
- OTP expires after 5 minutes (Redis TTL).
- User without phone number gets `400 Bad Request`.
- NoOpSmsService activates when `SMS_ENABLED=false` (rollback path).
- Twilio trial account: SMS to unverified numbers fails with clear error.

### 6.5 Container Health Check

```bash
# After activation, verify container is healthy
docker ps --filter name=identity-core-api --format "{{.Status}}"
# Expected: "Up X minutes (healthy)"

# Check Twilio initialization in logs
docker logs identity-core-api 2>&1 | grep -i "twilio"
# Expected: "Twilio SMS service initialized with from-number: +1XXXXXXXXXX"
```

---

## 7. Cost Estimation

### Twilio Pricing (as of 2026)

| Item | Cost |
|------|------|
| Phone number (US local) | $1.00/month |
| Outbound SMS (US to US) | $0.0079/segment |
| Outbound SMS (US to Turkey) | ~$0.0408/segment |
| Twilio Verify API | $0.05/successful verification |

### Budget: $50 GitHub Student Credit

**Scenario A: Raw SMS to Turkey (+90 numbers)**

| Item | Monthly | 12 Months |
|------|---------|-----------|
| Phone number | $1.00 | $12.00 |
| Remaining for SMS | - | $38.00 |
| SMS to Turkey at $0.0408 | ~93/month | ~931 total |

**Scenario B: Raw SMS to US (+1 numbers, development/testing)**

| Item | Monthly | 12 Months |
|------|---------|-----------|
| Phone number | $1.00 | $12.00 |
| Remaining for SMS | - | $38.00 |
| SMS to US at $0.0079 | ~481/month | ~4,810 total |

**Scenario C: Twilio Verify API**

| Item | Monthly | 12 Months |
|------|---------|-----------|
| Phone number | Not needed | $0 |
| Verify at $0.05/verification | - | $50.00 |
| Total verifications | ~83/month | ~1,000 total |

### Expected Usage

For a university project with a small user base (5-20 active users, demo presentations,
exam portal integration):

- **Development/testing**: ~50 SMS/month
- **Demo presentations**: ~10 SMS/event
- **Exam portal pilot**: ~100 SMS/semester

**Estimated monthly cost**: $3-5 (raw SMS) or $5-10 (Verify API).  
**$50 credit duration**: Easily lasts the entire academic year and beyond.

### Recommendation

Start with **raw SMS (TwilioSmsService)** to maximize the number of messages per dollar.
The existing implementation is ready — just add credentials. Upgrade to Verify API only if
rate limiting or fraud detection becomes necessary.

---

## Appendix: Quick Reference

```
# Activate SMS
./scripts/setup-twilio.sh

# Check status
./scripts/setup-twilio.sh --check

# Deactivate (rollback)
# Set SMS_ENABLED=false in .env.prod, restart container

# Logs
docker logs identity-core-api 2>&1 | grep -i sms
```

---

## Appendix: SMS Sender ID Branding (Turkey, +90)

**Status (2026-04-15)**: Twilio Verify SMS messages to Turkish numbers currently show **"TWVerify"** as the sender, not "FIVUCSAS". This is NOT a bug and cannot be fixed in code.

**Why**: "TWVerify" is Twilio's default shared alphanumeric sender for Verify routes in countries where no custom sender has been registered on the account. None of the following affect it:
- Verify Service "Friendly Name" (internal label only, never shown to end users)
- "Branded Sender ID" (a separate product — Branded Communications / RCS, not SMS)
- Java SDK or REST API parameters (`.setFriendlyName`, `.setLocale`, etc.)

**What CAN change it**: Per Twilio Verify documentation, the SMS From field is controlled by (in priority order):
1. An **Alternate Sender** configured per country under *Verify → Service → Channel Configuration → SMS → Alternate Senders*, or
2. A Messaging Service SID passed via `.setMessagingServiceSid(...)` whose pool contains a registered alpha sender for TR, or
3. Twilio's default shared alpha ("TWVerify") — current state.

**To set "FIVUCSAS" as the Turkish sender** (owner: Ahmet):
1. Register "FIVUCSAS" with the Turkish regulator (BTK / İYS — İleti Yönetim Sistemi) as a brand-origin sender ID.
2. Open a Twilio Support ticket titled "Register alphanumeric Sender ID 'FIVUCSAS' for Turkey (+90) on Verify Service SID VAxxxx". Attach:
   - Turkish company registration proof
   - BTK/İYS registration evidence
3. Approval: 1–4 weeks.
4. Once approved, in Twilio Console: **Verify → Services → (service) → Channel Configuration → SMS → Alternate Senders** → add `FIVUCSAS` under country `TR`.
5. No code change required — existing `Verification.creator(...).setLocale("tr").create()` will pick up the alternate sender automatically.

**Code already in place**: `TwilioVerifySmsService.sendOtp` calls `.setLocale("tr")` so the message body is Turkish regardless of sender branding.
