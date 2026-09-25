# tourism-mobile

Flutter-клиент КРЫМТРИП для Android и iOS
(CrimeaTrip).

Стек целиком: [tourism-platform/docs/stack.md](https://github.com/xotabeach/tourism-platform/blob/main/docs/stack.md).
Архитектура: [flutter-app-architecture.md](https://github.com/xotabeach/tourism-platform/blob/main/docs/flutter-app-architecture.md).
Версия исходного кода: `0.3.0+26` (`pubspec.yaml`); версия опубликованного APK
может отличаться.

## Назначение

- Каталог мест, маршрутов и статей, профиль, избранное, публикация, inbox.
- Активное прохождение и история маршрутов, интерактивная карта, дни и
  сложность маршрута.
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
`./scripts/validate.sh`. APK собирается локально, чтобы Android toolchain не
конкурировал за память с production-контейнерами.

### Публикация APK по ссылке

Приложения нет ни в одном сторе, поэтому единственный способ отдать кому-то
сборку — ссылка. Одна локальная команда собирает подписанный релиз с боевым
API и кладёт его в media-том бэкенда:

```bash
./scripts/publish-production-apk.sh --dry-run  # только проверка настроек
./scripts/publish-production-apk.sh            # сборка и публикация
```

```
https://201-24-55-130.sslip.io/media/app/crimeatrip-latest.apk   # всегда последняя
https://201-24-55-130.sslip.io/media/app/crimeatrip-<версия>.apk # если опубликована
```

Команда запускается вручную, потому что она перезаписывает ссылку, с которой
все ставят приложение: какая сборка станет «latest», решает человек. Файл
пишется под временным именем и переименовывается только после сверки размера —
недокачанный APK ставится как повреждённый пакет.

Нужны локальные `android/key.properties`, `scripts/build.env`, ключ
`~/.ssh/crimeatrip-apk-publish` и закреплённый ключ сервера в
`~/.ssh/known_hosts`. Необязательные переопределения читаются из
gitignored `scripts/publish.env`; шаблон — `scripts/publish.env.example`.

#### Ключ, который умеет только это

Локальной публикации **не** отдаётся деплойный ключ бэкенда: он открывает
полный SSH на прод вместе с миграциями, а для APK нужно одно действие. Вместо
этого используется отдельный ключ, ограниченный на сервере forced command
(`tourism-platform/deploy/test/apk-receive.sh`, установлен как
`/opt/crimeatrip-test/apk-receive.sh`). С `command=` в `authorized_keys` sshd
игнорирует то, что просит клиент, и запускает приёмник. Такой ключ не открывает
шелл, не пробрасывает порты и не деплоит — он передаёт один APK.

Приёмник принимает ровно `publish <major.minor.patch>` и проверяет входной
поток: непустой, до 300 МБ, начинается с ZIP-заголовка. Версия сверяется с
шаблоном и в шелл не попадает.

Завести ключ на рабочей машине (делается один раз):

```bash
ssh-keygen -t ed25519 -N '' -C crimeatrip-apk-publish -f ~/.ssh/crimeatrip-apk-publish

printf 'command="/opt/crimeatrip-test/apk-receive.sh",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-user-rc %s\n' \
  "$(cat ~/.ssh/crimeatrip-apk-publish.pub)" \
  | ssh crimeatrip-prod 'cat >> /home/crimeatrip-deploy/.ssh/authorized_keys'

# Приватный ключ остаётся только локально и не добавляется в git.
chmod 600 ~/.ssh/crimeatrip-apk-publish
```

Проверить, что ключ действительно ограничен:

```bash
ssh -i ~/.ssh/crimeatrip-apk-publish crimeatrip-deploy@<host>    # должно отказать
```

Сборка iOS/Android, `dart-define`, signed APK/AAB описаны в скриптах
`scripts/build-signed-apk.sh` и `scripts/publish-production-apk.sh`.

Проверки:

```bash
./scripts/validate.sh
```

Пиксельные golden-тесты сняты на macOS; на других хостах пропускаются.
CI: `SKIP_PIXEL_GOLDENS=1 flutter test`. Подробности —
[руководстве по тестам](https://github.com/xotabeach/tourism-platform/blob/main/docs/flutter-testing-guide.md).

## Что реально vs stub

**API при `DATA_SOURCE=api`:** auth OTP, каталог мест/маршрутов, избранное,
публикация черновика → модерация, отдельные отзывы маршрутов и локаций (фото,
закреплённый собственный отзыв, ответы с цитатой, fullscreen viewer), профиль
(тп/звания/лидерборд/лайки/эксперт/достижения, цельный pull-to-refresh), support tickets с фото,
тест пользовательских предпочтений, inbox,
FCM token (Android и сконфигурированный iOS-клиент; APNs key всё ещё нужен).

**UI-only / stub:** Travel+ billing и аудиогид.
«Пройти маршрут» уже подключён к route-executions API (start/resume,
остановки, complete/cancel, история); offline download работает как read-only snapshot
и не заявляет turn-by-turn навигацию. В `DATA_SOURCE=mock` чат использует сценарии;
в API-режиме работает через backend planning sessions.

Статьи, комментарии и редактор статей подключены к API; маршруты показывают
дни, этапы, интерактивную карту и объяснение оценки сложности.

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
│   ├── route_match/  # form + interactive AI chat; builder = Phase 8B
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

- [`tourism-platform`](https://github.com/xotabeach/tourism-platform) — архитектура и local Compose.
- [`tourism-backend`](https://github.com/xotabeach/tourism-backend) — OpenAPI и server contracts.

Mobile не подключается к PostgreSQL и не вызывает Ollama напрямую.

## Лицензия

MIT — см. [LICENSE](LICENSE).
