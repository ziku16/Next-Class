import { ArrowRight, CalendarDays, ClipboardList, Timer } from 'lucide-react';
import { Link } from 'react-router-dom';
import DownloadButton from '../components/DownloadButton.jsx';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';

const essentials = [
  { icon: CalendarDays, title: 'Weekly timetable', text: 'Keep class days and times in one clear view.' },
  { icon: ClipboardList, title: 'Quiz tracking', text: 'Save quiz dates, topics, and completion.' },
  { icon: Timer, title: 'Class reminders', text: 'Get local reminders on your device.' },
];

export default function HomePage() {
  usePageMeta({ title: 'NextClass — Your semester. Under control.', description: 'Classes, quizzes, exams and reminders. One app. Zero chaos.', path: '/' });
  return <div className="home-page">
    <section className="hero shell" data-reveal>
      <div className="hero-copy">
        <p className="eyebrow"><span className="eyebrow-dot" />NEXTCLASS FOR ANDROID</p>
        <h1>YOUR SEMESTER.<br /><span>UNDER CONTROL.</span></h1>
        <p className="hero-lede">Classes, quizzes, exams and reminders. One app. Zero chaos.</p>
        <div className="hero-actions">
          <DownloadButton availableLabel="Download NextClass" unavailableLabel="Download NextClass" />
          <Link className="button button-paper" to="/features">Explore Features <ArrowRight size={17} /></Link>
        </div>
        <p className="hero-proof">Saved schedules stay available offline.</p>
      </div>
      <div className="hero-visual">
        <figure className="hero-screen-preview"><img src="/images/screenshots/today.png" width="360" height="800" alt="NextClass Today screen showing the class schedule." /><figcaption>Today</figcaption></figure>
      </div>
    </section>

    <section className="feature-preview shell section-space" data-reveal>
      <div className="section-heading"><div><p className="eyebrow">THE WEEK, MADE CLEAR</p><h2>Keep the essentials<br />in one place.</h2></div><Link className="text-link" to="/features">Explore features <ArrowRight size={17} /></Link></div>
      <div className="home-essentials">{essentials.map(({ icon: Icon, title, text }, index) => <article className={`essential-item essential-${index + 1}`} key={title}><Icon aria-hidden="true" size={25} /><h3>{title}</h3><p>{text}</p></article>)}</div>
    </section>

    <section className="home-gallery-callout shell section-space" data-reveal>
      <div className="home-gallery-copy"><p className="eyebrow">IN THE APP</p><h2>Plan the week.<br />Track the details.</h2><Link className="text-link" to="/screenshots">View all app screens <ArrowRight size={17} /></Link></div>
      <div className="home-preview-row" aria-label="NextClass screen previews">
        <Link to="/screenshots" aria-label="View the weekly timetable screen"><img src="/images/screenshots/week.png" width="360" height="800" loading="lazy" alt="NextClass weekly timetable preview." /></Link>
        <Link to="/screenshots" aria-label="View the quizzes screen"><img src="/images/screenshots/quizzes.png" width="360" height="800" loading="lazy" alt="NextClass quiz list preview." /></Link>
        <Link to="/screenshots" aria-label="View the exam screen"><img src="/images/screenshots/exams.png" width="360" height="800" loading="lazy" alt="NextClass exam schedule preview." /></Link>
      </div>
    </section>
  </div>;
}
