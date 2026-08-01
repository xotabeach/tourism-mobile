/// Display-name policy mirrored with the backend identity module.
class DisplayNamePolicy {
  DisplayNamePolicy._();

  static const int minLength = 1;
  static const int maxLength = 20;

  static const Set<String> _blockedTerms = {
    'fuck',
    'fucker',
    'fucking',
    'shit',
    'bullshit',
    'bitch',
    'asshole',
    'bastard',
    'cunt',
    'dick',
    'cock',
    'pussy',
    'whore',
    'slut',
    'faggot',
    'nigger',
    'nigga',
    'motherfucker',
    'блять',
    'блядь',
    'бляд',
    'сука',
    'суки',
    'хуй',
    'хуя',
    'хуе',
    'хуи',
    'пизда',
    'пиздец',
    'ебать',
    'ебал',
    'ебан',
    'ебаный',
    'пидор',
    'пидар',
    'педик',
    'мудак',
    'мудила',
    'гандон',
    'залупа',
    'еблан',
    'мразь',
    'дебил',
    'уебок',
  };

  static const Set<String> _shortWholeOnly = {'ass', 'sex', 'fag', 'cum'};

  static const Set<String> _rootSubstrings = {
    'хуй',
    'хуе',
    'хуя',
    'хуи',
    'бляд',
    'пизд',
    'ебал',
    'ебан',
    'fuck',
    'shit',
    'dick',
    'cunt',
  };

  static final RegExp _nonLetter = RegExp(r'[^a-zа-яё]+', unicode: true);

  /// Returns a localized error, or null when [value] is acceptable.
  static String? validationError(String? value) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) {
      return 'Укажите имя';
    }
    if (cleaned.length > maxLength) {
      return 'Не больше $maxLength символов';
    }
    if (containsProhibitedLanguage(cleaned)) {
      return 'Имя содержит недопустимые слова';
    }
    return null;
  }

  static bool containsProhibitedLanguage(String value) {
    final collapsed = _normalizeForScan(value);
    if (collapsed.isEmpty) {
      return false;
    }
    for (final root in _rootSubstrings) {
      if (collapsed.contains(root)) {
        return true;
      }
    }
    for (final term in _blockedTerms) {
      if (term.length >= 4 && collapsed.contains(term)) {
        return true;
      }
      if (collapsed == term) {
        return true;
      }
    }
    for (final token in _tokens(value)) {
      if (_blockedTerms.contains(token) || _shortWholeOnly.contains(token)) {
        return true;
      }
      for (final term in _blockedTerms) {
        if (term.length >= 4 && token.contains(term)) {
          return true;
        }
      }
    }
    return false;
  }

  static String _normalizeForScan(String value) {
    final folded = value.toLowerCase().replaceAll('ё', 'е');
    final leet = _applyLeet(folded);
    return leet.replaceAll(_nonLetter, '');
  }

  static Iterable<String> _tokens(String value) {
    final folded = _applyLeet(value.toLowerCase().replaceAll('ё', 'е'));
    return folded.split(_nonLetter).where((token) => token.isNotEmpty);
  }

  static String _applyLeet(String value) {
    return value
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('!', 'i');
  }
}
