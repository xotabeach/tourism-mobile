# tourism-mobile

Private Flutter repository для Crimea Travel Platform — мобильный клиент
Android и iOS.

## Назначение

- Пользовательские сценарии поиска мест и работы с маршрутами.
- Feature-first architecture с **Riverpod**, GoRouter и Dio.
- Конфигурация local / test / staging / production без встроенных secrets.

## Требования

- Flutter stable (см. `environment.sdk` в `pubspec.yaml`)
- Backend **не обязателен** для обычной UI-разработки (mock по умолчанию)

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

Release без `APP_ENV` автоматически выбирает `production` и откажется
запускаться без неплейсхолдерного `API_BASE_URL`. Android release signing
берётся из gitignored `android/key.properties` (без fallback на debug key).

Полная шпаргалка по iOS/Android сборкам, `dart-define`, signed APK/AAB и
установке на устройство:
[mobile-build-and-install.md](../tourism-platform/docs/mobile-build-and-install.md)
(в monorepo) / канон в `tourism-platform/docs/mobile-build-and-install.md`.

Проверки:

```bash
./scripts/validate.sh
```

Пиксельные golden-тесты сняты на macOS и на других хостах пропускаются, поэтому
CI их не проверяет — прогоняй `flutter test` на маке перед пушем UI-правок.
Что именно увидит CI: `SKIP_PIXEL_GOLDENS=1 flutter test`. Подробности —
`tourism-platform/docs/flutter-testing-guide.md`.

Архитектура Phase 5:
`tourism-platform/docs/flutter-app-architecture.md`.
Стиль: `flutter-code-style.md`, DX: `development-environment.md`.

## Структура

```text
lib/
├── core/
│   ├── config/       # AppEnvironment / AppConfig
│   ├── design/       # Design tokens + glass components
│   ├── theme/        # AppTheme (+ re-exports of design tokens)
│   ├── network/      # Dio client
│   ├── errors/       # AppFailure
│   └── storage/      # SecureStorage port (Phase 6 tokens)
├── features/
│   ├── onboarding/   # Welcome + session gate
│   ├── auth/         # Mock name/phone/OTP UI (Phase 6 wires API)
│   ├── home/         # Design home feed
│   ├── places/
│   ├── routes/       # Catalog slider + detail
│   └── shared/       # placeholder tabs helpers
├── routing/
│   ├── app_router.dart
│   └── shell/        # glass bottom NavigationBar + StatefulShellRoute
├── app.dart
└── main.dart
```

## Конфигурация окружений

`AppConfig.fromEnvironment` выбирает окружение через `APP_ENV`; release без
define выбирает production. Test/staging/production — HTTPS only и требуют
`API_BASE_URL`.

- Local: `DATA_SOURCE=mock`, API base `http://localhost:8000`.
- Local API: `--dart-define=DATA_SOURCE=api`.
- Test/staging/production: только `DATA_SOURCE=api`; mock запрещён startup
  validation.

## Связанные репозитории

- [`tourism-platform`](../tourism-platform) — архитектура и local Compose.
- [`tourism-backend`](../tourism-backend) — OpenAPI и server contracts.

Mobile не подключается к PostgreSQL напрямую.

## Лицензия

MIT — см. [LICENSE](LICENSE).
