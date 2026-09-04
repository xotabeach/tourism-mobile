import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/cache/app_data_refresh.dart';

/// Порог, после которого данные считаются несвежими.
///
/// Внутри сессии свежесть держит TTL самих кешей (5–10 минут). Но пока
/// приложение висит в фоне, ничего не истекает по-настоящему: вернувшись
/// через час, человек видел то же, что оставил, пока сам не потянет список
/// вниз. Пятнадцать минут — компромисс: короткое переключение в мессенджер
/// не стоит перезагрузки, а возвращение «на следующий день» её стоит.
const staleAfterBackground = Duration(minutes: 15);

/// Сбрасывает кеши, если приложение вернулось из фона несвежим.
///
/// Обёртка над деревом: подписывается на жизненный цикл, запоминает время
/// ухода в фон и на возврате решает, стоит ли перечитывать данные.
class StaleDataRefresher extends ConsumerStatefulWidget {
  const StaleDataRefresher({
    required this.child,
    this.staleAfter = staleAfterBackground,
    super.key,
  });

  final Widget child;
  final Duration staleAfter;

  @override
  ConsumerState<StaleDataRefresher> createState() => _StaleDataRefresherState();
}

class _StaleDataRefresherState extends ConsumerState<StaleDataRefresher>
    with WidgetsBindingObserver {
  DateTime? _leftForegroundAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _leftForegroundAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        _refreshIfStale();
      case AppLifecycleState.inactive:
        // Короткая пауза — шторка уведомлений, входящий звонок. Данные от
        // этого не устаревают, и отметку времени здесь ставить не за что.
        break;
    }
  }

  void _refreshIfStale() {
    final leftAt = _leftForegroundAt;
    _leftForegroundAt = null;
    if (leftAt == null) {
      return;
    }
    if (DateTime.now().difference(leftAt) < widget.staleAfter) {
      return;
    }
    // Ничего не ждём: экран уже на месте, и обновление должно приехать
    // само, а не задержать возврат в приложение.
    unawaited(
      refreshAppData(ref, scope: AppDataRefreshScope.all, awaitPrimary: false),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
