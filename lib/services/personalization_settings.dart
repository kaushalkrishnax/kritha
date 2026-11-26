import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalizationSettings {
  const PersonalizationSettings({
    this.systemPrompt = defaultSystemPrompt,
    this.userName = '',
    this.interests = '',
    this.extras = '',
  });

  static const defaultSystemPrompt = '''
You are Kritha, an intelligent personal AI assistant.

Be helpful, accurate, concise, and natural. Understand the user's intent and context before responding. Follow instructions carefully, remember relevant conversation context, and never fabricate facts, actions, or results.

Give direct, practical answers. Ask for clarification only when genuinely necessary. Correct mistakes honestly instead of agreeing blindly. Adapt your tone to the situation and avoid unnecessary repetition, filler, or excessive explanations.''';

  final String systemPrompt;
  final String userName;
  final String interests;
  final String extras;

  bool get isDefaultPrompt => systemPrompt.trim() == defaultSystemPrompt;

  bool get hasPersonalDetails =>
      userName.trim().isNotEmpty ||
      interests.trim().isNotEmpty ||
      extras.trim().isNotEmpty;

  PersonalizationSettings copyWith({
    String? systemPrompt,
    String? userName,
    String? interests,
    String? extras,
  }) {
    return PersonalizationSettings(
      systemPrompt: systemPrompt ?? this.systemPrompt,
      userName: userName ?? this.userName,
      interests: interests ?? this.interests,
      extras: extras ?? this.extras,
    );
  }

  /// Combines the active system prompt with any optional user profile fields.
  String buildEffectiveSystemPrompt() {
    final base = systemPrompt.trim().isEmpty
        ? defaultSystemPrompt
        : systemPrompt.trim();
    final name = userName.trim();
    final topics = interests.trim();
    final notes = extras.trim();
    if (name.isEmpty && topics.isEmpty && notes.isEmpty) return base;

    final buffer = StringBuffer(base)..writeln('\n\nUser details:');
    if (name.isNotEmpty) buffer.writeln('- Name: $name');
    if (topics.isNotEmpty) buffer.writeln('- Interests: $topics');
    if (notes.isNotEmpty) buffer.writeln('- Extra context: $notes');
    return buffer.toString().trimRight();
  }
}

class PersonalizationNotifier extends Notifier<PersonalizationSettings> {
  static const systemPromptKey = 'kritha.personalize.system_prompt';
  static const userNameKey = 'kritha.personalize.user_name';
  static const interestsKey = 'kritha.personalize.interests';
  static const extrasKey = 'kritha.personalize.extras';

  Future<PersonalizationSettings>? _restoreFuture;
  int _revision = 0;

  @override
  PersonalizationSettings build() {
    _restoreFuture = _restore(_revision);
    return const PersonalizationSettings();
  }

  Future<PersonalizationSettings> _restore(int revision) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPrompt = prefs.getString(systemPromptKey)?.trim() ?? '';
    final restored = PersonalizationSettings(
      systemPrompt: savedPrompt.isEmpty
          ? PersonalizationSettings.defaultSystemPrompt
          : savedPrompt,
      userName: prefs.getString(userNameKey) ?? '',
      interests: prefs.getString(interestsKey) ?? '',
      extras: prefs.getString(extrasKey) ?? '',
    );
    if (ref.mounted && revision == _revision) state = restored;
    return restored;
  }

  Future<PersonalizationSettings> readSettings() async {
    final pending = _restoreFuture;
    if (pending != null) {
      await pending;
    } else {
      await _restore(_revision);
    }
    return state;
  }

  Future<void> setSystemPrompt(String prompt) async {
    final trimmed = prompt.trim();
    final nextPrompt = trimmed.isEmpty
        ? PersonalizationSettings.defaultSystemPrompt
        : trimmed;
    _revision++;
    state = state.copyWith(systemPrompt: nextPrompt);
    _restoreFuture = Future.value(state);
    final prefs = await SharedPreferences.getInstance();
    if (nextPrompt == PersonalizationSettings.defaultSystemPrompt) {
      await prefs.remove(systemPromptKey);
    } else {
      await prefs.setString(systemPromptKey, nextPrompt);
    }
  }

  Future<void> resetSystemPrompt() =>
      setSystemPrompt(PersonalizationSettings.defaultSystemPrompt);

  Future<void> setPersonalDetails({
    required String userName,
    required String interests,
    required String extras,
  }) async {
    final cleanName = userName.trim();
    final cleanInterests = interests.trim();
    final cleanExtras = extras.trim();
    _revision++;
    state = state.copyWith(
      userName: cleanName,
      interests: cleanInterests,
      extras: cleanExtras,
    );
    _restoreFuture = Future.value(state);
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      cleanName.isEmpty
          ? prefs.remove(userNameKey)
          : prefs.setString(userNameKey, cleanName),
      cleanInterests.isEmpty
          ? prefs.remove(interestsKey)
          : prefs.setString(interestsKey, cleanInterests),
      cleanExtras.isEmpty
          ? prefs.remove(extrasKey)
          : prefs.setString(extrasKey, cleanExtras),
    ]);
  }
}

final personalizationProvider =
    NotifierProvider<PersonalizationNotifier, PersonalizationSettings>(
      PersonalizationNotifier.new,
    );
