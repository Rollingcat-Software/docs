# Email OTP Setup — Status & Configuration

## Current Status: CONFIGURED AND WORKING

SMTP is already wired up and active in production. No action required.

## Configuration (as of 2026-04-10)

### .env.prod (identity-core-api)
```
MAIL_HOST=smtp.hostinger.com
MAIL_PORT=587
MAIL_USERNAME=info@fivucsas.com
MAIL_FROM=info@fivucsas.com
MAIL_ENABLED=true
MAIL_PASSWORD=<set in .env.prod>
```

### docker-compose.prod.yml passes both sets of env vars:
```
MAIL_HOST / MAIL_PORT / MAIL_USERNAME / MAIL_PASSWORD / MAIL_FROM / MAIL_ENABLED
SPRING_MAIL_HOST / SPRING_MAIL_PORT / SPRING_MAIL_USERNAME / SPRING_MAIL_PASSWORD
SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH=true
SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE=true
```
Both sets are needed: custom `mail.*` keys drive `SmtpEmailService`, while `SPRING_MAIL_*` keys drive Spring Boot's auto-configured `JavaMailSender` bean.

### Hostinger SMTP Settings
- Host: smtp.hostinger.com
- Port: 587 (STARTTLS)
- From: info@fivucsas.com

## How Email OTP Works

Email OTP is NOT a standalone REST endpoint. It flows through the N-step MFA system:

1. User initiates login → auth session created
2. Auth flow includes EMAIL_OTP step
3. Frontend calls `POST /api/v1/auth/mfa/step` with `{ action: "send" }` → OTP sent via SMTP
4. User enters code → frontend calls `POST /api/v1/auth/mfa/step` with `{ code: "123456" }` → validated
5. On success, JWT issued (if final step) or next step begins

### Key Classes
- `EmailOtpAuthHandler` — handles send + validate logic
- `SmtpEmailService` — active when `mail.enabled=true`, sends via JavaMailSender
- `NoOpEmailService` — fallback when `mail.enabled=false` (logs OTP to console)
- OTP stored in Redis with 5-minute TTL via `OtpService`

## If SMTP Needs to Change (e.g. different sender address)

1. Create new email account in Hostinger hPanel → Emails → Email Accounts
2. Update in `identity-core-api/.env.prod`:
   ```
   MAIL_USERNAME=noreply@fivucsas.com
   MAIL_PASSWORD=new_password
   MAIL_FROM=noreply@fivucsas.com
   ```
3. Restart the container:
   ```bash
   cd /opt/projects/fivucsas/identity-core-api
   docker compose -f docker-compose.prod.yml --env-file .env.prod up -d identity-core-api
   ```

## Testing Email OTP in Production

You cannot test via a standalone curl since the endpoint requires an active auth session.
To verify it works:
1. Log into app.fivucsas.com with an account that has EMAIL_OTP in its auth flow
2. Observe whether the OTP email arrives
3. Check logs: `docker logs identity-core-api 2>&1 | grep -i "otp\|mail"`

If `SmtpEmailService` is active, successful sends log: `OTP email sent to: <email>`
If `NoOpEmailService` is active instead, it logs: `Mail disabled - OTP for <email>: <code>`
