/**
 * NextClass — Interactive Landing Page Script
 * Powers phone simulator screen transitions, live dynamic data,
 * interactive week day switcher, FAQ toggles, and Google Play Store link actions.
 */

document.addEventListener('DOMContentLoaded', () => {
  initClock();
  initPhoneSimulator();
  initFaqAccordion();
  initSmoothScroll();
  initMobileMenu();
});

/* --------------------------------------------------------------------------
   1. Live Phone Status Bar Clock
   -------------------------------------------------------------------------- */
function initClock() {
  const clockElement = document.getElementById('phone-live-clock');
  if (!clockElement) return;

  function updateTime() {
    const now = new Date();
    let hours = now.getHours();
    let minutes = now.getMinutes();
    hours = hours % 12 || 12;
    minutes = minutes < 10 ? '0' + minutes : minutes;
    clockElement.textContent = `${hours}:${minutes}`;
  }

  updateTime();
  setInterval(updateTime, 10000);
}

/* --------------------------------------------------------------------------
   2. Interactive Phone Simulator Screens
   -------------------------------------------------------------------------- */
const screenTemplates = {
  today: `
    <div class="screen-header">
      <div class="screen-badge">TODAY · OCT 10 ⚡</div>
      <h2 class="screen-title">Good morning</h2>
      <p class="screen-subtitle">Your day at COMSATS</p>
    </div>

    <div class="agenda-pill">
      <span class="pill-dot"></span>
      <span>2 classes left · next in 15m</span>
    </div>

    <!-- Active Class Card -->
    <div class="mock-class-card active-class">
      <div class="mock-card-inner">
        <div class="mock-card-stripe" style="background-color: var(--yellow);"></div>
        <div class="mock-card-body">
          <div class="mock-card-top">
            <div class="mock-card-title">Data Structures &amp; Algorithms</div>
            <span class="mock-status-tag" style="background-color: var(--yellow);">LIVE NOW</span>
          </div>
          <div class="mock-card-meta">
            <span>⏱️ 10:00 – 11:30 AM</span>
            <span>📍 CS-301</span>
            <span>👨‍🏫 Dr. Vance</span>
          </div>
          <div class="mock-progress-wrap" title="Class progress">
            <div class="mock-progress-fill" style="width: 72%;"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Next Class Card -->
    <div class="mock-class-card next-class">
      <div class="mock-card-inner">
        <div class="mock-card-stripe" style="background-color: var(--orange);"></div>
        <div class="mock-card-body">
          <div class="mock-card-top">
            <div class="mock-card-title">Operating Systems</div>
            <span class="mock-status-tag tag-urgent">NEXT UP</span>
          </div>
          <div class="mock-card-meta">
            <span>⏱️ 12:00 – 01:30 PM</span>
            <span>📍 LB-204</span>
            <span>👨‍🏫 Prof. Harris</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Upcoming Quiz Alert -->
    <div class="mock-quiz-preview">
      <div class="mock-quiz-left">
        <div class="mock-quiz-bell">🔔</div>
        <div>
          <div class="mock-quiz-title">Algo Midterm Quiz</div>
          <div class="mock-quiz-due">Tomorrow at 9:00 AM · Chapter 4-6</div>
        </div>
      </div>
      <span class="mock-status-tag tag-urgent">URGENT</span>
    </div>

    <!-- Done Class (Past) -->
    <div class="mock-class-card" style="opacity: 0.75; background: #ECEFF1;">
      <div class="mock-card-inner">
        <div class="mock-card-stripe" style="background-color: #9E9E9E;"></div>
        <div class="mock-card-body">
          <div class="mock-card-top">
            <div class="mock-card-title" style="text-decoration: line-through; color: #555;">Calculus III</div>
            <span class="mock-status-tag" style="background-color: #CFD8DC;">COMPLETED ✓</span>
          </div>
          <div class="mock-card-meta">
            <span>⏱️ 08:30 – 10:00 AM</span>
            <span>📍 M-102</span>
          </div>
        </div>
      </div>
    </div>
  `,

  scan: `
    <div class="screen-header">
      <div class="screen-badge" style="background: var(--green);">GEMINI 3.8 VISION 📷</div>
      <h2 class="screen-title">AI Timetable Scan</h2>
      <p class="screen-subtitle">Photo-to-schedule in 3.2s</p>
    </div>

    <div class="scanner-graphic">
      <div class="scanner-laser"></div>
      <div class="timetable-paper-mock">
        <div style="font-size: 0.68rem; font-weight: 800; margin-bottom: 8px; text-transform: uppercase;">
          Department Timetable Fall 2026
        </div>
        <div class="paper-grid">
          <div class="paper-cell detected">CS-301<br>10:00</div>
          <div class="paper-cell detected">OS-204<br>12:00</div>
          <div class="paper-cell">LUNCH<br>1:30</div>
          <div class="paper-cell detected">SE-101<br>2:00</div>
        </div>
        <div style="margin-top: 10px; display: flex; justify-content: space-between; align-items: center;">
          <span class="ai-pill-detected">✓ 14 Classes Detected</span>
          <span style="font-size: 0.65rem; font-weight: 800; color: #666;">Daily Quota: 2/2</span>
        </div>
      </div>
    </div>

    <div style="background: #FFFFFF; border: 2px solid #000; border-radius: 6px; padding: 10px; box-shadow: 2px 2px 0px #000;">
      <div style="font-size: 0.75rem; font-weight: 900; color: #000; margin-bottom: 4px;">⚡ Gemini Extraction Status:</div>
      <div style="font-size: 0.7rem; color: #2E7D32; font-weight: 700;">● Multimodal OCR: Completed</div>
      <div style="font-size: 0.7rem; color: #2E7D32; font-weight: 700;">● Room &amp; Time Normalization: 100%</div>
      <div style="font-size: 0.7rem; color: #FF6D00; font-weight: 700;">● 1 Uncertain room flagged for review</div>
    </div>

    <button class="btn btn-primary btn-sm" style="width: 100%;" onclick="switchPhoneScreen('review')">
      Review &amp; Verify Schedule ➔
    </button>
  `,

  review: `
    <div class="screen-header">
      <div class="screen-badge" style="background: var(--blue); color: #FFF;">VERIFICATION ✍️</div>
      <h2 class="screen-title">Review Schedule</h2>
      <p class="screen-subtitle">Verify parsed classes before saving</p>
    </div>

    <div style="display: flex; flex-direction: column; gap: 8px;">
      <!-- Editable Item 1 -->
      <div class="mock-class-card" style="border: 2px solid #000;">
        <div class="mock-card-inner">
          <div class="mock-card-stripe" style="background-color: var(--yellow);"></div>
          <div class="mock-card-body" style="padding: 8px 10px;">
            <div class="mock-card-top">
              <div class="mock-card-title" style="font-size: 0.85rem;">Data Structures</div>
              <span class="mock-status-tag" style="background: #E0E0E0;">EDIT</span>
            </div>
            <div class="mock-card-meta" style="font-size: 0.68rem;">
              <span>Monday · 10:00 – 11:30</span>
              <span>Room: CS-301</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Editable Item 2 with AI UNSURE BADGE -->
      <div class="mock-class-card" style="border: 2px solid #D50000; background: #FFEBEE;">
        <div class="mock-card-inner">
          <div class="mock-card-stripe" style="background-color: var(--orange);"></div>
          <div class="mock-card-body" style="padding: 8px 10px;">
            <div class="mock-card-top">
              <div class="mock-card-title" style="font-size: 0.85rem;">Operating Systems</div>
              <span class="mock-status-tag" style="background: #D50000; color: #FFF;">AI UNSURE ?</span>
            </div>
            <div class="mock-card-meta" style="font-size: 0.68rem; color: #C62828;">
              <span>Monday · 12:00 – 01:30</span>
              <span>Room: LB-204 (Tap to fix)</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Editable Item 3 -->
      <div class="mock-class-card" style="border: 2px solid #000;">
        <div class="mock-card-inner">
          <div class="mock-card-stripe" style="background-color: var(--green);"></div>
          <div class="mock-card-body" style="padding: 8px 10px;">
            <div class="mock-card-top">
              <div class="mock-card-title" style="font-size: 0.85rem;">Database Systems</div>
              <span class="mock-status-tag" style="background: #E0E0E0;">EDIT</span>
            </div>
            <div class="mock-card-meta" style="font-size: 0.68rem;">
              <span>Tuesday · 09:00 – 10:30</span>
              <span>Room: DB-Lab 2</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <button class="btn btn-yellow btn-sm" style="width: 100%; margin-top: 4px;" onclick="switchPhoneScreen('today')">
      Looks Great, Save Timetable 🚀
    </button>
  `,

  week: `
    <div class="screen-header">
      <div class="screen-badge">WEEK VIEW 🗓️</div>
      <h2 class="screen-title">Full Timetable</h2>
      <p class="screen-subtitle">Your entire weekly schedule</p>
    </div>

    <!-- Day Selector Strip -->
    <div style="display: flex; gap: 4px; overflow-x: auto; padding-bottom: 4px;">
      <div class="mock-day-pill" style="padding: 4px 8px; border: 1.5px solid #000; border-radius: 4px; background: #FFF; font-size: 0.65rem; font-weight: 800;">MON (3)</div>
      <div class="mock-day-pill" style="padding: 4px 8px; border: 1.5px solid #000; border-radius: 4px; background: #FFF; font-size: 0.65rem; font-weight: 800;">TUE (4)</div>
      <div class="mock-day-pill" style="padding: 4px 8px; border: 1.5px solid #000; border-radius: 4px; background: var(--yellow); font-size: 0.65rem; font-weight: 900; box-shadow: 1.5px 1.5px 0px #000;">WED (3) ★</div>
      <div class="mock-day-pill" style="padding: 4px 8px; border: 1.5px solid #000; border-radius: 4px; background: #FFF; font-size: 0.65rem; font-weight: 800;">THU (2)</div>
      <div class="mock-day-pill" style="padding: 4px 8px; border: 1.5px solid #000; border-radius: 4px; background: #FFF; font-size: 0.65rem; font-weight: 800;">FRI (3)</div>
    </div>

    <!-- Wednesday Schedule List -->
    <div style="display: flex; flex-direction: column; gap: 8px;">
      <div class="mock-class-card" style="border: 2px solid #000;">
        <div class="mock-card-inner">
          <div class="mock-card-stripe" style="background-color: var(--blue);"></div>
          <div class="mock-card-body" style="padding: 8px 10px;">
            <div class="mock-card-top">
              <div class="mock-card-title" style="font-size: 0.85rem;">Computer Networks</div>
              <span style="font-size: 0.65rem; font-weight: 800;">09:00 - 10:30</span>
            </div>
            <div class="mock-card-meta" style="font-size: 0.68rem;">
              <span>📍 Room NET-01</span>
              <span>👨‍🏫 Dr. Tariq</span>
            </div>
          </div>
        </div>
      </div>

      <div class="mock-class-card" style="border: 2px solid #000; background: var(--yellow-light);">
        <div class="mock-card-inner">
          <div class="mock-card-stripe" style="background-color: var(--yellow);"></div>
          <div class="mock-card-body" style="padding: 8px 10px;">
            <div class="mock-card-top">
              <div class="mock-card-title" style="font-size: 0.85rem;">Algorithms Lab</div>
              <span class="mock-status-tag">NOW</span>
            </div>
            <div class="mock-card-meta" style="font-size: 0.68rem;">
              <span>⏱️ 11:00 – 01:00</span>
              <span>📍 Lab-4</span>
            </div>
          </div>
        </div>
      </div>

      <div class="mock-class-card" style="border: 2px solid #000;">
        <div class="mock-card-inner">
          <div class="mock-card-stripe" style="background-color: var(--pink);"></div>
          <div class="mock-card-body" style="padding: 8px 10px;">
            <div class="mock-card-top">
              <div class="mock-card-title" style="font-size: 0.85rem;">Technical Writing</div>
              <span style="font-size: 0.65rem; font-weight: 800;">02:00 - 03:30</span>
            </div>
            <div class="mock-card-meta" style="font-size: 0.68rem;">
              <span>📍 Room H-205</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,

  quizzes: `
    <div class="screen-header">
      <div class="screen-badge" style="background: var(--coral-urgent); color: #FFF;">DEADLINE RADAR ⏰</div>
      <h2 class="screen-title">Quizzes &amp; Tests</h2>
      <p class="screen-subtitle">Evening-before &amp; morning-of alarms</p>
    </div>

    <!-- Filter chips -->
    <div style="display: flex; gap: 6px;">
      <span class="mock-status-tag tag-urgent" style="font-size: 0.7rem; padding: 4px 8px;">ALL (4)</span>
      <span class="mock-status-tag" style="background: #FFF; font-size: 0.7rem; padding: 4px 8px;">TODAY / TMRW (2)</span>
      <span class="mock-status-tag" style="background: #FFF; font-size: 0.7rem; padding: 4px 8px;">UPCOMING (2)</span>
    </div>

    <!-- Quiz Card 1: Urgent -->
    <div class="mock-class-card" style="background: #FFF8E1; border: 2.5px solid #000;">
      <div class="mock-card-inner">
        <div class="mock-card-stripe" style="background-color: var(--coral-urgent); width: 10px;"></div>
        <div class="mock-card-body" style="padding: 10px;">
          <div class="mock-card-top">
            <div class="mock-card-title" style="font-size: 0.9rem;">Algorithms Midterm</div>
            <span class="mock-status-tag tag-urgent">TOMORROW</span>
          </div>
          <div class="mock-card-meta" style="font-size: 0.7rem; color: #444;">
            <span>📅 Thu, Oct 11 · 09:00 AM</span>
            <span>🔔 Alarm: 8:00 PM tonight</span>
          </div>
          <div style="font-size: 0.68rem; color: #666; margin-top: 4px;">Weight: 15% · Bring Calculator</div>
        </div>
      </div>
    </div>

    <!-- Quiz Card 2 -->
    <div class="mock-class-card" style="border: 2px solid #000;">
      <div class="mock-card-inner">
        <div class="mock-card-stripe" style="background-color: var(--orange); width: 10px;"></div>
        <div class="mock-card-body" style="padding: 10px;">
          <div class="mock-card-top">
            <div class="mock-card-title" style="font-size: 0.9rem;">OS Threads Quiz</div>
            <span class="mock-status-tag" style="background: #FFE0B2;">IN 3 DAYS</span>
          </div>
          <div class="mock-card-meta" style="font-size: 0.7rem; color: #444;">
            <span>📅 Mon, Oct 15 · 12:00 PM</span>
            <span>🔔 Reminder scheduled</span>
          </div>
        </div>
      </div>
    </div>

    <button class="btn btn-primary btn-sm" style="width: 100%; margin-top: 4px;">
      + Add New Quiz / Exam
    </button>
  `
};

function initPhoneSimulator() {
  const scrollArea = document.getElementById('phone-scroll-content');
  const buttons = document.querySelectorAll('.screen-switch-btn');
  const navItems = document.querySelectorAll('.mock-nav-item');

  if (!scrollArea) return;

  // Set default view
  scrollArea.innerHTML = screenTemplates.today;

  window.switchPhoneScreen = function(screenKey) {
    if (!screenTemplates[screenKey]) return;

    // Fade out and swap
    scrollArea.style.opacity = '0';
    scrollArea.style.transform = 'translateY(6px)';
    scrollArea.style.transition = 'all 0.15s ease';

    setTimeout(() => {
      scrollArea.innerHTML = screenTemplates[screenKey];
      scrollArea.style.opacity = '1';
      scrollArea.style.transform = 'translateY(0)';

      // Update button active state
      buttons.forEach(btn => {
        if (btn.dataset.screen === screenKey) {
          btn.classList.add('active');
        } else {
          btn.classList.remove('active');
        }
      });

      // Update phone bottom nav active state if matching
      navItems.forEach(item => {
        if (item.dataset.screen === screenKey) {
          item.classList.add('active');
        } else {
          item.classList.remove('active');
        }
      });
    }, 150);
  };

  buttons.forEach(btn => {
    btn.addEventListener('click', () => {
      const screenKey = btn.dataset.screen;
      window.switchPhoneScreen(screenKey);
    });
  });

  navItems.forEach(item => {
    item.addEventListener('click', () => {
      const screenKey = item.dataset.screen;
      if (screenKey && screenTemplates[screenKey]) {
        window.switchPhoneScreen(screenKey);
      }
    });
  });
}

/* --------------------------------------------------------------------------
   3. FAQ Accordion
   -------------------------------------------------------------------------- */
function initFaqAccordion() {
  const faqCards = document.querySelectorAll('.faq-card');

  faqCards.forEach(card => {
    const question = card.querySelector('.faq-question');
    if (!question) return;

    question.addEventListener('click', () => {
      const isOpen = card.classList.contains('open');

      // Close all others
      faqCards.forEach(c => c.classList.remove('open'));

      // Toggle current
      if (!isOpen) {
        card.classList.add('open');
      }
    });
  });
}

/* --------------------------------------------------------------------------
   4. Smooth Scroll for Navigation Links
   -------------------------------------------------------------------------- */
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (targetId === '#' || targetId === '') return;

      const targetEl = document.querySelector(targetId);
      if (targetEl) {
        e.preventDefault();
        targetEl.scrollIntoView({
          behavior: 'smooth',
          block: 'start'
        });
      }
    });
  });
}

/* --------------------------------------------------------------------------
   5. Mobile Menu Toggle
   -------------------------------------------------------------------------- */
function initMobileMenu() {
  const toggleBtn = document.querySelector('.menu-toggle');
  const navLinks = document.querySelector('.nav-links');

  if (!toggleBtn || !navLinks) return;

  toggleBtn.addEventListener('click', () => {
    const isVisible = navLinks.style.display === 'flex';
    if (isVisible) {
      navLinks.style.display = 'none';
    } else {
      navLinks.style.display = 'flex';
      navLinks.style.flexDirection = 'column';
      navLinks.style.position = 'absolute';
      navLinks.style.top = '100%';
      navLinks.style.left = '0';
      navLinks.style.width = '100%';
      navLinks.style.background = 'var(--bg)';
      navLinks.style.borderBottom = 'var(--border-width) solid var(--border-color)';
      navLinks.style.padding = '20px';
      navLinks.style.boxShadow = 'var(--shadow-md)';
      navLinks.style.zIndex = '999';
    }
  });
}

/* --------------------------------------------------------------------------
   6. Interactive Play Store Button Toast Feedback
   -------------------------------------------------------------------------- */
window.handlePlayStoreClick = function(event) {
  // Can be called to log or provide feedback
  console.log('Navigating to Google Play Store: com.nextclass.app');
};
