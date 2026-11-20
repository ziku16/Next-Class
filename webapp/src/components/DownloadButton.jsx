import { ArrowDownToLine, ExternalLink } from 'lucide-react';
import { useRelease } from '../hooks/useRelease.jsx';
import { isPublicReleaseData } from '../data/releaseConfig.js';

export default function DownloadButton({ className = '', availableLabel = 'Download APK', unavailableLabel = 'Download NextClass' }) {
  const release = useRelease();
  const available = release.status === 'available' && isPublicReleaseData(release.data);
  if (release.status === 'loading') return <button className={`button button-disabled ${className}`} type="button" disabled aria-live="polite"><span className="mini-loader" />Checking for release…</button>;
  if (!available) {
    return <button className={`button button-disabled ${className}`} type="button" disabled title="No public download is available."><ArrowDownToLine size={19} />{unavailableLabel}</button>;
  }
  return <a className={`button button-orange ${className}`} href={release.data.url} target="_blank" rel="noopener noreferrer" aria-label={`Download NextClass ${release.data.version} APK`}><ArrowDownToLine size={19} />{availableLabel} <ExternalLink size={16} /></a>;
}