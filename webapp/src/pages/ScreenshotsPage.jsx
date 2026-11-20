import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, ChevronRight, X, ZoomIn } from 'lucide-react';
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
  const [selectedIndex, setSelectedIndex] = useState(null);
  const closeButton = useRef(null);
  const modalPanel = useRef(null);
  const opener = useRef(null);
  const touchStartX = useRef(null);
  const isOpen = selectedIndex !== null;
  const selected = isOpen ? captures[selectedIndex] : null;
  usePageMeta({ title: 'Screenshots — NextClass', description: 'A look at the NextClass Android app, from the weekly timetable to quizzes and exams.', path: '/screenshots' });

  useEffect(() => {
    if (!isOpen) return undefined;
    const previousBodyOverflow = document.body.style.overflow;
    const previousRootOverflow = document.documentElement.style.overflow;
    document.body.style.overflow = 'hidden';
    document.documentElement.style.overflow = 'hidden';
    closeButton.current?.focus();
    const onKeyDown = (event) => {
      if (event.key === 'Escape') {
        setSelectedIndex(null);
        return;
      }
      if (event.key === 'ArrowRight') {
        event.preventDefault();
        setSelectedIndex((index) => index === null ? null : (index + 1) % captures.length);
        return;
      }
      if (event.key === 'ArrowLeft') {
        event.preventDefault();
        setSelectedIndex((index) => index === null ? null : (index - 1 + captures.length) % captures.length);
        return;
      }
      if (event.key === 'Tab') {
        const focusable = [...(modalPanel.current?.querySelectorAll('button:not([disabled])') ?? [])];
        if (!focusable.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => {
      document.body.style.overflow = previousBodyOverflow;
      document.documentElement.style.overflow = previousRootOverflow;
      window.removeEventListener('keydown', onKeyDown);
      opener.current?.focus();
    };
  }, [isOpen]);

  const close = () => setSelectedIndex(null);
  const changeCapture = (direction) => setSelectedIndex((index) => index === null ? null : (index + direction + captures.length) % captures.length);
  const handleTouchStart = (event) => { touchStartX.current = event.changedTouches[0]?.clientX ?? null; };
  const handleTouchEnd = (event) => {
    if (touchStartX.current === null) return;
    const endX = event.changedTouches[0]?.clientX;
    const distance = typeof endX === 'number' ? endX - touchStartX.current : 0;
    touchStartX.current = null;
    if (Math.abs(distance) > 48) changeCapture(distance < 0 ? 1 : -1);
  };

  const previewModal = selected && createPortal(
    <div className="screenshot-lightbox" role="dialog" aria-modal="true" aria-labelledby="screenshot-dialog-title" onClick={close}>
      <div ref={modalPanel} className="screenshot-lightbox-panel" onClick={(event) => event.stopPropagation()}>
        <div className="screenshot-lightbox-heading"><div><p className="eyebrow">NEXTCLASS APP · {selectedIndex + 1} OF {captures.length}</p><h2 id="screenshot-dialog-title">{selected.title}</h2></div><button ref={closeButton} className="lightbox-close" type="button" onClick={close} aria-label="Close preview"><X size={20} /></button></div>
        <div className="lightbox-image-wrap" onTouchStart={handleTouchStart} onTouchEnd={handleTouchEnd}><img src={`/images/screenshots/${selected.file}`} width="360" height="800" alt={selected.alt} /></div>
        <div className="lightbox-controls"><button type="button" onClick={() => changeCapture(-1)} aria-label="Previous screenshot"><ChevronLeft size={19} /> Previous</button><span>{String(selectedIndex + 1).padStart(2, '0')} / {String(captures.length).padStart(2, '0')}</span><button type="button" onClick={() => changeCapture(1)} aria-label="Next screenshot">Next <ChevronRight size={19} /></button></div>
      </div>
    </div>,
    document.body,
  );

  return <>
    <div className="page-shell shell">
      <PageIntro kicker="THE APP" title={<>NextClass,<br /><span>screen by<br className="mobile-title-break" /> screen.</span></>} description="Actual Flutter-rendered app previews with sample university data. Open any screen to see it at full size." />
      <div className="gallery-grid" data-reveal aria-label="NextClass app screenshots">
        {captures.map((item, index) => <article className={`capture-card capture-${index + 1}`} key={item.file} data-reveal-item>
          <button className="capture-image-button" type="button" onClick={(event) => { opener.current = event.currentTarget; setSelectedIndex(index); }} aria-label={`Open larger preview: ${item.title}`}>
            <img src={`/images/screenshots/${item.file}`} width="360" height="800" loading="lazy" alt={item.alt} />
            <span className="capture-open"><ZoomIn size={15} aria-hidden="true" /> View screen</span>
          </button>
          <div className="capture-caption"><h2>{item.title}</h2><p>{item.text}</p></div>
        </article>)}
      </div>
      <p className="gallery-source-note">Previews are rendered from the app’s Flutter widgets using sample data.</p>
    </div>
    {previewModal}
  </>;
}