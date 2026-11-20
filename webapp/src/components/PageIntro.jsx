export default function PageIntro({ kicker, title, description, children }) {
  return <header className="page-intro" data-reveal><p className="eyebrow"><span className="eyebrow-dot" />{kicker}</p><h1>{title}</h1><p className="page-intro-copy">{description}</p>{children}</header>;
}
