import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_grimoire_fresh/services/environment_config.dart';
import 'package:crystal_grimoire_fresh/services/support_service.dart';

class _FakeConfig extends EnvironmentConfig {
  @override
  bool get enableSupportTickets => true;

  @override
  bool get hasFirebaseConfiguration => false;
}

void main() {
  group('SupportService offline fallback', () {
    late SupportService service;

    setUp(() {
      service = SupportService(config: _FakeConfig());
    });

    test('createTicket stores local ticket when Firebase unavailable', () async {
      final ticket = await service.createTicket(
        userId: 'user-1',
        subject: 'Need help with crystals',
        description: 'Please help me choose the right stones for focus.',
        priority: 'high',
        tags: const ['focus'],
      );

      expect(ticket.isLocal, isTrue);
      expect(ticket.status, equals('open'));
      expect(ticket.priority, equals('high'));
      expect(ticket.comments, hasLength(1));
      expect(service.tickets, isNotEmpty);
      expect(service.lastError, contains('ticket stored locally'));
    });

    test('addComment appends comment and updates status locally', () async {
      final ticket = await service.createTicket(
        userId: 'user-1',
        subject: 'Moon ritual guidance',
        description: 'Looking for a ritual under the new moon.',
      );

      final comment = await service.addComment(
        ticket.id,
        userId: 'user-1',
        message: 'Sharing an additional detail for the ritual.',
      );

      final refreshed = service.getTicket(ticket.id);
      expect(comment.isLocal, isTrue);
      expect(refreshed, isNotNull);
      expect(refreshed!.comments.length, equals(2));
      expect(refreshed.status, equals('pending_support'));
    });

    test('updateTicketStatus validates transitions and stores locally', () async {
      final ticket = await service.createTicket(
        userId: 'user-2',
        subject: 'Billing question',
        description: 'Need to change my plan.',
      );

      final updated = await service.updateTicketStatus(
        ticket.id,
        status: 'pending_support',
        priority: 'low',
        tags: const ['billing'],
        assigneeId: 'agent-1',
        supportAgent: true,
        internalNotes: 'Follow up tomorrow',
      );

      expect(updated.status, equals('pending_support'));
      expect(updated.tags, contains('billing'));
      expect(updated.assigneeId, equals('agent-1'));
      expect(updated.isLocal, isTrue);
      expect(updated.internalNotes, equals('Follow up tomorrow'));
    });

    test('refreshForUser returns cached tickets offline', () async {
      final ticket = await service.createTicket(
        userId: 'user-3',
        subject: 'General support',
        description: 'Testing offline refresh.',
      );

      final tickets = await service.refreshForUser('user-3');
      expect(tickets, hasLength(1));
      expect(tickets.first.id, equals(ticket.id));
    });
  });
}
