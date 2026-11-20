import { ArrowDownToLine, ExternalLink } from 'lucide-react';
import { useRelease } from '../hooks/useRelease.jsx';

export default function DownloadButton({ className = '', availableLabel = 'Download APK', unavailableLabel = 'APK coming soon' }) {
  const release = useRelease();
  if (release.status === 'loading') return <span className={`button button-disabled ${className}`} aria-live="polite"><span className="mini-loader" />Checking for APK…</span>;
  if (release.status !== 'available' || !release.data) {
    const label = release.status === 'error' ? 'APK status unavailable' : unavailableLabel;
    return <span className={`button button-disabled ${className}`} title="A verified APK has not been found in the latest stable release."><ArrowDownToLine size={19} />{label}</span>;
  }
  return <a className={`button button-orange ${className}`} href={release.data.url} target="_blank" rel="noopener noreferrer" aria-label={`Download NextClass ${release.data.version} APK`}><ArrowDownToLine size={19} />{availableLabel} <ExternalLink size={16} /></a>;
}
