#!/usr/bin/env python3
"""
NextClass Video Generation Engine
Renders high-definition brutalist motion graphics video matching video.md specifications.
"""

import os
import sys
import math
import subprocess
from PIL import Image, ImageDraw, ImageFont

# Canvas dimensions
WIDTH = 1080
HEIGHT = 1920
FPS = 30
DURATION_SEC = 30.0
TOTAL_FRAMES = int(FPS * DURATION_SEC)

# Brutalist Color Tokens
BG_COLOR = (250, 246, 238)         # Warm off-white #FAF6EE
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 229, 0)             # Safety Yellow #FFE500
ORANGE = (255, 85, 0)              # Vivid Orange #FF5500
GREEN = (0, 230, 118)              # Electric Green #00E676
RED = (255, 23, 68)                # Vivid Red #FF1744
CYAN = (0, 229, 255)               # Electric Cyan #00E5FF
PALE_YELLOW = (255, 249, 196)      # #FFF9C4
PALE_ORANGE = (255, 224, 178)      # #FFE0B2
TICKET_GREY = (236, 239, 241)      # #ECEFF1
DARK_BG = (18, 18, 20)             # Always-On Display dark

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
FONT_PATH = os.path.join(ASSETS_DIR, "fonts", "SpaceGrotesk.ttf")
if not os.path.exists(FONT_PATH):
    FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

CRUMPLED_IMG_PATH = os.path.join(ASSETS_DIR, "crumpled_timetable.jpg")
SCAN_IMG_PATH = os.path.join(ASSETS_DIR, "printed_timetable_scan.jpg")
APP_ICON_PATH = os.path.join(BASE_DIR, "AppIcon.jpeg")

# Font cache
_font_cache = {}

def get_font(size, bold=True):
    key = (size, bold)
    if key not in _font_cache:
        try:
            _font_cache[key] = ImageFont.truetype(FONT_PATH, size)
        except Exception:
            _font_cache[key] = ImageFont.load_default()
    return _font_cache[key]

# Load and prepare images
crumpled_img = None
if os.path.exists(CRUMPLED_IMG_PATH):
    try:
        crumpled_img = Image.open(CRUMPLED_IMG_PATH).convert("RGB")
    except Exception as e:
        print(f"Warning: could not open crumpled image: {e}")

scan_img = None
if os.path.exists(SCAN_IMG_PATH):
    try:
        scan_img = Image.open(SCAN_IMG_PATH).convert("RGB")
    except Exception as e:
        print(f"Warning: could not open scan image: {e}")

app_icon_img = None
if os.path.exists(APP_ICON_PATH):
    try:
        app_icon_img = Image.open(APP_ICON_PATH).convert("RGB")
    except Exception as e:
        print(f"Warning: could not open app icon: {e}")

# Helper: Draw Brutalist Card
def draw_card(draw, rect, fill, border_color=BLACK, border_w=3.5, shadow_offset=(4.5, 4.5), radius=14):
    x0, y0, x1, y1 = rect
    if x1 <= x0 or y1 <= y0:
        return
    max_r = max(0, min((x1 - x0) // 2, (y1 - y0) // 2))
    r = min(radius, max_r)
    sx, sy = shadow_offset
    if sx > 0 or sy > 0:
        draw.rounded_rectangle([x0 + sx, y0 + sy, x1 + sx, y1 + sy], radius=r, fill=BLACK)
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=fill, outline=border_color, width=int(border_w))


# Helper: Draw Circle
def draw_circle(draw, center, radius, fill=None, outline=None, width=1):
    cx, cy = center
    r = radius
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=int(width))


# Helper: Draw Badge / Pill
def draw_badge(draw, text, x, y, bg_color=YELLOW, text_color=BLACK, font_size=18, pad_x=12, pad_y=6, shadow=True, border_w=2.5, radius=8):
    font = get_font(font_size)
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    w = tw + pad_x * 2
    h = th + pad_y * 2
    if shadow:
        draw.rounded_rectangle([x + 3.0, y + 3.0, x + w + 3.0, y + h + 3.0], radius=radius, fill=BLACK)
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=bg_color, outline=BLACK, width=int(border_w))
    draw.text((x + pad_x, y + pad_y - bbox[1]), text, fill=text_color, font=font)
    return w, h

# Helper: Draw Official Brand Sticker: NEXTCLASS ↗
def draw_brand_sticker(draw, x, y, scale=1.0, angle_deg=-2.5):
    font = get_font(int(26 * scale))
    text = "NEXTCLASS ↗"
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    pad_x = int(18 * scale)
    pad_y = int(10 * scale)
    w = tw + pad_x * 2
    h = th + pad_y * 2
    
    # We create a small RGBA buffer for clean rotation
    sticker = Image.new("RGBA", (w + 20, h + 20), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(sticker)
    
    # Shadow
    s_draw.rounded_rectangle([4, 4, w + 4, h + 4], radius=int(6 * scale), fill=(0, 0, 0, 255))
    # Main Box
    s_draw.rounded_rectangle([0, 0, w, h], radius=int(6 * scale), fill=(255, 229, 0, 255), outline=(0, 0, 0, 255), width=int(3.5 * scale))
    s_draw.text((pad_x, pad_y - bbox[1]), text, fill=(0, 0, 0, 255), font=font)
    
    # Rotate
    rotated = sticker.rotate(angle_deg, expand=True, resample=Image.BICUBIC)
    return rotated

# Helper: Starburst loader polygon
def draw_starburst(draw, cx, cy, r_outer, r_inner, num_points, angle_deg, fill=YELLOW, outline=BLACK, border_w=3):
    points = []
    angle_step = math.pi / num_points
    base_angle = math.radians(angle_deg)
    for i in range(num_points * 2):
        r = r_outer if i % 2 == 0 else r_inner
        a = base_angle + i * angle_step
        points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    
    # Shadow
    shadow_points = [(p[0] + 5, p[1] + 5) for p in points]
    draw.polygon(shadow_points, fill=BLACK)
    draw.polygon(points, fill=fill, outline=outline)

# Helper: Live Progress Bar with Green Hatching
def draw_hatching_progress_bar(draw, rect, progress, anim_t=0.0):
    x0, y0, x1, y1 = rect
    w = x1 - x0
    h = y1 - y0
    # Outer box
    draw.rounded_rectangle(rect, radius=h//2, fill=(240, 240, 240), outline=BLACK, width=2)
    
    # Fill progress
    fill_w = int(w * min(1.0, max(0.0, progress)))
    if fill_w > 4:
        fill_rect = [x0, y0, x0 + fill_w, y1]
        draw.rounded_rectangle(fill_rect, radius=h//2, fill=GREEN, outline=BLACK, width=2)
        
        # Diagonal hatching lines
        offset = int((anim_t * 60) % 16)
        for hx in range(int(x0) - 20 + offset, int(x0 + fill_w) + 10, 14):
            line_x0 = max(x0, hx)
            line_x1 = min(x0 + fill_w, hx + h)
            if line_x0 < line_x1:
                draw.line([(hx, y1), (hx + h, y0)], fill=BLACK, width=2)

# Helper: Phone Frame
def draw_phone_chassis(draw, px, py, pw, ph, bg_fill=WHITE, is_dark=False):
    # Hard shadow
    draw.rounded_rectangle([px + 10, py + 10, px + pw + 10, py + ph + 10], radius=52, fill=BLACK)
    # Chassis
    border_col = BLACK
    chassis_fill = (24, 24, 26) if is_dark else WHITE
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=52, fill=chassis_fill, outline=border_col, width=5)
    
    # Dynamic Island / Notch
    notch_w = 160
    notch_h = 32
    nx = px + (pw - notch_w) // 2
    ny = py + 18
    draw.rounded_rectangle([nx, ny, nx + notch_w, ny + notch_h], radius=16, fill=BLACK)
    
    # Status bar
    f_stat = get_font(18)
    time_col = WHITE if is_dark else BLACK
    draw.text((px + 50, py + 22), "09:41", fill=time_col, font=f_stat)
    draw.text((px + pw - 100, py + 22), "5G 100%", fill=time_col, font=f_stat)
    
    # Bottom home indicator
    hx = px + (pw - 200) // 2
    hy = py + ph - 24
    draw.rounded_rectangle([hx, hy, hx + 200, hy + 6], radius=3, fill=BLACK if not is_dark else (100, 100, 100))

# Kinetic Typography Banner at Bottom/Top
def draw_kinetic_banner(draw, text, y_pos=1760, fill_col=YELLOW, text_col=BLACK):
    font = get_font(30)
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    
    pad_x = 32
    pad_y = 16
    w = tw + pad_x * 2
    h = th + pad_y * 2
    x = (WIDTH - w) // 2
    
    # Shadow
    draw.rectangle([x + 6, y_pos + 6, x + w + 6, y_pos + h + 6], fill=BLACK)
    # Banner
    draw.rectangle([x, y_pos, x + w, y_pos + h], fill=fill_col, outline=BLACK, width=4)
    draw.text((x + pad_x, y_pos + pad_y - bbox[1]), text, fill=text_col, font=font)

print("Video renderer helper module initialized successfully.")
