import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/theme/app_theme.dart';

/// Rubik must ship as static cuts with explicit weights. With the variable
/// file alone Flutter drew 500, 600 and 700 as one synthetic bold
/// (FRONTEND-33), so medium, semibold and bold text all looked the same.
void main() {
  test('Rubik is declared as static cuts with their weights', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('Rubik-VariableFont')));
    for (final (file, weight) in [
      ('Rubik-Regular.ttf', 400),
      ('Rubik-Medium.ttf', 500),
      ('Rubik-SemiBold.ttf', 600),
      ('Rubik-Bold.ttf', 700),
    ]) {
      expect(
        RegExp(
          'asset: assets/fonts/${RegExp.escape(file)}\\s+weight: $weight',
        ).hasMatch(pubspec),
        isTrue,
        reason: '$file should be declared with weight $weight',
      );
      expect(File('assets/fonts/$file').existsSync(), isTrue);
    }
  });

  test('the whole theme uses Rubik', () {
    final theme = AppTheme.light;
    for (final style in [
      theme.textTheme.bodyMedium,
      theme.textTheme.titleMedium,
      theme.textTheme.labelLarge,
      theme.primaryTextTheme.bodyMedium,
    ]) {
      expect(style?.fontFamily, AppFonts.rubik);
    }
  });
}
