import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/validation/display_name.dart';

void main() {
  group('DisplayNamePolicy', () {
    test('accepts normal names within 20 chars', () {
      expect(DisplayNamePolicy.validationError('Никита'), isNull);
      expect(DisplayNamePolicy.validationError('Ada'), isNull);
      expect(
        DisplayNamePolicy.validationError('x' * DisplayNamePolicy.maxLength),
        isNull,
      );
    });

    test('rejects empty and overlong names', () {
      expect(DisplayNamePolicy.validationError('   '), 'Укажите имя');
      expect(
        DisplayNamePolicy.validationError('x' * 21),
        'Не больше 20 символов',
      );
    });

    test('rejects prohibited language in RU and EN', () {
      expect(
        DisplayNamePolicy.validationError('fuck'),
        'Имя содержит недопустимые слова',
      );
      expect(
        DisplayNamePolicy.validationError('F u c k'),
        'Имя содержит недопустимые слова',
      );
      expect(
        DisplayNamePolicy.validationError('сука'),
        'Имя содержит недопустимые слова',
      );
      expect(
        DisplayNamePolicy.validationError('хуевый'),
        'Имя содержит недопустимые слова',
      );
    });
  });
}
