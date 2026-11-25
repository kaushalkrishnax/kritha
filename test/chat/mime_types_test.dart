import 'package:flutter_test/flutter_test.dart';
import 'package:kritha/core/mime_types.dart';
import 'package:kritha/models/chat_attachment.dart';

void main() {
  test('detectMimeType resolves video, audio, image, and document extensions', () {
    expect(detectMimeType(name: 'Snapchat-1965854931.mp4'), 'video/mp4');
    expect(detectMimeType(name: 'clip.mov'), 'video/mov');
    expect(detectMimeType(name: 'voice.ogg'), 'audio/ogg');
    expect(detectMimeType(name: 'song.mp3'), 'audio/mp3');
    expect(detectMimeType(name: 'photo.png'), 'image/png');
    expect(detectMimeType(name: 'doc.pdf'), 'application/pdf');
  });

  test('detectMimeType sniffs magic bytes when extension is missing', () {
    // MP4 ftyp header
    expect(
      detectMimeType(
        name: 'blob',
        headerBytes: [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D],
      ),
      'video/mp4',
    );
    // OggS header
    expect(
      detectMimeType(name: 'blob', headerBytes: [0x4F, 0x67, 0x67, 0x53, 0, 2]),
      'audio/ogg',
    );
    // PNG header
    expect(
      detectMimeType(
        name: 'blob',
        headerBytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      ),
      'image/png',
    );
  });

  test('attachmentKindForMime maps image, video, audio, and file', () {
    expect(attachmentKindForMime('video/mp4'), ChatAttachmentKind.video);
    expect(attachmentKindForMime('audio/ogg'), ChatAttachmentKind.audio);
    expect(attachmentKindForMime('image/jpeg'), ChatAttachmentKind.image);
    expect(attachmentKindForMime('application/pdf'), ChatAttachmentKind.file);
  });

  test('ChatAttachment round-trips video and audio kinds', () {
    const video = ChatAttachment(
      id: '1',
      name: 'clip.mp4',
      path: '/tmp/clip.mp4',
      sizeBytes: 1024,
      kind: ChatAttachmentKind.video,
      mimeType: 'video/mp4',
    );
    final restored = ChatAttachment.fromJson(video.toJson());
    expect(restored.kind, ChatAttachmentKind.video);
    expect(restored.isVideo, isTrue);
    expect(restored.mimeType, 'video/mp4');
  });
}
