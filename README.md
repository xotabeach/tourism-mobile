# tourism-mobile

Private Flutter repository для Crimea Travel Platform — мобильный клиент
Android и iOS.

## Назначение

- Пользовательские сценарии поиска мест и работы с маршрутами.
- Feature-first architecture с **Riverpod**, GoRouter и Dio.
- Конфигурация dev / staging / production без встроенных secrets.

## Требования

- Flutter stable (см. `environment.sdk` в `pubspec.yaml`)
- Запущенный `tourism-backend` для интеграционной разработки

## Быстрый старт

```bash
flutter pub get
flutter run
```

Проверки:

```bash
./scripts/validate.sh
```

Архитектура Phase 5:
`tourism-platform/docs/flutter-app-architecture.md`.
Стиль: `flutter-code-style.md`, DX: `development-environment.md`.

## Структура

```text
lib/
├── core/
│   ├── config/       # AppFlavor / AppConfig
│   ├── theme/        # AppColors + AppTheme
│   ├── network/      # Dio client
│   ├── errors/       # AppFailure
│   └── storage/      # SecureStorage port (Phase 6 tokens)
├── features/
│   ├── home/
│   ├── places/
│   └── shared/       # placeholder tabs helpers
├── routing/
│   ├── app_router.dart
│   └── shell/        # bottom NavigationBar + StatefulShellRoute
├── app.dart
└── main.dart
```

## Конфигурация окружений

`AppConfig.fromFlavor` задаёт базовый URL API. Staging/production — HTTPS only.

По умолчанию dev указывает на `http://localhost:8000`.

## Связанные репозитории

- [`tourism-platform`](../tourism-platform) — архитектура и local Compose.
- [`tourism-backend`](../tourism-backend) — OpenAPI и server contracts.

Mobile не подключается к PostgreSQL напрямую.

## Лицензия

MIT — см. [LICENSE](LICENSE).
