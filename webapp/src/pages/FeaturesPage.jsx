import { BellRing, CalendarDays, CloudOff, FileImage, ListChecks, ScanLine, Timer } from 'lucide-react';
import { Link } from 'react-router-dom';
import FeatureCard from '../components/FeatureCard.jsx';
import FinalCta from '../components/FinalCta.jsx';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';

const available = [
  { icon: CalendarDays, title: 'Weekly class schedule', text: 'Keep class days, times, rooms, and instructors in a weekly view.', tone: 'yellow' },
  { icon: ScanLine, title: 'AI timetable scanning', text: 'Choose a timetable image and review the class entries Gemini drafts. Internet is required.', tone: 'orange' },
  { icon: ListChecks, title: 'Quiz management', text: 'Track quiz dates, topics, completion, and linked class details.', tone: 'blue' },
  { icon: BellRing, title: 'Smart reminders', text: 'Set local reminders for classes and quizzes on your Android device.', tone: 'cream' },
  { icon: CloudOff, title: 'Offline schedule access', text: 'Schedules you have saved stay on-device and remain available offline.', tone: 'yellow' },
  { icon: FileImage, title: 'Exam date-sheet import', text: 'Import PDF, XLSX, JPG, or PNG date sheets, then review the detected exams before saving.', tone: 'cream' },
  { icon: Timer, title: 'Automatic Exam Mode', text: 'During the dates in an active exam schedule, the Today screen pauses regular classes and focuses on exams.', tone: 'blue' },
];

export default function FeaturesPage() {
  usePageMeta({ title: 'Features — NextClass', description: 'Explore NextClass timetable, quiz, exam, reminder, and scanning features.', path: '/features' });
  return <div className="page-shell shell">
    <PageIntro kicker="WHAT’S IN YOUR POCKET" title={<>Small plan.<br /><span>Big semester energy.</span></>} description="A clear look at what the current Android app can do." />
    <section className="feature-section">
      <div className="feature-section-title"><span className="section-index">01</span><div><p className="eyebrow">AVAILABLE IN THE APP</p><h2>Built for your actual week.</h2></div></div>
      <div className="feature-grid">{available.map((feature) => <FeatureCard key={feature.title} {...feature} status="Available" />)}</div>
    </section>
    <section className="feature-proof-strip">
      <div><p className="eyebrow">EXAM MODE, IN THE APP</p><h2>Exam dates change the Today view.</h2><p>When an active schedule covers the current date, regular classes are paused and the day’s exams take priority.</p><Link className="text-link" to="/screenshots">See the Flutter-rendered preview <span aria-hidden="true">→</span></Link></div>
      <img src="/images/screenshots/exam-mode.png" width="360" height="800" loading="lazy" alt="Flutter-rendered UI preview of the NextClass Today screen in Automatic Exam Mode." />
    </section>
    <FinalCta />
  </div>;
}