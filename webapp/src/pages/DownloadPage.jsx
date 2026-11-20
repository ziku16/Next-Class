import { ArrowDownToLine, Check, CircleAlert, ExternalLink, ShieldCheck } from 'lucide-react';
import { Link } from 'react-router-dom';
import DownloadButton from '../components/DownloadButton.jsx';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';
import { useRelease } from '../hooks/useRelease.jsx';

function ReleaseDetails({ release }) {
  if (release.status === 'loading') return <div className="release-state" aria-live="polite"><span className="mini-loader" />Checking the official GitHub release…</div>;
  if (release.status === 'error') return <div className="release-state"><CircleAlert size={19} /> Couldn’t check GitHub right now. Try again in a moment, or check the <a href={release.releasesUrl} target="_blank" rel="noreferrer">official Releases page</a>.</div>;
  if (release.status !== 'available' || !release.data) return <div className="release-state"><CircleAlert size={19} /> No verified APK is available yet. The download activates when a stable NextClass release has a non-empty APK attached.</div>;
  const details = release.data;
  return <>
    <dl className="release-details">
      <div><dt>VERSION</dt><dd>{details.version}</dd></div>
      <div><dt>APK SIZE</dt><dd>{details.size ?? '—'}{Number.isFinite(details.sizeBytes) && <small>{details.sizeBytes.toLocaleString()} bytes</small>}</dd></div>
      <div><dt>ARCHITECTURE</dt><dd>{details.architecture ?? 'Not specified by release'}</dd></div>
      <div><dt>MIN ANDROID</dt><dd>{details.minimumAndroid ?? 'Not specified by release'}</dd></div>
      <div><dt>RELEASE DATE</dt><dd>{details.published ? details.published.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' }) : '—'}</dd></div>
      <div><dt>FILE</dt><dd>{details.fileName}</dd></div>
    </dl>
    {details.checksum && <p className="download-checksum"><strong>SHA-256</strong><code>{details.checksum}</code></p>}
  </>;
}

function InstallSteps({ isLocal = false }) {
  const downloadTitle = isLocal ? 'Download the local APK' : 'Download the official APK';
  const downloadSource = isLocal ? 'This test file is served by the local development server.' : 'Published builds are served from the official NextClass GitHub Releases page.';
  return <ol className="install-steps"><li><span>01</span><div><h3>{downloadTitle}</h3><p>Use the download button when it is active. {downloadSource}</p></div></li><li><span>02</span><div><h3>Open the downloaded file</h3><p>On Android, open the APK from your browser’s downloads list or the Files app and follow the installer prompts.</p></div></li><li><span>03</span><div><h3>Allow this install source if asked</h3><p>Android may ask whether your browser or Files app can install this file. Allow it only for a download you chose, and keep Play Protect enabled.</p></div></li></ol>;
}

export default function DownloadPage() {
  const release = useRelease();
  usePageMeta({ title: 'Download NextClass for Android', description: 'Get the official NextClass Android APK and read the installation guide.', path: '/download' });
  return <div className="page-shell shell">
    <PageIntro kicker={release.data?.isLocal ? "LOCAL APK TEST" : "OFFICIAL ANDROID DOWNLOAD"} title={<>Your next class,<br /><span>closer at hand.</span></>} description="NextClass is distributed directly by its developer. It is not currently distributed through Google Play." />
    <section className="download-panel"><div className="download-panel-top"><div className="download-app-icon"><span>N</span></div><div><p className="eyebrow">NEXTCLASS FOR ANDROID</p><h2>Keep the week moving.</h2><p>Classes, quizzes, exams, and local reminders in one student-friendly app.</p></div><span className="direct-badge">{release.data?.isLocal ? "LOCAL TEST" : "DIRECT RELEASE"}</span></div>
      <ReleaseDetails release={release} />
      <div className="download-action-row"><DownloadButton className="download-main-button" availableLabel="Download APK" unavailableLabel="APK not available yet" /><a className="text-link" href={release.releasesUrl} target="_blank" rel="noreferrer">View official releases <ExternalLink size={15} /></a></div>
      <p className="download-small-note">{release.data?.isLocal ? "Local development APK — this build is for local testing and is not a published release." : "Architecture and minimum Android are shown only when the release publishes those values. Download links point to the configured NextClass repository."}</p>
    </section>
    <section className="download-lower"><div className="installation-guide"><p className="eyebrow">INSTALL IN A MINUTE</p><h2>How to install the APK</h2><InstallSteps isLocal={release.data?.isLocal} /></div><aside className="security-card"><ShieldCheck size={29} /><p className="eyebrow">A QUICK SAFETY CHECK</p><h2>{release.data?.isLocal ? "Local test build." : "Keep Play Protect on."}</h2><p>{release.data?.isLocal ? "This APK is served by the local development server and is not a public release. On Android, install it only if you intentionally transferred this test file." : "Only install an APK linked from the official NextClass release page. Android may request permission for the app you used to open the file; allow it only if you chose this download. Keep Google Play Protect enabled."}</p><div className="security-check"><Check size={16} /> {release.data?.isLocal ? "APK served from local development server" : "Download link validated against the repository"}</div><div className="security-check"><Check size={16} /> No Google Play listing claimed</div></aside></section>
    <section className="changelog-panel"><div><p className="eyebrow">WHAT’S NEW</p><h2>Release notes</h2></div>{release.status === 'available' && release.data?.notes ? <pre>{release.data.notes}</pre> : <p>No published release notes are available yet.</p>}</section>
    <p className="download-privacy-note">AI scanning sends selected content to Google Gemini: timetable images and exam-sheet PDF/images, or extracted text from XLSX sheets. <Link to="/privacy">Read the privacy details.</Link></p>
  </div>;
}
