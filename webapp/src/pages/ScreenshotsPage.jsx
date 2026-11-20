import { ArrowDown, X, ZoomIn } from 'lucide-react';
import { useEffect, useState } from 'react';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';

const captures = [
  { title: 'Today Dashboard', file: 'today.png', text: 'Today’s classes, next class time, and quick navigation.', alt: 'NextClass Today Dashboard with Algorithms and Database Systems classes.' },
  { title: 'Weekly Timetable', file: 'week.png', text: 'Day-by-day classes with rooms and times.', alt: 'NextClass weekly timetable showing university classes across the week.' },
  { title: 'Quiz Management', file: 'quizzes.png', text: 'Upcoming quizzes grouped by due date.', alt: 'NextClass quiz management screen with upcoming university quizzes.' },
  { title: 'Add Quiz', file: 'add-quiz.png', text: 'The app’s quiz entry sheet, opened over the quiz list.', alt: 'NextClass Add Quiz form in a Flutter-rendered bottom sheet.' },
  { title: 'Exam Schedule', file: 'exams.png', text: 'An active exam schedule with the imported student group.', alt: 'NextClass examination schedule with sample university exams.' },
  { title: 'Automatic Exam Mode', file: 'exam-mode.png', text: 'The Today screen focused on exams during the active exam period.', alt: 'NextClass Today screen in Automatic Exam Mode with an Algorithms final.' },
  { title: 'Exam Date-Sheet Import', file: 'exam-import.png', text: 'The student-group step shown before reading a date sheet.', alt: 'NextClass exam date-sheet import flow asking for degree program, semester, and section.' },
];

export default function ScreenshotsPage() {
  const [selected, setSelected] = useState(null);
  usePageMeta({ title: 'Screenshots — NextClass', description: 'Flutter-rendered UI previews of the NextClass app, generated from its actual widget source.', path: '/screenshots' });

  useEffect(() => {
    if (!selected) return undefined;
    const closeOnEscape = (event) => {
      if (event.key === 'Escape') setSelected(null);
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [selected]);

  return <div className="page-shell shell">
    <PageIntro kicker="THE APP, RENDERED FROM SOURCE" title={<>Real Flutter UI.<br /><span>Every pixel, honest.</span></>} description="These 360 × 800 previews are rendered from the app’s Flutter widgets with isolated sample data. They are not screenshots captured from an Android device." />
    <div className="gallery-grid">{captures.map((item) => <article className="capture-card" key={item.file}>
      <div className="capture-art"><button className="capture-image-button" type="button" onClick={() => setSelected(item)} aria-label={`Open larger Flutter-rendered preview: ${item.title}`}><img src={`/images/screenshots/${item.file}`} width="360" height="800" loading="lazy" alt={`Flutter-rendered UI preview: ${item.alt}`} /><span><ZoomIn size={14} /> Open preview</span></button></div>
      <div className="capture-caption"><div><span className="eyebrow">FLUTTER-RENDERED UI PREVIEW</span><h2>{item.title}</h2><p>{item.text}</p></div><span className="capture-file">{item.file}</span></div>
    </article>)}</div>
    <aside className="asset-request"><div className="request-icon"><ArrowDown size={23} /></div><div><p className="eyebrow">HOW THESE PREVIEWS WERE MADE</p><h2>Actual widgets. Controlled data.</h2><p>The Flutter golden-test harness uses the app’s real theme, Space Grotesk font, Material icons, screen widgets, and sample university information at a fixed 360 × 800 logical viewport with a 3× device-pixel setting. No production database or personal records are used.</p><code>webapp/public/images/screenshots/</code></div></aside>
    {selected && <div className="screenshot-lightbox" role="dialog" aria-modal="true" aria-labelledby="screenshot-dialog-title" onClick={() => setSelected(null)}><div className="screenshot-lightbox-panel" onClick={(event) => event.stopPropagation()}><div className="screenshot-lightbox-heading"><div><p className="eyebrow">FLUTTER-RENDERED UI PREVIEW</p><h2 id="screenshot-dialog-title">{selected.title}</h2></div><button className="lightbox-close" type="button" onClick={() => setSelected(null)} aria-label="Close screenshot preview"><X size={20} /></button></div><img src={`/images/screenshots/${selected.file}`} width="360" height="800" alt={`Flutter-rendered UI preview: ${selected.alt}`} /><p>{selected.text} Rendered from Flutter widgets, not captured from an Android device.</p></div></div>}
  </div>;
}