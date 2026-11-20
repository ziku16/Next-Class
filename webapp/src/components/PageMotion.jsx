import { useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useGSAP } from '@gsap/react';

gsap.registerPlugin(ScrollTrigger, useGSAP);

export default function PageMotion({ children, className = '' }) {
  const scope = useRef(null);

  useGSAP(() => {
    const media = gsap.matchMedia();
    media.add('(prefers-reduced-motion: no-preference)', () => {
      scope.current?.querySelectorAll('[data-reveal]').forEach((item) => {
        const revealTargets = item.querySelectorAll('[data-reveal-item]');
        const targets = revealTargets.length ? revealTargets : item;
        gsap.fromTo(targets, { autoAlpha: 0, y: 14 }, {
          autoAlpha: 1,
          y: 0,
          duration: 0.48,
          ease: 'power2.out',
          stagger: revealTargets.length ? 0.07 : 0,
          clearProps: 'transform,opacity,visibility',
          scrollTrigger: { trigger: item, start: 'top 90%', once: true },
        });
      });
    });

    return () => media.revert();
  }, { scope });

  return <div className={className} ref={scope}>{children}</div>;
}
