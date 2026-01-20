# UI Screenshots Guide for ADD Section 4.3

**TEAM ACTION REQUIRED:** Capture these screenshots and add them to the ADD document.

---

## Critical Requirement

**CSE4197 ADD Guide states:**
> "In this section, you are expected to provide sample screen-shots of your project's Graphical User Interfaces."

Your ADD currently has only textual descriptions. Screenshots are **mandatory** for academic compliance.

---

## Required Screenshots

### A. Demo Web UI (biometric-processor/demo-ui/)

According to `IMPLEMENTATION_STATUS_REPORT.md`, you have 14+ implemented pages. Capture these:

#### Priority 1: Core Flows (Must Have)

1. **Login/Authentication Screen**
   - File: Save as `ADD_screenshots/01_login.png`
   - What to show: Login form with email/password fields
   - URL: `http://localhost:3000/login` (or actual URL)

2. **Dashboard Overview**
   - File: Save as `ADD_screenshots/02_dashboard.png`
   - What to show: Admin dashboard with metrics overview
   - URL: `/dashboard`

3. **Face Enrollment Page**
   - File: Save as `ADD_screenshots/03_enrollment.png`
   - What to show: Camera feed + enrollment form
   - URL: `/enrollment`
   - **Important:** Show webcam active with face detection box

4. **Face Verification Page**
   - File: Save as `ADD_screenshots/04_verification.png`
   - What to show: 1:1 verification interface
   - URL: `/verification`

5. **Liveness Detection (Biometric Puzzle)**
   - File: Save as `ADD_screenshots/05_liveness_challenge.png`
   - What to show: Active challenge in progress (e.g., "Blink your eyes" instruction)
   - URL: `/liveness`
   - **This is unique to your project - must show!**

#### Priority 2: Advanced Features (Highly Recommended)

6. **Face Search (1:N)**
   - File: Save as `ADD_screenshots/06_search_results.png`
   - What to show: Search results with similarity scores
   - URL: `/search`

7. **Quality Analysis**
   - File: Save as `ADD_screenshots/07_quality_analysis.png`
   - What to show: Image quality metrics (brightness, sharpness, etc.)
   - URL: `/quality`

8. **Facial Landmarks Visualization**
   - File: Save as `ADD_screenshots/08_landmarks.png`
   - What to show: 468-point landmark overlay on face
   - URL: `/landmarks`

9. **Demographics Analysis**
   - File: Save as `ADD_screenshots/09_demographics.png`
   - What to show: Age/gender/emotion detection results
   - URL: `/demographics`

10. **Proctoring Session**
    - File: Save as `ADD_screenshots/10_proctoring.png`
    - What to show: Real-time monitoring dashboard
    - URL: `/session` or `/realtime`

### B. Mobile Application (client-apps/androidApp/)

If the UI is implemented (even without backend connection):

11. **Android Login Screen**
    - File: Save as `ADD_screenshots/11_mobile_login.png`
    - What to show: Mobile login interface
    - **How to capture:** Android emulator screenshot (Ctrl+S in Android Studio)

12. **Android Enrollment Screen**
    - File: Save as `ADD_screenshots/12_mobile_enrollment.png`
    - What to show: CameraX preview with enrollment UI

### C. Desktop Application (client-apps/desktopApp/)

If running:

13. **Desktop Kiosk Mode**
    - File: Save as `ADD_screenshots/13_desktop_kiosk.png`
    - What to show: Self-service kiosk interface

14. **Desktop Admin Dashboard**
    - File: Save as `ADD_screenshots/14_desktop_admin.png`
    - What to show: Admin panel with tabs

---

## How to Capture Screenshots

### For Web UI (Demo GUI):

```bash
# 1. Start the demo UI
cd biometric-processor/demo-ui
npm run dev

# 2. Open browser to http://localhost:3000

# 3. Capture screenshots using:
#    - Browser DevTools (F12 → Device toolbar for responsive)
#    - Browser screenshot: Ctrl+Shift+S (Firefox) or use extension
#    - OS screenshot tool: Windows Snipping Tool, macOS Cmd+Shift+4

# 4. Save with descriptive names in ADD_screenshots/ folder
```

### For Mobile App:

```bash
# 1. Run Android emulator
cd client-apps
./gradlew :androidApp:installDebug

# 2. In Android Studio: Emulator → Camera icon OR Ctrl+S

# 3. Screenshot saves to: ~/Desktop/ or emulator screenshot folder
```

### For Desktop App:

```bash
# 1. Run desktop app
cd client-apps
./gradlew :desktopApp:run

# 2. Use OS screenshot tool
```

---

## Screenshot Quality Standards

For each screenshot:
- **Resolution:** Minimum 1280x720, ideally 1920x1080
- **Format:** PNG (preferred) or JPG
- **Content:** Ensure no sensitive test data (use dummy data)
- **Clarity:** Avoid blurry images
- **Context:** Show complete UI, not partial crops
- **Annotations:** Optional but helpful - add arrows/labels for key features

---

## Integration into ADD Document

Once screenshots are captured:

1. Create folder: `/home/user/docs/ADD_screenshots/`
2. Move all images there
3. Update `ADD_FIVUCSAS.md` Section 4.3 with:

```markdown
### 4.3 User Interface Design

#### 4.3.1 Web Admin Dashboard

![Dashboard Overview](ADD_screenshots/02_dashboard.png)
*Figure 4.3.1: Admin dashboard showing biometric enrollment statistics and system health*

#### 4.3.2 Face Enrollment Interface

![Enrollment Page](ADD_screenshots/03_enrollment.png)
*Figure 4.3.2: Face enrollment page with live camera feed and quality assessment*

[Continue for all screenshots...]
```

---

## Alternative: Wireframes

If you cannot provide actual screenshots (e.g., services not running), you may use:
- **Figma/Excalidraw wireframes** - Quick mockups
- **Hand-drawn diagrams** - Scanned and digitized
- **UI component screenshots** - Show individual components

**However:** Actual screenshots are **strongly preferred** since the UI is already implemented.

---

## Section 4.3 Enhanced Structure

Replace the current table-based description with:

```markdown
## 4.3 User Interface Design

### 4.3.1 Design Principles
- Material Design 3 (web and mobile)
- Responsive layout (mobile-first)
- Accessibility compliance (WCAG 2.1 AA)
- Real-time feedback for biometric operations

### 4.3.2 Web Admin Dashboard
[Screenshot + description]

### 4.3.3 Biometric Enrollment Flow
[Screenshot + step-by-step description]

### 4.3.4 Liveness Detection Interface
[Screenshot highlighting biometric puzzle]

### 4.3.5 Mobile Application
[Screenshots from Android app]

### 4.3.6 Desktop Kiosk Mode
[Screenshot from desktop app]

### 4.3.7 UI Component Library
- shadcn/ui for web
- Jetpack Compose for mobile
- Compose Multiplatform for desktop
```

---

## Estimated Time

- **Capturing screenshots:** 30-45 minutes
- **Organizing and annotating:** 15 minutes
- **Updating ADD document:** 30 minutes
- **Total:** ~1.5 hours

---

## Notes

- **Dummy data:** Use test accounts like `test@example.com` for screenshots
- **Privacy:** Blur/redact any sensitive information
- **Consistency:** Use same theme/styling across screenshots
- **Captions:** Write descriptive figure captions (Figure 4.3.X: ...)

---

**Guide Created:** January 20, 2026
**Purpose:** Fulfill CSE4197 ADD Section 4.3 requirement
**Priority:** CRITICAL - Required for ADD compliance
