import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/application/support_providers.dart';
import 'package:tourism_mobile/features/settings/data/support_repository.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_support_screens.dart';

void main() {
  testWidgets('shows an operator reply while the chat remains open', (
    tester,
  ) async {
    final repository = _LiveChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: SettingsChatScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Первое сообщение'), findsOneWidget);
    expect(find.text('КРЫМТРИП'), findsOneWidget);
    final composer = find.byType(TextField);
    expect(
      tester.getRect(composer).bottom,
      greaterThan(tester.getSize(find.byType(Scaffold).first).height - 100),
    );

    await tester.tap(composer);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(find.text('Первое сообщение'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('chat-empty-space')));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );

    repository.addOperatorReply('Ответ оператора');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Ответ оператора'), findsOneWidget);
  });

  testWidgets('keeps keyboard focus after sending a message', (tester) async {
    final repository = _LiveChatRepository(canSend: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SettingsChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byType(TextField);
    await tester.tap(composer);
    await tester.enterText(composer, 'Второе сообщение');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Второе сообщение'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('scrolls latest message into view when keyboard opens', (
    tester,
  ) async {
    final repository = _LiveChatRepository(
      extraMessages: List.generate(
        12,
        (index) => SupportMessage(
          id: 'bulk-$index',
          author: 'user',
          body: 'Сообщение $index',
          createdAt: DateTime.utc(2026, 8, 1, 11, index),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supportRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SettingsChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    final controller = tester.widget<Scrollable>(scrollable).controller!;
    // Move away from the bottom so focus/keyboard must pull latest into view.
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(controller.position.pixels, 0);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    // Simulate shell-resized keyboard via raw view metrics (parent Scaffold
    // strips MediaQuery.viewInsets for nested chat screens).
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();

    expect(
      controller.position.pixels,
      closeTo(controller.position.maxScrollExtent, 1),
    );
    final lastMessageBottom = tester.getRect(find.text('Сообщение 11')).bottom;
    final composerTop = tester.getRect(find.byType(TextField)).top;
    expect(lastMessageBottom, lessThanOrEqualTo(composerTop + 8));
  });
}

final class _LiveChatRepository implements SupportRepository {
  _LiveChatRepository({
    this.canSend = false,
    List<SupportMessage>? extraMessages,
  }) : _ticket = _ticketWithMessages([
         SupportMessage(
           id: 'user-1',
           author: 'user',
           body: 'Первое сообщение',
           createdAt: DateTime.utc(2026, 8, 1, 11),
         ),
         ...?extraMessages,
       ]);

  final bool canSend;
  SupportTicket _ticket;

  static SupportTicket _ticketWithMessages(List<SupportMessage> messages) {
    final now = DateTime.utc(2026, 8, 1);
    return SupportTicket(
      id: 'chat-1',
      kind: 'chat',
      subject: 'Чат поддержки',
      status: 'open',
      createdAt: now,
      updatedAt: now,
      messages: messages,
    );
  }

  @override
  Future<SupportMessage> addMessage({
    required String ticketId,
    required String body,
  }) async {
    if (!canSend) {
      throw UnimplementedError();
    }
    final message = SupportMessage(
      id: 'user-${_ticket.messages.length + 1}',
      author: 'user',
      body: body,
      createdAt: DateTime.utc(2026, 8, 1, 12, _ticket.messages.length),
    );
    _ticket = _ticketWithMessages([..._ticket.messages, message]);
    return message;
  }

  void addOperatorReply(String body) {
    final reply = SupportMessage(
      id: 'operator-${_ticket.messages.length}',
      author: 'operator',
      body: body,
      createdAt: DateTime.utc(2026, 8, 1, 12),
    );
    _ticket = _ticketWithMessages([..._ticket.messages, reply]);
  }

  @override
  Future<SupportTicket> createTicket({
    required String kind,
    required String subject,
    required String body,
    String? routeId,
  }) async => throw UnimplementedError();

  @override
  Future<SupportTicket> getTicket(String ticketId) async => _ticket;

  @override
  Future<List<SupportTicket>> listTickets() async => [_ticket];

  @override
  Future<SupportAttachment> uploadAttachment({
    required String ticketId,
    required String filePath,
  }) async => throw UnimplementedError();
}
