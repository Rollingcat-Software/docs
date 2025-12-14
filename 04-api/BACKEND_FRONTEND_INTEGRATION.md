# Backend-Frontend Integration Guide

## Overview

This document describes the integration layer between the FIVUCSAS backend services and frontend applications (Web and Mobile). The integration enables real-time communication between clients and the Spring Boot backend API, with proper authentication, error handling, and CORS configuration.

## Architecture

### Component Overview

```
┌─────────────┐         ┌─────────────┐         ┌──────────────────┐
│  Web App    │────────▶│  Identity   │────────▶│   Biometric      │
│  (React)    │  HTTP   │  Core API   │  HTTP   │   Processor      │
│  Port: 5173 │         │  (Spring)   │         │   (FastAPI)      │
└─────────────┘         │  Port: 8080 │         │   Port: 8001     │
                        └──────────────┘         └──────────────────┘
┌─────────────┐                ▲
│  Mobile App │                │
│  (Kotlin MP)│────────────────┘
└─────────────┘      HTTP
```

### Technology Stack

- **Backend**: Spring Boot 3.2+ (Java 21)
- **Web Frontend**: React 18 + TypeScript + Vite
- **Mobile Frontend**: Kotlin Multiplatform
- **HTTP Client (Web)**: Axios
- **HTTP Client (Mobile)**: Ktor Client
- **Authentication**: JWT (JSON Web Tokens)
- **API Documentation**: SpringDoc OpenAPI 3

## Configuration

### 1. Backend Configuration (identity-core-api)

#### CORS Configuration

The backend is configured to accept requests from frontend applications.

**File**: `src/main/java/com/fivucsas/identity/config/SecurityConfig.java`

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration configuration = new CorsConfiguration();

    // Parse allowed origins from configuration
    List<String> origins = Arrays.asList(allowedOrigins.split(","));
    configuration.setAllowedOrigins(origins);

    configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));
    configuration.setAllowedHeaders(Arrays.asList("Authorization", "Content-Type", "X-Tenant-ID"));
    configuration.setExposedHeaders(List.of("Authorization"));
    configuration.setAllowCredentials(true);
    configuration.setMaxAge(3600L);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", configuration);
    return source;
}
```

#### Environment-Specific CORS Origins

**Development** (`application-dev.yml`):
```yaml
cors:
  allowed-origins: http://localhost:5173,http://localhost:3000,http://localhost:4200
```

**Production** (`application-prod.yml`):
```yaml
cors:
  allowed-origins: ${CORS_ALLOWED_ORIGINS}  # Set via environment variable
```

#### API Endpoints

Base URL: `http://localhost:8080/api/v1`

**Public Endpoints** (No authentication required):
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `POST /auth/refresh` - Token refresh
- `GET /auth/health` - Health check

**Protected Endpoints** (Requires JWT):
- `GET /auth/me` - Get current user
- `POST /auth/logout` - User logout
- `GET /users/**` - User management
- `POST /biometric/**` - Biometric operations
- `GET /statistics/**` - Statistics endpoints
- `GET /tenants/**` - Tenant management

### 2. Web App Configuration (React + TypeScript)

#### Environment Variables

**File**: `.env`

```bash
# API Configuration
VITE_API_BASE_URL=http://localhost:8080/api/v1
VITE_BIOMETRIC_API_URL=http://localhost:8001/api/v1
VITE_API_TIMEOUT=30000

# Application Configuration
VITE_APP_NAME=FIVUCSAS Admin
VITE_APP_VERSION=1.0.0
VITE_ENVIRONMENT=development

# Authentication
VITE_TOKEN_STORAGE=localStorage
VITE_SESSION_TIMEOUT=3600000

# Development
VITE_DEV_SERVER_PORT=5173
# Set to 'false' to use real backend API (requires backend server running)
# Set to 'true' to use mock data for development without backend
VITE_ENABLE_MOCK_API=false
```

#### Axios HTTP Client

**File**: `src/core/api/AxiosClient.ts`

The Axios client is configured with:
1. **Base URL**: Loaded from environment variables
2. **Request Interceptor**: Automatically adds JWT token to all requests
3. **Response Interceptor**: Handles token refresh on 401 errors
4. **Error Handling**: Proper error transformation and logging

**Key Features**:

```typescript
// Request Interceptor - Add JWT token
this.client.interceptors.request.use(async (config) => {
    const accessToken = sessionStorage.getItem('access_token')

    if (accessToken && !config.url?.includes('/auth/login')) {
        config.headers.Authorization = `Bearer ${accessToken}`
    }

    return config
})

// Response Interceptor - Auto refresh token on 401
this.client.interceptors.response.use(
    (response) => response,
    async (error) => {
        if (error.response?.status === 401 && !originalRequest.url?.includes('/auth/refresh')) {
            // Attempt token refresh
            const refreshToken = sessionStorage.getItem('refresh_token')
            // ... refresh logic
        }
        return Promise.reject(error)
    }
)
```

#### Dependency Injection

**File**: `src/core/di/container.ts`

The application uses InversifyJS for dependency injection:

```typescript
// Configuration
const config: IConfig = {
    apiBaseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/api/v1',
    apiTimeout: parseInt(import.meta.env.VITE_API_TIMEOUT as string) || 30000,
    useMockAPI: import.meta.env.VITE_ENABLE_MOCK_API !== 'false',
    // ...
}

// HTTP Client binding
container.bind<IHttpClient>(TYPES.HttpClient).to(AxiosClient).inSingletonScope()

// Repository binding - switches between mock and real based on config
if (config.useMockAPI) {
    container.bind<IAuthRepository>(TYPES.AuthRepository).to(MockAuthRepository)
} else {
    container.bind<IAuthRepository>(TYPES.AuthRepository).to(AuthRepository)
}
```

### 3. Mobile App Configuration (Kotlin Multiplatform)

#### API Configuration

**File**: `shared/src/commonMain/kotlin/com/fivucsas/shared/data/remote/config/ApiConfig.kt`

```kotlin
object ApiConfig {
    enum class Environment {
        DEVELOPMENT,
        STAGING,
        PRODUCTION
    }

    var currentEnvironment: Environment = Environment.DEVELOPMENT

    private const val DEV_BASE_URL = "http://localhost:8080/api/v1"
    private const val STAGING_BASE_URL = "https://staging.fivucsas.com/api/v1"
    private const val PROD_BASE_URL = "https://api.fivucsas.com/api/v1"

    val baseUrl: String
        get() = when (currentEnvironment) {
            Environment.DEVELOPMENT -> DEV_BASE_URL
            Environment.STAGING -> STAGING_BASE_URL
            Environment.PRODUCTION -> PROD_BASE_URL
        }

    const val CONNECT_TIMEOUT_MS = 30_000L
    const val REQUEST_TIMEOUT_MS = 60_000L
    const val SOCKET_TIMEOUT_MS = 30_000L

    var useRealApi: Boolean = true // Set to false to use mock data
}
```

#### Ktor HTTP Client

**File**: `shared/src/commonMain/kotlin/com/fivucsas/shared/di/NetworkModule.kt`

The Ktor client is configured with:
1. **Content Negotiation**: JSON serialization/deserialization
2. **Logging**: Request/response logging (disabled in production)
3. **Timeouts**: Configurable connection and request timeouts
4. **Authentication**: JWT token injection via defaultRequest

```kotlin
val networkModule = module {
    single {
        HttpClient {
            install(ContentNegotiation) {
                json(Json {
                    prettyPrint = true
                    isLenient = true
                    ignoreUnknownKeys = true
                    encodeDefaults = true
                })
            }

            install(Logging) {
                logger = Logger.DEFAULT
                level = if (ApiConfig.isLoggingEnabled) LogLevel.INFO else LogLevel.NONE
            }

            install(HttpTimeout) {
                requestTimeoutMillis = ApiConfig.REQUEST_TIMEOUT_MS
                connectTimeoutMillis = ApiConfig.CONNECT_TIMEOUT_MS
                socketTimeoutMillis = ApiConfig.SOCKET_TIMEOUT_MS
            }

            defaultRequest {
                url(ApiConfig.baseUrl + "/")

                // Add JWT token to all requests (except auth endpoints)
                val tokenManager = get<TokenManager>()
                val accessToken = tokenManager.getAccessToken()

                if (accessToken != null &&
                    !url.toString().contains("/auth/login") &&
                    !url.toString().contains("/auth/register")) {
                    header(HttpHeaders.Authorization, "Bearer $accessToken")
                }
            }
        }
    }

    singleOf(::AuthApiImpl) { bind<AuthApi>() }
    singleOf(::BiometricApiImpl) { bind<BiometricApi>() }
    singleOf(::IdentityApiImpl) { bind<IdentityApi>() }
}
```

## Authentication Flow

### 1. Login Flow

```
┌─────────┐           ┌─────────┐           ┌──────────┐
│ Client  │           │ Backend │           │ Database │
└────┬────┘           └────┬────┘           └────┬─────┘
     │                     │                     │
     │ POST /auth/login    │                     │
     │ {email, password}   │                     │
     ├────────────────────▶│                     │
     │                     │                     │
     │                     │ Validate credentials│
     │                     ├────────────────────▶│
     │                     │                     │
     │                     │ User data           │
     │                     │◀────────────────────┤
     │                     │                     │
     │                     │ Generate JWT tokens │
     │                     │                     │
     │ 200 OK              │                     │
     │ {accessToken,       │                     │
     │  refreshToken,      │                     │
     │  user}              │                     │
     │◀────────────────────┤                     │
     │                     │                     │
     │ Store tokens        │                     │
     │ in sessionStorage   │                     │
     │                     │                     │
```

### 2. Authenticated Request Flow

```
┌─────────┐           ┌─────────┐
│ Client  │           │ Backend │
└────┬────┘           └────┬────┘
     │                     │
     │ GET /users          │
     │ Authorization:      │
     │ Bearer {token}      │
     ├────────────────────▶│
     │                     │
     │                     │ Validate JWT
     │                     │ Extract user info
     │                     │
     │ 200 OK              │
     │ {data}              │
     │◀────────────────────┤
     │                     │
```

### 3. Token Refresh Flow

```
┌─────────┐           ┌─────────┐
│ Client  │           │ Backend │
└────┬────┘           └────┬────┘
     │                     │
     │ GET /users          │
     │ Authorization:      │
     │ Bearer {expired}    │
     ├────────────────────▶│
     │                     │
     │ 401 Unauthorized    │
     │◀────────────────────┤
     │                     │
     │ POST /auth/refresh  │
     │ {refreshToken}      │
     ├────────────────────▶│
     │                     │
     │ 200 OK              │
     │ {accessToken,       │
     │  refreshToken}      │
     │◀────────────────────┤
     │                     │
     │ Store new tokens    │
     │                     │
     │ Retry original      │
     │ request with        │
     │ new token           │
     ├────────────────────▶│
     │                     │
     │ 200 OK              │
     │ {data}              │
     │◀────────────────────┤
     │                     │
```

## Error Handling

### Backend Error Responses

The backend returns standardized error responses:

```json
{
  "timestamp": "2025-12-04T10:30:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "path": "/api/v1/users"
}
```

### Frontend Error Handling

#### Web App (TypeScript)

```typescript
try {
    const response = await httpClient.post('/auth/login', credentials)
    // Success handling
} catch (error) {
    if (axios.isAxiosError(error)) {
        if (error.response?.status === 401) {
            throw new UnauthorizedError('Invalid credentials')
        } else if (error.response?.status === 400) {
            throw new ValidationError('Invalid input', error.response.data.errors)
        }
    }
    throw error
}
```

#### Mobile App (Kotlin)

```kotlin
try {
    val response = client.post("auth/login") {
        setBody(credentials)
    }
    // Success handling
} catch (e: ClientRequestException) {
    when (e.response.status.value) {
        401 -> throw UnauthorizedException("Invalid credentials")
        400 -> throw ValidationException("Invalid input")
        else -> throw ApiException("Request failed")
    }
}
```

## Development Setup

### Prerequisites

1. Java 21+
2. Node.js 18+
3. Python 3.11+ (for biometric service)
4. Android Studio (for mobile development)

### Starting the Backend

```bash
cd identity-core-api

# Set required environment variables
export JWT_SECRET=your-secret-key-here

# Run with development profile
./gradlew bootRun --args='--spring.profiles.active=dev'
```

Backend will be available at: `http://localhost:8080`

### Starting the Web App

```bash
cd web-app

# Install dependencies
pnpm install

# Start development server
pnpm dev
```

Web app will be available at: `http://localhost:5173`

### Starting the Mobile App

```bash
cd mobile-app

# For Android
./gradlew :composeApp:installDebug

# For iOS (macOS only)
open iosApp/iosApp.xcodeproj
```

## Testing the Integration

### 1. Health Check

```bash
curl http://localhost:8080/api/v1/auth/health
```

Expected response:
```json
{
  "status": "UP",
  "timestamp": "2025-12-04T10:30:00Z"
}
```

### 2. User Registration

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePassword123!",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

### 3. User Login

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePassword123!"
  }'
```

Expected response:
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 86400,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe"
  }
}
```

### 4. Authenticated Request

```bash
curl -X GET http://localhost:8080/api/v1/auth/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

## Troubleshooting

### CORS Errors

**Symptom**: `Access-Control-Allow-Origin` errors in browser console

**Solution**:
1. Verify CORS configuration in `SecurityConfig.java`
2. Check `application-dev.yml` has correct origins
3. Ensure frontend is running on configured port (5173)
4. Clear browser cache and restart development server

### 401 Unauthorized Errors

**Symptom**: All authenticated requests return 401

**Solution**:
1. Verify JWT token is being sent in Authorization header
2. Check token expiration (use jwt.io to decode)
3. Verify JWT_SECRET environment variable is set on backend
4. Check interceptor is adding token correctly

### Connection Refused

**Symptom**: `ERR_CONNECTION_REFUSED` or `Network Error`

**Solution**:
1. Verify backend is running: `curl http://localhost:8080/api/v1/auth/health`
2. Check backend logs for startup errors
3. Verify port 8080 is not in use by another application
4. Check firewall/antivirus is not blocking connections

### Mock Data Still Appearing

**Symptom**: Frontend shows mock data instead of real API data

**Solution**:
1. Verify `.env` has `VITE_ENABLE_MOCK_API=false`
2. Restart Vite dev server after changing .env
3. Check browser console for API request logs
4. Verify DI container is binding real repositories

## Security Considerations

### JWT Token Storage

- **Web App**: Tokens stored in `sessionStorage` (cleared on tab close)
- **Mobile App**: Tokens stored in secure encrypted storage
- **Never** store tokens in localStorage for production (XSS risk)

### HTTPS in Production

- Always use HTTPS in production
- Configure SSL certificates on backend
- Update CORS origins to use `https://` URLs

### Environment Variables

- Never commit `.env` files to version control
- Use `.env.example` as template
- Store production secrets in secure vaults (AWS Secrets Manager, etc.)

### Token Expiration

- Access tokens expire in 24 hours (configurable)
- Refresh tokens expire in 7 days (configurable)
- Automatic refresh on 401 errors
- Users must re-login after refresh token expires

## API Documentation

### SpringDoc OpenAPI (Swagger)

The backend provides interactive API documentation via Swagger UI:

**Development**: http://localhost:8080/swagger-ui.html

**OpenAPI JSON**: http://localhost:8080/api-docs

Features:
- Interactive API testing
- Request/response schemas
- Authentication testing
- Example payloads

## Performance Optimization

### Connection Pooling

Both web and mobile apps use connection pooling for HTTP requests:

- **Web (Axios)**: Default connection pooling
- **Mobile (Ktor)**: Configurable connection pool

### Request Caching

Consider implementing caching for:
- User profile data
- Static configuration
- Reference data (roles, permissions, etc.)

### Request Batching

For multiple related requests, consider:
- GraphQL (future enhancement)
- Batch API endpoints
- Websocket connections for real-time data

## Monitoring and Logging

### Backend Logging

**Development**: Verbose logging enabled
```yaml
logging:
  level:
    com.fivucsas: DEBUG
    org.springframework.security: DEBUG
```

**Production**: Minimal logging
```yaml
logging:
  level:
    com.fivucsas: INFO
    org.springframework.security: WARN
```

### Frontend Logging

**Web App**: LoggerService with configurable log levels
**Mobile App**: Ktor logging plugin (disabled in production)

## Next Steps

1. **Rate Limiting**: Implement rate limiting for API endpoints
2. **API Versioning**: Add versioning strategy (URL path vs header)
3. **GraphQL**: Consider GraphQL for complex data fetching
4. **Websockets**: Add real-time notifications via WebSocket
5. **API Gateway**: Consider API Gateway for production (Kong, AWS API Gateway)
6. **Monitoring**: Add APM tools (New Relic, DataDog, etc.)
7. **CDN**: Use CDN for static assets in production

## References

- [Spring Security Documentation](https://docs.spring.io/spring-security/reference/)
- [Axios Documentation](https://axios-http.com/docs/intro)
- [Ktor Client Documentation](https://ktor.io/docs/client.html)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [CORS Specification](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)

## Support

For issues or questions:
1. Check existing documentation in `/docs` directory
2. Review backend logs for error details
3. Test endpoints using Swagger UI
4. Check browser developer console for frontend errors
