import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

enum InboxNotificationKind { routeReview, unknown }

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isUnread,
    required this.createdAt,
    this.actorUserId,
    this.actorDisplayName,
    this.targetType,
    this.targetId,
  });

  final String id;
  final InboxNotificationKind kind;
  final String title;
  final String body;
  final String? actorUserId;
  final String? actorDisplayName;
  final String? targetType;
  final String? targetId;
  final bool isUnread;
  final DateTime createdAt;

  String get actorName => actorDisplayName?.trim().isNotEmpty == true
      ? actorDisplayName!
      : 'Путешественник';

  InboxNotification copyWith({bool? isUnread}) {
    return InboxNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      actorUserId: actorUserId,
      actorDisplayName: actorDisplayName,
      targetType: targetType,
      targetId: targetId,
      isUnread: isUnread ?? this.isUnread,
      createdAt: createdAt,
    );
  }

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'] as String? ?? '';
    return InboxNotification(
      id: json['id'] as String,
      kind: kindRaw == 'route_review'
          ? InboxNotificationKind.routeReview
          : InboxNotificationKind.unknown,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      actorUserId: json['actor_user_id'] as String?,
      actorDisplayName: json['actor_display_name'] as String?,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      isUnread: !(json['is_read'] as bool? ?? false),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationsPage {
  const NotificationsPage({required this.items, required this.unreadCount});

  final List<InboxNotification> items;
  final int unreadCount;
}

abstract interface class NotificationsRepository {
  Future<NotificationsPage> list();
  Future<InboxNotification> markRead(String id);
  Future<void> markAllRead();
}

final class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._dio);

  final Dio _dio;

  @override
  Future<NotificationsPage> list() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/me/notifications',
        queryParameters: const {'limit': 50, 'offset': 0},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      final raw = data['items'];
      return NotificationsPage(
        items: raw is List
            ? [
                for (final item in raw)
                  if (item is Map<String, dynamic>)
                    InboxNotification.fromJson(item),
              ]
            : const [],
        unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Future<InboxNotification> markRead(String id) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/me/notifications/$id/read',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return InboxNotification.fromJson(data);
    });
  }

  @override
  Future<void> markAllRead() {
    return guardApiCall(() async {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/me/notifications/read-all',
      );
    });
  }
}

final class MockNotificationsRepository implements NotificationsRepository {
  var _items = <InboxNotification>[
    InboxNotification(
      id: 'n3',
      kind: InboxNotificationKind.routeReview,
      title: 'Новый отзыв',
      body: 'Оставил свой комментарий под вашим маршрутом «Крымская классика»',
      actorDisplayName: 'Никита',
      targetType: 'route',
      targetId: 'mock-route',
      isUnread: true,
      createdAt: DateTime.utc(2026, 1, 2),
    ),
    InboxNotification(
      id: 'n4',
      kind: InboxNotificationKind.routeReview,
      title: 'Новый отзыв',
      body: 'Оставил свой комментарий под вашим маршрутом «Крымская классика»',
      actorDisplayName: 'Никита',
      targetType: 'route',
      targetId: 'mock-route',
      isUnread: false,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  @override
  Future<NotificationsPage> list() async {
    return NotificationsPage(
      items: List.unmodifiable(_items),
      unreadCount: _items.where((n) => n.isUnread).length,
    );
  }

  @override
  Future<InboxNotification> markRead(String id) async {
    _items = [
      for (final item in _items)
        if (item.id == id) item.copyWith(isUnread: false) else item,
    ];
    return _items.firstWhere((n) => n.id == id);
  }

  @override
  Future<void> markAllRead() async {
    _items = [for (final item in _items) item.copyWith(isUnread: false)];
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return MockNotificationsRepository();
  }
  return ApiNotificationsRepository(ref.watch(dioProvider));
});
