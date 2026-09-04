import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/components/app_list_skeleton.dart';
import 'package:tourism_mobile/core/design/components/app_skeleton.dart';

void main() {
  testWidgets('the shared list skeleton draws a row per placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppListSkeleton(rows: 3))),
    );
    await tester.pump();

    expect(find.byType(AppShimmer), findsOneWidget);
    // Three rows, each a leading square plus two text bars.
    expect(find.byType(AppSkeleton), findsNWidgets(9));
  });

  testWidgets('it can drop the leading square for text-only lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppListSkeleton(rows: 2, showLeading: false)),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeleton), findsNWidgets(4));
  });

  test('no screen falls back to a bare spinner while loading', () {
    // A spinner says "something is happening"; a skeleton says what is about
    // to appear and holds its space. Loading states were audited and moved
    // over on 2026-09-04 — this keeps a new screen from quietly regressing.
    //
    // Deliberate exceptions: paging footers (the list is already on screen,
    // and a small spinner under it reads correctly) and in-button progress.
    const allowed = {
      'lib/features/home/presentation/all_list_screen.dart', // paging footer
      'lib/features/route_execution/presentation/route_execution_screen.dart',
    };

    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('CircularProgressIndicator')) continue;
      if (allowed.contains(entity.path)) continue;
      // Only the async-loading branch matters; a spinner inside a button
      // that is mid-submit is the right control.
      if (RegExp(
        r'loading: \(\) =>[^;]{0,120}CircularProgressIndicator',
      ).hasMatch(source)) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Эти экраны грузятся спиннером: $offenders',
    );
  });
}
