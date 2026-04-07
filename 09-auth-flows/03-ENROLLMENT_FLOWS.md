# Enrollment Flows

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

Before a user can authenticate with a biometric or device-bound method, they must **enroll** — register their biometric template, device credential, or secret key. This document defines the enrollment flow for each of the 10 authentication methods, per platform.

**Key Principle**: Enrollment data is method-specific and stored differently:
- **Server-side biometrics** (Face, Voice): Embedding vectors stored in pgvector on the biometric processor
- **Device-bound credentials** (Fingerprint, Hardware Key): Private keys stay on device; only public keys stored server-side (FIDO2/WebAuthn)
- **Shared secrets** (TOTP, Password): Encrypted secret stored server-side
- **Token-based** (QR Code, Email OTP, SMS OTP): Generated on-demand, no persistent enrollment data
- **Document-based** (NFC Document): Document hash + verification metadata stored server-side

---

## 2. Enrollment Status Model

Each user has an enrollment record per auth method:

| Status | Description |
|---|---|
| `NOT_ENROLLED` | User has never enrolled for this method |
| `PENDING` | Enrollment initiated but not completed |
| `ENROLLED` | Successfully enrolled and active |
| `FAILED` | Enrollment attempt failed |
| `REVOKED` | Previously enrolled but revoked by admin or user |
| `EXPIRED` | Enrollment expired and needs renewal |

### Enrollment Lifecycle

```
NOT_ENROLLED --> PENDING --> ENROLLED --> REVOKED
                    |                       |
                    v                       v
                  FAILED              NOT_ENROLLED
                    |                  (re-enroll)
                    v
              NOT_ENROLLED
               (retry)
```

---

## 3. Password Enrollment

### 3.1 Flow
Password is the simplest enrollment — it happens during user registration.

```
1. User registers (or admin creates account)
2. Password validated against policy:
   - Minimum 8 characters
   - At least 1 uppercase, 1 lowercase, 1 digit, 1 special character
3. Password hashed with BCrypt (work factor 12)
4. Hash stored in users.password_hash
5. Enrollment status: ENROLLED (automatic)
```

### 3.2 Re-Enrollment (Password Change)
```
1. User submits: current password + new password
2. Current password verified against stored hash
3. New password validated against policy
4. New hash stored
5. All existing sessions invalidated (optional, configurable)
```

### 3.3 Platform Availability
| Platform | Support | Notes |
|---|---|---|
| Web | YES | Standard form input |
| Android | YES | TextInput |
| iOS | YES | TextInput |
| Desktop | YES | TextInput |

---

## 4. Email OTP Enrollment

### 4.1 Flow
Email OTP uses the user's registered email address. No separate enrollment needed.

```
1. User registers with email address
2. Email address verified during registration (verification email sent)
3. Once verified, Email OTP is automatically available
4. Enrollment status: ENROLLED (when email is verified)
```

### 4.2 Runtime Verification
```
1. System generates 6-digit OTP
2. OTP sent to user's verified email
3. OTP stored server-side with 5-minute TTL
4. User enters OTP code
5. Server validates: code matches AND not expired AND single-use
```

### 4.3 Platform Availability
All platforms (user types the code they received via email).

---

## 5. SMS OTP Enrollment

### 5.1 Flow
```
1. User provides phone number during registration or profile update
2. Verification SMS sent with 6-digit code
3. User enters code to verify phone number
4. Phone number marked as verified
5. Enrollment status: ENROLLED
```

### 5.2 Phone Number Change
```
1. User submits new phone number
2. Verification SMS sent to NEW number
3. User enters code
4. Old number replaced with new verified number
5. Audit log: phone number changed
```

### 5.3 Platform Availability
All platforms (user types the code they received via SMS).

---

## 6. TOTP Enrollment (Authenticator App)

### 6.1 Flow
```
Step 1: Generate Secret
  - Server generates 160-bit random secret (Base32 encoded)
  - Create otpauth:// URI: otpauth://totp/FIVUCSAS:{email}?secret={base32}&issuer=FIVUCSAS&digits=6&period=30

Step 2: Display QR Code
  - Render QR code from otpauth:// URI
  - Also display secret as text (for manual entry)

Step 3: User Scans
  - User scans QR with authenticator app (Google Authenticator, Authy, Microsoft Authenticator)

Step 4: Verify Setup
  - User enters the current 6-digit code from their authenticator
  - Server validates code using the generated secret
  - If valid: store encrypted secret, mark ENROLLED
  - If invalid: user retries

Step 5: Backup Codes (Optional)
  - Generate 10 single-use backup codes
  - Display to user (save securely)
  - Store hashed backup codes server-side
```

### 6.2 Data Stored
```json
{
  "auth_method_type": "TOTP",
  "enrollment_data": {
    "secret_encrypted": "AES-256-encrypted-base32-secret",
    "algorithm": "SHA1",
    "digits": 6,
    "period": 30,
    "backup_codes_remaining": 10,
    "verified_at": "2026-02-17T10:30:00Z"
  }
}
```

### 6.3 Platform-Specific UI

| Platform | QR Display | Manual Entry | Verification |
|---|---|---|---|
| Web | `qrcode.react` library | Text field | 6-digit input |
| Android | Compose Canvas QR | Text display | TextField |
| iOS | SwiftUI QR generator | Text display | TextField |
| Desktop | Compose Canvas QR | Text display | TextField |

---

## 7. QR Code Enrollment

### 7.1 Flow
QR Code auth works in two modes. Enrollment creates the user's unique QR identifier.

```
Step 1: Generate QR Identity
  - Server creates a unique, signed QR token for the user:
    {
      userId: UUID,
      tenantId: UUID,
      issuedAt: timestamp,
      signature: HMAC-SHA256(payload, serverSecret)
    }
  - Token encrypted with AES-256

Step 2: Display QR Code
  - QR code rendered containing the encrypted token
  - User can:
    a) Save QR as image (for digital badge)
    b) Print QR (for physical badge)

Step 3: Confirm
  - User scans their own QR code to verify it works
  - Server validates the scanned token
  - Mark ENROLLED

Step 4: Badge Provisioning (Optional)
  - Generate printable badge with:
    - User name and photo
    - QR code
    - Tenant logo
    - Expiry date (if configured)
```

### 7.2 QR Authentication Modes

**Mode A: User presents QR (badge scan)**
- User shows printed/digital QR badge to a camera (kiosk, access point)
- Camera scans QR, extracts token, validates with server
- Use case: Door access, building entry, event check-in

**Mode B: Device shows QR (cross-device bridge)**
- Primary device displays a session-specific QR code
- User scans with phone to complete auth step on phone
- Use case: Cross-device delegation (see 08-CROSS_DEVICE_PROTOCOL.md)

### 7.3 Platform Availability
- **QR Display**: All platforms (screen-based)
- **QR Scan**: All camera-equipped platforms (Web webcam, Android CameraX, iOS AVFoundation, Desktop OpenCV)

---

## 8. Face Recognition Enrollment

### 8.1 Flow

```
Step 1: Pre-Check
  - Verify user hasn't already enrolled (prevent duplicate)
  - Verify tenant has face recognition enabled
  - Verify device has front-facing camera

Step 2: Camera Activation
  - Activate front-facing camera
  - Show live preview with face detection overlay

Step 3: Real-Time Quality Guidance (WebSocket)
  - Connect to biometric processor: ws://bp-host/api/v1/ws/live-analysis
  - Mode: "enrollment-ready"
  - Real-time feedback:
    - Face detected? (green outline)
    - Face centered? (position guide)
    - Good lighting? (brightness indicator)
    - Eyes open? (alert if closed)
    - No blur? (focus indicator)
    - Face large enough? (distance guide)

Step 4: Capture High-Quality Image
  - When quality score > 0.8 threshold:
    - Auto-capture or manual button press
    - Capture high-resolution image (minimum 640x480)
  - Optional: Capture 3 images from slightly different angles

Step 5: Liveness Check
  - POST /api/v1/liveness with captured image
  - Passive liveness: texture analysis (anti-photo attack)
  - Optional active liveness: prompt user to blink/smile
  - Liveness score must exceed threshold (0.7 default)

Step 6: Quality Assessment
  - POST /api/v1/quality/analyze with captured image
  - 8-point quality assessment:
    1. Face size
    2. Face centered
    3. Brightness
    4. Contrast
    5. Blur
    6. Noise
    7. Face angles (yaw < 15, pitch < 15)
    8. Eye openness
  - Overall quality must exceed threshold (70/100 default)

Step 7: Enrollment
  - POST /api/v1/enroll with image + userId + tenantId
  - Biometric processor:
    a. Detects face
    b. Extracts embedding (512-dim vector)
    c. Stores embedding in pgvector
    d. Returns enrollment confirmation

Step 8: Identity Core Update
  - POST /api/v1/users/{userId}/enrollments/FACE
  - Store enrollment metadata:
    {
      "qualityScore": 85,
      "livenessScore": 0.92,
      "embeddingDimension": 512,
      "model": "ArcFace",
      "captureDevice": "webcam",
      "imageCount": 3
    }
  - Mark user as biometricEnrolled = true

Step 9: Confirmation
  - Display enrolled face thumbnail
  - Show quality metrics
  - "Face enrollment successful!"
```

### 8.2 Multi-Image Enrollment (Enhanced)
For higher accuracy, capture 3-5 images:
```
Image 1: Neutral expression, straight ahead
Image 2: Slight left turn (15 degrees)
Image 3: Slight right turn (15 degrees)
Image 4: Smile (optional)
Image 5: With glasses off (if applicable)
```
Each image gets its own embedding. Verification matches against the best-matching embedding.

### 8.3 Platform-Specific Implementation

| Platform | Camera API | Preview | Capture |
|---|---|---|---|
| Web | `getUserMedia` + `<video>` | Canvas overlay | Canvas `toBlob()` |
| Android | CameraX `Preview` + `ImageCapture` | Compose CameraPreview | `takePicture()` |
| iOS | AVFoundation `AVCaptureSession` | SwiftUI camera preview | `capturePhoto()` |
| Desktop | OpenCV `VideoCapture` | Compose Image render | `read()` frame |

### 8.4 Re-Enrollment
```
1. Admin or user initiates re-enrollment
2. Old embedding is NOT deleted until new one succeeds
3. New enrollment flow (Steps 2-8)
4. On success: old embedding replaced
5. On failure: old embedding preserved
```

---

## 9. Fingerprint Enrollment

### 9.1 Flow (FIDO2/WebAuthn Based)

Fingerprint enrollment uses the FIDO2/WebAuthn protocol. The biometric template **never leaves the device**.

```
Step 1: Pre-Check
  - Verify device has fingerprint sensor (capability check)
  - If no sensor: offer cross-device delegation to phone

Step 2: WebAuthn Registration Ceremony
  a. Client requests registration challenge from server:
     POST /api/v1/users/{userId}/enrollments/FINGERPRINT/challenge
     Response: {
       challenge: "random-bytes-base64",
       rpId: "fivucsas.com",
       rpName: "FIVUCSAS",
       userId: base64(userId),
       userName: email,
       authenticatorSelection: {
         authenticatorAttachment: "platform",  // use built-in sensor
         userVerification: "required"
       }
     }

  b. Client calls WebAuthn API:
     navigator.credentials.create({publicKey: options})  // Web
     BiometricPrompt.authenticate()                       // Android
     LAContext.evaluatePolicy()                            // iOS

  c. User touches fingerprint sensor
     - OS handles fingerprint capture and template matching
     - Key pair generated: private key stays on device, public key returned

  d. Client sends attestation to server:
     POST /api/v1/users/{userId}/enrollments/FINGERPRINT
     {
       credentialId: "base64-credential-id",
       publicKey: "base64-public-key",
       attestation: "base64-attestation-object",
       clientDataJSON: "base64-client-data"
     }

Step 3: Server Stores Credential
  - Validate attestation
  - Store credential ID + public key + metadata
  - Mark ENROLLED

Step 4: Confirmation
  - "Fingerprint enrolled successfully!"
  - Show device name where fingerprint was registered
```

### 9.2 Data Stored (Server-Side)
```json
{
  "auth_method_type": "FINGERPRINT",
  "enrollment_data": {
    "credential_id": "base64-credential-id",
    "public_key": "base64-public-key-cose",
    "sign_count": 0,
    "device_name": "Samsung Galaxy S24",
    "platform": "android",
    "aaguid": "authenticator-guid",
    "enrolled_at": "2026-02-17T10:30:00Z"
  }
}
```

### 9.3 Platform Availability

| Platform | Sensor | API | Notes |
|---|---|---|---|
| Android | Built-in | BiometricPrompt + FIDO2 | Android 9+ required |
| iOS | Touch ID / Face ID* | LAContext + ASAuthorization | iOS 16+ for passkeys |
| Desktop | External USB reader | FIDO2 CTAP2 via USB HID | Rare, mostly delegation |
| Web | Laptop built-in | WebAuthn `navigator.credentials` | Chrome, Safari, Firefox |

*iOS Face ID is handled under the Fingerprint umbrella in WebAuthn since both are "platform authenticators".

---

## 10. Voice Recognition Enrollment

### 10.1 Flow

```
Step 1: Pre-Check
  - Verify device has microphone
  - Request microphone permission
  - Check ambient noise level (reject if too noisy)

Step 2: Passphrase Display
  - System generates or selects enrollment passphrase
  - Example: "The quick brown fox jumps over the lazy dog"
  - Display passphrase on screen

Step 3: Record Voice Sample 1
  - Start audio recording
  - User reads passphrase aloud
  - Minimum duration: 3 seconds
  - Show recording waveform visualization
  - Stop recording

Step 4: Submit and Validate Sample 1
  - POST /api/v1/voice/enroll/sample
    {userId, tenantId, audio: base64, sampleNumber: 1}
  - Server extracts voiceprint features
  - Validates audio quality:
    - Duration >= 3 seconds
    - SNR (signal-to-noise ratio) > threshold
    - Speech detected (not silence)

Step 5: Repeat for Samples 2 and 3
  - Same passphrase or different phrases
  - Each sample validates independently
  - 3 samples provide robust voiceprint template

Step 6: Finalize Enrollment
  - POST /api/v1/voice/enroll/finalize
    {userId, tenantId}
  - Server combines 3 voiceprint embeddings
  - Creates unified voiceprint model
  - Stores in pgvector

Step 7: Identity Core Update
  - POST /api/v1/users/{userId}/enrollments/VOICE
  - Store metadata:
    {
      "samples": 3,
      "avgSnr": 22.5,
      "model": "ECAPA-TDNN",
      "embeddingDimension": 192
    }

Step 8: Verification Test
  - Optional: user speaks passphrase one more time
  - System verifies against newly created voiceprint
  - Confirms enrollment works
```

### 10.2 Platform-Specific Audio Capture

| Platform | API | Format | Sample Rate |
|---|---|---|---|
| Web | MediaRecorder API | WAV/WebM | 16kHz |
| Android | AudioRecord | PCM/WAV | 16kHz |
| iOS | AVAudioEngine | WAV | 16kHz |
| Desktop | javax.sound.sampled | WAV | 16kHz |

---

## 11. NFC Document Enrollment

### 11.1 Flow

```
Step 1: Pre-Check
  - Verify device has NFC capability
  - If no NFC: redirect to companion device (phone) via QR delegation

Step 2: Document Selection
  - User selects document type:
    - Passport (e-Passport with NFC chip)
    - National ID (if NFC-enabled)
    - Driver's License (if NFC-enabled)

Step 3: MRZ Capture (for Passport)
  - User takes photo of passport data page
  - OCR extracts MRZ (Machine Readable Zone)
  - MRZ provides: document number, date of birth, expiry date
  - These serve as keys for BAC (Basic Access Control) to unlock the chip

Step 4: NFC Chip Reading
  - Prompt: "Hold your document against the back of your phone"
  - Establish NFC connection (IsoDep tag technology)
  - Perform BAC authentication using MRZ-derived keys
  - Read data groups:
    - DG1: MRZ data (name, nationality, document number)
    - DG2: Face image (JPEG2000 or JPEG)
    - DG3: Fingerprint templates (if available, requires EAC)
    - DG14: Security info
  - Verify document authenticity:
    - Passive Authentication: verify digital signatures on data groups
    - Active Authentication: challenge-response with chip

Step 5: Face Comparison
  - Extract face photo from DG2
  - Capture live selfie
  - Compare: POST /api/v1/compare (biometric processor)
  - Similarity must exceed threshold (0.7)
  - This proves the person holding the document is the document owner

Step 6: Store Enrollment
  - POST /api/v1/users/{userId}/enrollments/NFC_DOCUMENT
  - Store:
    {
      "documentType": "PASSPORT",
      "documentNumber_hash": "sha256(documentNumber)",
      "nationality": "TR",
      "dateOfBirth_hash": "sha256(dob)",
      "expiryDate": "2030-01-01",
      "faceMatchScore": 0.94,
      "chipAuthenticated": true,
      "passiveAuth": true,
      "activeAuth": true,
      "readAt": "2026-02-17T10:30:00Z"
    }
  - Note: Raw document data is NOT stored (privacy). Only hashes and verification status.

Step 7: Confirmation
  - "Document verified and enrolled successfully!"
  - Show document type, nationality, expiry
```

### 11.2 Platform Availability

| Platform | NFC | MRZ OCR | Face Comparison |
|---|---|---|---|
| Android | NfcAdapter + IsoDep | ML Kit Text Recognition or camera capture | POST /compare |
| iOS | CoreNFC (NFCTagReaderSession) | Vision framework | POST /compare |
| Web | NO (delegate) | Camera OCR | POST /compare |
| Desktop | NO (delegate) | Camera OCR | POST /compare |

---

## 12. Hardware Key (FIDO2) Enrollment

### 12.1 Flow (WebAuthn Registration)

```
Step 1: Pre-Check
  - Prompt user to insert/connect security key
  - Supported: USB-A, USB-C, NFC, BLE

Step 2: WebAuthn Registration Ceremony
  a. Server generates challenge:
     POST /api/v1/users/{userId}/enrollments/HARDWARE_KEY/challenge
     Response: {
       challenge: "random-bytes",
       rpId: "fivucsas.com",
       rpName: "FIVUCSAS",
       userId: base64(userId),
       userName: email,
       authenticatorSelection: {
         authenticatorAttachment: "cross-platform",  // external key
         userVerification: "discouraged",
         residentKey: "preferred"
       },
       pubKeyCredParams: [
         {type: "public-key", alg: -7},   // ES256
         {type: "public-key", alg: -257}  // RS256
       ]
     }

  b. Client calls WebAuthn API:
     const credential = await navigator.credentials.create({publicKey: options})

  c. User touches/taps the security key (LED blinks)

  d. Key generates credential pair
     - Private key stored on the hardware key
     - Public key + attestation returned to client

  e. Client sends to server:
     POST /api/v1/users/{userId}/enrollments/HARDWARE_KEY
     {
       credentialId: base64url(credential.rawId),
       publicKey: extractPublicKey(attestationObject),
       attestationObject: base64url(attestationObject),
       clientDataJSON: base64url(clientDataJSON),
       transports: ["usb", "nfc"]  // how key connects
     }

Step 3: Server Validates and Stores
  - Verify attestation (check signature, origin, challenge)
  - Store credential ID + public key
  - Mark ENROLLED

Step 4: Confirmation
  - "Hardware key registered successfully!"
  - Show key model/type if available from attestation
```

### 12.2 Multiple Keys
Users can register multiple hardware keys for redundancy. Each registration creates a separate enrollment record.

### 12.3 Platform Availability

| Platform | USB | NFC | BLE |
|---|---|---|---|
| Web | YES (HID) | Chrome Android only | YES (Web Bluetooth) |
| Android | YES (USB-C OTG) | YES | YES |
| iOS | YES (Lightning/USB-C) | YES | YES |
| Desktop | YES (USB-A/C) | NO | Varies |

---

## 13. Card Detection Enrollment

### 13.1 Flow

```
Step 1: Document Photo Capture
  - Activate camera (rear-facing preferred)
  - Overlay guide frame for document alignment
  - Capture front of ID document

Step 2: Document Classification
  - POST /api/v1/card/detect (biometric processor, YOLO-based)
  - Detect document type: passport, national ID, driver's license, etc.

Step 3: Data Extraction
  - OCR to extract text fields
  - Face photo extraction from document

Step 4: Face Comparison (Optional)
  - Compare document face with live selfie
  - Proves document belongs to user

Step 5: Store Enrollment
  - Similar to NFC Document but camera-based
  - Store document hash + verification metadata

Note: Card Detection is primarily used alongside NFC Document enrollment
as a fallback when NFC is not available. The NFC enrollment provides
stronger document authentication via chip verification.
```

---

## 14. Enrollment Summary Matrix

| Method | Enrollment Required | Data Stored Server-Side | Data on Device | Re-Enrollment Trigger |
|---|---|---|---|---|
| Password | Yes (at registration) | BCrypt hash | None | Password change |
| Email OTP | No (uses verified email) | None | None | Email change |
| SMS OTP | Yes (phone verification) | Verified phone hash | None | Phone change |
| TOTP | Yes (QR scan + verify) | Encrypted TOTP secret | Authenticator app seed | Device loss |
| QR Code | Yes (generate + confirm) | Encrypted QR token | QR image (optional) | Token rotation |
| Face | Yes (multi-step capture) | Embedding in pgvector | None | Model update, quality decline |
| Fingerprint | Yes (WebAuthn) | Public key + credential ID | Private key + template | Device change |
| Voice | Yes (3 voice samples) | Voiceprint in pgvector | None | Voice change, quality decline |
| NFC Document | Yes (chip read + face match) | Document hash + status | None | Document expiry |
| Hardware Key | Yes (WebAuthn) | Public key + credential ID | Private key on key | Key loss |

---

## 15. Enrollment Wizard UX

### 15.1 Web App Enrollment Wizard
The web app presents a guided enrollment wizard accessible from:
- User profile page → "Manage Authentication Methods"
- Admin → User details → "Manage Enrollments"

```
Wizard Steps:
1. Method Selection: Grid of available methods with enrollment status badges
2. Method-Specific Flow: Camera UI (Face), QR display (TOTP), etc.
3. Verification: Test the enrolled method
4. Confirmation: Success message with metadata
```

### 15.2 Mobile/Desktop Enrollment
Similar wizard flow but with native camera, NFC, and fingerprint integration.

### 15.3 Admin-Initiated Enrollment
Tenant admins can:
- View enrollment status for all users
- Require specific enrollments before deadline
- Send enrollment reminders
- Revoke enrollments
- Export enrollment audit trail
