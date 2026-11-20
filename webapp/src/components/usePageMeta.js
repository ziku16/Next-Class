import { useEffect } from 'react';
import { releaseConfig } from '../data/releaseConfig.js';

export default function usePageMeta({ title, description, path }) {
  useEffect(() => {
    document.title = title;
    document.querySelector('meta[name="description"]')?.setAttribute('content', description);
    document.querySelector('meta[property="og:title"]')?.setAttribute('content', title);
    document.querySelector('meta[property="og:description"]')?.setAttribute('content', description);
    const canonical = document.querySelector('link[rel="canonical"]');
    if (releaseConfig.siteUrl) {
      const link = canonical ?? document.head.appendChild(Object.assign(document.createElement('link'), { rel: 'canonical' }));
      link.href = `${releaseConfig.siteUrl}${path}`;
      document.querySelector('meta[property="og:url"]')?.setAttribute('content', `${releaseConfig.siteUrl}${path}`);
      document.querySelector('meta[property="og:image"]')?.setAttribute('content', `${releaseConfig.siteUrl}/images/og-card.svg`);
    } else if (canonical) canonical.remove();
  }, [description, path, title]);
}
