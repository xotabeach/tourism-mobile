# tourism-mobile

Private Flutter repository для Crimea Travel Platform — мобильный клиент
Android и iOS.

## Назначение

- Пользовательские сценарии поиска мест и работы с маршрутами.
- Feature-first architecture с Riverpod, GoRouter и Dio.
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

Стиль и DX: см. `tourism-platform/docs/development-environment.md`,
`flutter-code-style.md`, `flutter-testing-guide.md`. Freezed — Phase 5.

## Структура

```text
lib/
├── core/
│   ├── config/       # AppFlavor и environment configuration
│   └── network/      # Dio client providers
├── features/
│   └── home/         # Первый feature module
├── routing/          # GoRouter configuration
├── app.dart
└── main.dart
```

## Конфигурация окружений

`AppConfig.fromFlavor` задаёт базовый URL API. Для staging и production
используйте `--dart-define` или flavor-specific entrypoints по мере роста
проекта.

По умолчанию dev указывает на `http://localhost:8000` — local backend из
`sibling` repository `tourism-backend`.

## Связанные репозитории

- [`tourism-platform`](../tourism-platform) — архитектура и local Compose.
- [`tourism-backend`](../tourism-backend) — OpenAPI и server contracts.

Mobile не подключается к PostgreSQL напрямую.

## Лицензия

MIT — см. [LICENSE](LICENSE).
