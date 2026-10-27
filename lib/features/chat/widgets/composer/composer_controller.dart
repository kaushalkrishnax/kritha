import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/chat_attachment.dart';

enum LiveTalkPhase {
  listening,
  userSpeaking,
  interrupted,
  processing,
  thinking,
  speaking,
  paused,
}

extension LiveTalkPhaseX on LiveTalkPhase {
  bool get isListening =>
      this == LiveTalkPhase.listening ||
      this == LiveTalkPhase.userSpeaking ||
      this == LiveTalkPhase.interrupted;

  bool get isThinking =>
      this == LiveTalkPhase.processing || this == LiveTalkPhase.thinking;

  bool get isSpeaking => this == LiveTalkPhase.speaking || isThinking;

  bool get isPaused => this == LiveTalkPhase.paused;
}

/// Everything the composer needs to decide its layout.
class ComposerState {
  const ComposerState({
    this.draftText = '',
    this.measuredLines = 1,
    this.isExpanded = false,
    this.attachments = const [],
    this.isLiveTalkActive = false,
    this.liveTalkPhase = LiveTalkPhase.listening,
    this.editingMessageId,
  });

  final String draftText;
  final int measuredLines;
  final bool isExpanded;
  final List<ChatAttachment> attachments;
  final bool isLiveTalkActive;
  final LiveTalkPhase liveTalkPhase;
  final String? editingMessageId;

  bool get isEditing => editingMessageId != null;

  bool get hasText => draftText.trim().isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasContent => hasText || hasAttachments;
  bool get expandsFromContent => hasAttachments || isExpanded;

  ComposerState copyWith({
    String? draftText,
    int? measuredLines,
    bool? isExpanded,
    List<ChatAttachment>? attachments,
    bool? isLiveTalkActive,
    LiveTalkPhase? liveTalkPhase,
    String? editingMessageId,
    bool clearEditing = false,
  }) {
    return ComposerState(
      draftText: draftText ?? this.draftText,
      measuredLines: measuredLines ?? this.measuredLines,
      isExpanded: isExpanded ?? this.isExpanded,
      attachments: attachments ?? this.attachments,
      isLiveTalkActive: isLiveTalkActive ?? this.isLiveTalkActive,
      liveTalkPhase: liveTalkPhase ?? this.liveTalkPhase,
      editingMessageId: clearEditing
          ? null
          : (editingMessageId ?? this.editingMessageId),
    );
  }
}

class ComposerNotifier extends Notifier<ComposerState> {
  @override
  ComposerState build() => const ComposerState();

  void setDraftText(String text) {
    state = state.copyWith(draftText: text);
  }

  void setMeasuredLines(int lines) {
    final clamped = lines.clamp(1, 9);
    if (clamped != state.measuredLines) {
      state = state.copyWith(measuredLines: clamped);
    }
  }

  void setMeasurement({required int lines, required bool expanded}) {
    final clamped = lines.clamp(1, 9);
    if (clamped == state.measuredLines && expanded == state.isExpanded) return;
    state = state.copyWith(measuredLines: clamped, isExpanded: expanded);
  }

  void setExpanded(bool value) {
    if (value != state.isExpanded) {
      state = state.copyWith(isExpanded: value);
    }
  }

  void addAttachments(Iterable<ChatAttachment> attachments) {
    if (attachments.isEmpty) return;
    final existingIds = {for (final item in state.attachments) item.id};
    final next = [
      ...state.attachments,
      for (final item in attachments)
        if (!existingIds.contains(item.id)) item,
    ];
    state = state.copyWith(attachments: next);
  }

  void removeAttachment(String id) {
    state = state.copyWith(
      attachments: [
        for (final item in state.attachments)
          if (item.id != id) item,
      ],
    );
  }

  void clearAttachments() {
    if (state.attachments.isEmpty) return;
    state = state.copyWith(attachments: const []);
  }

  void clearDraft() {
    state = state.copyWith(
      draftText: '',
      measuredLines: 1,
      isExpanded: false,
      attachments: const [],
      clearEditing: true,
    );
  }

  void beginEditingMessage(String id, String text) {
    state = state.copyWith(
      editingMessageId: id,
      draftText: text,
      measuredLines: 1,
      isExpanded: false,
    );
  }

  void cancelEditing() {
    if (!state.isEditing) return;
    state = state.copyWith(clearEditing: true);
  }

  void setLiveTalkActive(bool value) {
    state = state.copyWith(
      isLiveTalkActive: value,
      liveTalkPhase: value ? LiveTalkPhase.listening : LiveTalkPhase.paused,
    );
  }

  void setLiveTalkPhase(LiveTalkPhase phase) {
    state = state.copyWith(liveTalkPhase: phase);
  }

  void toggleLiveTalkPause() {
    state = state.copyWith(
      liveTalkPhase: state.liveTalkPhase.isPaused
          ? LiveTalkPhase.listening
          : LiveTalkPhase.paused,
    );
  }
}

final composerProvider = NotifierProvider<ComposerNotifier, ComposerState>(
  ComposerNotifier.new,
);
