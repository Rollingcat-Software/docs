# Voice Speech-to-Text Verification Plan

**Version:** 1.0
**Date:** 2026-04-05
**Status:** Design Document (Pre-Implementation)
**Author:** Ahmet Abdullah Gultekin
**Project:** FIVUCSAS - Face and Identity Verification Using Cloud-Based SaaS
**Organization:** Marmara University - Computer Engineering Department
**Feature ID:** W17

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current Voice Architecture](#2-current-voice-architecture)
3. [Dual Verification Architecture](#3-dual-verification-architecture)
4. [STT Engine Selection](#4-stt-engine-selection)
5. [Passphrase Management](#5-passphrase-management)
6. [Anti-Replay and Liveness](#6-anti-replay-and-liveness)
7. [Integration with Existing System](#7-integration-with-existing-system)
8. [Implementation Phases](#8-implementation-phases)
9. [Risk Assessment](#9-risk-assessment)
10. [Dependencies and Prerequisites](#10-dependencies-and-prerequisites)

---

## 1. Executive Summary

FIVUCSAS currently implements voice biometric authentication using speaker embedding comparison (Resemblyzer, 256-dim). This verifies WHO is speaking but not WHAT they said. By adding Speech-to-Text (STT) verification, we create a dual-factor voice system: the speaker's identity is verified by their voiceprint, and their liveness is verified by recognizing a dynamically generated passphrase. This makes voice replay attacks virtually impossible -- an attacker would need both a perfect voice clone AND real-time synthesis of arbitrary phrases. The system generates a new random passphrase for each authentication attempt, displayed on screen, and verifies both the content match (>85% word accuracy) and speaker match (>0.75 cosine similarity) before granting access.

---

## 2. Current Voice Architecture

### Existing Pipeline

```
+----------------+     +----------------+     +-------------------+
|  Client        | --> |  biometric-    | --> |  PostgreSQL       |
|  (MediaRecorder|     |  processor     |     |  (biometric_db)   |
|   WAV 16kHz)   |     |  (FastAPI)     |     |                   |
+----------------+     +-------+--------+     +-------------------+
                               |
                    +----------+-----------+
                    |                      |
              +-----v------+        +-----v------+
              | Resemblyzer|        | pgvector   |
              | (256-dim   |        | (HNSW      |
              |  embedding)|        |  cosine)   |
              +------------+        +------------+
```

### Current Endpoints

| Endpoint | Method | Function |
|----------|--------|----------|
| `/voice/enroll` | POST | Extract embedding, store in voice_enrollments |
| `/voice/verify` | POST | Compare embedding against enrolled user |
| `/voice/search` | POST | 1:N search across all enrolled voices |
| `/voice/delete` | DELETE | Remove enrollment |

### Current Metrics

- Embedding extraction: 490-585ms
- Verification (1:1): ~600ms total
- Search (1:N): ~800ms for 100 enrollments
- EER: ~3% (with quality-weighted centroids)

---

## 3. Dual Verification Architecture

### Architecture Diagram

```
+------------------------------------------------------------------+
|                         CLIENT                                    |
|                                                                   |
|  +------------------+     +------------------+                    |
|  |  Display         |     |  Record Audio    |                    |
|  |  Passphrase:     |     |  (WAV 16kHz,     |                    |
|  |  "Yedi kirmizi   |     |   3-8 seconds)   |                    |
|  |   balon uctu"    |     |                  |                    |
|  +------------------+     +--------+---------+                    |
|                                    |                              |
+------------------------------------|---------+--------------------+
                                     |         |
                                     v         |
+------------------------------------+---------v--------------------+
|                    BIOMETRIC PROCESSOR                            |
|                                                                   |
|  +------------------+     +------------------+                    |
|  |  Resemblyzer     |     |  Whisper         |                    |
|  |  Speaker Embed   |     |  STT Engine      |                    |
|  |  (WHO said it)   |     |  (WHAT was said) |                    |
|  +--------+---------+     +--------+---------+                    |
|           |                        |                              |
|           v                        v                              |
|  +------------------+     +------------------+                    |
|  |  Speaker Match   |     |  Content Match   |                    |
|  |  cosine >= 0.75  |     |  WER <= 15%      |                    |
|  +--------+---------+     +--------+---------+                    |
|           |                        |                              |
|           +----------+  +----------+                              |
|                      |  |                                         |
|                      v  v                                         |
|              +-------+--+--------+                                |
|              |  DUAL VERDICT     |                                |
|              |  speaker AND      |                                |
|              |  content must     |                                |
|              |  both pass        |                                |
|              +-------------------+                                |
|                                                                   |
+------------------------------------------------------------------+
```

### Verification Decision Matrix

| Speaker Match | Content Match | Verdict | Interpretation |
|--------------|---------------|---------|----------------|
| PASS (>= 0.75) | PASS (WER <= 15%) | VERIFIED | Correct person, correct phrase |
| PASS (>= 0.75) | FAIL (WER > 15%) | REJECTED | Right person, wrong/garbled phrase |
| FAIL (< 0.75) | PASS (WER <= 15%) | REJECTED | Wrong person, right phrase (replay?) |
| FAIL (< 0.75) | FAIL (WER > 15%) | REJECTED | Wrong person, wrong phrase |

### Response Schema

```json
{
  "verified": false,
  "speaker_score": 0.82,
  "speaker_threshold": 0.75,
  "speaker_match": true,
  "content_transcript": "yedi kirmizi balon uctu",
  "content_expected": "yedi kirmizi balon uctu",
  "content_wer": 0.0,
  "content_threshold": 0.15,
  "content_match": true,
  "overall_verdict": "VERIFIED",
  "passphrase_id": "a1b2c3d4",
  "processing_time_ms": 1250
}
```

---

## 4. STT Engine Selection

### Comparison Matrix

| Engine | Deployment | Turkish Support | Latency (3s audio) | Cost | Accuracy (WER) |
|--------|-----------|-----------------|---------------------|------|-----------------|
| **Whisper (small)** | Local | Yes (multi-lingual) | ~800ms (CPU) | Free | ~8% (TR) |
| **Whisper (tiny)** | Local | Yes | ~300ms (CPU) | Free | ~15% (TR) |
| Google STT | Cloud API | Yes (tr-TR) | ~500ms | $0.006/15s | ~5% (TR) |
| Azure STT | Cloud API | Yes (tr-TR) | ~500ms | $1/hr audio | ~5% (TR) |
| Vosk (offline) | Local | Yes (TR model) | ~400ms | Free | ~12% (TR) |

### Recommendation: Whisper Small (Local)

**Rationale:**

1. **Privacy**: Audio never leaves the server; compliant with KVKK/GDPR
2. **Cost**: Zero per-request cost; critical for BaaS rental model viability
3. **Turkish**: Whisper's multi-lingual training includes Turkish with good accuracy
4. **Latency**: 800ms is acceptable when combined with speaker embedding (490ms runs in parallel)
5. **Consistency**: No external API dependency; no rate limits; no outages

**Model size**: ~500 MB (whisper-small). Fits in current 4 GB biometric-api memory budget.

### Whisper Integration

```python
import whisper

# Load once at startup (global singleton)
whisper_model = whisper.load_model("small", device="cpu")

async def transcribe(audio_path: str, language: str = "tr") -> dict:
    result = whisper_model.transcribe(
        audio_path,
        language=language,
        task="transcribe",
        fp16=False,              # CPU mode
        temperature=0.0,         # Deterministic
        no_speech_threshold=0.6
    )
    return {
        "text": result["text"].strip().lower(),
        "language": result["language"],
        "confidence": 1.0 - result.get("no_speech_prob", 0)
    }
```

---

## 5. Passphrase Management

### Passphrase Types

| Type | Example | Use Case |
|------|---------|----------|
| Random words (Turkish) | "mavi kedi pencereden baktı" | Default — high entropy |
| Random numbers | "dört yedi iki dokuz beş" | Simple, language-neutral |
| Challenge question | "bugün hava nasıl" | Conversational liveness |
| Custom (tenant-defined) | "Marmara Bankası hoş geldiniz" | Branded experience |

### Turkish Word Pool

```python
TURKISH_WORD_POOL = {
    "subjects": ["kedi", "köpek", "kuş", "balık", "aslan", "tavşan", "kelebek",
                  "araba", "gemi", "uçak", "tren", "bisiklet"],
    "adjectives": ["kırmızı", "mavi", "yeşil", "büyük", "küçük", "hızlı",
                    "yavaş", "güzel", "eski", "yeni", "sıcak", "soğuk"],
    "numbers": ["bir", "iki", "üç", "dört", "beş", "altı", "yedi",
                "sekiz", "dokuz", "sıfır"],
    "verbs": ["koştu", "uçtu", "yüzdü", "baktı", "güldü", "uyudu",
              "atladı", "döndü", "durdu", "geldi"]
}

def generate_passphrase(word_count: int = 4) -> str:
    """Generate a pronounceable Turkish passphrase.
    4 words from pool of ~50 = ~50^4 = 6.25M combinations.
    """
    pattern = random.choice([
        "{adj} {subj} {verb}",              # "kırmızı kedi koştu"
        "{num} {adj} {subj} {verb}",        # "üç büyük kuş uçtu"
        "{subj} {adj} {subj} {verb}",       # "kedi küçük balık gördü"
    ])
    # ... fill from pool
```

### Passphrase Lifecycle

```
1. Client requests passphrase:
   POST /voice/challenge -> { passphrase_id: "abc", text: "yedi kırmızı balon uçtu", expires_at: +60s }

2. Server stores in Redis:
   SET voice:challenge:abc "yedi kırmızı balon uçtu" EX 60

3. Client displays passphrase, user speaks it

4. Client sends audio + passphrase_id:
   POST /voice/verify-stt { audio: <wav>, passphrase_id: "abc", user_id: "..." }

5. Server:
   a. GET voice:challenge:abc -> expected text (fails if expired/used)
   b. DEL voice:challenge:abc (one-time use)
   c. Run speaker embedding (Resemblyzer) || Run STT (Whisper) in parallel
   d. Compare speaker + content
   e. Return dual verdict
```

---

## 6. Anti-Replay and Liveness

### Why Dual Verification Defeats Replay

| Attack | Speaker-Only | STT-Only | Dual (Ours) |
|--------|-------------|----------|-------------|
| Pre-recorded audio | Passes (same voice) | Passes (if same phrase) | **Fails** (phrase is random each time) |
| Voice cloning (TTS) | May pass (advanced clone) | Passes | **Fails** (clone quality + random phrase timing) |
| Live impersonator | Fails (different voiceprint) | May pass | Fails (different voiceprint) |
| Replay with editing | Passes | Fails (spliced audio artifacts) | Fails (both) |

### Additional Liveness Signals

| Signal | Method | Weight |
|--------|--------|--------|
| Phrase freshness | Passphrase expires in 60s, one-time use | Critical (gate) |
| Audio duration | Must be 2-8 seconds (reject too short/long) | High |
| Speech continuity | No >500ms gaps (detect concatenation) | Medium |
| Background consistency | Whisper noise profile should be uniform | Low |
| Timing | Response within 10s of challenge display | Medium |

### Rate Limiting

```
voice:challenge:{user_id}  -> max 5 challenges per minute
voice:verify:{user_id}     -> max 3 attempts per challenge
voice:lockout:{user_id}    -> 15 min lockout after 5 consecutive failures
```

---

## 7. Integration with Existing System

### VoiceAuthHandler Extension

```java
// identity-core-api: VoiceAuthHandler.java
// Currently:
public class VoiceAuthHandler implements AuthStepHandler {
    @Override
    public AuthStepResult handle(AuthSession session, AuthStepData data) {
        // Calls biometric-processor /voice/verify
        // Returns: speaker match only
    }
}

// After STT integration:
public class VoiceAuthHandler implements AuthStepHandler {
    @Override
    public AuthStepResult handle(AuthSession session, AuthStepData data) {
        String mode = data.getMode(); // "speaker_only" or "speaker_stt"

        if ("speaker_stt".equals(mode)) {
            // 1. Validate passphrase_id not expired
            // 2. Call biometric-processor /voice/verify-stt
            // 3. Check BOTH speaker_match AND content_match
        } else {
            // Existing behavior: speaker embedding only
        }
    }
}
```

### New Biometric Processor Endpoints

```
POST /voice/challenge
  Request:  { language: "tr", word_count: 4 }
  Response: { passphrase_id: "abc123", text: "yedi kirmizi balon uctu", expires_at: "..." }

POST /voice/verify-stt
  Request:  multipart { audio: <wav>, user_id: "...", passphrase_id: "abc123" }
  Response: { verified: bool, speaker_score, content_wer, transcript, ... }
```

### Auth Flow Configuration

Tenants can choose voice verification mode per auth flow:

```json
{
  "auth_flow_steps": [
    {
      "method": "VOICE",
      "config": {
        "mode": "speaker_stt",           // or "speaker_only"
        "passphrase_type": "random_tr",  // or "random_numbers", "custom"
        "word_count": 4,
        "speaker_threshold": 0.75,
        "content_wer_threshold": 0.15
      }
    }
  ]
}
```

### Frontend Changes

```
VoiceStep component (web-app + client-apps):

+----------------------------------------------+
|                                              |
|   Please say the following phrase:           |
|                                              |
|   +--------------------------------------+   |
|   |                                      |   |
|   |    "Yedi kirmizi balon uctu"         |   |
|   |                                      |   |
|   +--------------------------------------+   |
|                                              |
|   [ Recording... 2.3s ]  ||||||||||||        |
|                                              |
|   Speaker Match: 0.87 / 0.75  [PASS]        |
|   Content Match: 0.00 WER     [PASS]        |
|                                              |
|            [Verified]                        |
|                                              |
+----------------------------------------------+
```

---

## 8. Implementation Phases

### Phase 1 — Whisper Integration (1 week)

| Task | Effort | Details |
|------|--------|---------|
| Install Whisper in biometric-processor | 1 day | pip install openai-whisper, download "small" model |
| /voice/challenge endpoint | 1 day | Turkish word pool, Redis storage, expiry |
| /voice/verify-stt endpoint | 2 days | Parallel Resemblyzer + Whisper, dual verdict |
| WER calculation utility | 0.5 day | Levenshtein distance on word arrays |
| Unit tests | 0.5 day | Mock audio, verify scoring logic |

### Phase 2 — Backend Integration (1 week)

| Task | Effort | Details |
|------|--------|---------|
| VoiceAuthHandler STT mode | 1 day | Extend existing handler |
| BiometricServicePort extension | 0.5 day | Add verifySpeakerAndContent method |
| Auth flow step config schema | 0.5 day | mode, passphrase_type, thresholds |
| Rate limiting for voice challenges | 0.5 day | Redis-based per-user limits |
| Integration tests | 1.5 days | End-to-end with test audio files |

### Phase 3 — Frontend (1 week)

| Task | Effort | Details |
|------|--------|---------|
| VoiceStep STT mode (web-app) | 2 days | Passphrase display, dual result UI |
| VoiceStep STT mode (client-apps) | 2 days | KMP shared + Android/iOS/Desktop |
| Auth-test page update | 1 day | Add STT verification section |

### Phase 4 — Hardening (0.5 week)

| Task | Effort | Details |
|------|--------|---------|
| Turkish accent testing | 1 day | Test with various accents, adjust WER threshold |
| Performance optimization | 1 day | Whisper batch mode, model warmup |
| Documentation | 0.5 day | API docs, tenant configuration guide |

### Total Effort: ~3.5 weeks

```
Week 1:     Phase 1 (Whisper integration + endpoints)
Week 2:     Phase 2 (Backend integration + auth flow config)
Week 3:     Phase 3 (Frontend: web-app + client-apps)
Week 3.5:   Phase 4 (Hardening + accent testing)
```

---

## 9. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Whisper Turkish accuracy insufficient | Low | High | Whisper-small has ~8% WER on TR; threshold is 15% (generous margin) |
| Whisper model size (500 MB) exceeds memory | Medium | Medium | Current biometric-api has 4 GB; Whisper + Resemblyzer + DeepFace fit within budget |
| Users cannot pronounce passphrase correctly | Medium | Medium | Allow 3 retries; configurable word_count (fewer words = easier) |
| Noisy environment degrades both speaker and STT | High | Medium | Silero VAD pre-filter; instruct user to find quiet environment |
| Latency: Whisper 800ms + Resemblyzer 500ms | Medium | Low | Run in parallel (not sequential); total ~900ms acceptable |
| Accessibility: deaf/mute users excluded | Low | Medium | Voice STT is optional; tenants can use speaker-only or other auth methods |
| Whisper hallucination on silence | Medium | Low | no_speech_threshold=0.6; reject if confidence < 0.5 |
| Language detection mismatch | Low | Low | Force language="tr" (do not auto-detect) |

---

## 10. Dependencies and Prerequisites

### Technical Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Resemblyzer (speaker embedding) | Deployed | Already in biometric-processor |
| Redis (challenge storage) | Deployed | shared-redis on Hetzner |
| WAV audio capture (client) | Implemented | MediaRecorder in web-app, AudioRecorder in client-apps |
| VoiceAuthHandler | Implemented | identity-core-api, speaker-only mode |
| Whisper Python package | Not installed | `pip install openai-whisper` (~500 MB model download) |

### Infrastructure Impact

| Resource | Current | After STT | Delta |
|----------|---------|-----------|-------|
| biometric-api RAM | ~3.5 GB | ~4.2 GB | +700 MB (Whisper model) |
| biometric-api disk | ~2 GB | ~2.5 GB | +500 MB (model file) |
| Redis keys | ~100 | ~200 (peak) | +100 (voice challenges, 60s TTL) |
| CPU (inference) | Moderate | Higher | Whisper small: ~800ms CPU per request |

### Model Requirements

- Whisper "small" (244M parameters): Best accuracy/speed tradeoff for CPU
- If CPU becomes bottleneck: upgrade to Whisper "tiny" (39M parameters, ~300ms, 15% WER)
- Future: Whisper.cpp for 2x speedup without GPU (C++ implementation)

---

*This feature is a natural extension of the existing voice biometric system. The passphrase-based liveness mechanism provides a significant security improvement with relatively low implementation effort, since Resemblyzer and the voice pipeline are already deployed and tested.*
