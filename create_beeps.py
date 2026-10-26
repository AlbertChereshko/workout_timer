import math
import struct
import wave
import os

# Папка со звуками вашего Flutter проекта
OUTPUT_DIR = "workout_timer/assets/sounds"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def generate_tone(filename, freq=440.0, duration=0.2, volume=0.8, sample_rate=44100):
    filepath = os.path.join(OUTPUT_DIR, filename)
    num_samples = int(duration * sample_rate)
    
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)      # Моно
        wav_file.setsampwidth(2)      # 16-bit
        wav_file.setframerate(sample_rate)

        frames = bytearray()
        for i in range(num_samples):
            # Экспоненциальное затухание, чтобы звук не щелкал в конце
            envelope = math.exp(-3.0 * i / num_samples)
            value = volume * envelope * math.sin(2.0 * math.pi * freq * (i / sample_rate))
            sample = int(value * 32767.0)
            frames.extend(struct.pack('<h', sample))

        wav_file.writeframes(frames)
    print(f"✓ Создан файл: {filepath}")

# Генерация звуков:
# 1. Отсчет 3... 2... 1... (заменяет стандартный бип)
generate_tone("beep_countdown.wav", freq=660, duration=0.12)

# 2. Сигнал старта раунда
# (Если хотите заменить стандартный свисток старта — назовите "whistle_start.wav")
generate_tone("whistle_start.wav", freq=1320, duration=0.35)

# 3. Сигнал отдыха / окончания интервала
# (Если хотите заменить стандартный гонг отдыха — назовите "gong_rest.wav")
generate_tone("gong_rest.wav", freq=440, duration=0.40)
