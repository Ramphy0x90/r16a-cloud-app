import 'file_item.dart';

/// Mirrors `CursorPageResponse<File>` (`types/file.ts`) — the `GET /api/fs`
/// listing page.
class FileCursorPage {
  const FileCursorPage({
    required this.content,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<FileItem> content;
  final String? nextCursor;
  final bool hasMore;

  factory FileCursorPage.fromJson(Map<String, dynamic> json) => FileCursorPage(
    content: parseFileList(json['content']),
    nextCursor: json['nextCursor'] as String?,
    hasMore: json['hasMore'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'content': [for (final f in content) f.toJson()],
    'nextCursor': nextCursor,
    'hasMore': hasMore,
  };
}

/// Reads the `content` array of any listing payload — cursor pages and
/// Spring `Page`s (`/fs/shared-with-me`) alike. Like the web client, only
/// `content` is read from a Spring `Page`.
List<FileItem> parseFileList(Object? content) => (content as List<dynamic>)
    .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
    .toList();
