import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kritha/features/intelligence/intelligence_engine.dart';
import 'package:kritha/features/intelligence/providers/provider.dart';
import 'package:kritha/features/intelligence/providers/provider_registry.dart';
import 'package:kritha/features/models/model_record_store.dart';
import 'package:kritha/services/tts_audio_cache.dart';
import 'package:kritha/services/tts_playback_pipeline.dart';

class _DummyModelRepository implements ModelRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTtsAudioCache extends TtsAudioCache {
  _FakeTtsAudioCache(this.onSynthesize);

  final Future<SynthesizedSpeech> Function(String text) onSynthesize;
  final List<String> synthesizedTexts = [];

  @override
  Future<SynthesizedSpeech> synthesize({
    required IntelligenceEngine engine,
    required String modelId,
    required String text,
    required bool enabled,
  }) {
    synthesizedTexts.add(text);
    return onSynthesize(text);
  }
}

class _FakeTtsAudioPlayer implements TtsAudioPlayer {
  final StreamController<int?> _indexController = StreamController.broadcast();
  final StreamController<ProcessingState> _stateController =
      StreamController.broadcast();

  final List<String> playlist = [];
  final List<String> events = [];
  int? _currentIndex;
  ProcessingState _processingState = ProcessingState.idle;
  bool _playing = false;
  int _playCalls = 0;

  @override
  Stream<int?> get currentIndexStream => _indexController.stream;

  @override
  Stream<ProcessingState> get processingStateStream => _stateController.stream;

  @override
  int? get currentIndex => _currentIndex;

  @override
  ProcessingState get processingState => _processingState;

  @override
  bool get playing => _playing;

  int get playCalls => _playCalls;

  @override
  Future<void> setAudioFiles(List<String> paths) async {
    playlist
      ..clear()
      ..addAll(paths);
    _currentIndex = 0;
    _processingState = ProcessingState.ready;
    events.add('setAudioFiles:${paths.length}');
    _indexController.add(_currentIndex);
    _stateController.add(_processingState);
  }

  @override
  Future<void> addAudioFile(String path) async {
    playlist.add(path);
    events.add('addAudioFile:${playlist.length - 1}');
  }

  @override
  Future<void> seekToIndex(int index) async {
    _currentIndex = index;
    _processingState = ProcessingState.ready;
    events.add('seek:$index');
    _indexController.add(index);
    _stateController.add(_processingState);
  }

  @override
  Future<void> play() async {
    _playCalls++;
    _playing = true;
    events.add('play:${_currentIndex ?? -1}');
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _processingState = ProcessingState.idle;
    events.add('stop');
    _stateController.add(_processingState);
  }

  void advanceToIndex(int index) {
    _currentIndex = index;
    _processingState = ProcessingState.ready;
    events.add('advance:$index');
    _indexController.add(index);
    _stateController.add(_processingState);
  }

  void completeCurrent() {
    _processingState = ProcessingState.completed;
    events.add('completed:${_currentIndex ?? -1}');
    _stateController.add(_processingState);
  }

  Future<void> dispose() async {
    await _indexController.close();
    await _stateController.close();
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late IntelligenceEngine dummyEngine;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('kritha_tts_pipeline_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return tempDir.path;
          }
          return null;
        });

    dummyEngine = IntelligenceEngine(
      modelRepository: _DummyModelRepository(),
      registry: ProviderRegistry(),
      documentsPath: Future.value(tempDir.path),
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'plays chunks consecutively in a live playlist without dropping active audio',
    () async {
      final player = _FakeTtsAudioPlayer();
      final cache = _FakeTtsAudioCache((text) async {
        return SynthesizedSpeech(
          bytes: Uint8List.fromList(text.codeUnits),
          mimeType: 'audio/mp3',
        );
      });

      var firstAudioCount = 0;
      var completedCount = 0;
      final pipeline = TtsPlaybackPipeline(
        engine: dummyEngine,
        cache: cache,
        modelId: 'tts-model',
        cachingEnabled: false,
        queuePlayer: player,
        onFirstAudio: () => firstAudioCount++,
        onCompleted: () => completedCount++,
      );

      pipeline.addText('First sentence.');
      pipeline.addText('Second sentence.');
      pipeline.addText('Third sentence.');
      final done = pipeline.finish();

      // Wait for chunk 0 and chunk 1 (1 lookahead) to be queued.
      await _waitUntil(() => player.playlist.length == 2);

      expect(player.playlist.length, 2);
      expect(player.playCalls, 1);
      expect(firstAudioCount, 1);
      expect(completedCount, 0);
      // Chunk 0 and chunk 1 files must still exist on disk while chunk 0 plays.
      expect(File(player.playlist[0]).existsSync(), isTrue);
      expect(File(player.playlist[1]).existsSync(), isTrue);

      // Player transitions gaplessly from chunk 0 to chunk 1.
      player.advanceToIndex(1);
      await _waitUntil(() => player.playlist.length == 3);

      // Chunk 0 file is now deleted; chunk 2 is now synthesized and appended.
      expect(File(player.playlist[0]).existsSync(), isFalse);
      expect(player.playlist.length, 3);
      expect(File(player.playlist[1]).existsSync(), isTrue);
      expect(File(player.playlist[2]).existsSync(), isTrue);
      expect(completedCount, 0);

      // Player transitions to chunk 2 and completes.
      player.advanceToIndex(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      player.completeCurrent();
      await done;

      expect(completedCount, 1);
      expect(File(player.playlist[1]).existsSync(), isFalse);
      expect(File(player.playlist[2]).existsSync(), isFalse);
      await player.dispose();
    },
  );

  test(
    'resumes cleanly when previous chunk completes before next chunk finishes synthesis',
    () async {
      final player = _FakeTtsAudioPlayer();
      final secondGate = Completer<void>();
      final cache = _FakeTtsAudioCache((text) async {
        if (text == 'Second.') {
          await secondGate.future;
        }
        return SynthesizedSpeech(
          bytes: Uint8List.fromList(text.codeUnits),
          mimeType: 'audio/wav',
        );
      });

      final pipeline = TtsPlaybackPipeline(
        engine: dummyEngine,
        cache: cache,
        modelId: 'tts-model',
        cachingEnabled: false,
        queuePlayer: player,
      );

      pipeline.addText('First.');
      pipeline.addText('Second.');
      final done = pipeline.finish();

      await _waitUntil(() => player.playlist.isNotEmpty);
      expect(player.playlist.length, 1);

      // Chunk 0 completes before chunk 1 is ready.
      player.completeCurrent();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Now chunk 1 finishes synthesis: pipeline should append, seek to 1, and play.
      secondGate.complete();
      await _waitUntil(() => player.playlist.length == 2);
      // Let the pipeline finish seekToIndex + play after addAudioFile.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await _waitUntil(() => player.events.contains('seek:1'));

      expect(player.playlist.length, 2);
      expect(player.events, containsAllInOrder(['seek:1', 'play:1']));

      player.completeCurrent();
      await done;
      await player.dispose();
    },
  );

  test('cancel stops playback and cleans up temporary files', () async {
    final player = _FakeTtsAudioPlayer();
    final cache = _FakeTtsAudioCache((text) async {
      return SynthesizedSpeech(
        bytes: Uint8List.fromList(text.codeUnits),
        mimeType: 'audio/mp3',
      );
    });

    final pipeline = TtsPlaybackPipeline(
      engine: dummyEngine,
      cache: cache,
      modelId: 'tts-model',
      cachingEnabled: false,
      queuePlayer: player,
    );

    pipeline.addText('Hello.');
    pipeline.addText('World.');
    await _waitUntil(() => player.playlist.length == 2);

    final paths = List<String>.from(player.playlist);
    expect(paths.length, 2);

    await pipeline.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(player.events, contains('stop'));
    for (final path in paths) {
      expect(File(path).existsSync(), isFalse);
    }
    await player.dispose();
  });
}
