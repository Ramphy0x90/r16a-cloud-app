import '../../../core/util/file_types.dart';

/// Mirrors `File` from `types/file.ts` on the web client, i.e. the backend's
/// `FileResponse` (`file/dto/FileResponse.java`). Named `FileItem` to avoid
/// clashing with `dart:io`'s `File`.
class FileItem {
  const FileItem({
    required this.id,
    required this.name,
    required this.description,
    required this.fsPath,
    required this.isDirectory,
    required this.visibility,
    required this.parentId,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.sharedWithIds,
    required this.createdAt,
    required this.updatedAt,
    required this.takenAt,
    required this.blurHash,
  });

  final String id;
  final String name;
  final String? description;
  final String fsPath;
  final bool isDirectory;

  /// `PRIVATE` | `PUBLIC` | `SHARED`.
  final String visibility;
  final String? parentId;
  final String ownerId;
  final String ownerDisplayName;
  final List<String> sharedWithIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? takenAt;
  final String? blurHash;

  /// Same rule as the web `grid-view` / `list-view` shared badge.
  bool get isShared => visibility == 'SHARED' || sharedWithIds.isNotEmpty;

  bool get isImage => !isDirectory && isImageFileName(name);

  bool get isVideo => !isDirectory && isVideoFileName(name);

  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    fsPath: json['fsPath'] as String,
    isDirectory: json['isDirectory'] as bool,
    visibility: json['visibility'] as String,
    parentId: json['parentId'] as String?,
    ownerId: json['ownerId'] as String,
    ownerDisplayName: json['ownerDisplayName'] as String,
    sharedWithIds: (json['sharedWithIds'] as List<dynamic>? ?? const [])
        .cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    takenAt: json['takenAt'] == null
        ? null
        : DateTime.parse(json['takenAt'] as String),
    blurHash: json['blurHash'] as String?,
  );
}
