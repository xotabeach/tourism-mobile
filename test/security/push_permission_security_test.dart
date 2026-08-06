import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/notifications/push_permission.dart';

void main() {
  group('effectivePushEnabled', () {
    test('off when preference is off', () {
      expect(
        effectivePushEnabled(
          preferEnabled: false,
          osStatus: AuthorizationStatus.authorized,
          firebaseConfigured: true,
        ),
        isFalse,
      );
    });

    test('follows preference when Firebase is not configured', () {
      expect(
        effectivePushEnabled(
          preferEnabled: true,
          osStatus: AuthorizationStatus.denied,
          firebaseConfigured: false,
        ),
        isTrue,
      );
    });

    test('follows preference when OS status is unknown', () {
      expect(
        effectivePushEnabled(
          preferEnabled: true,
          osStatus: null,
          firebaseConfigured: true,
        ),
        isTrue,
      );
    });

    test('requires OS authorization when Firebase is configured', () {
      expect(
        effectivePushEnabled(
          preferEnabled: true,
          osStatus: AuthorizationStatus.denied,
          firebaseConfigured: true,
        ),
        isFalse,
      );
      expect(
        effectivePushEnabled(
          preferEnabled: true,
          osStatus: AuthorizationStatus.authorized,
          firebaseConfigured: true,
        ),
        isTrue,
      );
      expect(
        effectivePushEnabled(
          preferEnabled: true,
          osStatus: AuthorizationStatus.provisional,
          firebaseConfigured: true,
        ),
        isTrue,
      );
    });
  });

  group('pushToggleSubtitle', () {
    test('mentions system settings when OS denied', () {
      expect(
        pushToggleSubtitle(
          preferEnabled: true,
          osStatus: AuthorizationStatus.denied,
          firebaseConfigured: true,
        ),
        'Выключены в настройках системы',
      );
    });

    test('default copy when allowed or unknown', () {
      expect(
        pushToggleSubtitle(
          preferEnabled: true,
          osStatus: AuthorizationStatus.authorized,
          firebaseConfigured: true,
        ),
        'Уведомления из приложения',
      );
    });
  });

  group('isOsPushAuthorized', () {
    test('rejects denied and notDetermined', () {
      expect(isOsPushAuthorized(AuthorizationStatus.denied), isFalse);
      expect(isOsPushAuthorized(AuthorizationStatus.notDetermined), isFalse);
      expect(isOsPushAuthorized(AuthorizationStatus.authorized), isTrue);
    });
  });
}
