import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsSettings {
  const TtsSettings({this.streaming = false, this.caching = false});

  final bool streaming;
  final bool caching;

  TtsSettings copyWith({bool? streaming, bool? caching}) {
    return TtsSettings(
      streaming: streaming ?? this.streaming,
      caching: caching ?? this.caching,
    );
  }
}

/// User-controlled TTS behaviour. Both options are off by default because
/// sentence streaming multiplies provider requests and costs.
class TtsSettingsNotifier extends Notifier<TtsSettings> {
  static const streamingKey = 'kritha.tts.streaming';
  static const cachingKey = 'kritha.tts.caching';

  Future<TtsSettings>? _restoreFuture;
  int _revision = 0;

  @override
  TtsSettings build() {
    _restoreFuture = _restore(_revision);
    return const TtsSettings();
  }

  Future<TtsSettings> _restore(int revision) async {
    final preferences = await SharedPreferences.getInstance();
    final restored = TtsSettings(
      streaming: preferences.getBool(streamingKey) ?? false,
      caching: preferences.getBool(cachingKey) ?? false,
    );
    if (ref.mounted && revision == _revision) state = restored;
    return restored;
  }

  Future<TtsSettings> readSettings() async {
    final pending = _restoreFuture;
    if (pending != null) {
      await pending;
    } else {
      await _restore(_revision);
    }
    return state;
  }

  Future<void> setStreaming(bool enabled) async {
    _revision++;
    state = state.copyWith(streaming: enabled);
    _restoreFuture = Future.value(state);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(streamingKey, enabled);
  }

  Future<void> setCaching(bool enabled) async {
    _revision++;
    state = state.copyWith(caching: enabled);
    _restoreFuture = Future.value(state);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(cachingKey, enabled);
  }
}

final ttsSettingsProvider = NotifierProvider<TtsSettingsNotifier, TtsSettings>(
  TtsSettingsNotifier.new,
);
