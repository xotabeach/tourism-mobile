import 'dart:io';
import 'dart:typed_data';

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

  test('every static cut has the punctuation the app prints', () {
    // Missing glyphs are not tofu on a device: Flutter quietly takes them from
    // the system font, so «0/120» or a dash looked off in the middle of Rubik
    // text (FRONTEND-35). Cut from the variable file by
    // scripts/build_rubik_static.py.
    const needed =
        '/«»—–…№"„“”‘’·•−×°%€₽@&()[]{}<>=+:;,.!?-0123456789'
        'ЁёАЯаяABCXYZabcxyz';
    for (final file in [
      'Rubik-Regular.ttf',
      'Rubik-Medium.ttf',
      'Rubik-SemiBold.ttf',
      'Rubik-Bold.ttf',
    ]) {
      final covered = _codePoints(File('assets/fonts/$file').readAsBytesSync());
      final missing = [
        for (final rune in needed.runes)
          if (!covered.contains(rune)) String.fromCharCode(rune),
      ];
      expect(missing, isEmpty, reason: '$file lacks ${missing.join(' ')}');
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

/// Code points a TrueType font maps, read from its `cmap` table (formats 4
/// and 12 cover every font we ship).
Set<int> _codePoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tables = data.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmap = data.getUint32(record + 8);
  }
  expect(cmap, isNot(-1), reason: 'no cmap table');

  final result = <int>{};
  final subtables = data.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final start = cmap + data.getUint32(cmap + 4 + 8 * i + 4);
    final format = data.getUint16(start);
    if (format == 4) {
      final segments = data.getUint16(start + 6) ~/ 2;
      final ends = start + 14;
      final starts = ends + 2 * segments + 2;
      for (var s = 0; s < segments; s++) {
        final from = data.getUint16(starts + 2 * s);
        final to = data.getUint16(ends + 2 * s);
        if (from == 0xFFFF) continue;
        for (var code = from; code <= to; code++) {
          result.add(code);
        }
      }
    } else if (format == 12) {
      final groups = data.getUint32(start + 12);
      for (var g = 0; g < groups; g++) {
        final at = start + 16 + 12 * g;
        final from = data.getUint32(at);
        final to = data.getUint32(at + 4);
        for (var code = from; code <= to; code++) {
          result.add(code);
        }
      }
    }
  }
  return result;
}
