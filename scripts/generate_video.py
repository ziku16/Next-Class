#!/usr/bin/env python3
"""
NextClass Master Video Generation Script
Renders the complete 30-second 9:16 vertical promo video for NextClass
according to video.md specifications and combines it with the synthesized soundtrack.
"""

import os
import sys
import math
import subprocess
from PIL import Image, ImageDraw, ImageFont

# Add current scripts directory to path
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.insert(0, SCRIPT_DIR)

import generate_audio
from video_renderer import (
    WIDTH, HEIGHT, FPS, DURATION_SEC, TOTAL_FRAMES,
    BG_COLOR, BLACK, WHITE, YELLOW, ORANGE, GREEN, RED, CYAN,
    PALE_YELLOW, PALE_ORANGE, TICKET_GREY, DARK_BG,
    get_font, draw_card, draw_badge, draw_brand_sticker,
    draw_starburst, draw_hatching_progress_bar, draw_phone_chassis,
    draw_kinetic_banner, draw_circle, crumpled_img, scan_img, app_icon_img
)

# Output Paths
AUDIO_FILE = "/tmp/nextclass_soundtrack.wav"
OUTPUT_VIDEO_PATH = os.path.join(BASE_DIR, "NextClass_Promo_9x16.mp4")
OUTPUT_VIDEO_ALT = os.path.join(BASE_DIR, "nextclass_promo.mp4")

FFMPEG_EXE = "/home/zaki/.local/lib/python3.12/site-packages/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2"
if not os.path.exists(FFMPEG_EXE):
    FFMPEG_EXE = "ffmpeg"


def render_scene_1(frame_idx, t, draw, frame):
    """0.0s - 4.5s: Problem (Crumpled Timetable) -> Brand Reveal"""
    # 0.0 to 2.5: Crumpled paper shot with stamp
    if t < 2.5:
        # Scale/zoom effect
        zoom = 1.0 + 0.08 * (t / 2.5)
        zw = int(WIDTH * zoom)
        zh = int(HEIGHT * zoom)
        
        # Shake effect on stamp hit (t >= 1.5)
        shake_x, shake_y = 0, 0
        if 1.5 <= t < 1.9:
            st = (t - 1.5) / 0.4
            shake_amp = 18.0 * math.exp(-st * 6.0)
            shake_x = int(math.sin(st * 40.0) * shake_amp)
            shake_y = int(math.cos(st * 35.0) * shake_amp)
        
        if crumpled_img:
            # Crop center and resize
            cw, ch = crumpled_img.size
            crop_size = min(cw, ch)
            cropped = crumpled_img.crop(((cw - crop_size)//2, (ch - crop_size)//2, (cw + crop_size)//2, (ch + crop_size)//2))
            resized = cropped.resize((zw, zh), Image.BILINEAR)
            
            # Paste with shake offset
            ox = (WIDTH - zw) // 2 + shake_x
            oy = (HEIGHT - zh) // 2 + shake_y
            frame.paste(resized, (ox, oy))
        else:
            draw.rectangle([0, 0, WIDTH, HEIGHT], fill=(230, 225, 215))

        # Dark overlay
        overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 50))
        frame.paste(overlay, (0, 0), overlay)

        # Kinetic Banner
        draw_kinetic_banner(draw, "POV: STILL USING BLURRY TIMETABLES? 💀", 1680, fill_col=YELLOW)

        # Stamp slams down at t >= 1.4s
        if t >= 1.4:
            st = (t - 1.4) / 0.3
            scale = 1.0
            if st < 1.0:
                # Overshoot: 1.35x -> 0.95x -> 1.0x
                scale = 1.0 + 0.35 * math.sin((1.0 - st) * math.pi)
            
            stamp_w = int(820 * scale)
            stamp_h = int(140 * scale)
            sx = (WIDTH - stamp_w) // 2 + shake_x
            sy = (HEIGHT - stamp_h) // 2 - 100 + shake_y

            # Shadow
            draw.rounded_rectangle([sx + 8, sy + 8, sx + stamp_w + 8, sy + stamp_h + 8], radius=16, fill=BLACK)
            # Stamp Box
            draw.rounded_rectangle([sx, sy, sx + stamp_w, sy + stamp_h], radius=16, fill=YELLOW, outline=BLACK, width=5)
            
            f_stamp = get_font(int(36 * scale))
            stext = "STILL ZOOMING INTO SCREENSHOTS? ✕"
            sbox = f_stamp.getbbox(stext)
            tx = sx + (stamp_w - (sbox[2] - sbox[0])) // 2
            ty = sy + (stamp_h - (sbox[3] - sbox[1])) // 2 - sbox[1]
            draw.text((tx, ty), stext, fill=BLACK, font=f_stamp)

    # 2.5 to 4.5: Wipe to Welcome Screen Phone
    else:
        # Background
        draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
        
        # Phone emergence with spring bounce
        pt = min(1.0, (t - 2.5) / 0.5)
        # Spring curve
        phone_y_offset = int((1.0 - math.sin(pt * math.pi * 0.5)) * 400)
        
        pw = 860
        ph = 1520
        px = (WIDTH - pw) // 2
        py = 180 + phone_y_offset

        draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

        # Inside Phone - Welcome Screen
        # Slanted Sticker
        sticker_img = draw_brand_sticker(draw, px + 50, py + 120, scale=1.3, angle_deg=-3.0)
        frame.paste(sticker_img, (px + 50, py + 120), sticker_img)

        # Headline
        f_hero = get_font(52)
        draw.text((px + 50, py + 230), "Your semester,\nsorted.", fill=BLACK, font=f_hero, spacing=10)
        
        f_sub = get_font(26)
        draw.text((px + 50, py + 380), "Never miss what's next.", fill=(80, 80, 80), font=f_sub)

        # Feature pills
        draw_badge(draw, "[ 1-PHOTO IMPORT ]", px + 50, py + 450, bg_color=YELLOW, font_size=20, pad_x=16, pad_y=10)
        draw_badge(draw, "[ 100% OFFLINE ]", px + 330, py + 450, bg_color=TICKET_GREY, font_size=20, pad_x=16, pad_y=10)
        draw_badge(draw, "[ NO ACCOUNTS ]", px + 50, py + 520, bg_color=TICKET_GREY, font_size=20, pad_x=16, pad_y=10)
        draw_badge(draw, "[ ZERO ADS ]", px + 280, py + 520, bg_color=GREEN, font_size=20, pad_x=16, pad_y=10)

        # Big App Icon Card in center
        if app_icon_img:
            icon_size = 280
            ix = px + (pw - icon_size) // 2
            iy = py + 620
            # Card frame for icon
            draw_card(draw, [ix - 10, iy - 10, ix + icon_size + 10, iy + icon_size + 10], fill=WHITE, border_w=4, radius=32)
            resized_icon = app_icon_img.resize((icon_size, icon_size), Image.BILINEAR)
            frame.paste(resized_icon, (ix, iy))

        # Industrial Code
        f_code = get_font(18)
        draw.text((px + 50, py + 1040), "NC100 / REL 01 • READY", fill=(120, 120, 120), font=f_code)

        # Button Compression Physics at t >= 3.6s
        btn_pressed = (t >= 3.6)
        btn_ox = 0 if btn_pressed else 6
        btn_oy = 0 if btn_pressed else 6
        btn_rect = [px + 50 + btn_ox, py + 1120 + btn_oy, px + pw - 50 + btn_ox, py + 1240 + btn_oy]
        
        # Draw CTA button
        draw_card(draw, btn_rect, fill=ORANGE, border_w=4, shadow_offset=(0,0) if btn_pressed else (6,6), radius=16)
        f_btn = get_font(34)
        btn_text = "Upload timetable ↗"
        bbox = f_btn.getbbox(btn_text)
        bw = bbox[2] - bbox[0]
        bh = bbox[3] - bbox[1]
        draw.text((btn_rect[0] + (btn_rect[2] - btn_rect[0] - bw)//2, btn_rect[1] + (btn_rect[3] - btn_rect[1] - bh)//2 - bbox[1]), btn_text, fill=WHITE, font=f_btn)

        # Animated pointer cursor approaching button
        if 3.2 <= t < 4.2:
            cur_t = min(1.0, (t - 3.2) / 0.4)
            cx = int(px + pw//2 + (1.0 - cur_t) * 100)
            cy = int(py + 1180 + (1.0 - cur_t) * 120)
            draw.polygon([(cx, cy), (cx + 28, cy + 38), (cx + 12, cy + 38), (cx + 8, cy + 54), (cx - 2, cy + 50), (cx + 4, cy + 34), (cx - 6, cy + 34)], fill=BLACK, outline=WHITE)

        # Kinetic Banner
        draw_kinetic_banner(draw, "MEET NEXTCLASS ↗ • YOUR SEMESTER SORTED", 1760, fill_col=YELLOW)


def render_scene_2(frame_idx, t, draw, frame):
    """4.5s - 9.5s: 1 Photo Import -> Brutalist AI Parsing -> Timetable Review"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    
    pw = 860
    ph = 1520
    px = (WIDTH - pw) // 2
    py = 180

    # 4.5 to 6.2s: Camera Scan Mode
    if t < 6.2:
        draw_phone_chassis(draw, px, py, pw, ph, bg_fill=(30, 30, 30), is_dark=True)
        
        # Camera header
        draw_badge(draw, "[ TIMETABLE SCANNER ]", px + 50, py + 90, bg_color=YELLOW, font_size=20)
        
        # Viewfinder box
        vx0, vy0, vx1, vy1 = px + 40, py + 160, px + pw - 40, py + 1200
        draw.rectangle([vx0, vy0, vx1, vy1], outline=WHITE, width=3)
        
        # Paste scan image inside viewfinder
        if scan_img:
            vw = vx1 - vx0
            vh = vy1 - vy0
            # Center crop and fit
            sw, sh = scan_img.size
            crop_img = scan_img.resize((vw, vh), Image.BILINEAR)
            frame.paste(crop_img, (vx0, vy0))
            
            # Semi-transparent dark tint on outer edges
            overlay = Image.new("RGBA", (vw, vh), (0, 0, 0, 40))
            frame.paste(overlay, (vx0, vy0), overlay)

        # Brutalist corner brackets
        bracket_len = 45
        for bx, by, dx, dy in [(vx0, vy0, 1, 1), (vx1, vy0, -1, 1), (vx0, vy1, 1, -1), (vx1, vy1, -1, -1)]:
            draw.line([(bx, by), (bx + dx * bracket_len, by)], fill=YELLOW, width=6)
            draw.line([(bx, by), (bx, by + dy * bracket_len)], fill=YELLOW, width=6)

        # Scanning Laser Line sweeping vertically
        scan_progress = ((t - 4.5) / 1.5) % 1.0
        laser_y = int(vy0 + scan_progress * (vy1 - vy0))
        draw.line([(vx0, laser_y), (vx1, laser_y)], fill=YELLOW, width=5)
        # Laser glow line
        draw.line([(vx0, laser_y - 2), (vx1, laser_y - 2)], fill=ORANGE, width=2)
        draw.line([(vx0, laser_y + 2), (vx1, laser_y + 2)], fill=ORANGE, width=2)

        # Detected class tags floating
        if t > 5.0:
            draw_badge(draw, "MATHEMATICS DETECTED", vx0 + 40, vy0 + 60, bg_color=GREEN, font_size=18)
        if t > 5.4:
            draw_badge(draw, "PHYSICS DETECTED", vx0 + 40, vy0 + 130, bg_color=YELLOW, font_size=18)
        if t > 5.8:
            draw_badge(draw, "CHEMISTRY LAB DETECTED", vx0 + 40, vy0 + 200, bg_color=ORANGE, text_color=WHITE, font_size=18)

        # Shutter button at bottom
        shutter_cy = py + 1340
        draw_circle(draw, (px + pw//2, shutter_cy), 45, fill=WHITE, outline=BLACK, width=4)
        draw_circle(draw, (px + pw//2, shutter_cy), 35, fill=YELLOW)

        # Shutter flash at 5.5s
        if 5.5 <= t < 5.7:
            flash_alpha = int(255 * (1.0 - (t - 5.5)/0.2))
            flash_layer = Image.new("RGBA", (WIDTH, HEIGHT), (255, 255, 255, flash_alpha))
            frame.paste(flash_layer, (0, 0), flash_layer)

        draw_kinetic_banner(draw, "SNAP ONE PHOTO OF YOUR TIMETABLE", 1760, fill_col=YELLOW)

    # 6.2 to 7.6s: Brutalist Parsing Loader Screen
    elif t < 7.6:
        draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

        # Industrial Code Stamp
        f_code = get_font(20)
        draw.text((px + 50, py + 120), "TT2026 / SYNC 01 • PARSER", fill=(140, 140, 140), font=f_code)

        # Spinning Starburst Badge
        star_angle = (t - 6.2) * 240.0 # Fast rotation
        draw_starburst(draw, px + pw//2, py + 480, r_outer=130, r_inner=85, num_points=12, angle_deg=star_angle, fill=YELLOW)

        # Starburst center badge
        draw_circle(draw, (px + pw//2, py + 480), 55, fill=BLACK)
        f_ai = get_font(28)
        draw.text((px + pw//2 - 38, py + 480 - 18), "AI SYNC", fill=YELLOW, font=f_ai)

        # Heading
        f_head = get_font(42)
        draw.text((px + 70, py + 720), "Analyzing your timetable...", fill=BLACK, font=f_head)

        f_sub = get_font(24)
        draw.text((px + 70, py + 790), "Extracting class names, rooms & professors", fill=(90, 90, 90), font=f_sub)

        # Animated progress dots
        prog_w = int((t - 6.2) / 1.4 * 600)
        draw.rounded_rectangle([px + 70, py + 860, px + 70 + 600, py + 880], radius=10, fill=(230, 230, 230), outline=BLACK, width=2)
        draw.rounded_rectangle([px + 70, py + 860, px + 70 + prog_w, py + 880], radius=10, fill=GREEN, outline=BLACK, width=2)

        draw_kinetic_banner(draw, "INSTANT AI PARSING • ZERO MANUAL TYPING", 1760, fill_col=YELLOW)

    # 7.6 to 9.5s: Review Screen with Cascading Cards
    else:
        draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

        # Review Header
        sticker_img = draw_brand_sticker(draw, px + 50, py + 90, scale=1.0, angle_deg=-2.0)
        frame.paste(sticker_img, (px + 50, py + 90), sticker_img)

        f_rev = get_font(36)
        draw.text((px + 50, py + 180), "Review Timetable", fill=BLACK, font=f_rev)
        draw_badge(draw, "3 CLASSES FOUND", px + 440, py + 182, bg_color=GREEN, font_size=18)

        # Cascading cards
        cards_data = [
            ("Mathematics", "08:30 – 09:20", "Room A-04", "Dr. Smith", TICKET_GREY, 7.6),
            ("Physics", "09:30 – 10:20", "Room B-12", "Prof. Miller", PALE_YELLOW, 7.9),
            ("Chemistry Lab", "11:00 – 12:40", "Lab 2", "Ms. Sara", PALE_ORANGE, 8.2),
        ]

        card_y = py + 260
        for subj, time_str, room, prof, tint, start_t in cards_data:
            if t >= start_t:
                # Slide in from right with overshoot
                ct = min(1.0, (t - start_t) / 0.3)
                slide_x = int((1.0 - math.sin(ct * math.pi * 0.5)) * 300)
                
                cx0 = px + 40 + slide_x
                cx1 = px + pw - 40 + slide_x
                cy0 = card_y
                cy1 = card_y + 190

                draw_card(draw, [cx0, cy0, cx1, cy1], fill=tint, border_w=3.5, radius=16)

                # Card content
                f_s = get_font(32)
                draw.text((cx0 + 26, cy0 + 22), subj, fill=BLACK, font=f_s)

                f_t = get_font(22)
                draw.text((cx0 + 26, cy0 + 72), time_str, fill=(70, 70, 70), font=f_t)

                # Room & Prof pills
                draw_badge(draw, room, cx0 + 26, cy0 + 120, bg_color=WHITE, font_size=18, pad_x=12, pad_y=4)
                draw_badge(draw, prof, cx0 + 200, cy0 + 120, bg_color=WHITE, font_size=18, pad_x=12, pad_y=4)

            card_y += 220

        # Orange CTA button: Looks good, let's go! ↗
        btn_pressed = (t >= 9.0)
        btn_ox = 0 if btn_pressed else 6
        btn_oy = 0 if btn_pressed else 6
        b_rect = [px + 40 + btn_ox, py + 1240 + btn_oy, px + pw - 40 + btn_ox, py + 1360 + btn_oy]
        draw_card(draw, b_rect, fill=ORANGE, border_w=4, shadow_offset=(0,0) if btn_pressed else (6,6), radius=16)
        
        f_btn = get_font(32)
        btxt = "Looks good, let's go! ↗"
        bbox = f_btn.getbbox(btxt)
        draw.text((b_rect[0] + (b_rect[2] - b_rect[0] - (bbox[2]-bbox[0]))//2, b_rect[1] + (b_rect[3] - b_rect[1] - (bbox[3]-bbox[1]))//2 - bbox[1]), btxt, fill=WHITE, font=f_btn)

        draw_kinetic_banner(draw, "1 PHOTO -> YOUR WHOLE SEMESTER", 1760, fill_col=YELLOW)


def render_scene_3(frame_idx, t, draw, frame):
    """9.5s - 16.0s: Today Screen Command Center & Live Progress Bar"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    
    pw = 860
    ph = 1520
    px = (WIDTH - pw) // 2
    py = 180

    draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

    # 1. Official Slanted Sticker
    sticker_img = draw_brand_sticker(draw, px + 40, py + 90, scale=1.05, angle_deg=-2.5)
    frame.paste(sticker_img, (px + 40, py + 90), sticker_img)

    # 2. Greeting & Date
    f_greet = get_font(44)
    draw.text((px + 40, py + 175), "Good morning, Ali", fill=BLACK, font=f_greet)

    # Date Pill & Class Count Pill
    draw_badge(draw, "Friday, 2 October", px + 40, py + 240, bg_color=BLACK, text_color=WHITE, font_size=18, radius=20)
    draw_badge(draw, "3 CLASSES TODAY", px + 245, py + 240, bg_color=WHITE, font_size=18, radius=20)

    # Dynamic agenda summary pill
    draw_card(draw, [px + 40, py + 300, px + pw - 40, py + 355], fill=PALE_YELLOW, border_w=2.5, radius=12, shadow_offset=(3,3))
    f_sum = get_font(19)
    draw.text((px + 60, py + 316), "3 classes today · next at 08:30", fill=BLACK, font=f_sum)

    # Industrial code stamp
    f_code = get_font(15)
    draw.text((px + pw - 220, py + 100), "OCT0221 / CLASSIFY", fill=(140, 140, 140), font=f_code)

    # 3. Active Class Card: Physics (09:30 – 10:20) in Pale Yellow #FFF9C4
    c1_rect = [px + 40, py + 380, px + pw - 40, py + 710]
    draw_card(draw, c1_rect, fill=PALE_YELLOW, border_w=4, radius=20, shadow_offset=(6,6))

    # Pulsating Red Live Dot
    pulse = 1.0 + 0.3 * math.sin((t - 9.5) * 8.0)
    dot_r = int(9 * pulse)
    draw_circle(draw, (px + 72, py + 418), dot_r, fill=RED)
    
    # "Now" Badge
    draw_badge(draw, "NOW", px + 95, py + 402, bg_color=YELLOW, font_size=16, pad_x=10, pad_y=3, shadow=False)
    
    # Time tag
    f_time = get_font(22)
    draw.text((px + pw - 230, py + 405), "09:30 – 10:20", fill=(50, 50, 50), font=f_time)

    # Title: Physics
    f_subj = get_font(44)
    draw.text((px + 68, py + 450), "Physics", fill=BLACK, font=f_subj)

    # Tags: Room B-12 and Prof. Miller
    draw_badge(draw, "Room B-12", px + 68, py + 520, bg_color=WHITE, font_size=20, pad_x=14, pad_y=6)
    draw_badge(draw, "Prof. Miller", px + 250, py + 520, bg_color=WHITE, font_size=20, pad_x=14, pad_y=6)

    # Live Hatching Progress Bar filling up smoothly!
    # Progress starts at 45% at 9.5s and fills to 80% at 16.0s
    prog = 0.45 + (t - 9.5) / (16.0 - 9.5) * 0.35
    prog_rect = [px + 68, py + 610, px + pw - 68, py + 645]
    draw_hatching_progress_bar(draw, prog_rect, prog, anim_t=t)
    
    # Progress text
    f_prog = get_font(18)
    draw.text((px + 70, py + 660), f"{int(prog*100)}% complete · 18 min remaining", fill=(70, 70, 70), font=f_prog)

    # 4. Upcoming Class Card: Chemistry Lab (11:00 – 12:40) in Pale Orange #FFE0B2
    c2_rect = [px + 40, py + 740, px + pw - 40, py + 960]
    draw_card(draw, c2_rect, fill=PALE_ORANGE, border_w=3.5, radius=18, shadow_offset=(5,5))
    
    draw_badge(draw, "IN 25 MIN", px + 68, py + 760, bg_color=ORANGE, text_color=WHITE, font_size=16, pad_x=10, pad_y=4)
    draw.text((px + pw - 230, py + 762), "11:00 – 12:40", fill=(50, 50, 50), font=f_time)

    draw.text((px + 68, py + 805), "Chemistry Lab", fill=BLACK, font=get_font(36))
    draw_badge(draw, "Lab 2", px + 68, py + 870, bg_color=WHITE, font_size=18, pad_x=12, pad_y=5)
    draw_badge(draw, "Ms. Sara", px + 170, py + 870, bg_color=WHITE, font_size=18, pad_x=12, pad_y=5)

    # 5. Completed Class Card: Mathematics (08:30 – 09:20)
    c3_rect = [px + 40, py + 990, px + pw - 40, py + 1170]
    draw_card(draw, c3_rect, fill=TICKET_GREY, border_w=3.0, radius=16, shadow_offset=(4,4))
    draw_badge(draw, "DONE", px + 68, py + 1005, bg_color=BLACK, text_color=WHITE, font_size=15, pad_x=8, pad_y=3)
    draw.text((px + pw - 230, py + 1007), "08:30 – 09:20", fill=(90, 90, 90), font=f_time)
    draw.text((px + 68, py + 1045), "Mathematics", fill=(70, 70, 70), font=get_font(30))
    draw_badge(draw, "Room A-04", px + 68, py + 1095, bg_color=WHITE, font_size=16, pad_x=10, pad_y=4)
    draw_badge(draw, "Dr. Smith", px + 220, py + 1095, bg_color=WHITE, font_size=16, pad_x=10, pad_y=4)

    # Bottom Brutalist Nav Bar
    nav_rect = [px + 20, py + 1340, px + pw - 20, py + 1440]
    draw_card(draw, nav_rect, fill=WHITE, border_w=3.5, radius=24, shadow_offset=(4,4))
    
    # 4 Tabs: Today, Week, Quizzes, Settings
    tab_w = (pw - 40) // 4
    # Today active
    draw.rounded_rectangle([px + 30, py + 1350, px + 30 + tab_w - 20, py + 1430], radius=14, fill=YELLOW, outline=BLACK, width=2)
    draw.text((px + 52, py + 1378), "TODAY", fill=BLACK, font=get_font(18))
    draw.text((px + 30 + tab_w + 30, py + 1378), "WEEK", fill=(100, 100, 100), font=get_font(18))
    draw.text((px + 30 + tab_w*2 + 20, py + 1378), "QUIZZES", fill=(100, 100, 100), font=get_font(18))
    draw.text((px + 30 + tab_w*3 + 15, py + 1378), "SETTINGS", fill=(100, 100, 100), font=get_font(18))

    draw_kinetic_banner(draw, "LIVE PROGRESS • PHYSICS IN ROOM B-12", 1760, fill_col=YELLOW)


def render_scene_4(frame_idx, t, draw, frame):
    """16.0s - 21.5s: Pre-Class Nudges on Dark Always-On Display Lock Screen"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    
    pw = 860
    ph = 1520
    px = (WIDTH - pw) // 2
    py = 180

    # Phone in Dark Mode
    draw_phone_chassis(draw, px, py, pw, ph, bg_fill=DARK_BG, is_dark=True)

    # Large Lock Screen Clock: 09:15
    f_clk = get_font(110)
    draw.text((px + (pw - 310)//2, py + 220), "09:15", fill=WHITE, font=f_clk)

    f_date = get_font(26)
    draw.text((px + (pw - 230)//2, py + 360), "Friday, 2 October", fill=(180, 180, 180), font=f_date)

    # Notification drop animation (t >= 16.5s)
    if t >= 16.5:
        nt = min(1.0, (t - 16.5) / 0.5)
        # Spring overshoot curve
        ny_offset = -300 * (1.0 - math.sin(nt * math.pi * 0.5))
        if nt < 1.0:
            ny_offset += 25.0 * math.sin((1.0 - nt) * math.pi * 2.0)

        notif_x = px + 40
        notif_y = py + 480 + int(ny_offset)
        notif_w = pw - 80
        notif_h = 320

        # Brutalist Notification Banner in off-white
        draw_card(draw, [notif_x, notif_y, notif_x + notif_w, notif_y + notif_h], fill=WHITE, border_w=4, radius=22, shadow_offset=(7, 7))

        # Header Badge
        draw_badge(draw, "NEXTCLASS • 15 MIN BEFORE", notif_x + 24, notif_y + 24, bg_color=YELLOW, font_size=18, pad_x=12, pad_y=5)
        draw.text((notif_x + notif_w - 90, notif_y + 28), "Now", fill=(100, 100, 100), font=get_font(18))

        # Title: Physics in 15 min
        f_ntitle = get_font(42)
        draw.text((notif_x + 24, notif_y + 88), "Physics in 15 min", fill=BLACK, font=f_ntitle)

        # Subtitle: Room B-12 · Prof. Miller
        f_nsub = get_font(28)
        draw.text((notif_x + 24, notif_y + 155), "Room B-12  •  Prof. Miller", fill=BLACK, font=f_nsub)

        # Body row
        f_nbody = get_font(22)
        draw.text((notif_x + 24, notif_y + 215), "Scheduled: 09:30 – 10:20  •  Don't be late!", fill=(80, 80, 80), font=f_nbody)

        # Action tag
        draw_badge(draw, "OPEN IN NEXTCLASS ↗", notif_x + 24, notif_y + 260, bg_color=ORANGE, text_color=WHITE, font_size=16, pad_x=12, pad_y=4, shadow=False)

        # Tap animation at t >= 18.8s
        if 18.8 <= t < 20.2:
            tap_t = (t - 18.8) / 1.4
            ripple_r = int(tap_t * 90)
            ripple_alpha = int(255 * (1.0 - tap_t))
            # Ripple circle
            draw_circle(draw, (notif_x + notif_w//2, notif_y + 160), ripple_r, outline=ORANGE, width=3)
            # Pointer finger icon
            draw.polygon([(notif_x + notif_w//2, notif_y + 160), (notif_x + notif_w//2 + 25, notif_y + 195), (notif_x + notif_w//2 + 10, notif_y + 195), (notif_x + notif_w//2 + 6, cy:=notif_y + 210), (notif_x + notif_w//2 - 2, notif_y + 206), (notif_x + notif_w//2 + 4, notif_y + 192), (notif_x + notif_w//2 - 6, notif_y + 192)], fill=WHITE, outline=BLACK)

    draw_kinetic_banner(draw, "NUDGES YOU 15 MIN BEFORE CLASS", 1760, fill_col=YELLOW)


def render_scene_5(frame_idx, t, draw, frame):
    """21.5s - 26.5s: Quizzes & Night-Before Alerts Screen"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)
    
    pw = 860
    ph = 1520
    px = (WIDTH - pw) // 2
    py = 180

    draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE)

    # Header
    sticker_img = draw_brand_sticker(draw, px + 40, py + 90, scale=1.0, angle_deg=-2.0)
    frame.paste(sticker_img, (px + 40, py + 90), sticker_img)

    f_qtitle = get_font(40)
    draw.text((px + 40, py + 175), "Quizzes & Tests", fill=BLACK, font=f_qtitle)

    # Card 1: Urgent Quiz (Physics • Thermodynamics Quiz)
    qc1_rect = [px + 40, py + 250, px + pw - 40, py + 540]
    draw_card(draw, qc1_rect, fill=WHITE, border_w=4, radius=20, shadow_offset=(6,6))

    # Urgent Orange Badge
    draw_badge(draw, "TODAY • 09:30 AM", px + 68, py + 276, bg_color=ORANGE, text_color=WHITE, font_size=18, pad_x=12, pad_y=5)
    draw_badge(draw, "STARTS IN 15 MIN", px + 300, py + 276, bg_color=YELLOW, font_size=16, pad_x=10, pad_y=5)

    f_qname = get_font(34)
    draw.text((px + 68, py + 340), "Physics • Thermodynamics Quiz", fill=BLACK, font=f_qname)

    f_qdet = get_font(22)
    draw.text((px + 68, py + 410), "Room B-12  •  Prof. Miller", fill=(70, 70, 70), font=f_qdet)
    draw_badge(draw, "Formula sheet allowed", px + 68, py + 460, bg_color=PALE_YELLOW, font_size=16, pad_x=10, pad_y=4)

    # Card 2: Upcoming Quiz (Chemistry • Ch. 4–5 Lab Quiz)
    qc2_rect = [px + 40, py + 570, px + pw - 40, py + 840]
    draw_card(draw, qc2_rect, fill=WHITE, border_w=3.5, radius=18, shadow_offset=(5,5))

    draw_badge(draw, "TOMORROW • 11:00 AM", px + 68, py + 596, bg_color=YELLOW, font_size=17, pad_x=12, pad_y=5)
    draw.text((px + 68, py + 655), "Chemistry • Ch. 4–5 Lab Quiz", fill=BLACK, font=f_qname)
    draw.text((px + 68, py + 720), "Lab 2  •  Ms. Sara", fill=(70, 70, 70), font=f_qdet)
    draw_badge(draw, "Bring calculator & logbook", px + 68, py + 765, bg_color=TICKET_GREY, font_size=16, pad_x=10, pad_y=4)

    # Bottom Sheet: Quiz Reminder Timing (slides up at t >= 22.8s)
    if t >= 22.8:
        st = min(1.0, (t - 22.8) / 0.4)
        sheet_h = 520
        bottom_y = py + ph - 20
        sheet_top = bottom_y - max(40, int(sheet_h * math.sin(st * math.pi * 0.5)))
        
        # Bottom sheet card with heavy border
        draw_card(draw, [px + 10, sheet_top, px + pw - 10, bottom_y], fill=WHITE, border_w=4, radius=28, shadow_offset=(0,0))

        if st >= 0.3:
            # Handle bar
            draw.rounded_rectangle([px + pw//2 - 40, sheet_top + 16, px + pw//2 + 40, sheet_top + 24], radius=4, fill=BLACK)

            f_shhead = get_font(32)
            draw.text((px + 50, sheet_top + 50), "Add Quiz Reminder", fill=BLACK, font=f_shhead)

            f_shsub = get_font(20)
            draw.text((px + 50, sheet_top + 100), "When should NextClass nudge you?", fill=(100, 100, 100), font=f_shsub)

            # Brutalist Segmented Button
            seg_y = sheet_top + 150
            draw.rounded_rectangle([px + 50, seg_y, px + pw - 50, seg_y + 80], radius=14, fill=TICKET_GREY, outline=BLACK, width=3)
            
            # Toggle snaps to "Night before" at t >= 23.8s
            active_night = (t >= 23.8)
            
            # Option 1: Morning of
            m_fill = WHITE if not active_night else TICKET_GREY
            draw.rounded_rectangle([px + 55, seg_y + 5, px + pw//2 - 5, seg_y + 75], radius=10, fill=m_fill, outline=BLACK if not active_night else TICKET_GREY, width=2)
            draw.text((px + 110, seg_y + 26), "Morning of", fill=BLACK, font=get_font(22))

            # Option 2: Night before (Active Yellow)
            n_fill = YELLOW if active_night else WHITE
            draw.rounded_rectangle([px + pw//2 + 5, seg_y + 5, px + pw - 55, seg_y + 75], radius=10, fill=n_fill, outline=BLACK, width=2)
            draw.text((px + pw//2 + 40, seg_y + 26), "Night before (8 PM)", fill=BLACK, font=get_font(21))

            # Confirmation badge
            if active_night:
                draw_badge(draw, "ALERTS YOU AT 8:00 PM BEFORE QUIZ", px + 50, sheet_top + 260, bg_color=GREEN, font_size=19, pad_x=16, pad_y=8)

            # Orange Save button
            draw_card(draw, [px + 50, sheet_top + 340, px + pw - 50, sheet_top + 430], fill=ORANGE, border_w=3.5, radius=14, shadow_offset=(4,4))
            draw.text((px + pw//2 - 80, sheet_top + 368), "Set Reminder ↗", fill=WHITE, font=get_font(26))


    draw_kinetic_banner(draw, "QUIZZES & EXAMS • NIGHT-BEFORE ALERTS", 1760, fill_col=YELLOW)


def render_scene_6(frame_idx, t, draw, frame):
    """26.5s - 30.0s: Outro Brand Slap & Brutalist Feature Badges"""
    draw.rectangle([0, 0, WIDTH, HEIGHT], fill=BG_COLOR)

    # Subtle paper texture grain dots
    # 3 Feature Badges Slam Down sequentially with heavy impacts:
    badges_info = [
        ("100% OFFLINE", 26.8, YELLOW, 380),
        ("NO ACCOUNTS REQUIRED", 27.5, ORANGE, 540),
        ("ZERO ADS • 100% PRIVATE", 28.2, GREEN, 700),
    ]

    for label, hit_t, col, by in badges_info:
        if t >= hit_t:
            st = min(1.0, (t - hit_t) / 0.25)
            scale = 1.0
            if st < 1.0:
                scale = 1.0 + 0.3 * math.sin((1.0 - st) * math.pi)
            
            bw = int(840 * scale)
            bh = int(120 * scale)
            bx = (WIDTH - bw) // 2
            
            # Shadow
            draw.rounded_rectangle([bx + 8, by + 8, bx + bw + 8, by + bh + 8], radius=20, fill=BLACK)
            # Box
            text_col = WHITE if col == ORANGE else BLACK
            draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=20, fill=col, outline=BLACK, width=4)
            
            f_b = get_font(int(36 * scale))
            bbox = f_b.getbbox(label)
            tx = bx + (bw - (bbox[2] - bbox[0])) // 2
            ty = by + (bh - (bbox[3] - bbox[1])) // 2 - bbox[1]
            draw.text((tx, ty), label, fill=text_col, font=f_b)

    # Master Centered Yellow Brand Card slams in at t >= 28.8s
    if t >= 28.8:
        st = min(1.0, (t - 28.8) / 0.3)
        scale = 1.0 + 0.2 * math.sin((1.0 - st) * math.pi)
        
        mw = int(920 * scale)
        mh = int(680 * scale)
        mx = (WIDTH - mw) // 2
        my = 940

        # Master Shadow
        draw.rounded_rectangle([mx + 12, my + 12, mx + mw + 12, my + mh + 12], radius=32, fill=BLACK)
        # Master Card
        draw.rounded_rectangle([mx, my, mx + mw, my + mh], radius=32, fill=YELLOW, outline=BLACK, width=6)

        # App Icon inside
        if app_icon_img:
            isize = int(140 * scale)
            ix = mx + 60
            iy = my + 60
            draw_card(draw, [ix - 6, iy - 6, ix + isize + 6, iy + isize + 6], fill=WHITE, border_w=3, radius=24, shadow_offset=(4,4))
            ricon = app_icon_img.resize((isize, isize), Image.BILINEAR)
            frame.paste(ricon, (ix, iy))

        # Brand Text: NEXTCLASS ↗
        f_mbrand = get_font(int(58 * scale))
        draw.text((mx + 230, my + 80), "NEXTCLASS ↗", fill=BLACK, font=f_mbrand)

        f_mtag = get_font(int(34 * scale))
        draw.text((mx + 60, my + 250), "YOUR SEMESTER, SORTED.", fill=BLACK, font=f_mtag)

        f_msub = get_font(int(24 * scale))
        draw.text((mx + 60, my + 320), "Never miss what's next • v1.0.0", fill=(50, 50, 50), font=f_msub)

        # Big CTA pill inside master box
        cta_rect = [mx + 60, my + 410, mx + mw - 60, my + 540]
        draw_card(draw, cta_rect, fill=BLACK, border_w=3, radius=20, shadow_offset=(6,6))
        f_cta = get_font(int(36 * scale))
        cta_txt = "GET IT FREE ON ANDROID ↗"
        cbox = f_cta.getbbox(cta_txt)
        draw.text((cta_rect[0] + (cta_rect[2] - cta_rect[0] - (cbox[2]-cbox[0]))//2, cta_rect[1] + (cta_rect[3] - cta_rect[1] - (cbox[3]-cbox[1]))//2 - cbox[1]), cta_txt, fill=YELLOW, font=f_cta)

        # Screen code stamps
        f_mcode = get_font(18)
        draw.text((mx + 60, my + 600), "NC100 / REL 01 • PRODUCTION READY", fill=BLACK, font=f_mcode)

    draw_kinetic_banner(draw, "DOWNLOAD FREE ON ANDROID • NEXTCLASS", 1760, fill_col=YELLOW)


def generate_video():
    print(f"🎬 Starting NextClass Master Video Production...")
    print(f"Resolution: {WIDTH}x{HEIGHT} @ {FPS}fps, Duration: {DURATION_SEC}s ({TOTAL_FRAMES} frames)")
    print(f"Target Output: {OUTPUT_VIDEO_PATH}")

    # 1. Generate Synchronized Audio Track
    print(f"🎵 Synthesizing 128 BPM synchronized soundtrack & SFX...")
    generate_audio.create_soundtrack(DURATION_SEC, output_wav=AUDIO_FILE)

    # 2. Launch FFmpeg Process to stream raw frames
    ffmpeg_cmd = [
        FFMPEG_EXE, "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{WIDTH}x{HEIGHT}",
        "-pix_fmt", "rgb24",
        "-r", str(FPS),
        "-i", "-",                     # Pipe input for video
        "-i", AUDIO_FILE,              # Audio file
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        OUTPUT_VIDEO_PATH
    ]

    print(f"🚀 Launching FFmpeg encoder: {' '.join(ffmpeg_cmd)}")
    proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    # 3. Render frames in a loop
    for frame_idx in range(TOTAL_FRAMES):
        t = frame_idx / FPS
        
        frame = Image.new("RGB", (WIDTH, HEIGHT), color=BG_COLOR)
        draw = ImageDraw.Draw(frame)

        if t < 4.5:
            render_scene_1(frame_idx, t, draw, frame)
        elif t < 9.5:
            render_scene_2(frame_idx, t, draw, frame)
        elif t < 16.0:
            render_scene_3(frame_idx, t, draw, frame)
        elif t < 21.5:
            render_scene_4(frame_idx, t, draw, frame)
        elif t < 26.5:
            render_scene_5(frame_idx, t, draw, frame)
        else:
            render_scene_6(frame_idx, t, draw, frame)

        # Pipe raw bytes to FFmpeg
        proc.stdin.write(frame.tobytes())

        if frame_idx % 60 == 0 or frame_idx == TOTAL_FRAMES - 1:
            pct = (frame_idx + 1) / TOTAL_FRAMES * 100
            print(f"Frame {frame_idx + 1}/{TOTAL_FRAMES} ({pct:.1f}%) | Time: {t:.2f}s")

    proc.stdin.close()
    stderr_out = proc.stderr.read().decode('utf-8', errors='ignore')
    proc.wait()

    if proc.returncode != 0:
        print(f"❌ FFmpeg error: {stderr_out}")
        sys.exit(1)

    print(f"✅ Video generated successfully: {OUTPUT_VIDEO_PATH}")
    file_size_mb = os.path.getsize(OUTPUT_VIDEO_PATH) / (1024 * 1024)
    print(f"📦 File size: {file_size_mb:.2f} MB")

    # Create symlink/copy for convenient naming
    if os.path.exists(OUTPUT_VIDEO_PATH):
        try:
            import shutil
            shutil.copyfile(OUTPUT_VIDEO_PATH, OUTPUT_VIDEO_ALT)
            print(f"📁 Also saved as: {OUTPUT_VIDEO_ALT}")
        except Exception as e:
            print(f"Note on duplicate: {e}")

if __name__ == "__main__":
    generate_video()
