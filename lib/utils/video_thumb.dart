import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

final _videoThumbBytes = <String, Uint8List>{};

Uint8List? cachedVideoThumb(String mediaId) => _videoThumbBytes[mediaId];

void rememberVideoThumb(String mediaId, Uint8List bytes) {
  if (bytes.isNotEmpty) _videoThumbBytes[mediaId] = bytes;
}

Future<Uint8List?> videoThumbnailBytes(String source) async {
  if (source.trim().isEmpty) return null;
  for (final at in const [500, 0]) {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 72,
        timeMs: at,
      );
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } catch (_) {}
  }
  return null;
}
