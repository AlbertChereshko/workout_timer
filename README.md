# ⚡ Workout Timer — HIIT, Tabata, EMOM & AMRAP

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&height=200&section=header&text=Workout%20Timer%20App&fontSize=42&fontAlignY=38&desc=Next-Gen%20Interval%20Training%20%E2%80%A2%20Flutter%20%E2%80%A2%20Riverpod%20%E2%80%A2%20AI%20Coach&descFontSize=18&descAlignY=62" width="100%" alt="Workout Timer Banner"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Riverpod-2.5-blueviolet?style=for-the-badge&logo=redux" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Hive-Offline%20First-yellow?style=for-the-badge" alt="Hive" />
  <img src="https://img.shields.io/badge/Tests-88%20Passed-success?style=for-the-badge" alt="Tests" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License" />
</p>

---

## 🌟 Обзор проекта (Overview)

**Workout Timer** — современное, высокопроизводительное мобильное приложение для интервальных тренировок любой сложности. Создано на **Flutter** с использованием **Material 3**, оптимизировано под дисплеи с частотой **120 Гц** и оснащено умным **AI-тренером (Gemini)**.

Подходит для кроссфита, функционального тренинга, калистеники, единоборств и домашних тренировок.

---

## ✨ Ключевые возможности (Key Features)

### ⏱ Режимы тренировок
* **Tabata**: классические и настраиваемые протоколы высокой интенсивности (20s работа / 10s отдых).
* **EMOM (Every Minute on the Minute)**: посекундный контроль каждого раунда с автопереходом.
* **AMRAP (As Many Rounds As Possible)**: общий таймер тренировки с фиксацией выполненных раундов и повторений.
* **Интервалы и статика**: поддержка изометрических упражнений с кастомным временем фиксации.
* **Библиотека упражнений**: встроенный каталог упражнений, группировка по мышцам и инвентарю (гири, турник, собственный вес).

### 🤖 Интеграция с AI (Google Gemini)
* **AI Workout Generator**: автоматическое составление сбалансированной программы под ваш инвентарь и цели.
* **AI Coach Chat**: персональный интерактивный ассистент, готовый ответить на вопросы по технике и адаптации нагрузки.

### 🎨 Премиальный дизайн и кастомизация
* **Темы оформления**: 6 уникальных визуальных стилей (**Cosmic**, **Neon Cyberpunk**, **Minimalist**) с поддержкой Dark / Light режимов.
* **120 FPS анимации**: плавные переходы круговых прогресс-баров и фоновых эффектов.
* **Edge-to-Edge**: полная поддержка современных безрамочных экранов и вырезов.

### 🔊 Аудио и тактильный отклик (Haptics)
* **Звуковые эффекты**: профессиональные аудиотреки и звуковые сигналы (гонг, обратный отсчет, бипы).
* **Text-to-Speech (TTS)**: голосовое озвучивание следующего упражнения и оставшегося времени.
* **Тактильная отдача**: продвинутая вибрация с поддержкой бионических вибромоторов (O-Haptics).

### 📊 Аналитика и здоровье
* **Калькулятор калорий**: точный расчет расхода энергии с учетом MET-коэффициентов и профиля атлета.
* **Recovery Analyzer**: алгоритм анализа восстановления мышечных групп на основе истории тренировок.
* **Локальная база Hive**: мгновенный отклик, сохранение всей истории и работа полностью офлайн.

---

## 🛠 Технологический стек (Architecture & Tech Stack)

| Компонент | Технология | Назначение |
|---|---|---|
| **UI Framework** | [Flutter 3.x](https://flutter.dev) / Material 3 | Кроссплатформенный быстрый интерфейс |
| **State Management** | [flutter_riverpod](https://riverpod.dev) + `@riverpod` codegen | Реактивное управление состоянием |
| **Routing** | [go_router](https://pub.dev/packages/go_router) | Декларативная навигация |
| **Local Storage** | [hive_flutter](https://pub.dev/packages/hive_flutter) | Быстрая NoSQL БД для тренировок и истории |
| **AI Integration** | [google_generative_ai](https://pub.dev/packages/google_generative_ai) | Умный тренер и генерация тренировок |
| **Audio & TTS** | `audioplayers`, `flutter_tts`, `vibration` | Звуковое сопровождение и тактильный отклик |
| **Localization** | `flutter_localizations` (en, ru, de, hr) | Мультиязычный интерфейс |
| **System** | `wakelock_plus`, `home_widget` | Контроль экрана и виджеты |

---

## 🚀 Быстрый старт (Getting Started)

### Требования
* Flutter SDK `>= 3.3.0`
* Dart SDK `>= 3.3.0`

### Установка и запуск

1. **Клонируйте репозиторий:**
   ```bash
   git clone https://github.com/AlbertChereshko/workout_timer.git
   cd workout_timer
   ```

2. **Установите зависимости:**
   ```bash
   flutter pub get
   ```

3. **Сгенерируйте код (Riverpod & Hive):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Запустите приложение:**
   ```bash
   # Запуск на подключенном смартфоне
   flutter run

   # Запуск на Linux Desktop (с симуляцией мобильного экрана 430x932)
   flutter run -d linux
   ```

---

## 🧪 Тестирование и качество кода

Проект покрыт автоматическими тестами бизнес-логики, таймеров и аналитики:

```bash
# Проверка качества кода линтером
flutter analyze

# Запуск полного набора тестов
flutter test
```

> **Статус тестов**: 88/88 тестов успешно пройдены (покрывают логику отсчета времени, смену раундов, расчет калорий, восстановление мышц и работу репозиториев).

---

## 📱 Целевые устройства и платформы

* **Android**: протестировано на устройствах OnePlus (OxygenOS) с поддержкой O-Haptics и высокой частоты обновления (120 Гц).
* **Linux Desktop**: встроенный режим запуска для быстрого тестирования.
* **iOS / Web**: совместимая архитектура кодовой базы.

---

## 📄 Лицензия

Распространяется под лицензией MIT. Подробности в файле [LICENSE](LICENSE).

<p align="center">
  Разработано с ❤️ автором <a href="https://github.com/AlbertChereshko">@AlbertChereshko</a>
</p>

