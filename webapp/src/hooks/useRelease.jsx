import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { formatFileSize, getLocalRelease, isOfficialApkAsset, parseReleaseField, parseSha256Digest, releaseConfig } from '../data/releaseConfig.js';

const ReleaseContext = createContext(null);

export function ReleaseProvider({ children }) {
  const [release, setRelease] = useState({ status: 'loading', data: null });

  useEffect(() => {
    const localRelease = getLocalRelease();
    if (localRelease) {
      setRelease({ status: 'available', data: localRelease });
      return undefined;
    }

    const controller = new AbortController();
    fetch(releaseConfig.latestReleaseApi, {
      headers: { Accept: 'application/vnd.github+json' },
      signal: controller.signal,
    })
      .then((response) => {
        if (response.status === 404) return null;
        if (!response.ok) throw new Error(`Release lookup returned ${response.status}`);
        return response.json();
      })
      .then((releaseInfo) => {
        if (controller.signal.aborted) return;
        const asset = releaseInfo?.assets?.find(isOfficialApkAsset);
        const releaseBody = releaseInfo?.body ?? '';
        if (!releaseInfo || releaseInfo.draft || releaseInfo.prerelease || !asset) {
          setRelease({ status: 'unavailable', data: null });
          return;
        }
        setRelease({
          status: 'available',
          data: {
            version: releaseInfo.tag_name,
            url: asset.browser_download_url,
            fileName: asset.name,
            size: formatFileSize(asset.size),
            sizeBytes: asset.size,
            architecture: parseReleaseField(releaseBody, 'Architecture'),
            checksum: parseSha256Digest({ digest: asset.digest, body: releaseBody }),
            published: releaseInfo.published_at ? new Date(releaseInfo.published_at) : null,
            minimumAndroid: parseReleaseField(releaseBody, 'Minimum Android'),
            notes: releaseBody.trim(),
          },
        });
      })
      .catch(() => {
        if (!controller.signal.aborted) setRelease({ status: 'error', data: null });
      });
    return () => controller.abort();
  }, []);

  const value = useMemo(() => ({ ...release, releasesUrl: releaseConfig.releasesUrl }), [release]);
  return <ReleaseContext.Provider value={value}>{children}</ReleaseContext.Provider>;
}

export function useRelease() {
  return useContext(ReleaseContext) ?? { status: 'unavailable', data: null, releasesUrl: releaseConfig.releasesUrl };
}
