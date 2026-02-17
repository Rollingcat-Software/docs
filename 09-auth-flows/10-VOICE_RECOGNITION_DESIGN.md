# Voice Recognition Design

> FIVUCSAS Multi-Modal Authentication System
> Document Version: 1.0 | Date: February 2026

## 1. Overview

This document specifies the design for voice recognition endpoints in the FIVUCSAS Biometric Processor (FastAPI). Voice recognition adds a third biometric modality alongside face recognition and fingerprint (FIDO2).

**Goal**: Enable speaker verification (1:1) and identification (1:N) using voiceprint embeddings, following the same architecture patterns as face recognition.

---

## 2. Architecture

### 2.1 Clean Architecture Layers

```
biometric-processor/app/
├── domain/
│   ├── entities/
│   │   └── voice_embedding.py          # VoiceEmbedding entity
│   └── interfaces/
│       └── voice_port.py               # IVoiceService port
├── application/
│   ├── usecases/
│   │   ├── voice_enroll_usecase.py     # Enrollment orchestration
│   │   ├── voice_verify_usecase.py     # 1:1 verification
│   │   └── voice_search_usecase.py     # 1:N identification
│   └── dto/
│       ├── voice_enroll_request.py
│       ├── voice_verify_request.py
│       └── voice_response.py
├── infrastructure/
│   ├── ml/
│   │   └── voice_model_adapter.py      # ML model wrapper
│   └── db/
│       └── voice_repository.py         # pgvector storage
└── api/
    ├── routes/
    │   └── voice_routes.py             # FastAPI endpoints
    └── schemas/
        └── voice_schemas.py            # Pydantic request/response
```

### 2.2 ML Model Selection

| Model | Embedding Dim | Performance | Size | Recommendation |
|---|---|---|---|---|
| **ECAPA-TDNN** | 192 | EER 0.87% (VoxCeleb1) | ~20MB | **Primary choice** |
| x-vector | 512 | EER 3.1% | ~15MB | Lightweight alternative |
| ResNetSE34V2 | 256 | EER 1.2% | ~25MB | Good accuracy/size |
| TitaNet-Large | 192 | EER 0.68% (VoxCeleb1) | ~85MB | Best accuracy, large |

**Selected**: ECAPA-TDNN via SpeechBrain
- Best balance of accuracy and size
- Well-supported by SpeechBrain framework
- 192-dimensional embeddings (compact, efficient for pgvector)
- Pre-trained on VoxCeleb2 (6,000+ speakers)

---

## 3. API Endpoints

### 3.1 Voice Enrollment - Submit Sample

```
POST /api/v1/voice/enroll/sample

Request (multipart/form-data):
  user_id: string (UUID)
  tenant_id: string (UUID)
  audio: file (WAV/WebM/MP3, max 30s, max 10MB)
  sample_number: int (1-5)

Response 200:
{
  "user_id": "uuid",
  "sample_number": 1,
  "status": "ACCEPTED",
  "quality": {
    "duration_seconds": 4.2,
    "snr_db": 22.5,
    "speech_detected": true,
    "speech_ratio": 0.78,
    "clipping_detected": false,
    "sample_rate": 16000,
    "recommendations": []
  },
  "samples_collected": 1,
  "samples_required": 3
}

Response 400:
{
  "error": "AUDIO_QUALITY_INSUFFICIENT",
  "details": {
    "duration_seconds": 1.5,
    "snr_db": 8.2,
    "recommendations": [
      "Recording too short (minimum 3 seconds)",
      "Background noise too high (move to quieter location)"
    ]
  }
}
```

### 3.2 Voice Enrollment - Finalize

```
POST /api/v1/voice/enroll/finalize

Request:
{
  "user_id": "uuid",
  "tenant_id": "uuid"
}

Response 200:
{
  "user_id": "uuid",
  "status": "ENROLLED",
  "enrollment": {
    "samples_used": 3,
    "embedding_dimension": 192,
    "model": "ECAPA-TDNN",
    "model_version": "1.0.0",
    "quality_score": 0.89,
    "enrolled_at": "2026-02-17T10:30:00Z"
  }
}

Response 400:
{
  "error": "INSUFFICIENT_SAMPLES",
  "samples_collected": 2,
  "samples_required": 3
}
```

### 3.3 Voice Verification (1:1)

```
POST /api/v1/voice/verify

Request (multipart/form-data):
  user_id: string (UUID)
  tenant_id: string (UUID)
  audio: file (WAV/WebM/MP3)

Response 200:
{
  "user_id": "uuid",
  "verified": true,
  "confidence": 0.92,
  "distance": 0.18,
  "threshold": 0.35,
  "processing_time_ms": 120,
  "audio_quality": {
    "duration_seconds": 3.5,
    "snr_db": 20.1,
    "speech_detected": true
  }
}

Response 200 (not verified):
{
  "user_id": "uuid",
  "verified": false,
  "confidence": 0.42,
  "distance": 0.65,
  "threshold": 0.35,
  "message": "Voice does not match enrolled voiceprint"
}

Response 404:
{
  "error": "USER_NOT_ENROLLED",
  "message": "No voice enrollment found for user"
}
```

### 3.4 Voice Search (1:N Identification)

```
POST /api/v1/voice/search

Request (multipart/form-data):
  tenant_id: string (UUID)
  audio: file (WAV/WebM/MP3)
  max_results: int (default 10, max 100)
  threshold: float (default 0.35)

Response 200:
{
  "matches": [
    {
      "user_id": "uuid",
      "distance": 0.15,
      "confidence": 0.94,
      "rank": 1
    },
    {
      "user_id": "uuid",
      "distance": 0.28,
      "confidence": 0.82,
      "rank": 2
    }
  ],
  "total_voiceprints_searched": 150,
  "search_time_ms": 85,
  "audio_quality": {
    "duration_seconds": 4.1,
    "snr_db": 18.5
  }
}
```

### 3.5 Delete Voice Enrollment

```
DELETE /api/v1/voice/enrollments/{user_id}

Query: tenant_id=uuid

Response 204: No Content
Response 404: { "error": "ENROLLMENT_NOT_FOUND" }
```

---

## 4. Audio Processing Pipeline

### 4.1 Input Processing

```
Raw Audio Input
    |
    v
[1] Format Detection & Conversion
    - Accept: WAV, WebM, MP3, OGG, FLAC, M4A
    - Convert to: WAV, 16kHz, 16-bit, mono
    - Library: torchaudio or pydub + ffmpeg
    |
    v
[2] Validation
    - Duration: 3-30 seconds (reject too short/long)
    - Sample rate: resample to 16kHz if needed
    - Channels: convert to mono if stereo
    - File size: max 10MB
    |
    v
[3] Speech Activity Detection (VAD)
    - Detect speech segments
    - Calculate speech ratio (speech_duration / total_duration)
    - Reject if speech ratio < 0.5 (mostly silence)
    - Library: SpeechBrain VAD or WebRTC VAD
    |
    v
[4] Quality Assessment
    - SNR (Signal-to-Noise Ratio): min 15 dB
    - Clipping detection: reject if >1% samples clipped
    - Background noise level estimation
    - Reverberation estimation (optional)
    |
    v
[5] Preprocessing
    - Pre-emphasis filter (0.97)
    - Normalize amplitude
    - Remove silence segments (optional)
    |
    v
[6] Feature Extraction
    - 80-dimensional Mel-filterbank features
    - Window: 25ms, Hop: 10ms
    - CMVN (Cepstral Mean and Variance Normalization)
    |
    v
[7] Embedding Extraction
    - ECAPA-TDNN forward pass
    - Output: 192-dimensional L2-normalized embedding
    |
    v
[8] Storage
    - Store embedding in pgvector (voice_embeddings table)
    - Delete raw audio (never stored)
```

### 4.2 Enrollment Processing (Multi-Sample)

```
Sample 1 → Embedding 1 (192-dim)
Sample 2 → Embedding 2 (192-dim)
Sample 3 → Embedding 3 (192-dim)
                |
                v
    Average + L2-Normalize
                |
                v
    Final Enrollment Embedding (192-dim)
                |
                v
    Store in pgvector
```

### 4.3 Verification Processing

```
Probe Audio → Embedding (192-dim)
                |
                v
    Cosine Distance to Enrolled Embedding
                |
                v
    distance < threshold? → VERIFIED : NOT VERIFIED

    Default threshold: 0.35 (configurable per tenant)
    Confidence: 1 - (distance / max_distance)
```

---

## 5. Database Schema

### 5.1 Voice Embeddings Table (Biometric Processor DB)

```sql
CREATE TABLE voice_embeddings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    tenant_id       UUID NOT NULL,
    embedding       vector(192) NOT NULL,
    model_name      VARCHAR(50) NOT NULL DEFAULT 'ECAPA-TDNN',
    model_version   VARCHAR(20) NOT NULL DEFAULT '1.0.0',
    quality_score   FLOAT,
    samples_count   INTEGER NOT NULL DEFAULT 3,
    enrolled_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_voice_user_tenant UNIQUE (user_id, tenant_id)
);

-- pgvector index for similarity search
CREATE INDEX idx_voice_embeddings_ivfflat
    ON voice_embeddings USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Tenant filter index
CREATE INDEX idx_voice_embeddings_tenant ON voice_embeddings(tenant_id);
```

### 5.2 Voice Enrollment Samples (Temporary)

```sql
CREATE TABLE voice_enrollment_samples (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    tenant_id       UUID NOT NULL,
    sample_number   INTEGER NOT NULL,
    embedding       vector(192) NOT NULL,
    quality_metrics JSONB DEFAULT '{}',
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_voice_sample UNIQUE (user_id, tenant_id, sample_number)
);

-- Cleanup: delete samples older than 1 hour (enrollment should be quick)
CREATE INDEX idx_voice_samples_cleanup ON voice_enrollment_samples(created_at);
```

---

## 6. Security Considerations

### 6.1 Anti-Replay Protection

| Attack | Detection | Mitigation |
|---|---|---|
| **Recorded audio playback** | Spectrogram analysis for codec artifacts | Reject if recording artifacts detected |
| **Synthesized speech (TTS)** | Naturalness scoring | Reject if speech sounds synthetic |
| **Voice conversion** | Spectral analysis | Detect pitch/formant manipulation |
| **Same audio resubmitted** | Audio hash comparison | Reject duplicate audio within 5 minutes |

### 6.2 Challenge-Response

For higher security, use challenge phrases:

```
1. Server generates random phrase: "Seven blue cats jump high"
2. User must speak this specific phrase
3. Server verifies:
   a. Speech content matches phrase (basic ASR check)
   b. Voiceprint matches enrolled user
   c. Audio is live (not recorded)
```

### 6.3 Quality Gates

| Metric | Minimum | Rejection Message |
|---|---|---|
| Duration | 3 seconds | "Recording too short" |
| SNR | 15 dB | "Too much background noise" |
| Speech ratio | 50% | "Not enough speech detected" |
| Clipping | < 1% | "Audio volume too high" |
| Sample rate | 8 kHz (16 kHz preferred) | "Audio quality too low" |

### 6.4 Privacy

- Raw audio is NEVER stored after processing
- Only the 192-dim embedding is persisted
- Embeddings cannot be reversed to reconstruct voice
- Audio is processed in-memory and immediately discarded
- Temporary enrollment samples are auto-deleted after 1 hour

---

## 7. Integration with Identity Core API

### 7.1 Voice Auth Handler

The Identity Core API's `VoiceAuthHandler` delegates to the biometric processor:

```java
@Component
public class VoiceAuthHandler implements AuthMethodHandler {

    private final BiometricServicePort biometricService;

    @Override
    public AuthMethodType getMethodType() {
        return AuthMethodType.VOICE;
    }

    @Override
    public StepResult validate(AuthSession session, AuthFlowStep step, Map<String, Object> data) {
        String audioBase64 = (String) data.get("audio");
        byte[] audioBytes = Base64.getDecoder().decode(audioBase64);

        // Delegate to biometric processor
        VoiceVerificationResult result = biometricService.verifyVoice(
            session.getUserId(), audioBytes
        );

        if (result.isVerified() && result.getConfidence() >= step.getMinConfidence()) {
            return StepResult.success(Map.of(
                "confidence", result.getConfidence(),
                "distance", result.getDistance()
            ));
        }
        return StepResult.failure("Voice verification failed");
    }

    @Override
    public boolean requiresEnrollment() { return true; }

    @Override
    public boolean supportsOffline() { return false; }
}
```

### 7.2 BiometricServicePort Extension

Add voice methods to the existing `BiometricServicePort`:

```java
public interface BiometricServicePort {
    // Existing face methods
    BiometricVerificationResult enrollFace(UUID userId, MultipartFile image);
    BiometricVerificationResult verifyFace(UUID userId, MultipartFile image);

    // New voice methods
    VoiceEnrollmentResult enrollVoiceSample(UUID userId, UUID tenantId, byte[] audio, int sampleNumber);
    VoiceEnrollmentResult finalizeVoiceEnrollment(UUID userId, UUID tenantId);
    VoiceVerificationResult verifyVoice(UUID userId, byte[] audio);
}
```

---

## 8. Client-Side Audio Capture

### 8.1 Web (React)

```typescript
// useVoiceCapture.ts
const useVoiceCapture = () => {
    const mediaRecorderRef = useRef<MediaRecorder | null>(null);
    const chunksRef = useRef<Blob[]>([]);

    const startRecording = async () => {
        const stream = await navigator.mediaDevices.getUserMedia({
            audio: {
                sampleRate: 16000,
                channelCount: 1,
                echoCancellation: true,
                noiseSuppression: true
            }
        });
        const recorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });
        recorder.ondataavailable = (e) => chunksRef.current.push(e.data);
        recorder.start();
        mediaRecorderRef.current = recorder;
    };

    const stopRecording = async (): Promise<Blob> => {
        return new Promise((resolve) => {
            const recorder = mediaRecorderRef.current!;
            recorder.onstop = () => {
                const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
                chunksRef.current = [];
                resolve(blob);
            };
            recorder.stop();
        });
    };

    return { startRecording, stopRecording };
};
```

### 8.2 Android (Kotlin)

```kotlin
// AndroidAudioService.kt
class AndroidAudioService : IAudioService {
    private var recorder: AudioRecord? = null

    override suspend fun startRecording(): Result<Unit> {
        val bufferSize = AudioRecord.getMinBufferSize(
            16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            16000,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
        recorder?.startRecording()
        return Result.success(Unit)
    }

    override suspend fun stopRecording(): Result<ByteArray> {
        // Read buffer, convert to WAV, return bytes
    }
}
```

### 8.3 Desktop (Kotlin)

```kotlin
// DesktopAudioService.kt
class DesktopAudioService : IAudioService {
    private var line: TargetDataLine? = null

    override suspend fun startRecording(): Result<Unit> {
        val format = AudioFormat(16000f, 16, 1, true, false)
        val info = DataLine.Info(TargetDataLine::class.java, format)
        line = AudioSystem.getLine(info) as TargetDataLine
        line?.open(format)
        line?.start()
        return Result.success(Unit)
    }
}
```

---

## 9. Performance Targets

| Metric | Target | Notes |
|---|---|---|
| Embedding extraction | < 200ms | Per audio clip (GPU), < 500ms (CPU) |
| Verification (1:1) | < 300ms | Including audio processing |
| Search (1:N, 1000 users) | < 500ms | pgvector cosine search |
| Enrollment (per sample) | < 500ms | Including quality checks |
| Audio preprocessing | < 100ms | Format conversion + VAD |

### 9.1 GPU Considerations

- ECAPA-TDNN is lightweight (~20MB model)
- Runs efficiently on GTX 1650 (4GB VRAM)
- CPU inference is acceptable for low-traffic (< 500ms)
- Batch processing supported for high-traffic scenarios

---

## 10. Dependencies

### 10.1 Python Packages

```
# Voice recognition
speechbrain>=1.0.0          # ECAPA-TDNN model
torchaudio>=2.0.0           # Audio I/O and transformations

# Audio processing
librosa>=0.10.0             # Feature extraction, resampling
soundfile>=0.12.0           # Audio file reading
pydub>=0.25.1               # Format conversion (uses ffmpeg)

# VAD (Voice Activity Detection)
webrtcvad>=2.0.10           # Google WebRTC VAD (lightweight)

# Quality metrics
numpy>=1.24.0               # Already in project
scipy>=1.10.0               # Signal processing (SNR calculation)
```

### 10.2 System Requirements

```
ffmpeg                      # Audio format conversion (apt-get install ffmpeg)
libsndfile1                 # Audio file support (apt-get install libsndfile1)
```

---

## 11. Enrollment UI Flow

### 11.1 Voice Enrollment Screen

```
┌─────────────────────────────────────────────────┐
│  Voice Enrollment                                │
│                                                   │
│  Step 1 of 3: Record your voice                  │
│                                                   │
│  Please read the following phrase aloud:          │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  "The quick brown fox jumps over the        │ │
│  │   lazy dog near the riverbank"              │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  [===========|                             ]│ │
│  │   Recording: 3.2s                           │ │
│  │   ████████████████░░░░░░░░░░ Volume OK      │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  Quality: ✓ Duration OK  ✓ Low noise  ✓ Speech  │
│                                                   │
│  [■ Stop Recording]            [Next Sample →]   │
│                                                   │
│  Samples: ● ○ ○  (1 of 3)                       │
└─────────────────────────────────────────────────┘
```

### 11.2 Verification Screen

```
┌─────────────────────────────────────────────────┐
│  Voice Verification                              │
│                                                   │
│  Please speak clearly for 3+ seconds:            │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │                                             │ │
│  │          🎙 [Tap to start]                  │ │
│  │                                             │ │
│  │   ░░░░░░░░░░░░░░░░░░░░░░░░ Waiting...     │ │
│  │                                             │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  Speak any sentence naturally.                   │
│  Your voice will be matched against your          │
│  enrolled voiceprint.                            │
│                                                   │
└─────────────────────────────────────────────────┘
```
