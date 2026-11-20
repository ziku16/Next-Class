import { ArrowUpRight, Check, CircleAlert } from 'lucide-react';
import { Link } from 'react-router-dom';
import DownloadButton from '../components/DownloadButton.jsx';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';
import { useRelease } from '../hooks/useRelease.jsx';
import { bundledReleaseMetadata, getStudentReleaseNotes, isPublicReleaseData } from '../data/releaseConfig.js';

function ReleaseStatus({ status, releasesUrl }) {
  if (status === 'loading') return <p className="release-status" aria-live="polite"><span className="mini-loader" />Checking the current release…</p>;
  if (status === 'error') return <p className="release-status"><CircleAlert size={18} /> Release information could not be loaded. Try again shortly, or visit the <a href={releasesUrl} target="_blank" rel="noreferrer">official releases</a>.</p>;
  return null;
}

export default function DownloadPage() {
  const release = useRelease();
  const available = release.status === 'available' && isPublicReleaseData(release.data);
  const details = available ? release.data : bundledReleaseMetadata;
  const status = release.status === 'available' && !available ? 'unavailable' : release.status;
  const notes = details ? getStudentReleaseNotes(details.notes) : [];
  usePageMeta({ title: 'Download NextClass for Android', description: 'Get the current NextClass Android release, see what is new, and follow the simple installation steps.', path: '/download' });

  return <div className="page-shell shell download-page">
    <PageIntro kicker="NEXTCLASS FOR ANDROID" title={<>A calmer<br className="mobile-title-break" /> week,<br /><span>one tap away.</span></>} description="Classes, quizzes, exams, and local reminders in one student-friendly app." />
    <div className="download-showcase">
      <section className="release-card" aria-labelledby="release-title" data-reveal>
        <div className="release-card-heading">
          <img className="release-app-icon" src="/images/app-icon.png" width="512" height="512" alt="" />
          <div className="release-card-title"><p className="release-current"><span />Current Release</p><h1 id="release-title">NextClass</h1><p className="release-subtitle">Your classes and quizzes, together.</p></div>
        </div>
        <dl className="release-meta-grid" aria-live="polite">
          <div><dt>VERSION</dt><dd>{details?.version ?? '—'}</dd></div>
          <div><dt>DOWNLOAD SIZE</dt><dd>{details?.size ?? '—'}</dd></div>
          {details?.published && <div><dt>RELEASED</dt><dd>{details.published.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })}</dd></div>}
        </dl>
        <div className="release-download-row"><DownloadButton className="release-download" availableLabel="Download NextClass" unavailableLabel="Download NextClass" /><a className="release-list-link" href={release.releasesUrl} target="_blank" rel="noreferrer">All releases <ArrowUpRight size={15} /></a></div>
        <ReleaseStatus status={status} releasesUrl={release.releasesUrl} />
      </section>

      <section className="whats-new-card" aria-labelledby="whats-new-title" data-reveal>
        <p className="eyebrow"><span className="whats-new-dot" />LATEST UPDATE</p>
        <h2 id="whats-new-title">What’s New</h2>
        {notes.length ? <ul className="release-notes-list">{notes.map((note, index) => <li key={`${index}-${note}`}>{note}</li>)}</ul> : <p className="release-notes-empty">Release notes are not available yet.</p>}
      </section>
    </div>

    <section className="install-guide" aria-labelledby="install-title" data-reveal>
      <div className="install-guide-heading"><p className="eyebrow">UP AND RUNNING</p><h2 id="install-title">Install in three steps.</h2></div>
      <ol className="install-steps">
        <li data-reveal-item><span>01</span><div><h3>Download</h3><p>Tap the orange button to save the APK.</p></div><Check size={18} aria-hidden="true" /></li>
        <li data-reveal-item><span>02</span><div><h3>Open the file</h3><p>Choose the download from your browser or Files app.</p></div><Check size={18} aria-hidden="true" /></li>
        <li data-reveal-item><span>03</span><div><h3>Follow Android’s prompts</h3><p>Allow the install source if Android asks, then open NextClass.</p></div><Check size={18} aria-hidden="true" /></li>
      </ol>
    </section>
    <p className="download-privacy-note">AI scanning needs an internet connection. <Link to="/privacy">Read how scanning and saved schedules work.</Link></p>
  </div>;
}
