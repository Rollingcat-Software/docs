# Biometric Engine Architecture: Browser TypeScript Port

**Version:** 2.0
**Date:** 2026-03-19
**Status:** Design Document (Pre-Implementation)
**Source of Truth:** `biometric-processor/demo_local_fast.py` (2551 lines)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture Diagram](#2-system-architecture-diagram)
3. [Design Principles and Naming Conventions](#3-design-principles-and-naming-conventions)
4. [Component Priority Tiers](#4-component-priority-tiers)
5. [Engine Classes — Direct Port Mapping](#5-engine-classes--direct-port-mapping)
   - 5a. [BiometricEngine (Orchestrator)](#5a-biometricengine-orchestrator)
   - 5b. [FrameProcessor](#5b-frameprocessor)
   - 5c. [EnrollmentController](#5c-enrollmentcontroller)
   - 5d. [FaceMetricsCalculator (Shared)](#5d-facemetricscalculator-shared)
   - 5e. [FaceDetector](#5e-facedetector)
   - 5f. [QualityAssessor](#5f-qualityassessor)
   - 5g. [PassiveLivenessDetector](#5g-passivelivenessdetector)
   - 5h. [BiometricPuzzle (Strategy Pattern)](#5h-biometricpuzzle-strategy-pattern)
   - 5i. [HeadPoseEstimator](#5i-headposeestimator)
   - 5j. [FaceTracker](#5j-facetracker)
   - 5k. [EmbeddingComputer](#5k-embeddingcomputer)
   - 5l. [CardDetector](#5l-carddetector)
   - 5m. [VoiceProcessor](#5m-voiceprocessor)
6. [Type Definitions](#6-type-definitions)
7. [Enrollment State Machine](#7-enrollment-state-machine)
8. [Error Handling Strategy](#8-error-handling-strategy)
9. [React Hook Contracts](#9-react-hook-contracts)
10. [Auth-Test Adapter](#10-auth-test-adapter)
11. [Testing Strategy](#11-testing-strategy)
12. [Migration Plan](#12-migration-plan)
13. [Browser API Compatibility](#13-browser-api-compatibility)
14. [Performance Budgets](#14-performance-budgets)
15. [Threshold Reference Table](#15-threshold-reference-table)
16. [Versioning](#16-versioning)

---

## 1. Executive Summary

### Goal

Port the complete biometric engine from `demo_local_fast.py` to a browser-native TypeScript library. The Python demo is the gold standard — it runs at 20-30+ FPS with face detection, quality assessment, passive liveness, active liveness (14-challenge puzzle), head pose estimation, face tracking, embedding extraction, and card detection. The TypeScript port must replicate all of this logic client-side with zero server round-trips for real-time operations.

### Consumers

The engine serves three consumers through a layered architecture:

| Consumer | Integration Style | Framework |
|----------|------------------|-----------|
| **web-app** (React dashboard) | React hooks wrapping engine classes | React 18 + TypeScript |
| **auth-test page** | Direct ES module import or IIFE bundle | Vanilla JS/HTML |
| **client-apps** (KMP JS target) | ES module import (future) | Kotlin/JS |

### Design Principles

- **Framework-agnostic core**: The engine is pure TypeScript with zero React/framework imports. All classes use standard browser APIs only.
- **Thin integration layer**: React hooks are lightweight wrappers (~50 lines each) that connect engine classes to React state.
- **1:1 Python parity**: Every threshold, formula, landmark index, and algorithm from `demo_local_fast.py` is preserved exactly. Deviations are documented with rationale.
- **Progressive loading**: Heavy models (ONNX, MediaPipe) load lazily on first use. The engine is usable immediately for lightweight operations.
- **Dependency Inversion**: All components depend on interfaces, not concrete implementations. The orchestrator accepts injected dependencies via a builder.
- **Single Responsibility**: Each class has one reason to change. The orchestrator does not own the frame loop or enrollment flow.
- **Open/Closed**: New puzzle challenges can be added by implementing a `ChallengeDetector` interface and registering it, without modifying any existing code.

### What Changes from Current Web-App

The current web-app has scattered biometric logic across multiple hooks:

| Current File | Lines | Status |
|-------------|-------|--------|
| `useFaceDetection.ts` | 195 | Uses MediaPipe FaceDetector (detection only, no landmarks) |
| `useQualityAssessment.ts` | 196 | Canvas-based blur/brightness (no face crop) |
| `useFaceChallenge.ts` | 279 | 5 enrollment stages (position, frontal, turn, blink) — uses confidence-dip blink detection |
| `useLivenessPuzzle.ts` | 501 | 8 challenge types via FaceLandmarker, server-driven flow |
| `useCardDetection.ts` | 100 | Server-side YOLO (round-trip to biometric-processor) |
| `BiometricService.ts` | 192 | Server API client (enroll, verify, search, liveness) |

After migration, all real-time detection logic moves into the engine library. The hooks become thin state adapters. `BiometricService.ts` remains for server-side operations (enrollment persistence, verification against database).

---

## 2. System Architecture Diagram

```
+===========================================================================+
|                          BROWSER ENVIRONMENT                               |
+===========================================================================+
|                                                                            |
|  +-------------------------------+  +----------------------------------+  |
|  |        UI LAYER               |  |        UI LAYER                  |  |
|  |  (React Components)           |  |  (Vanilla HTML/JS)              |  |
|  |                               |  |                                  |  |
|  |  FaceCaptureStep.tsx          |  |  auth-test/index.html           |  |
|  |  FaceEnrollmentFlow.tsx       |  |  auth-test/app.js               |  |
|  |  LivenessPuzzleDialog.tsx     |  |                                  |  |
|  +-------------------------------+  +----------------------------------+  |
|          |                                     |                           |
|          v                                     v                           |
|  +-------------------------------+  +----------------------------------+  |
|  |   INTEGRATION LAYER           |  |   INTEGRATION LAYER              |  |
|  |  (React Hooks)                |  |  (Vanilla Adapter)               |  |
|  |                               |  |                                  |  |
|  |  useBiometricEngine()         |  |  BiometricEngineAdapter          |  |
|  |  useFaceDetection(engine)     |  |    .onFaceDetected(cb)           |  |
|  |  useLivenessPuzzle(engine)    |  |    .onQualityUpdate(cb)          |  |
|  |  useFaceEnrollment(engine)    |  |    .onPuzzleProgress(cb)         |  |
|  |  useVoiceRecorder()           |  |    .onCardDetected(cb)           |  |
|  |  useCardDetection(engine)     |  |                                  |  |
|  +-------------------------------+  +----------------------------------+  |
|          |                                     |                           |
|          +------------------+------------------+                           |
|                             |                                              |
|                             v                                              |
|  +=====================================================================+  |
|  |                    ENGINE LAYER (Pure TypeScript)                     |  |
|  |                    Package: @fivucsas/biometric-engine               |  |
|  |                                                                      |  |
|  |  Orchestrator:                                                       |  |
|  |  +-------------------+  +---------------------+  +----------------+  |  |
|  |  | BiometricEngine   |  | FrameProcessor      |  | Enrollment     |  |  |
|  |  | (Config/Dispose)  |  | (Detection Loop)    |  | Controller     |  |  |
|  |  +-------------------+  +---------------------+  +----------------+  |  |
|  |                                                                      |  |
|  |  P0 (Required):                                                      |  |
|  |  +-------------------+  +--------------------+  +-----------------+  |  |
|  |  | FaceDetector      |  | QualityAssessor    |  | BiometricPuzzle |  |  |
|  |  | (MediaPipe)       |  | (Canvas)           |  | (14 challenges) |  |  |
|  |  +-------------------+  +--------------------+  +-----------------+  |  |
|  |  +-------------------+  +--------------------+                       |  |
|  |  | HeadPoseEstimator |  | FaceMetrics        |                       |  |
|  |  | (Geometry)        |  | Calculator (DRY)   |                       |  |
|  |  +-------------------+  +--------------------+                       |  |
|  |                                                                      |  |
|  |  P1 (Important):                                                     |  |
|  |  +-------------------+  +--------------------+                       |  |
|  |  | FaceTracker       |  | VoiceProcessor     |                       |  |
|  |  | (Centroid)        |  | (Web Audio API)    |                       |  |
|  |  +-------------------+  +--------------------+                       |  |
|  |                                                                      |  |
|  |  P2 (Enhancement — deferrable to Phase 3+):                          |  |
|  |  +-------------------+  +--------------------+  +-----------------+  |  |
|  |  | PassiveLiveness   |  | EmbeddingComputer  |  | CardDetector    |  |  |
|  |  | Detector          |  | (MobileFaceNet)    |  | (ONNX YOLO)    |  |  |
|  |  +-------------------+  +--------------------+  +-----------------+  |  |
|  +=====================================================================+  |
|                             |                                              |
|                             v                                              |
|  +=====================================================================+  |
|  |                    BROWSER API LAYER                                  |  |
|  |                                                                      |  |
|  |  MediaPipe Vision Tasks    getUserMedia     Web Audio API            |  |
|  |  (FaceLandmarker)          (WebRTC)         (AudioContext)           |  |
|  |                                                                      |  |
|  |  ONNX Runtime Web          Canvas 2D        WebGL                   |  |
|  |  (WASM backend)            (image proc)     (GPU accel)             |  |
|  +=====================================================================+  |
|                                                                            |
+============================================================================+
                             |
                             v (server calls only for persist/verify)
                  +------------------------+
                  |  BiometricService.ts    |
                  |  (REST API Client)      |
                  |  - enrollFace()         |
                  |  - verifyFace()         |
                  |  - searchFace()         |
                  |  - checkLiveness()      |
                  +------------------------+
                             |
                             v
                  +------------------------+
                  | biometric-processor    |
                  | (FastAPI, port 8001)   |
                  +------------------------+
```

### Data Flow: Real-Time Detection Loop

```
Camera Frame (getUserMedia)
    |
    v
FrameProcessor.processFrame(videoFrame)
    |
    +---> FaceDetector.detect(videoFrame)           ~15-25ms
    |
    +---> FaceTracker.update(detections)             ~1ms
    |
    +---> For each tracked face:
    |       |
    |       +---> FaceMetricsCalculator.calculateAll(landmarks)  ~1ms
    |       +---> QualityAssessor.assess(faceROI)                ~5-10ms
    |       +---> HeadPoseEstimator.estimate(landmarks)          ~2ms
    |       +---> PassiveLivenessDetector.check(faceROI)         ~3-5ms  [P2]
    |       +---> BiometricPuzzle.checkChallenge(...)             ~1ms
    |
    +---> Emit results via callbacks / state update
    |
    v
Total: <50ms per frame (20+ FPS)
```

---

## 3. Design Principles and Naming Conventions

### SOLID Compliance

| Principle | How It Is Applied |
|-----------|-------------------|
| **Single Responsibility** | `BiometricEngine` is configuration/disposal only. `FrameProcessor` owns the detection loop. `EnrollmentController` owns multi-angle enrollment. Each component has one reason to change. |
| **Open/Closed** | `BiometricPuzzle` uses a `ChallengeDetector` strategy interface with a registry. New challenge types are added by implementing the interface and calling `registerDetector()`, with zero changes to existing code. |
| **Liskov Substitution** | All component interfaces (`IFaceDetector`, `IQualityAssessor`, etc.) define contracts that any implementation must honor. Mock implementations substitute freely in tests. |
| **Interface Segregation** | Consumers depend on narrow interfaces. The React hook layer sees only `FrameResult` and control methods. The auth-test adapter sees only callbacks. |
| **Dependency Inversion** | `BiometricEngine` accepts `IBiometricEngineConfig` with interface-typed dependencies. A `BiometricEngineBuilder` provides defaults while allowing mock injection for tests. |

### DRY Compliance

Face metric calculations (EAR, MAR, smile, eyebrow raise) are implemented once in `FaceMetricsCalculator`. Both `BiometricPuzzle` and `FrameProcessor` depend on this shared calculator instead of duplicating the logic.

### KISS — Optional Complexity

Components are tiered by priority (see Section 4). P2 components (PassiveLivenessDetector's Gabor convolution, EmbeddingComputer, CardDetector) are marked as deferrable. Server-side liveness is the primary authority; client-side passive liveness is a supplementary signal only.

### Naming Conventions

| Category | Convention | Examples |
|----------|-----------|----------|
| Classes | PascalCase | `BiometricEngine`, `FaceDetector`, `FrameProcessor` |
| Interfaces | I-prefix + PascalCase | `IFaceDetector`, `IQualityAssessor`, `IChallengeDetector` |
| Type aliases / data types | PascalCase | `FaceDetection`, `QualityReport`, `HeadPose` |
| Constants | UPPER_SNAKE_CASE | `EAR_THRESHOLD`, `LEFT_EYE`, `HOLD_DURATION` |
| Methods | camelCase | `detectFace()`, `calculateEAR()`, `processFrame()` |
| Files — classes | PascalCase | `FaceDetector.ts`, `BiometricPuzzle.ts` |
| Files — utilities | kebab-case | `image-utils.ts`, `gabor-kernels.ts` |
| Enums | PascalCase name, UPPER_SNAKE members | `enum ChallengeType { BLINK, SMILE }` |

These conventions match the existing web-app codebase.

---

## 4. Component Priority Tiers

Each component has a priority tier that determines when it must be implemented:

### P0 — Required (Phase 1-2)

Must be present for any biometric operation. Without these, the engine cannot function.

| Component | Responsibility |
|-----------|---------------|
| `FaceDetector` | MediaPipe face detection + 478-point landmarks |
| `QualityAssessor` | Blur, brightness, size scoring |
| `BiometricPuzzle` | 14-challenge active liveness |
| `HeadPoseEstimator` | Geometric yaw/pitch from landmarks |
| `FaceMetricsCalculator` | Shared EAR, MAR, smile, eyebrow calculations |
| `FrameProcessor` | Detection loop orchestration |
| `EnrollmentController` | Multi-angle enrollment state machine |

### P1 — Important (Phase 2-3)

Needed for production quality but the engine can start without them.

| Component | Responsibility |
|-----------|---------------|
| `FaceTracker` | Centroid-based multi-face tracking with IDs |
| `VoiceProcessor` | Web Audio recording + WAV conversion |

### P2 — Enhancement (Phase 3+, deferrable)

Nice to have. Server-side alternatives exist for all of these.

| Component | Responsibility | Server Fallback |
|-----------|---------------|-----------------|
| `PassiveLivenessDetector` | Texture/color/moire liveness scoring | Server-side liveness via `biometric-processor` is the primary authority. Client-side is supplementary. Gabor convolution is expensive; defer to Phase 3. |
| `EmbeddingComputer` | ONNX MobileFaceNet face embeddings | Server-side DeepFace embedding via REST API |
| `CardDetector` | ONNX YOLO card detection | Server-side YOLO (current production path) |

---

## 5. Engine Classes — Direct Port Mapping

### 5a. BiometricEngine (Orchestrator)

**Python source:** `FastBiometricDemo` class (lines 1227-2537)
**Pattern:** Singleton with dependency injection via Builder
**Responsibility:** Configuration, lifecycle management, and component wiring. Does NOT own the frame loop or enrollment flow.

```typescript
// ===== Interfaces for Dependency Inversion =====

interface IFaceDetector {
  initialize(): Promise<void>;
  dispose(): void;
  detect(video: HTMLVideoElement, timestamp: number): FaceDetection[];
  isAvailable(): boolean;
}

interface IQualityAssessor {
  assess(faceImageData: ImageData): QualityReport;
  isAvailable(): boolean;
}

interface IPassiveLivenessDetector {
  check(faceImageData: ImageData): LivenessResult;
  isAvailable(): boolean;
}

interface IHeadPoseEstimator {
  estimate(landmarks: PixelLandmark[], frameSize: { width: number; height: number }): HeadPose;
  isAvailable(): boolean;
}

interface IFaceTracker {
  update(detections: FaceDetection[]): Map<number, FaceDetection>;
  isAvailable(): boolean;
}

interface IBiometricPuzzle {
  start(challengeTypes?: ChallengeType[], numChallenges?: number): void;
  stop(): void;
  getCurrentChallenge(): ChallengeInfo | null;
  checkChallenge(
    landmarks: NormalizedLandmark[],
    yaw: number,
    pitch: number,
  ): ChallengeCheckResult;
  isAvailable(): boolean;
}

interface IEmbeddingComputer {
  initialize(modelUrl: string): Promise<void>;
  dispose(): void;
  extract(faceImageData: ImageData): Promise<Float32Array | null>;
  isAvailable(): boolean;
}

interface ICardDetector {
  initialize(modelUrl: string): Promise<void>;
  dispose(): void;
  detect(video: HTMLVideoElement, useSmoothing?: boolean): Promise<CardDetectionResult>;
  isAvailable(): boolean;
}

interface IVoiceProcessor {
  startRecording(): Promise<void>;
  stopRecording(): Promise<Blob>;
  dispose(): void;
  isAvailable(): boolean;
}

interface IFaceMetricsCalculator {
  calculateEAR(landmarks: NormalizedLandmark[], eyeIndices: number[]): number;
  calculateMAR(landmarks: NormalizedLandmark[]): number;
  calculateSmile(landmarks: NormalizedLandmark[]): SmileMetrics;
  calculateEyebrowRaise(landmarks: NormalizedLandmark[], baseline?: EyebrowBaseline): EyebrowMetrics;
  calculateAll(landmarks: NormalizedLandmark[], baseline?: EyebrowBaseline): FaceMetrics;
}

// ===== Configuration Interface =====

interface IBiometricEngineConfig {
  faceDetector?: IFaceDetector;
  qualityAssessor?: IQualityAssessor;
  livenessDetector?: IPassiveLivenessDetector;
  headPoseEstimator?: IHeadPoseEstimator;
  faceTracker?: IFaceTracker;
  puzzle?: IBiometricPuzzle;
  embeddingComputer?: IEmbeddingComputer;
  cardDetector?: ICardDetector;
  voiceProcessor?: IVoiceProcessor;
  metricsCalculator?: IFaceMetricsCalculator;
}

// ===== Builder Pattern =====

class BiometricEngineBuilder {
  private config: IBiometricEngineConfig = {};

  withFaceDetector(detector: IFaceDetector): this {
    this.config.faceDetector = detector;
    return this;
  }
  withQualityAssessor(assessor: IQualityAssessor): this {
    this.config.qualityAssessor = assessor;
    return this;
  }
  withLivenessDetector(detector: IPassiveLivenessDetector): this {
    this.config.livenessDetector = detector;
    return this;
  }
  withHeadPoseEstimator(estimator: IHeadPoseEstimator): this {
    this.config.headPoseEstimator = estimator;
    return this;
  }
  withFaceTracker(tracker: IFaceTracker): this {
    this.config.faceTracker = tracker;
    return this;
  }
  withPuzzle(puzzle: IBiometricPuzzle): this {
    this.config.puzzle = puzzle;
    return this;
  }
  withEmbeddingComputer(computer: IEmbeddingComputer): this {
    this.config.embeddingComputer = computer;
    return this;
  }
  withCardDetector(detector: ICardDetector): this {
    this.config.cardDetector = detector;
    return this;
  }
  withVoiceProcessor(processor: IVoiceProcessor): this {
    this.config.voiceProcessor = processor;
    return this;
  }
  withMetricsCalculator(calculator: IFaceMetricsCalculator): this {
    this.config.metricsCalculator = calculator;
    return this;
  }

  build(): BiometricEngine {
    return new BiometricEngine(this.config);
  }
}

// ===== Orchestrator (SRP: config + lifecycle only) =====

class BiometricEngine {
  // Singleton
  private static instance: BiometricEngine | null = null;
  static getInstance(config?: IBiometricEngineConfig): BiometricEngine;
  static destroy(): void;

  // Sub-components (injected or default, lazy-initialized)
  readonly faceDetector: IFaceDetector;
  readonly qualityAssessor: IQualityAssessor;
  readonly livenessDetector: IPassiveLivenessDetector;
  readonly headPoseEstimator: IHeadPoseEstimator;
  readonly faceTracker: IFaceTracker;
  readonly puzzle: IBiometricPuzzle;
  readonly embeddingComputer: IEmbeddingComputer;
  readonly cardDetector: ICardDetector;
  readonly voiceProcessor: IVoiceProcessor;
  readonly metricsCalculator: IFaceMetricsCalculator;

  // Separated concerns (SRP)
  readonly frameProcessor: FrameProcessor;
  readonly enrollmentController: EnrollmentController;

  // State
  readonly isReady: boolean;

  // Lifecycle (ONLY responsibility of BiometricEngine)
  constructor(config?: IBiometricEngineConfig);
  async initialize(): Promise<void>;  // Load MediaPipe models
  dispose(): void;                     // Release all resources
}
```

**Key differences from Python:**
- No OpenCV window management or keyboard handling (browser handles UI)
- No video capture management (browser provides `HTMLVideoElement`)
- Frame processing is delegated to `FrameProcessor` (SRP)
- Enrollment flow is delegated to `EnrollmentController` (SRP)
- All dependencies are injected via interfaces (DIP)
- Builder provides convenient construction with defaults
- Profiler is replaced by browser `performance.mark()`/`performance.measure()`

### 5b. FrameProcessor

**Responsibility:** Runs the per-frame detection loop. Emits `FrameResult` per frame. Does NOT own any sub-components; they are injected.

```typescript
class FrameProcessor {
  private running: boolean = false;
  private animationFrameId: number | null = null;

  constructor(
    private faceDetector: IFaceDetector,
    private faceTracker: IFaceTracker,
    private qualityAssessor: IQualityAssessor,
    private headPoseEstimator: IHeadPoseEstimator,
    private metricsCalculator: IFaceMetricsCalculator,
    private livenessDetector?: IPassiveLivenessDetector,
  );

  /**
   * Start continuous detection loop using requestAnimationFrame.
   * Calls processFrame() each frame, emits results via callback.
   */
  start(video: HTMLVideoElement, onResult: (result: FrameResult) => void): void;

  /**
   * Stop the detection loop.
   */
  stop(): void;

  /**
   * Process a single frame. Called by start() or manually.
   * Runs: detect -> track -> metrics -> quality -> pose -> liveness
   */
  processFrame(video: HTMLVideoElement): FrameResult;

  readonly fps: number;
  readonly isRunning: boolean;
}
```

### 5c. EnrollmentController

**Responsibility:** Manages the multi-angle enrollment state machine (see Section 7). Orchestrates puzzle phase and capture phase. Does NOT perform detection; it consumes `FrameResult` from `FrameProcessor`.

```typescript
class EnrollmentController {
  constructor(
    private puzzle: IBiometricPuzzle,
    private headPoseEstimator: IHeadPoseEstimator,
    private qualityAssessor: IQualityAssessor,
    private metricsCalculator: IFaceMetricsCalculator,
    private embeddingComputer?: IEmbeddingComputer,
  );

  // Control
  start(name: string): void;
  cancel(): void;

  // Per-frame update (fed from FrameProcessor output)
  update(frameResult: FrameResult): EnrollmentUpdate;

  // State (read-only)
  readonly state: EnrollmentState;
  readonly currentPose: EnrollmentPose | null;
  readonly step: number;
  readonly totalSteps: number;
  readonly captures: EnrollmentCapture[];

  // Event callbacks
  onCapture: ((step: number, total: number, pose: string) => void) | null;
  onComplete: ((result: EnrollmentResult) => void) | null;
  onFailed: ((reason: string) => void) | null;
}

type EnrollmentState =
  | 'IDLE'
  | 'PUZZLE_ACTIVE'
  | 'CAPTURE_STRAIGHT'
  | 'CAPTURE_LEFT'
  | 'CAPTURE_RIGHT'
  | 'CAPTURE_UP'
  | 'CAPTURE_DOWN'
  | 'SUBMITTING'
  | 'COMPLETE'
  | 'FAILED';
```

### 5d. FaceMetricsCalculator (Shared)

**Responsibility:** Single implementation of all face metric calculations. Both `BiometricPuzzle` and `FrameProcessor` depend on this, eliminating duplicate EAR/MAR/smile/eyebrow logic (DRY).

**Python source:** Extracted from `BiometricPuzzle.calculate_ear()` (lines 575-597), `calculate_mar()` (lines 600-620), `calculate_smile()` (lines 622-665), `calculate_eyebrow_raise()` (lines 667-700).

```typescript
class FaceMetricsCalculator implements IFaceMetricsCalculator {
  // --- MediaPipe Face Mesh Landmark Indices (lines 462-473) ---
  static readonly LEFT_EYE  = [362, 385, 387, 263, 373, 380];
  static readonly RIGHT_EYE = [33, 160, 158, 133, 153, 144];
  static readonly UPPER_LIP = 13;
  static readonly LOWER_LIP = 14;
  static readonly MOUTH_LEFT = 61;
  static readonly MOUTH_RIGHT = 291;
  static readonly LEFT_EYEBROW  = [70, 63, 105, 66, 107];
  static readonly RIGHT_EYEBROW = [300, 293, 334, 296, 336];
  static readonly LEFT_EYE_CENTER  = 468;  // iris landmark
  static readonly RIGHT_EYE_CENTER = 473;  // iris landmark
  static readonly NOSE_TIP = 1;
  static readonly CHIN = 152;

  /**
   * Eye Aspect Ratio (EAR)
   * Python: calculate_ear() (lines 575-597)
   *
   * EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
   *
   * For LEFT_EYE [362, 385, 387, 263, 373, 380]:
   *   p1=362 (outer), p2=385 (upper-outer), p3=387 (upper-inner),
   *   p4=263 (inner), p5=373 (lower-inner), p6=380 (lower-outer)
   *
   * For RIGHT_EYE [33, 160, 158, 133, 153, 144]:
   *   p1=33 (outer), p2=160 (upper-outer), p3=158 (upper-inner),
   *   p4=133 (inner), p5=153 (lower-inner), p6=144 (lower-outer)
   *
   * Low EAR = closed, High EAR = open
   * Default open: 0.3 if horizontal distance is 0
   */
  calculateEAR(landmarks: NormalizedLandmark[], eyeIndices: number[]): number;

  /**
   * Mouth Aspect Ratio (MAR)
   * Python: calculate_mar() (lines 600-620)
   *
   * MAR = |lower_lip - upper_lip| / |mouth_right - mouth_left|
   * Uses landmarks: UPPER_LIP(13), LOWER_LIP(14), MOUTH_LEFT(61), MOUTH_RIGHT(291)
   */
  calculateMAR(landmarks: NormalizedLandmark[]): number;

  /**
   * Smile Detection
   * Python: calculate_smile() (lines 622-665)
   *
   * Returns: { cornerRaise: number, widthRatio: number }
   *
   * cornerRaise = avg(mouth_center_y - corner_y) / face_height
   *   where mouth_center_y = (upper_lip_y + lower_lip_y) / 2
   *   face_height = |chin - nose_tip|
   *   Positive = corners raised above center (smiling)
   *
   * widthRatio = |mouth_right - mouth_left| / face_height
   *
   * SMILE detected when:
   *   cornerRaise > SMILE_CORNER_THRESHOLD (0.05)
   *   AND widthRatio > SMILE_WIDTH_THRESHOLD (0.60)
   */
  calculateSmile(landmarks: NormalizedLandmark[]): SmileMetrics;

  /**
   * Eyebrow Raise Detection
   * Python: calculate_eyebrow_raise() (lines 667-700)
   *
   * Returns: { bothRatio: number, leftRatio: number, rightRatio: number }
   * All values are ratios relative to baseline (1.0 = no change).
   *
   * left_dist = avg(LEFT_EYE[i].y) - avg(LEFT_EYEBROW[i].y)
   * right_dist = avg(RIGHT_EYE[i].y) - avg(RIGHT_EYEBROW[i].y)
   *
   * NOTE on coordinate system:
   *   MediaPipe Y increases downward. Eye is below eyebrow.
   *   So eye_y > eyebrow_y, and dist = eye_y - eyebrow_y > 0.
   *   When eyebrow raises, eyebrow_y decreases, dist increases.
   *
   * First call sets baseline. Subsequent calls return ratio to baseline.
   *
   * NOTE on mirroring:
   *   MediaPipe LEFT_EYE = anatomical left = user's left eye.
   *   In mirrored camera, user's left appears on LEFT of screen.
   *   Python swaps at check time (line 729-730):
   *     user_left_ear = right_ear (MediaPipe RIGHT = user's LEFT)
   *   BUT for eyebrows, Python uses LEFT_EYEBROW directly for "left"
   *   because the calculate function already works in user-perspective.
   */
  calculateEyebrowRaise(landmarks: NormalizedLandmark[], baseline?: EyebrowBaseline): EyebrowMetrics;

  /**
   * Calculate all metrics in one pass.
   * Returns a complete FaceMetrics object.
   * Used by both FrameProcessor (for TrackedFace) and BiometricPuzzle (for challenge detection).
   */
  calculateAll(landmarks: NormalizedLandmark[], baseline?: EyebrowBaseline): FaceMetrics;
}
```

### 5e. FaceDetector

**Python source:** `FastFaceDetector` class (lines 144-325)

```typescript
class FaceDetector implements IFaceDetector {
  private landmarker: FaceLandmarker | null = null;
  private ready: boolean = false;

  async initialize(): Promise<void>;
  dispose(): void;
  isAvailable(): boolean;

  /**
   * Detect faces and return 478-point landmarks.
   * Uses MediaPipe FaceLandmarker (Tasks API) in VIDEO mode.
   *
   * Python equivalent: FastFaceDetector.detect() + detect_landmarks()
   * Combined into one call because browser MediaPipe FaceLandmarker
   * returns both detection AND landmarks in a single inference.
   */
  detect(video: HTMLVideoElement, timestamp: number): FaceDetection[];
}
```

**Browser implementation notes:**
- Uses `@mediapipe/tasks-vision` package (`FaceLandmarker`, not `FaceDetector`)
- FaceLandmarker returns both bounding box AND 478 landmarks in one pass
  (Python uses separate detector + FaceMesh; browser combines them)
- Model: `face_landmarker.task` loaded from CDN or local bundle
- Running mode: `VIDEO` for continuous detection
- GPU delegate preferred, WASM fallback

**MediaPipe initialization (matches Python lines 1318-1365):**
```typescript
const vision = await FilesetResolver.forVisionTasks(
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm'
);
const landmarker = await FaceLandmarker.createFromOptions(vision, {
  baseOptions: {
    modelAssetPath: 'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
    delegate: 'GPU',
  },
  runningMode: 'VIDEO',
  numFaces: 5,           // Python: max_num_faces=5
  outputFaceBlendshapes: false,
  outputFacialTransformationMatrixes: false,
});
```

### 5f. QualityAssessor

**Python source:** `FastQualityAssessor` class (lines 332-366)

```typescript
class QualityAssessor implements IQualityAssessor {
  private blurThreshold: number;  // Default: 100.0

  constructor(blurThreshold?: number);
  isAvailable(): boolean;

  /**
   * Assess face image quality.
   *
   * Python equivalent: FastQualityAssessor.assess() (lines 338-366)
   *
   * Algorithm:
   * 1. Blur score: Laplacian variance via Canvas pixel manipulation
   *    - Python: cv2.Laplacian(gray, cv2.CV_64F).var()
   *    - Browser: Manual 3x3 Laplacian kernel convolution on grayscale pixels
   *    - Formula: lap[y][x] = -4*center + top + bottom + left + right
   *    - Variance of all Laplacian values = blur metric
   *    - Score: min(100, (variance / blurThreshold) * 100)
   *
   * 2. Size score: min(100, min(h, w) / 80 * 50)
   *
   * 3. Brightness: mean of grayscale pixels
   *    - OK range: 50 < brightness < 200
   *    - Score: 100 if OK, 50 if not
   *
   * 4. Overall: (blur + size + brightness) / 3
   */
  assess(faceImageData: ImageData): QualityReport;

  /**
   * Extract face region from video frame as ImageData.
   * Handles padding and bounds clamping.
   */
  static extractFaceROI(
    video: HTMLVideoElement,
    boundingBox: BoundingBox,
    padding?: number
  ): ImageData | null;
}
```

**Canvas-based Laplacian (replacing cv2.Laplacian):**
```typescript
function computeLaplacianVariance(gray: Float32Array, width: number, height: number): number {
  let sum = 0;
  let sumSq = 0;
  let count = 0;
  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      const center = gray[y * width + x];
      const lap = -4 * center
        + gray[(y - 1) * width + x]
        + gray[(y + 1) * width + x]
        + gray[y * width + (x - 1)]
        + gray[y * width + (x + 1)];
      sum += lap;
      sumSq += lap * lap;
      count++;
    }
  }
  const mean = sum / count;
  return (sumSq / count) - (mean * mean);  // variance
}
```

### 5g. PassiveLivenessDetector

**Python source:** `FastLivenessDetector` class (lines 369-444)
**Priority:** P2 (Enhancement). Server-side liveness is the primary authority. This client-side detector is a supplementary signal. Gabor convolution is expensive and deferrable to Phase 3.

```typescript
class PassiveLivenessDetector implements IPassiveLivenessDetector {
  private threshold: number;           // Default: 50.0
  private gaborKernels: Float32Array[]; // 4 oriented Gabor kernels

  constructor(threshold?: number);
  isAvailable(): boolean;

  /**
   * Passive liveness check via texture + color analysis.
   *
   * Python equivalent: FastLivenessDetector.check() (lines 387-444)
   *
   * 5 sub-scores (all 0-100):
   *
   * 1. TEXTURE (weight: 0.25)
   *    - Laplacian variance of grayscale face
   *    - Formula: min(100, max(0, (lapVar - 20) / 3))
   *    - Real faces: 50-500+ variance; prints: <30
   *
   * 2. COLOR NATURALNESS (weight: 0.25)
   *    - Mean saturation in HSV space
   *    - Real skin: S in 30-120 (0-255 scale) -> score 100
   *    - S < 30 (grayscale): score = max(0, S * 2)
   *    - S > 120 (oversaturated print): score = max(0, 100 - (S - 120) * 0.8)
   *    - Browser: Convert RGB -> HSV manually
   *
   * 3. SKIN TONE (weight: 0.15)
   *    - Mean hue in HSV space
   *    - Skin hue range: H < 25 or H > 165 (OpenCV 0-180 scale)
   *    - score 100 if in range, else max(0, 100 - |H - 15| * 3)
   *
   * 4. MOIRE PATTERN (weight: 0.20)
   *    - 4 Gabor filters at 0, pi/4, pi/2, 3pi/4
   *    - Kernel: 21x21, sigma=5.0, lambda=10.0, gamma=0.5
   *    - For each kernel: if std(filtered) > 40 -> moire -= 20
   *    - Start at 100, minimum 0
   *
   * 5. LOCAL VARIANCE (weight: 0.15)
   *    - Split face into 4 quadrants
   *    - Compute variance of each quadrant
   *    - score = min(100, (max_var - min_var) / 10)
   *    - Real faces have different texture across regions
   *
   * Combined: texture*0.25 + color*0.25 + skin*0.15 + moire*0.20 + local*0.15
   * is_live = score >= threshold (50.0)
   */
  check(faceImageData: ImageData): LivenessResult;
}
```

**Browser equivalents for cv2 operations:**

| Python (cv2) | Browser Equivalent |
|-------------|-------------------|
| `cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)` | Manual: `0.299*R + 0.587*G + 0.114*B` |
| `cv2.cvtColor(img, cv2.COLOR_BGR2HSV)` | Manual RGB->HSV conversion function |
| `cv2.Laplacian(gray, cv2.CV_64F).var()` | 3x3 kernel convolution + variance calc |
| `cv2.filter2D(gray, cv2.CV_64F, kernel)` | Manual 2D convolution with Gabor kernel |
| `cv2.getGaborKernel(...)` | Pre-computed Gabor kernel arrays |
| `np.std(filtered)` | Manual standard deviation calculation |
| `np.var(region)` | Manual variance calculation |
| `np.mean(channel)` | Sum / count |

**Gabor kernel pre-computation (replacing cv2.getGaborKernel):**
```typescript
function generateGaborKernel(
  ksize: number,  // 21
  sigma: number,  // 5.0
  theta: number,  // orientation
  lambd: number,  // 10.0
  gamma: number,  // 0.5
): Float32Array {
  const kernel = new Float32Array(ksize * ksize);
  const half = Math.floor(ksize / 2);
  for (let y = -half; y <= half; y++) {
    for (let x = -half; x <= half; x++) {
      const xp = x * Math.cos(theta) + y * Math.sin(theta);
      const yp = -x * Math.sin(theta) + y * Math.cos(theta);
      kernel[(y + half) * ksize + (x + half)] =
        Math.exp(-(xp * xp + gamma * gamma * yp * yp) / (2 * sigma * sigma))
        * Math.cos(2 * Math.PI * xp / lambd);
    }
  }
  return kernel;
}

// Pre-compute all 4 kernels at module load:
const GABOR_KERNELS = [0, Math.PI/4, Math.PI/2, 3*Math.PI/4].map(
  theta => generateGaborKernel(21, 5.0, theta, 10.0, 0.5)
);
```

### 5h. BiometricPuzzle (Strategy Pattern)

**Python source:** `BiometricPuzzle` class (lines 451-921)
**This is the most critical class to port faithfully.**

The puzzle uses the **Strategy pattern** with a registry of `ChallengeDetector` implementations. New challenge types can be added by implementing the interface and registering, without modifying any existing code (Open/Closed Principle).

```typescript
// ===== Strategy Interface =====

interface IChallengeDetector {
  readonly type: ChallengeType;
  detect(metrics: FaceMetrics, headPose: HeadPose): boolean;
  getMessage(metrics: FaceMetrics, headPose: HeadPose): string;
}

// ===== Challenge Detector Implementations =====

class BlinkDetector implements IChallengeDetector {
  readonly type = ChallengeType.BLINK;
  detect(metrics: FaceMetrics, headPose: HeadPose): boolean {
    // avg_ear < EAR_CLOSED_THRESHOLD (0.17)
    return metrics.eyes.avgEAR < THRESHOLDS.EAR_CLOSED_THRESHOLD;
  }
  getMessage(metrics: FaceMetrics): string {
    return metrics.eyes.avgEAR < THRESHOLDS.EAR_CLOSED_THRESHOLD
      ? 'Blink detected!' : 'Please blink both eyes';
  }
}

class CloseLeftDetector implements IChallengeDetector {
  readonly type = ChallengeType.CLOSE_LEFT;
  detect(metrics: FaceMetrics): boolean {
    // user_left_ear < 0.17 AND user_right_ear > 0.22
    return metrics.eyes.userLeftEAR < THRESHOLDS.EAR_CLOSED_THRESHOLD
      && metrics.eyes.userRightEAR > THRESHOLDS.EAR_THRESHOLD;
  }
  getMessage(metrics: FaceMetrics): string {
    return this.detect(metrics, {} as HeadPose)
      ? 'Left eye closed!' : 'Close your LEFT eye only';
  }
}

class SmileDetector implements IChallengeDetector {
  readonly type = ChallengeType.SMILE;
  detect(metrics: FaceMetrics): boolean {
    return metrics.mouth.smileCornerRaise > THRESHOLDS.SMILE_CORNER_THRESHOLD
      && metrics.mouth.smileWidthRatio > THRESHOLDS.SMILE_WIDTH_THRESHOLD;
  }
  getMessage(metrics: FaceMetrics): string {
    return this.detect(metrics, {} as HeadPose)
      ? 'Smile detected!' : 'Please smile';
  }
}

class TurnLeftDetector implements IChallengeDetector {
  readonly type = ChallengeType.TURN_LEFT;
  detect(_metrics: FaceMetrics, headPose: HeadPose): boolean {
    return headPose.yaw < -THRESHOLDS.YAW_THRESHOLD;
  }
  getMessage(_metrics: FaceMetrics, headPose: HeadPose): string {
    return headPose.yaw < -THRESHOLDS.YAW_THRESHOLD
      ? 'Turn detected!' : 'Turn your head LEFT';
  }
}

// ... (similar implementations for all 14 challenge types)

class NodDetector implements IChallengeDetector {
  readonly type = ChallengeType.NOD;
  detect(_metrics: FaceMetrics, headPose: HeadPose, motionHistory?: MotionEntry[]): boolean {
    // Requires motionHistory context — pitch_range > 25 over last 20 frames
    if (!motionHistory || motionHistory.length < THRESHOLDS.MOTION_MIN_FRAMES) return false;
    const recent = motionHistory.slice(-THRESHOLDS.MOTION_MIN_FRAMES);
    const pitchRange = Math.max(...recent.map(m => m.pitch)) - Math.min(...recent.map(m => m.pitch));
    return pitchRange > THRESHOLDS.NOD_PITCH_RANGE;
  }
  getMessage(): string { return 'Nod your head up and down'; }
}

// ===== Puzzle Class with Registry =====

class BiometricPuzzle implements IBiometricPuzzle {
  private detectors: Map<ChallengeType, IChallengeDetector> = new Map();
  private metricsCalculator: IFaceMetricsCalculator;

  // --- Thresholds (lines 495-503) ---
  // (Thresholds are in the shared THRESHOLDS constant, see Section 15)

  // --- Hold timer (line 515) ---
  private holdDuration: number = 0.6;  // seconds

  // --- Motion history for nod/shake (line 519) ---
  private motionHistory: Array<{ yaw: number; pitch: number; time: number }>;
  // maxlen=30 in Python, use ring buffer or slice

  // --- Eyebrow baseline (line 520) ---
  private baselineEyebrowDist: EyebrowBaseline | null = null;

  constructor(metricsCalculator: IFaceMetricsCalculator, numChallenges?: number);

  /**
   * Register a challenge detector. Open/Closed: new challenges are added
   * here without modifying any existing code.
   */
  registerDetector(detector: IChallengeDetector): void {
    this.detectors.set(detector.type, detector);
  }

  // --- Control ---
  start(challengeTypes?: ChallengeType[], numChallenges?: number): void;
  stop(): void;
  getCurrentChallenge(): ChallengeInfo | null;
  isAvailable(): boolean;

  /**
   * Check current challenge against face metrics.
   * Python: check_challenge() (lines 702-881)
   *
   * This is the main per-frame check. It:
   * 1. Computes all metrics via FaceMetricsCalculator (DRY)
   * 2. Looks up the registered ChallengeDetector for the current challenge type
   * 3. Delegates detection to the strategy
   * 4. Manages hold timer (0.6s continuous detection)
   * 5. Advances to next challenge on completion
   *
   * IMPORTANT mirror swap (Python lines 729-730):
   *   user_left_ear  = right_ear   // MediaPipe RIGHT = User's LEFT
   *   user_right_ear = left_ear    // MediaPipe LEFT  = User's RIGHT
   *
   * This swap applies to BLINK, CLOSE_LEFT, CLOSE_RIGHT challenges.
   * For eyebrows, the swap is handled differently (see FaceMetricsCalculator).
   */
  checkChallenge(
    landmarks: NormalizedLandmark[],
    yaw: number,
    pitch: number,
  ): ChallengeCheckResult;
}

// Default registration (all 14 built-in challenges):
function createDefaultPuzzle(metricsCalculator: IFaceMetricsCalculator): BiometricPuzzle {
  const puzzle = new BiometricPuzzle(metricsCalculator);
  puzzle.registerDetector(new BlinkDetector());
  puzzle.registerDetector(new CloseLeftDetector());
  puzzle.registerDetector(new CloseRightDetector());
  puzzle.registerDetector(new SmileDetector());
  puzzle.registerDetector(new OpenMouthDetector());
  puzzle.registerDetector(new TurnLeftDetector());
  puzzle.registerDetector(new TurnRightDetector());
  puzzle.registerDetector(new LookUpDetector());
  puzzle.registerDetector(new LookDownDetector());
  puzzle.registerDetector(new RaiseBothBrowsDetector());
  puzzle.registerDetector(new RaiseLeftBrowDetector());
  puzzle.registerDetector(new RaiseRightBrowDetector());
  puzzle.registerDetector(new NodDetector());
  puzzle.registerDetector(new ShakeHeadDetector());
  return puzzle;
}
```

**All 14 Challenge Detection Logic (Python lines 732-861):**

| Challenge | Detection Condition | Python Lines |
|-----------|-------------------|-------------|
| `BLINK` | `avg_ear < EAR_CLOSED_THRESHOLD (0.17)` | 732-742 |
| `CLOSE_LEFT` | `user_left_ear < 0.17 AND user_right_ear > 0.22` | 744-753 |
| `CLOSE_RIGHT` | `user_right_ear < 0.17 AND user_left_ear > 0.22` | 755-764 |
| `SMILE` | `smile_raise > 0.05 AND smile_width > 0.60` | 766-777 |
| `OPEN_MOUTH` | `mar > 0.12` | 779-784 |
| `TURN_LEFT` | `yaw < -20` | 786-793 |
| `TURN_RIGHT` | `yaw > 20` | 795-802 |
| `LOOK_UP` | `pitch < -12` | 804-811 |
| `LOOK_DOWN` | `pitch > 12` | 813-820 |
| `RAISE_BOTH_BROWS` | `brow_both > 1.20` | 822-831 |
| `RAISE_LEFT_BROW` | `brow_left > 1.25 AND brow_right < 1.20` | 833-842 |
| `RAISE_RIGHT_BROW` | `brow_right > 1.25 AND brow_left < 1.20` | 844-853 |
| `NOD` | `pitch_range > 25 over last 20 frames` | 855-857, 883-890 |
| `SHAKE_HEAD` | `yaw_range > 35 over last 20 frames` | 859-861, 892-899 |

**Hold timer logic (Python lines 863-881):**
```
if detected:
    if not previously_detected:
        hold_start = now
    hold_time = now - hold_start
    progress = min(100, hold_time / 0.6 * 100)
    if hold_time >= 0.6:
        advance_to_next_challenge()
        return { detected: true, progress: 100, completed: true }
    return { detected: true, progress }
else:
    reset_hold_timer()
    return { detected: false, progress: 0 }
```

### 5i. HeadPoseEstimator

**Python source:** `estimate_pose()` method (lines 1413-1437)

```typescript
class HeadPoseEstimator implements IHeadPoseEstimator {
  isAvailable(): boolean;

  /**
   * Estimate head yaw and pitch from 478-point landmarks.
   *
   * Python equivalent: estimate_pose() (lines 1413-1437)
   *
   * Uses 5 key landmarks:
   *   nose    = landmarks[1]    (NOSE_TIP)
   *   left_eye  = landmarks[33]   (RIGHT_EYE outer corner - user's left)
   *   right_eye = landmarks[263]  (LEFT_EYE outer corner - user's right)
   *   left_mouth  = landmarks[61]  (MOUTH_LEFT)
   *   right_mouth = landmarks[291] (MOUTH_RIGHT)
   *
   * YAW calculation:
   *   eye_cx = (left_eye.x + right_eye.x) / 2
   *   eye_dist = |right_eye.x - left_eye.x|
   *   yaw = (nose.x - eye_cx) / eye_dist * 60
   *   Clamped to [-45, 45]
   *
   * PITCH calculation:
   *   eye_cy = (left_eye.y + right_eye.y) / 2
   *   mouth_cy = (left_mouth.y + right_mouth.y) / 2
   *   face_h = mouth_cy - eye_cy
   *   mid_y = (eye_cy + mouth_cy) / 2
   *   pitch = (nose.y - mid_y) / face_h * 60
   *   Clamped to [-35, 35]
   *
   * NOTE: This is a simplified geometric estimation, NOT solvePnP.
   * It works well enough for the puzzle challenges.
   * Landmarks are in pixel coordinates (already scaled by frame size).
   */
  estimate(landmarks: PixelLandmark[], frameSize: { width: number; height: number }): HeadPose;
}
```

**Important:** The Python implementation does NOT use solvePnP despite the initial requirement suggesting it. The actual code uses a simpler geometric ratio approach that is equally portable to the browser. The TypeScript port should match the actual Python logic.

### 5j. FaceTracker

**Python source:** `FaceTracker` class (lines 987-1047)

```typescript
class FaceTracker implements IFaceTracker {
  private nextId: number = 0;
  private tracks: Map<number, { centroid: [number, number]; gone: number }>;
  private maxGone: number;  // Default: 15 frames

  constructor(maxGone?: number);
  isAvailable(): boolean;

  /**
   * Update tracks with new detections.
   * Python: FaceTracker.update() (lines 995-1047)
   *
   * Algorithm:
   * 1. If no detections: increment 'gone' counter for all tracks.
   *    Remove tracks where gone > maxGone.
   *
   * 2. Compute centroid (cx, cy) for each detection:
   *    cx = x + w/2, cy = y + h/2
   *
   * 3. If no existing tracks: create new track for each detection.
   *
   * 4. For each existing track, find nearest unmatched detection:
   *    - distance = sqrt((tc.x - nc.x)^2 + (tc.y - nc.y)^2)
   *    - Must be < 120 pixels to match
   *    - Greedy assignment (not Hungarian algorithm)
   *
   * 5. Unmatched detections become new tracks.
   * 6. Unmatched tracks increment 'gone', removed if > maxGone.
   *
   * Returns: Map of trackId -> FaceDetection
   */
  update(detections: FaceDetection[]): Map<number, FaceDetection>;
}
```

### 5k. EmbeddingComputer

**Python source:** `EmbeddingExtractor` class (lines 1192-1220)
**Priority:** P2 (Enhancement). Server-side DeepFace embedding is the primary path. Client-side embedding is for offline/low-latency use cases.

```typescript
class EmbeddingComputer implements IEmbeddingComputer {
  private session: ort.InferenceSession | null = null;
  private ready: boolean = false;

  /**
   * Initialize ONNX Runtime Web with MobileFaceNet model.
   *
   * Python uses DeepFace with Facenet512 model (512-dim embeddings).
   * Browser uses MobileFaceNet ONNX (128-dim or 512-dim).
   *
   * ONNX Runtime Web configuration:
   * - Backend: WASM (universal) or WebGL (GPU, Chrome/Edge)
   * - Model: mobilefacenet.onnx (~5MB)
   * - Input: [1, 3, 112, 112] RGB normalized float32
   * - Output: [1, 128] or [1, 512] float32 embedding
   */
  async initialize(modelUrl: string): Promise<void>;
  dispose(): void;
  isAvailable(): boolean;

  /**
   * Extract face embedding from image.
   * Python: EmbeddingExtractor.extract() (lines 1204-1220)
   *
   * Pre-processing:
   * 1. Resize face crop to 112x112 (MobileFaceNet input)
   * 2. Convert to RGB float32 [0, 1] or [-1, 1] depending on model
   * 3. Transpose to NCHW: [1, 3, 112, 112]
   *
   * Post-processing:
   * 1. L2-normalize the embedding vector
   */
  extract(faceImageData: ImageData): Promise<Float32Array | null>;

  /**
   * Compute cosine similarity between two embeddings.
   * Python: FaceDB.search() uses np.dot / (norm_a * norm_b) (lines 966-980)
   */
  static cosineSimilarity(a: Float32Array, b: Float32Array): number;

  /**
   * Fallback: geometry-based embedding from landmarks.
   * Uses inter-landmark distances as a feature vector.
   * Lower quality than neural embedding but requires no ONNX model.
   */
  static geometryEmbedding(landmarks: NormalizedLandmark[]): Float32Array;
}
```

### 5l. CardDetector

**Python source:** `CardDetector` class (lines 1054-1185)
**Priority:** P2 (Enhancement). Server-side YOLO is the current production path. Client-side ONNX is for offline/low-latency use.

```typescript
class CardDetector implements ICardDetector {
  private session: ort.InferenceSession | null = null;
  private ready: boolean = false;

  // Card labels (Python line 1057-1063)
  static readonly CARD_LABELS: Record<string, string> = {
    'tc_kimlik': 'Turkish ID',
    'ehliyet': 'License',
    'pasaport': 'Passport',
    'ogrenci_karti': 'Student',
    'akademisyen_karti': 'Academic',
  };

  // Temporal smoothing (Python lines 1068-1070)
  private detectionHistory: CardDetectionResult[];  // maxlen=5
  private lastStableResult: CardDetectionResult;

  /**
   * Initialize with YOLO ONNX model (nano variant for browser).
   *
   * Python uses ultralytics YOLO with PyTorch.
   * Browser uses exported ONNX model with ONNX Runtime Web.
   *
   * Model: best.onnx (exported from best.pt, nano variant)
   * Input: [1, 3, 640, 640] RGB float32 normalized
   * Output: [1, N, 10] where 10 = x,y,w,h + 1 obj_conf + 5 class_scores
   */
  async initialize(modelUrl: string): Promise<void>;
  dispose(): void;
  isAvailable(): boolean;

  /**
   * Detect card in frame.
   * Python: CardDetector.detect() (lines 1138-1180)
   *
   * Pre-processing (Python lines 1095-1103):
   * - CLAHE on L channel of LAB color space
   * - Resize to 640x640 (model input)
   *
   * Post-processing:
   * - NMS (non-max suppression)
   * - Best detection by confidence
   * - Temporal smoothing (majority vote over last 5 frames)
   *
   * Confidence threshold: 0.35 (Python line 1151)
   */
  detect(video: HTMLVideoElement, useSmoothing?: boolean): Promise<CardDetectionResult>;
}
```

**CLAHE in browser (replacing cv2.createCLAHE):**
The CLAHE algorithm can be approximated in the browser using Canvas pixel manipulation. A simplified version applies histogram equalization per tile with contrast limiting. For the card detector, a simpler approach may suffice: just apply global histogram equalization on the luminance channel.

### 5m. VoiceProcessor

**No direct Python equivalent in demo_local_fast.py** — this is a browser-specific component for Web Audio recording.

```typescript
class VoiceProcessor implements IVoiceProcessor {
  private audioContext: AudioContext | null = null;
  private mediaRecorder: MediaRecorder | null = null;
  private analyser: AnalyserNode | null = null;

  /**
   * Start recording from microphone.
   * Uses Web Audio API + MediaRecorder.
   *
   * Output: WebM audio blob
   * For server submission: convert to WAV 16kHz mono
   */
  async startRecording(): Promise<void>;
  stopRecording(): Promise<Blob>;
  isAvailable(): boolean;

  /**
   * Convert WebM blob to WAV 16kHz mono.
   * Uses OfflineAudioContext for resampling.
   */
  static async convertToWav16k(webmBlob: Blob): Promise<Blob>;

  /**
   * Get real-time waveform data for visualization.
   * Returns 128 frequency bins (Uint8Array).
   */
  getWaveformData(): Uint8Array | null;

  /**
   * Get recording duration in seconds.
   */
  getDuration(): number;

  dispose(): void;
}
```

---

## 6. Type Definitions

```typescript
// ===== Landmark Types =====

/** Normalized landmark from MediaPipe (0-1 range) */
interface NormalizedLandmark {
  x: number;  // 0.0 - 1.0
  y: number;  // 0.0 - 1.0
  z: number;  // depth (relative)
}

/** Pixel-space landmark (scaled to frame dimensions) */
interface PixelLandmark {
  x: number;  // 0 - frameWidth
  y: number;  // 0 - frameHeight
}

// ===== Face Detection Types =====

interface BoundingBox {
  x: number;       // top-left X (pixels)
  y: number;       // top-left Y (pixels)
  width: number;   // width (pixels)
  height: number;  // height (pixels)
}

interface FaceDetection {
  id: number;                          // Tracker-assigned ID
  boundingBox: BoundingBox;
  confidence: number;                  // 0-1
  landmarks478: NormalizedLandmark[];  // All 478 MediaPipe landmarks
  pixelLandmarks: PixelLandmark[];     // Same landmarks in pixel coords
}

// ===== Quality Types =====

interface QualityReport {
  score: number;       // 0-100 overall
  blur: number;        // 0-100 (higher = sharper)
  size: number;        // 0-100 (higher = larger face)
  brightness: number;  // Raw mean brightness (0-255)
  brightnessOk: boolean;  // 50 < brightness < 200
  issues: QualityIssue[];
}

type QualityIssue = 'Blurry' | 'Small' | 'Dark' | 'Bright';

interface QualityThresholds {
  blurThreshold: number;       // Default: 100.0 (Laplacian var divisor)
  minScore: number;            // Default: 65 (for enrollment)
  minBrightness: number;       // Default: 50
  maxBrightness: number;       // Default: 200
  minFaceDimension: number;    // Default: 80 pixels
}

// ===== Liveness Types =====

interface LivenessResult {
  isLive: boolean;
  score: number;     // 0-100
  breakdown: {
    texture: number;       // 0-100, weight 0.25
    color: number;         // 0-100, weight 0.25
    skinTone: number;      // 0-100, weight 0.15
    moire: number;         // 0-100, weight 0.20
    localVariance: number; // 0-100, weight 0.15
  };
}

interface LivenessConfig {
  threshold: number;  // Default: 50.0
}

// ===== Puzzle Types =====

enum ChallengeType {
  BLINK = 'BLINK',
  CLOSE_LEFT = 'CLOSE_LEFT',
  CLOSE_RIGHT = 'CLOSE_RIGHT',
  SMILE = 'SMILE',
  OPEN_MOUTH = 'OPEN_MOUTH',
  TURN_LEFT = 'TURN_LEFT',
  TURN_RIGHT = 'TURN_RIGHT',
  LOOK_UP = 'LOOK_UP',
  LOOK_DOWN = 'LOOK_DOWN',
  RAISE_BOTH_BROWS = 'RAISE_BOTH_BROWS',
  RAISE_LEFT_BROW = 'RAISE_LEFT_BROW',
  RAISE_RIGHT_BROW = 'RAISE_RIGHT_BROW',
  NOD = 'NOD',
  SHAKE_HEAD = 'SHAKE_HEAD',
}

interface ChallengeDefinition {
  displayName: string;
  key: string;
  icon: string;
}

interface ChallengeInfo {
  type: ChallengeType;
  displayName: string;
  icon: string;
  index: number;       // 0-based current
  total: number;       // total challenges in puzzle
}

interface ChallengeCheckResult {
  detected: boolean;
  progress: number;    // 0-100 (hold timer progress)
  message: string;     // User-facing feedback
  completed?: boolean; // True when this challenge is done
}

interface PuzzleStepResult {
  challenge: ChallengeType;
  passed: boolean;
  timestamp: number;
}

interface PuzzleResult {
  passed: boolean;
  steps: PuzzleStepResult[];
  totalTime: number;  // milliseconds
}

// ===== Head Pose Types =====

interface HeadPose {
  yaw: number;    // -45 to +45 degrees (negative=left, positive=right)
  pitch: number;  // -35 to +35 degrees (negative=up, positive=down)
}

// ===== Metric Types =====

interface SmileMetrics {
  cornerRaise: number;
  widthRatio: number;
}

interface EyebrowBaseline {
  left: number;
  right: number;
  avg: number;
}

interface EyeMetrics {
  leftEAR: number;       // Left eye aspect ratio (MediaPipe LEFT = user's right)
  rightEAR: number;      // Right eye aspect ratio (MediaPipe RIGHT = user's left)
  avgEAR: number;        // Average of both
  userLeftEAR: number;   // User's left eye (= MediaPipe RIGHT_EYE)
  userRightEAR: number;  // User's right eye (= MediaPipe LEFT_EYE)
}

interface MouthMetrics {
  mar: number;           // Mouth aspect ratio (open/close)
  smileCornerRaise: number;  // Lip corner raise ratio
  smileWidthRatio: number;   // Mouth width / face height
}

interface EyebrowMetrics {
  bothRatio: number;     // Both eyebrows raise ratio vs baseline
  leftRatio: number;     // Left eyebrow raise ratio
  rightRatio: number;    // Right eyebrow raise ratio
}

/** Combined face metrics from FaceMetricsCalculator */
interface FaceMetrics {
  eyes: EyeMetrics;
  mouth: MouthMetrics;
  eyebrows: EyebrowMetrics;
}

// ===== Embedding Types =====

interface Embedding {
  vector: Float32Array;  // 128-dim or 512-dim
  model: string;         // e.g. 'mobilefacenet-128' or 'geometry'
}

interface EnrollmentCapture {
  pose: string;          // 'STRAIGHT' | 'LEFT' | 'RIGHT' | 'UP' | 'DOWN'
  embedding: Embedding;
  qualityScore: number;
  imageData: string;     // base64 JPEG for server submission
}

interface EnrollmentResult {
  name: string;
  captures: EnrollmentCapture[];
  puzzlePassed: boolean;
}

interface EnrollmentUpdate {
  state: EnrollmentState;
  yawOk: boolean;
  pitchOk: boolean;
  isStable: boolean;
  stabilityScore: number;
  holdProgress: number;
  message: string;
}

interface VerificationResult {
  matched: boolean;
  name: string | null;
  similarity: number;    // 0-1 cosine similarity
  threshold: number;     // Default: 0.5 (Python line 966)
}

// ===== Card Detection Types =====

interface CardDetectionResult {
  detected: boolean;
  cardClass: string | null;    // Raw class name (e.g. 'tc_kimlik')
  cardLabel: string | null;    // Display name (e.g. 'Turkish ID')
  confidence: number;          // 0-1
  boundingBox: BoundingBox | null;
}

// ===== Frame Result (per-frame output) =====

interface FrameResult {
  faces: TrackedFace[];
  fps: number;
  timestamp: number;
}

interface TrackedFace {
  id: number;
  detection: FaceDetection;
  quality: QualityReport | null;
  liveness: LivenessResult | null;
  headPose: HeadPose | null;
  metrics: FaceMetrics | null;
}

// ===== Enrollment Pose Targets =====
// Python: self._enroll_poses (lines 1287-1293)

interface EnrollmentPose {
  name: string;
  targetYaw: number;
  targetPitch: number;
  tolerance: number;
}

const ENROLLMENT_POSES: EnrollmentPose[] = [
  { name: 'STRAIGHT', targetYaw: 0,   targetPitch: 0,   tolerance: 12 },
  { name: 'LEFT',     targetYaw: -25,  targetPitch: 0,   tolerance: 15 },
  { name: 'RIGHT',    targetYaw: 25,   targetPitch: 0,   tolerance: 15 },
  { name: 'UP',       targetYaw: 0,    targetPitch: 18,  tolerance: 15 },
  { name: 'DOWN',     targetYaw: 0,    targetPitch: -18, tolerance: 15 },
];

// ===== Motion History (for Nod/Shake detection) =====

interface MotionEntry {
  yaw: number;
  pitch: number;
  time: number;
}
```

---

## 7. Enrollment State Machine

The enrollment flow is a two-phase process managed by `EnrollmentController`. Phase 1 is active liveness verification via the puzzle. Phase 2 is multi-angle face capture.

### State Diagram

```
                         start()
  [IDLE] ─────────────────────────────────> [PUZZLE_ACTIVE]
    ^                                             |
    |                                             |
    |  cancel() (from any state)                  |
    |<──────────────────────────────────────────  |
    |                                             |
    |                              puzzle passed  |   puzzle failed
    |                                    |        └──────> [FAILED]
    |                                    v
    |                           [CAPTURE_STRAIGHT]
    |                                    |
    |                         stable + captured
    |                                    v
    |                            [CAPTURE_LEFT]
    |                                    |
    |                         stable + captured
    |                                    v
    |                            [CAPTURE_RIGHT]
    |                                    |
    |                         stable + captured
    |                                    v
    |                             [CAPTURE_UP]
    |                                    |
    |                         stable + captured
    |                                    v
    |                            [CAPTURE_DOWN]
    |                                    |
    |                         stable + captured
    |                                    v
    |                             [SUBMITTING]
    |                              /          \
    |                         success        error
    |                            v              v
    |                       [COMPLETE]      [FAILED]
    |                                          |
    └──────────────────────────────────────────┘
                     (reset to IDLE)
```

### State Transitions

| From State | Event | To State | Action |
|-----------|-------|----------|--------|
| `IDLE` | `start()` | `PUZZLE_ACTIVE` | Initialize puzzle with random challenges |
| `PUZZLE_ACTIVE` | Puzzle passed | `CAPTURE_STRAIGHT` | Begin multi-angle capture, set first pose target |
| `PUZZLE_ACTIVE` | Puzzle failed / timeout | `FAILED` | Report failure reason |
| `CAPTURE_STRAIGHT` | Stable + quality OK + captured | `CAPTURE_LEFT` | Store embedding, advance to left pose |
| `CAPTURE_LEFT` | Stable + quality OK + captured | `CAPTURE_RIGHT` | Store embedding, advance to right pose |
| `CAPTURE_RIGHT` | Stable + quality OK + captured | `CAPTURE_UP` | Store embedding, advance to up pose |
| `CAPTURE_UP` | Stable + quality OK + captured | `CAPTURE_DOWN` | Store embedding, advance to down pose |
| `CAPTURE_DOWN` | Stable + quality OK + captured | `SUBMITTING` | All 5 captures complete, submit to server |
| `SUBMITTING` | Server success | `COMPLETE` | Enrollment persisted |
| `SUBMITTING` | Server error | `FAILED` | Report error, allow retry |
| Any state | `cancel()` | `IDLE` | Clean up, release resources |

### Capture Conditions (per pose)

A capture is taken when ALL of the following hold for `HOLD_TO_CAPTURE` (0.8s):

1. **Pose match**: `|currentYaw - targetYaw| < tolerance` AND `|currentPitch - targetPitch| < tolerance`
2. **Stability**: Max face movement < 15px over last 10 frames (Python lines 1298-1301)
3. **Quality**: `qualityScore >= 65` (Python line 2223)

### Stability Tracking (Python lines 1298-1301)

```typescript
// Track last 10 face centroid positions
const positionHistory: Array<{ x: number; y: number }>;  // maxlen = 10

function isStable(history: Array<{ x: number; y: number }>): boolean {
  if (history.length < STABILITY_MIN_FRAMES) return false;
  const maxDx = Math.max(...history.map(p => p.x)) - Math.min(...history.map(p => p.x));
  const maxDy = Math.max(...history.map(p => p.y)) - Math.min(...history.map(p => p.y));
  return Math.max(maxDx, maxDy) < STABILITY_THRESHOLD;  // 15px
}
```

---

## 8. Error Handling Strategy

Each component follows a consistent error handling pattern: detect failure, report availability, and degrade gracefully. The engine never crashes on a component failure; it reduces functionality instead.

### Component Availability Pattern

Every component implements `isAvailable(): boolean`. The engine checks availability before delegating work:

```typescript
// Pattern used by FrameProcessor and EnrollmentController:
if (this.livenessDetector?.isAvailable()) {
  trackedFace.liveness = this.livenessDetector.check(faceROI);
} else {
  trackedFace.liveness = null;  // graceful skip
}
```

### Failure Modes and Recovery

| Failure | Detection | Degradation | User Message |
|---------|-----------|------------|--------------|
| **MediaPipe WASM load failure** | `FaceDetector.initialize()` rejects | Engine unusable. `isReady = false`. | "Face detection is unavailable. Please try a different browser or reload the page." |
| **MediaPipe model 404** | HTTP fetch fails during init | Same as above. | "Could not load face detection model. Check your network connection." |
| **Camera access denied** | `getUserMedia()` rejects with `NotAllowedError` | No detection loop. Clear error, no retry loop. | "Camera access was denied. Please allow camera access in your browser settings." |
| **Camera not found** | `getUserMedia()` rejects with `NotFoundError` | No detection loop. | "No camera found. Please connect a camera and reload." |
| **ONNX model 404** | `EmbeddingComputer.initialize()` or `CardDetector.initialize()` rejects | Skip embedding/card features. `isAvailable() = false`. Server fallback for embedding and card detection. | "Advanced features unavailable. Basic detection still works." |
| **ONNX Runtime WASM load failure** | WASM binary fails to load | Same as above. | (same) |
| **Network failure during enrollment submission** | `fetch()` rejects or returns 5xx | Queue captures locally with retry. `EnrollmentController` transitions to `SUBMITTING` with retry logic. | "Network error. Your enrollment data has been saved locally and will be submitted when connection is restored." |
| **Gabor kernel computation timeout** | Processing exceeds frame budget | Disable passive liveness for this session. Set `livenessDetector.isAvailable() = false`. | (Silent. Server-side liveness is the authority anyway.) |
| **Out of memory (large ONNX model)** | OOM error during ONNX session creation | Fall back to geometry-based embeddings. | "Using lightweight face matching. For best results, use a device with more memory." |
| **Web Audio API unavailable** | `AudioContext` constructor throws | Voice recording disabled. `isAvailable() = false`. | "Voice recording is not supported in this browser." |

### Error Propagation Rules

1. **Component initialization errors** are caught and logged. The component sets `isAvailable() = false`. The engine continues initializing other components.
2. **Per-frame processing errors** are caught per-component. A failing component returns `null` for that frame. Other components continue.
3. **Enrollment errors** transition the state machine to `FAILED` with a reason string.
4. **Network errors** during submission use a local queue with exponential backoff retry (max 3 retries, backoff: 1s, 4s, 16s).

### Local Queue for Network Failures

```typescript
interface QueuedEnrollment {
  result: EnrollmentResult;
  attemptCount: number;
  lastAttempt: number;
  nextRetryAt: number;
}

class EnrollmentQueue {
  private queue: QueuedEnrollment[] = [];

  enqueue(result: EnrollmentResult): void;
  async flush(): Promise<void>;  // Try submitting all queued items
  readonly pendingCount: number;
}
```

---

## 9. React Hook Contracts

### useBiometricEngine

```typescript
function useBiometricEngine(config?: IBiometricEngineConfig): {
  engine: BiometricEngine | null;
  isReady: boolean;
  isLoading: boolean;
  error: string | null;
  /** Which optional components are available */
  availability: {
    faceDetector: boolean;
    qualityAssessor: boolean;
    livenessDetector: boolean;
    embeddingComputer: boolean;
    cardDetector: boolean;
    voiceProcessor: boolean;
  };
}
```

Manages singleton lifecycle. Calls `engine.initialize()` on mount, `engine.dispose()` on unmount. Returns null engine until MediaPipe models are loaded. Accepts optional config for dependency injection (testing).

### useFaceDetection

```typescript
function useFaceDetection(
  engine: BiometricEngine | null,
  videoRef: React.RefObject<HTMLVideoElement | null>,
  active: boolean,
): {
  faces: TrackedFace[];
  primaryFace: TrackedFace | null;     // Largest detected face
  landmarks: NormalizedLandmark[][] | null;
  headPose: HeadPose | null;           // Primary face head pose
  quality: QualityReport | null;       // Primary face quality
  fps: number;
}
```

Runs the detection loop via `engine.frameProcessor.start()` when `active` is true. Quality and head pose are computed for the primary (largest) face.

**Replaces:** Current `useFaceDetection.ts` (195 lines) and `useQualityAssessment.ts` (196 lines).

### useLivenessPuzzle

```typescript
function useLivenessPuzzle(
  engine: BiometricEngine | null,
): {
  // Control
  start: (challengeTypes?: ChallengeType[], numChallenges?: number) => void;
  stop: () => void;

  // State
  isActive: boolean;
  isComplete: boolean;
  passed: boolean;

  // Current challenge
  currentChallenge: ChallengeInfo | null;
  challengeResult: ChallengeCheckResult | null;

  // Per-frame update (call from detection loop)
  updateChallenge: (
    landmarks: NormalizedLandmark[],
    headPose: HeadPose,
  ) => ChallengeCheckResult | null;

  // Results
  results: PuzzleStepResult[];

  // All metrics (for debug UI)
  metrics: FaceMetrics | null;
}
```

Wraps `engine.puzzle`. The `updateChallenge` method should be called every frame from the detection loop. The hook manages React state updates throttled to avoid excessive re-renders (every 100ms or on challenge transitions).

**Replaces:** Current `useLivenessPuzzle.ts` (501 lines) and parts of `useFaceChallenge.ts`.

### useFaceEnrollment

```typescript
function useFaceEnrollment(
  engine: BiometricEngine | null,
): {
  // Control
  startMultiAngle: (name: string) => void;
  cancelEnrollment: () => void;

  // State (delegates to EnrollmentController)
  isEnrolling: boolean;
  phase: 'idle' | 'puzzle' | 'capture' | 'complete';
  currentPose: EnrollmentPose | null;
  step: number;        // 0-4 (5 poses)
  totalSteps: number;  // 5
  enrollmentState: EnrollmentState;  // Full state machine state

  // Pose matching
  yawOk: boolean;
  pitchOk: boolean;
  isStable: boolean;
  stabilityScore: number;  // 0-100
  holdProgress: number;    // 0-100

  // Results
  captures: EnrollmentCapture[];
  status: 'idle' | 'enrolling' | 'success' | 'failed';
}
```

Implements the full 2-phase enrollment by delegating to `engine.enrollmentController`.

Stability tracking (Python lines 1298-1301): tracks last 10 face positions, requires max movement < 15 pixels.

**Replaces:** Current `useFaceChallenge.ts` enrollment logic (279 lines).

### useVoiceRecorder

```typescript
function useVoiceRecorder(): {
  // Control
  start: () => Promise<void>;
  stop: () => Promise<Blob | null>;

  // State
  isRecording: boolean;
  duration: number;      // seconds
  waveform: Uint8Array;  // Real-time frequency data (128 bins)
  error: string | null;

  // Output
  blob: Blob | null;     // WebM recording
  wav16k: Blob | null;   // Converted WAV 16kHz mono
}
```

### useCardDetection

```typescript
function useCardDetection(
  engine: BiometricEngine | null,
): {
  // Control
  detect: (video: HTMLVideoElement) => Promise<CardDetectionResult>;
  reset: () => void;

  // State
  isDetecting: boolean;
  isModelLoaded: boolean;
  result: CardDetectionResult | null;
  error: string | null;
}
```

**Replaces:** Current `useCardDetection.ts` (100 lines) which uses server-side detection. The new version runs YOLO ONNX client-side.

---

## 10. Auth-Test Adapter

The auth-test page (`/auth-test/app.js`) currently contains inline biometric logic. After migration, it imports the engine directly.

### Option A: ES Module Import

```html
<script type="module">
  import { BiometricEngine, ChallengeType } from './biometric-engine.esm.js';

  const engine = BiometricEngine.getInstance();
  await engine.initialize();

  // Face detection loop (via FrameProcessor)
  engine.frameProcessor.start(videoEl, (result) => {
    // ... use result
  });

  // Start puzzle
  engine.puzzle.start([ChallengeType.BLINK, ChallengeType.SMILE, ChallengeType.TURN_LEFT]);
</script>
```

### Option B: IIFE Bundle (no module support needed)

```html
<script src="biometric-engine.iife.js"></script>
<script>
  const engine = FIVUCSAS.BiometricEngine.getInstance();
  // ... same API
</script>
```

### Vanilla Adapter (Event-Based)

For auth-test pages that prefer callback patterns:

```typescript
class BiometricEngineAdapter {
  private engine: BiometricEngine;
  private running: boolean = false;

  constructor(engine: BiometricEngine);

  // Start continuous detection with callbacks
  startDetectionLoop(
    video: HTMLVideoElement,
    callbacks: {
      onFaceDetected?: (faces: TrackedFace[]) => void;
      onQualityUpdate?: (quality: QualityReport) => void;
      onPoseUpdate?: (pose: HeadPose) => void;
      onPuzzleProgress?: (result: ChallengeCheckResult) => void;
      onPuzzleComplete?: (passed: boolean) => void;
      onFps?: (fps: number) => void;
    },
  ): void;

  stopDetectionLoop(): void;
}
```

### Version Compatibility

The adapter must handle engine version mismatches gracefully. See Section 16 for the versioning strategy. The adapter checks `engine.version` on construction and warns if the adapter was built against a different major version.

### Build Configuration

The engine library is built with two output formats:

```
biometric-engine/
  dist/
    biometric-engine.esm.js      # ES module (tree-shakeable)
    biometric-engine.esm.js.map
    biometric-engine.iife.js     # IIFE global (FIVUCSAS namespace)
    biometric-engine.iife.js.map
    types/
      index.d.ts                 # TypeScript declarations
```

Build tool: Vite library mode or Rollup with TypeScript plugin.

---

## 11. Testing Strategy

### Unit Testing (Vitest)

Each component is tested in isolation using mock data. The interface-based architecture (Section 5a) makes mocking straightforward.

**Test structure:**
```
tests/
  core/
    FaceDetector.test.ts
    QualityAssessor.test.ts
    HeadPoseEstimator.test.ts
    FaceTracker.test.ts
    FaceMetricsCalculator.test.ts
    PassiveLivenessDetector.test.ts
    EmbeddingComputer.test.ts
    CardDetector.test.ts
    VoiceProcessor.test.ts
  puzzle/
    BlinkDetector.test.ts
    SmileDetector.test.ts
    TurnLeftDetector.test.ts
    ... (one per ChallengeDetector)
    BiometricPuzzle.test.ts
  orchestration/
    FrameProcessor.test.ts
    EnrollmentController.test.ts
    BiometricEngine.test.ts
  integration/
    enrollment-flow.test.ts
    puzzle-full-run.test.ts
```

### Mock Landmark Data (Save/Replay Pattern)

Record real MediaPipe landmark data from sessions, save as JSON fixtures, and replay in tests:

```typescript
// Record (run once with real camera):
function recordLandmarkSession(duration: number): LandmarkFrame[] {
  const frames: LandmarkFrame[] = [];
  // ... capture landmarks from FaceLandmarker for N seconds
  return frames;
}

// Save to fixture:
// tests/fixtures/blink-session.json
// tests/fixtures/smile-session.json
// tests/fixtures/turn-left-session.json

// Replay in test:
import blinkSession from '../fixtures/blink-session.json';

describe('BlinkDetector', () => {
  it('detects blink in recorded session', () => {
    const calculator = new FaceMetricsCalculator();
    const detector = new BlinkDetector();

    const blinkFrame = blinkSession.frames.find(f => f.label === 'eyes_closed');
    const metrics = calculator.calculateAll(blinkFrame.landmarks);
    expect(detector.detect(metrics, blinkFrame.headPose)).toBe(true);
  });

  it('does not detect blink with eyes open', () => {
    const openFrame = blinkSession.frames.find(f => f.label === 'eyes_open');
    const metrics = calculator.calculateAll(openFrame.landmarks);
    expect(detector.detect(metrics, openFrame.headPose)).toBe(false);
  });
});
```

### Canvas-Based Test Fixtures

For components that operate on `ImageData` (QualityAssessor, PassiveLivenessDetector):

```typescript
// Create test ImageData from pre-rendered face images
function createTestImageData(width: number, height: number, pattern: 'sharp' | 'blurry' | 'dark'): ImageData {
  const data = new Uint8ClampedArray(width * height * 4);
  // Fill with pattern-specific pixel values
  return new ImageData(data, width, height);
}

describe('QualityAssessor', () => {
  it('flags blurry images', () => {
    const assessor = new QualityAssessor();
    const blurryImage = createTestImageData(100, 100, 'blurry');
    const report = assessor.assess(blurryImage);
    expect(report.issues).toContain('Blurry');
    expect(report.blur).toBeLessThan(50);
  });
});
```

### Threshold Validation: Python vs TypeScript Parity

Run both Python and TypeScript implementations on the same test images and compare outputs:

```bash
# 1. Generate reference data from Python
cd biometric-processor
python -m tests.generate_threshold_reference \
  --input tests/fixtures/face_images/ \
  --output tests/fixtures/threshold_reference.json

# 2. Run TypeScript against same images
cd biometric-engine
npx vitest run tests/parity/threshold-parity.test.ts
```

```typescript
// tests/parity/threshold-parity.test.ts
import reference from '../fixtures/threshold_reference.json';

describe('Python-TypeScript parity', () => {
  for (const entry of reference.ears) {
    it(`EAR matches for ${entry.name}`, () => {
      const calculator = new FaceMetricsCalculator();
      const ear = calculator.calculateEAR(entry.landmarks, entry.eyeIndices);
      expect(ear).toBeCloseTo(entry.pythonEAR, 3);  // 3 decimal places
    });
  }

  for (const entry of reference.quality) {
    it(`Quality score matches for ${entry.name}`, () => {
      const assessor = new QualityAssessor();
      const report = assessor.assess(entry.imageData);
      expect(report.score).toBeCloseTo(entry.pythonScore, 0);  // within 1 point
    });
  }
});
```

### Integration Tests (Playwright with Camera Mock)

Use Playwright's camera mock to simulate webcam input:

```typescript
// tests/e2e/enrollment.spec.ts
import { test, expect } from '@playwright/test';

test('full enrollment flow with mocked camera', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['camera'],
    // Use pre-recorded video as camera input
    recordVideo: undefined,
  });

  // Playwright camera mock: provide frames from a video file
  // This requires the @playwright/test camera mock API
  const page = await context.newPage();
  await page.goto('/auth-test/');

  // Start enrollment
  await page.click('#face-enroll-btn');

  // Wait for puzzle to appear
  await expect(page.locator('.puzzle-challenge')).toBeVisible({ timeout: 5000 });

  // ... verify puzzle progression
  // ... verify capture phases
  // ... verify submission
});
```

### Unit Test Examples per Component

| Component | Key Test Cases |
|-----------|---------------|
| `FaceMetricsCalculator` | EAR=0.3 for open eyes, EAR=0.15 for closed, MAR=0.0 for closed mouth, MAR>0.12 for open, smile detection positive/negative |
| `BiometricPuzzle` | Hold timer advances to 100% after 0.6s, resets on detection loss, advances to next challenge on completion, all 14 challenges work with fixture data |
| `HeadPoseEstimator` | Yaw=0 for centered face, yaw<-20 for left turn, pitch>12 for look down, clamping works at boundaries |
| `FaceTracker` | New track assigned ID, track survives 14 frames without detection, track removed at frame 16, centroid matching within 120px |
| `QualityAssessor` | Sharp image scores >80 blur, dark image flagged, small face flagged, overall score computed correctly |
| `EnrollmentController` | State transitions match diagram (Section 7), cancel from any state returns to IDLE, network failure queues locally |

---

## 12. Migration Plan

### Phase 1: Engine Core (Week 1-2)

**Goal:** FaceDetector, QualityAssessor, HeadPoseEstimator, FaceTracker, FaceMetricsCalculator working in isolation.

| File | Description | Source |
|------|-------------|--------|
| `src/core/FaceDetector.ts` | MediaPipe FaceLandmarker wrapper | Python lines 144-325, 1318-1411 |
| `src/core/QualityAssessor.ts` | Canvas-based blur/brightness/size | Python lines 332-366 |
| `src/core/HeadPoseEstimator.ts` | Geometric yaw/pitch from landmarks | Python lines 1413-1437 |
| `src/core/FaceTracker.ts` | Centroid-based multi-face tracking | Python lines 987-1047 |
| `src/core/FaceMetricsCalculator.ts` | Shared EAR/MAR/smile/eyebrow (DRY) | Python lines 575-700 |
| `src/core/image-utils.ts` | Grayscale, HSV, convolution helpers | Replaces cv2 calls |
| `src/interfaces/index.ts` | All component interfaces | Section 5a of this doc |
| `src/types/index.ts` | All TypeScript interfaces | Section 6 of this doc |
| `tests/core/` | Unit tests for each class | |

**Validation:** Detect face, draw landmarks on canvas, show quality score, show head pose angles.

### Phase 2: BiometricPuzzle + FrameProcessor + EnrollmentController (Week 2-3)

**Goal:** All 14 challenges working with hold timer and motion detection. Frame loop and enrollment state machine operational.

| File | Description | Source |
|------|-------------|--------|
| `src/core/BiometricPuzzle.ts` | Strategy-based 14-challenge puzzle engine | Python lines 451-921 |
| `src/core/challenges/BlinkDetector.ts` | Blink challenge strategy | Python lines 732-742 |
| `src/core/challenges/SmileDetector.ts` | Smile challenge strategy | Python lines 766-777 |
| `src/core/challenges/...` | (one file per ChallengeDetector) | |
| `src/core/FrameProcessor.ts` | Detection loop orchestration | New (extracted from BiometricEngine) |
| `src/core/EnrollmentController.ts` | Multi-angle enrollment state machine | Python lines 1287-1301, 2161-2223 |
| `src/core/BiometricEngine.ts` | Orchestrator with DI builder | New structure |
| `tests/core/puzzle/` | Tests for each challenge type | |

**Validation:** Run each of the 14 challenges. Verify thresholds match Python. Test hold timer. Test nod/shake motion detection. Test enrollment state transitions.

### Phase 3: PassiveLiveness + EmbeddingComputer (Week 3-4)

**Goal:** Texture/color liveness analysis and ONNX face embedding extraction. These are P2 components and can be deferred.

| File | Description | Source |
|------|-------------|--------|
| `src/core/PassiveLivenessDetector.ts` | 5-component liveness scoring | Python lines 369-444 |
| `src/core/image-processing/gabor.ts` | Pre-computed Gabor kernels | Python lines 381-385 |
| `src/core/image-processing/hsv.ts` | RGB to HSV conversion | Replaces cv2.COLOR_BGR2HSV |
| `src/core/EmbeddingComputer.ts` | ONNX Runtime Web MobileFaceNet | Python lines 1192-1220 |
| `src/core/EmbeddingComputer.geometry.ts` | Landmark geometry fallback | New |
| `tests/core/liveness/` | Liveness scoring tests | |

**Validation:** Compare liveness scores between Python and TypeScript on the same face images. Verify embedding cosine similarity.

### Phase 4: React Hooks + Components (Week 4-5)

**Goal:** Replace existing scattered hooks with engine-backed hooks.

| File | Description | Replaces |
|------|-------------|----------|
| `src/hooks/useBiometricEngine.ts` | Engine singleton lifecycle | New |
| `src/hooks/useFaceDetection.ts` | Detection loop + tracking | `useFaceDetection.ts` (195 lines) |
| `src/hooks/useLivenessPuzzle.ts` | 14-challenge puzzle hook | `useLivenessPuzzle.ts` (501 lines) + `useFaceChallenge.ts` (279 lines) |
| `src/hooks/useFaceEnrollment.ts` | 2-phase enrollment flow | Part of `useFaceChallenge.ts` |
| `src/hooks/useVoiceRecorder.ts` | Web Audio recording | New |
| `src/hooks/useCardDetection.ts` | Client-side ONNX YOLO | `useCardDetection.ts` (100 lines, was server-side) |

**Validation:** All existing React components (FaceCaptureStep, FaceEnrollmentFlow, LivenessPuzzleDialog) work with new hooks. No regressions.

### Phase 5: Auth-Test Adapter (Week 5-6)

**Goal:** Auth-test page imports engine library, removes inline biometric code.

| Task | Description |
|------|-------------|
| Build IIFE bundle | Vite library mode output |
| Create `BiometricEngineAdapter` | Event-based wrapper for vanilla JS |
| Refactor `auth-test/app.js` | Replace inline face/puzzle/liveness code with engine imports |
| Verify all 11 auth-test sections | Face, Voice, Card, Liveness, Bank enrollment all work |

### Phase 6: CardDetector ONNX Migration (Week 6-7)

**Goal:** Client-side card detection with YOLO ONNX nano model.

| Task | Description |
|------|-------------|
| Export YOLO model to ONNX | `yolo export model=best.pt format=onnx opset=12 simplify` |
| Implement ONNX pre/post-processing | Resize, normalize, NMS, class mapping |
| CLAHE approximation | Simplified histogram equalization for browser |
| Temporal smoothing | Majority vote over 5 frames (Python lines 1105-1136) |

---

## 13. Browser API Compatibility

| API | Chrome | Edge | Firefox | Safari | Notes |
|-----|--------|------|---------|--------|-------|
| MediaPipe Vision Tasks | 90+ | 90+ | 104+ | 16.4+ | GPU delegate: Chrome/Edge only; WASM fallback for Firefox/Safari |
| `getUserMedia` | 53+ | 79+ | 36+ | 11+ | `facingMode: 'user'` for selfie cam |
| Web Audio API | 35+ | 79+ | 25+ | 14.1+ | `AudioContext`, `MediaRecorder`, `AnalyserNode` |
| ONNX Runtime Web (WASM) | 91+ | 91+ | 89+ | 15.2+ | ~5MB WASM binary download |
| ONNX Runtime Web (WebGL) | 91+ | 91+ | N/A | N/A | GPU acceleration; Chrome/Edge only |
| Canvas 2D (`getImageData`) | 4+ | 12+ | 3.6+ | 3.1+ | Used for all image processing |
| `OffscreenCanvas` | 69+ | 79+ | 105+ | 16.4+ | Optional: worker-based processing |
| WebGL 2 | 56+ | 79+ | 51+ | 15+ | Optional: GPU-accelerated image processing |
| `performance.now()` | 24+ | 12+ | 15+ | 8+ | High-resolution timing for FPS |
| `requestAnimationFrame` | 24+ | 12+ | 23+ | 7+ | Detection loop driver |

### Model Loading Strategy

| Model | Size | CDN URL | Fallback |
|-------|------|---------|----------|
| `face_landmarker.task` | ~5MB | `storage.googleapis.com/mediapipe-models/...` | Bundle in `/public/models/` |
| `mobilefacenet.onnx` | ~5MB | Self-hosted on CDN | Bundle in `/public/models/` |
| `card_detector.onnx` | ~15MB | Self-hosted on CDN | Skip (card detection unavailable) |
| MediaPipe WASM files | ~4MB | `cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm` | Self-host in `/public/wasm/` |

**CSP Requirements** (update `vite.config.ts` and `.htaccess`):
```
script-src: cdn.jsdelivr.net (MediaPipe WASM)
connect-src: storage.googleapis.com (MediaPipe models), self (ONNX models)
worker-src: blob: (ONNX WASM workers)
```

---

## 14. Performance Budgets

Based on Python demo targets (20-30+ FPS) and browser overhead.

| Operation | Python Target | Browser Budget | Notes |
|-----------|---------------|---------------|-------|
| Face detection + landmarks | ~15-25ms | **<30ms** | MediaPipe FaceLandmarker (GPU) |
| Quality assessment | ~2ms | **<10ms** | Canvas pixel operations |
| Passive liveness | ~3-5ms | **<8ms** | Gabor convolution is expensive; sample every 4th pixel |
| Head pose estimation | ~1ms | **<3ms** | Simple arithmetic |
| Face tracking | ~1ms | **<2ms** | Centroid matching |
| Puzzle challenge check | ~1ms | **<2ms** | Metric calculations |
| **Total per frame** | **~25-35ms** | **<50ms** | **Target: 20+ FPS** |
| Embedding extraction | ~200ms | **<100ms** | ONNX WASM; on-demand only |
| Card detection | ~50ms | **<200ms** | ONNX YOLO nano; on-demand only |
| Voice WAV conversion | N/A | **<500ms** | OfflineAudioContext resample |

### Optimization Strategies

1. **GPU delegation** for MediaPipe when available (Chrome/Edge).
2. **Sampling** for expensive pixel operations: Laplacian and Gabor filter every 4th pixel (Python demo also does this for Laplacian via step parameter).
3. **Throttling** for non-critical assessments: quality every 500ms, liveness every 1000ms (Python caches at similar intervals).
4. **Lazy initialization**: ONNX models load only when first needed.
5. **OffscreenCanvas** in Web Worker for image processing (future optimization).
6. **TypedArrays** (`Float32Array`, `Uint8Array`) for all numeric computation.

---

## 15. Threshold Reference Table

All thresholds from `demo_local_fast.py` in one reference table.

### Puzzle Challenge Thresholds

| Constant | Value | Python Line | Used By |
|----------|-------|-------------|---------|
| `EAR_THRESHOLD` | 0.22 | 495 | Eye open detection |
| `EAR_CLOSED_THRESHOLD` | 0.17 | 496 | Eye closed detection (BLINK, CLOSE_LEFT, CLOSE_RIGHT) |
| `SMILE_CORNER_THRESHOLD` | 0.05 | 497 | Lip corner raise ratio (SMILE) |
| `SMILE_WIDTH_THRESHOLD` | 0.60 | 498 | Mouth width / face height (SMILE) |
| `MOUTH_OPEN_THRESHOLD` | 0.12 | 499 | Mouth aspect ratio (OPEN_MOUTH) |
| `YAW_THRESHOLD` | 20 deg | 500 | Head turn detection (TURN_LEFT, TURN_RIGHT) |
| `PITCH_THRESHOLD` | 12 deg | 501 | Head tilt detection (LOOK_UP, LOOK_DOWN) |
| `EYEBROW_RAISE_THRESHOLD` | 1.20x | 502 | Both eyebrows ratio vs baseline (RAISE_BOTH_BROWS) |
| `SINGLE_BROW_THRESHOLD` | 1.25x | 503 | Single eyebrow ratio vs baseline (RAISE_LEFT/RIGHT_BROW) |
| `NOD_PITCH_RANGE` | 25 deg | 890 | Min pitch range over 20 frames (NOD) |
| `SHAKE_YAW_RANGE` | 35 deg | 898 | Min yaw range over 20 frames (SHAKE_HEAD) |
| `HOLD_DURATION` | 0.6 sec | 515 | Continuous detection time to pass challenge |
| `MOTION_HISTORY_SIZE` | 30 frames | 519 | Ring buffer for nod/shake detection |
| `MOTION_MIN_FRAMES` | 20 frames | 885, 896 | Min frames before checking nod/shake |

### Quality Assessment Thresholds

| Constant | Value | Python Line | Description |
|----------|-------|-------------|-------------|
| `BLUR_THRESHOLD` | 100.0 | 335 | Laplacian variance divisor |
| `MIN_BRIGHTNESS` | 50 | 354 | Minimum acceptable brightness |
| `MAX_BRIGHTNESS` | 200 | 354 | Maximum acceptable brightness |
| `MIN_FACE_DIM` | 80 px | 350 | Minimum face dimension for size score |
| `QUALITY_MIN_SCORE` | 65 | 2223 | Minimum score for enrollment capture |

### Passive Liveness Thresholds

| Constant | Value | Python Line | Description |
|----------|-------|-------------|-------------|
| `LIVENESS_THRESHOLD` | 50.0 | 379 | Overall score threshold for isLive |
| `TEXTURE_OFFSET` | 20 | 398 | Laplacian variance offset |
| `TEXTURE_SCALE` | 3 | 398 | Laplacian variance divisor |
| `SAT_LOW` | 30 | 405 | Min acceptable saturation |
| `SAT_HIGH` | 120 | 405 | Max natural saturation |
| `SAT_OVERSATURATED_SCALE` | 0.8 | 410 | Penalty factor for S > 120 |
| `SKIN_HUE_MAX` | 25 | 414 | Max hue for skin tone (OpenCV 0-180 scale) |
| `SKIN_HUE_WRAP` | 165 | 414 | Wrapped hue threshold for skin |
| `GABOR_STD_THRESHOLD` | 40 | 421 | Max Gabor response before moire penalty |
| `MOIRE_PENALTY` | 20 | 422 | Points deducted per bad Gabor kernel |
| `LOCAL_VAR_SCALE` | 10 | 434 | Divisor for local variance score |
| **Score weights** | | 439 | |
| - texture | 0.25 | 439 | |
| - color | 0.25 | 439 | |
| - skinTone | 0.15 | 439 | |
| - moire | 0.20 | 439 | |
| - localVariance | 0.15 | 439 | |

### Face Detection Thresholds

| Constant | Value | Python Line | Description |
|----------|-------|-------------|-------------|
| `MIN_DETECTION_CONFIDENCE` | 0.5 | 191 | MediaPipe detection confidence |
| `MIN_FACE_SIZE` | 30 px | 269 | Minimum face bounding box dimension |
| `LANDMARK_CACHE_INTERVAL` | 50 ms | 1377 | Min time between landmark detections |
| `LIVENESS_CACHE_INTERVAL` | 1000 ms | 2358 | Per-face liveness cache TTL |
| `VERIFY_CACHE_INTERVAL` | 2000 ms | 1530 | Per-face verification cache TTL |

### Enrollment Thresholds

| Constant | Value | Python Line | Description |
|----------|-------|-------------|-------------|
| `STABILITY_THRESHOLD` | 15 px | 1300 | Max face movement for stable detection |
| `STABILITY_MIN_FRAMES` | 5 | 2161 | Min frames to assess stability |
| `STABILITY_HISTORY_SIZE` | 10 | 1299 | Face position history length |
| `HOLD_TO_CAPTURE` | 0.8 sec | 2212 | Time to hold pose before capture |
| `EMBEDDING_THRESHOLD` | 0.5 | 966 | Cosine similarity for face search |
| `ENROLLMENT_QUALITY_MIN` | 65 | 2223 | Min quality score for enrollment frame |
| `MAX_EMBEDDINGS_PER_FACE` | 5 | 961 | Max stored embeddings per identity |

### Enrollment Pose Targets

| Pose | Target Yaw | Target Pitch | Tolerance | Python Line |
|------|-----------|-------------|-----------|-------------|
| STRAIGHT | 0 | 0 | 12 | 1288 |
| LEFT | -25 | 0 | 15 | 1289 |
| RIGHT | 25 | 0 | 15 | 1290 |
| UP | 0 | 18 | 15 | 1291 |
| DOWN | 0 | -18 | 15 | 1292 |

### Head Pose Estimation

| Constant | Value | Python Line | Description |
|----------|-------|-------------|-------------|
| `YAW_SCALE` | 60 | 1427 | Multiplier: (nose_offset / eye_dist) * 60 |
| `PITCH_SCALE` | 60 | 1433 | Multiplier: (nose_offset / face_h) * 60 |
| `YAW_CLAMP` | [-45, 45] | 1435 | Output range for yaw |
| `PITCH_CLAMP` | [-35, 35] | 1435 | Output range for pitch |

### Tracker Thresholds

| Constant | Value | Python Line | Description |
|----------|-------|-------------|-------------|
| `MAX_GONE_FRAMES` | 15 | 990 | Frames before track is removed |
| `MAX_MATCH_DISTANCE` | 120 px | 1028 | Max centroid distance for track match |

### Card Detection Thresholds

| Constant | Value | Python Line | Description |
|----------|-------|-------------|-------------|
| `CARD_CONFIDENCE` | 0.35 | 1151 | Min YOLO detection confidence |
| `CARD_INPUT_SIZE` | 640 px | 1151 | YOLO inference image size |
| `SMOOTHING_HISTORY` | 5 | 1069 | Temporal smoothing window |
| `SMOOTHING_MIN_DETECTIONS` | 2 | 1115 | Min detections in window to confirm |
| `CARD_CACHE_INTERVAL` | 150 ms | 1559 | Min time between card detections |
| `CLAHE_CLIP_LIMIT` | 2.0 | 1100 | CLAHE contrast limiting |
| `CLAHE_TILE_SIZE` | (8, 8) | 1100 | CLAHE tile grid |

### MediaPipe Landmark Indices (Quick Reference)

| Feature | Indices | Python Line |
|---------|---------|-------------|
| Left eye (EAR) | [362, 385, 387, 263, 373, 380] | 462 |
| Right eye (EAR) | [33, 160, 158, 133, 153, 144] | 463 |
| Upper lip | 13 | 464 |
| Lower lip | 14 | 465 |
| Mouth left | 61 | 466 |
| Mouth right | 291 | 467 |
| Left eyebrow | [70, 63, 105, 66, 107] | 468 |
| Right eyebrow | [300, 293, 334, 296, 336] | 469 |
| Left iris | 468 | 470 |
| Right iris | 473 | 471 |
| Nose tip | 1 | 472 |
| Chin | 152 | 473 |
| Forehead | 10 | (used in existing hooks) |
| Face left contour | 234 | (used in head turn detection) |
| Face right contour | 454 | (used in head turn detection) |
| Head pose reference (left eye outer) | 33 | 1420 |
| Head pose reference (right eye outer) | 263 | 1421 |
| Head pose reference (left mouth) | 61 | 1422 |
| Head pose reference (right mouth) | 291 | 1423 |

### Mirror Mapping (Critical!)

The camera is mirrored (flipped horizontally). MediaPipe landmarks follow anatomical convention:

```
MediaPipe LEFT_EYE  [362,...] = Anatomical left = User's LEFT eye  = Screen LEFT  (mirrored)
MediaPipe RIGHT_EYE [33,...]  = Anatomical right = User's RIGHT eye = Screen RIGHT (mirrored)
```

But for EAR calculations in challenges (Python lines 729-730):
```
user_left_ear  = right_ear   // MediaPipe RIGHT_EYE = User's LEFT
user_right_ear = left_ear    // MediaPipe LEFT_EYE  = User's RIGHT
```

This swap is ONLY applied for BLINK, CLOSE_LEFT, CLOSE_RIGHT challenges where the UI says "Close YOUR left/right eye." For eyebrow challenges, the swap works differently because the `calculate_eyebrow_raise` function already uses the correct perspective internally.

---

## 16. Versioning

### Semantic Versioning

The `@fivucsas/biometric-engine` package follows [Semantic Versioning](https://semver.org/):

```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes to public API (interface signatures, removed methods, renamed types)
MINOR: New features, new components, new challenge types (backward-compatible)
PATCH: Bug fixes, threshold adjustments, performance improvements
```

**Current version:** `1.0.0` (initial release after Phase 2 completion).

### Version History Plan

| Version | Milestone | Content |
|---------|-----------|---------|
| `0.1.0` | Phase 1 complete | FaceDetector, QualityAssessor, HeadPoseEstimator, FaceTracker, FaceMetricsCalculator |
| `0.2.0` | Phase 2 complete | BiometricPuzzle (14 challenges), FrameProcessor, EnrollmentController |
| `0.3.0` | Phase 3 complete | PassiveLivenessDetector, EmbeddingComputer |
| `1.0.0` | Phase 4 complete | React hooks, stable public API, all tests green |
| `1.1.0` | Phase 5 complete | Auth-test adapter, IIFE bundle |
| `1.2.0` | Phase 6 complete | CardDetector ONNX |

### Auth-Test Adapter Version Compatibility

The auth-test page (`app.js`) imports the engine as a standalone bundle. It must handle version mismatches gracefully:

```typescript
class BiometricEngineAdapter {
  static readonly COMPATIBLE_MAJOR = 1;

  constructor(engine: BiometricEngine) {
    const [major] = engine.version.split('.').map(Number);
    if (major !== BiometricEngineAdapter.COMPATIBLE_MAJOR) {
      console.warn(
        `BiometricEngineAdapter was built for engine v${BiometricEngineAdapter.COMPATIBLE_MAJOR}.x, ` +
        `but engine v${engine.version} is loaded. Some features may not work correctly.`
      );
    }
  }
}
```

### Backward-Compatible API Evolution

Rules for evolving the public API without breaking consumers:

1. **New optional parameters** can be added to existing methods (with defaults).
2. **New methods** can be added to interfaces if they have default implementations or are optional.
3. **New challenge types** are added via the registry (Section 5h) and do not change existing code.
4. **Threshold changes** are PATCH-level only if they improve accuracy without changing detection semantics.
5. **Interface extensions** use the TypeScript `extends` pattern so existing implementations remain valid.
6. **Deprecation**: Methods are marked `@deprecated` for one MINOR version before removal in the next MAJOR.

```typescript
// Example: Adding a new optional method without breaking existing code
interface IFaceDetector {
  detect(video: HTMLVideoElement, timestamp: number): FaceDetection[];
  // Added in v1.1.0 — optional, default behavior if not implemented
  detectWithROI?(video: HTMLVideoElement, roi: BoundingBox, timestamp: number): FaceDetection[];
}
```

---

## Appendix A: Landmark Connection Maps (for Rendering)

These are used by `draw_landmarks()` (Python lines 1603-1678) for optional debug visualization in the browser.

```typescript
const FACE_CONTOUR = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
  397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
  172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109, 10];

const LEFT_EYE_OUTLINE = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246, 33];

const RIGHT_EYE_OUTLINE = [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466, 263];

const LIPS_OUTER = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, 37, 39, 40, 185, 61];

const NOSE = [168, 6, 197, 195, 5, 4, 1, 19, 94, 2];

const LEFT_EYEBROW_OUTLINE = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46];

const RIGHT_EYEBROW_OUTLINE = [300, 293, 334, 296, 336, 285, 295, 282, 283, 276];
```

---

## Appendix B: Gabor Kernel Parameters

Python source (lines 382-385):
```python
cv2.getGaborKernel((21, 21), 5.0, theta, 10.0, 0.5, 0)
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| ksize | (21, 21) | Kernel size |
| sigma | 5.0 | Gaussian envelope std dev |
| theta | 0, pi/4, pi/2, 3pi/4 | 4 orientations |
| lambd | 10.0 | Wavelength of sinusoidal |
| gamma | 0.5 | Spatial aspect ratio |
| psi | 0 | Phase offset |

---

## Appendix C: HSV Conversion Formula

Python uses `cv2.cvtColor(img, cv2.COLOR_BGR2HSV)` which produces H in [0, 180], S in [0, 255], V in [0, 255].

Browser equivalent (RGB input with R, G, B in [0, 255]):

```typescript
function rgbToHsv(r: number, g: number, b: number): [number, number, number] {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const d = max - min;

  let h = 0;
  if (d !== 0) {
    if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
    if (h < 0) h += 360;
  }

  // Convert to OpenCV scale: H [0, 180], S [0, 255], V [0, 255]
  const hOpenCV = h / 2;              // 0-180
  const s = max === 0 ? 0 : (d / max) * 255;  // 0-255
  const v = max * 255;                // 0-255

  return [hOpenCV, s, v];
}
```

This matches OpenCV's BGR2HSV conversion. The skin tone thresholds in the liveness detector (H < 25, H > 165) are on this 0-180 scale.

---

*End of document. This is the single source of truth for the FIVUCSAS browser biometric engine architecture.*
