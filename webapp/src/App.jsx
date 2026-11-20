import { Suspense, lazy, useEffect } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import SiteLayout from './layouts/SiteLayout.jsx';
import { ReleaseProvider } from './hooks/useRelease.jsx';

const HomePage = lazy(() => import('./pages/HomePage.jsx'));
const FeaturesPage = lazy(() => import('./pages/FeaturesPage.jsx'));
const ScreenshotsPage = lazy(() => import('./pages/ScreenshotsPage.jsx'));
const DownloadPage = lazy(() => import('./pages/DownloadPage.jsx'));
const PrivacyPage = lazy(() => import('./pages/PrivacyPage.jsx'));

const routeMeta = {
  '/': ['NextClass — Your semester. Under control.', 'Classes, quizzes, exams and reminders. One app. Zero chaos.'],
  '/features': ['Features — NextClass', 'A clear look at the timetable, quiz, reminder, and scanning features in NextClass.'],
  '/screenshots': ['Screenshots — NextClass', 'See real NextClass screens. Missing captures are clearly marked.'],
  '/download': ['Download NextClass for Android', 'Get the official NextClass Android APK and read the installation guide.'],
  '/privacy': ['Privacy — NextClass', 'How NextClass stores schedules locally and sends selected timetable images to Google Gemini.'],
};

function RouteEffects() {
  const { pathname } = useLocation();
  useEffect(() => {
    const [title, description] = routeMeta[pathname] ?? routeMeta['/'];
    document.title = title;
    document.querySelector('meta[name="description"]')?.setAttribute('content', description);
    document.querySelector('meta[property="og:title"]')?.setAttribute('content', title);
    document.querySelector('meta[property="og:description"]')?.setAttribute('content', description);
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

function LoadingPage() {
  return <main className="page-loading" aria-live="polite"><span className="loading-mark" />Loading NextClass…</main>;
}

export default function App() {
  return (
    <ReleaseProvider>
      <RouteEffects />
      <Suspense fallback={<LoadingPage />}>
        <Routes>
          <Route element={<SiteLayout />}>
            <Route path="/" element={<HomePage />} />
            <Route path="/features" element={<FeaturesPage />} />
            <Route path="/screenshots" element={<ScreenshotsPage />} />
            <Route path="/download" element={<DownloadPage />} />
            <Route path="/privacy" element={<PrivacyPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </Suspense>
    </ReleaseProvider>
  );
}
