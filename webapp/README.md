# NextClass Website

React 18 site with routes for the homepage, features, screenshots, download, and privacy.

## Develop and verify

```sh
npm install
npm run dev
npm test
npm run build
```

The build output is `dist/`. `public/_redirects` sends direct route requests to the React app so nested routes work after refresh.

## Downloads

`src/data/releaseConfig.js` is the source of the official GitHub release endpoint. The download control activates only for an uploaded APK attached to the latest stable release. The page displays the version from that release and keeps technical release metadata out of the public UI. No local APK is bundled in the Pages build.

## Search metadata

Set `VITE_SITE_URL` to the deployed HTTPS origin when building for production. The build script uses it for canonical and Open Graph URLs, `sitemap.xml`, and the sitemap reference in `robots.txt`. Do not set an invented origin.

## Cloudflare Pages

- Root directory: `webapp`
- Build command: `npm run build`
- Build output directory: `dist`

## App previews

The seven Flutter-rendered previews are in `public/images/screenshots/`. They use sample data and are not device photographs.

## Privacy accuracy

The release implementation routes timetable and exam-sheet scans through the NextClass Cloudflare Worker to Gemini. Keep the public Privacy route aligned with the Flutter parsers and Worker retention behavior when those implementations change.
