import 'package:cloud_firestore/cloud_firestore.dart';

enum PatientMediaKind {
  photo('Fotoğraf'),
  video('Video'),
  audio('Ses');

  const PatientMediaKind(this.label);
  final String label;

  static PatientMediaKind fromName(String? name) {
    return PatientMediaKind.values.firstWhere(
      (item) => item.name == name,
      orElse: () => PatientMediaKind.photo,
    );
  }

  static PatientMediaKind fromContentType(String contentType, String fileName) {
    final mime = contentType.toLowerCase();
    final name = fileName.toLowerCase();
    if (mime.startsWith('video/') || _endsWithAny(name, const ['.mp4', '.mov', '.mkv', '.webm', '.3gp'])) {
      return PatientMediaKind.video;
    }
    if (mime.startsWith('audio/') ||
        _endsWithAny(name, const ['.mp3', '.m4a', '.aac', '.wav', '.ogg', '.opus', '.flac'])) {
      return PatientMediaKind.audio;
    }
    return PatientMediaKind.photo;
  }
}

bool _endsWithAny(String value, List<String> suffixes) {
  for (final suffix in suffixes) {
    if (value.endsWith(suffix)) return true;
  }
  return false;
}

String guessMediaContentType(String path, String? mime) {
  final given = mime?.trim().toLowerCase() ?? '';
  if (given.isNotEmpty && given != 'application/octet-stream') return given;
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.3gp')) return 'video/3gpp';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  if (lower.endsWith('.opus')) return 'audio/opus';
  if (lower.endsWith('.flac')) return 'audio/flac';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return given.isEmpty ? 'application/octet-stream' : given;
}

class PatientMedia {
  const PatientMedia({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.storagePath,
    required this.url,
    required this.contentType,
    required this.createdAt,
    this.displayName,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.sessionId,
    this.sessionTitle,
    this.sessionStartsAt,
  });

  final String id;
  final PatientMediaKind kind;
  final String fileName;
  final String storagePath;
  final String url;
  final String contentType;
  final DateTime createdAt;
  final String? displayName;
  final String? thumbnailUrl;
  final String? thumbnailPath;
  final String? sessionId;
  final String? sessionTitle;
  final DateTime? sessionStartsAt;

  String get title {
    final given = displayName?.trim() ?? '';
    if (given.isNotEmpty) return given;
    return kind.label;
  }

  factory PatientMedia.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final fileName = data['fileName'] as String? ?? 'dosya';
    final contentType = data['contentType'] as String? ?? '';
    return PatientMedia(
      id: doc.id,
      kind: data['kind'] is String
          ? PatientMediaKind.fromName(data['kind'] as String)
          : PatientMediaKind.fromContentType(contentType, fileName),
      fileName: fileName,
      storagePath: data['storagePath'] as String? ?? '',
      url: data['url'] as String? ?? '',
      contentType: contentType,
      createdAt: _readDate(data['createdAt']),
      displayName: data['displayName'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      thumbnailPath: data['thumbnailPath'] as String?,
      sessionId: data['sessionId'] as String?,
      sessionTitle: data['sessionTitle'] as String?,
      sessionStartsAt: data['sessionStartsAt'] == null ? null : _readDate(data['sessionStartsAt']),
    );
  }
}

class IncomingMedia {
  const IncomingMedia({
    required this.path,
    required this.name,
    required this.mime,
  });

  final String path;
  final String name;
  final String mime;

  PatientMediaKind get kind => PatientMediaKind.fromContentType(mime, name);
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
