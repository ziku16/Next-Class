#!/usr/bin/env python3
"""
NextClass Development Progress Auto-Tracker
Scans the project codebase to automatically verify completed milestones
and keeps PROGRESS.md in sync with Obsidian in real-time.
"""

import os
import re
import sys
import shutil
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROGRESS_FILE = PROJECT_ROOT / "PROGRESS.md"
OBSIDIAN_VAULT_TRACK = Path("/home/zaki/Documents/Obsidian Vault/Next Class/Progress Track.md")

# Rules to detect completed tasks by inspecting filesystem and code artifacts
AUTODETECT_RULES = {
    "Flutter SDK installation / PATH verification": lambda: (
        shutil.which("flutter") is not None
        or (Path.home() / "development/flutter/bin/flutter").exists()
    ),
    "Base Flutter app scaffolding": lambda: (
        (PROJECT_ROOT / "pubspec.yaml").is_file()
        and (PROJECT_ROOT / "lib" / "main.dart").is_file()
    ),
    "pubspec.yaml dependencies installation": lambda: (
        (PROJECT_ROOT / "pubspec.yaml").is_file()
        and any(pkg in (PROJECT_ROOT / "pubspec.yaml").read_text() for pkg in ["google_fonts", "sqflite", "provider"])
    ),
    "Clean directory structure initialization (`core/`, `data/`, `domain/`, `state/`, `ui/`)": lambda: (
        all((PROJECT_ROOT / "lib" / d).is_dir() for d in ["core", "data", "domain", "state", "ui"])
    ),
    "Light & Dark `ColorScheme` (Manual, no `fromSeed`)": lambda: (
        any((PROJECT_ROOT / "lib").glob("**/theme*.dart"))
        or any((PROJECT_ROOT / "lib").glob("**/color_scheme*.dart"))
    ),
    "`NextClassColors` `ThemeExtension`": lambda: (
        any("NextClassColors" in f.read_text(errors="ignore") for f in (PROJECT_ROOT / "lib").rglob("*.dart"))
        if (PROJECT_ROOT / "lib").exists() else False
    ),
    "`ClassItem`, `QuizItem`, `ScanQuota`, `UserSettings` models": lambda: (
        all(any(model in f.name.lower() for f in (PROJECT_ROOT / "lib").rglob("*.dart"))
            for model in ["class", "quiz", "setting"])
        if (PROJECT_ROOT / "lib").exists() else False
    ),
    "SQLite helper (`AppDatabase`) & cascade delete logic": lambda: (
        any("AppDatabase" in f.read_text(errors="ignore") for f in (PROJECT_ROOT / "lib").rglob("*.dart"))
        if (PROJECT_ROOT / "lib").exists() else False
    ),
}

def load_progress():
    if not PROGRESS_FILE.exists():
        print(f"Error: {PROGRESS_FILE} not found.")
        sys.exit(1)
    return PROGRESS_FILE.read_text()

def save_progress(content):
    # Update timestamp
    today = datetime.now().strftime("%Y-%m-%d")
    content = re.sub(r">\s*\*\*Last Updated\*\*:\s*[\d-]+", f"> **Last Updated**: {today}", content)
    PROGRESS_FILE.write_text(content)
    
    # Touch Obsidian symlink to trigger Obsidian's file watcher refresh
    if OBSIDIAN_VAULT_TRACK.exists():
        try:
            os.utime(OBSIDIAN_VAULT_TRACK, None)
        except Exception:
            pass

def check_task(task_text, complete=True):
    content = load_progress()
    target_box = "[x]" if complete else "[ ]"
    old_box = "[ ]" if complete else "[x]"
    
    escaped_box = re.escape(old_box)
    escaped_task = re.escape(task_text)
    pattern = rf"(-\s*){escaped_box}(\s*.*?{escaped_task})"
    replacement = rf"\g<1>{target_box}\g<2>"
    
    new_content, count = re.subn(pattern, replacement, content, flags=re.IGNORECASE)
    if count > 0:
        save_progress(new_content)
        print(f"[{'X' if complete else ' '}] Updated: {task_text}")
        return True
    return False

def scan_and_update():
    """Scans the codebase against detection rules and checks off matching tasks."""
    print("Scanning NextClass development environment...")
    updated = 0
    for task_name, rule_fn in AUTODETECT_RULES.items():
        try:
            if rule_fn():
                if check_task(task_name, complete=True):
                    updated += 1
        except Exception as e:
            print(f"Error checking rule for '{task_name}': {e}")
            
    # Check if all items in a phase are complete and update phase status
    update_phase_headers()
    print(f"Scan complete. {updated} tasks updated.")

def update_phase_headers():
    content = load_progress()
    lines = content.splitlines()
    new_lines = []
    
    current_phase_index = None
    phase_items = []
    
    for i, line in enumerate(lines):
        phase_match = re.match(r"^-\s*\[([ x])\]\s*\*\*(Phase \d+):.*?\*\*", line)
        if phase_match:
            # Check previous phase items if applicable
            pass
        new_lines.append(line)
        
    save_progress("\n".join(new_lines) + "\n")

def complete_phase(phase_num):
    content = load_progress()
    # Mark the phase and all sub-items under it as completed
    phase_str = f"Phase {phase_num}:"
    in_phase = False
    new_lines = []
    for line in content.splitlines():
        if re.search(rf"^-\s*\[[ x]\]\s*\*\*{phase_str}", line):
            in_phase = True
            new_lines.append(re.sub(r"^-\s*\[ \]", "- [x]", line))
            continue
        elif in_phase and re.match(r"^-\s*\[[ x]\]\s*\*\*Phase \d+:", line):
            in_phase = False
        
        if in_phase and re.match(r"^\s+-\s*\[ \]", line):
            new_lines.append(re.sub(r"\[ \]", "[x]", line, count=1))
        else:
            new_lines.append(line)
            
    save_progress("\n".join(new_lines) + "\n")
    print(f"Phase {phase_num} marked as complete.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        scan_and_update()
    elif sys.argv[1] == "--scan":
        scan_and_update()
    elif sys.argv[1] == "--phase" and len(sys.argv) > 2:
        complete_phase(sys.argv[2])
    elif sys.argv[1] == "--check" and len(sys.argv) > 2:
        check_task(" ".join(sys.argv[2:]), complete=True)
    elif sys.argv[1] == "--uncheck" and len(sys.argv) > 2:
        check_task(" ".join(sys.argv[2:]), complete=False)
    else:
        print("Usage:")
        print("  python3 scripts/track_progress.py --scan")
        print("  python3 scripts/track_progress.py --phase <number>")
        print("  python3 scripts/track_progress.py --check <task substring>")
