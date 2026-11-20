import { ArrowUpRight, Github } from 'lucide-react';
import { Link } from 'react-router-dom';
import Brand from './Brand.jsx';
import { releaseConfig } from '../data/releaseConfig.js';

export default function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="shell footer-main">
        <div className="footer-brand"><Brand /></div>
        <div className="footer-links">
          <div><span className="footer-label">Explore</span><Link to="/features">Features</Link><Link to="/screenshots">Screenshots</Link><Link to="/download">Download</Link></div>
          <div><span className="footer-label">Project</span><Link to="/privacy">Privacy</Link><a href={releaseConfig.issuesUrl} target="_blank" rel="noreferrer">Support on GitHub <ArrowUpRight size={14} /></a></div>
        </div>
      </div>
      <div className="shell footer-bottom"><span>© {new Date().getFullYear()} NextClass</span><a href={releaseConfig.repositoryUrl} target="_blank" rel="noreferrer"><Github size={16} /> Open source on GitHub</a></div>
    </footer>
  );
}
