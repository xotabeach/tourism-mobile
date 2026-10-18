import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notices a route page that was asked for but never appeared (FRONTEND-85,
/// spec 47 D11).
///
/// A push from a screen outside the tabs into the tab's `/routes/:id` used
/// to leave an empty page: no crash, no request, nothing to report. Every
/// open goes through [openRouteDetails], which asks this watch to wait; the
/// route page says it was built. If it was not within [timeout], the watch
/// reports a `blank_screen` through [onBlankScreen].
abstract final class RouteOpenWatch {
  static const timeout = Duration(seconds: 3);

  /// Where a blank page is reported: the error journal (FRONTEND-81) sets
  /// it; until then it goes to the debug log.
  static void Function(String routeId, String from) onBlankScreen =
      (routeId, from) {
        debugPrint('route page not shown: $routeId from $from');
      };

  static final _pending = <String, Timer>{};

  /// A route page for [routeId] was asked for from [from].
  static void expect(String routeId, {required String from}) {
    _pending.remove(routeId)?.cancel();
    _pending[routeId] = Timer(timeout, () {
      _pending.remove(routeId);
      onBlankScreen(routeId, from);
    });
  }

  /// The route page for [routeId] was built.
  static void shown(String routeId) => _pending.remove(routeId)?.cancel();

  @visibleForTesting
  static void reset() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
  }
}
