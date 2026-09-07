import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/route_match/presentation/route_match_widgets.dart';

double identityPx(double value) => value;

Widget _chat({
  required bool sessionFull,
  required bool dismissed,
  List<RouteChatMessage> messages = const [],
  VoidCallback? onShow,
  VoidCallback? onSaveAllDrafts,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RouteAiChatView(
        header: const SizedBox(height: 60),
        px: identityPx,
        messages: messages,
        scrollController: ScrollController(),
        composerController: TextEditingController(),
        composerFocus: FocusNode(),
        typing: false,
        canSend: true,
        onChanged: (_) {},
        onSend: () {},
        bottomInset: 0,
        sessionFull: sessionFull,
        limitNoticeDismissed: dismissed,
        onNewChat: () {},
        onShowLimitNotice: onShow,
        onSaveAllDrafts: onSaveAllDrafts,
      ),
    ),
  );
}

void main() {
  testWidgets('an open chat shows the composer and no limit notice', (
    tester,
  ) async {
    await tester.pumpWidget(_chat(sessionFull: false, dismissed: false));
    await tester.pump();

    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-limit-notice')), findsNothing);
  });

  testWidgets('a full chat replaces the composer with the limit notice', (
    tester,
  ) async {
    await tester.pumpWidget(_chat(sessionFull: true, dismissed: false));
    await tester.pump();

    expect(find.byKey(const ValueKey('chat-limit-notice')), findsOneWidget);
    expect(find.text('Диалог достиг предела длины'), findsOneWidget);
    expect(find.text('Создать новый чат'), findsOneWidget);
    // Writing is over, but the transcript must stay reachable.
    expect(find.byType(ChatComposer), findsNothing);
  });

  testWidgets('dismissing the notice keeps the chat locked but readable', (
    tester,
  ) async {
    var shown = false;
    await tester.pumpWidget(
      _chat(
        sessionFull: true,
        dismissed: true,
        onShow: () => shown = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-limit-notice')), findsNothing);
    expect(find.byType(ChatComposer), findsNothing, reason: 'still locked');

    await tester.tap(find.textContaining('Диалог завершён'));
    await tester.pump();
    expect(shown, isTrue, reason: 'the notice can be brought back');
  });

  testWidgets('the drafts offer appears only when the chat built something', (
    tester,
  ) async {
    await tester.pumpWidget(
      _chat(sessionFull: true, dismissed: false, onSaveAllDrafts: () {}),
    );
    await tester.pump();
    expect(find.text('Сохранить маршруты в черновики'), findsNothing);

    await tester.pumpWidget(
      _chat(
        sessionFull: true,
        dismissed: false,
        onSaveAllDrafts: () {},
        messages: const [
          RouteChatMessage(
            fromAgent: true,
            text: 'Собрал маршрут',
            time: '12:00',
            proposalId: 'proposal-1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Сохранить маршруты в черновики'), findsOneWidget);
  });
}
