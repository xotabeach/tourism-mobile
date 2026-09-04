import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/domain/route_publish_repository.dart';

/// The current backend exposes route reads only. Keeping this as an explicit
/// adapter prevents the form from posting to an invented or unstable endpoint.
final class UnavailableRoutePublicationRepository
    implements RoutePublicationRepository {
  const UnavailableRoutePublicationRepository();

  @override
  Future<void> discardDraft(String routeId) {
    throw const UnexpectedFailure(
      'Не удалось удалить серверный черновик. Попробуйте позже.',
    );
  }

  @override
  Future<RouteDraft> loadForEdit(String routeId) {
    throw const UnexpectedFailure(
      'Сервис публикации ещё не подключён — маршрут нельзя открыть на правку.',
    );
  }

  @override
  Future<RoutePublicationReceipt> saveDraft(RouteDraft draft) {
    return _unavailable();
  }

  @override
  Future<RoutePublicationReceipt> submit(RouteDraft draft) {
    return _unavailable();
  }

  @override
  Future<RoutePublicationReceipt> withdraw(String routeId) {
    return _unavailable();
  }

  Future<RoutePublicationReceipt> _unavailable() {
    throw const UnexpectedFailure(
      'Сервис публикации ещё не подключён. Черновик сохранён — попробуйте позже.',
    );
  }
}
