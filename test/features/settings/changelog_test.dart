import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/domain/changelog.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_changelog_screen.dart';

import '../../support/test_overrides.dart';

/// The changelog is read by people who do not build the app — a designer, an
/// analyst — so these tests guard the things that would make it useless to
/// them: entries written in implementation terms, or a version with nothing
/// under it.
void main() {
  test('releases are newest first, so the top of the screen is the news', () {
    final versions = appChangelog.map((release) => release.version).toList();
    expect(versions, versions.toList()..sort((a, b) => b.compareTo(a)));
  });

  test('every release says something', () {
    for (final release in appChangelog) {
      expect(release.entries, isNotEmpty, reason: release.version);
    }
  });

  test('only one release is marked as still being built', () {
    expect(appChangelog.where((r) => r.inProgress).length, lessThanOrEqualTo(1));
    // A shipped release carries its date; the one in progress does not.
    for (final release in appChangelog) {
      if (release.inProgress) {
        expect(release.date, isNull, reason: release.version);
      } else {
        expect(release.date, isNotNull, reason: release.version);
      }
    }
  });

  test('entries read as product changes, not as implementation notes', () {
    // A rough guard rather than a style checker: these words only ever show
    // up when an entry is describing the code instead of the app.
    const codeWords = [
      'провайдер',
      'рефактор',
      'эндпоинт',
      'миграци',
      'коммит',
      'API',
      'null',
    ];
    for (final release in appChangelog) {
      for (final entry in release.entries) {
        for (final word in codeWords) {
          expect(
            entry.text.toLowerCase(),
            isNot(contains(word.toLowerCase())),
            reason: '«$word» в записи: ${entry.text}',
          );
        }
        // Long enough to say what changed, short enough to read.
        expect(entry.text.length, greaterThan(20), reason: entry.text);
        expect(entry.text.length, lessThan(300), reason: entry.text);
      }
    }
  });

  testWidgets('the screen lists every version with its changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: testSessionOverrides(onboardingCompleted: true),
        child: const MaterialApp(home: SettingsChangelogScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final release in appChangelog) {
      expect(
        find.text('Версия ${release.version}'),
        findsOneWidget,
        reason: release.version,
      );
    }
    expect(find.text('Готовится'), findsOneWidget);
    expect(find.text('Новое'), findsWidgets);
    expect(find.text('Исправлено'), findsWidgets);
  });
}
