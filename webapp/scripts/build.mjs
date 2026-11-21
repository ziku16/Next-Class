import { execFileSync } from 'node:child_process';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(project, 'dist');
const viteCli = path.join(project, 'node_modules', 'vite', 'bin', 'vite.js');

execFileSync(process.execPath, [viteCli, 'build'], { cwd: project, stdio: 'inherit' });

// The local development APK is never part of the production website bundle.
await rm(path.join(output, 'downloads', 'NextClass-v1.0.1-universal.apk'), { force: true });
await rm(path.join(output, 'downloads', 'NextClass-v1.0.1.apk'), { force: true });

const configuredUrl = process.env.VITE_SITE_URL?.trim().replace(/\/+$/, '') ?? '';
let siteUrl = '';
if (configuredUrl) {
  const parsed = new URL(configuredUrl);
  if (parsed.protocol !== 'https:' || parsed.pathname !== '/' || parsed.search || parsed.hash) {
    throw new Error('VITE_SITE_URL must be a clean HTTPS origin, for example https://your-project.pages.dev');
  }
  siteUrl = parsed.origin;
}

const indexPath = path.join(output, 'index.html');
let html = await readFile(indexPath, 'utf8');
html = html.replace(/\s*<link rel="canonical" href=""\s*\/>/i, '');
html = html.replace(/<meta property="og:image" content="[^"]*"\s*\/>/i, `<meta property="og:image" content="${siteUrl ? `${siteUrl}/images/og-card.svg` : '/images/og-card.svg'}" />`);
if (siteUrl) {
  html = html.replace('</head>', `    <link rel="canonical" href="${siteUrl}/" />\n    <meta property="og:url" content="${siteUrl}/" />\n  </head>`);
}
await writeFile(indexPath, html);

const sitemapPath = path.join(output, 'sitemap.xml');
const robotsPath = path.join(output, 'robots.txt');
if (siteUrl) {
  const routes = ['/', '/features', '/screenshots', '/download', '/privacy'];
  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${routes.map((route) => `  <url><loc>${siteUrl}${route}</loc></url>`).join('\n')}\n</urlset>\n`;
  await writeFile(sitemapPath, sitemap);
  await writeFile(robotsPath, `User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`);
} else {
  await rm(sitemapPath, { force: true });
  await mkdir(output, { recursive: true });
  await writeFile(robotsPath, 'User-agent: *\nAllow: /\n');
  console.warn('VITE_SITE_URL is unset; sitemap and canonical URL are omitted. Set it to your actual HTTPS Pages origin before launch.');
}

