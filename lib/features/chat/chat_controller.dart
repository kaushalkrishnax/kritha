import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/seed_messages.dart';
import '../../models/chat_attachment.dart';
import '../../models/chat_message.dart';
import '../../models/chat_session.dart';

class ChatState {
  const ChatState({
    required this.sessions,
    required this.archivedSessions,
    required this.messages,
    this.currentSessionId,
    this.sending = false,
  });

  /// Active (non-archived) sessions, pinned first and then newest first.
  final List<ChatSession> sessions;
  final List<ChatSession> archivedSessions;
  final String? currentSessionId;
  final List<ChatMessage> messages;
  final bool sending;

  /// A fresh chat that has not been written to SQLite yet.
  bool get isDraft => currentSessionId == null;

  ChatSession? get currentSession {
    for (final session in sessions) {
      if (session.id == currentSessionId) return session;
    }
    for (final session in archivedSessions) {
      if (session.id == currentSessionId) return session;
    }
    return null;
  }

  ChatState copyWith({
    List<ChatSession>? sessions,
    List<ChatSession>? archivedSessions,
    String? currentSessionId,
    List<ChatMessage>? messages,
    bool? sending,
    bool clearCurrentSession = false,
  }) {
    return ChatState(
      sessions: sessions ?? this.sessions,
      archivedSessions: archivedSessions ?? this.archivedSessions,
      currentSessionId: clearCurrentSession
          ? null
          : (currentSessionId ?? this.currentSessionId),
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
    );
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends AsyncNotifier<ChatState> {
  @override
  Future<ChatState> build() async {
    final database = ref.watch(databaseProvider);
    await database.seedIfEmpty(demoMessages());
    await database.adoptOrphanMessages();
    return _load(selectMostRecent: true);
  }

  Future<ChatState> _load({bool selectMostRecent = false}) async {
    final database = ref.read(databaseProvider);
    final sessions = await database.allSessions();
    final archived = await database.allSessions(archived: true);
    final currentId = selectMostRecent ? _mostRecentId(sessions) : null;

    final messages = currentId == null
        ? const <ChatMessage>[]
        : await database.messagesForSession(currentId);
    return ChatState(
      sessions: sessions,
      archivedSessions: archived,
      currentSessionId: currentId,
      messages: messages,
    );
  }

  static String? _mostRecentId(List<ChatSession> sessions) {
    if (sessions.isEmpty) return null;
    var latest = sessions.first;
    for (final session in sessions) {
      if (session.updatedAt.isAfter(latest.updatedAt)) latest = session;
    }
    return latest.id;
  }

  /// Starts an unsaved chat. The row is created with the first prompt so the
  /// sidebar never fills with empty "New chat" entries.
  void newChat() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        clearCurrentSession: true,
        messages: const [],
        sending: false,
      ),
    );
  }

  Future<void> selectSession(String id) async {
    final current = state.value;
    if (current == null || current.currentSessionId == id) return;
    final messages = await ref.read(databaseProvider).messagesForSession(id);
    state = AsyncData(
      current.copyWith(currentSessionId: id, messages: messages),
    );
  }

  Future<void> send(
    String rawText, {
    List<ChatAttachment> attachments = const [],
    String? editingMessageId,
  }) async {
    final text = rawText.trim();
    final current = state.value;
    if ((text.isEmpty && attachments.isEmpty) ||
        current == null ||
        current.sending) {
      return;
    }

    final database = ref.read(databaseProvider);
    final now = DateTime.now();
    var sessionId = current.currentSessionId;
    var sessions = current.sessions;
    var messages = current.messages;

    // First prompt in a draft chat creates the session and titles it.
    if (sessionId == null) {
      final session = ChatSession(
        id: 'session-${now.microsecondsSinceEpoch}',
        title: _titleFor(text, attachments),
        createdAt: now,
        updatedAt: now,
      );
      await database.saveSession(session);
      sessionId = session.id;
      messages = const [];
      sessions = await database.allSessions();
    }

    // Editing a prompt restarts the conversation from that turn: the target
    // and every later message are deleted before the replacement is saved.
    if (editingMessageId != null) {
      final editingId = editingMessageId;
      ChatMessage? target;
      for (final message in messages) {
        if (message.id == editingId) {
          target = message;
          break;
        }
      }
      if (target != null) {
        messages = messages
            .takeWhile((message) => message.id != editingId)
            .toList();
        await database.deleteMessagesFrom(sessionId, target.createdAt);
      }
    }

    final userMessage = ChatMessage(
      id: 'user-${now.microsecondsSinceEpoch}',
      role: ChatRole.user,
      text: text,
      createdAt: now,
      attachments: attachments,
    );

    state = AsyncData(
      current.copyWith(
        sessions: sessions,
        currentSessionId: sessionId,
        messages: [...messages, userMessage],
        sending: true,
      ),
    );
    await database.saveMessage(userMessage, sessionId: sessionId);
    await database.touchSession(sessionId, now);

    // A short delay keeps the "typing" affordance honest without pretending a
    // model is running. TODO(stub): replace demoReplyFor with the real engine.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final replyTime = DateTime.now();
    final reply = ChatMessage(
      id: 'assistant-${replyTime.microsecondsSinceEpoch}',
      role: ChatRole.assistant,
      text: demoReplyFor(text),
      createdAt: replyTime,
    );
    await database.saveMessage(reply, sessionId: sessionId);
    await database.touchSession(sessionId, replyTime);

    final latest = state.value ?? current;
    final stillOnSession = latest.currentSessionId == sessionId;
    final refreshed = await database.allSessions();
    final archived = await database.allSessions(archived: true);
    state = AsyncData(
      latest.copyWith(
        sessions: refreshed,
        archivedSessions: archived,
        messages: stillOnSession
            ? [...messages, userMessage, reply]
            : latest.messages,
        sending: false,
      ),
    );
  }

  Future<void> renameSession(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await ref.read(databaseProvider).renameSession(id, trimmed);
    await _refreshSessions();
  }

  Future<void> togglePinned(String id) async {
    final current = state.value;
    if (current == null) return;
    final session = _findSession(current, id);
    if (session == null) return;
    await ref.read(databaseProvider).setSessionPinned(id, !session.pinned);
    await _refreshSessions();
  }

  Future<void> archiveSession(String id) async {
    final database = ref.read(databaseProvider);
    await database.setSessionArchived(id, true);
    final current = state.value;
    if (current?.currentSessionId == id) {
      final sessions = await database.allSessions();
      final archived = await database.allSessions(archived: true);
      final next = _mostRecentId(sessions);
      state = AsyncData(
        current!.copyWith(
          sessions: sessions,
          archivedSessions: archived,
          currentSessionId: next,
          messages: next == null
              ? const []
              : await database.messagesForSession(next),
          clearCurrentSession: next == null,
        ),
      );
      return;
    }
    await _refreshSessions();
  }

  Future<void> restoreSession(String id) async {
    await ref.read(databaseProvider).setSessionArchived(id, false);
    await _refreshSessions();
  }

  Future<void> deleteSession(String id) async {
    await ref.read(databaseProvider).deleteSession(id);
    final current = state.value;
    if (current?.currentSessionId == id) {
      final sessions = await ref.read(databaseProvider).allSessions();
      final next = _mostRecentId(sessions);
      state = AsyncData(
        current!.copyWith(
          sessions: sessions,
          archivedSessions: await ref
              .read(databaseProvider)
              .allSessions(archived: true),
          currentSessionId: next,
          messages: next == null
              ? const []
              : await ref.read(databaseProvider).messagesForSession(next),
          clearCurrentSession: next == null,
        ),
      );
      return;
    }
    await _refreshSessions();
  }

  /// Settings action: wipe every row and re-seed the fixture.
  Future<void> restart() async {
    final database = ref.read(databaseProvider);
    await database.resetAll();
    await database.seedIfEmpty(demoMessages());
    state = AsyncData(await _load(selectMostRecent: true));
  }

  Future<void> _refreshSessions() async {
    final current = state.value;
    if (current == null) return;
    final database = ref.read(databaseProvider);
    final sessions = await database.allSessions();
    final archived = await database.allSessions(archived: true);
    state = AsyncData(
      current.copyWith(sessions: sessions, archivedSessions: archived),
    );
  }

  ChatSession? _findSession(ChatState state, String id) {
    for (final session in [...state.sessions, ...state.archivedSessions]) {
      if (session.id == id) return session;
    }
    return null;
  }

  static String _titleFor(String text, List<ChatAttachment> attachments) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      final hasAudio = attachments.any(
        (attachment) => attachment.mimeType?.startsWith('audio/') ?? false,
      );
      return hasAudio ? 'Voice note' : 'Attachment';
    }
    const limit = 48;
    if (cleaned.length <= limit) return cleaned;
    return '${cleaned.substring(0, limit).trimRight()}…';
  }
}
