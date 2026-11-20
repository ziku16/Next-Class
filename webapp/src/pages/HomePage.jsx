import { ArrowRight, CalendarDays, Check, ClipboardList, FileImage, Timer } from 'lucide-react';
import { Link } from 'react-router-dom';
import Button from '../components/Button.jsx';
import DownloadButton from '../components/DownloadButton.jsx';
import FeatureCard from '../components/FeatureCard.jsx';
import FinalCta from '../components/FinalCta.jsx';
import usePageMeta from '../components/usePageMeta.js';

const previewFeatures = [
  { icon: CalendarDays, title: 'Weekly Timetable', text: 'Keep class days, times, rooms, and instructors easy to scan.', tone: 'yellow' },
  { icon: ClipboardList, title: 'Quiz Tracking', text: 'Save quiz dates and topics beside the class they belong to.', tone: 'orange' },
  { icon: Timer, title: 'Automatic Exam Mode', text: 'See exams first while an active schedule is in effect.', tone: 'blue' },
  { icon: FileImage, title: 'Date-Sheet Import', text: 'Review detected exams from a PDF, spreadsheet, or image.', tone: 'cream' },
];

export default function HomePage() {
  usePageMeta({ title: 'NextClass — Your semester. Under control.', description: 'Classes, quizzes, exams and reminders. One app. Zero chaos.', path: '/' });
  return (
    <div className="home-page">
      <section className="hero shell">
        <div className="hero-copy">
          <p className="eyebrow"><span className="eyebrow-dot" />THE STUDENT SIDEKICK</p>
          <h1>YOUR SEMESTER.<br /><span>UNDER CONTROL.</span></h1>
          <p className="hero-lede">Classes, quizzes, exams and reminders.<br className="desktop-only" /> One app. Zero chaos.</p>
          <div className="hero-actions"><DownloadButton availableLabel="Download for Android" unavailableLabel="Android APK coming soon" /><Button to="/features" variant="paper">Explore NextClass <ArrowRight size={17} /></Button></div>
          <div className="hero-proof"><span><Check size={15} /> No account needed</span><span><Check size={15} /> Works offline for saved schedules</span></div>
        </div>
        <div className="hero-visual">
          <div className="orbit-stamp" aria-hidden="true"><span>ONE WEEK AT A TIME</span><b>✳</b></div>
          <figure className="hero-screenshot-frame"><img src="/images/screenshots/today.png" width="360" height="800" alt="Flutter-rendered UI preview of the NextClass Today dashboard. This is rendered from Flutter widgets, not captured from an Android device." /></figure>
          <p className="hero-note">REAL APP WIDGETS.<br /><span>Flutter-rendered UI preview · 360 × 800</span></p>
        </div>
        <div className="hero-coordinate" aria-hidden="true">NC—01 / ANDROID</div>
      </section>

      <section className="feature-preview shell section-space">
        <div className="section-heading"><div><p className="eyebrow">LESS TABS IN YOUR BRAIN</p><h2>The essentials,<br />all in one place.</h2></div><Link className="text-link" to="/features">See every feature <ArrowRight size={17} /></Link></div>
        <div className="feature-grid home-feature-grid">{previewFeatures.map((feature) => <FeatureCard key={feature.title} {...feature} status="Available" />)}</div>
      </section>

      <section className="product-strip shell section-space">
        <div className="product-strip-copy"><p className="eyebrow">MADE FOR THE MONDAY SCRAMBLE</p><h2>Know what’s next.<br />Keep your head clear.</h2><p>Save your timetable and quizzes locally, then check the plan even when your connection drops.</p><Link className="text-link" to="/screenshots">See the app gallery <ArrowRight size={17} /></Link></div>
        <div className="product-strip-art"><div className="art-yellow"><CalendarDays size={32} /><span>PLAN<br />THE WEEK</span></div><div className="art-orange"><Check size={28} /><span>SHOW UP<br />ON TIME</span></div><span className="art-check"><Check size={30} /></span></div>
      </section>

      <section className="shell section-space"><FinalCta compact /></section>
    </div>
  );
}