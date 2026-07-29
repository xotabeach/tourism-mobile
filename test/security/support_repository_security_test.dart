import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/settings/data/support_repository.dart';

void main() {
  test('mock support stores ticket messages as plain data', () async {
    final repo = MockSupportRepository();
    final ticket = await repo.createTicket(
      kind: 'chat',
      subject: 'Help',
      body: '<script>alert(1)</script>',
    );
    expect(ticket.messages.first.body, '<script>alert(1)</script>');
    expect(ticket.messages.any((m) => m.author == 'assistant'), isTrue);

    final msg = await repo.addMessage(
      ticketId: ticket.id,
      body: "'; DROP TABLE support_tickets;--",
    );
    expect(msg.body, startsWith("';"));
  });
}
