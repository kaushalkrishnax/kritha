import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../data/app_database.dart';

/// Result of touching each platform package once at startup.
class RuntimeStatus {
  const RuntimeStatus({
    required this.sherpaVersion,
    required this.onnxRuntimeVersion,
    required this.sqliteVersion,
    required this.secureStorageReady,
    required this.preferencesReady,
    required this.microphone,
    required this.recorderReady,
    required this.audioPlayerReady,
    required this.dioBaseUrl,
    required this.documentsPath,
  });

  final String sherpaVersion;
  final String onnxRuntimeVersion;
  final String sqliteVersion;
  final bool secureStorageReady;
  final bool preferencesReady;
  final String microphone;
  final bool recorderReady;
  final bool audioPlayerReady;
  final String dioBaseUrl;
  final String documentsPath;

  bool get sherpaReady => sherpaVersion.isNotEmpty;
}

/// Exercises every platform dependency once. Everything is best-effort: a
/// missing permission or unavailable plugin is reported in the UI instead of
/// crashing the demo.
class RuntimeProbe {
  RuntimeProbe({required this.database, required this.dio});

  final AppDatabase database;
  final Dio dio;

  Future<RuntimeStatus> run() async {
    var sherpaVersion = '';
    var onnxRuntimeVersion = '';
    try {
      await sherpa.initBindingsAsync();
      sherpaVersion = sherpa.getVersion();
      onnxRuntimeVersion = sherpa.getOnnxruntimeVersion();
    } on Object {
      // Reported as unavailable in the runtime screen.
    }

    var sqliteVersion = '';
    try {
      final db = sqlite.sqlite3.openInMemory();
      final row = db.select('select sqlite_version() as version').first;
      sqliteVersion = row['version'] as String? ?? '';
      db.close();
    } on Object {
      // sqlite3 is also exercised by Drift; this is a direct probe.
    }

    var secureStorageReady = false;
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'kritha_demo_probe', value: 'ok');
      secureStorageReady = await storage.read(key: 'kritha_demo_probe') == 'ok';
      await storage.delete(key: 'kritha_demo_probe');
    } on Object {
      secureStorageReady = false;
    }

    var preferencesReady = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'kritha_demo_last_probe',
        DateTime.now().toIso8601String(),
      );
      preferencesReady = preferences.containsKey('kritha_demo_last_probe');
    } on Object {
      preferencesReady = false;
    }

    var microphone = 'unknown';
    try {
      microphone = (await Permission.microphone.status).name;
    } on Object {
      microphone = 'unavailable';
    }

    var recorderReady = false;
    try {
      final recorder = AudioRecorder();
      recorderReady = await recorder.hasPermission(request: false);
      await recorder.dispose();
    } on Object {
      recorderReady = false;
    }

    var audioPlayerReady = false;
    try {
      final player = AudioPlayer();
      await player.setVolume(0.8);
      audioPlayerReady = true;
      await player.dispose();
    } on Object {
      audioPlayerReady = false;
    }

    var documentsPath = '';
    try {
      documentsPath = (await getApplicationDocumentsDirectory()).path;
    } on Object {
      documentsPath = '';
    }

    // Touch the database so its lazy connection opens during startup.
    try {
      await database.countMessages();
    } on Object {
      // The chat provider will surface a database error separately.
    }

    return RuntimeStatus(
      sherpaVersion: sherpaVersion,
      onnxRuntimeVersion: onnxRuntimeVersion,
      sqliteVersion: sqliteVersion,
      secureStorageReady: secureStorageReady,
      preferencesReady: preferencesReady,
      microphone: microphone,
      recorderReady: recorderReady,
      audioPlayerReady: audioPlayerReady,
      dioBaseUrl: dio.options.baseUrl,
      documentsPath: documentsPath,
    );
  }
}
