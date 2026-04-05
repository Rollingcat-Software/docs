# Client-Side ML Migration Plan (Phase 4.2)

**Version:** 1.0
**Date:** 2026-04-05
**Status:** Design Document (Pre-Implementation)
**Author:** Ahmet Abdullah Gultekin
**Project:** FIVUCSAS - Face and Identity Verification Using Cloud-Based SaaS
**Organization:** Marmara University - Computer Engineering Department

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Architecture Overview](#3-architecture-overview)
4. [Model Catalog](#4-model-catalog)
5. [KMP Inference Strategy](#5-kmp-inference-strategy)
6. [Migration Phases](#6-migration-phases)
7. [Model Training Pipeline (Phase 4.3)](#7-model-training-pipeline-phase-43)
8. [Performance Benchmarks](#8-performance-benchmarks)
9. [Risk Assessment](#9-risk-assessment)
10. [Dependencies and Prerequisites](#10-dependencies-and-prerequisites)

---

## 1. Executive Summary

FIVUCSAS currently performs all biometric inference server-side via the biometric-processor (FastAPI + DeepFace + Resemblyzer). While this provides accurate results, it introduces network latency (490ms-7s per operation), requires constant connectivity, and creates a server bottleneck under load. This document defines the architecture for migrating compute-intensive ML inference to the client side using TFLite (Android), CoreML (iOS), ONNX Runtime (Desktop), and WASM (Browser), while maintaining server-side verification as a trust anchor. The migration targets sub-500ms latency for all biometric operations while preserving backward compatibility with existing API contracts.

---

## 2. Current State Analysis

### Server-Side Inference (Current)

| Operation | Backend | Latency | Model |
|-----------|---------|---------|-------|
| Face detection | biometric-processor | 200-400ms | RetinaFace (DeepFace) |
| Face embedding | biometric-processor | 300-600ms | ArcFace 512-dim |
| Face verify | biometric-processor | 900-1500ms | DeepFace cosine similarity |
| Voice embedding | biometric-processor | 490-585ms | Resemblyzer 256-dim |
| Card detection | biometric-processor | ~7000ms | YOLOv8n ONNX (WASM) |
| Liveness check | biometric-processor | 200-400ms | MediaPipe + heuristics |

### Existing Client-Side Work

- **MediaPipe FaceMesh**: Already running in browser (auth-test page) for landmark detection
- **YOLO ONNX in WASM**: Card detection at 97.1% accuracy, but ~7s/frame (too slow)
- **MobileFaceNet ONNX**: Pipeline exists in auth-test (`computeNeuralEmbedding()`), needs model file
- **Feature branch**: `feature/client-side-ml` merged to master with CLIENT_SIDE_ML_REPORT.md

### Problems with Server-Only Approach

1. **Latency**: 490ms-7000ms per operation, unacceptable for real-time UX
2. **Offline**: No biometric capability without network
3. **Bandwidth**: Sending raw images/audio over the wire
4. **Scalability**: Each concurrent user loads the GPU/CPU server
5. **Privacy**: Raw biometric data traverses the network

---

## 3. Architecture Overview

### Hybrid Client-Server Architecture

```
+------------------------------------------------------------------+
|                        CLIENT DEVICE                              |
|                                                                   |
|  +------------------+  +------------------+  +------------------+ |
|  |  Camera/Mic      |  |  ML Runtime      |  |  Embedding       | |
|  |  Capture Layer   |->|  (TFLite/CoreML/ |->|  Cache           | |
|  |                  |  |   ONNX/WASM)     |  |  (Encrypted)     | |
|  +------------------+  +------------------+  +------------------+ |
|           |                    |                      |           |
|           v                    v                      v           |
|  +------------------+  +------------------+  +------------------+ |
|  |  Quality Gate    |  |  Local Verify    |  |  Sync Manager    | |
|  |  (blur, light,   |  |  (fast path,     |  |  (delta sync,    | |
|  |   pose check)    |  |   threshold)     |  |   conflict res)  | |
|  +------------------+  +------------------+  +------------------+ |
|                                |                      |           |
+--------------------------------|----------------------|-----------+
                                 |                      |
                    +------------|----------------------|-----------+
                    |            v                      v           |
                    |   +------------------+  +------------------+  |
                    |   |  Server Verify   |  |  Enrollment      |  |
                    |   |  (trust anchor,  |  |  Store           |  |
                    |   |   ArcFace 512d)  |  |  (pgvector)      |  |
                    |   +------------------+  +------------------+  |
                    |                  SERVER                        |
                    +-----------------------------------------------+
```

### Inference Distribution Strategy

| Task | Client | Server | Rationale |
|------|--------|--------|-----------|
| Face detection | Primary | Fallback | Real-time UX requires <50ms |
| Face quality | Primary | None | No network needed for blur/light check |
| Face embedding | Primary | Verification | Client for speed, server as trust anchor |
| Face verify | Primary | Secondary | Local fast-path, server confirms critical ops |
| Voice embedding | Primary | Verification | Speaker ID should work offline |
| Card detection | Primary | Fallback | YOLO nano for real-time, server for accuracy |
| Liveness | Client + Server | Final verdict | Client pre-screen, server authoritative |
| 1:N search | None | Primary | Requires full database scan with pgvector |

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Client-first, server-verify | Best UX with maintained security |
| Embeddings sent, not images | Privacy-preserving, bandwidth-efficient |
| Model versioning via manifest | Atomic model updates without app store release |
| Encrypted local cache | Biometric data at rest must be protected |
| Graceful degradation | If client ML fails, fall back to server |

---

## 4. Model Catalog

### 4.1 Face Detection — MediaPipe BlazeFace

| Property | Value |
|----------|-------|
| Format | TFLite (Android), CoreML (iOS), WASM (Browser) |
| Size | ~1.2 MB |
| Latency target | <30ms |
| Input | 128x128 RGB |
| Output | Bounding boxes + 6 keypoints |
| Status | Already deployed in browser via MediaPipe |

### 4.2 Face Embedding — MobileFaceNet

| Property | Value |
|----------|-------|
| Format | TFLite / CoreML / ONNX |
| Size | ~4.9 MB (INT8 quantized) |
| Latency target | <100ms |
| Input | 112x112 aligned face |
| Output | 128-dim L2-normalized embedding |
| Compatibility | Cosine similarity with existing 512-dim ArcFace via projection layer |

**Projection Layer**: Server maintains a learned 128->512 projection matrix to compare client MobileFaceNet embeddings against server ArcFace embeddings. This allows gradual migration without re-enrolling all users.

### 4.3 Voice Embedding — Silero VAD + ECAPA-TDNN Lite

| Property | Value |
|----------|-------|
| Format | TFLite (Android), CoreML (iOS), ONNX (Desktop/Browser) |
| Size | ~8.2 MB (Silero 1.8MB + ECAPA-Lite 6.4MB) |
| Latency target | <200ms for 3-second clip |
| Input | 16kHz mono PCM |
| Output | 192-dim speaker embedding |
| Compatibility | Projection to Resemblyzer 256-dim space |

### 4.4 Card Detection — YOLOv8n Istanbul Card

| Property | Value |
|----------|-------|
| Format | TFLite (Android), CoreML (iOS), ONNX (Desktop/Browser) |
| Size | ~6.2 MB (FP16) |
| Latency target | <500ms (vs current 7000ms) |
| Input | 640x640 RGB |
| Output | Bounding boxes + class (TC Kimlik, Passport, Driver License) |
| Training | Custom dataset (Phase 4.3) |

### 4.5 Passive Liveness — MobileNet-v3 Anti-Spoof

| Property | Value |
|----------|-------|
| Format | TFLite / CoreML / ONNX |
| Size | ~3.1 MB |
| Latency target | <50ms |
| Input | 224x224 face crop |
| Output | real/spoof probability |
| Note | Client pre-screen only; server liveness remains authoritative |

### Model Delivery

```
Model Manifest (JSON, CDN-hosted, versioned):
{
  "version": "2026.04.1",
  "models": {
    "face_detect": { "url": "...", "sha256": "...", "size_bytes": 1200000 },
    "face_embed": { "url": "...", "sha256": "...", "size_bytes": 4900000 },
    "voice_embed": { "url": "...", "sha256": "...", "size_bytes": 8200000 },
    "card_detect": { "url": "...", "sha256": "...", "size_bytes": 6200000 },
    "liveness":    { "url": "...", "sha256": "...", "size_bytes": 3100000 }
  }
}

Total download: ~23.6 MB (one-time, cached)
```

---

## 5. KMP Inference Strategy

### expect/actual Pattern for ML Inference

```
commonMain/
  ml/
    InferenceEngine.kt          // expect class
    ModelManager.kt             // expect class
    FaceEmbedder.kt             // uses InferenceEngine
    VoiceEmbedder.kt            // uses InferenceEngine
    CardDetector.kt             // uses InferenceEngine

androidMain/
  ml/
    InferenceEngine.android.kt  // actual: TensorFlow Lite
    ModelManager.android.kt     // actual: asset extraction + file cache

iosMain/
  ml/
    InferenceEngine.ios.kt      // actual: CoreML via cinterop
    ModelManager.ios.kt         // actual: Bundle + MLModel cache

desktopMain/
  ml/
    InferenceEngine.desktop.kt  // actual: ONNX Runtime (Java binding)
    ModelManager.desktop.kt     // actual: ~/.fivucsas/models/ directory
```

### Platform-Specific Implementation

```
+---------------------+-------------------+-------------------+
|     commonMain      |                   |                   |
|                     |                   |                   |
| expect class        |   androidMain     |     iosMain       |
| InferenceEngine {   | actual class      | actual class      |
|   fun load(model)   | InferenceEngine { | InferenceEngine { |
|   fun run(input)    |   // TFLite       |   // CoreML       |
|   fun close()       |   Interpreter()   |   MLModel()       |
| }                   | }                 | }                 |
|                     |                   |                   |
| expect class        |   desktopMain     |     jsMain        |
| ModelManager {      | actual class      | actual class      |
|   fun download()    | InferenceEngine { | InferenceEngine { |
|   fun getPath()     |   // ONNX Runtime |   // ort-web      |
|   fun validate()    |   OrtSession()    |   InferSession()  |
| }                   | }                 | }                 |
+---------------------+-------------------+-------------------+
```

### Android (TensorFlow Lite)

```kotlin
actual class InferenceEngine {
    private var interpreter: Interpreter? = null

    actual fun load(modelBuffer: ByteArray) {
        val options = Interpreter.Options().apply {
            setNumThreads(4)
            addDelegate(GpuDelegate())  // GPU acceleration
        }
        interpreter = Interpreter(ByteBuffer.wrap(modelBuffer), options)
    }

    actual fun run(input: FloatArray, outputShape: IntArray): FloatArray {
        val output = Array(1) { FloatArray(outputShape[1]) }
        interpreter?.run(arrayOf(input), output)
        return output[0]
    }
}
```

### iOS (CoreML)

```kotlin
actual class InferenceEngine {
    private var model: MLModel? = null

    actual fun load(modelBuffer: ByteArray) {
        // Convert to .mlmodel, compile, load
        val compiledUrl = MLModel.compileModel(at: modelUrl)
        model = MLModel(contentsOf: compiledUrl)
    }

    actual fun run(input: FloatArray, outputShape: IntArray): FloatArray {
        val mlInput = MLMultiArray(shape: ..., dataType: .float32)
        val prediction = model?.prediction(from: mlInput)
        return prediction.featureValue.multiArrayValue.toFloatArray()
    }
}
```

---

## 6. Migration Phases

### Phase 4.2.1 — Face Detection + Quality (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| MediaPipe BlazeFace on all KMP platforms | 3 days | Already works in browser; add Android/iOS/Desktop |
| Quality gate (blur, brightness, pose) | 2 days | Port from biometric-processor heuristics |
| Camera capture abstraction | 2 days | expect/actual for CameraX, AVFoundation, OpenCV |
| Integration tests | 1 day | Compare quality scores: client vs server |
| Backward compat: server fallback | 2 days | If client detection fails, fall back to /detect endpoint |

**Exit criteria**: Face detection <30ms on Pixel 6, iPhone 13, MacBook M1.

### Phase 4.2.2 — Face Embedding + Local Verify (3 weeks)

| Task | Effort | Details |
|------|--------|---------|
| MobileFaceNet model conversion | 2 days | PyTorch -> TFLite + CoreML + ONNX |
| 128->512 projection matrix training | 3 days | Train on existing face_embeddings table |
| Client-side face verification | 3 days | Cosine similarity with local embedding cache |
| Embedding sync manager | 3 days | Delta sync enrolled embeddings to device |
| Encrypted embedding store | 2 days | Android Keystore / iOS Keychain encryption |
| Server verification handshake | 2 days | Client embed + server re-verify for critical ops |

**Exit criteria**: Face verify <150ms locally, <1% FAR deviation from server ArcFace.

### Phase 4.2.3 — Voice Embedding (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| Silero VAD integration | 2 days | Voice activity detection before embedding |
| ECAPA-TDNN Lite conversion | 2 days | PyTorch -> platform models |
| 192->256 projection layer | 2 days | Map to Resemblyzer embedding space |
| Client-side voice verify | 2 days | Local speaker verification |
| Audio preprocessing pipeline | 2 days | Noise reduction, normalization (port from Python) |

**Exit criteria**: Voice verify <250ms on-device, EER within 2% of server Resemblyzer.

### Phase 4.2.4 — Card Detection YOLO Nano (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| YOLOv8n model optimization | 3 days | FP16 quantization, NMS tuning |
| TFLite/CoreML/ONNX conversion | 2 days | Export from Ultralytics |
| Real-time camera overlay | 3 days | Bounding box + guidance arrows |
| OCR handoff pipeline | 2 days | Crop detected card, send to Tesseract endpoint |

**Exit criteria**: Card detection <500ms (vs current 7000ms), mAP@0.5 > 0.90.

### Phase 4.2.5 — Integration + Model Delivery (1 week)

| Task | Effort | Details |
|------|--------|---------|
| Model manifest + CDN hosting | 2 days | Version-pinned model URLs with SHA256 |
| Background model download | 1 day | Download models on first launch, not blocking |
| A/B testing framework | 1 day | Gradual rollout: 10% -> 50% -> 100% client-side |
| Monitoring: client vs server accuracy | 1 day | Log both, compare drift |

### Total Effort: ~10 weeks

```
Week 1-2:   Phase 4.2.1 (Face Detection + Quality)
Week 3-5:   Phase 4.2.2 (Face Embedding + Local Verify)
Week 6-7:   Phase 4.2.3 (Voice Embedding)
Week 8-9:   Phase 4.2.4 (Card Detection YOLO)
Week 10:    Phase 4.2.5 (Integration + Delivery)
```

---

## 7. Model Training Pipeline (Phase 4.3)

### Istanbul Card YOLO Training

**Objective**: Train a custom YOLOv8n model for Turkish identity document detection.

#### Dataset Requirements

| Document Type | Training Images | Validation | Source |
|--------------|----------------|------------|--------|
| TC Kimlik (new) | 800 | 200 | Synthetic + real (redacted) |
| TC Kimlik (old) | 400 | 100 | Synthetic |
| Passport (TR) | 400 | 100 | Synthetic |
| Driver License (TR) | 400 | 100 | Synthetic |
| Negative (no card) | 500 | 125 | Random backgrounds |
| **Total** | **2,500** | **625** |

#### Synthetic Data Generation Pipeline

```
+------------------+     +------------------+     +------------------+
|  Template Cards  | --> |  Augmentation    | --> |  Scene           |
|  (redacted real  |     |  (rotation,      |     |  Composition     |
|   specimens)     |     |   blur, noise,   |     |  (hand holding,  |
|                  |     |   lighting)      |     |   desk, scanner) |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  |  YOLO Format     |
                                                  |  Annotation      |
                                                  |  (auto-labeled)  |
                                                  +------------------+
```

#### Training Configuration

```yaml
# yolov8n-card.yaml
model: yolov8n.pt          # Pretrained COCO nano
data: istanbul-card.yaml
epochs: 100
imgsz: 640
batch: 16
device: 0                  # GTX 1650 (4GB VRAM)
optimizer: AdamW
lr0: 0.001
lrf: 0.01
augment: true
mosaic: 1.0
mixup: 0.1
```

#### Training Infrastructure

- **Local**: GTX 1650 (4GB VRAM) via WSL2 — sufficient for YOLOv8n
- **Estimated training time**: ~4 hours for 100 epochs on 2,500 images
- **Export**: `yolo export model=best.pt format=tflite` (+ coreml, onnx)
- **Validation target**: mAP@0.5 > 0.92, mAP@0.5:0.95 > 0.75

---

## 8. Performance Benchmarks

### Target Latencies (P95)

| Operation | Server (Current) | Client (Target) | Improvement |
|-----------|-----------------|------------------|-------------|
| Face detection | 200-400ms | <30ms | 10x |
| Face quality check | 100-200ms | <20ms | 8x |
| Face embedding | 300-600ms | <100ms | 5x |
| Face verification | 900-1500ms | <150ms | 8x |
| Voice embedding | 490-585ms | <200ms | 3x |
| Card detection | ~7000ms | <500ms | 14x |
| Liveness pre-screen | 200-400ms | <50ms | 6x |

### Model Size Budget

| Model | Raw Size | Quantized | Platform |
|-------|----------|-----------|----------|
| BlazeFace | 1.5 MB | 1.2 MB (INT8) | All |
| MobileFaceNet | 8.4 MB | 4.9 MB (INT8) | All |
| Silero VAD | 1.8 MB | 1.8 MB | All |
| ECAPA-TDNN Lite | 12 MB | 6.4 MB (FP16) | All |
| YOLOv8n Card | 12 MB | 6.2 MB (FP16) | All |
| Liveness MobileNet | 5.4 MB | 3.1 MB (INT8) | All |
| **Total** | **41.1 MB** | **23.6 MB** | |

### Device Compatibility Matrix

| Device Tier | Example | GPU Delegate | Expected FPS (face) |
|-------------|---------|-------------|---------------------|
| High-end | Pixel 8, iPhone 15 | Yes (NNAPI/Metal) | 30+ |
| Mid-range | Pixel 6, iPhone 13 | Yes | 25-30 |
| Low-end | Galaxy A14, iPhone SE | CPU only | 15-20 |
| Desktop | MacBook M1 | ONNX + Metal | 30+ |
| Browser | Chrome 120+ | WebGL/WASM | 10-20 |

---

## 9. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| MobileFaceNet accuracy gap vs ArcFace | Medium | High | Projection matrix + threshold tuning; keep server as trust anchor |
| Model size bloats app (>50MB) | Low | Medium | Lazy loading, on-demand download, INT8 quantization |
| iOS CoreML conversion failures | Medium | Medium | Use coremltools with fallback to ONNX Runtime for iOS |
| Client-side liveness spoofing | High | Critical | Client liveness is pre-screen only; server remains authoritative |
| YOLO training data insufficiency | Medium | Medium | Synthetic augmentation pipeline; start with server fallback |
| Cross-platform embedding drift | Medium | High | Weekly projection matrix recalibration; monitoring dashboard |
| GPU delegate unavailable on low-end | Low | Low | Graceful fallback to CPU with larger latency budget |
| Model IP theft via APK extraction | Medium | Medium | Encrypt model files, obfuscate weights, use on-demand download |

---

## 10. Dependencies and Prerequisites

### Technical Prerequisites

| Prerequisite | Status | Blocking Phase |
|-------------|--------|----------------|
| MediaPipe KMP wrapper | Exists (browser only) | 4.2.1 |
| TFLite Gradle dependency | Not added | 4.2.1 |
| CoreML cinterop for KMP | Not built | 4.2.1 |
| ONNX Runtime Java binding | Available (Maven) | 4.2.1 |
| MobileFaceNet pretrained weights | Available (InsightFace) | 4.2.2 |
| Face alignment pipeline (client-side) | Not built | 4.2.2 |
| ECAPA-TDNN Lite weights | Available (SpeechBrain) | 4.2.3 |
| Istanbul card training dataset | Not collected | 4.2.4 |
| CDN for model hosting | Not provisioned | 4.2.5 |

### Team Skills Required

- ML model conversion (PyTorch -> TFLite/CoreML/ONNX)
- KMP platform-specific development (expect/actual)
- YOLO training and hyperparameter tuning
- Performance profiling on mobile devices

### Hardware Required

- Android test devices (low-end + high-end)
- iOS test device (iPhone 13+ for CoreML Neural Engine)
- GTX 1650 for YOLO training (already available via WSL2)

---

*This document should be reviewed and updated after each migration phase is completed. Performance benchmarks should be re-measured on actual devices, not emulators.*
