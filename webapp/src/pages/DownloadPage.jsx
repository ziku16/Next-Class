import DownloadButton from '../components/DownloadButton.jsx';
import usePageMeta from '../components/usePageMeta.js';
import { useRelease } from '../hooks/useRelease.jsx';

export default function DownloadPage() {
  const release = useRelease();
  usePageMeta({ title: 'Download NextClass for Android', description: 'Get the current NextClass Android release.', path: '/download' });

  const version = release.status === 'available' && release.data?.version
    ? `Version ${release.data.version}`
    : release.status === 'loading' ? 'Checking current release' : 'No current release';

  return <div className="download-page-compact page-shell shell">
    <section className="release-simple" aria-labelledby="download-title" data-reveal>
      <img className="release-app-icon" src="/images/app-icon.png" width="512" height="512" alt="" />
      <p className="release-current">Current Release</p>
      <h1 id="download-title">NextClass</h1>
      <p className="release-version" aria-live="polite">{version}</p>
      <DownloadButton className="release-download" availableLabel="Download NextClass" unavailableLabel="Download NextClass" />
      {release.status === 'error' && <p className="release-note">Release information could not be loaded. Try again shortly.</p>}
      {release.status === 'unavailable' && <p className="release-note">There is no public APK release yet.</p>}
    </section>
  </div>;
}
