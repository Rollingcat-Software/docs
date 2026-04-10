# Analytics & Tracking Plan — FIVUCSAS

## What to Set Up

### 1. Google Analytics 4 (Free)
- **Where**: fivucsas.com (landing) + demo.fivucsas.com
- **NOT on**: app.fivucsas.com (dashboard — privacy, GDPR/KVKK)
- **Setup**: analytics.google.com → Create Account → Web Property
- **Metrics to track**: page views, demo clicks, "Get Started" clicks, time on page
- **Code location**: landing-website/index.html (placeholder already added, uncomment after setup and replace G-XXXXXXXXXX)

### 2. Google Search Console (Free — Highest Priority)
- **Where**: fivucsas.com
- **Setup**: search.google.com/search-console → Add property → verify
- **DNS TXT already exists**: google-site-verification=RTnOyspxMve8PKsFb3cUAmPpEz-PMTUEwb8vKwh3L44
- **Action**: Just add fivucsas.com in Search Console — it will auto-verify via the existing TXT record
- **Time to set up**: ~10 minutes

### 3. Uptime Kuma (Already running)
- **URL**: https://status.fivucsas.com
- **Monitors**: All services already configured, no action needed

### 4. NOT recommended (for now)
- Google Ads: Too early, no revenue model yet
- Hotjar/FullStory: Overkill for current stage
- Facebook Pixel: Not needed

## Priority Order
1. **Google Search Console** — 10 min setup, immediate SEO benefit (indexing status, keywords, crawl errors)
2. **Google Analytics 4** — 15 min setup, understand landing page traffic (requires GA4 property first)
3. **Cookie consent banner** — Required before enabling GA4 for KVKK/GDPR compliance
4. **Google Ads** — Only after GA shows organic traffic bottleneck

## Implementation Steps

### Step 1: Google Search Console (do this now)
1. Go to https://search.google.com/search-console
2. Click "Add property" → choose "Domain" → enter `fivucsas.com`
3. It will ask for DNS TXT verification — the record already exists, so it should auto-verify
4. Submit sitemap: `https://fivucsas.com/sitemap.xml` (if one exists)

### Step 2: Google Analytics 4
1. Go to https://analytics.google.com
2. Create Account → Property → Web Stream → enter `https://fivucsas.com`
3. Copy the Measurement ID (format: G-XXXXXXXXXX)
4. In `landing-website/index.html`, uncomment the GA4 block and replace `G-XXXXXXXXXX`
5. Build and deploy: `npm run build` then SCP to Hostinger

### Step 3: Cookie Consent (KVKK/GDPR)
Add a simple banner before enabling GA4. Options:
- Simple HTML/CSS banner (store consent in localStorage)
- `react-cookie-consent` npm package if converting to React
- Only activate GA4 if user accepts

## GDPR/KVKK Note
GA4 collects IP addresses and sets cookies — this requires user consent under KVKK (Turkish law).
Add a cookie consent banner to fivucsas.com BEFORE enabling GA4 in production.
