import { Image } from 'lucide-react';

export default function PhonePlaceholder({ label = 'Real app capture coming soon' }) {
  return (
    <div className="product-placeholder" role="img" aria-label="NextClass app screenshot placeholder. A real screenshot has not been added yet.">
      <div className="placeholder-sticker">SCREENSHOT<br />NEEDED</div>
      <div className="placeholder-phone">
        <div className="phone-camera" />
        <div className="placeholder-screen">
          <div className="placeholder-screen-top"><span>NextClass</span><span className="placeholder-index">NC / 01</span></div>
          <div className="placeholder-art"><img src="/images/app-icon.png" alt="" /><span className="placeholder-orbit orbit-one" /><span className="placeholder-orbit orbit-two" /></div>
          <div className="placeholder-title">{label}</div>
          <div className="placeholder-pending"><Image size={17} /><span>Authentic app capture pending</span></div>
          <div className="placeholder-colorbars" aria-hidden="true"><i /><i /><i /></div>
        </div>
      </div>
      <p className="placeholder-caption">Illustrative placeholder · not a screenshot</p>
    </div>
  );
}
