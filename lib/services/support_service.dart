import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'environment_config.dart';
import 'firebase_guard.dart';
import 'monitoring_service.dart';

/// Exception thrown when a support workflow fails locally before reaching the
/// backend (for example due to invalid input).
class SupportServiceException implements Exception {
  SupportServiceException(this.message);

  final String message;

  @override
  String toString() => 'SupportServiceException: $message';
}

/// Immutable representation of a support ticket comment.
class SupportComment {
  const SupportComment({
    required this.id,
    required this.ticketId,
    required this.authorId,
    required this.authorRole,
    required this.message,
    required this.visibility,
    required this.createdAt,
    this.editedAt,
    this.isLocal = false,
  });

  final String id;
  final String ticketId;
  final String authorId;
  final String authorRole;
  final String message;
  final String visibility;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isLocal;

  SupportComment copyWith({
    String? message,
    String? visibility,
    DateTime? editedAt,
    bool? isLocal,
  }) {
    return SupportComment(
      id: id,
      ticketId: ticketId,
      authorId: authorId,
      authorRole: authorRole,
      message: message ?? this.message,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}

/// Immutable representation of a support ticket.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.channel,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
    this.assigneeId,
    this.internalNotes,
    this.comments = const <SupportComment>[],
    this.isLocal = false,
    this.error,
  });

  final String id;
  final String userId;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final String channel;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastActivityAt;
  final String? assigneeId;
  final String? internalNotes;
  final List<SupportComment> comments;
  final bool isLocal;
  final String? error;

  SupportTicket copyWith({
    String? subject,
    String? description,
    String? status,
    String? priority,
    String? channel,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActivityAt,
    String? assigneeId,
    String? internalNotes,
    List<SupportComment>? comments,
    bool? isLocal,
    String? error,
  }) {
    return SupportTicket(
      id: id,
      userId: userId,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      channel: channel ?? this.channel,
      tags: tags ?? List<String>.from(this.tags),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      assigneeId: assigneeId ?? this.assigneeId,
      internalNotes: internalNotes ?? this.internalNotes,
      comments: comments ?? List<SupportComment>.from(this.comments),
      isLocal: isLocal ?? this.isLocal,
      error: error ?? this.error,
    );
  }
}

/// Lightweight client-side wrapper for the support ticket Cloud Functions.
///
/// The class gracefully degrades when Firebase Functions/Firestore are not
/// configured, storing tickets locally so testers can still exercise the user
/// flows in preview builds.
class SupportService extends ChangeNotifier {
  SupportService({EnvironmentConfig? config})
      : _config = config ?? EnvironmentConfig();

  final EnvironmentConfig _config;
  final Map<String, SupportTicket> _ticketCache = <String, SupportTicket>{};

  bool _isLoading = false;
  String? _lastError;
  int _localCounter = 0;

  static const String _localTicketPrefix = 'local-ticket-';
  static const String _localCommentPrefix = 'local-comment-';

  static const Set<String> _allowedStatuses = <String>{
    'open',
    'pending_support',
    'pending_user',
    'resolved',
    'closed',
  };

  static const Set<String> _allowedPriorities = <String>{
    'low',
    'medium',
    'high',
  };

  static const Set<String> _allowedVisibilities = <String>{
    'public',
    'internal',
  };

  static const Map<String, List<String>> _supportTransitions = <String, List<String>>{
    'open': <String>['pending_support', 'pending_user', 'resolved', 'closed'],
    'pending_support': <String>['pending_user', 'resolved', 'closed'],
    'pending_user': <String>['pending_support', 'resolved', 'closed'],
    'resolved': <String>['pending_support', 'pending_user', 'closed'],
    'closed': <String>['pending_support'],
  };

  static const Map<String, List<String>> _customerTransitions = <String, List<String>>{
    'open': <String>['pending_support', 'closed'],
    'pending_support': <String>['closed'],
    'pending_user': <String>['pending_support', 'closed'],
    'resolved': <String>['pending_support', 'closed'],
    'closed': <String>[],
  };

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  List<SupportTicket> get tickets => _sortedTickets();

  FirebaseFirestore? get _firestore => FirebaseGuard.firestore;
  FirebaseFunctions? get _functions => FirebaseGuard.functions();
  bool get _remoteAvailable =>
      _config.enableSupportTickets &&
      FirebaseGuard.isConfigured &&
      _firestore != null &&
      _functions != null;

  /// Returns a cached ticket if available.
  SupportTicket? getTicket(String ticketId) => _ticketCache[ticketId];

  /// Refreshes the current user's ticket list.
  Future<List<SupportTicket>> refreshForUser(
    String userId, {
    bool includeClosed = false,
  }) async {
    if (userId.isEmpty) {
      return const <SupportTicket>[];
    }

    if (!_remoteAvailable) {
      return _localTicketsForUser(userId, includeClosed: includeClosed);
    }

    final firestore = _firestore;
    if (firestore == null) {
      return _localTicketsForUser(userId, includeClosed: includeClosed);
    }

    _setLoading(true);
    _lastError = null;

    try {
      final query = await firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: userId)
          .orderBy('lastActivityAt', descending: true)
          .limit(20)
          .get();

      final List<SupportTicket> fetched = <SupportTicket>[];
      for (final doc in query.docs) {
        final commentsSnap = await doc.reference
            .collection('comments')
            .orderBy('createdAt', descending: false)
            .get();
        final comments = commentsSnap.docs
            .map((commentDoc) =>
                _commentFromMap(commentDoc.id, commentDoc.data(), ticketId: doc.id))
            .toList(growable: false);
        final ticket = _ticketFromMap(doc.id, doc.data(), comments: comments);
        fetched.add(ticket);
        _ticketCache[ticket.id] = ticket;
      }

      _setLoading(false);
      notifyListeners();

      return _localTicketsForUser(
        userId,
        includeClosed: includeClosed,
      );
    } catch (error, stackTrace) {
      _setLoading(false);
      _lastError = 'Failed to load support tickets: $error';
      MonitoringService.instance.recordError(error, stackTrace, context: <String, Object?>{
        'operation': 'refresh_support_tickets',
      });
      notifyListeners();
      return _localTicketsForUser(userId, includeClosed: includeClosed);
    }
  }

  /// Attempts to push any locally-cached tickets or comments to the backend.
  ///
  /// When Firebase is unavailable the method returns the current local cache
  /// and records a descriptive error. Callers can retry once connectivity
  /// returns or after Firebase configuration is restored.
  Future<List<SupportTicket>> synchronizePending(
    String userId, {
    bool includeClosed = false,
  }) async {
    if (userId.isEmpty) {
      return const <SupportTicket>[];
    }

    final pending = _ticketCache.values
        .where((ticket) =>
            ticket.userId == userId &&
            (ticket.isLocal ||
                ticket.comments.any((comment) => comment.isLocal)))
        .toList(growable: false);

    if (pending.isEmpty) {
      return refreshForUser(userId, includeClosed: includeClosed);
    }

    if (!_remoteAvailable) {
      _lastError =
          'Support tickets sync unavailable; Firebase is not configured.';
      notifyListeners();
      return _localTicketsForUser(userId, includeClosed: includeClosed);
    }

    if (_functions == null) {
      _lastError =
          'Firebase Functions unavailable; pending tickets remain local.';
      notifyListeners();
      return _localTicketsForUser(userId, includeClosed: includeClosed);
    }

    _setLoading(true);
    final List<SupportTicket> synced = <SupportTicket>[];
    final List<String> failures = <String>[];

    for (final ticket in pending) {
      try {
        final syncedTicket = await _syncTicket(ticket);
        if (syncedTicket != null) {
          synced.add(syncedTicket);
        }
      } catch (error, stackTrace) {
        failures.add(ticket.id);
        MonitoringService.instance
            .recordError(error, stackTrace, context: <String, Object?>{
          'operation': 'sync_support_ticket',
          'ticketId': ticket.id,
        });
      }
    }

    _setLoading(false);

    for (final ticket in synced) {
      final refreshed = await _loadTicketFromFirestore(ticket.id);
      if (refreshed != null) {
        _ticketCache[refreshed.id] = refreshed;
      }
    }

    if (failures.isEmpty) {
      _lastError = null;
    } else {
      _lastError = 'Unable to sync ${failures.length} support ticket(s).';
    }

    notifyListeners();
    return _localTicketsForUser(userId, includeClosed: includeClosed);
  }

  /// Creates a support ticket either through Cloud Functions or locally when
  /// Firebase is unavailable.
  Future<SupportTicket> createTicket({
    required String userId,
    required String subject,
    required String description,
    String priority = 'medium',
    List<String> tags = const <String>[],
    String channel = 'app',
  }) async {
    final trimmedSubject = subject.trim();
    final trimmedDescription = description.trim();

    if (trimmedSubject.length < 5 || trimmedSubject.length > 100) {
      throw SupportServiceException('Subject must be between 5 and 100 characters.');
    }
    if (trimmedDescription.length < 10 || trimmedDescription.length > 5000) {
      throw SupportServiceException('Description must be between 10 and 5000 characters.');
    }

    final normalisedPriority = _normalisePriority(priority);
    final sanitisedTags = tags
        .where((tag) => tag.trim().isNotEmpty)
        .map((tag) => tag.trim().toLowerCase())
        .take(10)
        .toList(growable: false);

    final now = DateTime.now().toUtc();

    if (!_remoteAvailable) {
      final fallbackTicket = _createLocalTicket(
        userId: userId,
        subject: trimmedSubject,
        description: trimmedDescription,
        priority: normalisedPriority,
        tags: sanitisedTags,
        channel: channel,
        createdAt: now,
      );
      _ticketCache[fallbackTicket.id] = fallbackTicket;
      _lastError =
          'Firebase support services are not configured; ticket stored locally only.';
      notifyListeners();
      return fallbackTicket;
    }

    final functions = _functions;
    if (functions == null) {
      final fallbackTicket = _createLocalTicket(
        userId: userId,
        subject: trimmedSubject,
        description: trimmedDescription,
        priority: normalisedPriority,
        tags: sanitisedTags,
        channel: channel,
        createdAt: now,
      );
      _ticketCache[fallbackTicket.id] = fallbackTicket;
      _lastError =
          'Firebase Functions unavailable; ticket stored locally only.';
      notifyListeners();
      return fallbackTicket;
    }

    _setLoading(true);
    final stopwatch = Stopwatch()..start();

    try {
      final callable = functions.httpsCallable('createSupportTicket');
      final response = await callable.call(<String, dynamic>{
        'subject': trimmedSubject,
        'description': trimmedDescription,
        'priority': normalisedPriority,
        if (channel.isNotEmpty) 'channel': channel,
        if (sanitisedTags.isNotEmpty) 'tags': sanitisedTags,
      });
      stopwatch.stop();
      unawaited(MonitoringService.instance.logFunctionInvocation(
        'createSupportTicket',
        success: true,
        duration: stopwatch.elapsed,
      ));

      final data = response.data is Map ? Map<String, dynamic>.from(response.data) : <String, dynamic>{};
      final ticketId = (data['ticketId'] as String?) ?? _generateLocalId();
      final fetched = await _loadTicketFromFirestore(ticketId);
      final ticket = fetched ?? SupportTicket(
        id: ticketId,
        userId: userId,
        subject: trimmedSubject,
        description: trimmedDescription,
        status: (data['status'] as String? ?? 'open').toString().toLowerCase(),
        priority: (data['priority'] as String? ?? normalisedPriority).toString().toLowerCase(),
        channel: channel,
        tags: sanitisedTags,
        createdAt: now,
        updatedAt: now,
        lastActivityAt: now,
        comments: const <SupportComment>[],
      );
      _ticketCache[ticket.id] = ticket;
      _lastError = null;
      _setLoading(false);
      notifyListeners();
      return ticket;
    } catch (error, stackTrace) {
      stopwatch.stop();
      unawaited(MonitoringService.instance.logFunctionInvocation(
        'createSupportTicket',
        success: false,
        duration: stopwatch.elapsed,
        metadata: const <String, Object?>{'fallback': true},
      ));
      MonitoringService.instance.recordError(error, stackTrace, context: <String, Object?>{
        'operation': 'create_support_ticket',
      });
      _setLoading(false);
      final fallbackTicket = _createLocalTicket(
        userId: userId,
        subject: trimmedSubject,
        description: trimmedDescription,
        priority: normalisedPriority,
        tags: sanitisedTags,
        channel: channel,
        createdAt: now,
        error: error.toString(),
      );
      _ticketCache[fallbackTicket.id] = fallbackTicket;
      _lastError = 'Ticket stored locally because the network request failed.';
      notifyListeners();
      return fallbackTicket;
    }
  }

  /// Adds a comment to a ticket and returns the created comment.
  Future<SupportComment> addComment(
    String ticketId, {
    required String userId,
    required String message,
    bool supportAgent = false,
    String visibility = 'public',
    String? assigneeId,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.length < 2 || trimmedMessage.length > 4000) {
      throw SupportServiceException('Comment must be between 2 and 4000 characters.');
    }

    final normalisedVisibility = _normaliseVisibility(visibility);
    final now = DateTime.now().toUtc();
    final ticket = _ticketCache[ticketId];

    if (!_remoteAvailable || ticket == null) {
      final localTicket = ticket ?? _createLocalTicket(
        userId: userId,
        subject: 'Pending Support Ticket',
        description: trimmedMessage,
        priority: 'medium',
        tags: const <String>[],
        channel: 'app',
        createdAt: now,
      );

      final comment = _createLocalComment(
        ticketId: localTicket.id,
        userId: userId,
        message: trimmedMessage,
        authorRole: supportAgent ? 'support' : 'customer',
        visibility: normalisedVisibility,
        createdAt: now,
      );

      final nextStatus = _computeNextStatusOnComment(localTicket.status, comment.authorRole);
      final updated = localTicket.copyWith(
        comments: <SupportComment>[...localTicket.comments, comment],
        status: nextStatus,
        assigneeId: assigneeId ?? localTicket.assigneeId,
        updatedAt: now,
        lastActivityAt: now,
        isLocal: true,
      );

      _ticketCache[updated.id] = updated;
      _lastError = 'Comment stored locally; sync when Firebase is available.';
      notifyListeners();
      return comment;
    }

    final functions = _functions;
    if (functions == null) {
      final comment = _createLocalComment(
        ticketId: ticketId,
        userId: userId,
        message: trimmedMessage,
        authorRole: supportAgent ? 'support' : 'customer',
        visibility: normalisedVisibility,
        createdAt: now,
      );
      final existing = ticket;
      if (existing != null) {
        final updated = existing.copyWith(
          comments: <SupportComment>[...existing.comments, comment],
          updatedAt: now,
          lastActivityAt: now,
          isLocal: true,
        );
        _ticketCache[updated.id] = updated;
      }
      _lastError = 'Firebase Functions unavailable; comment stored locally only.';
      notifyListeners();
      return comment;
    }

    _setLoading(true);
    final stopwatch = Stopwatch()..start();

    try {
      final callable = functions.httpsCallable('addSupportTicketComment');
      await callable.call(<String, dynamic>{
        'ticketId': ticketId,
        'message': trimmedMessage,
        'visibility': normalisedVisibility,
        if (assigneeId != null) 'assigneeId': assigneeId,
      });
      stopwatch.stop();
      unawaited(MonitoringService.instance.logFunctionInvocation(
        'addSupportTicketComment',
        success: true,
        duration: stopwatch.elapsed,
      ));

      final refreshed = await _loadTicketFromFirestore(ticketId);
      if (refreshed != null) {
        _ticketCache[refreshed.id] = refreshed;
        _lastError = null;
        _setLoading(false);
        notifyListeners();
        return refreshed.comments.isNotEmpty
            ? refreshed.comments.last
            : _createLocalComment(
                ticketId: refreshed.id,
                userId: userId,
                message: trimmedMessage,
                authorRole: supportAgent ? 'support' : 'customer',
                visibility: normalisedVisibility,
                createdAt: now,
              );
      }

      final fallbackComment = _createLocalComment(
        ticketId: ticketId,
        userId: userId,
        message: trimmedMessage,
        authorRole: supportAgent ? 'support' : 'customer',
        visibility: normalisedVisibility,
        createdAt: now,
      );
      final existing = ticket;
      if (existing != null) {
        final updated = existing.copyWith(
          comments: <SupportComment>[...existing.comments, fallbackComment],
          updatedAt: now,
          lastActivityAt: now,
        );
        _ticketCache[updated.id] = updated;
      }
      _lastError = null;
      _setLoading(false);
      notifyListeners();
      return fallbackComment;
    } catch (error, stackTrace) {
      stopwatch.stop();
      unawaited(MonitoringService.instance.logFunctionInvocation(
        'addSupportTicketComment',
        success: false,
        duration: stopwatch.elapsed,
        metadata: const <String, Object?>{'fallback': true},
      ));
      MonitoringService.instance.recordError(error, stackTrace, context: <String, Object?>{
        'operation': 'add_support_comment',
        'ticketId': ticketId,
      });
      _setLoading(false);

      final comment = _createLocalComment(
        ticketId: ticket?.id ?? ticketId,
        userId: userId,
        message: trimmedMessage,
        authorRole: supportAgent ? 'support' : 'customer',
        visibility: normalisedVisibility,
        createdAt: now,
      );
      final existing = ticket;
      if (existing != null) {
        final updated = existing.copyWith(
          comments: <SupportComment>[...existing.comments, comment],
          updatedAt: now,
          lastActivityAt: now,
          isLocal: true,
        );
        _ticketCache[updated.id] = updated;
      }
      _lastError = 'Comment stored locally because the network request failed.';
      notifyListeners();
      return comment;
    }
  }

  /// Updates the status, priority, and metadata for a ticket.
  Future<SupportTicket> updateTicketStatus(
    String ticketId, {
    String? status,
    String? priority,
    List<String>? tags,
    String? assigneeId,
    String? internalNotes,
    bool supportAgent = false,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = _ticketCache[ticketId];

    if (status != null) {
      status = _normaliseStatus(status);
    }
    if (priority != null) {
      priority = _normalisePriority(priority);
    }

    final sanitisedTags = tags
            ?.where((tag) => tag.trim().isNotEmpty)
            .map((tag) => tag.trim().toLowerCase())
            .take(12)
            .toList(growable: false) ??
        existing?.tags;

    if (!_remoteAvailable || existing == null) {
      final ticket = existing ??
          _createLocalTicket(
            userId: 'unknown',
            subject: 'Pending Support Ticket',
            description: '',
            priority: priority ?? 'medium',
            tags: sanitisedTags ?? const <String>[],
            channel: 'app',
            createdAt: now,
          );
      final nextStatus = status ?? ticket.status;

      if (!_canTransition(ticket.status, nextStatus, supportAgent)) {
        throw SupportServiceException(
          'Cannot transition ticket from ${ticket.status} to $nextStatus.',
        );
      }

      final updated = ticket.copyWith(
        status: nextStatus,
        priority: priority ?? ticket.priority,
        tags: sanitisedTags ?? ticket.tags,
        assigneeId: assigneeId ?? ticket.assigneeId,
        internalNotes: internalNotes ?? ticket.internalNotes,
        updatedAt: now,
        lastActivityAt: now,
        isLocal: true,
      );
      _ticketCache[updated.id] = updated;
      _lastError = 'Ticket update stored locally; sync when Firebase is available.';
      notifyListeners();
      return updated;
    }

    final functions = _functions;
    if (functions == null) {
      final updated = existing.copyWith(
        status: status ?? existing.status,
        priority: priority ?? existing.priority,
        tags: sanitisedTags ?? existing.tags,
        assigneeId: assigneeId ?? existing.assigneeId,
        internalNotes: internalNotes ?? existing.internalNotes,
        updatedAt: now,
        lastActivityAt: now,
        isLocal: true,
      );
      _ticketCache[updated.id] = updated;
      _lastError = 'Firebase Functions unavailable; update stored locally only.';
      notifyListeners();
      return updated;
    }

    if (status != null && !_canTransition(existing.status, status, supportAgent)) {
      throw SupportServiceException(
        'Cannot transition ticket from ${existing.status} to $status.',
      );
    }

    _setLoading(true);
    final stopwatch = Stopwatch()..start();

    try {
      final payload = <String, dynamic>{'ticketId': ticketId};
      if (status != null) payload['status'] = status;
      if (priority != null) payload['priority'] = priority;
      if (assigneeId != null) payload['assigneeId'] = assigneeId;
      if (sanitisedTags != null) payload['tags'] = sanitisedTags;
      if (internalNotes != null) payload['internalNotes'] = internalNotes;

      final callable = functions.httpsCallable('updateSupportTicketStatus');
      await callable.call(payload);
      stopwatch.stop();
      unawaited(MonitoringService.instance.logFunctionInvocation(
        'updateSupportTicketStatus',
        success: true,
        duration: stopwatch.elapsed,
      ));

      final refreshed = await _loadTicketFromFirestore(ticketId);
      if (refreshed != null) {
        _ticketCache[refreshed.id] = refreshed;
        _lastError = null;
        _setLoading(false);
        notifyListeners();
        return refreshed;
      }

      final updated = existing.copyWith(
        status: status ?? existing.status,
        priority: priority ?? existing.priority,
        tags: sanitisedTags ?? existing.tags,
        assigneeId: assigneeId ?? existing.assigneeId,
        internalNotes: internalNotes ?? existing.internalNotes,
        updatedAt: now,
        lastActivityAt: now,
      );
      _ticketCache[updated.id] = updated;
      _lastError = null;
      _setLoading(false);
      notifyListeners();
      return updated;
    } catch (error, stackTrace) {
      stopwatch.stop();
      unawaited(MonitoringService.instance.logFunctionInvocation(
        'updateSupportTicketStatus',
        success: false,
        duration: stopwatch.elapsed,
        metadata: const <String, Object?>{'fallback': true},
      ));
      MonitoringService.instance.recordError(error, stackTrace, context: <String, Object?>{
        'operation': 'update_support_ticket',
        'ticketId': ticketId,
      });
      _setLoading(false);

      final updated = existing.copyWith(
        status: status ?? existing.status,
        priority: priority ?? existing.priority,
        tags: sanitisedTags ?? existing.tags,
        assigneeId: assigneeId ?? existing.assigneeId,
        internalNotes: internalNotes ?? existing.internalNotes,
        updatedAt: now,
        lastActivityAt: now,
        isLocal: true,
      );
      _ticketCache[updated.id] = updated;
      _lastError = 'Ticket update stored locally because the network request failed.';
      notifyListeners();
      return updated;
    }
  }

  List<SupportTicket> _localTicketsForUser(
    String userId, {
    bool includeClosed = false,
  }) {
    final local = _ticketCache.values
        .where((ticket) => ticket.userId == userId)
        .toList(growable: false);
    local.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    if (includeClosed) {
      return local;
    }
    return local.where((ticket) => ticket.status != 'closed').toList(growable: false);
  }

  @visibleForTesting
  List<SupportComment> pendingCommentsForSync(
    SupportTicket ticket, {
    required bool newTicketCreated,
  }) =>
      _pendingCommentsForSync(ticket, newTicketCreated: newTicketCreated);

  List<SupportTicket> _sortedTickets() {
    final list = _ticketCache.values.toList(growable: false);
    list.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return list;
  }

  SupportTicket _createLocalTicket({
    required String userId,
    required String subject,
    required String description,
    required String priority,
    required List<String> tags,
    required String channel,
    required DateTime createdAt,
    String status = 'open',
    String? error,
  }) {
    final id = _generateLocalId();
    final comment = SupportComment(
      id: _generateLocalCommentId(),
      ticketId: id,
      authorId: userId,
      authorRole: 'customer',
      message: description,
      visibility: 'public',
      createdAt: createdAt,
      editedAt: null,
      isLocal: true,
    );
    return SupportTicket(
      id: id,
      userId: userId,
      subject: subject,
      description: description,
      status: status,
      priority: priority,
      channel: channel,
      tags: List<String>.from(tags),
      createdAt: createdAt,
      updatedAt: createdAt,
      lastActivityAt: createdAt,
      comments: <SupportComment>[comment],
      isLocal: true,
      error: error,
    );
  }

  SupportComment _createLocalComment({
    required String ticketId,
    required String userId,
    required String message,
    required String authorRole,
    required String visibility,
    required DateTime createdAt,
  }) {
    return SupportComment(
      id: _generateLocalCommentId(),
      ticketId: ticketId,
      authorId: userId,
      authorRole: authorRole,
      message: message,
      visibility: visibility,
      createdAt: createdAt,
      editedAt: null,
      isLocal: true,
    );
  }

  Future<SupportTicket?> _syncTicket(SupportTicket ticket) async {
    SupportTicket current = ticket;
    String activeId = ticket.id;
    bool createdRemotely = false;

    if (_isLocalTicketId(ticket.id)) {
      final created = await createTicket(
        userId: ticket.userId,
        subject: ticket.subject,
        description: ticket.description,
        priority: ticket.priority,
        tags: ticket.tags,
        channel: ticket.channel,
      );

      if (created.isLocal) {
        // Avoid duplicating local placeholders created during retry attempts.
        if (created.id != ticket.id) {
          _ticketCache.remove(created.id);
        }
        throw SupportServiceException(
          'Failed to sync local ticket ${ticket.id}; still offline.',
        );
      }

      _ticketCache.remove(ticket.id);
      current = created;
      activeId = created.id;
      createdRemotely = true;
    } else if (ticket.isLocal) {
      final updated = await updateTicketStatus(
        ticket.id,
        status: ticket.status,
        priority: ticket.priority,
        tags: ticket.tags,
        assigneeId: ticket.assigneeId,
        internalNotes: ticket.internalNotes,
        supportAgent: _assumeSupportAgent(ticket),
      );

      if (updated.isLocal) {
        throw SupportServiceException(
          'Failed to push ticket update for ${ticket.id}; still offline.',
        );
      }

      current = updated;
      activeId = updated.id;
    }

    final commentsToSync = _pendingCommentsForSync(
      ticket,
      newTicketCreated: createdRemotely,
    );

    for (final comment in commentsToSync) {
      final syncedComment = await addComment(
        activeId,
        userId: comment.authorId,
        message: comment.message,
        supportAgent: comment.authorRole == 'support',
        visibility: comment.visibility,
        assigneeId: ticket.assigneeId,
      );

      if (syncedComment.isLocal) {
        throw SupportServiceException(
          'Failed to sync comment ${comment.id} for ticket $activeId.',
        );
      }
    }

    final refreshed = await _loadTicketFromFirestore(activeId);
    if (refreshed != null) {
      return refreshed;
    }
    return current;
  }

  Future<SupportTicket?> _loadTicketFromFirestore(String ticketId) async {
    final firestore = _firestore;
    if (firestore == null) {
      return null;
    }
    final snapshot = await firestore.collection('support_tickets').doc(ticketId).get();
    if (!snapshot.exists) {
      return null;
    }
    final commentsSnap = await snapshot.reference
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .get();
    final comments = commentsSnap.docs
        .map((doc) => _commentFromMap(doc.id, doc.data(), ticketId: ticketId))
        .toList(growable: false);
    return _ticketFromMap(snapshot.id, snapshot.data() ?? <String, dynamic>{}, comments: comments);
  }

  SupportTicket _ticketFromMap(
    String id,
    Map<String, dynamic> data, {
    List<SupportComment> comments = const <SupportComment>[],
  }) {
    final createdAt = _parseDateTime(data['createdAt']);
    final updatedAt = _parseDateTime(data['updatedAt']);
    final lastActivityAt = _parseDateTime(data['lastActivityAt']);

    return SupportTicket(
      id: id,
      userId: (data['userId'] as String?) ?? 'unknown',
      subject: (data['subject'] as String?) ?? 'Support Ticket',
      description: (data['description'] as String?) ?? '',
      status: _normaliseStatus(data['status'] as String? ?? 'open'),
      priority: _normalisePriority(data['priority'] as String? ?? 'medium'),
      channel: (data['channel'] as String?) ?? 'app',
      tags: List<String>.from((data['tags'] as List<dynamic>?)?.map((tag) => tag.toString()) ?? <String>[]),
      assigneeId: data['assigneeId'] as String?,
      internalNotes: data['internalNotes'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastActivityAt: lastActivityAt,
      comments: comments,
      isLocal: false,
    );
  }

  SupportComment _commentFromMap(
    String id,
    Map<String, dynamic> data, {
    required String ticketId,
  }) {
    return SupportComment(
      id: id,
      ticketId: ticketId,
      authorId: (data['authorId'] as String?) ?? 'unknown',
      authorRole: (data['authorRole'] as String?) ?? 'customer',
      message: (data['message'] as String?) ?? '',
      visibility: _normaliseVisibility((data['visibility'] as String?) ?? 'public'),
      createdAt: _parseDateTime(data['createdAt']),
      editedAt: data['editedAt'] != null ? _parseDateTime(data['editedAt']) : null,
      isLocal: false,
    );
  }

  DateTime _parseDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }

  String _normaliseStatus(String status) {
    final normalised = status.trim().toLowerCase();
    if (_allowedStatuses.contains(normalised)) {
      return normalised;
    }
    return 'open';
  }

  String _normalisePriority(String priority) {
    final normalised = priority.trim().toLowerCase();
    if (_allowedPriorities.contains(normalised)) {
      return normalised;
    }
    return 'medium';
  }

  String _normaliseVisibility(String visibility) {
    final normalised = visibility.trim().toLowerCase();
    if (_allowedVisibilities.contains(normalised)) {
      return normalised;
    }
    return 'public';
  }

  bool _canTransition(String current, String next, bool supportAgent) {
    final from = _normaliseStatus(current);
    final to = _normaliseStatus(next);
    if (from == to) {
      return true;
    }
    final transitions = supportAgent ? _supportTransitions : _customerTransitions;
    final allowed = transitions[from] ?? const <String>[];
    return allowed.contains(to);
  }

  String _computeNextStatusOnComment(String currentStatus, String authorRole) {
    final status = _normaliseStatus(currentStatus);
    final role = authorRole == 'support' ? 'support' : 'customer';

    if (role == 'support') {
      if (status == 'resolved' || status == 'closed') {
        return status;
      }
      return 'pending_user';
    }

    if (status == 'resolved') {
      return 'open';
    }
    if (status == 'pending_user') {
      return 'pending_support';
    }
    if (status == 'closed') {
      return 'closed';
    }
    return 'pending_support';
  }

  String _generateLocalId() {
    _localCounter += 1;
    return '$_localTicketPrefix${DateTime.now().microsecondsSinceEpoch}-${_localCounter}';
  }

  String _generateLocalCommentId() {
    _localCounter += 1;
    return '$_localCommentPrefix${DateTime.now().microsecondsSinceEpoch}-${_localCounter}';
  }

  List<SupportComment> _pendingCommentsForSync(
    SupportTicket ticket, {
    required bool newTicketCreated,
  }) {
    final comments = ticket.comments
        .where((comment) => comment.isLocal)
        .toList(growable: false);
    if (newTicketCreated && comments.isNotEmpty) {
      return comments.sublist(1);
    }
    return comments;
  }

  bool _isLocalTicketId(String ticketId) => ticketId.startsWith(_localTicketPrefix);

  bool _assumeSupportAgent(SupportTicket ticket) {
    if (ticket.internalNotes != null && ticket.internalNotes!.trim().isNotEmpty) {
      return true;
    }
    if (ticket.assigneeId != null && ticket.assigneeId!.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }
}
