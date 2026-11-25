import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../services/silero_vad_service.dart';
import '../../services/wake_word_bridge.dart';
import '../intelligence/models/task_registry.dart';
import '../intelligence/providers/providers.dart';
import '../models/active/active_models.dart';
import '../models/catalogue/catalogue_model.dart';
import 'chat_controller.dart';
import 'widgets/composer/composer_controller.dart';

class LiveTalkState {
  const LiveTalkState({
    this.active = false,
    this.phase = LiveTalkPhase.listening,
    this.audioLevel = 0.0,
    this.lastTranscript = '',
    this.lastReply = '',
    this.errorMessage,
  });

  final bool active;
  final LiveTalkPhase phase;
  final double audioLevel;
  final String lastTranscript;
  final String lastReply;
  final String? errorMessage;

  LiveTalkState copyWith({
    bool? active,
    LiveTalkPhase? phase,
    double? audioLevel,
    String? lastTranscript,
    String? lastReply,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LiveTalkState(
      active: active ?? this.active,
      phase: phase ?? this.phase,
      audioLevel: audioLevel ?? this.audioLevel,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      lastReply: lastReply ?? this.lastReply,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Orchestrates continuous Live Talk with streamed sentence-pipelined TTS:
/// mic PCM stream -> Silero VAD + TurnDetector -> ASR -> streamed LLM ->
/// per-sentence TTS -> playback, with voice barge-in.
class LiveTalkNotifier extends Notifier<LiveTalkState> {
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;
  AudioPlayer? _player;
  SileroVadSession? _vad;
  final TurnDetector _turnDetector = TurnDetector(silenceFrameCount: 20);
  final List<int> _pcmCarry = [];
  final List<int> _utteranceBytes = [];
  int _sessionEpoch = 0;
  int _turnEpoch = 0;
  final List<String> _ttsTempFiles = [];

  @override
  LiveTalkState build() {
    ref.onDispose(() {
      unawaited(stop());
    });
    return const LiveTalkState();
  }

  Future<void> start() async {
    if (state.active) return;
    final epoch = ++_sessionEpoch;
    _turnEpoch++;
    final recorder = _recorder ??= AudioRecorder();
    final allowed = await recorder.hasPermission();
    if (!allowed) {
      state = state.copyWith(
        errorMessage: 'Microphone permission is required for Live Talk.',
      );
      ref.read(composerProvider.notifier).setLiveTalkActive(false);
      return;
    }

    final active = await ref.read(activeModelsProvider.future);
    final sttModelId = _sttModelId(active);
    final textModelId = _textModelId(active);
    if (sttModelId == null || textModelId == null) {
      state = state.copyWith(
        errorMessage: sttModelId == null
            ? 'Assign a Speech recognition or Audio model in Active Models.'
            : 'Assign a Text model in Active Models.',
      );
      ref.read(composerProvider.notifier).setLiveTalkActive(false);
      return;
    }

    _vad = await SileroVadSession.create();
    if (epoch != _sessionEpoch || !ref.mounted) {
      _vad?.dispose();
      _vad = null;
      return;
    }

    _turnDetector.reset();
    _pcmCarry.clear();
    _utteranceBytes.clear();

    ref.read(composerProvider.notifier)
      ..setLiveTalkActive(true)
      ..setLiveTalkPhase(LiveTalkPhase.listening);
    state = const LiveTalkState(
      active: true,
      phase: LiveTalkPhase.listening,
    );
    unawaited(WakeWordBridge.setKeepScreenOn(true));

    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: SileroVadSession.sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
        ),
      ),
    );
    if (epoch != _sessionEpoch || !ref.mounted) return;
    _audioSub = stream.listen(
      (chunk) => _onAudioChunk(chunk, epoch),
      onError: (_) {
        if (epoch == _sessionEpoch) unawaited(stop());
      },
    );
  }

  void _onAudioChunk(Uint8List chunk, int epoch) {
    if (epoch != _sessionEpoch || !state.active) return;
    if (state.phase.isPaused) return;
    _pcmCarry.addAll(chunk);

    const frameByteCount = SileroVadSession.frameSamples * 2;
    while (_pcmCarry.length >= frameByteCount) {
      final frameBytes = _pcmCarry.sublist(0, frameByteCount);
      _pcmCarry.removeRange(0, frameByteCount);
      final pcm16 = Int16List.view(Uint8List.fromList(frameBytes).buffer);
      final vadResult = _vad?.processFrame(pcm16);
      if (vadResult == null) continue;

      final attack = vadResult.level > state.audioLevel;
      final smoothedLevel = (attack
              ? state.audioLevel * 0.25 + vadResult.level * 0.75
              : state.audioLevel * 0.65 + vadResult.level * 0.35)
          .clamp(0.0, 1.0);
      if ((smoothedLevel - state.audioLevel).abs() > 0.008) {
        state = state.copyWith(audioLevel: smoothedLevel);
      }

      final signal = _turnDetector.accept(vadResult.probability);
      if (signal == TurnSignal.speechStart) {
        if (state.phase == LiveTalkPhase.speaking ||
            state.phase == LiveTalkPhase.thinking ||
            state.phase == LiveTalkPhase.processing) {
          _turnEpoch++;
          unawaited(_stopPlayback());
        }
        _utteranceBytes.clear();
        _utteranceBytes.addAll(frameBytes);
        _setPhase(LiveTalkPhase.userSpeaking);
      } else if (_turnDetector.inSpeech) {
        _utteranceBytes.addAll(frameBytes);
        if (_utteranceBytes.length > SileroVadSession.sampleRate * 2 * 25) {
          final captured = List<int>.from(_utteranceBytes);
          _utteranceBytes.clear();
          _turnDetector.reset();
          _vad?.reset();
          unawaited(_processUtterance(captured, epoch, ++_turnEpoch));
        }
      } else if (signal == TurnSignal.speechEnd) {
        _utteranceBytes.addAll(frameBytes);
        final captured = List<int>.from(_utteranceBytes);
        _utteranceBytes.clear();
        _vad?.reset();
        unawaited(_processUtterance(captured, epoch, ++_turnEpoch));
      }
    }
  }

  Future<void> _processUtterance(
    List<int> pcmBytes,
    int epoch,
    int turnEpoch,
  ) async {
    bool isCurrent() =>
        epoch == _sessionEpoch &&
        turnEpoch == _turnEpoch &&
        state.active &&
        !state.phase.isPaused;

    if (!isCurrent() || pcmBytes.length < 3200) {
      if (isCurrent()) _setPhase(LiveTalkPhase.listening);
      return;
    }

    _setPhase(LiveTalkPhase.processing);
    ProviderSubscription<AsyncValue<ChatState>>? chatSub;
    try {
      final active = await ref.read(activeModelsProvider.future);
      final sttModelId = _sttModelId(active);
      final textModelId = _textModelId(active);
      if (sttModelId == null || textModelId == null) return;

      final wav = pcm16ToWav(pcmBytes, sampleRate: SileroVadSession.sampleRate);
      final engine = ref.read(intelligenceEngineProvider);
      final transcript = (await engine.transcribeAudio(
        bytes: wav,
        mimeType: 'audio/wav',
        modelId: sttModelId,
      )).trim();

      if (!isCurrent() || transcript.isEmpty) {
        if (isCurrent()) _setPhase(LiveTalkPhase.listening);
        return;
      }

      state = state.copyWith(lastTranscript: transcript);
      _setPhase(LiveTalkPhase.thinking);

      final ttsModelId = _ttsModelId(active);
      final ttsQueue = Queue<Future<String?>>();
      var synthesizedOffset = 0;
      var playbackStarted = false;
      var playbackCompleter = Completer<void>();

      Future<void> pumpPlayback() async {
        if (playbackStarted) return;
        playbackStarted = true;
        try {
          // Keep voice-communication mode and hardware AEC intact during TTS playback.
          final player = _player ??= AudioPlayer(
            handleAudioSessionActivation: false,
            androidApplyAudioAttributes: false,
          );
          while (ttsQueue.isNotEmpty && isCurrent()) {
            final path = await ttsQueue.removeFirst();
            if (path == null || !isCurrent()) continue;
            _setPhase(LiveTalkPhase.speaking);
            await player.setFilePath(path);
            if (!isCurrent()) break;
            await player.play();
          }
        } finally {
          playbackStarted = false;
          if (!playbackCompleter.isCompleted) playbackCompleter.complete();
        }
      }

      void enqueueSentence(String sentence) {
        if (ttsModelId == null || sentence.trim().isEmpty || !isCurrent()) {
          return;
        }
        final future = _synthesizeSentenceTemp(
          engine: engine,
          ttsModelId: ttsModelId,
          sentence: sentence.trim(),
        );
        ttsQueue.add(future);
        if (!playbackStarted) {
          playbackCompleter = Completer<void>();
          unawaited(pumpPlayback());
        }
      }

      if (ttsModelId != null) {
        chatSub = ref.listen(chatControllerProvider, (prev, next) {
          if (!isCurrent()) return;
          final streamed = next.value?.streamingText;
          if (streamed == null || streamed.length <= synthesizedOffset) return;
          final slice = streamed.substring(synthesizedOffset);
          final boundary = RegExp(r'[.!?](?:\s+|$)|\n+').firstMatch(slice);
          if (boundary != null && boundary.end >= 20) {
            final sentence = slice.substring(0, boundary.end).trim();
            synthesizedOffset += boundary.end;
            enqueueSentence(sentence);
          }
        });
      }

      await ref.read(chatControllerProvider.notifier).send(transcript);
      chatSub?.close();
      chatSub = null;
      if (!isCurrent()) return;

      final chatMessages = ref.read(chatControllerProvider).value?.messages;
      final replyText = chatMessages != null &&
              chatMessages.isNotEmpty &&
              chatMessages.last.role.name == 'assistant'
          ? chatMessages.last.text.trim()
          : '';
      if (replyText.isEmpty) {
        if (isCurrent()) _setPhase(LiveTalkPhase.listening);
        return;
      }

      state = state.copyWith(lastReply: replyText);
      if (ttsModelId == null) {
        if (isCurrent()) _setPhase(LiveTalkPhase.listening);
        return;
      }

      if (synthesizedOffset < replyText.length) {
        enqueueSentence(replyText.substring(synthesizedOffset));
      }
      if (playbackStarted) {
        await playbackCompleter.future;
      }
      if (isCurrent()) {
        _turnDetector.reset();
        _vad?.reset();
        _setPhase(LiveTalkPhase.listening);
      }
    } on Object catch (error) {
      if (isCurrent()) {
        state = state.copyWith(errorMessage: '$error');
        _turnDetector.reset();
        _vad?.reset();
        _setPhase(LiveTalkPhase.listening);
      }
    } finally {
      chatSub?.close();
    }
  }

  Future<String?> _synthesizeSentenceTemp({
    required dynamic engine,
    required String ttsModelId,
    required String sentence,
  }) async {
    try {
      final speech = await engine.synthesizeSpeech(
        text: sentence,
        modelId: ttsModelId,
      );
      final dir = await getTemporaryDirectory();
      final ext = speech.mimeType.contains('wav') ? 'wav' : 'mp3';
      final file = File(
        '${dir.path}/kritha_live_tts_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(speech.bytes, flush: true);
      _ttsTempFiles.add(file.path);
      return file.path;
    } on Object {
      return null;
    }
  }

  /// Single mic button handler:
  /// - while speaking/thinking/processing -> interrupt and return to listening
  /// - while listening -> pause
  /// - while paused -> resume listening
  Future<void> handleMicButton() async {
    if (!state.active) return;
    if (state.phase.isPaused) {
      _turnDetector.reset();
      _vad?.reset();
      _utteranceBytes.clear();
      _setPhase(LiveTalkPhase.listening);
      return;
    }
    if (state.phase == LiveTalkPhase.speaking ||
        state.phase == LiveTalkPhase.thinking ||
        state.phase == LiveTalkPhase.processing) {
      _turnEpoch++;
      await _stopPlayback();
      _turnDetector.reset();
      _vad?.reset();
      _utteranceBytes.clear();
      _setPhase(LiveTalkPhase.listening);
      return;
    }
    _turnEpoch++;
    await _stopPlayback();
    _turnDetector.reset();
    _vad?.reset();
    _utteranceBytes.clear();
    _setPhase(LiveTalkPhase.paused);
  }

  Future<void> stop() async {
    _sessionEpoch++;
    _turnEpoch++;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _recorder?.stop();
    } on Object {
      // Recorder may already be stopped.
    }
    await _stopPlayback();
    _vad?.dispose();
    _vad = null;
    _pcmCarry.clear();
    _utteranceBytes.clear();
    _turnDetector.reset();
    unawaited(WakeWordBridge.setKeepScreenOn(false));
    if (ref.mounted) {
      ref.read(composerProvider.notifier).setLiveTalkActive(false);
      state = const LiveTalkState();
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _player?.stop();
    } on Object {
      // Best-effort stop.
    }
    _cleanupTtsFiles();
  }

  void _cleanupTtsFiles() {
    for (final path in _ttsTempFiles) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } on Object {
        // Best-effort cleanup.
      }
    }
    _ttsTempFiles.clear();
  }

  void _setPhase(LiveTalkPhase phase) {
    if (!ref.mounted) return;
    state = state.copyWith(phase: phase, clearError: true);
    ref.read(composerProvider.notifier).setLiveTalkPhase(phase);
  }

  static String? _sttModelId(ActiveModelsState active) =>
      active.executableSelection[AiTaskId.automaticSpeechRecognition] ??
      active.singleModels[ModelCapability.speechRecognition] ??
      active.executableSelection[AiTaskId.audioUnderstanding] ??
      active.singleModels[ModelCapability.audio] ??
      active.multiModel?.modelId;

  static String? _textModelId(ActiveModelsState active) =>
      active.executableSelection[AiTaskId.textGeneration] ??
      active.singleModels[ModelCapability.text] ??
      active.multiModel?.modelId;

  static String? _ttsModelId(ActiveModelsState active) =>
      active.executableSelection[AiTaskId.textToSpeech] ??
      active.singleModels[ModelCapability.textToSpeech];
}

final liveTalkProvider = NotifierProvider<LiveTalkNotifier, LiveTalkState>(
  LiveTalkNotifier.new,
);
