# NextClass Webapp

Standalone React 18 website for the NextClass Android app. All source and site assets live in this directory; the legacy root website and Flutter source are separate.

## Local development

```sh
npm install
npm run dev
```

Build and verify:

```sh
npm test
npm run build
npm run preview
```

The build output is `webapp/dist/`. React Router uses Cloudflare Pages’ `public/_redirects` fallback so routes such as `/features` and `/privacy` work when opened directly or refreshed.

## GitHub APK release configuration

The single release configuration is `src/data/releaseConfig.js`. It points to the official `ziku16/Next-Class` GitHub Releases API. The site checks the latest stable release and activates the APK button only when it finds a non-empty uploaded `.apk` asset whose URL belongs to that repository’s release downloads. No APK URL, version, file size, or release date is fabricated. If GitHub has no usable release, or its API is unavailable, the download control stays disabled and visitors can open the official Releases page.

For version, size, date, and compatibility details, add a verified `Minimum Android: ...` line to the release notes. The displayed changelog comes directly from the release body. Do not commit Gemini credentials or put them into website environment variables.

## Real app screenshots

No Flutter screenshots were present when this website was built. Gallery frames are explicitly labeled placeholders and do not pretend to be app screens. Capture these real screens from a running Android app and save optimized portrait PNG or WebP files here:

- `public/images/screenshots/today.png` — Today screen with current/next class context.
- `public/images/screenshots/weekly-timetable.png` — weekly timetable view.
- `public/images/screenshots/quiz-tracking.png` — quizzes list and status.
- `public/images/screenshots/exam-mode.png` — only after Automatic Exam Mode is implemented and released.
- `public/images/screenshots/exam-date-sheet-scanner.png` — only after exam date-sheet import is implemented and released.

Remove private names, course details, notifications, and student identifiers before publishing screenshots. Do not supply exam-feature images until those features actually ship. Then update `src/pages/ScreenshotsPage.jsx` to use the real assets with meaningful alt text.

## Cloudflare Pages

Create a Pages project connected to this repository and set:

- **Root directory:** `webapp`
- **Build command:** `npm run build`
- **Build output directory:** `dist`
- **Node.js version:** 20.19+ or 22.12+

After the first Pages build, set `VITE_SITE_URL` to that actual HTTPS origin (for example the assigned `*.pages.dev` origin) in the Production build environment, then rebuild. This adds canonical and Open Graph URLs, plus a sitemap and the matching `robots.txt` sitemap reference. Without the real URL, the site builds with no canonical URL or sitemap. No custom domain or paid service is required.

## Privacy and status accuracy

The Privacy route reflects the current client implementation: saved data stays in local SQLite, while optional timetable scanning preprocesses the chosen image and sends it to Google Gemini over the internet. The current code does not implement exam-sheet import or Automatic Exam Mode, so both are marked as coming soon. Review Google’s current Gemini API terms before any public scanning release; the Android app’s build-time API key can be extracted from a public APK.
