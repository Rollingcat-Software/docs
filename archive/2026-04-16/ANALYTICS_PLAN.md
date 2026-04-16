# Analytics & Tracking Plan — FIVUCSAS

**Created**: 2026-04-10

---

## What to Set Up (Priority Order)

### 1. Google Search Console (Free — Do This First, 10 min)

- **Site**: fivucsas.com
- **Why**: Understand how Google indexes the site, fix crawl errors, submit sitemap
- **DNS TXT record already exists**: `google-site-verification=RTnOyspxMve8PKsFb3cUAmPpEz-PMTUEwb8vKwh3L44`
- **Setup**:
  1. Go to search.google.com/search-console
  2. Add property → `https://fivucsas.com`
  3. Choose "DNS record" verification — it will auto-verify (TXT record already in DNS)
  4. Submit sitemap: `https://fivucsas.com/sitemap.xml`
- **What to monitor**: Search queries, click-through rate, crawl errors

### 2. Google Analytics 4 (Free — 15 min)

- **Where**: fivucsas.com + demo.fivucsas.com
- **NOT on**: app.fivucsas.com (authenticated dashboard — GDPR/KVKK concern)
- **Setup**:
  1. Go to analytics.google.com
  2. Create Account → Create Property → Web
  3. Add `fivucsas.com` → get Measurement ID (format: `G-XXXXXXXXXX`)
  4. Add the GA4 snippet to landing-website/index.html `<head>`:
  ```html
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-XXXXXXXXXX');
  </script>
  ```
  5. Rebuild and deploy landing-website
- **Events to track**:
  - `click_demo` — "Live Demo" button in hero
  - `click_dashboard` — "Try Admin Dashboard" button
  - `click_github` — GitHub link clicks
  - Page views, scroll depth (auto-collected by GA4)

### 3. Cookie Consent Banner (Required before GA4 for KVKK compliance)

Add a simple banner to fivucsas.com before enabling analytics:

```html
<!-- Add to landing-website/index.html before </body> -->
<div id="cookie-banner" style="position:fixed;bottom:0;left:0;right:0;background:#1e293b;color:#cbd5e1;padding:16px 24px;display:flex;justify-content:space-between;align-items:center;z-index:9999;font-size:14px;">
  <span>Bu site Google Analytics kullanmaktadır. <a href="#" style="color:#60a5fa;">Gizlilik Politikası</a></span>
  <button onclick="document.getElementById('cookie-banner').style.display='none';localStorage.setItem('cookies_accepted','true')" style="background:#3b82f6;color:white;border:none;padding:8px 16px;border-radius:6px;cursor:pointer;">Kabul Et</button>
</div>
<script>
  if(localStorage.getItem('cookies_accepted')) document.getElementById('cookie-banner').style.display='none';
</script>
```

### 4. Uptime Kuma (Already Running)

- **URL**: https://status.fivucsas.com
- All services already monitored
- Public status page already live

---

## NOT Recommended Right Now

| Tool | Reason to Skip |
|------|---------------|
| Google Ads | No revenue model yet; organic first |
| Hotjar / Clarity | Overkill for current stage |
| Facebook Pixel | Not relevant for B2B/academic project |
| Mixpanel | GA4 is sufficient |

---

## GitHub Actions: Deployment Notes

The DNS TXT record for Google Search Console is already in place:
```
TXT  fivucsas.com  "google-site-verification=RTnOyspxMve8PKsFb3cUAmPpEz-PMTUEwb8vKwh3L44"
```
Just add the property in Search Console and it will verify instantly.
