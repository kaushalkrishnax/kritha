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

/// Orchestrates the real-time Live Talk loop:
/// mic PCM stream -> Silero VAD + TurnDetector -> ASR -> Intelligence -> TTS -> playback.
class LiveTalkNotifier extends Notifier<LiveTalkState> {
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;
  AudioPlayer? _player;
  SileroVadSession? _vad;
  final TurnDetector _turnDetector = TurnDetector();
  final List<int> _pcmCarry = [];
  final List<int> _utteranceBytes = [];
  int _sessionEpoch = 0;
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
          (state.audioLevel * 0.65 + vadResult.level * 0.35).clamp(0.0, 1.0);
      if ((smoothedLevel - state.audioLevel).abs() > 0.02) {
        state = state.copyWith(audioLevel: smoothedLevel);
      }

      final signal = _turnDetector.accept(vadResult.probability);
      if (signal == TurnSignal.speechStart) {
        if (state.phase.isSpeaking) {
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
          unawaited(_processUtterance(captured, epoch));
        }
      } else if (signal == TurnSignal.speechEnd) {
        _utteranceBytes.addAll(frameBytes);
        final captured = List<int>.from(_utteranceBytes);
        _utteranceBytes.clear();
        unawaited(_processUtterance(captured, epoch));
      }
    }
  }

  Future<void> _processUtterance(List<int> pcmBytes, int epoch) async {
    if (epoch != _sessionEpoch || !state.active || pcmBytes.length < 3200) {
      if (state.active && !state.phase.isPaused) {
        _setPhase(LiveTalkPhase.listening);
      }
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

      if (epoch != _sessionEpoch || !state.active || transcript.isEmpty) {
        if (state.active && !state.phase.isPaused) {
          _setPhase(LiveTalkPhase.listening);
        }
        return;
      }

      state = state.copyWith(lastTranscript: transcript);
      _setPhase(LiveTalkPhase.thinking);

      await ref.read(chatControllerProvider.notifier).send(transcript);
      if (epoch != _sessionEpoch || !state.active) return;

      final chatMessages = ref.read(chatControllerProvider).value?.messages;
      final replyText = chatMessages != null &&
              chatMessages.isNotEmpty &&
              chatMessages.last.role.name == 'assistant'
          ? chatMessages.last.text.trim()
          : '';
      if (replyText.isEmpty) {
        _setPhase(LiveTalkPhase.listening);
        return;
      }

      state = state.copyWith(lastReply: replyText);
      final ttsModelId = _ttsModelId(active);
      if (ttsModelId == null) {
        _setPhase(LiveTalkPhase.listening);
        return;
      }

      _setPhase(LiveTalkPhase.speaking);
      final speech = await engine.synthesizeSpeech(
        text: replyText,
        modelId: ttsModelId,
      );
      if (epoch != _sessionEpoch || !state.active || state.phase.isPaused) {
        return;
      }

      final dir = await getTemporaryDirectory();
      final ext = speech.mimeType.contains('wav') ? 'wav' : 'mp3';
      final file = File(
        '${dir.path}/kritha_live_tts_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(speech.bytes, flush: true);
      _cleanupTtsFile();
      _ttsTempPath = file.path;

      final player = _player ??= AudioPlayer();
      await player.setFilePath(file.path);
      if (epoch != _sessionEpoch || !state.active || state.phase.isPaused) {
        return;
      }
      await player.play();
      if (epoch == _sessionEpoch && state.active && !state.phase.isPaused) {
        _setPhase(LiveTalkPhase.listening);
      }
    } on Object catch (error) {
      if (epoch == _sessionEpoch && state.active) {
        state = state.copyWith(errorMessage: '$error');
        _setPhase(LiveTalkPhase.listening);
      }
    }
  }

  Future<void> togglePause() async {
    if (!state.active) return;
    if (state.phase.isPaused) {
      _turnDetector.reset();
      _utteranceBytes.clear();
      _setPhase(LiveTalkPhase.listening);
    } else {
      await _stopPlayback();
      _turnDetector.reset();
      _utteranceBytes.clear();
      _setPhase(LiveTalkPhase.paused);
    }
  }

  Future<void> stop() async {
    _sessionEpoch++;
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
