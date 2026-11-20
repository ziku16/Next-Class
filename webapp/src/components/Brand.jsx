import { Link } from 'react-router-dom';

export default function Brand({ onClick }) {
  return (
    <Link className="brand" to="/" aria-label="NextClass home" onClick={onClick}>
      <img className="brand-mark" src="/images/app-icon.png" alt="" width="42" height="42" />
      <span className="brand-word">NextClass<span className="brand-period">.</span></span>
    </Link>
  );
}
