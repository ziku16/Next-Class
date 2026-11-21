import { ExternalLink } from 'lucide-react';
import PageIntro from '../components/PageIntro.jsx';
import usePageMeta from '../components/usePageMeta.js';
import { releaseConfig } from '../data/releaseConfig.js';

const sections = [
  ['Saved information', 'Class schedules, quiz details, exam schedules, and preferences are stored in the app’s local SQLite database on your device. Saved schedules remain available offline. NextClass does not provide an account or cloud sync. The app does not encrypt this database.'],
  ['AI timetable and exam scanning', 'AI scanning needs an internet connection. For a timetable, the app prepares the selected image on your device and sends it to the NextClass Cloudflare Worker. For an exam sheet, PDFs and images are sent through the Worker; XLSX workbook cells are read on your device and the extracted text is sent. The Worker forwards supported extraction requests to Google Gemini. You can review detected classes or exams before saving them.'],
  ['Temporary processing', 'The Worker temporarily caches normalized extraction results so a duplicate request can return the same result. AI scans are not processed entirely on your device.'],
  ['Google Gemini', 'Google Gemini processes the selected image or extracted workbook text and prompt as an external service. Google’s applicable terms and privacy practices govern that processing. Review a document before scanning if it contains personal or sensitive information.'],
  ['Reminders', 'Class, quiz, and exam reminders are scheduled locally on your Android device. Android notification, battery, and alarm settings can affect when reminders appear.'],
  ['Your choices', 'AI scanning is optional. You can edit or clear saved records in the app, or remove local app data by clearing storage or uninstalling NextClass.'],
  ['Contact', 'For privacy questions or support, email muhammadzakriaawan237@gmail.com. Please do not email timetables, exam sheets, student IDs, or other private documents.'],
];

export default function PrivacyPage() {
  usePageMeta({ title: 'Privacy — NextClass', description: 'How NextClass stores schedules and handles optional AI timetable and exam scanning.', path: '/privacy' });
  return <div className="page-shell shell">
    <PageIntro kicker="PRIVACY" title={<>Your schedule,<br /><span>on your device.</span></>} description="Saved information stays on your device. Optional AI scanning sends selected content through the NextClass Worker to Google Gemini and needs internet." />
    <div className="privacy-callout" data-reveal><span className="callout-icon"><ExternalLink size={22} /></span><p><strong>AI scans send selected content outside the app.</strong> Check timetable images and exam documents for names, student IDs, or other private information before scanning.</p></div>
    <div className="privacy-sections">{sections.map(([title, content], index) => <section className="privacy-section" key={title} data-reveal><span className="privacy-number">{String(index + 1).padStart(2, '0')}</span><div><h2>{title}</h2><p>{content}</p>{index === 3 && <p className="privacy-links"><a href="https://ai.google.dev/gemini-api/terms" target="_blank" rel="noreferrer">Gemini API terms <ExternalLink size={14} /></a><a href="https://policies.google.com/privacy" target="_blank" rel="noreferrer">Google Privacy Policy <ExternalLink size={14} /></a></p>}{index === 6 && <p className="privacy-links"><a href={`mailto:${releaseConfig.supportEmail}`}>Email NextClass support</a></p>}</div></section>)}</div>
  </div>;
}
