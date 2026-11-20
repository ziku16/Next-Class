import { ArrowDownToLine, ExternalLink } from 'lucide-react';
import { useRelease } from '../hooks/useRelease.jsx';
import { getDownloadArtifact } from '../data/releaseConfig.js';

export default function DownloadButton({ className = '', availableLabel = 'Download APK', unavailableLabel = 'Download NextClass' }) {
  const release = useRelease();
  const artifact = getDownloadArtifact(release, import.meta.env.DEV);
  if (!artifact) {
    if (release.status === 'loading') return <button className={`button button-disabled ${className}`} type="button" disabled aria-live="polite"><span className="mini-loader" />Checking for release…</button>;
    return <button className={`button button-disabled ${className}`} type="button" disabled title="No public download is available."><ArrowDownToLine size={19} />{unavailableLabel}</button>;
  }

  const isLocal = artifact.isLocal === true;
  return <a className={`button button-orange ${className}`} href={artifact.url} download={isLocal ? artifact.fileName : undefined} target={isLocal ? undefined : '_blank'} rel={isLocal ? undefined : 'noopener noreferrer'} aria-label={`Download NextClass ${artifact.version} APK`}><ArrowDownToLine size={19} />{availableLabel}{!isLocal && <> <ExternalLink size={16} /></>}</a>;
}
