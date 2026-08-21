/// Topic / intent classification for route-match AI chat.
///
/// Local optimistic guard. Backend must re-check the same classes when
/// `/route-builder/sessions/.../messages` lands. Crisis handling stays in
/// [routeMatchLooksLikeSelfHarm].
library;

import 'package:tourism_mobile/features/route_match/presentation/route_match_ai_safety.dart';

enum RouteMatchChatIntent {
  crisis,
  greeting,
  onTopicTravel,
  offTopic,
  injectionAttempt,
}

/// Classifies user text for canned replies before any LLM call.
RouteMatchChatIntent classifyRouteMatchChatIntent(String raw) {
  final text = raw.toLowerCase().replaceAll('ё', 'е').trim();
  if (text.isEmpty) {
    return RouteMatchChatIntent.onTopicTravel;
  }
  if (routeMatchLooksLikeSelfHarm(raw)) {
    return RouteMatchChatIntent.crisis;
  }
  if (_looksLikeInjection(text)) {
    return RouteMatchChatIntent.injectionAttempt;
  }
  if (_looksLikeGreeting(text)) {
    return RouteMatchChatIntent.greeting;
  }
  if (_looksLikeOffTopic(text)) {
    return RouteMatchChatIntent.offTopic;
  }
  return RouteMatchChatIntent.onTopicTravel;
}

/// Canonical canned replies for hard safety / off-topic only.
/// Greeting is handled by the LLM with system rules (no mock small-talk).
String cannedReplyForIntent(RouteMatchChatIntent intent) {
  switch (intent) {
    case RouteMatchChatIntent.crisis:
      return routeMatchCrisisSupportReply;
    case RouteMatchChatIntent.greeting:
      return '';
    case RouteMatchChatIntent.offTopic:
      return routeMatchOffTopicReply;
    case RouteMatchChatIntent.injectionAttempt:
      return routeMatchInjectionReply;
    case RouteMatchChatIntent.onTopicTravel:
      return '';
  }
}

const String routeMatchOffTopicReply =
    'Я могу помогать только с подбором маршрутов и мест в Крыму. '
    'Давайте вернёмся к поездке: город старта, длительность или интересы?';

const String routeMatchInjectionReply =
    'Я работаю только как помощник по маршрутам КрымТрип и не меняю свои '
    'правила. Чем помочь с маршрутом?';

bool _looksLikeGreeting(String text) {
  const greetings = <String>[
    'привет',
    'здравствуй',
    'здравствуйте',
    'добрый день',
    'доброе утро',
    'добрый вечер',
    'хай',
    'hello',
    'hi!',
    'как дела',
    'как ты',
    'как вы',
  ];
  if (text.length > 80) {
    return false;
  }
  for (final g in greetings) {
    if (text == g ||
        text.startsWith('$g ') ||
        text.startsWith('$g!') ||
        text.startsWith('$g,')) {
      if (_hasTravelCue(text)) {
        return false;
      }
      return true;
    }
  }
  return false;
}

bool _looksLikeInjection(String text) {
  const markers = <String>[
    'игнорируй инструкции',
    'игнорируй правила',
    'ignore previous',
    'ignore all',
    'system prompt',
    'jailbreak',
    'developer mode',
    'режим разработчика',
  ];
  for (final m in markers) {
    if (text.contains(m)) {
      return true;
    }
  }
  return false;
}

bool _looksLikeOffTopic(String text) {
  const offTopic = <String>[
    'напиши код',
    'напиши программу',
    'написать код',
    'python',
    'javascript',
    'typescript',
    'sql запрос',
    'dockerfile',
    'kubernetes',
    'рецепт',
    'как приготовить',
    'домашнее задание',
    'реши задачу',
    'курсовую',
    'диплом',
    'переведи текст',
    'сочини стих',
    'напиши сочинение',
    'криптовалют',
    'инвестиц',
    'медицин',
    'диагноз',
    'юридическ',
    'договор купли',
  ];
  for (final phrase in offTopic) {
    if (text.contains(phrase)) {
      return true;
    }
  }
  if (text.contains('```') || text.contains('def ') || text.contains('fn ')) {
    return true;
  }
  return false;
}

bool _hasTravelCue(String text) {
  const cues = <String>[
    'маршрут',
    'крым',
    'ялт',
    'севастопол',
    'алушт',
    'поездк',
    'экскурси',
    'пляж',
    'горы',
    'дворец',
    'место',
    'локац',
    'прогулк',
    'турист',
  ];
  for (final c in cues) {
    if (text.contains(c)) {
      return true;
    }
  }
  return false;
}
