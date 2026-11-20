import { useEffect, useState } from 'react';
import { ArrowUpRight, Menu, X } from 'lucide-react';
import { NavLink, Link, useLocation } from 'react-router-dom';
import Brand from './Brand.jsx';

const links = [
  ['Features', '/features'],
  ['Screenshots', '/screenshots'],
  ['Privacy', '/privacy'],
];

export default function SiteHeader() {
  const [open, setOpen] = useState(false);
  const location = useLocation();
  useEffect(() => setOpen(false), [location.pathname]);
  useEffect(() => {
    if (!open) return undefined;
    const onKeyDown = (event) => event.key === 'Escape' && setOpen(false);
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [open]);

  return (
    <header className="site-header">
      <div className="header-inner shell flex items-center justify-between">
        <Brand onClick={() => setOpen(false)} />
        <nav className="desktop-nav" aria-label="Main navigation">
          {links.map(([label, to]) => <NavLink key={to} to={to} className={({ isActive }) => `nav-link${isActive ? ' is-active' : ''}`}>{label}</NavLink>)}
          <Link className="button button-dark header-download" to="/download">Download NextClass <ArrowUpRight size={17} /></Link>
        </nav>
        <button className="menu-toggle" type="button" aria-label={open ? 'Close navigation' : 'Open navigation'} aria-expanded={open} aria-controls="mobile-navigation" onClick={() => setOpen((value) => !value)}>
          {open ? <X size={23} /> : <Menu size={23} />}
        </button>
      </div>
      <nav id="mobile-navigation" className={`mobile-nav${open ? ' is-open' : ''}`} aria-label="Mobile navigation" aria-hidden={!open}>
        {links.map(([label, to]) => <NavLink key={to} to={to} className={({ isActive }) => `mobile-nav-link${isActive ? ' is-active' : ''}`}>{label}</NavLink>)}
        <Link className="button button-dark mobile-download" to="/download">Download NextClass <ArrowUpRight size={18} /></Link>
      </nav>
    </header>
  );
}
