import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../intelligence_exception.dart';

String stripTrailingSlashes(String value) =>
    value.trim().replaceFirst(RegExp(r'/+$'), '');

Uri remoteUri(String baseUrl, String path, {Map<String, String>? query}) {
  final base = stripTrailingSlashes(baseUrl);
  final uri = Uri.parse('$base$path');
  return query == null || query.isEmpty
      ? uri
      : uri.replace(queryParameters: {...uri.queryParameters, ...query});
}

/// One discovery endpoint optionally labelled with a discovery catalogue.
class DiscoveryEndpoint {
  const DiscoveryEndpoint(this.url, {this.catalogue = 'models'});
  final String url;
  final String catalogue;
}

/// Decodes server-sent events carrying JSON objects per data line.
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

/// POST a JSON body and return the decoded response map.
Future<Map<String, dynamic>> postJson(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  required Map<String, dynamic> body,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final response = await client
      .post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      )
      .timeout(timeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw remoteStatusFailure('remote', response.statusCode);
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) {
    throw InferenceFailedException(
      'The provider returned an unexpected response.',
      providerId: 'remote',
    );
  }
  return {for (final entry in decoded.entries) '${entry.key}': entry.value};
}

/// Streams a chat-completions request, yielding decoded SSE JSON events.
Stream<Map<String, dynamic>> streamJson(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  required Map<String, dynamic> body,
  Duration timeout = const Duration(seconds: 60),
}) async* {
  final request = http.Request('POST', uri)
    ..headers.addAll(headers)
    ..body = jsonEncode(body);
  final response = await client.send(request).timeout(timeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw remoteStatusFailure('remote', response.statusCode);
  }
  await for (final event in decodeSseJson(response.stream)) {
    yield event;
  }
}

/// Authentication headers for a remote provider call.
Map<String, String> remoteAuthHeaders(String? apiKey,
    {String accept = 'application/json', bool stream = false}) {
  final headers = <String, String>{
    'accept': stream ? 'text/event-stream' : 'application/json',
    'content-type': 'application/json',
  };
  final key = apiKey?.trim();
  if (key != null && key.isNotEmpty) {
    headers['authorization'] = 'Bearer $key';
  }
  return headers;
}

/// Anthropic-specific headers.
Map<String, String> anthropicHeaders(String? apiKey,
    {bool stream = false}) {
  return {
    ...remoteAuthHeaders(apiKey, stream: stream),
    'anthropic-version': '2023-06-01',
  };
}
