import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../intelligence_exception.dart';

String stripTrailingSlashes(String value) =>
    value.trim().replaceFirst(RegExp(r'/+$'), '');

Uri remoteUri(String baseUrl, String path, {Map<String, String>? query}) {
  final base = stripTrailingSlashes(baseUrl);
  final uri = Uri.parse('$base$path');
  return query == null || query.isEmpty
      ? uri
      : uri.replace(queryParameters: {...uri.queryParameters, ...query});
}

/// Decodes server-sent events carrying one JSON object per `data:` line.
///
/// Anthropic and Gemini both use this shape. Comment, event and id lines are
/// ignored, and the stream ends at `[DONE]` when a provider sends it.
Stream<Map<String, dynamic>> decodeSseJson(Stream<List<int>> bytes) async* {
  final lines = bytes
      .transform(const Utf8Decoder())
      .transform(const LineSplitter());
  final data = StringBuffer();

  Future<Map<String, dynamic>?> take() async {
    final raw = data.toString().trim();
    data.clear();
    if (raw.isEmpty || raw == '[DONE]') return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const InferenceFailedException(
        'The provider sent an unexpected streaming payload.',
        providerId: 'remote',
      );
    }
    return {for (final entry in decoded.entries) '${entry.key}': entry.value};
  }

  await for (final line in lines) {
    if (line.isEmpty) {
      final event = await take();
      if (event != null) yield event;
      continue;
    }
    if (line.startsWith('data:')) {
      final value = line.substring(5).trimLeft();
      if (data.isNotEmpty) data.write('\n');
      data.write(value);
    }
  }
  final event = await take();
  if (event != null) yield event;
}

ProviderUnavailableException remoteTransportFailure(
  String providerId,
  Object error,
) {
  if (error is IntelligenceException) {
    return ProviderUnavailableException(
      error.message,
      providerId: providerId,
      cause: error,
    );
  }
  if (error is TimeoutException || error is SocketException) {
    return ProviderUnavailableException(
      'The provider could not be reached.',
      providerId: providerId,
      cause: error,
    );
  }
  if (error is http.ClientException) {
    return ProviderUnavailableException(
      'The provider connection failed.',
      providerId: providerId,
      cause: error,
    );
  }
  return ProviderUnavailableException(
    'The provider could not be reached.',
    providerId: providerId,
    cause: error,
  );
}

IntelligenceException remoteStatusFailure(String providerId, int statusCode) {
  return switch (statusCode) {
    401 || 403 => ProviderUnavailableException(
      'The provider rejected the credential.',
      providerId: providerId,
      cause: statusCode,
    ),
    404 => ProviderUnavailableException(
      'The provider does not expose that model or endpoint.',
      providerId: providerId,
      cause: statusCode,
    ),
    408 || 429 => InferenceFailedException(
      'The provider is busy or rate-limited this request.',
      providerId: providerId,
      cause: statusCode,
    ),
    >= 500 => InferenceFailedException(
      'The provider returned a server error.',
      providerId: providerId,
      cause: statusCode,
    ),
    _ => InferenceFailedException(
      'The provider rejected the request (HTTP $statusCode).',
      providerId: providerId,
      cause: statusCode,
    ),
  };
}
