#!/usr/bin/env python3
"""
NextClass 16:9 Landscape Video Generator
Renders a 1920x1080 cinematic product showcase commercial for YouTube / Website Hero / Product Hunt.
"""

import os
import sys
import math
import subprocess
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

import generate_audio
from video_renderer import (
    BG_COLOR, BLACK, WHITE, YELLOW, ORANGE, GREEN, RED, CYAN,
    PALE_YELLOW, PALE_ORANGE, TICKET_GREY, DARK_BG,
    get_font, draw_card, draw_badge, draw_brand_sticker,
    draw_starburst, draw_hatching_progress_bar, draw_phone_chassis,
    draw_kinetic_banner, draw_circle, crumpled_img, scan_img, app_icon_img
)

WIDTH = 1920
HEIGHT = 1080
FPS = 30
DURATION_SEC = 30.0
TOTAL_FRAMES = int(FPS * DURATION_SEC)

AUDIO_FILE = "/tmp/nextclass_soundtrack.wav"
OUTPUT_VIDEO_PATH = os.path.join(BASE_DIR, "NextClass_Showcase_16x9.mp4")
OUTPUT_VIDEO_ALT = os.path.join(BASE_DIR, "nextclass_landscape.mp4")

FFMPEG_EXE = "/home/zaki/.local/lib/python3.12/site-packages/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2"
if not os.path.exists(FFMPEG_EXE):
    FFMPEG_EXE = "ffmpeg"


def draw_header_bar(draw, title_tag="NEXTCLASS ↗"):
    # Slanted sticker in top left
    draw_badge(draw, title_tag, 80, 50, bg_color=YELLOW, font_size=24, pad_x=16, pad_y=8)
    draw_badge(draw, "OCTOBER 2026 • UNIVERSITY ASSISTANT", 320, 50, bg_color=WHITE, font_size=18, pad_x=14, pad_y=10)


def render_scene_1(t, draw, frame):
    """0.0s - 4.5s: Problem -> Brand Reveal (Landscape)"""
    if t < 2.5:
        zoom = 1.0 + 0.08 * (t / 2.5)
        zw = int(WIDTH * zoom)
        zh = int(HEIGHT * zoom)
        
        shake_x, shake_y = 0, 0
        if 1.5 <= t < 1.9:
            st = (t - 1.5) / 0.4
            shake_amp = 18.0 * math.exp(-st * 6.0)
            shake_x = int(math.sin(st * 40.0) * shake_amp)
            shake_y = int(math.cos(st * 35.0) * shake_amp)
            
        if crumpled_img:
            cw, ch = crumpled_img.size
            crop_img = crumpled_img.resize((zw, zh), Image.BILINEAR)
            ox = (WIDTH - zw) // 2 + shake_x
            oy = (HEIGHT - zh) // 2 + shake_y
            frame.paste(crop_img, (ox, oy))
        else:
            draw.rectangle([0, 0, WIDTH, HEIGHT], fill=(230, 225, 215))

        overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 60))
        frame.paste(overlay, (0, 0), overlay)

        # Kinetic Text
        draw_badge(draw, "POV: STILL ZOOMING INTO BLURRY TIMETABLES? 💀", 400 + shake_x, 880 + shake_y, bg_color=YELLOW, font_size=32, pad_x=28, pad_y=16)

        if t >= 1.4:
            st = (t - 1.4) / 0.3
            scale = 1.0 + 0.35 * math.sin((1.0 - min(1.0, st)) * math.pi) if st < 1.0 else 1.0
            stamp_w = int(1100 * scale)
            stamp_h = int(140 * scale)
            sx = (WIDTH - stamp_w) // 2 + shake_x
            sy = (HEIGHT - stamp_h) // 2 - 50 + shake_y

            draw.rounded_rectangle([sx + 8, sy + 8, sx + stamp_w + 8, sy + stamp_h + 8], radius=20, fill=BLACK)
            draw.rounded_rectangle([sx, sy, sx + stamp_w, sy + stamp_h], radius=20, fill=YELLOW, outline=BLACK, width=5)
            
            f_stamp = get_font(int(42 * scale))
            stext = "STOP DIGGING THROUGH WHATSAPP SCREENSHOTS ✕"
            sbox = f_stamp.getbbox(stext)
            tx = sx + (stamp_w - (sbox[2] - sbox[0])) // 2
            ty = sy + (stamp_h - (sbox[3] - sbox[1])) // 2 - sbox[1]
            draw.text((tx, ty), stext, fill=BLACK, font=f_stamp)

    else:
        draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
        draw_header_bar(draw)

        # Left Column: Hero Text
        f_hero = get_font(68)
        draw.text((120, 240), "Your semester,\nsorted.", fill=BLACK, font=f_hero, spacing=14)
        
        f_sub = get_font(30)
        draw.text((120, 440), "Never miss what's next.\n100% Offline • Zero Accounts • Pure Brutalism.", fill=(70, 70, 70), font=f_sub, spacing=8)

        draw_badge(draw, "[ 1-PHOTO IMPORT ]", 120, 580, bg_color=YELLOW, font_size=22, pad_x=18, pad_y=10)
        draw_badge(draw, "AUTOMATIC NUDGES", 400, 580, bg_color=TICKET_GREY, font_size=22, pad_x=18, pad_y=10)
        draw_badge(draw, "[ 100% OFFLINE ]", 120, 660, bg_color=GREEN, font_size=22, pad_x=18, pad_y=10)
        draw_badge(draw, "[ ZERO ADS ]", 360, 660, bg_color=TICKET_GREY, font_size=22, pad_x=18, pad_y=10)

        # Right Column: Phone Mockup
        pw, ph = 460, 880
        px, py = 1200, 100
        draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

        sticker_img = draw_brand_sticker(draw, px + 30, py + 80, scale=0.9, angle_deg=-2.5)
        frame.paste(sticker_img, (px + 30, py + 80), sticker_img)

        draw.text((px + 30, py + 160), "Good morning, Ali", fill=BLACK, font=get_font(28))
        draw_badge(draw, "Friday, 2 Oct", px + 30, py + 210, bg_color=BLACK, text_color=WHITE, font_size=15, radius=12)

        # Welcome Button
        btn_pressed = (t >= 3.6)
        btn_ox = 0 if btn_pressed else 4
        btn_oy = 0 if btn_pressed else 4
        b_rect = [px + 30 + btn_ox, py + 720 + btn_oy, px + pw - 30 + btn_ox, py + 800 + btn_oy]
        draw_card(draw, b_rect, fill=ORANGE, border_w=3.5, shadow_offset=(0,0) if btn_pressed else (4,4), radius=12)
        f_b = get_font(22)
        draw.text((px + 85, py + 745), "Upload timetable ↗", fill=WHITE, font=f_b)

        # Center App Icon
        if app_icon_img:
            isize = 240
            ix = px + (pw - isize)//2
            iy = py + 340
            draw_card(draw, [ix - 6, iy - 6, ix + isize + 6, iy + isize + 6], fill=WHITE, border_w=3, radius=24, shadow_offset=(4,4))
            ricon = app_icon_img.resize((isize, isize), Image.BILINEAR)
            frame.paste(ricon, (ix, iy))


def render_scene_2(t, draw, frame):
    """4.5s - 9.5s: 1 Photo Import -> Timetable Review (Landscape)"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    draw_header_bar(draw, "SCAN & PARSE ⚡")

    # Left: Scanning / Parsing view
    pw, ph = 460, 880
    px, py = 120, 100

    if t < 6.8:
        draw_phone_chassis(draw, px, py, pw, ph, bg_fill=(25, 25, 25), is_dark=True)
        draw_badge(draw, "[ TIMETABLE SCANNER ]", px + 30, py + 70, bg_color=YELLOW, font_size=16)

        # Viewfinder
        vx0, vy0, vx1, vy1 = px + 25, py + 120, px + pw - 25, py + 700
        draw.rectangle([vx0, vy0, vx1, vy1], outline=WHITE, width=2)
        if scan_img:
            crop_img = scan_img.resize((vx1 - vx0, vy1 - vy0), Image.BILINEAR)
            frame.paste(crop_img, (vx0, vy0))

        # Laser
        scan_progress = ((t - 4.5) / 1.5) % 1.0
        laser_y = int(vy0 + scan_progress * (vy1 - vy0))
        draw.line([(vx0, laser_y), (vx1, laser_y)], fill=YELLOW, width=4)

        # Right side: Extraction Explainer
        f_h = get_font(48)
        draw.text((700, 220), "1 Photo ➔ Full Timetable", fill=BLACK, font=f_h)
        f_desc = get_font(26)
        draw.text((700, 310), "Point your camera at any syllabus or paper schedule.\nNextClass automatically detects subjects, rooms, and professors.", fill=(70, 70, 70), font=f_desc, spacing=8)

        draw_badge(draw, "MATHEMATICS (Room A-04)", 700, 460, bg_color=GREEN, font_size=22)
        draw_badge(draw, "PHYSICS (Room B-12)", 700, 540, bg_color=YELLOW, font_size=22)
        draw_badge(draw, "CHEMISTRY LAB (Lab 2)", 700, 620, bg_color=ORANGE, text_color=WHITE, font_size=22)

    else:
        # Loader / Review Screen
        draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)
        star_angle = (t - 6.8) * 200.0
        draw_starburst(draw, px + pw//2, py + 340, r_outer=90, r_inner=60, num_points=12, angle_deg=star_angle, fill=YELLOW)
        draw_circle(draw, (px + pw//2, py + 340), 40, fill=BLACK)
        draw.text((px + pw//2 - 18, py + 340 - 14), "AI", fill=YELLOW, font=get_font(22))
        draw.text((px + 40, py + 480), "Parsing Schedule...", fill=BLACK, font=get_font(26))
        
        # Right Side: Cascading Cards on Monday schedule
        f_h = get_font(48)
        draw.text((700, 160), "Review Extracted Schedule", fill=BLACK, font=f_h)
        draw_badge(draw, "3 CLASSES DETECTED", 1450, 165, bg_color=GREEN, font_size=20)

        cards = [
            ("Mathematics", "08:30 – 09:20", "Room A-04", "Dr. Smith", TICKET_GREY),
            ("Physics", "09:30 – 10:20", "Room B-12", "Prof. Miller", PALE_YELLOW),
            ("Chemistry Lab", "11:00 – 12:40", "Lab 2", "Ms. Sara", PALE_ORANGE),
        ]
        cy = 260
        for subj, tstr, rm, pf, col in cards:
            draw_card(draw, [700, cy, 1750, cy + 140], fill=col, border_w=3.5, radius=16, shadow_offset=(5,5))
            draw.text((730, cy + 22), subj, fill=BLACK, font=get_font(32))
            draw.text((730, cy + 80), tstr, fill=(60, 60, 60), font=get_font(22))
            draw_badge(draw, rm, 1150, cy + 45, bg_color=WHITE, font_size=20)
            draw_badge(draw, pf, 1420, cy + 45, bg_color=WHITE, font_size=20)
            cy += 170

        # Action Button on Right
        btn_pressed = (t >= 9.0)
        draw_card(draw, [700, 800, 1200, 880], fill=ORANGE, border_w=3.5, shadow_offset=(0,0) if btn_pressed else (5,5), radius=16)
        draw.text((780, 825), "Looks good, let's go! ↗", fill=WHITE, font=get_font(26))


def render_scene_3(t, draw, frame):
    """9.5s - 16.0s: Today Screen Command Center & Live Progress Bar"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    draw_header_bar(draw, "TODAY SCREEN • LIVE AGENDA")

    # Left: Phone running Today Screen
    pw, ph = 460, 880
    px, py = 120, 100
    draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

    draw.text((px + 30, py + 80), "Good morning, Ali", fill=BLACK, font=get_font(28))
    draw_badge(draw, "Friday, 2 October", px + 30, py + 125, bg_color=BLACK, text_color=WHITE, font_size=15, radius=12)

    # Active card inside phone
    draw_card(draw, [px + 20, py + 190, px + pw - 20, py + 410], fill=PALE_YELLOW, border_w=3.5, radius=16, shadow_offset=(4,4))
    pulse = 1.0 + 0.3 * math.sin((t - 9.5) * 8.0)
    draw_circle(draw, (px + 45, py + 220), int(7 * pulse), fill=RED)
    draw_badge(draw, "NOW", px + 62, py + 208, bg_color=YELLOW, font_size=14, pad_x=8, pad_y=2, shadow=False)
    draw.text((px + 40, py + 250), "Physics", fill=BLACK, font=get_font(32))
    draw.text((px + 40, py + 300), "09:30 – 10:20 • Room B-12", fill=(60,60,60), font=get_font(18))
    
    prog = 0.45 + (t - 9.5) / 6.5 * 0.35
    draw_hatching_progress_bar(draw, [px + 40, py + 345, px + pw - 40, py + 375], prog, anim_t=t)

    # Upcoming card inside phone
    draw_card(draw, [px + 20, py + 435, px + pw - 20, py + 610], fill=PALE_ORANGE, border_w=3.0, radius=14, shadow_offset=(3,3))
    draw_badge(draw, "IN 25 MIN", px + 40, py + 450, bg_color=ORANGE, text_color=WHITE, font_size=13, pad_x=8, pad_y=2)
    draw.text((px + 40, py + 485), "Chemistry Lab", fill=BLACK, font=get_font(26))
    draw.text((px + 40, py + 530), "11:00 – 12:40 • Lab 2", fill=(60,60,60), font=get_font(18))

    # Right: Macro Spotlight on Active Class Card & Live Progress Bar!
    f_h = get_font(48)
    draw.text((680, 150), "Live Class Tracking & Progress", fill=BLACK, font=f_h)
    draw_badge(draw, "OCT0221 / CLASSIFY", 1520, 155, bg_color=WHITE, font_size=18)

    # Giant spotlight card for Physics
    mc_rect = [680, 240, 1800, 680]
    draw_card(draw, mc_rect, fill=PALE_YELLOW, border_w=5.0, radius=24, shadow_offset=(8,8))

    draw_circle(draw, (740, 310), int(14 * pulse), fill=RED)
    draw_badge(draw, "NOW HAPPENING", 775, 290, bg_color=YELLOW, font_size=24, pad_x=16, pad_y=6)
    draw.text((1450, 295), "09:30 – 10:20", fill=BLACK, font=get_font(30))

    draw.text((740, 380), "Physics", fill=BLACK, font=get_font(64))
    draw_badge(draw, "Room B-12", 740, 480, bg_color=WHITE, font_size=28, pad_x=20, pad_y=8)
    draw_badge(draw, "Prof. Miller", 1040, 480, bg_color=WHITE, font_size=28, pad_x=20, pad_y=8)

    # Macro progress bar
    draw_hatching_progress_bar(draw, [740, 570, 1740, 630], prog, anim_t=t)
    draw.text((740, 640), f"{int(prog*100)}% elapsed  •  18 minutes remaining until Chemistry Lab", fill=(60, 60, 60), font=get_font(24))

    # Next badge banner below
    draw_badge(draw, "NEXT CLASS: CHEMISTRY LAB (11:00 AM • LAB 2)", 680, 740, bg_color=PALE_ORANGE, font_size=26, pad_x=24, pad_y=12)


def render_scene_4(t, draw, frame):
    """16.0s - 21.5s: Pre-Class Lock Screen Nudges"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    draw_header_bar(draw, "ALWAYS-ON DISPLAY • AUTOMATIC NUDGES")

    # Left: Phone in Dark Mode
    pw, ph = 460, 880
    px, py = 120, 100
    draw_phone_chassis(draw, px, py, pw, ph, bg_fill=DARK_BG, is_dark=True)
    draw.text((px + 140, py + 160), "09:15", fill=WHITE, font=get_font(64))
    draw.text((px + 120, py + 250), "Friday, 2 October", fill=(180, 180, 180), font=get_font(20))

    # Notification inside phone
    if t >= 16.5:
        draw_card(draw, [px + 20, py + 340, px + pw - 20, py + 560], fill=WHITE, border_w=3.5, radius=16, shadow_offset=(4,4))
        draw_badge(draw, "NEXTCLASS", px + 35, py + 355, bg_color=YELLOW, font_size=13, pad_x=6, pad_y=2)
        draw.text((px + 35, py + 395), "Physics in 15 min", fill=BLACK, font=get_font(24))
        draw.text((px + 35, py + 440), "Room B-12 • Prof. Miller", fill=BLACK, font=get_font(18))
        draw_badge(draw, "09:30 – 10:20", px + 35, py + 480, bg_color=TICKET_GREY, font_size=14, pad_x=8, pad_y=3)

    # Right: Giant Lock Screen Notification Callout
    f_h = get_font(48)
    draw.text((680, 150), "Pre-Class Nudges (Zero Alarms)", fill=BLACK, font=f_h)
    draw.text((680, 230), "NextClass alerts you 15 minutes before class with room and teacher,\nso you never walk into the wrong lecture hall again.", fill=(70, 70, 70), font=get_font(26), spacing=8)

    # Massive brutalist notification card
    nt_rect = [680, 340, 1800, 760]
    draw_card(draw, nt_rect, fill=WHITE, border_w=5.0, radius=24, shadow_offset=(8,8))

    draw_badge(draw, "NEXTCLASS • 15 MIN BEFORE", 730, 390, bg_color=YELLOW, font_size=24, pad_x=18, pad_y=8)
    draw.text((1650, 400), "Now", fill=(100, 100, 100), font=get_font(24))

    draw.text((730, 480), "Physics in 15 min", fill=BLACK, font=get_font(54))
    draw.text((730, 565), "Room B-12  •  Prof. Miller", fill=BLACK, font=get_font(34))
    draw.text((730, 630), "Scheduled: 09:30 – 10:20  •  Don't forget your lab manual!", fill=(80, 80, 80), font=get_font(26))

    draw_badge(draw, "TICKET CODE: NC03024 / CONST 00", 730, 690, bg_color=TICKET_GREY, font_size=18, pad_x=12, pad_y=4)


def render_scene_5(t, draw, frame):
    """21.5s - 26.5s: Quizzes & Night-Before Alerts"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    draw_header_bar(draw, "QUIZZES & EXAMS • REMINDERS")

    # Left: Phone on Quizzes Tab
    pw, ph = 460, 880
    px, py = 120, 100
    draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

    draw.text((px + 30, py + 80), "Quizzes & Tests", fill=BLACK, font=get_font(28))
    draw_card(draw, [px + 20, py + 140, px + pw - 20, py + 330], fill=WHITE, border_w=3.0, radius=14, shadow_offset=(3,3))
    draw_badge(draw, "TODAY • 09:30", px + 35, py + 155, bg_color=ORANGE, text_color=WHITE, font_size=13, pad_x=8, pad_y=2)
    draw.text((px + 35, py + 195), "Thermodynamics Quiz", fill=BLACK, font=get_font(22))
    draw.text((px + 35, py + 235), "Room B-12 • Prof. Miller", fill=(70,70,70), font=get_font(16))

    # Right: Giant Quiz Details & Night-Before Selector
    f_h = get_font(48)
    draw.text((680, 140), "Never Forget a Quiz or Test", fill=BLACK, font=f_h)

    # Quiz 1 Card
    draw_card(draw, [680, 220, 1800, 480], fill=WHITE, border_w=4.5, radius=20, shadow_offset=(7,7))
    draw_badge(draw, "TODAY • 09:30 AM", 720, 255, bg_color=ORANGE, text_color=WHITE, font_size=22, pad_x=16, pad_y=6)
    draw_badge(draw, "STARTS IN 15 MIN", 1020, 255, bg_color=YELLOW, font_size=20, pad_x=14, pad_y=6)

    draw.text((720, 330), "Physics • Thermodynamics Quiz", fill=BLACK, font=get_font(44))
    draw.text((720, 400), "Room B-12  •  Prof. Miller  •  Bring formula sheet & calculator", fill=(70, 70, 70), font=get_font(26))

    # Night Before Alert Widget
    draw_card(draw, [680, 530, 1800, 880], fill=WHITE, border_w=4.5, radius=20, shadow_offset=(7,7))
    draw.text((720, 565), "Smart Quiz Reminders", fill=BLACK, font=get_font(36))
    draw.text((720, 620), "Choose when NextClass notifies you so you have time to study.", fill=(80, 80, 80), font=get_font(24))

    active_night = (t >= 23.8)
    # Segmented buttons
    draw_card(draw, [720, 680, 1150, 770], fill=WHITE if not active_night else TICKET_GREY, border_w=3.0, radius=14, shadow_offset=(0,0))
    draw.text((810, 710), "Morning of class", fill=BLACK, font=get_font(26))

    draw_card(draw, [1200, 680, 1750, 770], fill=YELLOW if active_night else WHITE, border_w=3.5, radius=14, shadow_offset=(4,4) if active_night else (0,0))
    draw.text((1280, 710), "Night before at 08:00 PM", fill=BLACK, font=get_font(26))

    if active_night:
        draw_badge(draw, "ALERTS SCHEDULED: NIGHT BEFORE AT 08:00 PM", 720, 810, bg_color=GREEN, font_size=22, pad_x=20, pad_y=8)


def render_scene_6(t, draw, frame):
    """26.5s - 30.0s: Outro Brand Slap & Master CTA (Landscape)"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)

    # 3 Badges slam down horizontally
    badges = [
        ("100% OFFLINE", 26.8, YELLOW, 120),
        ("NO ACCOUNTS REQUIRED", 27.5, ORANGE, 680),
        ("ZERO ADS • PRIVATE", 28.2, GREEN, 1260),
    ]

    for label, hit_t, col, bx in badges:
        if t >= hit_t:
            st = min(1.0, (t - hit_t) / 0.25)
            scale = 1.0 + 0.3 * math.sin((1.0 - st) * math.pi) if st < 1.0 else 1.0
            bw = int(540 * scale)
            bh = int(110 * scale)
            by = 140

            draw.rounded_rectangle([bx + 6, by + 6, bx + bw + 6, by + bh + 6], radius=18, fill=BLACK)
            draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=18, fill=col, outline=BLACK, width=4)
            f_b = get_font(int(26 * scale))
            bbox = f_b.getbbox(label)
            tcol = WHITE if col == ORANGE else BLACK
            draw.text((bx + (bw - (bbox[2] - bbox[0]))//2, by + (bh - (bbox[3] - bbox[1]))//2 - bbox[1]), label, fill=tcol, font=f_b)

    # Master Box in Center
    if t >= 28.8:
        mw = 1680
        mh = 640
        mx = (WIDTH - mw) // 2
        my = 340

        draw.rounded_rectangle([mx + 10, my + 10, mx + mw + 10, my + mh + 10], radius=32, fill=BLACK)
        draw.rounded_rectangle([mx, my, mx + mw, my + mh], radius=32, fill=YELLOW, outline=BLACK, width=6)

        if app_icon_img:
            isize = 200
            ix = mx + 80
            iy = my + 80
            draw_card(draw, [ix - 6, iy - 6, ix + isize + 6, iy + isize + 6], fill=WHITE, border_w=3.5, radius=24, shadow_offset=(5,5))
            ricon = app_icon_img.resize((isize, isize), Image.BILINEAR)
            frame.paste(ricon, (ix, iy))

        draw.text((mx + 330, my + 90), "NEXTCLASS ↗", fill=BLACK, font=get_font(72))
        draw.text((mx + 330, my + 190), "YOUR SEMESTER, SORTED.", fill=BLACK, font=get_font(42))
        draw.text((mx + 330, my + 250), "Never miss what's next. Timetable, rooms & quiz countdowns.", fill=(60,60,60), font=get_font(28))

        # Big CTA
        cta_rect = [mx + 80, my + 380, mx + mw - 80, my + 520]
        draw_card(draw, cta_rect, fill=BLACK, border_w=4, radius=22, shadow_offset=(6,6))
        f_cta = get_font(46)
        cta_txt = "FREE ON ANDROID • DOWNLOAD TODAY ↗"
        bbox = f_cta.getbbox(cta_txt)
        draw.text((cta_rect[0] + (cta_rect[2] - cta_rect[0] - (bbox[2]-bbox[0]))//2, cta_rect[1] + (cta_rect[3] - cta_rect[1] - (bbox[3]-bbox[1]))//2 - bbox[1]), cta_txt, fill=YELLOW, font=f_cta)

        draw.text((mx + 80, my + 560), "NC100 / REL 01 • 100% OFFLINE • NO SIGNUPS REQUIRED", fill=BLACK, font=get_font(22))


def generate_video():
    print(f"🎬 Starting NextClass 16:9 Landscape Video Production...")
    print(f"Resolution: {WIDTH}x{HEIGHT} @ {FPS}fps, Duration: {DURATION_SEC}s ({TOTAL_FRAMES} frames)")
    print(f"Target Output: {OUTPUT_VIDEO_PATH}")

    generate_audio.create_soundtrack(DURATION_SEC, output_wav=AUDIO_FILE)

    ffmpeg_cmd = [
        FFMPEG_EXE, "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{WIDTH}x{HEIGHT}",
        "-pix_fmt", "rgb24",
        "-r", str(FPS),
        "-i", "-",
        "-i", AUDIO_FILE,
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        OUTPUT_VIDEO_PATH
    ]

    proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    for frame_idx in range(TOTAL_FRAMES):
        t = frame_idx / FPS
        frame = Image.new("RGB", (WIDTH, HEIGHT), color=BG_COLOR)
        draw = ImageDraw.Draw(frame)

        if t < 4.5:
            render_scene_1(t, draw, frame)
        elif t < 9.5:
            render_scene_2(t, draw, frame)
        elif t < 16.0:
            render_scene_3(t, draw, frame)
        elif t < 21.5:
            render_scene_4(t, draw, frame)
        elif t < 26.5:
            render_scene_5(t, draw, frame)
        else:
            render_scene_6(t, draw, frame)

        proc.stdin.write(frame.tobytes())

        if frame_idx % 60 == 0 or frame_idx == TOTAL_FRAMES - 1:
            pct = (frame_idx + 1) / TOTAL_FRAMES * 100
            print(f"Frame {frame_idx + 1}/{TOTAL_FRAMES} ({pct:.1f}%) | Time: {t:.2f}s")

    proc.stdin.close()
    proc.wait()

    print(f"✅ 16:9 Video generated successfully: {OUTPUT_VIDEO_PATH}")
    if os.path.exists(OUTPUT_VIDEO_PATH):
        import shutil
        shutil.copyfile(OUTPUT_VIDEO_PATH, OUTPUT_VIDEO_ALT)


if __name__ == "__main__":
    generate_video()
