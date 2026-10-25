import math
import struct
import wave
import subprocess

SAMPLE_RATE = 44100

def save_wav(filename, samples):
    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        int_samples = [max(-32767, min(32767, int(s * 32767))) for s in samples]
        raw_data = struct.pack(f"<{len(int_samples)}h", *int_samples)
        wf.writeframes(raw_data)

# 1. Real Deep Heavy Boxing Gong (multi-harmonic resonant metal bell with strike transient and sub-bass)
def gen_heavy_gong():
    duration = 2.2
    n_samples = int(SAMPLE_RATE * duration)
    samples = []
    # Fundamental and inharmonic resonant partials for a large bronze gong
    partials = [
        (130.81, 0.45, 1.8),  # C3 fundamental
        (261.63, 0.35, 1.4),  # C4
        (392.00, 0.25, 1.0),  # G4
        (523.25, 0.20, 0.8),  # C5
        (784.00, 0.15, 0.5),  # G5
        (1046.5, 0.10, 0.3),  # C6
        (215.00, 0.20, 1.5),  # inharmonic ring
        (340.00, 0.18, 1.2),  # inharmonic ring
    ]
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        # Strike transient (noise burst on impact)
        if t < 0.03:
            impact = (1.0 - t / 0.03) * ((hash(i) % 2000) / 1000.0 - 1.0) * 0.35
            val += impact
        # Partials
        for freq, amp, decay in partials:
            env = math.exp(-t * (3.0 / decay))
            val += amp * math.sin(2 * math.pi * freq * t) * env
        samples.append(val * 0.8)
    return samples

# 2. Boxing Bell (Clang Clang high brass gym ring bell)
def gen_boxing_bell():
    duration = 1.0
    n_samples = int(SAMPLE_RATE * duration)
    samples = []
    partials = [
        (880.0, 0.4, 0.8),
        (1760.0, 0.3, 0.5),
        (2640.0, 0.2, 0.3),
        (1320.0, 0.25, 0.6),
    ]
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        if t < 0.015:
            val += (1.0 - t / 0.015) * 0.3
        for freq, amp, decay in partials:
            env = math.exp(-t * (4.0 / decay))
            val += amp * math.sin(2 * math.pi * freq * t) * env
        samples.append(val * 0.75)
    return samples

# 3. High Pitch Piercing Whistle (referee Fox 40 style two-tone trill)
def gen_referee_whistle():
    duration = 0.65
    n_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Envelope: fast attack, steady, release
        if t < 0.05:
            env = t / 0.05
        elif t > 0.5:
            env = max(0.0, (0.65 - t) / 0.15)
        else:
            env = 1.0
        # Trill modulation (pea in whistle)
        mod = math.sin(2 * math.pi * 32.0 * t) * 80.0
        f1 = 2600.0 + mod
        f2 = 2950.0 + mod * 0.8
        val = 0.5 * math.sin(2 * math.pi * f1 * t) + 0.5 * math.sin(2 * math.pi * f2 * t)
        samples.append(val * env * 0.7)
    return samples

# 4. Digital Stadium Horn / Airhorn
def gen_airhorn():
    duration = 0.6
    n_samples = int(SAMPLE_RATE * duration)
    samples = []
    # Stadium horn triad: F4, A4, C5
    freqs = [349.23, 440.0, 523.25]
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        if t < 0.03:
            env = t / 0.03
        elif t > 0.45:
            env = max(0.0, (0.6 - t) / 0.15)
        else:
            env = 1.0
        val = 0.0
        for f in freqs:
            # Sawtooth-like bright brass harmonic
            s = math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * 2 * f * t) + 0.25 * math.sin(2 * math.pi * 3 * f * t)
            val += s * 0.25
        samples.append(val * env * 0.8)
    return samples

# 5. Crisp Modern Beep (Short countdown pulse)
def gen_countdown_beep():
    duration = 0.15
    n_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 18.0)
        val = math.sin(2 * math.pi * 950.0 * t) * env
        samples.append(val * 0.8)
    return samples

# 6. Woodblock / Click (percussive tick)
def gen_woodblock():
    duration = 0.08
    n_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 55.0)
        val = math.sin(2 * math.pi * 1200.0 * t) * env
        samples.append(val * 0.8)
    return samples

# 7. Victorious Finish Fanfare
def gen_victory_fanfare():
    duration = 1.5
    n_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * n_samples
    notes = [
        (0.0, 0.18, 523.25),   # C5
        (0.18, 0.18, 659.25),  # E5
        (0.36, 0.18, 783.99),  # G5
        (0.54, 0.90, 1046.50), # C6 triumphant hold
    ]
    for start_t, note_dur, freq in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        dur_samples = int(note_dur * SAMPLE_RATE)
        for j in range(dur_samples):
            idx = start_idx + j
            if idx >= n_samples:
                break
            t = j / SAMPLE_RATE
            env = min(t / 0.02, 1.0) * math.exp(-t * (2.0 / note_dur))
            val = (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * 2 * freq * t)) * env * 0.5
            samples[idx] += val
    return samples

save_wav('assets/sounds/gong_rest.wav', gen_heavy_gong())
save_wav('assets/sounds/bell_boxing.wav', gen_boxing_bell())
save_wav('assets/sounds/whistle_start.wav', gen_referee_whistle())
save_wav('assets/sounds/horn_stadium.wav', gen_airhorn())
save_wav('assets/sounds/beep_countdown.wav', gen_countdown_beep())
save_wav('assets/sounds/click_tick.wav', gen_woodblock())
save_wav('assets/sounds/fanfare_finish.wav', gen_victory_fanfare())
print("All sports sound assets generated successfully!")
