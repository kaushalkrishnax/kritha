import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../services/device_asr_service.dart';
import '../../services/device_tts_service.dart';
import '../../services/silero_vad_service.dart';
import '../../services/tts_audio_cache.dart';
import '../../services/tts_playback_pipeline.dart';
import '../../services/tts_settings.dart';
import '../../services/wake_word_bridge.dart';
import '../intelligence/models/task_registry.dart';
import '../intelligence/providers/providers.dart';
import '../models/active/active_models.dart';
import '../models/catalogue/catalogue_model.dart';
import 'chat_controller.dart';
import 'speech_playback_controller.dart';
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

/// Orchestrates continuous Live Talk: mic capture -> Silero VAD + turn
/// detection -> ASR -> streamed LLM -> sentence TTS -> playback, with
/// voice barge-in during generation and while TTS is speaking.
class LiveTalkNotifier extends Notifier<LiveTalkState> {
  static const _bargeInSpeechProbability = 0.6;
  static const _bargeInConfirmFrames = 3;
  static const _maxUtteranceSeconds = 30;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;
  AudioPlayer? _player;
  SileroVadSession? _vad;
  TtsPlaybackPipeline? _pipeline;
  DeviceTtsSession? _deviceTts;
  final TurnDetector _turnDetector = TurnDetector(
    silenceFrameCount: 22,
    maxSpeechFrames: 938,
  );
  final List<int> _pcmCarry = [];
  final List<int> _utteranceBytes = [];
  int _sessionEpoch = 0;
  int _turnEpoch = 0;
  int _bargeInStreak = 0;
  bool _usingDeviceAsr = false;
  String _deviceTurnTranscript = '';

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
    _bargeInStreak = 0;
    final recorder = _recorder ??= AudioRecorder();

    // Run permission, active-model lookup, and speech-stop concurrently.
    final (allowed, active, _) = await (
      recorder.hasPermission(),
      ref.read(activeModelsProvider.future),
      ref.read(speechPlaybackProvider.notifier).stop(),
    ).wait;
    if (epoch != _sessionEpoch || !ref.mounted) return;

    if (!allowed) {
      state = state.copyWith(
        errorMessage: 'Microphone permission is required for Live Talk.',
      );
      ref.read(composerProvider.notifier).setLiveTalkActive(false);
      return;
    }

    final sttModelId = _sttModelId(active);
    final textModelId = _textModelId(active);
    if (textModelId == null) {
      state = state.copyWith(
        errorMessage: 'Assign a Text model in Active Models.',
      );
      ref.read(composerProvider.notifier).setLiveTalkActive(false);
      return;
    }

    // Activate Live Talk UI immediately so startup feels instant.
    _turnDetector.reset();
    _pcmCarry.clear();
    _utteranceBytes.clear();
    ref.read(composerProvider.notifier)
      ..setLiveTalkActive(true)
      ..setLiveTalkPhase(LiveTalkPhase.listening);
    state = const LiveTalkState(active: true, phase: LiveTalkPhase.listening);
    unawaited(WakeWordBridge.setKeepScreenOn(true));

    _usingDeviceAsr = sttModelId == null || sttModelId.trim().isEmpty;
    if (_usingDeviceAsr) {
      final ready = await ref
          .read(deviceAsrServiceProvider)
          .ensureInitialized();
      if (epoch != _sessionEpoch || !ref.mounted) return;
      if (!ready) {
        unawaited(WakeWordBridge.setKeepScreenOn(false));
        ref.read(composerProvider.notifier).setLiveTalkActive(false);
        state = const LiveTalkState(
          errorMessage:
              'Device speech recognition is unavailable on this device.',
        );
        return;
      }
      await _startDeviceAsrTurn(epoch);
      return;
    }

    // Start immediately with energy VAD and upgrade to Silero in the background
    // so model loading or downloading never blocks Live Talk startup.
    _vad = SileroVadSession.energyFallback();
    unawaited(
      SileroVadSession.create().then((silero) {
        if (epoch != _sessionEpoch || !ref.mounted || !state.active) {
          silero.dispose();
          return;
        }
        if (silero.usesSilero) {
          final previous = _vad;
          _vad = silero;
          previous?.dispose();
        } else {
          silero.dispose();
        }
      }),
    );

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
      final smoothedLevel =
          (attack
                  ? state.audioLevel * 0.25 + vadResult.level * 0.75
                  : state.audioLevel * 0.65 + vadResult.level * 0.35)
              .clamp(0.0, 1.0);
      if ((smoothedLevel - state.audioLevel).abs() > 0.008) {
        state = state.copyWith(audioLevel: smoothedLevel);
      }

      final assistantActive =
          state.phase == LiveTalkPhase.speaking ||
          state.phase == LiveTalkPhase.thinking ||
          state.phase == LiveTalkPhase.processing;
      var probability = vadResult.probability;
      if (assistantActive) {
        _bargeInStreak = probability >= _bargeInSpeechProbability
            ? _bargeInStreak + 1
            : 0;
        if (_bargeInStreak < _bargeInConfirmFrames) probability = 0;
      } else {
        _bargeInStreak = 0;
      }

      final signal = _turnDetector.accept(probability);
      if (signal == TurnSignal.speechStart) {
        if (assistantActive) {
          unawaited(_interruptAssistant());
        }
        _utteranceBytes.clear();
        _utteranceBytes.addAll(frameBytes);
        _setPhase(LiveTalkPhase.userSpeaking);
      } else if (_turnDetector.inSpeech) {
        _utteranceBytes.addAll(frameBytes);
        if (_utteranceBytes.length >
            SileroVadSession.sampleRate * 2 * _maxUtteranceSeconds) {
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

  Future<void> _interruptAssistant() async {
    _turnEpoch++;
    _bargeInStreak = 0;
    await _stopPlayback();
    if (!ref.mounted) return;
    try {
      await ref.read(chatControllerProvider.notifier).cancelReply();
    } on Object {
      // The reply may have already completed.
    }
  }

  Future<void> _startDeviceAsrTurn(int epoch) async {
    if (epoch != _sessionEpoch || !state.active || state.phase.isPaused) {
      return;
    }
    _deviceTurnTranscript = '';
    final asr = ref.read(deviceAsrServiceProvider);
    try {
      await asr.startListening(
        pauseFor: const Duration(seconds: 2),
        onSoundLevel: (level) {
          if (epoch != _sessionEpoch || !state.active) return;
          if ((level - state.audioLevel).abs() > 0.01) {
            state = state.copyWith(audioLevel: level);
          }
        },
        onResult: (words, isFinal) {
          if (epoch != _sessionEpoch || !state.active || state.phase.isPaused) {
            return;
          }
          if (words.isNotEmpty) {
            _deviceTurnTranscript = words;
            if (state.phase == LiveTalkPhase.listening) {
              _setPhase(LiveTalkPhase.userSpeaking);
            }
          }
          if (isFinal && _deviceTurnTranscript.isNotEmpty) {
            final captured = _deviceTurnTranscript;
            _deviceTurnTranscript = '';
            unawaited(_submitDeviceAsrTurn(captured, epoch, ++_turnEpoch));
          }
        },
        onStatus: (status) {
          if (epoch != _sessionEpoch || !state.active || state.phase.isPaused) {
            return;
          }
          if (status == 'done' || status == 'notListening') {
            if (_deviceTurnTranscript.isNotEmpty &&
                (state.phase == LiveTalkPhase.listening ||
                    state.phase == LiveTalkPhase.userSpeaking)) {
              final captured = _deviceTurnTranscript;
              _deviceTurnTranscript = '';
              unawaited(_submitDeviceAsrTurn(captured, epoch, ++_turnEpoch));
            } else if (state.phase == LiveTalkPhase.listening) {
              unawaited(_startDeviceAsrTurn(epoch));
            }
          }
        },
        onError: (message) {
          if (epoch != _sessionEpoch || !state.active || state.phase.isPaused) {
            return;
          }
          if (state.phase == LiveTalkPhase.listening ||
              state.phase == LiveTalkPhase.userSpeaking) {
            _setPhase(LiveTalkPhase.listening);
            unawaited(_startDeviceAsrTurn(epoch));
          }
        },
      );
    } on Object catch (error) {
      if (epoch == _sessionEpoch && state.active) {
        state = state.copyWith(errorMessage: '$error');
      }
    }
  }

  Future<void> _submitDeviceAsrTurn(
    String transcript,
    int epoch,
    int turnEpoch,
  ) async {
    await ref.read(deviceAsrServiceProvider).stopListening();
    await _respondToTranscript(transcript, epoch, turnEpoch);
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
      if (sttModelId == null || textModelId == null) {
        if (isCurrent()) {
          _setPhase(LiveTalkPhase.listening);
          state = state.copyWith(
            errorMessage: sttModelId == null
                ? 'Assign a Speech recognition model in Active Models.'
                : 'Assign a Text model in Active Models.',
          );
        }
        return;
      }

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

      await _respondToTranscript(transcript, epoch, turnEpoch);
    } on Object catch (error) {
      if (isCurrent()) {
        _turnDetector.reset();
        _vad?.reset();
        _setPhase(LiveTalkPhase.listening);
        state = state.copyWith(errorMessage: '$error');
      }
    }
  }

  Future<void> _respondToTranscript(
    String transcript,
    int epoch,
    int turnEpoch,
  ) async {
    bool isCurrent() =>
        epoch == _sessionEpoch &&
        turnEpoch == _turnEpoch &&
        state.active &&
        !state.phase.isPaused;

    if (!isCurrent() || transcript.trim().isEmpty) {
      if (isCurrent()) {
        _setPhase(LiveTalkPhase.listening);
        if (_usingDeviceAsr) unawaited(_startDeviceAsrTurn(epoch));
      }
      return;
    }

    ProviderSubscription<AsyncValue<ChatState>>? chatSub;
    TtsPlaybackPipeline? pipeline;
    DeviceTtsSession? deviceTts;
    var chunkedOffset = 0;

    void addTtsText(String text) {
      pipeline?.addText(text);
      deviceTts?.addText(text);
    }

    try {
      final active = await ref.read(activeModelsProvider.future);
      if (!isCurrent()) return;

      state = state.copyWith(lastTranscript: transcript);
      _setPhase(LiveTalkPhase.thinking);

      final ttsModelId = _ttsModelId(active);
      final settings = await ref
          .read(ttsSettingsProvider.notifier)
          .readSettings();
      if (!isCurrent()) return;

      if (ttsModelId != null) {
        final player = _player ??= AudioPlayer(
          handleAudioSessionActivation: false,
          androidApplyAudioAttributes: false,
        );
        pipeline = TtsPlaybackPipeline(
          engine: ref.read(intelligenceEngineProvider),
          cache: ref.read(ttsAudioCacheProvider),
          modelId: ttsModelId,
          cachingEnabled: settings.caching,
          player: player,
          onFirstAudio: () {
            if (isCurrent()) _setPhase(LiveTalkPhase.speaking);
          },
        );
        _pipeline = pipeline;
      } else {
        deviceTts = DeviceTtsSession(
          driver: ref.read(deviceTtsDriverProvider),
          onFirstAudio: () {
            if (isCurrent()) _setPhase(LiveTalkPhase.speaking);
          },
        );
        _deviceTts = deviceTts;
      }

      if (settings.streaming) {
        chatSub = ref.listen(chatControllerProvider, (prev, next) {
          if (!isCurrent()) return;
          final streamed = next.value?.streamingText;
          if (streamed == null || streamed.length <= chunkedOffset) return;
          while (chunkedOffset < streamed.length) {
            final slice = streamed.substring(chunkedOffset);
            final boundary = RegExp(r'(?<=[.!?…])\s+|\n+').firstMatch(slice);
            if (boundary == null) break;
            final sentence = slice.substring(0, boundary.end).trim();
            chunkedOffset += boundary.end;
            if (sentence.isNotEmpty) addTtsText(sentence);
          }
        });
      }

      await ref.read(chatControllerProvider.notifier).send(transcript);
      chatSub?.close();
      chatSub = null;
      if (!isCurrent()) return;

      final chatMessages = ref.read(chatControllerProvider).value?.messages;
      final rawReply =
          chatMessages != null &&
              chatMessages.isNotEmpty &&
              chatMessages.last.role.name == 'assistant'
          ? chatMessages.last.text
          : '';
      final replyText = rawReply.trim();
      if (replyText.isEmpty) {
        if (isCurrent()) {
          _setPhase(LiveTalkPhase.listening);
          if (_usingDeviceAsr) unawaited(_startDeviceAsrTurn(epoch));
        }
        return;
      }

      state = state.copyWith(lastReply: replyText);

      if (settings.streaming) {
        if (chunkedOffset < rawReply.length) {
          addTtsText(rawReply.substring(chunkedOffset));
        }
      } else {
        addTtsText(replyText);
      }

      if (pipeline != null) {
        await pipeline.finish();
      } else if (deviceTts != null) {
        await deviceTts.finish();
      }
      if (!isCurrent()) return;
      final playbackError = pipeline?.firstError ?? deviceTts?.firstError;
      _turnDetector.reset();
      _vad?.reset();
      _setPhase(LiveTalkPhase.listening);
      if (playbackError != null) {
        state = state.copyWith(errorMessage: '$playbackError');
      }
      if (_usingDeviceAsr) {
        unawaited(_startDeviceAsrTurn(epoch));
      }
    } on Object catch (error) {
      await pipeline?.cancel();
      await deviceTts?.cancel();
      if (isCurrent()) {
        _turnDetector.reset();
        _vad?.reset();
        _setPhase(LiveTalkPhase.listening);
        state = state.copyWith(errorMessage: '$error');
        if (_usingDeviceAsr) {
          unawaited(_startDeviceAsrTurn(epoch));
        }
      }
    } finally {
      chatSub?.close();
      if (identical(_pipeline, pipeline)) _pipeline = null;
      if (identical(_deviceTts, deviceTts)) _deviceTts = null;
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
      if (_usingDeviceAsr) unawaited(_startDeviceAsrTurn(_sessionEpoch));
      return;
    }
    if (state.phase == LiveTalkPhase.speaking ||
        state.phase == LiveTalkPhase.thinking ||
        state.phase == LiveTalkPhase.processing) {
      await _interruptAssistant();
      _turnDetector.reset();
      _vad?.reset();
      _utteranceBytes.clear();
      _setPhase(LiveTalkPhase.listening);
      if (_usingDeviceAsr) unawaited(_startDeviceAsrTurn(_sessionEpoch));
      return;
    }
    await _interruptAssistant();
    if (_usingDeviceAsr) {
      unawaited(ref.read(deviceAsrServiceProvider).cancelListening());
    }
    _turnDetector.reset();
    _vad?.reset();
    _utteranceBytes.clear();
    _setPhase(LiveTalkPhase.paused);
  }

  Future<void> stop() async {
    final wasActive = state.active;
    final usingDeviceAsr = _usingDeviceAsr;
    _sessionEpoch++;
    _turnEpoch++;
    _bargeInStreak = 0;
    _usingDeviceAsr = false;
    _deviceTurnTranscript = '';
    await _audioSub?.cancel();
    _audioSub = null;
    if (usingDeviceAsr) {
      try {
        await ref.read(deviceAsrServiceProvider).cancelListening();
      } on Object {
        // Device ASR may already be stopped.
      }
    }
    try {
      await _recorder?.stop();
    } on Object {
      // Recorder may already be stopped.
    }
    await _stopPlayback();
    if (wasActive && ref.mounted) {
      try {
        await ref.read(chatControllerProvider.notifier).cancelReply();
      } on Object {
        // The reply may have already completed.
      }
    }
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
    final pipeline = _pipeline;
    _pipeline = null;
    await pipeline?.cancel();
    final deviceTts = _deviceTts;
    _deviceTts = null;
    await deviceTts?.cancel();
    try {
      await _player?.stop();
    } on Object {
      // Best-effort stop.
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
