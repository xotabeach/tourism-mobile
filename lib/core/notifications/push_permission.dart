import 'package:firebase_messaging/firebase_messaging.dart';

/// Whether the OS will deliver system tray notifications for this status.
bool isOsPushAuthorized(AuthorizationStatus status) {
  return status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

/// Effective push toggle: app preference AND OS permission when known.
///
/// [osStatus] `null` means "unknown / Firebase not ready" — fall back to the
/// in-app preference only (tests, pre-bootstrap, unconfigured platforms).
bool effectivePushEnabled({
  required bool preferEnabled,
  required AuthorizationStatus? osStatus,
  required bool firebaseConfigured,
}) {
  if (!preferEnabled) {
    return false;
  }
  if (!firebaseConfigured || osStatus == null) {
    return true;
  }
  return isOsPushAuthorized(osStatus);
}

String pushToggleSubtitle({
  required bool preferEnabled,
  required AuthorizationStatus? osStatus,
  required bool firebaseConfigured,
}) {
  if (!firebaseConfigured || osStatus == null) {
    return 'Уведомления из приложения';
  }
  if (osStatus == AuthorizationStatus.denied) {
    return 'Выключены в настройках системы';
  }
  if (preferEnabled && isOsPushAuthorized(osStatus)) {
    return 'Уведомления из приложения';
  }
  return 'Уведомления из приложения';
}
