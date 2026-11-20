export default function FeatureCard({ icon: Icon, title, text, tone = 'cream', status }) {
  return <article className={`feature-card flex flex-col tone-${tone}`}><div className="feature-card-head flex items-center justify-between"><span className="feature-icon"><Icon size={22} strokeWidth={2.4} /></span>{status && <span className="status-pill">{status}</span>}</div><h3>{title}</h3><p>{text}</p></article>;
}
