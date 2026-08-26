import 'package:dio/dio.dart';

import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/network/api_guard.dart';

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String body;
  final DateTime createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String,
      author: json['author'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.url,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final int? width;
  final int? height;

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      id: json['id'] as String,
      url: json['url'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.kind,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.routeId,
    this.attachments = const [],
  });

  final String id;
  final String kind;
  final String subject;
  final String status;
  final String? routeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportMessage> messages;
  final List<SupportAttachment> attachments;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final rawAttachments = json['attachments'];
    return SupportTicket(
      id: json['id'] as String,
      kind: json['kind'] as String,
      subject: json['subject'] as String,
      status: json['status'] as String,
      routeId: json['route_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      messages: rawMessages is List
          ? [
              for (final item in rawMessages)
                if (item is Map<String, dynamic>) SupportMessage.fromJson(item),
            ]
          : const [],
      attachments: rawAttachments is List
          ? [
              for (final item in rawAttachments)
                if (item is Map<String, dynamic>)
                  SupportAttachment.fromJson(item),
            ]
          : const [],
    );
  }
}

abstract interface class SupportRepository {
  Future<SupportTicket> createTicket({
    required String kind,
    required String subject,
    required String body,
    String? routeId,
  });

  Future<List<SupportTicket>> listTickets();

  Future<SupportTicket> getTicket(String ticketId);

  Future<SupportMessage> addMessage({
    required String ticketId,
    required String body,
  });

  Future<SupportAttachment> uploadAttachment({
    required String ticketId,
    required String filePath,
  });
}

final class ApiSupportRepository implements SupportRepository {
  ApiSupportRepository(this._dio);

  final Dio _dio;

  @override
  Future<SupportTicket> createTicket({
    required String kind,
    required String subject,
    required String body,
    String? routeId,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/support/tickets',
        data: {
          'kind': kind,
          'subject': subject,
          'body': body,
          'route_id': ?routeId,
        },
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return SupportTicket.fromJson(data);
    });
  }

  @override
  Future<List<SupportTicket>> listTickets() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/support/tickets',
      );
      final items = response.data?['items'];
      if (items is! List) {
        return const [];
      }
      return [
        for (final item in items)
          if (item is Map<String, dynamic>) SupportTicket.fromJson(item),
      ];
    });
  }

  @override
  Future<SupportTicket> getTicket(String ticketId) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/support/tickets/$ticketId',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return SupportTicket.fromJson(data);
    });
  }

  @override
  Future<SupportMessage> addMessage({
    required String ticketId,
    required String body,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/support/tickets/$ticketId/messages',
        data: {'body': body},
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return SupportMessage.fromJson(data);
    });
  }

  @override
  Future<SupportAttachment> uploadAttachment({
    required String ticketId,
    required String filePath,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/support/tickets/$ticketId/attachments',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath),
        }),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedFailure();
      }
      return SupportAttachment.fromJson(data);
    });
  }
}

final class MockSupportRepository implements SupportRepository {
  final _tickets = <SupportTicket>[];

  @override
  Future<SupportTicket> createTicket({
    required String kind,
    required String subject,
    required String body,
    String? routeId,
  }) async {
    final now = DateTime.now().toUtc();
    final messages = <SupportMessage>[
      SupportMessage(
        id: 'm-${_tickets.length}-u',
        author: 'user',
        body: body,
        createdAt: now,
      ),
    ];
    if (kind == 'chat') {
      messages.add(
        SupportMessage(
          id: 'm-${_tickets.length}-a',
          author: 'assistant',
          body:
              'Здравствуйте! Спасибо за обращение. Мы ответим в течение 1–2 рабочих дней.',
          createdAt: now,
        ),
      );
    }
    final ticket = SupportTicket(
      id: 't-${_tickets.length + 1}',
      kind: kind,
      subject: subject,
      status: 'open',
      routeId: routeId,
      createdAt: now,
      updatedAt: now,
      messages: messages,
    );
    _tickets.insert(0, ticket);
    return ticket;
  }

  @override
  Future<List<SupportTicket>> listTickets() async => List.of(_tickets);

  @override
  Future<SupportTicket> getTicket(String ticketId) async {
    return _tickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => throw const NotFoundFailure(),
    );
  }

  @override
  Future<SupportMessage> addMessage({
    required String ticketId,
    required String body,
  }) async {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index < 0) {
      throw const NotFoundFailure();
    }
    final ticket = _tickets[index];
    final message = SupportMessage(
      id: 'm-${ticket.id}-${ticket.messages.length}',
      author: 'user',
      body: body,
      createdAt: DateTime.now().toUtc(),
    );
    _tickets[index] = SupportTicket(
      id: ticket.id,
      kind: ticket.kind,
      subject: ticket.subject,
      status: ticket.status,
      routeId: ticket.routeId,
      createdAt: ticket.createdAt,
      updatedAt: message.createdAt,
      messages: [...ticket.messages, message],
    );
    return message;
  }

  @override
  Future<SupportAttachment> uploadAttachment({
    required String ticketId,
    required String filePath,
  }) async {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index < 0) {
      throw const NotFoundFailure();
    }
    final ticket = _tickets[index];
    final attachment = SupportAttachment(
      id: 'a-${ticket.id}-${ticket.attachments.length}',
      url: filePath,
    );
    _tickets[index] = SupportTicket(
      id: ticket.id,
      kind: ticket.kind,
      subject: ticket.subject,
      status: ticket.status,
      routeId: ticket.routeId,
      createdAt: ticket.createdAt,
      updatedAt: DateTime.now().toUtc(),
      messages: ticket.messages,
      attachments: [...ticket.attachments, attachment],
    );
    return attachment;
  }
}
