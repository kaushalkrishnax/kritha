import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../intelligence_exception.dart';
import '../../models/ai_input.dart';
import '../../models/ai_request.dart';
import '../provider.dart';

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

IntelligenceException _statusFailureWithBody(
  String providerId,
  int statusCode,
  String body,
) {
  final base = remoteStatusFailure(providerId, statusCode);
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final err = decoded['error'];
      final detail = err is Map ? err['message'] : decoded['message'];
      if (detail is String && detail.trim().isNotEmpty) {
        if (base is ProviderUnavailableException) {
          return ProviderUnavailableException(
            detail.trim(),
            providerId: providerId,
            cause: statusCode,
          );
        }
        return InferenceFailedException(
          detail.trim(),
          providerId: providerId,
          cause: statusCode,
        );
      }
    }
  } on Object {
    // Non-JSON error body; use generic status message.
  }
  return base;
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
      .post(uri, headers: headers, body: jsonEncode(body))
      .timeout(timeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _statusFailureWithBody('remote', response.statusCode, response.body);
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
    final errBody = await response.stream.bytesToString();
    throw _statusFailureWithBody('remote', response.statusCode, errBody);
  }
  await for (final event in decodeSseJson(response.stream)) {
    yield event;
  }
}

/// Authentication headers for a remote provider call.
Map<String, String> remoteAuthHeaders(
  String? apiKey, {
  String accept = 'application/json',
  bool stream = false,
}) {
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
Map<String, String> anthropicHeaders(String? apiKey, {bool stream = false}) {
  return {
    ...remoteAuthHeaders(apiKey, stream: stream),
    'anthropic-version': '2023-06-01',
  };
}

/// Builds OpenAI-compatible chat messages, encoding image inputs on the last user turn.
List<Map<String, dynamic>> openAiChatMessages(AiRequest request) {
  final system = [
    for (final message in request.messages)
      if (message.role == AiRole.system) message.text.trim(),
  ].where((text) => text.isNotEmpty).join('\n\n');
  final nonSystem = [
    for (final message in request.messages)
      if (message.role != AiRole.system) message,
  ];
  final images = [
    for (final input in request.inputs)
      if (input is AiImageInput) input,
  ];
  return [
    if (system.isNotEmpty) {'role': 'system', 'content': system},
    for (var i = 0; i < nonSystem.length; i++)
      if (i == nonSystem.length - 1 && images.isNotEmpty)
        {
          'role': nonSystem[i].role == AiRole.assistant ? 'assistant' : 'user',
          'content': [
            {'type': 'text', 'text': nonSystem[i].text},
            for (final image in images)
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
                },
              },
          ],
        }
      else
        {
          'role': nonSystem[i].role == AiRole.assistant ? 'assistant' : 'user',
          'content': nonSystem[i].text,
        },
  ];
}

/// Calls an OpenAI-compatible `/images/generations` endpoint.
Future<GeneratedImage> openAiGenerateImage(
  http.Client client, {
  required String baseUrl,
  required String? apiKey,
  required String modelId,
  required String prompt,
  required String providerAlias,
  Duration timeout = const Duration(minutes: 3),
}) async {
  // response_format is omitted on purpose: gpt-image models reject it and
  // always return b64_json; other models default to a downloadable url.
  final decoded = await postJson(
    client,
    remoteUri(stripTrailingSlashes(baseUrl), '/images/generations'),
    headers: remoteAuthHeaders(apiKey),
    body: {'model': modelId, 'prompt': prompt, 'n': 1},
    timeout: timeout,
  );
  final data = decoded['data'];
  if (data is List && data.isNotEmpty) {
    final first = data.first;
    if (first is Map) {
      final b64 = first['b64_json'];
      if (b64 is String && b64.isNotEmpty) {
        return GeneratedImage(bytes: base64Decode(b64), mimeType: 'image/png');
      }
      final url = first['url'];
      if (url is String && url.isNotEmpty) {
        final imageResponse = await client.get(Uri.parse(url));
        if (imageResponse.statusCode >= 200 && imageResponse.statusCode < 300) {
          final contentType = imageResponse.headers['content-type'];
          return GeneratedImage(
            bytes: Uint8List.fromList(imageResponse.bodyBytes),
            mimeType: contentType ?? 'image/png',
          );
        }
      }
    }
  }
  throw InferenceFailedException(
    'The provider did not return an image.',
    providerId: providerAlias,
  );
}
