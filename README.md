# tourism-mobile

Private Flutter repository для Crimea Travel Platform — мобильный клиент
Android и iOS.

## Назначение

- Пользовательские сценарии поиска мест и работы с маршрутами.
- Feature-first architecture с **Riverpod**, GoRouter и Dio.
- Конфигурация dev / staging / production без встроенных secrets.

## Требования

- Flutter stable (см. `environment.sdk` в `pubspec.yaml`)
- Backend **не обязателен** для обычной UI-разработки (mock по умолчанию)

## Быстрый старт (frontend-only, без Docker)

```bash
flutter pub get
flutter run
```

Dev по умолчанию использует `useMockData: true` — места и маршруты из
локальных mock-репозиториев и `assets/images/`.

## Работа с реальным API

Нужны поднятый Compose/backend и:

```bash
flutter run --dart-define=USE_MOCK_DATA=false
```

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
│   ├── config/       # AppFlavor / AppConfig
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

`AppConfig.fromFlavor` задаёт базовый URL API и флаг `useMockData`.
Staging/production — HTTPS only.

- Dev: mock on (`useMockData: true`), API base `http://localhost:8000`.
- Override: `--dart-define=USE_MOCK_DATA=false` (или `true`).

## Связанные репозитории

- [`tourism-platform`](../tourism-platform) — архитектура и local Compose.
- [`tourism-backend`](../tourism-backend) — OpenAPI и server contracts.

Mobile не подключается к PostgreSQL напрямую.

## Лицензия

MIT — см. [LICENSE](LICENSE).
