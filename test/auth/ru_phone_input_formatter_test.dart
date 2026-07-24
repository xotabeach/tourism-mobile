import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/auth/presentation/ru_phone_input_formatter.dart';

void main() {
  test('starts formatting from +7 and completes RU mobile', () {
    expect(RuPhoneInputFormatter.format(''), '+7 ');
    expect(RuPhoneInputFormatter.format('9991234567'), '+7 999 123-45-67');
    expect(RuPhoneInputFormatter.format('89991234567'), '+7 999 123-45-67');
    expect(
      RuPhoneInputFormatter.format('+7 999 123-45-67'),
      '+7 999 123-45-67',
    );
    expect(RuPhoneInputFormatter.isComplete('+7 999 123-45-67'), isTrue);
    expect(RuPhoneInputFormatter.toE164('+7 999 123-45-67'), '+79991234567');
  });

  test('rejects incomplete numbers', () {
    expect(RuPhoneInputFormatter.isComplete('+7 999'), isFalse);
    expect(RuPhoneInputFormatter.isComplete('9991234567'), isFalse);
  });
}
