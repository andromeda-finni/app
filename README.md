# Andromeda App

Мобильное приложение на Flutter (Android).

## Стек

- **Frontend**: Flutter (Dart), таргет — Android
- **Backend**: см. раздел [Backend](#backend) ниже
- **БД**: PostgreSQL — схема и миграции в [`db/`](db/README.md)
- **CI/CD**: GitHub Actions

## Структура проекта

Стандартная структура Flutter-проекта:

- `lib/` — исходный код приложения (точка входа — `lib/main.dart`)
- `android/` — нативный Android-проект (gradle, манифест и т.д.)
- `test/` — unit/widget-тесты
- `.github/workflows/` — пайплайны CI/CD
- `db/` — SQL-миграции PostgreSQL и `docker-compose.yml` для локальной БД (подробнее в [`db/README.md`](db/README.md))

## Переменные окружения (.env)

Перед любой работой с БД/бэкендом **обязательно** создать `.env` из шаблона:

```bash
cp .env.example .env
```

и заполнить значения (пароли для `POSTGRES_ADMIN_PASSWORD` и `GROSHIK_APP_PASSWORD`, при необходимости — `DATABASE_URL`/`APP_DATABASE_URL`). Без `.env` не запустится ни `docker compose up`, ни `db/scripts/migrate.sh` — переменные без значений намеренно обрывают выполнение (`set -euo pipefail` + проверки в скрипте), чтобы никто случайно не накатил миграции на БД с пустым/дефолтным паролем.

`.env` в `.gitignore` и никогда не коммитится — там реальные пароли. В репозитории есть только `.env.example` с плейсхолдерами `change_me`. Каждый, кто клонирует репозиторий, создаёт свой `.env` заново; продовые секреты хранятся в переменных окружения CI/хостинга, а не в файле.

## Разработка

### Установка окружения

1. Установить Flutter SDK: `brew install --cask flutter` (macOS) или см. [flutter.dev/get-started](https://docs.flutter.dev/get-started/install)
2. Установить Android Studio + Android SDK, принять лицензии: `flutter doctor --android-licenses`
3. Проверить окружение: `flutter doctor`
4. Скопировать `.env.example` → `.env` и заполнить (см. раздел [Переменные окружения](#переменные-окружения-env) выше) — нужно для локальной БД

### Запуск

```bash
flutter pub get
flutter run
```

### Тесты и анализ

```bash
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed .
```

## CI/CD

Все изменения кода должны идти через Pull Request — прямые пуши в `main` не используются для разработки.

В репозитории настроено 3 пайплайна (`.github/workflows/`):

| Файл | Триггер | Что делает |
|---|---|---|
| `ci.yml` | PR в `main`, push в `main` | `flutter analyze`, `flutter test`, проверка форматирования |
| `build-apk.yml` | push в `main`, вручную | собирает release APK и кладёт его в Artifacts запуска (хранится 30 дней) |
| `release.yml` | push тега `v*` (например `v1.0.0`) | собирает release APK и публикует его в GitHub Releases |

### Как включить обязательность пайплайна перед мёржем

По умолчанию GitHub не блокирует мёрж без прохождения CI — это нужно включить вручную (сделать может только владелец/админ репозитория):

1. Зайти в репозиторий на GitHub → **Settings → Branches**
2. Добавить **branch protection rule** для `main`
3. Включить:
   - **Require a pull request before merging**
   - **Require status checks to pass before merging** → выбрать job `Analyze & Test` из `ci.yml`
   - (опционально) **Require branches to be up to date before merging**

После этого смёржить в `main` можно будет только через PR с зелёным CI.

### Как получить собранный APK

- **Из обычной сборки** (после мёржа в `main`): GitHub → вкладка **Actions** → нужный запуск `Build APK` → раздел **Artifacts** → скачать `app-release-apk.zip`, внутри — `app-release.apk`.
- **Из релиза** (после `git tag vX.Y.Z && git push --tags`): GitHub → вкладка **Releases** → скачать `.apk` напрямую.

## Запуск собранного APK локально

Скачанный `.apk` можно поставить на эмулятор или физическое устройство.

### Вариант 1 — Android-эмулятор

```bash
# посмотреть доступные эмуляторы (создаются в Android Studio: Device Manager)
flutter emulators
flutter emulators --launch <emulator_id>

# когда эмулятор запущен — установить apk
adb install -r ~/Downloads/app-release.apk
```

### Вариант 2 — физическое Android-устройство

1. На телефоне: **Настройки → О телефоне** → 7 раз тапнуть по номеру сборки, чтобы включить режим разработчика
2. **Настройки → Для разработчиков** → включить **Отладка по USB**
3. Подключить телефон по USB и разрешить отладку на самом устройстве
4. Проверить, что устройство видно: `adb devices`
5. Установить APK:

```bash
adb install -r ~/Downloads/app-release.apk
```

Если APK собран не в Play Store и на устройстве есть более ранняя версия, подписанная другим ключом, `adb install` может отказать — тогда сначала `adb uninstall <package_name>` (package name — `com.andromedafinni.andromeda_app`).

### Вариант 3 — просто открыть APK на телефоне

Скачать `.apk` на телефон (например, из GitHub Releases в браузере) и открыть файл — Android предложит установить (может потребоваться разрешить установку из неизвестных источников в настройках).

## Backend

Приложению нужен бэкенд с PostgreSQL. Рекомендация:

**Основной вариант — Supabase.**
Это BaaS поверх настоящего PostgreSQL: сразу даёт REST/GraphQL API, авторизацию, файловое хранилище и realtime-подписки без написания сервера с нуля. У Flutter есть официальный пакет `supabase_flutter`. Хорошо подходит, чтобы быстро начать и не поддерживать отдельный сервис на первых порах; self-host тоже возможен (open source), если нужен полный контроль над инфраструктурой.

**Альтернатива — свой backend, если нужна сложная бизнес-логика:**
- **NestJS** (TypeScript) + **Prisma** + **PostgreSQL** — типизированный REST/GraphQL API, много готовых модулей (auth, validation, queues), хорошо ложится на Flutter-клиент через codegen моделей.
- или **Go** (Fiber/Echo) + **PostgreSQL** — если важны производительность и минимальный рантайм.

Если позже понадобится поднять свой backend и CI/CD для него — можно добавить отдельный репозиторий/каталог с аналогичным набором GitHub Actions пайплайнов (тесты → билд Docker-образа → деплой).

Схема БД (`db/migrations/`) — обычный portable SQL, накатится и на Supabase (через их SQL Editor/CLI), и на self-hosted/managed Postgres любого провайдера — выбор из пункта выше ни на что здесь не завязан.
