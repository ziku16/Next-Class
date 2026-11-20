// Keep release source and repository validation in one place.
// The public download link is supplied only by a verified APK asset in GitHub Releases.
const buildEnv = import.meta.env ?? {};

export const releaseConfig = {
  owner: 'ziku16',
  repository: 'Next-Class',
  repositoryUrl: 'https://github.com/ziku16/Next-Class',
  issuesUrl: 'https://github.com/ziku16/Next-Class/issues',
  releasesUrl: 'https://github.com/ziku16/Next-Class/releases',
  latestReleaseApi: 'https://api.github.com/repos/ziku16/Next-Class/releases/latest',
  assetPathPrefix: '/ziku16/Next-Class/releases/download/',
  siteUrl: (buildEnv.VITE_SITE_URL ?? '').replace(/\/$/, ''),
};

export const formatFileSize = (bytes) => {
  if (!Number.isFinite(bytes) || bytes <= 0) return null;
  const units = ['B', 'KB', 'MB', 'GB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(unit >= 2 ? 1 : 0)} ${units[unit]}`;
};

// Metadata for the APK already bundled in public/downloads; it is not a hosted release.
export const bundledReleaseMetadata = { version: '1.0.1', sizeBytes: 25824416, size: formatFileSize(25824416) };

export function parseReleaseField(body, label) {
  if (typeof body !== 'string' || typeof label !== 'string' || !label.trim()) return null;
  const escapedLabel = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const value = body.match(new RegExp(`^\\s*${escapedLabel}:\\s*(\\S.*?)\\s*$`, 'im'))?.[1]?.trim();
  return value || null;
}

export function parseSha256Digest({ digest, body } = {}) {
  const apiDigest = typeof digest === 'string' ? digest.match(/^sha256:([a-f0-9]{64})$/i)?.[1] : null;
  const noteDigest = typeof body === 'string' ? body.match(/^SHA-256:\s*([a-f0-9]{64})\s*$/im)?.[1] : null;
  return (apiDigest ?? noteDigest)?.toLowerCase() ?? null;
}

const hiddenReleaseDetail = /^(?:architecture|abis?|sha\s*-?\s*256|checksum|signing(?:\s+(?:certificate(?:\s+fingerprint)?|identity|fingerprint))?|minimum\s+android|android\s+(?:version|sdk|api(?:\s+level)?)|minimum\s+(?:sdk|api)|sdk(?:\s+(?:version|level))?|api(?:\s+(?:version|level))?|build\s+(?:configuration|config|type)|version\s+code|application\s+id)\s*:/i;
const hiddenPlatformDetail = /\b(?:armeabi-v7a|arm64-v8a|x86_64|API\s*level\s*\d+|SDK\s*\d+)\b/i;

export function getStudentReleaseNotes(body) {
  if (typeof body !== 'string') return [];
  return body.split(/\r?\n/)
    .map((line) => line
      .replace(/^\s*#{1,6}\s*/, '')
      .replace(/^\s*(?:[-*+]\s+|\d+[.)]\s+)/, '')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/[*_`~]/g, '')
      .trim())
    .filter((line) => line && !/^(?:what['’]?s new|release notes?)$/i.test(line))
    .filter((line) => !hiddenReleaseDetail.test(line) && !hiddenPlatformDetail.test(line))
    .slice(0, 6);
}
export function isPublicReleaseData(data) {
  if (!data || data.isLocal === true || typeof data.url !== 'string') return false;
  try {
    const url = new URL(data.url);
    return url.protocol === 'https:'
      && url.hostname === 'github.com'
      && url.pathname.startsWith(releaseConfig.assetPathPrefix)
      && url.pathname.toLowerCase().endsWith('.apk');
  } catch {
    return false;
  }
}
export function isOfficialApkAsset(asset) {
  if (!asset || asset.state !== 'uploaded' || !asset.name?.toLowerCase().endsWith('.apk') || asset.size <= 0) return false;
  try {
    const url = new URL(asset.browser_download_url);
    return url.protocol === 'https:' && url.hostname === 'github.com' && url.pathname.startsWith(releaseConfig.assetPathPrefix);
  } catch {
    return false;
  }
}

export function getLocalRelease(env = buildEnv) {
  if (env.DEV !== true) return null;
  const url = env.VITE_LOCAL_APK_URL;
  const version = env.VITE_LOCAL_APK_VERSION;
  const fileName = env.VITE_LOCAL_APK_FILENAME;
  const sizeBytes = Number(env.VITE_LOCAL_APK_SIZE_BYTES);
  const architecture = env.VITE_LOCAL_APK_ARCHITECTURE;
  const minimumAndroid = env.VITE_LOCAL_APK_MIN_ANDROID;
  const checksum = parseSha256Digest({ digest: `sha256:${env.VITE_LOCAL_APK_SHA256 ?? ''}` });
  if (typeof url !== 'string' || !url.startsWith('/') || url.startsWith('//') || url.includes('..')) return null;
  if (!version || !fileName?.toLowerCase().endsWith('.apk') || !Number.isSafeInteger(sizeBytes) || sizeBytes <= 0) return null;
  if (!architecture || !minimumAndroid || !checksum) return null;
  return {
    version,
    url,
    fileName,
    size: formatFileSize(sizeBytes),
    sizeBytes,
    architecture,
    checksum,
    published: null,
    minimumAndroid,
    notes: 'Local development APK. This artifact is not a published GitHub release.',
    isLocal: true,
  };
}
