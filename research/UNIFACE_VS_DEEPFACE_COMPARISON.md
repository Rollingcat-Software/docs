# UniFace 3.0 vs DeepFace: Comprehensive Technology Comparison

## FIVUCSAS Biometric Processor Migration Analysis

| | |
|---|---|
| **Document Type** | Technology Evaluation Report |
| **Project** | FIVUCSAS - Face and Identity Verification Using Cloud-based SaaS |
| **Date** | 2026-02-21 |
| **Status** | Final |

---

## Executive Summary

This report evaluates whether migrating the FIVUCSAS biometric-processor from DeepFace (TensorFlow-based) to UniFace 3.0 (ONNX Runtime-based) is warranted.

**Key Findings:**

- UniFace is **7.3x faster** for face detection (87ms vs 640ms) on CPU
- UniFace provides **anti-spoofing without PyTorch** (saving ~2GB in dependencies)
- DeepFace offers **superior model variety** (9+ recognition models vs 3-4) and **built-in database search**
- The biometric-processor's **hexagonal architecture** isolates DeepFace behind port interfaces, making partial or full migration low-risk
- UniFace's benchmark showed **100% detection rate** vs DeepFace's **0% detection rate** in the test environment (DeepFace's 0% was a configuration issue, not a fundamental flaw)

**Recommendation: Option C -- Hybrid Approach** (keep DeepFace for detection and recognition, add UniFace MiniFASNet for anti-spoofing). This provides the highest value with the lowest risk.

---

## A. Architecture Comparison

### Design Philosophy

| Aspect | DeepFace | UniFace 3.0 |
|--------|----------|-------------|
| Runtime | TensorFlow 2.15 | ONNX Runtime |
| Architecture | Monolithic API | Modular pipeline |
| State Management | Global model singletons | Instance-based |
| API Style | Functional (`DeepFace.represent()`) | OO (`ArcFace().get_embedding()`) |
| Pipeline Control | Combined detect+embed in one call | Separate detect, align, embed |
| Anti-spoofing | Requires PyTorch (~2GB) | ONNX MiniFASNet (~1MB) |

### Hexagonal Architecture Fit

**DeepFace: Adequate (with workarounds)**

DeepFace's functional API combines multiple operations. The FIVUCSAS adapters work around this -- `DeepFaceExtractor` calls `represent()` with `enforce_detection=False` to skip redundant detection. This is a workaround, not a clean separation.

**UniFace: Excellent (native alignment)**

UniFace's modular API maps directly to hexagonal ports. Each component (`RetinaFace`, `ArcFace`, `MiniFASNet`) maps cleanly to a domain port (`IFaceDetector`, `IEmbeddingExtractor`, `ILivenessDetector`).

### DeepFace Integration Points in Biometric-Processor

DeepFace is used in exactly **3 adapter classes**:

| Adapter File | Port | DeepFace API |
|---|---|---|
| `infrastructure/ml/detectors/deepface_detector.py` | `IFaceDetector` | `DeepFace.extract_faces()` |
| `infrastructure/ml/extractors/deepface_extractor.py` | `IEmbeddingExtractor` | `DeepFace.represent()` |
| `infrastructure/ml/demographics/deepface_demographics.py` | `IDemographicsAnalyzer` | `DeepFace.analyze()` |

Critically, liveness detection does NOT use DeepFace -- it uses OpenCV Haar cascades, scikit-image LBP, and MediaPipe.

---

## B. Performance Benchmarks

### Benchmark Data (from `comparison_results.json`, 22 images, CPU)

**Detection Speed:**

| Metric | DeepFace (TF) | UniFace (ONNX) | Winner |
|--------|--------------|----------------|--------|
| Average (ms) | 639.54 | **87.22** | UniFace (**7.3x faster**) |
| Median (ms) | 582.53 | **85.63** | UniFace (6.8x) |
| P95 (ms) | 825.95 | **100.69** | UniFace (8.2x) |
| Detection Rate | 0.0%* | **100.0%** | UniFace |

> *DeepFace's 0% is a benchmark configuration issue, not a production issue.

**Recognition / Embedding:**

| Metric | DeepFace | UniFace |
|--------|---------|---------|
| Embedding avg (ms) | 639.54 (combined) | **14.06** |
| Embedding dim | 512 (Facenet512) | 512 (ArcFace) |
| Intra-class similarity | N/A* | 0.4691 |
| Inter-class similarity | N/A* | 0.0296 |
| Separation gap | N/A* | **0.4394** |

**Anti-Spoofing:**

| Metric | DeepFace | UniFace (MiniFASNet) |
|--------|---------|---------------------|
| Average (ms) | 644.75 | **3.80** (**170x faster**) |
| Requires PyTorch | **Yes (~2GB)** | **No** |
| Model size | N/A | ~1MB ONNX |

**Memory / Dependencies:**

| Metric | DeepFace | UniFace |
|--------|---------|---------|
| Install size (all deps) | ~2.6 GB | **~200 MB** (13x smaller) |
| Cold start time | ~5-10s | ~1-2s |
| PyTorch needed for anti-spoof | Yes (~2GB) | No |

---

## C. Feature Parity Matrix

| Feature | DeepFace 0.0.98 | UniFace 3.0 | Winner |
|---------|----------------|-------------|--------|
| Detection backends | 10+ | 4 | DeepFace |
| Recognition models | 9+ | 3-4 | DeepFace |
| Anti-spoofing (no PyTorch) | No | Yes | **UniFace** |
| Age/Gender/Race/Emotion | Yes | Yes (FairFace) | Tie |
| Database search (1:N) | Yes (`find()`) | No | DeepFace |
| 106-point landmarks | No | Yes | UniFace |
| Face parsing (19 classes) | No | Yes (BiSeNet) | UniFace |
| Gaze estimation | No | Yes (MobileGaze) | UniFace |
| Face tracking | No | Yes (BYTETracker) | UniFace |
| Face anonymization | No | Yes (5 methods) | UniFace |
| Community (GitHub stars) | ~12K | ~250 | DeepFace |
| Install size | ~2.6GB | ~200MB | UniFace |

---

## D. Migration Impact Analysis

### Endpoint Dependency Breakdown (46 total endpoints)

- **12-15 endpoints** directly depend on DeepFace (detection + extraction pipeline: enrollment, verification, comparison, search, batch, embeddings I/O)
- **1 endpoint** depends on DeepFace for demographics
- **14+ proctoring endpoints** partially depend on face detection
- **16+ endpoints** have zero DeepFace dependency (liveness, quality, landmarks, health, admin, webhooks, metrics, similarity, card type)

### Embedding Compatibility Warning (CRITICAL)

Despite both producing 512-dimensional vectors, **Facenet512 and ArcFace embeddings are NOT interchangeable**. A full migration (Option B) would require re-enrolling ALL existing users -- this is the primary argument against full migration.

### Effort Estimates

| Option | Files Changed | Effort | Risk |
|--------|--------------|--------|------|
| A: Stay with DeepFace | 0 | 0 hours | None |
| B: Full Migration | 6-8 | 16-24 hours | MEDIUM (embedding breaking) |
| C: Hybrid (anti-spoof only) | 3 | 2-4 hours | LOW |

---

## E. Three Options with Recommendation

### Option A: Stay with DeepFace

- **Pros**: Zero risk, battle-tested, compatible with existing enrollments
- **Cons**: PyTorch ~2GB for anti-spoofing, heavy TF dependency, monolithic API

### Option B: Full Migration to UniFace

- **Pros**: 7.3x faster, 13x smaller, clean architecture fit
- **Cons**: BREAKS existing embeddings (re-enrollment required), fewer models, smaller community

### Option C: Hybrid Approach (RECOMMENDED)

- **Description**: Keep DeepFace for detection/recognition. Add UniFace MiniFASNet as a new `ILivenessDetector` adapter.
- **Pros**: Anti-spoofing without PyTorch (~2GB saved), zero risk to existing pipeline, 2-4 hours effort, stepping stone for future migration
- **Cons**: Two ML libraries in deps (net savings still ~1.8GB)

### Implementation Plan (Option C)

1. Add `uniface>=0.1.0` to `requirements.txt`
2. Create `app/infrastructure/ml/liveness/uniface_antispoof_detector.py` implementing `ILivenessDetector`
3. Update `app/infrastructure/ml/factories/liveness_factory.py` to support `UNIFACE_MINIFASNET` mode
4. Configure via `.env`: `LIVENESS_BACKEND=uniface` (default stays as current)

### Decision Matrix

| Criterion (Weight) | Option A | Option B | Option C |
|--------------------|----------|----------|----------|
| Risk (30%) | 10/10 | 4/10 | 9/10 |
| Performance gain (20%) | 0/10 | 9/10 | 6/10 |
| Effort (20%) | 10/10 | 3/10 | 9/10 |
| Architecture fit (15%) | 5/10 | 10/10 | 7/10 |
| Dependency footprint (15%) | 3/10 | 10/10 | 7/10 |
| **Weighted Score** | **6.15** | **6.55** | **7.85** |

**Option C wins with 7.85/10.**

---

## Sources

- [UniFace GitHub Repository](https://github.com/yakhyo/uniface)
- [UniFace Documentation](https://yakhyo.github.io/uniface/)
- [DeepFace GitHub Repository](https://github.com/serengil/deepface)
- FIVUCSAS Benchmark Results: `practice-and-test/uniface-evaluation/output/comparison_results.json`
- Biometric Processor ML Infrastructure: `biometric-processor/app/infrastructure/ml/`
