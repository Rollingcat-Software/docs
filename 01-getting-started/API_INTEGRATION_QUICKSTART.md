# API Integration Quick Start

## Quick Setup (5 Minutes)

### Step 1: Start Backend

```bash
cd identity-core-api
export JWT_SECRET=your-dev-secret-key-change-in-production
./gradlew bootRun --args='--spring.profiles.active=dev'
```

Backend ready at: `http://localhost:8080`

### Step 2: Configure Web App

```bash
cd web-app

# Verify .env file
cat .env
# Should show: VITE_ENABLE_MOCK_API=false
# Should show: VITE_API_BASE_URL=http://localhost:8080/api/v1

pnpm install
pnpm dev
```

Web app ready at: `http://localhost:5173`

### Step 3: Test Integration

Open browser to `http://localhost:5173` and:

1. Click "Login" or navigate to login page
2. Use test credentials (if seeded) or register new user
3. Check browser Developer Tools > Network tab
4. Verify requests are going to `localhost:8080/api/v1`

## Verify Real API is Connected

### Check Network Tab

Open browser Developer Tools (F12) > Network tab:

- Requests should show: `localhost:8080/api/v1/...`
- Status codes: 200, 201, 401 (expected errors)
- NOT seeing mock data responses

### Check Console Logs

Open browser Developer Tools (F12) > Console tab:

- Should see: `HTTP POST http://localhost:8080/api/v1/auth/login`
- Should see: `HTTP GET http://localhost:8080/api/v1/users`
- Should NOT see: "Using mock data" messages

## Common Issues

### Issue: Still seeing mock data

**Solution:**
```bash
cd web-app
# Edit .env file
echo "VITE_ENABLE_MOCK_API=false" > .env
# Restart dev server
pnpm dev
```

### Issue: CORS errors

**Solution:**
```bash
# Verify backend CORS configuration includes:
# http://localhost:5173

# Check identity-core-api/src/main/resources/application-dev.yml
# Should contain:
# cors:
#   allowed-origins: http://localhost:5173,http://localhost:3000
```

### Issue: 401 Unauthorized

**Solution:**
1. Clear browser storage: Developer Tools > Application > Storage > Clear site data
2. Login again to get fresh tokens
3. Verify JWT_SECRET is set on backend

## Test API Directly

### Register User

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### Login

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!"
  }'
```

Save the `accessToken` from response.

### Get Current User

```bash
curl -X GET http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN_HERE"
```

## Mobile App Setup

```bash
cd mobile-app

# Verify ApiConfig.kt
# Should show: useRealApi = true

# Run Android app
./gradlew :composeApp:installDebug
```

Note: For Android emulator, use `10.0.2.2:8080` instead of `localhost:8080`

## Quick Reference

| Component | URL | Status Check |
|-----------|-----|--------------|
| Backend API | http://localhost:8080 | http://localhost:8080/api/v1/auth/health |
| Web App | http://localhost:5173 | Open in browser |
| Swagger UI | http://localhost:8080/swagger-ui.html | Open in browser |
| H2 Console | http://localhost:8080/h2-console | Open in browser (dev only) |

## Environment Variables Reference

### Web App (.env)

```bash
# REQUIRED - Backend API
VITE_API_BASE_URL=http://localhost:8080/api/v1

# REQUIRED - Enable/Disable Mock API
VITE_ENABLE_MOCK_API=false

# OPTIONAL
VITE_API_TIMEOUT=30000
VITE_DEV_SERVER_PORT=5173
```

### Backend (environment variables)

```bash
# REQUIRED
JWT_SECRET=your-secret-key-minimum-32-chars

# OPTIONAL - Defaults work for development
SPRING_PROFILES_ACTIVE=dev
PORT=8080
```

## Need Help?

1. Check full documentation: `docs/04-api/BACKEND_FRONTEND_INTEGRATION.md`
2. Check backend logs for errors
3. Check browser console for frontend errors
4. Test API endpoints using Swagger UI: http://localhost:8080/swagger-ui.html
