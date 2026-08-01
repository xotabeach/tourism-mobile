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
}

final class _LiveChatRepository implements SupportRepository {
  _LiveChatRepository() : _ticket = _ticketWithMessages(const []);

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
  }) async => throw UnimplementedError();

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
  Future<List<SupportTicket>> listTickets() async {
    final firstMessage = SupportMessage(
      id: 'user-1',
      author: 'user',
      body: 'Первое сообщение',
      createdAt: DateTime.utc(2026, 8, 1, 11),
    );
    _ticket = _ticketWithMessages([firstMessage, ..._ticket.messages]);
    return [_ticket];
  }
}
