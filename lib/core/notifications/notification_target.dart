import 'dart:async';

import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/routing/app_router.dart';

/// Opens what a notification is about (FRONTEND-74), the same way from the
/// inbox and from a push: an article or a route right at the comment or the
/// review, a profile, a group, an achievement or the support chat.
///
/// [anchorId] is the comment or review inside the target (BACKEND-67); an
/// older server sends none and the screen simply opens at the top. Returns
/// false when there is nothing to open.
bool openNotificationTarget(
  GoRouter router, {
  required String? targetType,
  required String? targetId,
  String? anchorId,
}) {
  final id = targetId == null || targetId.isEmpty ? null : targetId;
  final anchor = anchorId == null || anchorId.isEmpty ? null : anchorId;
  switch (targetType) {
    // Notifications open over everything, outside the tabs: the
    // root-level route page (FRONTEND-85).
    case 'route' when id != null:
      openRouteDetailsFromRouter(router, id, reviewId: anchor);
    case 'article' when id != null:
      unawaited(
        router.pushNamed(
          AppRouteNames.articleDetails,
          pathParameters: {'id': id},
          queryParameters: {'comment': ?anchor},
        ),
      );
    case 'user' when id != null:
      unawaited(
        router.pushNamed(
          AppRouteNames.userProfile,
          pathParameters: {'userId': id},
        ),
      );
    case 'companion_group' when id != null:
      unawaited(
        router.pushNamed(
          AppRouteNames.companionGroup,
          pathParameters: {'groupId': id},
        ),
      );
    case 'achievement':
      unawaited(
        router.pushNamed(
          AppRouteNames.achievements,
          queryParameters: {'achievementId': ?id},
        ),
      );
    case 'support_ticket':
      unawaited(router.pushNamed(AppRouteNames.settingsChat));
    case 'inbox':
      // Anti-fraud notices: the message lives in the inbox.
      unawaited(router.pushNamed(AppRouteNames.settingsNotificationsInbox));
    default:
      return false;
  }
  return true;
}
