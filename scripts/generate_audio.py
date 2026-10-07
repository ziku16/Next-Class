import math
import struct
import wave
import random

def create_soundtrack(duration_sec=30.0, sample_rate=44100, output_wav="/tmp/nextclass_soundtrack.wav"):
    total_samples = int(duration_sec * sample_rate)
    buffer = [0.0] * total_samples

    bpm = 128.0
    beat_sec = 60.0 / bpm
    total_beats = int(duration_sec / beat_sec)

    def add_sound(start_time, sound_fn, dur, amp=1.0):
        start_idx = int(start_time * sample_rate)
        end_idx = min(total_samples, start_idx + int(dur * sample_rate))
        for idx in range(start_idx, end_idx):
            t = (idx - start_idx) / sample_rate
            buffer[idx] += sound_fn(t) * amp

    # --- Instrument Synthesizers ---

    def kick(t):
        if t > 0.35: return 0.0
        # Pitch drop from 160Hz to 38Hz
        freq = 38.0 + 122.0 * math.exp(-22.0 * t)
        phase = 2.0 * math.pi * (38.0 * t + (122.0 / 22.0) * (1.0 - math.exp(-22.0 * t)))
        env = math.exp(-10.0 * t)
        return math.sin(phase) * env

    def sub_808(t, root_freq=55.0):
        if t > 0.8: return 0.0
        freq = root_freq * (1.0 + 0.5 * math.exp(-35.0 * t))
        env = math.exp(-3.5 * t)
        # saturated sine
        val = math.sin(2.0 * math.pi * freq * t)
        return math.tanh(val * 1.8) * env

    def snare(t):
        if t > 0.25: return 0.0
        noise = (random.random() * 2.0 - 1.0) * math.exp(-18.0 * t)
        tone = math.sin(2.0 * math.pi * 195.0 * t) * math.exp(-22.0 * t)
        return 0.7 * noise + 0.5 * tone

    def hihat(t):
        if t > 0.08: return 0.0
        noise = (random.random() * 2.0 - 1.0) * math.exp(-55.0 * t)
        return noise * 0.4

    def click(t):
        if t > 0.04: return 0.0
        return math.sin(2.0 * math.pi * 1400.0 * t) * math.exp(-90.0 * t)

    def bell_chime(t):
        if t > 1.8: return 0.0
        env = math.exp(-2.8 * t)
        # Chime chord: E6 (1318 Hz), G#6 (1661 Hz), B6 (1975 Hz)
        c1 = math.sin(2.0 * math.pi * 1318.5 * t)
        c2 = 0.7 * math.sin(2.0 * math.pi * 1661.2 * t)
        c3 = 0.5 * math.sin(2.0 * math.pi * 1975.5 * t)
        return (c1 + c2 + c3) * 0.5 * env

    def shutter(t):
        if t > 0.15: return 0.0
        n1 = (random.random() * 2.0 - 1.0) * math.exp(-40.0 * t)
        n2 = 0.0
        if t > 0.07:
            n2 = (random.random() * 2.0 - 1.0) * math.exp(-40.0 * (t - 0.07))
        return (n1 + n2) * 0.6

    def scan_hum(t):
        if t > 1.2: return 0.0
        env = math.sin(math.pi * (t / 1.2))
        freq = 380.0 + 80.0 * math.sin(2.0 * math.pi * 6.0 * t)
        return math.sin(2.0 * math.pi * freq * t) * env * 0.35

    def whoosh(t):
        if t > 0.4: return 0.0
        env = math.sin(math.pi * (t / 0.4))
        noise = (random.random() * 2.0 - 1.0)
        return noise * env * 0.4

    def stamp_thud(t):
        if t > 0.5: return 0.0
        freq = 65.0 * math.exp(-12.0 * t)
        env = math.exp(-8.0 * t)
        impact = (random.random() * 2.0 - 1.0) * math.exp(-45.0 * t) * 0.5
        return (math.sin(2.0 * math.pi * freq * t) + impact) * env

    # --- Build Background Beat (128 BPM) ---
    for b in range(total_beats):
        t_beat = b * beat_sec
        if t_beat > duration_sec - 0.5:
            break

        # Intro lo-fi buildup during Scene 1 (0 to 4.5s)
        if t_beat < 4.5:
            if b % 2 == 0:
                add_sound(t_beat, kick, 0.35, 0.45)
            if b % 4 == 2:
                add_sound(t_beat, click, 0.05, 0.5)
            continue

        # Outro section (from 26.5s to 30.0s) has heavy impacts instead of loop
        if t_beat >= 26.5:
            continue

        # Full high-energy breakbeat during main body (4.5s to 26.5s)
        # Kick on 1 and 3 (or syncopated breakbeat)
        beat_in_bar = b % 4
        if beat_in_bar == 0:
            add_sound(t_beat, kick, 0.35, 0.8)
            add_sound(t_beat, sub_808, 0.7, 0.5)
        elif beat_in_bar == 2:
            add_sound(t_beat, kick, 0.35, 0.7)
            # syncopated kick 1/8 note before next bar
            add_sound(t_beat + beat_sec * 0.75, kick, 0.3, 0.6)

        # Snare on 2 and 4
        if beat_in_bar == 1 or beat_in_bar == 3:
            add_sound(t_beat, snare, 0.25, 0.65)

        # Hihats on every 8th note
        add_sound(t_beat, hihat, 0.08, 0.3)
        add_sound(t_beat + beat_sec * 0.5, hihat, 0.08, 0.35)

    # --- Specific Synchronized Event SFX ---
    # Scene 1:
    add_sound(0.1, whoosh, 0.4, 0.4)
    add_sound(1.5, stamp_thud, 0.5, 0.9) # Stamp: STILL ZOOMING?
    add_sound(2.6, whoosh, 0.4, 0.6) # Paper wipe
    add_sound(3.6, click, 0.05, 0.8) # Button press

    # Scene 2: Timetable Scan
    add_sound(4.6, shutter, 0.2, 0.8) # Shutter
    add_sound(5.2, scan_hum, 1.2, 0.6) # Laser scan
    add_sound(6.6, whoosh, 0.4, 0.5) # Loader spin
    add_sound(7.8, click, 0.05, 0.7) # Cards deal
    add_sound(8.2, click, 0.05, 0.7)
    add_sound(8.6, click, 0.05, 0.7)
    add_sound(9.0, click, 0.05, 0.9) # Looks good button press

    # Scene 3: Today Screen
    add_sound(9.8, whoosh, 0.35, 0.5)
    # Ticking clock accents
    for tick_t in [10.5, 11.5, 12.5, 13.5, 14.5, 15.5]:
        add_sound(tick_t, click, 0.04, 0.3)

    # Scene 4: Lock screen notification drop
    add_sound(16.0, whoosh, 0.4, 0.5)
    add_sound(17.2, bell_chime, 1.8, 1.0) # Crisp glass chime!
    add_sound(17.3, click, 0.05, 0.6) # Tap bounce

    # Scene 5: Quizzes
    add_sound(21.6, whoosh, 0.35, 0.5)
    add_sound(23.8, click, 0.05, 0.8) # Night-before toggle click 1
    add_sound(24.0, click, 0.05, 0.8) # click 2

    # Scene 6: Outro 3 Stamp Slams
    add_sound(26.8, stamp_thud, 0.5, 0.95) # 100% OFFLINE
    add_sound(27.5, stamp_thud, 0.5, 0.95) # NO ACCOUNTS
    add_sound(28.2, stamp_thud, 0.5, 1.0)  # ZERO ADS
    add_sound(28.8, sub_808, 1.8, 1.2)     # Massive 808 drop
    add_sound(28.8, bell_chime, 2.0, 0.7)  # Final brand chime

    # Normalize audio buffer
    max_amp = max(abs(s) for s in buffer)
    if max_amp > 0.001:
        norm_factor = 0.92 / max_amp
    else:
        norm_factor = 1.0

    wav_samples = []
    for s in buffer:
        val = int(s * norm_factor * 32767.0)
        val = max(-32768, min(32767, val))
        wav_samples.append(struct.pack('<h', val))

    with wave.open(output_wav, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(b''.join(wav_samples))

    print(f"Soundtrack generated: {output_wav} ({duration_sec}s)")
    return output_wav

if __name__ == "__main__":
    create_soundtrack(30.0, output_wav="/tmp/nextclass_soundtrack.wav")
