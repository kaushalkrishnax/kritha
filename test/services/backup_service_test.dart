import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/core/providers.dart';
import 'package:kritha/core/storage/secure_storage_service.dart';
import 'package:kritha/data/app_database.dart';
import 'package:kritha/features/providers/provider_stores.dart';
import 'package:kritha/models/chat_attachment.dart';
import 'package:kritha/models/chat_message.dart';
import 'package:kritha/models/chat_session.dart';
import 'package:kritha/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStorage implements SecureStorageService {
  final Map<String, String> data = {};

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('kritha_backup_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ProviderContainer createContainer(
    AppDatabase db,
    _MemorySecureStorage secure,
  ) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureStorageServiceProvider.overrideWithValue(secure),
      ],
    );
  }

  test('exports and imports JSON backup with conflict detection', () async {
    final db1 = AppDatabase(NativeDatabase.memory());
    final sec1 = _MemorySecureStorage();
    final c1 = createContainer(db1, sec1);
    addTearDown(() async {
      c1.dispose();
      await db1.close();
    });

    final session = ChatSession(
      id: 'sess-1',
      title: 'Test Chat',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await db1.saveSession(session);
    await db1.saveMessage(
      ChatMessage(
        id: 'msg-1',
        role: ChatRole.user,
        text: 'Hello backup',
        createdAt: DateTime.utc(2026, 1, 1, 1),
      ),
      sessionId: session.id,
    );
    await c1.read(providerCredentialStoreProvider).write('11111111-1111-1111-1111-111111111102', 'secret-key');
    await c1.read(providerSettingsStoreProvider).write({
      '11111111-1111-1111-1111-111111111102': const StoredProviderSettings(
        baseUrl: 'https://example.com',
      ),
    });

    final exported = await c1
        .read(backupServiceProvider)
        .exportBackup({
          BackupCategory.providers,
          BackupCategory.chatHistory,
          BackupCategory.settings,
        }, outputDir: tempDir);
    expect(exported.isZip, isFalse);
    expect(exported.file.existsSync(), isTrue);

    // Import into a fresh database and prefs (simulates reinstall).
    SharedPreferences.setMockInitialValues({});
    final db2 = AppDatabase(NativeDatabase.memory());
    final sec2 = _MemorySecureStorage();
    final c2 = createContainer(db2, sec2);
    addTearDown(() async {
      c2.dispose();
      await db2.close();
    });

    final parsed = await c2
        .read(backupServiceProvider)
        .inspectBackup(exported.file.path);
    expect(parsed.checksumMismatch, isFalse);
    expect(parsed.conflicts.hasAny, isFalse);
    expect(parsed.sessionCount, 1);
    expect(parsed.messageCount, 1);

    await c2
        .read(backupServiceProvider)
        .applyImport(parsed, resolution: ConflictResolution.replaceExisting);

    final restoredSessions = await db2.allSessions();
    expect(restoredSessions.map((s) => s.id), ['sess-1']);
    final restoredMsgs = await db2.messagesForSession('sess-1');
    expect(restoredMsgs.single.text, 'Hello backup');
    expect(
      await c2
          .read(providerCredentialStoreProvider)
          .read('11111111-1111-1111-1111-111111111102'),
      'secret-key',
    );

    // Re-inspecting into db2 detects conflicts.
    final reParsed = await c2
        .read(backupServiceProvider)
        .inspectBackup(exported.file.path);
    expect(reParsed.conflicts.conflictingSessions, 1);
    expect(reParsed.conflicts.conflictingProviders, 1);
  });

  test('exports ZIP with media, verifies SHA-256, and detects tampering', () async {
    final db1 = AppDatabase(NativeDatabase.memory());
    final sec1 = _MemorySecureStorage();
    final c1 = createContainer(db1, sec1);
    addTearDown(() async {
      c1.dispose();
      await db1.close();
    });

    final mediaFile = File('${tempDir.path}/photo.png');
    await mediaFile.writeAsBytes([1, 2, 3, 4, 5, 6]);

    final session = ChatSession(
      id: 'sess-media',
      title: 'Media Chat',
      createdAt: DateTime.utc(2026, 2, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
    );
    await db1.saveSession(session);
    await db1.saveMessage(
      ChatMessage(
        id: 'msg-m1',
        role: ChatRole.user,
        text: 'Check this image',
        createdAt: DateTime.utc(2026, 2, 1),
        attachments: [
          ChatAttachment(
            id: 'att-1',
            name: 'photo.png',
            path: mediaFile.path,
            sizeBytes: 6,
            kind: ChatAttachmentKind.image,
          ),
        ],
      ),
      sessionId: session.id,
    );

    final exported = await c1
        .read(backupServiceProvider)
        .exportBackup({
          BackupCategory.chatHistory,
          BackupCategory.media,
        }, outputDir: tempDir);
    expect(exported.isZip, isTrue);
    expect(exported.mediaCount, 1);

    // Delete original file to simulate reinstall, then import into fresh DB.
    await mediaFile.delete();

    final db2 = AppDatabase(NativeDatabase.memory());
    final sec2 = _MemorySecureStorage();
    final c2 = createContainer(db2, sec2);
    addTearDown(() async {
      c2.dispose();
      await db2.close();
    });

    final parsed = await c2
        .read(backupServiceProvider)
        .inspectBackup(exported.file.path);
    expect(parsed.checksumMismatch, isFalse);
    expect(parsed.mediaCount, 1);

    final restoredMediaDir = Directory('${tempDir.path}/restored_docs');
    await c2.read(backupServiceProvider).applyImport(
          parsed,
          resolution: ConflictResolution.replaceExisting,
          mediaOutputDir: restoredMediaDir,
        );

    final restoredMsgs = await db2.messagesForSession('sess-media');
    final restoredPath = restoredMsgs.single.attachments.single.path;
    expect(File(restoredPath).existsSync(), isTrue);
    expect(await File(restoredPath).readAsBytes(), [1, 2, 3, 4, 5, 6]);

    // Tamper with the media bytes inside the ZIP and verify checksum mismatch.
    final rawArchive = ZipDecoder().decodeBytes(await exported.file.readAsBytes());
    final tamperedArchive = Archive();
    for (final entry in rawArchive.files) {
      if (entry.name.startsWith('media/')) {
        tamperedArchive.addFile(ArchiveFile(entry.name, 3, [9, 9, 9]));
      } else {
        tamperedArchive.addFile(
          ArchiveFile(entry.name, entry.size, entry.content as List<int>),
        );
      }
    }
    final tamperedFile = File('${tempDir.path}/tampered.zip');
    await tamperedFile.writeAsBytes(ZipEncoder().encode(tamperedArchive));

    final tamperedParsed = await c2
        .read(backupServiceProvider)
        .inspectBackup(tamperedFile.path);
    expect(tamperedParsed.checksumMismatch, isTrue);
  });
}
