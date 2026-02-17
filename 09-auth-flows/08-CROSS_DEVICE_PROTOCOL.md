# Cross-Device Delegation Protocol

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

Cross-device delegation enables authentication to continue when the primary device lacks hardware required for a specific auth step. For example, a desktop app cannot read NFC, so it delegates that step to the user's registered smartphone via a QR code bridge and WebSocket real-time communication.

---

## 2. When Delegation Is Triggered

### 2.1 Automatic Detection

```
Client starts auth session
  → Receives required steps + methods
  → For each step:
       Check: device.capabilities.includes(method.requiredHardware)?
       YES → Execute locally
       NO  → Offer delegation OR use fallback
```

### 2.2 Delegation Trigger Matrix

| Step Method | Missing Hardware | Primary Device | Action |
|---|---|---|---|
| Fingerprint | No sensor | Web/Desktop | Delegate to phone or offer fallback |
| NFC Document | No NFC | Web/Desktop | Delegate to phone |
| Face | No camera | Rare desktop | Delegate to phone or external webcam |
| Voice | No mic | Very rare | Delegate to phone |

### 2.3 User Choice

When delegation is needed, the UI presents:
```
┌─────────────────────────────────────────────────┐
│  This step requires [Fingerprint]                │
│                                                   │
│  Your current device doesn't have a fingerprint  │
│  sensor. You can:                                │
│                                                   │
│  [1] Complete on your phone                      │
│      Scan the QR code below with your phone      │
│                                                   │
│  [2] Use fallback method (QR Code)               │
│      Present your QR badge to the camera         │
│                                                   │
│  ┌────────────────┐                              │
│  │   ██████████   │  Scan this QR with           │
│  │   ██    ████   │  the FIVUCSAS app            │
│  │   ██████████   │  on your phone               │
│  │   ████  ████   │                              │
│  │   ██████████   │  Waiting...                  │
│  └────────────────┘                              │
│                                                   │
│  Expires in: 4:32                                │
└─────────────────────────────────────────────────┘
```

---

## 3. Delegation Protocol Sequence

### 3.1 Full Sequence Diagram

```
PRIMARY DEVICE              IDENTITY CORE API              COMPANION DEVICE
(Desktop/Web)                  (Backend)                    (Phone)
     |                            |                            |
     |  1. POST /auth/sessions    |                            |
     |     {capabilities: [...]}  |                            |
     |--------------------------->|                            |
     |                            |                            |
     |  2. Session created        |                            |
     |     Steps: [PASSWORD, NFC] |                            |
     |<---------------------------|                            |
     |                            |                            |
     |  3. Complete PASSWORD step |                            |
     |--------------------------->|                            |
     |                            |                            |
     |  4. PASSWORD OK, next: NFC |                            |
     |<---------------------------|                            |
     |                            |                            |
     |  (detect: no NFC on device)|                            |
     |                            |                            |
     |  5. POST /delegate         |                            |
     |     {stepOrder: 2}         |                            |
     |--------------------------->|                            |
     |                            |  [Generate delegation      |
     |                            |   token (JWT, 5min TTL)]   |
     |                            |                            |
     |  6. Delegation response    |                            |
     |     {delegationToken,      |                            |
     |      qrData, websocketUrl} |                            |
     |<---------------------------|                            |
     |                            |                            |
     |  7. Display QR code        |                            |
     |  8. Open WebSocket         |                            |
     |     wss://host/ws/auth-sessions/{id}                    |
     |--------------------------->|                            |
     |                            |                            |
     |  9. WebSocket connected    |                            |
     |<---------------------------|                            |
     |                            |                            |
     |                            |  10. Scan QR code ←------  |
     |                            |      (user scans with phone)|
     |                            |                            |
     |                            |  11. POST /delegate-complete|
     |                            |      {delegationToken,     |
     |                            |       method: NFC,         |
     |                            |       data: {chipData...}} |
     |                            |<---------------------------|
     |                            |                            |
     |                            |  [Validate delegation token|
     |                            |   Validate NFC data        |
     |                            |   Mark step COMPLETED]     |
     |                            |                            |
     |                            |  12. 200 OK ─────────────> |
     |                            |      {status: COMPLETED}   |
     |                            |                            |
     |  13. WebSocket push:       |                            |
     |      STEP_COMPLETED        |                            |
     |<---------------------------|                            |
     |                            |                            |
     |  (all steps done)          |                            |
     |                            |                            |
     |  14. WebSocket push:       |                            |
     |      SESSION_COMPLETED     |                            |
     |      {accessToken, ...}    |                            |
     |<---------------------------|                            |
     |                            |                            |
     |  15. Auth complete!        |                            |
     |  Close WebSocket           |                            |
```

---

## 4. QR Code Payload

### 4.1 Structure

```json
{
  "v": 1,
  "action": "delegate",
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "stepOrder": 2,
  "method": "NFC_DOCUMENT",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "server": "https://api.fivucsas.com",
  "nonce": "a1b2c3d4e5f6"
}
```

### 4.2 Encoding

1. JSON payload is created
2. Payload is encrypted with AES-256-GCM using server secret
3. Encrypted bytes are Base64URL encoded
4. Prefixed with protocol identifier: `fivucsas://delegate/{base64url}`
5. QR code generated from the final string

### 4.3 QR Code Properties

| Property | Value |
|---|---|
| **Error Correction** | Level M (15% recovery) |
| **Module Size** | Auto-sized for ~300x300px display |
| **Color** | Black on white (standard for scanning reliability) |
| **Refresh** | Static (token in QR doesn't change) |
| **Expiry** | 5 minutes (shown as countdown on screen) |

---

## 5. WebSocket Protocol

### 5.1 Connection Establishment

```
Primary Device → Server:
  wss://host/ws/auth-sessions/{sessionId}?token={accessTokenOrDelegationToken}

Server validates:
  1. Session exists and is active
  2. Token is valid (JWT signature + expiry)
  3. User/device is associated with session

Server → Primary Device:
  {
    "type": "CONNECTION_ESTABLISHED",
    "sessionId": "uuid",
    "currentStatus": "IN_PROGRESS",
    "currentStep": 2
  }
```

### 5.2 Message Types (Server → Client)

```typescript
// Step completed by companion device
{
  "type": "STEP_COMPLETED",
  "stepOrder": 2,
  "method": "NFC_DOCUMENT",
  "status": "COMPLETED",
  "delegated": true,
  "companionDevice": {
    "name": "Samsung Galaxy S24",
    "platform": "android"
  },
  "timestamp": "2026-02-17T10:32:15Z"
}

// All steps done, session completed
{
  "type": "SESSION_COMPLETED",
  "sessionId": "uuid",
  "authentication": {
    "accessToken": "eyJhbG...",
    "refreshToken": "eyJhbG...",
    "expiresIn": 86400,
    "tokenType": "Bearer",
    "authLevel": 3,
    "methodsUsed": ["PASSWORD", "NFC_DOCUMENT"],
    "user": { ... }
  }
}

// Step failed
{
  "type": "STEP_FAILED",
  "stepOrder": 2,
  "method": "NFC_DOCUMENT",
  "error": "NFC_READ_FAILED",
  "attemptsRemaining": 2,
  "message": "Could not read document chip"
}

// Session expired or failed
{
  "type": "SESSION_EXPIRED",
  "reason": "TIMEOUT"
}

{
  "type": "SESSION_FAILED",
  "reason": "MAX_ATTEMPTS_EXCEEDED",
  "failedStep": 2
}

// Companion device connected
{
  "type": "COMPANION_CONNECTED",
  "device": {
    "name": "Samsung Galaxy S24",
    "platform": "android"
  }
}

// Heartbeat
{
  "type": "PING",
  "timestamp": "2026-02-17T10:31:00Z"
}
```

### 5.3 Message Types (Client → Server)

```typescript
// Heartbeat response
{
  "type": "PONG"
}

// Cancel delegation
{
  "type": "CANCEL_DELEGATION",
  "stepOrder": 2
}
```

### 5.4 Connection Lifecycle

| State | Duration | Action |
|---|---|---|
| Connecting | 0-5s | TCP + TLS + WebSocket handshake |
| Connected | Until session end | Receiving real-time updates |
| Heartbeat | Every 30 seconds | Server sends PING, client sends PONG |
| Idle timeout | 60 seconds | Disconnect if no PONG received |
| Max duration | 10 minutes | Matches session TTL |
| Reconnection | 3 attempts, 2s backoff | Auto-reconnect on disconnect |

---

## 6. Companion Device Flow

### 6.1 QR Code Scanning

When the companion device scans the QR code:

```
1. App recognizes fivucsas:// URI scheme
2. Decrypt payload with app's copy of delegation key
3. Extract: sessionId, stepOrder, method, token, server
4. Display: "Desktop is requesting NFC verification"
   [Accept] [Decline]
5. User taps Accept
6. App opens method-specific UI (NFC reader, fingerprint prompt, etc.)
7. User completes the method
8. App submits: POST /auth/sessions/{sessionId}/steps/{stepOrder}/delegate-complete
9. App displays: "Verification sent to desktop"
```

### 6.2 Companion Device UI

```
┌─────────────────────────────────────────┐
│  FIVUCSAS                               │
│                                          │
│  🖥 Your desktop is requesting          │
│  NFC verification                        │
│                                          │
│  Step 2 of 2: NFC Document              │
│  Session expires in: 4:32               │
│                                          │
│  ┌─────────────────────────────────┐    │
│  │                                 │    │
│  │     📱 Hold your passport       │    │
│  │     against the back of         │    │
│  │     your phone                  │    │
│  │                                 │    │
│  │     [Animation: phone + card]   │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                          │
│  [Cancel]                               │
└─────────────────────────────────────────┘
```

### 6.3 Deep Link Handling

```kotlin
// Android: AndroidManifest.xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="fivucsas" android:host="delegate" />
</intent-filter>

// iOS: Info.plist
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fivucsas</string>
        </array>
    </dict>
</array>
```

---

## 7. Push Notification Integration

### 7.1 When Primary Device Has No QR Display

If the primary device can't display QR (rare edge case), push notification can be sent instead:

```
Server → Firebase/APNs:
{
  "to": "device-push-token",
  "notification": {
    "title": "Authentication Request",
    "body": "Your desktop needs NFC verification"
  },
  "data": {
    "action": "delegate",
    "sessionId": "uuid",
    "stepOrder": 2,
    "method": "NFC_DOCUMENT",
    "delegationToken": "jwt-token"
  }
}
```

### 7.2 Push Flow

```
PRIMARY DEVICE              SERVER                    COMPANION (Phone)
     |                         |                            |
     |  POST /delegate         |                            |
     |  {preferredDeviceId}    |                            |
     |------------------------>|                            |
     |                         |  Push notification ------->|
     |                         |  {delegationToken, ...}    |
     |                         |                            |
     |                         |  User taps notification    |
     |                         |                     <------|
     |                         |                            |
     |                         |  App opens delegation UI   |
     |                         |  User completes method     |
     |                         |                            |
     |                         |  POST /delegate-complete   |
     |                         |<---------------------------|
     |                         |                            |
     |  WebSocket: COMPLETED   |                            |
     |<------------------------|                            |
```

---

## 8. Error Handling

### 8.1 Delegation Failures

| Error | Cause | Recovery |
|---|---|---|
| QR expired | 5 minutes elapsed | Re-request delegation (new QR) |
| Token invalid | Tampered or reused | Re-request delegation |
| Companion timeout | User didn't complete on phone | Show fallback option |
| WebSocket disconnect | Network issue | Auto-reconnect (3 attempts) |
| Method failed on companion | NFC read error, etc. | Retry on companion or use fallback |
| Session expired | 10 minutes total | Start new session |
| No companion registered | No phone registered | Prompt user to register device |

### 8.2 Fallback Chain

```
1. Try delegation to registered companion device
   ↓ fails
2. Offer QR code scanning to any FIVUCSAS app
   ↓ fails
3. Offer configured fallback method (if any)
   ↓ fails
4. Auth step fails → session may fail
```

### 8.3 Network Resilience

```
WebSocket reconnection strategy:
  Attempt 1: Immediate reconnect
  Attempt 2: Wait 2 seconds
  Attempt 3: Wait 5 seconds
  After 3 failures: Fall back to polling

Polling fallback:
  GET /auth/sessions/{id} every 3 seconds
  Continue until session is completed, failed, or expired
```

---

## 9. Security Considerations

### 9.1 Delegation Token Security

| Property | Value |
|---|---|
| Format | JWT signed with HMAC-SHA256 |
| TTL | 5 minutes |
| Single-use | Invalidated after first successful use |
| Scope | Bound to specific session + step |
| Claims | sessionId, stepOrder, userId, tenantId, nonce |

### 9.2 QR Code Security

- Encrypted with AES-256-GCM (not just Base64)
- Contains nonce for replay prevention
- Server-side validation on every scan
- QR cannot be used after delegation completes

### 9.3 WebSocket Security

- WSS (TLS) only
- Token authentication on connection
- Origin validation
- Rate limiting (10 messages/second)
- Auto-disconnect on token expiry

### 9.4 Man-in-the-Middle Prevention

- All communication over TLS 1.2+
- Certificate pinning in mobile apps (optional)
- Delegation token contains session context (prevents reuse in different session)

---

## 10. Implementation Notes

### 10.1 Spring Boot WebSocket (Identity Core API)

```java
// WebSocket configuration
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(authSessionWebSocketHandler(), "/ws/auth-sessions/{sessionId}")
                .setAllowedOrigins("*"); // Configure properly
    }
}
```

### 10.2 React WebSocket (Web App)

```typescript
// useAuthSessionWebSocket.ts
const useAuthSessionWebSocket = (sessionId: string) => {
    const ws = useRef<WebSocket | null>(null);

    useEffect(() => {
        ws.current = new WebSocket(`wss://host/ws/auth-sessions/${sessionId}`);
        ws.current.onmessage = (event) => {
            const message = JSON.parse(event.data);
            switch (message.type) {
                case 'STEP_COMPLETED': handleStepCompleted(message); break;
                case 'SESSION_COMPLETED': handleSessionCompleted(message); break;
                // ...
            }
        };
        return () => ws.current?.close();
    }, [sessionId]);
};
```

### 10.3 Kotlin WebSocket (Client Apps)

```kotlin
// OkHttp WebSocket in shared module
val client = OkHttpClient()
val request = Request.Builder()
    .url("wss://host/ws/auth-sessions/$sessionId?token=$token")
    .build()

client.newWebSocket(request, object : WebSocketListener() {
    override fun onMessage(webSocket: WebSocket, text: String) {
        val message = json.decodeFromString<WsMessage>(text)
        // Handle delegation completion
    }
})
```
