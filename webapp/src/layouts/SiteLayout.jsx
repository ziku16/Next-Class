import { Outlet } from 'react-router-dom';
import SiteHeader from '../components/SiteHeader.jsx';
import SiteFooter from '../components/SiteFooter.jsx';

export default function SiteLayout() {
  return <><a className="skip-link" href="#main-content">Skip to content</a><SiteHeader /><main id="main-content"><Outlet /></main><SiteFooter /></>;
}
