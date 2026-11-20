import { useEffect, useRef, useState } from 'react';
import { X, ZoomIn } from 'lucide-react';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';

const captures = [
  { title: 'Today', file: 'today.png', text: 'Today’s classes and what is next.', alt: 'NextClass Today screen with the current and upcoming classes.' },
  { title: 'Weekly timetable', file: 'week.png', text: 'Classes laid out across the week.', alt: 'NextClass weekly timetable screen with sample university classes.' },
  { title: 'Quizzes', file: 'quizzes.png', text: 'Quiz dates, topics, and status.', alt: 'NextClass quiz list with sample quiz details.' },
  { title: 'Add a quiz', file: 'add-quiz.png', text: 'The form for adding a quiz.', alt: 'NextClass add quiz form.' },
  { title: 'Exam schedule', file: 'exams.png', text: 'A saved schedule of upcoming exams.', alt: 'NextClass exam schedule with sample university exams.' },
  { title: 'Automatic Exam Mode', file: 'exam-mode.png', text: 'The Today screen focused on exams during an active exam period.', alt: 'NextClass Today screen in Automatic Exam Mode.' },
  { title: 'Date-sheet import', file: 'exam-import.png', text: 'Choose the student group for a date sheet.', alt: 'NextClass date-sheet import flow asking for degree program, semester, and section.' },
];

export default function ScreenshotsPage() {
  const [selected, setSelected] = useState(null);
  const closeButton = useRef(null);
  const opener = useRef(null);
  usePageMeta({ title: 'Screenshots — NextClass', description: 'A look at the NextClass Android app, from the weekly timetable to quizzes and exams.', path: '/screenshots' });

  useEffect(() => {
    if (!selected) return undefined;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    closeButton.current?.focus();
    const closeOnEscape = (event) => {
      if (event.key === 'Escape') setSelected(null);
      if (event.key === 'Tab') {
        event.preventDefault();
        closeButton.current?.focus();
      }
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener('keydown', closeOnEscape);
      opener.current?.focus();
    };
  }, [selected]);

  const close = () => setSelected(null);

  return <div className="page-shell shell">
    <PageIntro kicker="THE APP" title={<>NextClass,<br /><span>screen by screen.</span></>} description="App screens shown with sample university data. These are rendered previews, not photos taken on a device." />
    <div className="gallery-grid" data-reveal>
      {captures.map((item, index) => <article className={`capture-card capture-${index + 1}`} key={item.file} data-reveal-item>
        <button className="capture-image-button" type="button" onClick={(event) => { opener.current = event.currentTarget; setSelected(item); }} aria-label={`Open larger preview: ${item.title}`}>
          <img src={`/images/screenshots/${item.file}`} width="360" height="800" loading="lazy" alt={item.alt} />
          <span className="capture-open"><ZoomIn size={15} aria-hidden="true" /> View larger</span>
        </button>
        <div className="capture-caption"><div><h2>{item.title}</h2><p>{item.text}</p></div></div>
      </article>)}
    </div>
    {selected && <div className="screenshot-lightbox" role="dialog" aria-modal="true" aria-labelledby="screenshot-dialog-title" onClick={close}>
      <div className="screenshot-lightbox-panel" onClick={(event) => event.stopPropagation()}>
        <div className="screenshot-lightbox-heading"><div><p className="eyebrow">NEXTCLASS APP</p><h2 id="screenshot-dialog-title">{selected.title}</h2></div><button ref={closeButton} className="lightbox-close" type="button" onClick={close} aria-label="Close preview"><X size={20} /></button></div>
        <img src={`/images/screenshots/${selected.file}`} width="360" height="800" alt={selected.alt} />
        <p>{selected.text}</p>
      </div>
    </div>}
  </div>;
}
