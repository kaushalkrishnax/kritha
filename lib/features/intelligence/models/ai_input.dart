import 'dart:typed_data';

sealed class AiInput {
  const AiInput();
}

final class AiTextInput extends AiInput {
  const AiTextInput(this.value);

  final String value;
}

final class AiImageInput extends AiInput {
  const AiImageInput({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

final class AiAudioInput extends AiInput {
  const AiAudioInput({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

final class AiVideoInput extends AiInput {
  const AiVideoInput({this.bytes, this.reference, this.mimeType})
    : assert(bytes != null || reference != null);

  final Uint8List? bytes;
  final String? reference;
  final String? mimeType;
}

extension AiInputCollection on Iterable<AiInput> {
  bool get hasText => any((input) => input is AiTextInput);
  bool get hasImage => any((input) => input is AiImageInput);
  bool get hasAudio => any((input) => input is AiAudioInput);
  bool get hasVideo => any((input) => input is AiVideoInput);
}
