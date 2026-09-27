/// Mirrors `DashboardMetrics` from `types/file.ts` on the web client.
class DashboardMetrics {
  const DashboardMetrics({
    required this.uploadedFiles,
    required this.usedStorageBytes,
    required this.sharedFiles,
    required this.uploadedPhotos,
  });

  final int uploadedFiles;
  final int usedStorageBytes;
  final int sharedFiles;
  final int uploadedPhotos;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) => DashboardMetrics(
        uploadedFiles: json['uploadedFiles'] as int,
        usedStorageBytes: (json['usedStorageBytes'] as num).toInt(),
        sharedFiles: json['sharedFiles'] as int,
        uploadedPhotos: json['uploadedPhotos'] as int,
      );
}

/// Mirrors `RecentFileItem` from `types/file.ts`.
class RecentFileItem {
  const RecentFileItem({
    required this.id,
    required this.name,
    required this.visibility,
    required this.sizeBytes,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// `PRIVATE` | `PUBLIC` | `SHARED`.
  final String visibility;
  final int sizeBytes;
  final DateTime updatedAt;

  factory RecentFileItem.fromJson(Map<String, dynamic> json) => RecentFileItem(
        id: json['id'] as String,
        name: json['name'] as String,
        visibility: json['visibility'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// Mirrors `DashboardResponse` — the payload of `GET /api/fs/dashboard`.
class DashboardResponse {
  const DashboardResponse({required this.metrics, required this.recentFiles});

  final DashboardMetrics metrics;
  final List<RecentFileItem> recentFiles;

  factory DashboardResponse.fromJson(Map<String, dynamic> json) => DashboardResponse(
        metrics: DashboardMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
        recentFiles: (json['recentFiles'] as List<dynamic>)
            .map((e) => RecentFileItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
