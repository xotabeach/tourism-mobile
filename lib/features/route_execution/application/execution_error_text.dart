import 'package:tourism_mobile/core/errors/app_failure.dart';

/// Another route is being walked: this one cannot be started or opened.
class AnotherRunInProgress implements Exception {
  const AnotherRunInProgress();
}

/// API code of a start refused because another run is in progress.
const activeRunConflictCode = 'active_route_execution_exists';

/// What to tell the walker when an action of a run failed.
///
/// Decided by the kind of failure and the server's `error.code`, never by
/// the wording of a message: the server is free to reword its texts.
String executionErrorText(Object error) {
  if (error is AnotherRunInProgress) {
    return 'Сначала завершите текущий маршрут';
  }
  if (error is NetworkFailure) {
    return error.code == NetworkFailure.timeoutCode
        ? 'Сервер долго не отвечает. Попробуйте ещё раз'
        : 'Нет соединения. Попробуйте ещё раз';
  }
  final code = error is AppFailure ? error.code : null;
  return switch (code) {
    activeRunConflictCode => 'Сначала завершите текущий маршрут',
    'required_stops_incomplete' =>
      'Отметьте или пропустите обязательные точки, чтобы завершить',
    'no_stops_marked' => 'Отметьте хотя бы одну точку, чтобы завершить',
    'route_execution_stop_not_last' => 'Снять можно только последнюю отметку',
    'route_execution_stop_already_marked' =>
      'Точка уже отмечена, пропустить её нельзя',
    'route_execution_not_active' => 'Прохождение уже завершено или на паузе',
    'route_execution_not_found' || 'route_execution_stop_not_found' =>
      'Прохождение не найдено. Откройте маршрут заново',
    'route_has_no_stops' => 'В маршруте нет точек, пройти его нельзя',
    'route_quality_unusable' =>
      'Маршрут пока нельзя пройти: для него не построена дорога',
    'route_blocked_by_road_event' =>
      'Маршрут временно закрыт из-за события на дороге',
    'route_not_found' => 'Маршрут не найден',
    _ => 'Не удалось обновить прохождение',
  };
}
