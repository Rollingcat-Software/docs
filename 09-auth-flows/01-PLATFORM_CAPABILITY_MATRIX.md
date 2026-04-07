# Platform Capability Matrix

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document defines which authentication methods are available on each client platform based on hardware capabilities, and how cross-device delegation bridges gaps when a platform lacks required hardware.

FIVUCSAS supports **5 client platforms** and **10 authentication methods** across **4 categories**.

---

## 2. Platform Definitions

| Platform | Runtime | Distribution | Primary Users |
|----------|---------|-------------|---------------|
| **Web** | Browser (Chrome, Firefox, Safari, Edge) | URL (app.fivucsas.com) | Tenant Admins, Members |
| **Android** | Android 8.0+ (API 26+) | APK / Play Store | Members, Field Users |
| **iOS** | iOS 15.0+ | TestFlight / App Store | Members, Field Users |
| **Desktop** | Windows 10+, macOS 12+, Linux | Installable binary (Compose Desktop) | Admins, Kiosk Operators |
| **External Device** | Varies (NFC readers, fingerprint scanners) | USB/BLE connected hardware | Kiosk/Access Control |

---

## 3. Authentication Method Categories

| Category | Methods | Pricing Tier |
|----------|---------|-------------|
| **Basic** | Password, Email OTP | Free |
| **Standard** | SMS OTP, TOTP (Authenticator App), QR Code | $50-75/mo |
| **Premium** | Face Recognition, Fingerprint, Voice Recognition | $150-250/mo |
| **Enterprise** | NFC Document, Hardware Key (FIDO2) | $100-500/mo |

---

## 4. Hardware Capability Matrix

### 4.1 Native Hardware Support

| Auth Method | Web (Browser) | Android App | iOS App | Desktop App | Hardware Required |
|---|:---:|:---:|:---:|:---:|---|
| **Password** | YES | YES | YES | YES | Keyboard |
| **Email OTP** | YES | YES | YES | YES | None (email delivery) |
| **SMS OTP** | YES | YES | YES | YES | None (SMS delivery) |
| **TOTP** | YES | YES | YES | YES | None (manual code entry) |
| **QR Code (Scan)** | YES* | YES | YES | YES* | Camera |
| **QR Code (Display)** | YES | YES | YES | YES | Screen |
| **Face Recognition** | YES* | YES | YES | YES* | Front camera |
| **Fingerprint** | NO** | YES | YES | NO** | Fingerprint sensor |
| **Voice Recognition** | YES | YES | YES | YES | Microphone |
| **NFC Document** | NO | YES | YES*** | NO | NFC chip reader |
| **Hardware Key (FIDO2)** | YES | YES**** | YES**** | YES | USB/BLE security key |
| **Card Detection** | YES* | YES | YES | YES* | Camera |

**Notes:**
- `*` Webcam required; not all desktops/laptops have one. If absent, delegates to companion device.
- `**` WebAuthn can bridge fingerprint on laptops with built-in readers (e.g., ThinkPad) via platform authenticator. For standard PCs, external USB fingerprint readers work via FIDO2.
- `***` iOS NFC requires CoreNFC framework; supports reading NDEF tags and ISO 7816 (passport) since iOS 13.
- `****` Android/iOS FIDO2 support via USB-C/Lightning adapter or BLE.

### 4.2 Detailed Hardware Requirements Per Method

#### Password
- **Input**: Keyboard (physical or virtual)
- **Platforms**: All
- **Dependencies**: None
- **Enrollment**: Set during registration
- **Offline Capable**: Yes (cached hash comparison not recommended; typically online)

#### Email OTP
- **Input**: User types 6-digit code received via email
- **Platforms**: All
- **Dependencies**: Email delivery service (SMTP/SendGrid/SES)
- **Enrollment**: Email address verified during registration
- **Offline Capable**: No (requires email delivery)

#### SMS OTP
- **Input**: User types 6-digit code received via SMS
- **Platforms**: All
- **Dependencies**: SMS gateway (Twilio/Vonage)
- **Enrollment**: Phone number verified during registration
- **Offline Capable**: No (requires SMS delivery)

#### TOTP (Authenticator App)
- **Input**: User types 6-digit time-based code from authenticator app
- **Platforms**: All
- **Dependencies**: Authenticator app installed on user's device (Google Authenticator, Authy, etc.)
- **Enrollment**: Scan QR code with authenticator app, verify with initial code
- **Offline Capable**: Yes (time-based generation, no network needed for code generation)

#### QR Code
- **Scan Mode**: Camera scans QR code displayed on another device/printed badge
  - Requires: Camera hardware
  - Web: Webcam via `getUserMedia` API
  - Android: CameraX with ZXing/ML Kit
  - iOS: AVFoundation with CIDetector
  - Desktop: OpenCV/webcam via system camera API
- **Display Mode**: Screen displays QR code for another device to scan
  - Requires: Screen only (all platforms)
- **Enrollment**: System generates unique encrypted QR identifier for user
- **Offline Capable**: Yes (QR contains pre-signed token)

#### Face Recognition
- **Input**: Live camera feed for face capture
- **Platforms**: All camera-equipped devices
- **Dependencies**: Biometric Processor API (FastAPI), front-facing camera
- **Processing**: Server-side (image sent to biometric-processor for embedding extraction/matching)
- **Quality Requirements**: Minimum face size 112x112px, centered, well-lit, eyes open
- **Anti-Spoofing**: Passive liveness detection (texture analysis) + optional active challenges (blink, smile)
- **Enrollment**: 1-3 face images captured with quality validation
- **Offline Capable**: No (requires biometric processor)

#### Fingerprint
- **Input**: Touch fingerprint sensor
- **Native Platforms**: Android (BiometricPrompt API), iOS (LAContext/Touch ID)
- **Non-Native Platforms**: Web (WebAuthn platform authenticator on supported hardware), Desktop (external USB reader via FIDO2)
- **Processing**: Local-only (biometric template never leaves device per FIDO2 spec)
- **Enrollment**: Register credential via WebAuthn registration ceremony
- **Offline Capable**: Yes (local verification + cached credential assertion)

#### Voice Recognition
- **Input**: Microphone audio capture
- **Platforms**: All (all devices have microphones)
- **Dependencies**: Biometric Processor API (voice endpoints - to be implemented)
- **Processing**: Server-side (audio sent to biometric-processor for voiceprint extraction/matching)
- **Quality Requirements**: Minimum 3-second audio, low background noise, consistent volume
- **Enrollment**: Speak passphrase 3x for robust voiceprint template
- **Offline Capable**: No (requires biometric processor)

#### NFC Document
- **Input**: NFC chip in identity document (passport, national ID)
- **Native Platforms**: Android (NfcAdapter), iOS (CoreNFC)
- **Non-Native Platforms**: None (Web and Desktop cannot read NFC natively)
- **Processing**: Read chip data (MRZ, photo, fingerprints), verify chip authenticity via BAC/PACE
- **Enrollment**: Read document once, store document hash + verification status
- **Offline Capable**: Partial (chip reading is local, but authenticity verification may need server)

#### Hardware Key (FIDO2/WebAuthn)
- **Input**: Touch/press hardware security key (YubiKey, SoloKey, etc.)
- **Platforms**: Web (USB/BLE), Android (USB-C/BLE), iOS (Lightning/BLE), Desktop (USB)
- **Processing**: Local cryptographic operation (challenge-response)
- **Protocol**: WebAuthn / CTAP2
- **Enrollment**: WebAuthn registration ceremony (create credential pair)
- **Offline Capable**: Yes (challenge can be pre-signed)

#### Card Detection (ID Document Scan)
- **Input**: Camera captures image of physical document
- **Platforms**: All camera-equipped devices
- **Dependencies**: Biometric Processor API (`/api/v1/card/detect` - YOLO-based)
- **Processing**: Server-side (image classification + OCR)
- **Enrollment**: Capture front/back of ID document, extract and verify data
- **Offline Capable**: No (requires biometric processor)

---

## 5. Cross-Device Delegation Matrix

When a platform **cannot** natively perform a required auth method, the system delegates to a **companion device** that has the necessary hardware.

### 5.1 Delegation Trigger Rules

| Primary Device | Missing Capability | Delegation Target | Bridge Method |
|---|---|---|---|
| Web (no webcam) | Face, QR Scan, Card Detection | User's smartphone | QR code displayed on web, scanned by phone |
| Desktop (no webcam) | Face, QR Scan, Card Detection | User's smartphone | QR code displayed on desktop, scanned by phone |
| Web | Fingerprint | User's smartphone or laptop biometric | QR delegation or WebAuthn platform authenticator |
| Desktop | Fingerprint | User's smartphone or external USB reader | QR delegation or USB FIDO2 reader |
| Web | NFC Document | User's smartphone | QR delegation to phone NFC |
| Desktop | NFC Document | User's smartphone | QR delegation to phone NFC |
| Any (offline) | Face, Voice, Card Detection | N/A | Fallback to offline-capable method |

### 5.2 Delegation Protocol Summary

1. Primary device detects it cannot perform the required auth step
2. Primary device requests delegation: `POST /api/v1/auth/sessions/{id}/delegate`
3. Server creates a delegation token (5-minute TTL, single-use, session-bound)
4. Primary device displays QR code containing: `{sessionId, stepId, delegationToken, serverUrl}`
5. Companion device scans QR code
6. Companion device performs the auth method (e.g., NFC scan, fingerprint touch)
7. Companion device submits result: `POST /api/v1/auth/sessions/{id}/steps/{stepId}/delegate-complete`
8. Server validates delegation token and marks step as completed
9. Primary device receives WebSocket notification: step completed
10. Primary device proceeds to next step or completes authentication

### 5.3 Device Capability Registration

When a device first connects, it registers its capabilities:

```json
{
  "platform": "android",
  "deviceName": "Samsung Galaxy S24",
  "capabilities": ["camera", "nfc", "fingerprint", "microphone", "bluetooth"],
  "pushToken": "fcm_token_here",
  "deviceFingerprint": "sha256_of_device_identifiers"
}
```

The system uses registered capabilities to:
- Determine if delegation is needed for a given auth step
- Choose the best companion device for delegation
- Send push notifications to companion devices

---

## 6. Platform-Specific Implementation Notes

### 6.1 Web (React 18 + TypeScript)
- Camera access: `navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' } })`
- WebAuthn: `navigator.credentials.create()` / `navigator.credentials.get()`
- QR scanning: `jsQR` library or `BarcodeDetector` API (Chrome 83+)
- Audio: `navigator.mediaDevices.getUserMedia({ audio: true })` + `MediaRecorder` API
- WebSocket: Native `WebSocket` API for cross-device delegation notifications
- No NFC support (Web NFC API is experimental, Chrome Android only)
- No native fingerprint (only via WebAuthn on supported hardware)

### 6.2 Android (Kotlin, Compose)
- Camera: CameraX library (face capture, QR scanning, card detection)
- Fingerprint: `BiometricPrompt` API (Android 9+)
- NFC: `NfcAdapter` + `IsoDep` for passport reading (BAC/PACE)
- QR: ML Kit Barcode Scanning or ZXing
- Audio: `AudioRecord` API for voice capture
- FIDO2: `Fido2ApiClient` (Google Play Services)
- Push: Firebase Cloud Messaging for delegation notifications

### 6.3 iOS (Kotlin Multiplatform + SwiftUI)
- Camera: AVFoundation (face capture, QR scanning)
- Fingerprint/Face ID: LocalAuthentication framework (`LAContext`)
- NFC: CoreNFC framework (iOS 13+ for passport, iOS 11+ for NDEF)
- QR: CIDetector or Vision framework
- Audio: AVAudioEngine for voice capture
- FIDO2: ASAuthorization (iOS 16+) or third-party SDK
- Push: APNs for delegation notifications

### 6.4 Desktop (Kotlin Compose Desktop)
- Camera: OpenCV via JavaCV or system camera API
- No fingerprint sensor (unless external USB reader via FIDO2)
- No NFC (delegate to phone)
- QR: ZXing + webcam
- Audio: javax.sound.sampled for voice capture
- FIDO2: USB HID communication with hardware keys
- WebSocket: OkHttp WebSocket client for delegation notifications

---

## 7. Offline Capability Summary

| Auth Method | Offline Support | Notes |
|---|:---:|---|
| Password | Partial | Server validation required; local hash cache possible but not recommended |
| Email OTP | No | Requires email delivery |
| SMS OTP | No | Requires SMS delivery |
| TOTP | Yes | Time-based code generation is fully local |
| QR Code | Yes | Pre-signed QR tokens work offline |
| Face Recognition | No | Requires biometric processor server |
| Fingerprint | Yes | FIDO2 local verification (assertion cached) |
| Voice Recognition | No | Requires biometric processor server |
| NFC Document | Partial | Chip reading is local; verification needs server |
| Hardware Key | Yes | Local cryptographic challenge-response |

**Offline Auth Strategy**: If the tenant's auth flow includes only offline-capable methods (Password + TOTP, or Fingerprint + Hardware Key), the client can authenticate locally and sync the session when connectivity resumes. If any step requires server connectivity and the device is offline, the auth attempt is queued and the user is informed.

---

## 8. Method Availability by Use Case

| Use Case | Recommended Methods | Reason |
|---|---|---|
| **Web Admin Login** | Password + TOTP | Standard MFA, no special hardware |
| **Mobile App Login** | Face + Fingerprint | Biometric convenience on phones |
| **Door Access (Kiosk)** | Face or NFC or QR | Hands-free or badge-based |
| **Building Entry** | NFC + Face | Two-factor physical security |
| **Exam Proctoring** | Face (continuous) | Identity verification during exam |
| **Guest Access** | QR Code | Simple, no enrollment needed |
| **High-Security Transaction** | Password + Face + Hardware Key | Three-factor for sensitive ops |
| **API Access** | Hardware Key or TOTP | Programmatic authentication |
