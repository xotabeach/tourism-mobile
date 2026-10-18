import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_execution/application/execution_error_text.dart';

void main() {
  test('the hint follows the server code, whatever the message says', () {
    // The same code with any wording gives the same hint.
    for (final message in ['Conflict', 'Нельзя', '']) {
      expect(
        executionErrorText(
          RejectedFailure(message, 'route_execution_stop_not_last'),
        ),
        'Снять можно только последнюю отметку',
      );
    }
    expect(
      executionErrorText(
        const UnexpectedFailure('x', 'required_stops_incomplete'),
      ),
      'Отметьте или пропустите обязательные точки, чтобы завершить',
    );
    expect(
      executionErrorText(const RejectedFailure('x', 'no_stops_marked')),
      'Отметьте хотя бы одну точку, чтобы завершить',
    );
    expect(
      executionErrorText(const RejectedFailure('x', activeRunConflictCode)),
      'Сначала завершите текущий маршрут',
    );
    expect(
      executionErrorText(
        const RejectedFailure('x', 'route_execution_not_active'),
      ),
      'Прохождение уже завершено или на паузе',
    );
    expect(
      executionErrorText(
        const NotFoundFailure('x', 'route_execution_not_found'),
      ),
      'Прохождение не найдено. Откройте маршрут заново',
    );
  });

  test('a message that only looks like a known case is not guessed', () {
    // These texts used to be matched by substring.
    for (final message in [
      'HTTP 409',
      'Network is fine, the request is wrong',
      'route_execution_stop_not_last',
      'Сначала завершите текущий маршрут',
    ]) {
      expect(
        executionErrorText(UnexpectedFailure(message)),
        'Не удалось обновить прохождение',
      );
    }
    expect(
      executionErrorText(StateError('409 connection')),
      'Не удалось обновить прохождение',
    );
  });

  test('no connection and a slow server are told apart by kind', () {
    expect(
      executionErrorText(const NetworkFailure()),
      'Нет соединения. Попробуйте ещё раз',
    );
    expect(
      executionErrorText(
        const NetworkFailure('Request timed out', NetworkFailure.timeoutCode),
      ),
      'Сервер долго не отвечает. Попробуйте ещё раз',
    );
  });

  test('another run in the way has its own hint', () {
    expect(
      executionErrorText(const AnotherRunInProgress()),
      'Сначала завершите текущий маршрут',
    );
  });
}
