import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../data/app_database.dart';
import '../features/chat/chat_controller.dart';
import '../features/intelligence/models/ai_request.dart';
import '../features/intelligence/models/task_registry.dart';
import '../features/models/active/active_models.dart';
import '../features/models/token/hugging_face_token_store.dart';
import '../features/providers/provider_stores.dart';
import '../features/providers/providers_controller.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/model_record.dart';
import 'personalization_settings.dart';
import 'tts_settings.dart';
import 'wake_word_controller.dart';

enum BackupCategory {
  providers(
    'Provider Configurations',
    'API keys, endpoints, usage stats, and custom providers.',
  ),
  activeModels(
    'Active Models & Model Records',
    'Selected task models, recents, and model metadata.',
  ),
  chatHistory(
    'Chat History',
    'Active conversations and messages.',
  ),
  archivedChats(
    'Archived Chats',
    'Archived conversations and messages.',
  ),
  settings(
    'Settings & Personalization',
    'Theme, Voice, TTS, Personal Details, and AI Instructions.',
  ),
  media(
    'Media & Attachments (ZIP)',
    'Bundle chat images, audio, video, and files with SHA-256 check.',
  );

  const BackupCategory(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

enum ConflictResolution { keepExisting, replaceExisting }

class BackupConflicts {
  const BackupConflicts({
    this.conflictingSessions = 0,
    this.conflictingProviders = 0,
    this.activeModelsConflict = false,
    this.settingsConflict = false,
  });

  final int conflictingSessions;
  final int conflictingProviders;
  final bool activeModelsConflict;
  final bool settingsConflict;

  bool get hasAny =>
      conflictingSessions > 0 ||
      conflictingProviders > 0 ||
      activeModelsConflict ||
      settingsConflict;

  List<String> describe() {
    final items = <String>[];
    if (conflictingSessions > 0) {
      items.add(
        '$conflictingSessions existing chat '
        '${conflictingSessions == 1 ? 'session' : 'sessions'}',
      );
    }
    if (conflictingProviders > 0) {
      items.add(
        '$conflictingProviders configured '
        '${conflictingProviders == 1 ? 'provider' : 'providers'}',
      );
    }
    if (activeModelsConflict) {
      items.add('Active model assignments');
    }
    if (settingsConflict) {
      items.add('Settings & personalization');
    }
    return items;
  }
}

class BackupExportResult {
  const BackupExportResult({
    required this.file,
    required this.isZip,
    required this.mediaCount,
  });

  final File file;
  final bool isZip;
  final int mediaCount;
}

class ParsedBackup {
  const ParsedBackup({
    required this.data,
    required this.isZip,
    required this.mediaFiles,
    required this.checksumMismatch,
    required this.checksumMessage,
    required this.conflicts,
    required this.sessionCount,
    required this.messageCount,
    required this.mediaCount,
  });

  final Map<String, dynamic> data;
  final bool isZip;
  final Map<String, List<int>> mediaFiles;
  final bool checksumMismatch;
  final String? checksumMessage;
  final BackupConflicts conflicts;
  final int sessionCount;
  final int messageCount;
  final int mediaCount;
}

class BackupService {
  BackupService(this._ref);

  final Ref _ref;
  static const int formatVersion = 1;
  static const String _manifestFileName = 'kritha_backup.json';

  Future<BackupExportResult> exportBackup(
    Set<BackupCategory> categories, {
    Directory? outputDir,
  }) async {
    final db = _ref.read(databaseProvider);
    final payload = <String, dynamic>{
      'version': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'categories': [for (final c in categories) c.name],
    };

    if (categories.contains(BackupCategory.providers)) {
      payload['providers'] = await _exportProviders(db);
    }
    if (categories.contains(BackupCategory.activeModels)) {
      payload['activeModels'] = await _exportActiveModels(db);
    }

    final exportedMessages = <ChatMessage>[];
    if (categories.contains(BackupCategory.chatHistory)) {
      final active = await _exportSessions(db, archived: false);
      payload['chatHistory'] = active.json;
      exportedMessages.addAll(active.messages);
    }
    if (categories.contains(BackupCategory.archivedChats)) {
      final archived = await _exportSessions(db, archived: true);
      payload['archivedChats'] = archived.json;
      exportedMessages.addAll(archived.messages);
    }
    if (categories.contains(BackupCategory.settings)) {
      payload['settings'] = await _exportSettings();
    }

    final dir = outputDir ?? await getTemporaryDirectory();
    final stamp = _timestamp();
    final includeMedia = categories.contains(BackupCategory.media);

    if (!includeMedia) {
      final file = File('${dir.path}/kritha_backup_$stamp.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      return BackupExportResult(file: file, isZip: false, mediaCount: 0);
    }

    final archive = Archive();
    final manifest = <Map<String, dynamic>>[];
    final seenPaths = <String>{};
    var index = 0;

    for (final msg in exportedMessages) {
      for (final att in msg.attachments) {
        final origPath = att.path.trim();
        if (origPath.isEmpty || !seenPaths.add(origPath)) continue;
        final src = File(origPath);
        if (!src.existsSync()) continue;
        final bytes = await src.readAsBytes();
        final digest = sha256.convert(bytes).toString();
        final safeName = _sanitizeFileName(att.name.isEmpty ? 'file' : att.name);
        final zipPath = 'media/${index++}_$safeName';
        archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
        manifest.add({
          'zipPath': zipPath,
          'originalPath': origPath,
          'sha256': digest,
          'sizeBytes': bytes.length,
        });
      }
    }

    payload['mediaManifest'] = manifest;
    payload['mediaBundleSha256'] = _computeBundleSha256(manifest);

    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    archive.addFile(
      ArchiveFile(_manifestFileName, jsonBytes.length, jsonBytes),
    );

    final zipBytes = ZipEncoder().encode(archive);
    final file = File('${dir.path}/kritha_backup_$stamp.zip');
    await file.writeAsBytes(zipBytes, flush: true);
    return BackupExportResult(
      file: file,
      isZip: true,
      mediaCount: manifest.length,
    );
  }

  Future<ParsedBackup> inspectBackup(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw const FormatException('Selected backup file does not exist.');
    }

    final isZip = filePath.toLowerCase().endsWith('.zip');
    late Map<String, dynamic> data;
    final mediaFiles = <String, List<int>>{};
    var checksumMismatch = false;
    String? checksumMessage;

    if (isZip) {
      final rawBytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(rawBytes);
      ArchiveFile? manifestEntry;
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        if (entry.name == _manifestFileName) {
          manifestEntry = entry;
        } else {
          mediaFiles[entry.name] = entry.content as List<int>;
        }
      }
      if (manifestEntry == null) {
        throw const FormatException(
          'ZIP archive is missing kritha_backup.json.',
        );
      }
      data = _decodeJsonMap(
        utf8.decode(manifestEntry.content as List<int>),
      );
      final verification = _verifyMediaChecksums(data, mediaFiles);
      checksumMismatch = verification.mismatch;
      checksumMessage = verification.message;
    } else {
      data = _decodeJsonMap(await file.readAsString());
    }

    if (data['version'] is! int) {
      throw const FormatException('Unrecognized Kritha backup format.');
    }

    final conflicts = await _detectConflicts(data);
    final chatList = _asList(data['chatHistory']);
    final archList = _asList(data['archivedChats']);
    var msgCount = 0;
    for (final s in [...chatList, ...archList]) {
      if (s is Map) msgCount += _asList(s['messages']).length;
    }

    return ParsedBackup(
      data: data,
      isZip: isZip,
      mediaFiles: mediaFiles,
      checksumMismatch: checksumMismatch,
      checksumMessage: checksumMessage,
      conflicts: conflicts,
      sessionCount: chatList.length + archList.length,
      messageCount: msgCount,
      mediaCount: mediaFiles.length,
    );
  }

  Future<void> applyImport(
    ParsedBackup backup, {
    required ConflictResolution resolution,
    Directory? mediaOutputDir,
  }) async {
    final db = _ref.read(databaseProvider);
    final data = backup.data;

    final pathMap = await _extractMedia(
      data,
      backup.mediaFiles,
      mediaOutputDir: mediaOutputDir,
    );

    if (data['providers'] is Map) {
      await _importProviders(
        db,
        _stringMap(data['providers'] as Map),
        replaceExisting: resolution == ConflictResolution.replaceExisting,
      );
    }

    if (data['activeModels'] is Map) {
      await _importActiveModels(
        db,
        _stringMap(data['activeModels'] as Map),
        replaceExisting: resolution == ConflictResolution.replaceExisting,
      );
    }

    if (data['chatHistory'] is List) {
      await _importSessions(
        db,
        _asList(data['chatHistory']),
        archived: false,
        pathMap: pathMap,
        replaceExisting: resolution == ConflictResolution.replaceExisting,
      );
    }

    if (data['archivedChats'] is List) {
      await _importSessions(
        db,
        _asList(data['archivedChats']),
        archived: true,
        pathMap: pathMap,
        replaceExisting: resolution == ConflictResolution.replaceExisting,
      );
    }

    if (data['settings'] is Map) {
      final shouldApply =
          resolution == ConflictResolution.replaceExisting ||
          !backup.conflicts.settingsConflict;
      if (shouldApply) {
        await _importSettings(_stringMap(data['settings'] as Map));
      }
    }

    _refreshProviders();
  }

  Future<Map<String, dynamic>> _exportProviders(AppDatabase db) async {
    final settingsStore = _ref.read(providerSettingsStoreProvider);
    final usageStore = _ref.read(providerUsageStoreProvider);
    final credStore = _ref.read(providerCredentialStoreProvider);
    final hfStore = _ref.read(huggingFaceTokenStoreProvider);

    final dbProviders = await db.allProviders();
    final settings = await settingsStore.read();
    final usage = await usageStore.read();

    final ids = <String>{
      for (final p in dbProviders) p.id,
      ...settings.keys,
    };
    final credentials = <String, String>{};
    for (final id in ids) {
      final cred = await credStore.read(id);
      if (cred != null && cred.isNotEmpty) {
        credentials[id] = cred;
      }
    }
    final hfToken = await hfStore.readToken();

    return {
      'dbProviders': [
        for (final p in dbProviders)
          {
            'id': p.id,
            'alias': p.alias,
            'baseUrl': p.baseUrl,
            'createdAt': p.createdAt.toUtc().toIso8601String(),
            'updatedAt': p.updatedAt.toUtc().toIso8601String(),
          },
      ],
      'settings': {
        for (final e in settings.entries) e.key: e.value.toJson(),
      },
      'usage': {
        for (final e in usage.entries) e.key: e.value.toJson(),
      },
      'credentials': credentials,
      if (hfToken != null && hfToken.isNotEmpty) 'huggingFaceToken': hfToken,
    };
  }

  Future<Map<String, dynamic>> _exportActiveModels(AppDatabase db) async {
    final activeStore = _ref.read(activeModelStoreProvider);
    final recentStore = _ref.read(recentModelStoreProvider);
    final active = await activeStore.read();
    final recents = await recentStore.read();
    final records = await db.allModelRecords();

    final exportedRecords = <Map<String, dynamic>>[];
    for (final r in records) {
      final settings = await db.modelSettingsFor(r.id);
      exportedRecords.add({
        'id': r.id,
        'providerId': r.providerId,
        'externalModelId': r.externalModelId,
        'displayName': r.displayName,
        'parentModelId': r.parentModelId,
        'suffix': r.suffix,
        'publisher': r.publisher,
        'metadata': r.metadata,
        'tasks': [
          for (final t in r.tasks)
            {
              'task': t.task.id,
              'confidence': t.confidence.name,
              'source': t.source.name,
              if (t.upstreamValue != null) 'upstreamValue': t.upstreamValue,
              if (t.refreshedAt != null)
                'refreshedAt': t.refreshedAt!.toUtc().toIso8601String(),
            },
        ],
        'createdAt': r.createdAt.toUtc().toIso8601String(),
        'updatedAt': r.updatedAt.toUtc().toIso8601String(),
        if (settings != null)
          'settings': {
            'id': settings.id,
            'version': settings.version,
            'options': settings.options.toJson(),
            'overrides': settings.overrides,
            'maxThinkingTokens': settings.maxThinkingTokens,
            'thinkingConfig': settings.thinkingConfig,
            'updatedAt': settings.updatedAt.toUtc().toIso8601String(),
          },
      });
    }

    return {
      'active': active.toJson(),
      'recents': [for (final r in recents) r.toJson()],
      'records': exportedRecords,
    };
  }

  Future<({List<Map<String, dynamic>> json, List<ChatMessage> messages})>
  _exportSessions(AppDatabase db, {required bool archived}) async {
    final sessions = await db.allSessions(archived: archived);
    final result = <Map<String, dynamic>>[];
    final allMessages = <ChatMessage>[];
    for (final s in sessions) {
      final msgs = await db.messagesForSession(s.id);
      allMessages.addAll(msgs);
      result.add({
        'session': {
          'id': s.id,
          'title': s.title,
          'createdAt': s.createdAt.toUtc().toIso8601String(),
          'updatedAt': s.updatedAt.toUtc().toIso8601String(),
          'pinned': s.pinned,
          'archived': s.archived,
        },
        'messages': [for (final m in msgs) m.toJson()],
      });
    }
    return (json: result, messages: allMessages);
  }

  Future<Map<String, dynamic>> _exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('kritha.theme.preference');
    final ttsStreaming = prefs.getBool(TtsSettingsNotifier.streamingKey);
    final ttsCaching = prefs.getBool(TtsSettingsNotifier.cachingKey);
    final wakeWordMode = prefs.getString(WakeWordSettingsNotifier.preferenceKey);
    final wakeWordEnabled = prefs.getBool('kritha.wake_word.enabled');
    final personalization = await _ref
        .read(personalizationProvider.notifier)
        .readSettings();

    return {
      'theme': ?theme,
      'ttsStreaming': ?ttsStreaming,
      'ttsCaching': ?ttsCaching,
      'wakeWordMode': ?wakeWordMode,
      'wakeWordEnabled': ?wakeWordEnabled,
      'personalization': {
        'systemPrompt': personalization.systemPrompt,
        'userName': personalization.userName,
        'interests': personalization.interests,
        'extras': personalization.extras,
      },
    };
  }

  Future<BackupConflicts> _detectConflicts(Map<String, dynamic> data) async {
    final db = _ref.read(databaseProvider);

    final activeSessions = await db.allSessions(archived: false);
    final archivedSessions = await db.allSessions(archived: true);
    final existingSessionIds = {
      for (final s in activeSessions) s.id,
      for (final s in archivedSessions) s.id,
    };

    var sessionConflicts = 0;
    for (final entry in [
      ..._asList(data['chatHistory']),
      ..._asList(data['archivedChats']),
    ]) {
      if (entry is Map && entry['session'] is Map) {
        final id = entry['session']['id'];
        if (id is String && existingSessionIds.contains(id)) {
          sessionConflicts++;
        }
      }
    }

    var providerConflicts = 0;
    if (data['providers'] is Map) {
      final pData = _stringMap(data['providers'] as Map);
      final localSettings = await _ref.read(providerSettingsStoreProvider).read();
      final importedSettings = pData['settings'] is Map
          ? _stringMap(pData['settings'] as Map)
          : const <String, dynamic>{};
      for (final id in importedSettings.keys) {
        if (localSettings.containsKey(id)) providerConflicts++;
      }
    }

    var activeModelsConflict = false;
    if (data['activeModels'] is Map) {
      final localActive = await _ref.read(activeModelStoreProvider).read();
      activeModelsConflict = !localActive.isEmpty;
    }

    var settingsConflict = false;
    if (data['settings'] is Map) {
      final prefs = await SharedPreferences.getInstance();
      final p = await _ref.read(personalizationProvider.notifier).readSettings();
      settingsConflict =
          prefs.containsKey('kritha.theme.preference') ||
          prefs.containsKey(TtsSettingsNotifier.streamingKey) ||
          prefs.containsKey(TtsSettingsNotifier.cachingKey) ||
          !p.isDefaultPrompt ||
          p.hasPersonalDetails;
    }

    return BackupConflicts(
      conflictingSessions: sessionConflicts,
      conflictingProviders: providerConflicts,
      activeModelsConflict: activeModelsConflict,
      settingsConflict: settingsConflict,
    );
  }

  Future<Map<String, String>> _extractMedia(
    Map<String, dynamic> data,
    Map<String, List<int>> mediaFiles, {
    Directory? mediaOutputDir,
  }) async {
    final manifest = _asList(data['mediaManifest']);
    if (manifest.isEmpty || mediaFiles.isEmpty) return const {};

    final baseDir = mediaOutputDir ?? await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${baseDir.path}/kritha_media');
    await mediaDir.create(recursive: true);

    final pathMap = <String, String>{};
    for (final item in manifest) {
      if (item is! Map) continue;
      final zipPath = item['zipPath'];
      final origPath = item['originalPath'];
      if (zipPath is! String || origPath is! String) continue;
      final bytes = mediaFiles[zipPath];
      if (bytes == null) continue;
      final fileName = _sanitizeFileName(zipPath.split('/').last);
      final dest = File('${mediaDir.path}/$fileName');
      await dest.writeAsBytes(bytes, flush: true);
      pathMap[origPath] = dest.path;
    }
    return pathMap;
  }

  Future<void> _importProviders(
    AppDatabase db,
    Map<String, dynamic> pData, {
    required bool replaceExisting,
  }) async {
    for (final raw in _asList(pData['dbProviders'])) {
      if (raw is! Map) continue;
      final id = raw['id'] as String?;
      final alias = raw['alias'] as String?;
      if (id == null || alias == null) continue;
      final existing = await db.providerById(id);
      if (existing != null && !replaceExisting) continue;
      await db.saveProvider(
        ProviderRow(
          id: id,
          alias: alias,
          baseUrl: raw['baseUrl'] as String?,
          apiKey: null,
          createdAt: _parseDate(raw['createdAt']),
          updatedAt: _parseDate(raw['updatedAt']),
        ),
      );
    }

    final settingsStore = _ref.read(providerSettingsStoreProvider);
    final currentSettings = Map<String, StoredProviderSettings>.from(
      await settingsStore.read(),
    );
    if (pData['settings'] is Map) {
      for (final entry in _stringMap(pData['settings'] as Map).entries) {
        if (entry.value is! Map) continue;
        if (currentSettings.containsKey(entry.key) && !replaceExisting) continue;
        final v = _stringMap(entry.value as Map);
        currentSettings[entry.key] = StoredProviderSettings(
          baseUrl: v['baseUrl'] is String ? v['baseUrl'] as String : '',
          configured: v['configured'] != false,
          alias: v['alias'] is String ? v['alias'] as String : null,
        );
      }
      await settingsStore.write(currentSettings);
    }

    final usageStore = _ref.read(providerUsageStoreProvider);
    final currentUsage = Map<String, ProviderUsage>.from(
      await usageStore.read(),
    );
    if (pData['usage'] is Map) {
      for (final entry in _stringMap(pData['usage'] as Map).entries) {
        if (entry.value is! Map) continue;
        if (currentUsage.containsKey(entry.key) && !replaceExisting) continue;
        final v = _stringMap(entry.value as Map);
        currentUsage[entry.key] = ProviderUsage(
          requests: (v['requests'] as num?)?.toInt() ?? 0,
          successes: (v['successes'] as num?)?.toInt() ?? 0,
          failures: (v['failures'] as num?)?.toInt() ?? 0,
        );
      }
      await usageStore.write(currentUsage);
    }

    final credStore = _ref.read(providerCredentialStoreProvider);
    if (pData['credentials'] is Map) {
      for (final entry in _stringMap(pData['credentials'] as Map).entries) {
        if (entry.value is! String) continue;
        final existing = await credStore.read(entry.key);
        if (existing != null && !replaceExisting) continue;
        await credStore.write(entry.key, entry.value as String);
      }
    }

    if (pData['huggingFaceToken'] is String) {
      final hfStore = _ref.read(huggingFaceTokenStoreProvider);
      final existing = await hfStore.readToken();
      if (existing == null || replaceExisting) {
        await hfStore.writeToken(pData['huggingFaceToken'] as String);
      }
    }
  }

  Future<void> _importActiveModels(
    AppDatabase db,
    Map<String, dynamic> mData, {
    required bool replaceExisting,
  }) async {
    for (final raw in _asList(mData['records'])) {
      if (raw is! Map) continue;
      final id = raw['id'] as String?;
      final providerId = raw['providerId'] as String?;
      final externalId = raw['externalModelId'] as String?;
      final displayName = raw['displayName'] as String?;
      if (id == null ||
          providerId == null ||
          externalId == null ||
          displayName == null) {
        continue;
      }
      final existing = await db.modelRecordById(id);
      if (existing != null && !replaceExisting) continue;

      final tasks = <TaskDeclaration>[];
      for (final t in _asList(raw['tasks'])) {
        if (t is Map) {
          final taskId = AiTaskId.fromId(t['task'] as String? ?? '');
          if (taskId == null) continue;
          final confidence = TaskMetadataConfidence.values.firstWhere(
            (c) => c.name == t['confidence'],
            orElse: () => TaskMetadataConfidence.values.first,
          );
          final source = TaskMetadataSource.values.firstWhere(
            (s) => s.name == t['source'],
            orElse: () => TaskMetadataSource.manual,
          );
          tasks.add(
            TaskDeclaration(
              task: taskId,
              confidence: confidence,
              source: source,
              upstreamValue: t['upstreamValue'] as String?,
              refreshedAt: t['refreshedAt'] is String
                  ? DateTime.tryParse(t['refreshedAt'] as String)
                  : null,
            ),
          );
        }
      }

      await db.saveModelRecord(
        ModelRecord(
          id: id,
          providerId: providerId,
          externalModelId: externalId,
          displayName: displayName,
          parentModelId: raw['parentModelId'] as String?,
          suffix: raw['suffix'] as String?,
          publisher: raw['publisher'] as String?,
          metadata: raw['metadata'] is Map
              ? _stringMap(raw['metadata'] as Map)
              : const {},
          tasks: tasks,
          createdAt: _parseDate(raw['createdAt']),
          updatedAt: _parseDate(raw['updatedAt']),
        ),
      );

      if (raw['settings'] is Map) {
        final s = _stringMap(raw['settings'] as Map);
        await db.saveModelInferenceSettings(
          ModelSettingsRecord(
            id: s['id'] as String? ?? 'settings-$id',
            modelId: id,
            version: (s['version'] as num?)?.toInt() ?? 1,
            options: s['options'] is Map
                ? AiGenerationOptions.fromJson(_stringMap(s['options'] as Map))
                : const AiGenerationOptions(),
            overrides: s['overrides'] is Map
                ? _stringMap(s['overrides'] as Map)
                : const {},
            maxThinkingTokens: (s['maxThinkingTokens'] as num?)?.toInt(),
            thinkingConfig: s['thinkingConfig'] is Map
                ? _stringMap(s['thinkingConfig'] as Map)
                : const {},
            updatedAt: _parseDate(s['updatedAt']),
          ),
        );
      }
    }

    if (mData['active'] is Map) {
      final activeStore = _ref.read(activeModelStoreProvider);
      final current = await activeStore.read();
      if (current.isEmpty || replaceExisting) {
        await activeStore.write(
          ActiveModelConfig.fromJson(_stringMap(mData['active'] as Map)),
        );
      }
    }

    if (mData['recents'] is List) {
      final recentStore = _ref.read(recentModelStoreProvider);
      final current = await recentStore.read();
      final imported = <RecentModelRef>[];
      for (final item in _asList(mData['recents'])) {
        if (item is Map) {
          try {
            imported.add(RecentModelRef.fromJson(_stringMap(item)));
          } on Object {
            // Skip malformed recent entry.
          }
        }
      }
      if (replaceExisting) {
        await recentStore.write(imported);
      } else {
        final seen = {for (final r in current) r.modelId};
        final merged = [
          ...current,
          for (final r in imported)
            if (seen.add(r.modelId)) r,
        ];
        await recentStore.write(merged);
      }
    }
  }

  Future<void> _importSessions(
    AppDatabase db,
    List<dynamic> items, {
    required bool archived,
    required Map<String, String> pathMap,
    required bool replaceExisting,
  }) async {
    for (final item in items) {
      if (item is! Map || item['session'] is! Map) continue;
      final sMap = _stringMap(item['session'] as Map);
      final sId = sMap['id'] as String?;
      if (sId == null || sId.isEmpty) continue;
      final session = ChatSession(
        id: sId,
        title: sMap['title'] as String? ?? 'Imported Chat',
        createdAt: _parseDate(sMap['createdAt']),
        updatedAt: _parseDate(sMap['updatedAt']),
        pinned: sMap['pinned'] == true,
        archived: archived,
      );
      final existing = await db.sessionById(session.id);
      if (existing != null && !replaceExisting) continue;
      if (existing != null && replaceExisting) {
        await db.deleteSession(session.id);
      }
      await db.saveSession(session);
      for (final rawMsg in _asList(item['messages'])) {
        if (rawMsg is! Map) continue;
        final msg = ChatMessage.fromJson(_stringMap(rawMsg));
        final rewritten = msg.attachments.isEmpty || pathMap.isEmpty
            ? msg
            : msg.copyWith(
                attachments: [
                  for (final att in msg.attachments)
                    ChatAttachment(
                      id: att.id,
                      name: att.name,
                      path: pathMap[att.path] ?? att.path,
                      sizeBytes: att.sizeBytes,
                      kind: att.kind,
                      mimeType: att.mimeType,
                    ),
                ],
              );
        await db.saveMessage(rewritten, sessionId: session.id);
      }
    }
  }

  Future<void> _importSettings(Map<String, dynamic> sData) async {
    final prefs = await SharedPreferences.getInstance();
    if (sData['theme'] is String) {
      final rawTheme = sData['theme'] as String;
      final pref = KrithaThemePreference.values.firstWhere(
        (e) => e.storageValue == rawTheme,
        orElse: () => KrithaThemePreference.system,
      );
      await _ref.read(themePreferenceProvider.notifier).setPreference(pref);
    }
    if (sData['ttsStreaming'] is bool) {
      await _ref
          .read(ttsSettingsProvider.notifier)
          .setStreaming(sData['ttsStreaming'] as bool);
    }
    if (sData['ttsCaching'] is bool) {
      await _ref
          .read(ttsSettingsProvider.notifier)
          .setCaching(sData['ttsCaching'] as bool);
    }
    if (sData['wakeWordMode'] is String) {
      await _ref
          .read(wakeWordModeProvider.notifier)
          .setMode(WakeWordMode.fromName(sData['wakeWordMode'] as String));
    }
    if (sData['wakeWordEnabled'] is bool) {
      await prefs.setBool(
        'kritha.wake_word.enabled',
        sData['wakeWordEnabled'] as bool,
      );
    }
    if (sData['personalization'] is Map) {
      final p = _stringMap(sData['personalization'] as Map);
      await _ref
          .read(personalizationProvider.notifier)
          .setSystemPrompt(
            p['systemPrompt'] as String? ??
                PersonalizationSettings.defaultSystemPrompt,
          );
      await _ref
          .read(personalizationProvider.notifier)
          .setPersonalDetails(
            userName: p['userName'] as String? ?? '',
            interests: p['interests'] as String? ?? '',
            extras: p['extras'] as String? ?? '',
          );
    }
  }

  void _refreshProviders() {
    _ref.invalidate(chatControllerProvider);
    _ref.invalidate(activeModelsProvider);
    _ref.invalidate(providersControllerProvider);
  }

  static ({bool mismatch, String? message}) _verifyMediaChecksums(
    Map<String, dynamic> data,
    Map<String, List<int>> mediaFiles,
  ) {
    final manifest = _asList(data['mediaManifest']);
    if (manifest.isEmpty) {
      return (mismatch: false, message: null);
    }
    final expectedBundle = data['mediaBundleSha256'] as String?;
    final actualBundle = _computeBundleSha256(manifest);
    if (expectedBundle != null && expectedBundle != actualBundle) {
      return (
        mismatch: true,
        message: 'Media manifest checksum does not match the backup header.',
      );
    }
    for (final entry in manifest) {
      if (entry is! Map) continue;
      final zipPath = entry['zipPath'] as String?;
      final expectedSha = entry['sha256'] as String?;
      if (zipPath == null || expectedSha == null) continue;
      final bytes = mediaFiles[zipPath];
      if (bytes == null) {
        return (
          mismatch: true,
          message: 'Missing media file in archive: $zipPath',
        );
      }
      final actualSha = sha256.convert(bytes).toString();
      if (actualSha != expectedSha) {
        return (
          mismatch: true,
          message: 'SHA-256 mismatch for "$zipPath".',
        );
      }
    }
    return (mismatch: false, message: null);
  }

  static String _computeBundleSha256(List<dynamic> manifest) {
    final lines = <String>[];
    for (final item in manifest) {
      if (item is Map && item['zipPath'] != null && item['sha256'] != null) {
        lines.add('${item['zipPath']}:${item['sha256']}');
      }
    }
    lines.sort();
    return sha256.convert(utf8.encode(lines.join('\n'))).toString();
  }

  static Map<String, dynamic> _decodeJsonMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Backup root must be a JSON object.');
    }
    return _stringMap(decoded);
  }

  static Map<String, dynamic> _stringMap(Map<dynamic, dynamic> raw) => {
    for (final entry in raw.entries) '${entry.key}': entry.value,
  };

  static List<dynamic> _asList(Object? value) =>
      value is List ? value : const [];

  static DateTime _parseDate(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now().toUtc();
  }

  static String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  static String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }
}

final backupServiceProvider = Provider<BackupService>(BackupService.new);
