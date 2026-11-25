import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../services/silero_vad_service.dart';
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

/// Orchestrates the continuous Live Talk loop:
/// mic PCM stream -> Silero VAD + TurnDetector -> ASR -> Intelligence -> TTS -> playback,
/// with voice barge-in and single-source-of-truth mic state.
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
  String? _ttsTempPath;

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

    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: SileroVadSession.sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
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

      final smoothedLevel =
          (state.audioLevel * 0.60 + vadResult.level * 0.40).clamp(0.0, 1.0);
      if ((smoothedLevel - state.audioLevel).abs() > 0.015) {
        state = state.copyWith(audioLevel: smoothedLevel);
      }

      final signal = _turnDetector.accept(vadResult.probability);
      if (signal == TurnSignal.speechStart) {
        // Voice barge-in: cancel in-flight response/TTS immediately.
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

      await ref.read(chatControllerProvider.notifier).send(transcript);
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
      final ttsModelId = _ttsModelId(active);
      if (ttsModelId == null) {
        if (isCurrent()) _setPhase(LiveTalkPhase.listening);
        return;
      }

      _setPhase(LiveTalkPhase.speaking);
      final speech = await engine.synthesizeSpeech(
        text: replyText,
        modelId: ttsModelId,
      );
      if (!isCurrent()) return;

      final dir = await getTemporaryDirectory();
      final ext = speech.mimeType.contains('wav') ? 'wav' : 'mp3';
      final file = File(
        '${dir.path}/kritha_live_tts_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(speech.bytes, flush: true);
      _cleanupTtsFile();
      _ttsTempPath = file.path;

      // Avoid stealing audio focus from the active mic capture stream.
      final player = _player ??= AudioPlayer(
        handleAudioSessionActivation: false,
      );
      await player.setFilePath(file.path);
      if (!isCurrent()) return;
      await player.play();
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
    _cleanupTtsFile();
  }

  void _cleanupTtsFile() {
    final path = _ttsTempPath;
    _ttsTempPath = null;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on Object {
      // Best-effort cleanup.
    }
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
