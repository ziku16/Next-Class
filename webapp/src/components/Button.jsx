import { Link } from 'react-router-dom';

export default function Button({ to, href, children, variant = 'orange', className = '', ...props }) {
  const classes = `button button-${variant} ${className}`.trim();
  return to ? <Link className={classes} to={to} {...props}>{children}</Link> : <a className={classes} href={href} {...props}>{children}</a>;
}
