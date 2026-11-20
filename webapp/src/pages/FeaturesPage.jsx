import { BellRing, CalendarDays, CloudOff, FileImage, ListChecks, ScanLine, Timer } from 'lucide-react';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';

const features = [
  { icon: CalendarDays, title: 'Weekly timetable', text: 'See your classes by day, with times, rooms, and instructors.', tone: 'yellow' },
  { icon: ScanLine, title: 'AI timetable scanning', text: 'Turn a timetable image into class entries to review. Scanning needs an internet connection.', tone: 'orange' },
  { icon: ListChecks, title: 'Quiz management', text: 'Keep quiz dates, topics, completion, and class details together.', tone: 'blue' },
  { icon: FileImage, title: 'Exam date-sheet scanning', text: 'Import a PDF, image, or spreadsheet, then review detected exams before saving.', tone: 'cream' },
  { icon: Timer, title: 'Automatic Exam Mode', text: 'During an active exam schedule, Today focuses on exams instead of regular classes.', tone: 'blue' },
  { icon: BellRing, title: 'Class and exam reminders', text: 'Schedule class and exam reminders on your Android device.', tone: 'cream' },
  { icon: CloudOff, title: 'Saved schedules offline', text: 'Open your saved timetable without an internet connection.', tone: 'yellow' },
];

export default function FeaturesPage() {
  usePageMeta({ title: 'Features — NextClass', description: 'Explore the timetable, quiz, reminder, and AI scanning features in NextClass.', path: '/features' });
  return <div className="page-shell shell">
    <PageIntro kicker="NEXTCLASS FEATURES" title={<>Your week,<br /><span>in one place.</span></>} description="A clear plan for classes, quizzes, exams, and reminders." />
    <section className="feature-section" data-reveal>
      <div className="feature-grid feature-grid-refined" data-reveal-items>
        {features.map(({ icon: Icon, title, text, tone }, index) => <article className={`feature-card tone-${tone}`} key={title} data-reveal-item><div className="feature-card-head"><span className="feature-icon"><Icon size={22} aria-hidden="true" /></span><span className="feature-index">0{index + 1}</span></div><h2>{title}</h2><p>{text}</p></article>)}
      </div>
    </section>
  </div>;
}
