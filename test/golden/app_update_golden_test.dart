import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/theme/app_theme.dart';
import 'package:tourism_mobile/features/app_update/application/app_update_controller.dart';
import 'package:tourism_mobile/features/app_update/data/version_policy_repository.dart';
import 'package:tourism_mobile/features/app_update/domain/version_policy.dart';
import 'package:tourism_mobile/features/app_update/presentation/app_update_host.dart';

const _key = ValueKey('app-update-golden');

final _skipPixelGoldens =
    !Platform.isMacOS || Platform.environment['SKIP_PIXEL_GOLDENS'] == '1';

/// BACKEND-5: the soft prompt and the blocking screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  for (final (name, policy) in [
    (
      'app_update_soft',
      VersionPolicy(
        kind: UpdateKind.soft,
        latestVersion: '0.3.1',
        hardAt: DateTime(2026, 10, 1, 12),
        downloadUrl: 'https://example.org/download',
      ),
    ),
    (
      'app_update_hard',
      const VersionPolicy(
        kind: UpdateKind.hard,
        latestVersion: '0.3.1',
        downloadUrl: 'https://example.org/download',
      ),
    ),
  ]) {
    testWidgets('golden $name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdateControllerProvider.overrideWith(
              (ref) => AppUpdateController(
                repository: _Fixed(policy),
                snoozeStore: MemoryUpdateSnoozeStore(),
                supported: true,
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const RepaintBoundary(
              key: _key,
              child: Stack(
                children: [
                  Scaffold(
                    body: Center(child: Text('Главный экран приложения')),
                  ),
                  AppUpdateHost(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_key),
        matchesGoldenFile('goldens/$name.png'),
        skip: _skipPixelGoldens,
      );
    });
  }
}

class _Fixed implements VersionPolicyRepository {
  const _Fixed(this.policy);

  final VersionPolicy policy;

  @override
  Future<VersionPolicy> fetch() async => policy;
}

Future<void> _loadFonts() async {
  final rubik = FontLoader('Rubik')
    ..addFont(rootBundle.load('assets/fonts/Rubik-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Rubik-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Rubik-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Rubik-Bold.ttf'));
  await rubik.load();
  final materialIcons = File(
    '${_flutterSdkRoot().path}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  final icons = FontLoader('MaterialIcons')
    ..addFont(materialIcons.readAsBytes().then(ByteData.sublistView));
  await icons.load();
}

Directory _flutterSdkRoot() {
  var current = File(Platform.resolvedExecutable).parent;
  while (current.parent.path != current.path) {
    if (File('${current.path}/bin/flutter').existsSync()) return current;
    current = current.parent;
  }
  throw StateError('Unable to locate the active Flutter SDK');
}
