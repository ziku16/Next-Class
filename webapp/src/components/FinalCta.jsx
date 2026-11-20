import { ArrowUpRight, Sparkles } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function FinalCta({ compact = false }) {
  return <section className={`final-cta${compact ? ' is-compact' : ''}`}><div className="cta-spark" aria-hidden="true"><Sparkles size={28} /></div><div><p className="eyebrow">NEXT UP: A CALMER SEMESTER</p><h2>Make room for the good stuff.</h2></div><Link className="button button-dark" to="/download">Get NextClass <ArrowUpRight size={17} /></Link></section>;
}
