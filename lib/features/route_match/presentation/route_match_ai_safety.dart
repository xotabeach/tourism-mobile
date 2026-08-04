/// Safety / moderation helpers for route-builder AI chat.
///
/// Production responses never joke about self-harm and never generate routes
/// while a crisis signal is active.
library;

/// Detects explicit self-harm / farewell / cliff-jump intent in user text.
bool routeMatchLooksLikeSelfHarm(String raw) {
  final text = raw.toLowerCase().replaceAll('ё', 'е');
  if (text.trim().isEmpty) {
    return false;
  }
  const phrases = <String>[
    'прыгну со скалы',
    'прыгнуть со скалы',
    'со скалы на закате',
    'покончить с собой',
    'покончу с собой',
    'убить себя',
    'убью себя',
    'самоубий',
    'суицид',
    'попрощаться с жизнью',
    'прощаюсь с жизнью',
    'не хочу жить',
    'хочу умереть',
    'последний закат',
    'разбежавшись прыгну',
  ];
  for (final phrase in phrases) {
    if (text.contains(phrase)) {
      return true;
    }
  }
  return false;
}

/// Calm supportive reply used when [routeMatchLooksLikeSelfHarm] is true.
const String routeMatchCrisisSupportReply =
    'Мне важно, что тебе сейчас тяжело. Я не могу помочь с планами '
    'причинить себе вред и не буду подбирать маршрут в этом контексте.\n\n'
    'Если ты в непосредственной опасности — пожалуйста, сразу свяжись с '
    'экстренной службой или с близким человеком, которому доверяешь. '
    'Ты не один, и поддержка рядом важнее любого маршрута.\n\n'
    'Если хочешь, расскажи, чем я могу помочь безопасно: спокойная прогулка, '
    'люди рядом, тихие места у моря — без риска для жизни.';

/// Demo / golden-only thread. Never used as a production agent reply.
abstract final class RouteBuilderDemoState {
  static const String pixelAgentGreeting =
      'Здравствуй Путник! Что должно быть в твоём идеальном маршруте?';

  /// Explicit line breaks match the design frame for golden tests only.
  static const String pixelUserMessage =
      'Мне очень тоскливо последние\n'
      'дни: меня бросила жена, меня\n'
      'уволили с работы, а ещё у меня\n'
      'долгов на 200 000 рублей.\n\n'
      'Я бы хотел отправиться в\n'
      'одиночный маршрут. Хочу\n'
      'посмотреть на свой последний\n'
      'закат перед тем как под песню\n'
      'группы “Король и Шут” я\n'
      'разбежавшись прыгну со скалы\n'
      'на закате.\n\n'
      'Перед этим я бы хотел\n'
      'посмаковать бокал пива и\n'
      'вкусить самый нежный стейк в\n'
      'ресторане на берегу черного\n'
      'моря в полном одиночестве.';

  /// Intentionally vulgar design-frame placeholder — golden/demo only.
  static const String pixelAgentShort = 'пиздец';
}
