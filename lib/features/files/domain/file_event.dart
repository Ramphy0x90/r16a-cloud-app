/// Mirrors `FileEventDto` (`types/file.ts`) — one entry of `GET /api/fs/events`.
class FileEvent {
  const FileEvent({
    required this.fileId,
    required this.parentId,
    required this.fileName,
    required this.eventType,
    required this.occurredAt,
  });

  final String fileId;
  final String? parentId;
  final String fileName;

  /// `CREATED` | `UPDATED` | `DELETED`.
  final String eventType;

  /// Epoch milliseconds.
  final int occurredAt;

  factory FileEvent.fromJson(Map<String, dynamic> json) => FileEvent(
    fileId: json['fileId'] as String,
    parentId: json['parentId'] as String?,
    fileName: json['fileName'] as String,
    eventType: json['eventType'] as String,
    occurredAt: (json['occurredAt'] as num).toInt(),
  );
}

/// Mirrors `FileEventsResponse` (`types/file.ts`). [nextCursor] is the
/// epoch-ms `since` value for the next poll.
class FileEventsPage {
  const FileEventsPage({
    required this.events,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<FileEvent> events;
  final int nextCursor;
  final bool hasMore;

  factory FileEventsPage.fromJson(Map<String, dynamic> json) => FileEventsPage(
    events: (json['events'] as List<dynamic>)
        .map((e) => FileEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextCursor: (json['nextCursor'] as num).toInt(),
    hasMore: json['hasMore'] as bool,
  );
}
