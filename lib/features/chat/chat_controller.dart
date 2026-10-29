import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/app_database.dart';
import '../../models/chat_attachment.dart';
import '../../models/chat_message.dart';
import '../../models/chat_session.dart';
import '../intelligence/intelligence_exception.dart';
import '../intelligence/model_configuration.dart';
import '../intelligence/models/ai_response.dart';
import '../intelligence/providers.dart';
import 'conversation_context.dart';

/// A reply that could not be produced, scoped to the chat that asked for it.
class ChatFailure {
  const ChatFailure({
    required this.sessionId,
    required this.message,
    required this.retryable,
  });

  final String sessionId;
  final String message;
  final bool retryable;
}

class ChatState {
  const ChatState({
    required this.sessions,
    required this.archivedSessions,
    required this.messages,
    this.currentSessionId,
    this.sending = false,
    this.streamingText,
    this.failure,
  });

  /// Active (non-archived) sessions, pinned first and then newest first.
  final List<ChatSession> sessions;
  final List<ChatSession> archivedSessions;
  final String? currentSessionId;
  final List<ChatMessage> messages;
  final bool sending;

  /// Assistant text produced so far for the in-flight reply. Non-null while
  /// generation is active, including before the first token arrives.
  final String? streamingText;

  /// The last reply failure for this chat, cleared on the next attempt.
  final ChatFailure? failure;

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
    String? streamingText,
    ChatFailure? failure,
    bool clearCurrentSession = false,
    bool clearStreaming = false,
    bool clearFailure = false,
  }) {
    return ChatState(
      sessions: sessions ?? this.sessions,
      archivedSessions: archivedSessions ?? this.archivedSessions,
      currentSessionId: clearCurrentSession
          ? null
          : (currentSessionId ?? this.currentSessionId),
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      streamingText: clearStreaming
          ? null
          : (streamingText ?? this.streamingText),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends AsyncNotifier<ChatState> {
  static final RegExp _messageSequence = RegExp(r'-(\d{6})-[ua]$');
  static const _contextBuilder = ConversationContextBuilder();

  StreamIterator<AiResponse>? _activeIterator;
  Future<void>? _activeRequest;
  Future<void>? _selection;
  int _generation = 0;
  int _sessionEpoch = 0;
  int _refreshEpoch = 0;
  bool _requestActive = false;
  bool _requestCanceled = false;

  @override
  Future<ChatState> build() async {
    ref.onDispose(_cancelActiveGeneration);
    final database = ref.watch(databaseProvider);
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
    _sessionEpoch++;
    _selection = null;
    _abortGeneration();
    state = AsyncData(
      current.copyWith(
        clearCurrentSession: true,
        messages: const [],
        sending: false,
        clearStreaming: true,
        clearFailure: true,
      ),
    );
  }

  Future<void> selectSession(String id) {
    final future = _selectSession(id);
    _selection = future;
    return future.whenComplete(() {
      if (identical(_selection, future)) _selection = null;
    });
  }

  Future<void> _selectSession(String id) async {
    final current = state.value;
    if (current == null || current.currentSessionId == id) return;
    final epoch = ++_sessionEpoch;
    _abortGeneration();
    try {
      final messages = await ref.read(databaseProvider).messagesForSession(id);
      if (!ref.mounted || epoch != _sessionEpoch) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          currentSessionId: id,
          messages: messages,
          sending: false,
          clearStreaming: true,
          clearFailure: true,
        ),
      );
    } on Object {
      if (!ref.mounted || epoch != _sessionEpoch) return;
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(sending: false, clearStreaming: true));
    }
  }

  Future<void> send(
    String rawText, {
    List<ChatAttachment> attachments = const [],
    String? editingMessageId,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    if (!await _selectionSettled()) return;

    final current = state.value;
    if (current == null || current.sending) return;

    if (_requestActive) {
      // A canceled request is still unwinding. Let it finish so its cleanup
      // cannot race the new prompt; an overlapping uncanceled request is a
      // duplicate send and is ignored.
      if (!_requestCanceled) return;
      final active = _activeRequest;
      if (active != null) {
        try {
          await active;
        } on Object {
          // The request reports its own failures through chat state.
        }
      }
      if (_requestActive) return;
    }

    final latest = state.value;
    if (latest == null || latest.sending) return;
    _requestCanceled = false;
    await _runRequest(
      () => _send(
        text,
        attachments: attachments,
        editingMessageId: editingMessageId,
      ),
    );
  }

  Future<bool> _selectionSettled() async {
    while (true) {
      final selection = _selection;
      if (selection == null) return ref.mounted;
      try {
        await selection;
      } on Object {
        return false;
      }
      if (identical(_selection, selection)) return ref.mounted;
    }
  }

  Future<void> _runRequest(Future<void> Function() body) async {
    _requestActive = true;
    final done = Completer<void>();
    _activeRequest = done.future;
    try {
      await body();
    } finally {
      _requestActive = false;
      if (identical(_activeRequest, done.future)) _activeRequest = null;
      done.complete();
    }
  }

  Future<void> _send(
    String text, {
    required List<ChatAttachment> attachments,
    String? editingMessageId,
  }) async {
    final current = state.value;
    if (current == null) return;

    final generation = ++_generation;
    // A prompt is an explicit action on this chat; a navigation that was still
    // loading when it started must not replace the transcript afterwards.
    _sessionEpoch++;
    final database = ref.read(databaseProvider);
    final now = _nextTimestamp(
      current.messages.isEmpty ? null : current.messages.last.createdAt,
    );

    final existingSessionId = current.currentSessionId;
    late String sessionId;
    var sessions = current.sessions;
    var messages = current.messages;

    // First prompt in a draft chat creates the session and titles it.
    if (existingSessionId == null) {
      final session = ChatSession(
        id: 'session-${now.microsecondsSinceEpoch}-$_sessionEpoch',
        title: _titleFor(text, attachments),
        createdAt: now,
        updatedAt: now,
      );
      try {
        await database.saveSession(session);
      } on Object {
        _publishCurrentFailure('The chat could not be created.', generation);
        return;
      }
      if (generation != _generation || !ref.mounted) {
        await _deleteSessionQuietly(database, session.id);
        return;
      }
      sessionId = session.id;
      messages = const [];
      try {
        sessions = await database.allSessions();
      } on Object {
        sessions = [...current.sessions, session];
      }
    } else {
      sessionId = existingSessionId;
    }

    // Editing a prompt restarts the conversation from that turn: the target
    // and every later message are deleted before the replacement is saved.
    if (editingMessageId != null) {
      ChatMessage? target;
      for (final message in messages) {
        if (message.id == editingMessageId) {
          target = message;
          break;
        }
      }
      if (target != null) {
        messages = messages
            .takeWhile((message) => message.id != editingMessageId)
            .toList();
        try {
          await database.deleteMessagesFromId(sessionId, target.id);
        } on Object {
          _publishCurrentFailure(
            'The prompt could not be updated.',
            generation,
          );
          return;
        }
      }
    }
    if (generation != _generation || !ref.mounted) return;

    final userMessage = ChatMessage(
      id: _messageId(sessionId, _nextSequence(messages), ChatRole.user),
      role: ChatRole.user,
      text: text,
      createdAt: now,
      attachments: attachments,
    );
    final history = [...messages, userMessage];
    final latest = state.value;
    if (latest == null) {
      if (existingSessionId == null) {
        await _deleteSessionQuietly(database, sessionId);
      }
      return;
    }

    state = AsyncData(
      latest.copyWith(
        sessions: existingSessionId == null ? sessions : latest.sessions,
        currentSessionId: sessionId,
        messages: history,
        sending: true,
        streamingText: '',
        clearFailure: true,
      ),
    );

    try {
      await database.saveMessage(userMessage, sessionId: sessionId);
    } on Object {
      _removeUnsavedUserMessage(sessionId, userMessage, generation);
      return;
    }
    try {
      await database.touchSession(sessionId, now);
    } on Object {
      // The turn is persisted; a stale session timestamp is recoverable.
    }
    if (generation != _generation) {
      await _discardMessageIfSessionMissing(database, sessionId, userMessage);
      return;
    }

    await _generateReply(
      sessionId: sessionId,
      messages: history,
      generation: generation,
    );
  }

  /// Regenerates the reply for the last user turn without saving it again.
  Future<void> retryReply() async {
    if (!await _selectionSettled()) return;
    final current = state.value;
    final failure = current?.failure;
    if (current == null ||
        failure == null ||
        current.sending ||
        current.currentSessionId != failure.sessionId ||
        !failure.retryable) {
      return;
    }
    final messages = current.messages;
    if (messages.isEmpty || messages.last.role != ChatRole.user) return;

    if (_requestActive) {
      if (!_requestCanceled) return;
      final active = _activeRequest;
      if (active != null) {
        try {
          await active;
        } on Object {
          // The request reports its own failures through chat state.
        }
      }
      if (_requestActive) return;
    }

    final latest = state.value;
    final latestFailure = latest?.failure;
    if (latest == null ||
        latest.sending ||
        !identical(latestFailure, failure) ||
        latest.currentSessionId != failure.sessionId) {
      return;
    }

    _requestCanceled = false;
    await _runRequest(() => _retryReplyBody(failure));
  }

  Future<void> _retryReplyBody(ChatFailure failure) async {
    final current = state.value;
    if (current == null || !identical(current.failure, failure)) return;
    final messages = current.messages;
    if (messages.isEmpty || messages.last.role != ChatRole.user) return;

    final generation = ++_generation;
    _sessionEpoch++;
    state = AsyncData(
      current.copyWith(sending: true, streamingText: '', clearFailure: true),
    );

    final database = ref.read(databaseProvider);
    late final List<ChatMessage> persisted;
    try {
      persisted = await database.messagesForSession(failure.sessionId);
    } on Object {
      _publishFailure(
        failure.sessionId,
        'The conversation could not be loaded. Try again.',
        retryable: true,
        generation: generation,
      );
      return;
    }
    if (!ref.mounted || generation != _generation) return;

    final latest = state.value;
    if (latest == null || latest.currentSessionId != failure.sessionId) return;

    if (persisted.isEmpty) {
      _publishFailure(
        failure.sessionId,
        'The last prompt is no longer available.',
        retryable: false,
        generation: generation,
      );
      return;
    }

    // A prior attempt may have committed the reply but failed to update state.
    // Replaying the persisted transcript is safer than generating a duplicate.
    if (persisted.last.role == ChatRole.assistant ||
        persisted.last.id != messages.last.id) {
      state = AsyncData(
        latest.copyWith(
          messages: persisted,
          sending: false,
          clearStreaming: true,
          clearFailure: true,
        ),
      );
      return;
    }

    state = AsyncData(
      latest.copyWith(
        messages: persisted,
        sending: true,
        streamingText: '',
        clearFailure: true,
      ),
    );
    await _generateReply(
      sessionId: failure.sessionId,
      messages: persisted,
      generation: generation,
    );
  }

  /// Stops native generation. Partial text is discarded and never persisted.
  Future<void> cancelReply() async {
    final current = state.value;
    if (current == null || !current.sending) return;
    _generation++;
    _requestCanceled = true;
    final iterator = _activeIterator;
    _activeIterator = null;
    state = AsyncData(current.copyWith(sending: false, clearStreaming: true));
    await _cancelIterator(iterator);

    final active = _activeRequest;
    if (active != null) {
      try {
        await active;
      } on Object {
        // The request reports its own failures through chat state.
      }
    }
  }

  Future<void> _generateReply({
    required String sessionId,
    required List<ChatMessage> messages,
    required int generation,
  }) async {
    if (generation != _generation) return;
    final prompt = messages.last;
    if (prompt.role != ChatRole.user) return;

    if (prompt.text.trim().isEmpty && prompt.attachments.isNotEmpty) {
      _publishFailure(
        sessionId,
        'Attachments cannot be read by the local model yet. '
        'Send a text prompt instead.',
        retryable: false,
        generation: generation,
      );
      return;
    }

    StreamIterator<AiResponse>? iterator;
    try {
      // The model may have been removed since it was selected; revalidate
      // before the runtime touches the path.
      await ref.read(modelConfigurationProvider.notifier).revalidate();
      if (generation != _generation) return;

      final stream = ref
          .read(intelligenceEngineProvider)
          .stream(_contextBuilder.build(messages));
      iterator = StreamIterator(stream);
      _activeIterator = iterator;

      final buffer = StringBuffer();
      while (await iterator.moveNext()) {
        if (generation != _generation) return;
        final text = iterator.current.text;
        if (text.isEmpty) continue;
        buffer
          ..clear()
          ..write(text);
        _publishStreaming(sessionId, text, generation);
      }
      if (generation != _generation) return;

      final text = buffer.toString();
      if (text.trim().isEmpty) {
        _publishFailure(
          sessionId,
          'The local model returned an empty response.',
          retryable: true,
          generation: generation,
        );
        return;
      }
      await _commitReply(
        sessionId,
        text,
        generation,
        after: prompt.createdAt,
        sequence: _nextSequence(messages),
      );
    } on IntelligenceException catch (error) {
      if (generation != _generation) return;
      _publishFailure(
        sessionId,
        _failureMessageFor(error),
        retryable: _retryable(error),
        generation: generation,
      );
    } on Object {
      if (generation != _generation) return;
      _publishFailure(
        sessionId,
        'The local model could not answer. Try again.',
        retryable: true,
        generation: generation,
      );
    } finally {
      if (identical(_activeIterator, iterator)) _activeIterator = null;
      await _cancelIterator(iterator);
      if (generation == _generation) _finishStreaming();
    }
  }

  Future<void> _commitReply(
    String sessionId,
    String text,
    int generation, {
    required DateTime after,
    required int sequence,
  }) async {
    if (generation != _generation) return;

    final database = ref.read(databaseProvider);
    final replyTime = _nextTimestamp(after);
    final reply = ChatMessage(
      id: _messageId(sessionId, sequence, ChatRole.assistant),
      role: ChatRole.assistant,
      text: text,
      createdAt: replyTime,
    );
    await database.saveMessage(reply, sessionId: sessionId);
    try {
      await database.touchSession(sessionId, replyTime);
    } on Object {
      // The reply is persisted; a stale session timestamp is recoverable.
    }

    // A delete can win while the insert is in flight. Do not leave the reply
    // behind as an orphan when its session no longer exists.
    var sessionExists = true;
    try {
      sessionExists = await database.sessionById(sessionId) != null;
    } on Object {
      // If existence cannot be checked, keep the saved reply.
    }
    if (!sessionExists) {
      await _discardMessage(database, sessionId, reply);
      return;
    }
    if (!ref.mounted || generation != _generation) return;

    List<ChatSession>? sessions;
    List<ChatSession>? archived;
    try {
      sessions = await database.allSessions();
      archived = await database.allSessions(archived: true);
    } on Object {
      // The reply is already durable; keep the current sidebar snapshot.
    }
    if (!ref.mounted || generation != _generation) return;

    final latest = state.value;
    if (latest == null) return;
    final stillOnSession = latest.currentSessionId == sessionId;
    state = AsyncData(
      latest.copyWith(
        sessions: sessions ?? latest.sessions,
        archivedSessions: archived ?? latest.archivedSessions,
        messages: stillOnSession ? [...latest.messages, reply] : null,
        sending: false,
        clearStreaming: true,
        clearFailure: true,
      ),
    );
  }

  void _publishStreaming(String sessionId, String text, int generation) {
    if (!ref.mounted || generation != _generation) return;
    final current = state.value;
    if (current == null || current.currentSessionId != sessionId) return;
    state = AsyncData(
      current.copyWith(sending: true, streamingText: text, clearFailure: true),
    );
  }

  void _publishFailure(
    String sessionId,
    String message, {
    required bool retryable,
    required int generation,
  }) {
    if (!ref.mounted || generation != _generation) return;
    final current = state.value;
    if (current == null || current.currentSessionId != sessionId) return;
    state = AsyncData(
      current.copyWith(
        sending: false,
        clearStreaming: true,
        failure: ChatFailure(
          sessionId: sessionId,
          message: message,
          retryable: retryable,
        ),
      ),
    );
  }

  void _publishCurrentFailure(String message, int generation) {
    if (!ref.mounted || generation != _generation) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        sending: false,
        clearStreaming: true,
        failure: ChatFailure(
          sessionId: current.currentSessionId ?? '',
          message: message,
          retryable: false,
        ),
      ),
    );
  }

  void _removeUnsavedUserMessage(
    String sessionId,
    ChatMessage message,
    int generation,
  ) {
    if (!ref.mounted || generation != _generation) return;
    final current = state.value;
    if (current == null || current.currentSessionId != sessionId) return;
    state = AsyncData(
      current.copyWith(
        messages: current.messages
            .where((candidate) => candidate.id != message.id)
            .toList(growable: false),
        sending: false,
        clearStreaming: true,
        failure: ChatFailure(
          sessionId: sessionId,
          message: 'The message could not be saved to local history.',
          retryable: false,
        ),
      ),
    );
  }

  void _finishStreaming() {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null || !current.sending) return;
    state = AsyncData(current.copyWith(sending: false, clearStreaming: true));
  }

  void _abortGeneration() {
    _cancelActiveGeneration();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null ||
        (!current.sending && current.streamingText == null)) {
      return;
    }
    state = AsyncData(current.copyWith(sending: false, clearStreaming: true));
  }

  void _cancelActiveGeneration() {
    _generation++;
    _requestCanceled = true;
    final iterator = _activeIterator;
    _activeIterator = null;
    if (iterator != null) unawaited(_cancelIterator(iterator));
  }

  static Future<void> _cancelIterator(
    StreamIterator<AiResponse>? iterator,
  ) async {
    try {
      await iterator?.cancel();
    } on Object {
      // Cancellation is best effort; terminal state is still cleared.
    }
  }

  static Future<void> _deleteSessionQuietly(
    AppDatabase database,
    String sessionId,
  ) async {
    try {
      await database.deleteSession(sessionId);
    } on Object {
      // A failed cleanup leaves an empty session, not a corrupt transcript.
    }
  }

  static Future<void> _discardMessage(
    AppDatabase database,
    String sessionId,
    ChatMessage message,
  ) async {
    try {
      await database.deleteMessagesFrom(sessionId, message.createdAt);
    } on Object {
      // Best effort: a failed cleanup never changes visible chat state.
    }
  }

  static Future<void> _discardMessageIfSessionMissing(
    AppDatabase database,
    String sessionId,
    ChatMessage message,
  ) async {
    try {
      if (await database.sessionById(sessionId) != null) return;
      await _discardMessage(database, sessionId, message);
    } on Object {
      // If existence cannot be checked, keep the saved message.
    }
  }

  static String _messageId(String sessionId, int sequence, ChatRole role) {
    final tag = role == ChatRole.user ? 'u' : 'a';
    return '$sessionId-${sequence.toString().padLeft(6, '0')}-$tag';
  }

  static int _nextSequence(List<ChatMessage> messages) {
    var next = 0;
    for (final message in messages) {
      final match = _messageSequence.firstMatch(message.id);
      if (match == null) continue;
      final value = int.parse(match.group(1)!) + 1;
      if (value > next) next = value;
    }
    return next;
  }

  /// Keeps generated turns strictly ordered even when the platform clock only
  /// has millisecond resolution.
  static DateTime _nextTimestamp(DateTime? after) {
    final now = DateTime.now();
    if (after != null && !now.isAfter(after)) {
      return after.add(const Duration(microseconds: 1));
    }
    return now;
  }

  static String _failureMessageFor(IntelligenceException error) {
    return switch (error) {
      ProviderUnavailableException(:final cause)
          when cause is UnsupportedError =>
        'This device cannot run the selected local model.',
      ProviderUnavailableException() =>
        'The local model is not available. Check the model in Models, '
            'then retry.',
      UnsupportedCapabilityException() =>
        'The selected model cannot handle this request.',
      InvalidRequestException() =>
        'This prompt could not be sent to the local model.',
      InferenceFailedException() =>
        'The local model could not finish the reply. Try again.',
    };
  }

  static bool _retryable(IntelligenceException error) {
    return switch (error) {
      ProviderUnavailableException(:final cause)
          when cause is UnsupportedError =>
        false,
      UnsupportedCapabilityException() || InvalidRequestException() => false,
      ProviderUnavailableException() || InferenceFailedException() => true,
    };
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
    if (state.value?.currentSessionId == id) _abortGeneration();
    await database.setSessionArchived(id, true);

    final latest = state.value;
    if (latest?.currentSessionId != id) {
      await _refreshSessions();
      return;
    }

    final epoch = ++_sessionEpoch;
    final sessions = await database.allSessions();
    final archived = await database.allSessions(archived: true);
    final next = _mostRecentId(sessions);
    final messages = next == null
        ? const <ChatMessage>[]
        : await database.messagesForSession(next);
    if (!ref.mounted) return;
    if (epoch != _sessionEpoch) {
      await _refreshSessions();
      return;
    }

    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        sessions: sessions,
        archivedSessions: archived,
        currentSessionId: next,
        messages: messages,
        clearCurrentSession: next == null,
        sending: false,
        clearStreaming: true,
        clearFailure: true,
      ),
    );
  }

  Future<void> restoreSession(String id) async {
    await ref.read(databaseProvider).setSessionArchived(id, false);
    await _refreshSessions();
  }

  Future<void> deleteSession(String id) async {
    final database = ref.read(databaseProvider);
    if (state.value?.currentSessionId == id) _abortGeneration();
    await database.deleteSession(id);

    final latest = state.value;
    if (latest?.currentSessionId != id) {
      await _refreshSessions();
      return;
    }

    final epoch = ++_sessionEpoch;
    final sessions = await database.allSessions();
    final archived = await database.allSessions(archived: true);
    final next = _mostRecentId(sessions);
    final messages = next == null
        ? const <ChatMessage>[]
        : await database.messagesForSession(next);
    if (!ref.mounted) return;
    if (epoch != _sessionEpoch) {
      await _refreshSessions();
      return;
    }

    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        sessions: sessions,
        archivedSessions: archived,
        currentSessionId: next,
        messages: messages,
        clearCurrentSession: next == null,
        sending: false,
        clearStreaming: true,
        clearFailure: true,
      ),
    );
  }

  /// Settings action: wipe every conversation. A fresh install stays empty;
  /// no fixture is re-created here.
  Future<void> clearHistory() async {
    final epoch = ++_sessionEpoch;
    _abortGeneration();
    final database = ref.read(databaseProvider);
    await database.resetAll();
    final loaded = await _load(selectMostRecent: true);
    if (!ref.mounted || epoch != _sessionEpoch) return;
    state = AsyncData(loaded);
  }

  Future<void> _refreshSessions() async {
    final epoch = ++_refreshEpoch;
    final database = ref.read(databaseProvider);
    final sessions = await database.allSessions();
    final archived = await database.allSessions(archived: true);
    if (!ref.mounted || epoch != _refreshEpoch) return;
    final latest = state.value;
    if (latest == null) return;
    state = AsyncData(
      latest.copyWith(sessions: sessions, archivedSessions: archived),
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
