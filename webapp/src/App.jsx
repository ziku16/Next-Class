import { Suspense, lazy, useEffect } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import PageMotion from './components/PageMotion.jsx';
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
  '/screenshots': ['Screenshots — NextClass', 'A look at the NextClass Android app.'],
  '/download': ['Download NextClass for Android', 'Get the current NextClass Android release.'],
  '/privacy': ['Privacy — NextClass', 'How NextClass stores timetable and quiz information and handles optional AI timetable scanning.'],
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
    const frame = window.requestAnimationFrame(() => ScrollTrigger.refresh());
    return () => window.cancelAnimationFrame(frame);
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
            <Route path="/" element={<PageMotion><HomePage /></PageMotion>} />
            <Route path="/features" element={<PageMotion><FeaturesPage /></PageMotion>} />
            <Route path="/screenshots" element={<PageMotion><ScreenshotsPage /></PageMotion>} />
            <Route path="/download" element={<PageMotion><DownloadPage /></PageMotion>} />
            <Route path="/privacy" element={<PageMotion><PrivacyPage /></PageMotion>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </Suspense>
    </ReleaseProvider>
  );
}
