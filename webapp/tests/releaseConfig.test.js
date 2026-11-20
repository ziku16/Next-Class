import test from 'node:test';
import assert from 'node:assert/strict';
import { formatFileSize, getLocalRelease, isOfficialApkAsset, parseReleaseField, parseSha256Digest } from '../src/data/releaseConfig.js';

const localReleaseEnv = {
  DEV: true,
  VITE_LOCAL_APK_URL: '/downloads/NextClass-v1.0.1-universal.apk',
  VITE_LOCAL_APK_VERSION: '1.0.1',
  VITE_LOCAL_APK_FILENAME: 'NextClass-v1.0.1-universal.apk',
  VITE_LOCAL_APK_SIZE_BYTES: '25824416',
  VITE_LOCAL_APK_ARCHITECTURE: 'Universal (armeabi-v7a, arm64-v8a, x86_64)',
  VITE_LOCAL_APK_MIN_ANDROID: 'Android 7.0 (API 24)',
  VITE_LOCAL_APK_SHA256: 'fc5b4fc3c9455a95649ae36769f2bd3ab40bc35aa8450a550ccecb9193379375',
};

test('accepts a non-empty uploaded APK from the configured official repository', () => {
  assert.equal(isOfficialApkAsset({
    name: 'nextclass.apk',
    state: 'uploaded',
    size: 1024,
    browser_download_url: 'https://github.com/ziku16/Next-Class/releases/download/v1.0.1/nextclass.apk',
  }), true);
});

test('rejects missing, empty, non-APK, or unofficial release assets', () => {
  assert.equal(isOfficialApkAsset(null), false);
  assert.equal(isOfficialApkAsset({ name: 'nextclass.apk', state: 'uploaded', size: 0, browser_download_url: 'https://github.com/ziku16/Next-Class/releases/download/v1/a.apk' }), false);
  assert.equal(isOfficialApkAsset({ name: 'notes.txt', state: 'uploaded', size: 12, browser_download_url: 'https://github.com/ziku16/Next-Class/releases/download/v1/a.txt' }), false);
  assert.equal(isOfficialApkAsset({ name: 'nextclass.apk', state: 'uploaded', size: 12, browser_download_url: 'https://example.com/ziku16/Next-Class/releases/download/v1/a.apk' }), false);
  assert.equal(isOfficialApkAsset({ name: 'nextclass.apk', state: 'uploaded', size: 12, browser_download_url: 'https://github.com/other/repo/releases/download/v1/a.apk' }), false);
});

test('formats APK size without inventing values', () => {
  assert.equal(formatFileSize(0), null);
  assert.equal(formatFileSize(1024), '1 KB');
  assert.equal(formatFileSize(2 * 1024 * 1024), '2.0 MB');
});

test('extracts only explicit release metadata fields', () => {
  const notes = 'Minimum Android: Android 8.0 (API 26)\nArchitecture: Android ARM64';
  assert.equal(parseReleaseField(notes, 'Minimum Android'), 'Android 8.0 (API 26)');
  assert.equal(parseReleaseField(notes, 'Architecture'), 'Android ARM64');
  assert.equal(parseReleaseField(notes, 'Release date'), null);
});

test('accepts only a real SHA-256 checksum from GitHub or release notes', () => {
  const digest = 'a'.repeat(64);
  assert.equal(parseSha256Digest({ digest: `sha256:${digest}`, body: '' }), digest);
  assert.equal(parseSha256Digest({ digest: null, body: `SHA-256: ${digest}` }), digest);
  assert.equal(parseSha256Digest({ digest: 'md5:abc', body: 'SHA-256: not-a-digest' }), null);
});

test('creates local APK metadata only in development with a complete valid config', () => {
  const release = getLocalRelease(localReleaseEnv);
  assert.equal(release.url, localReleaseEnv.VITE_LOCAL_APK_URL);
  assert.equal(release.version, '1.0.1');
  assert.equal(release.fileName, localReleaseEnv.VITE_LOCAL_APK_FILENAME);
  assert.equal(release.sizeBytes, 25824416);
  assert.equal(release.architecture, localReleaseEnv.VITE_LOCAL_APK_ARCHITECTURE);
  assert.equal(release.minimumAndroid, localReleaseEnv.VITE_LOCAL_APK_MIN_ANDROID);
  assert.equal(release.checksum, localReleaseEnv.VITE_LOCAL_APK_SHA256.toLowerCase());
  assert.equal(release.isLocal, true);
  assert.equal(getLocalRelease({ ...localReleaseEnv, DEV: false }), null);
  assert.equal(getLocalRelease({ ...localReleaseEnv, VITE_LOCAL_APK_SHA256: '' }), null);
});
