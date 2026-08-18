# tourism-mobile

Private Flutter repository для Crimea Travel Platform — клиент Android и iOS
(CrimeaTrip).

Стек целиком: `tourism-platform/docs/stack.md`.
Архитектура: `tourism-platform/docs/flutter-app-architecture.md`.

## Назначение

- Каталог мест и маршрутов, профиль, избранное, публикация, inbox.
- Feature-first: Riverpod, GoRouter, Dio; credentials — secure storage.
- Конфигурация local / test / staging / production без secrets в Git.

## Требования

- Flutter stable (см. `environment.sdk` в `pubspec.yaml`)
- Backend не обязателен для UI (`DATA_SOURCE=mock` по умолчанию)

## Быстрый старт (frontend-only, без Docker)

```bash
flutter pub get
flutter run
```

Local по умолчанию использует `DATA_SOURCE=mock` — места и маршруты из
локальных mock-репозиториев и `assets/images/`.

## Работа с реальным API

Нужны поднятый Compose/backend и:

```bash
flutter run --dart-define=DATA_SOURCE=api
```

Staging и production требуют явный HTTPS endpoint:

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://staging-api.example.org
```

Release без `APP_ENV` выбирает `production` и откажется стартовать без
неплейсхолдерного `API_BASE_URL`. Android release signing — gitignored
`android/key.properties` (без fallback на debug key).

Подписанный release APK с test API (локальный `android/key.properties`):

```bash
./scripts/build-signed-apk.sh          # → build/app/outputs/flutter-apk/app-release.apk
./scripts/build-signed-apk.sh --install
```

CI lean (default): на `main`/`gamma` style/tests не гоняются — локально
`./scripts/validate.sh`. APK: job `mobile-apk-test` **manual** (или полный
pipeline при `CI_PIPELINE_MODE=full`). Нужны CI variables keystore +
`MOBILE_TEST_API_BASE_URL`; см.
[ci-and-runners.md](../tourism-platform/docs/ci-and-runners.md).

Сборка iOS/Android, `dart-define`, signed APK/AAB:
[mobile-build-and-install.md](../tourism-platform/docs/mobile-build-and-install.md).

Проверки:

```bash
./scripts/validate.sh
```

Пиксельные golden-тесты сняты на macOS; на других хостах пропускаются.
CI: `SKIP_PIXEL_GOLDENS=1 flutter test`. Подробности —
`tourism-platform/docs/flutter-testing-guide.md`.

## Что реально vs stub

**API при `DATA_SOURCE=api`:** auth OTP, каталог мест/маршрутов, избранное,
публикация черновика → модерация, отзывы, профиль (тп/звания/лидерборд/лайки/
достижения), support tickets, inbox, FCM token (Android).

**UI-only / stub:** подбор маршрута (срез каталога до Phase 8A), «Пройти
маршрут», Travel+ billing, аудиогид, offline download,
история в «Мои маршруты». Чат ИИ не ходит в Gemma/Gemini.

## Структура

```text
lib/
├── core/
│   ├── config/       # AppEnvironment / AppConfig
│   ├── design/       # Design tokens + glass
│   ├── theme/
│   ├── network/      # Dio
│   ├── errors/
│   └── storage/      # Keychain/Keystore
├── features/
│   ├── onboarding/
│   ├── auth/
│   ├── home/
│   ├── places/
│   ├── routes/
│   ├── route_publish/
│   ├── route_match/  # form UI; builder = Phase 8A
│   ├── my_routes/
│   ├── profile/
│   ├── settings/     # support, inbox, Travel+ mock
│   ├── search/
│   └── favorites/
├── routing/
├── app.dart
└── main.dart
```

## Конфигурация окружений

`AppConfig.fromEnvironment` выбирает окружение через `APP_ENV`; release без
define выбирает production. Test/staging/production — HTTPS only и требуют
`API_BASE_URL`.

- Local: `DATA_SOURCE=mock`, API base `http://localhost:8000`.
- Local API: `--dart-define=DATA_SOURCE=api`.
- Test/staging/production: только `DATA_SOURCE=api`; mock запрещён.

## Связанные репозитории

- [`tourism-platform`](../tourism-platform) — архитектура и local Compose.
- [`tourism-backend`](../tourism-backend) — OpenAPI и server contracts.

Mobile не подключается к PostgreSQL и не вызывает Ollama напрямую.

## Лицензия

MIT — см. [LICENSE](LICENSE).
