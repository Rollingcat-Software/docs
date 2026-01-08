# Gamma.app / Beautiful.ai Optimized Prompt for FIVUCSAS Presentation

Copy and paste the following prompt into Gamma.app or Beautiful.ai to generate professional slides:

---

## PROMPT:

Create a professional 17-slide presentation for a university graduation project defense. The project is called **FIVUCSAS - Face and Identity Verification Using Cloud-Based SaaS Models**.

### Presentation Requirements:
- **Format:** 16:9 aspect ratio
- **Style:** Modern, professional, clean, minimal
- **Primary Color:** Dark blue (#1e3a5f)
- **Accent Color:** Orange (#f39c12)
- **Font:** Sans-serif (Segoe UI, Inter, or similar)
- **Audience:** Academic jury, professors

### Slide Structure:

**SLIDE 1: Title Slide**
- Title: "FIVUCSAS" (large)
- Subtitle: "Face and Identity Verification Using Cloud-Based SaaS Models"
- Course: CSE4197 Engineering Project - Fall 2025
- Team: Ahmet Abdullah Gultekin (150121025), Ayse Gulsum Eren (150120005), Aysenur Arici (150123825)
- Supervisor: Assoc. Prof. Dr. Mustafa Agaoglu
- University: Marmara University - Computer Engineering
- Page number: 1/17

**SLIDE 2: Outline**
- Three sections: WHY THIS MATTERS, HOW WE SOLVE IT, WHAT WE BUILT
- 10 numbered items total
- Page number: 2/17

**SLIDE 3: Why This Matters (Problem Statement)**
- Quote: "2024: Deepfake CFO video call -> $25 Million stolen"
- Three large statistics:
  - $23B - Identity Fraud Losses (2024)
  - +400% - Deepfake Attacks (Year over Year)
  - 1 in 4 - People Cannot Detect Deepfakes
- Goal statement: "Prove LIVE + AUTHENTIC + IMPOSSIBLE to spoof"
- Page number: 3/17

**SLIDE 4: Related Work & Gap Analysis**
- Comparison table with 5 competitors: Azure, AWS, Sodec, BioGATE, FIVUCSAS
- Features: Open Source, Liveness, Multi-Tenant, Multi-Platform, NFC ICAO, Card Detection, Hybrid Liveness
- Show FIVUCSAS with checkmarks for ALL features (competitors have gaps)
- Gap statement: "No open-source solution with hybrid liveness + NFC + card detection"
- Page number: 4/17

**SLIDE 5: Scope & Engineering Constraints**
- IN SCOPE (6 items with checkmarks): Cloud-Native SaaS, Hybrid Liveness Detection, Card Detection ML Model, NFC Document Reading, Multi-Tenant Dashboard, Cross-Platform Apps
- OUT OF SCOPE: Hardware Manufacturing (with X)
- Engineering Constraints box: >480p Image Quality, <200ms API Latency, ISO 14443 NFC Standard
- Page number: 5/17

**SLIDE 6: System Architecture**
- Visual architecture diagram:
  - Top: NGINX API Gateway (Rate Limiting, Routing, Load Balancing)
  - Middle (3 boxes): Identity Core (Spring Boot Java 21), Biometric Processor (FastAPI Python 3.11), Client Apps (Kotlin Multiplatform)
  - Bottom: PostgreSQL 16 + pgvector, Redis
- Note: Hexagonal Architecture + DDD
- Page number: 6/17

**SLIDE 7: The Biometric Puzzle - Hybrid Liveness**
- Challenge-response flow diagram:
  - Server generates random challenge ("Blink Left Eye")
  - Mobile client captures with 468 facial landmarks (MediaPipe)
  - EAR calculation (threshold < 0.2)
  - Passive analysis (LBP texture check)
- Two categories: ACTIVE (EAR, MAR, Head Pose) and PASSIVE (LBP Texture, Color, Frequency)
- Page number: 7/17

**SLIDE 8: Biometric Processor Demo**
- Three boxes showing team member faces with 468 mesh overlay (placeholders)
- Each box shows: EAR value, Quality score, "LIVE" status
- Caption: "All team members verified with 468 facial landmarks + liveness detection"
- Page number: 8/17

**SLIDE 9: ML Pipeline & Vector Search**
- Pipeline: Input -> Detect (MediaPipe) -> Align (5-Point) -> Extract (Embedding) -> Search (Cosine)
- Vector Database: PostgreSQL + pgvector + IVFFlat -> O(log n) sub-ms queries
- Threshold: cosine distance < 0.68 = MATCH
- Page number: 9/17

**SLIDE 10: Card Detection & NFC Verification**
- Two-step process:
  - Step 1: Visual Card Detection (ML Model) - Camera -> Trained Model -> Card Type Detected
  - Step 2: NFC Chip Verification (ICAO) - Mobile NFC -> BAC Handshake -> Read DG1/DG2 -> SOD Verification
- Standards: ICAO Doc 9303, ISO/IEC 14443, ISO 7816-4
- Card types: Turkish eID, e-Passport, MIFARE, NDEF, 10+ types
- Page number: 10/17

**SLIDE 11: Document Verification Demo**
- Split view:
  - Left: Card Detection results (Turkish eID 97.3%, e-Passport 98.1%)
  - Right: NFC reading results (BAC, DG1, DG2, SOD - all with checkmarks)
- Page number: 11/17

**SLIDE 12: Tasks Accomplished**
- 22 implemented features in 3 columns:
  - Biometric Features (8): Face Detection, Enrollment, Verification, Search, Biometric Puzzle, Quality Analysis, Demographics, Similarity
  - Document Verification (6): Card Detection ML, NFC Reading, BAC, SOD, MRZ, 10+ Card Types
  - Infrastructure (8): JWT Auth, Multi-Tenant, 40+ APIs, PostgreSQL pgvector, IVFFlat, Redis, Flyway, Kotlin MP
- Web Demo GUI: 6 pages
- Page number: 12/17

**SLIDE 13: Technical Challenges**
- 3 challenges with solutions:
  1. NFC Passport Integration - Complex ICAO protocols -> 7 specialized readers
  2. Card Detection Training - Dataset + accuracy -> Custom dataset + on-device inference
  3. Cross-Language Communication - Java <-> Python -> REST APIs + OpenAPI + Redis
- Page number: 13/17

**SLIDE 14: Semester 2 Plans & B-Plan**
- Timeline: FEB (Integration + OCR), MAR (Proctoring), APR (Security Testing), MAY (Deployment)
- Contingency Plan: If NFC fails -> Focus Turkish eID + e-Passport; If delayed -> Web demo primary
- Future Research: Offline mode, Fingerprint & iris, Embedded devices
- Page number: 14/17

**SLIDE 15: Thank You**
- Dark blue background with white text
- Thank advisor message
- GitHub: github.com/Rollingcat-Software/FIVUCSAS
- "Will be released as open-source"
- Page number: 15/17

**SLIDE 16: References**
- 6 academic references:
  1. DeepFace (Taigman 2014)
  2. FaceNet (Schroff 2015)
  3. ArcFace (Deng 2019)
  4. MediaPipe (Lugaresi 2019)
  5. ICAO Doc 9303
  6. ISO/IEC 14443 & ISO 7816-4
- Page number: 16/17

**SLIDE 17: Q&A**
- Dark blue background
- "Questions & Answers" title
- "We welcome your questions."
- Page number: 17/17

### Design Guidelines:
1. Use dark blue (#1e3a5f) for headers and primary elements
2. Use orange (#f39c12) for accents and highlights
3. Use green checkmarks for positive items, red X for negative
4. Keep text minimal, use visual elements where possible
5. Include page numbers on ALL slides (format: X/17)
6. Use consistent spacing and alignment
7. Diagrams should be clean and modern
8. Tables should have dark blue headers
9. Statistics should be displayed prominently with large numbers
10. Use rounded rectangles for content boxes

---

## ADDITIONAL TIPS FOR GAMMA.APP:

1. **Start with:** "Create a presentation about FIVUCSAS, a face and identity verification system"
2. **Specify style:** "Professional, academic, minimal design with dark blue and orange colors"
3. **For each slide, provide:** Title, key points, visual suggestions
4. **Ask for:** "16:9 format, sans-serif fonts, page numbers on each slide"

## ADDITIONAL TIPS FOR BEAUTIFUL.AI:

1. Use the "Technology" or "Professional" template
2. Customize colors to match the brand (#1e3a5f, #f39c12)
3. Use the "Stats" slide type for Slide 3
4. Use the "Comparison Table" for Slide 4
5. Use the "Process Flow" for Slides 7, 9, 10
6. Use the "Three Column" layout for Slide 12

---

**Note:** After generating, manually replace placeholder text with actual screenshots from your demo:
- Slide 8: Team member faces with 468 mesh overlay
- Slide 11: Card detection and NFC verification screenshots
- Slide 1: Add Marmara University logo
