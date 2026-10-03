import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/core/session/current_user.dart';
import 'package:r16a_cloud_app/core/session/session_api.dart';
import 'package:r16a_cloud_app/core/session/user_preferences.dart';
import 'package:r16a_cloud_app/core/session/user_summary.dart';
import 'package:r16a_cloud_app/features/files/data/file_downloads.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/domain/file_event.dart';
import 'package:r16a_cloud_app/features/files/domain/file_item.dart';
import 'package:r16a_cloud_app/features/files/domain/file_page.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';

FileItem fakeFile(
  String id, {
  bool isDirectory = false,
  String? parentId,
  String extension = 'txt',
  String? name,
  String ownerId = 'owner-1',
  List<String> sharedWithIds = const [],
}) => FileItem(
  id: id,
  name: name ?? (isDirectory ? id : '$id.$extension'),
  description: null,
  fsPath: '/$id',
  isDirectory: isDirectory,
  visibility: 'PRIVATE',
  parentId: parentId,
  ownerId: ownerId,
  ownerDisplayName: 'Owner',
  sharedWithIds: sharedWithIds,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  takenAt: null,
  blurHash: null,
);

FileCursorPage fakePage(List<FileItem> items, {String? nextCursor}) =>
    FileCursorPage(
      content: items,
      nextCursor: nextCursor,
      hasMore: nextCursor != null,
    );

/// One recorded `getFiles` call; complete [response] to answer it.
class FilesCall {
  FilesCall(
    this.parentId,
    this.cursor,
    this.sortField,
    this.sortDirection,
    this.ifNoneMatch,
  );

  final String? parentId;
  final String? cursor;
  final FileSortField sortField;
  final FileSortDirection sortDirection;

  /// ETag sent for revalidation, if any.
  final String? ifNoneMatch;
  final result = Completer<({FileCursorPage? page, String? etag})>();

  /// Answers with a 200 page (and optionally an ETag).
  late final response = _ResponseHandle(result);

  void notModified({String? etag}) =>
      result.complete((page: null, etag: etag ?? ifNoneMatch));
}

class _ResponseHandle {
  _ResponseHandle(this._result);

  final Completer<({FileCursorPage? page, String? etag})> _result;

  bool get isCompleted => _result.isCompleted;

  void complete(FileCursorPage page, {String? etag}) =>
      _result.complete((page: page, etag: etag));

  void completeError(Object error) => _result.completeError(error);
}

/// [FilesApi] whose listing calls stay pending until the test answers them.
class FakeFilesApi extends FilesApi {
  FakeFilesApi() : super(Dio());

  final calls = <FilesCall>[];
  final sharedCalls = <Completer<List<FileItem>>>[];

  /// Every listing request (first pages and cursor pages) lands here.
  @override
  Future<({FileCursorPage? page, String? etag})> getFilesRevalidating({
    required String ownerId,
    String? parentId,
    FileSortField sortField = FileSortField.name,
    FileSortDirection sortDirection = FileSortDirection.asc,
    String? cursor,
    int limit = FilesApi.pageSize,
    String? ifNoneMatch,
  }) {
    final call = FilesCall(
      parentId,
      cursor,
      sortField,
      sortDirection,
      ifNoneMatch,
    );
    calls.add(call);
    return call.result.future;
  }

  /// File ids asked for a thumbnail; answered with an error (no thumbnail)
  /// unless [thumbnailBytes] is set.
  final thumbnailCalls = <(String, ThumbnailSize)>[];
  Uint8List? thumbnailBytes;
  final downloadCalls = <String>[];

  @override
  Future<Uint8List> getThumbnail(
    String id, {
    ThumbnailSize size = ThumbnailSize.small,
    Duration? receiveTimeout,
  }) async {
    thumbnailCalls.add((id, size));
    final bytes = thumbnailBytes;
    if (bytes == null) throw Exception('no thumbnail');
    return bytes;
  }

  /// Never completes — previews stay in their loading state.
  @override
  Future<Uint8List> downloadBytes(String id, {Duration? receiveTimeout}) {
    downloadCalls.add(id);
    return Completer<Uint8List>().future;
  }

  @override
  Future<String> getDownloadToken(String id) async => 'tkn-$id';

  /// Delta-sync pages served in order; empty once drained.
  final eventPages = <FileEventsPage>[];
  final eventCalls = <int>[];

  @override
  Future<FileEventsPage> getFileEvents({
    required String ownerId,
    required int since,
    int limit = 100,
  }) async {
    eventCalls.add(since);
    if (eventPages.isEmpty) {
      return FileEventsPage(
        events: const [],
        nextCursor: since,
        hasMore: false,
      );
    }
    return eventPages.removeAt(0);
  }

  // ── Mutations: answered immediately and recorded ──

  final deleted = <String>[];

  /// Ids whose delete fails with a 500.
  final failingDeletes = <String>{};
  final renamed = <(String, String)>[];
  final sharingUpdates = <(String, List<String>)>[];

  /// When set, every mutation fails with this.
  ApiException? mutationError;

  @override
  Future<FileItem> createFolder({
    required String ownerId,
    required String name,
    String? parentId,
  }) async {
    if (mutationError case final e?) throw e;
    return fakeFile(name, isDirectory: true, parentId: parentId);
  }

  @override
  Future<FileItem> rename(String id, String name) async {
    if (mutationError case final e?) throw e;
    renamed.add((id, name));
    return fakeFile(id, name: name);
  }

  @override
  Future<FileItem> updateSharing(String id, List<String> sharedWithIds) async {
    if (mutationError case final e?) throw e;
    sharingUpdates.add((id, sharedWithIds));
    return fakeFile(id, sharedWithIds: sharedWithIds);
  }

  @override
  Future<void> delete(String id) async {
    if (mutationError case final e?) throw e;
    if (failingDeletes.contains(id)) {
      throw const ApiException('boom', statusCode: 500);
    }
    deleted.add(id);
  }

  @override
  Future<List<FileItem>> getFilesSharedWithMe({
    FileSortField sortField = FileSortField.name,
    FileSortDirection sortDirection = FileSortDirection.asc,
    int page = 0,
    int size = FilesApi.pageSize,
  }) {
    final completer = Completer<List<FileItem>>();
    sharedCalls.add(completer);
    return completer.future;
  }
}

class FakeSessionApi extends SessionApi {
  FakeSessionApi() : super(Dio());

  @override
  Future<CurrentUser> getCurrentUser() async => const CurrentUser(
    id: 'owner-1',
    username: 'owner',
    displayName: 'Owner',
    email: 'owner@example.com',
    preferences: UserPreferences(
      theme: AppThemePreference.light,
      defaultViewMode: DefaultFileView.list,
      encryptFilesByDefault: false,
    ),
  );

  /// Includes the signed-in user, who the share picker must leave out.
  @override
  Future<List<UserSummary>> listUsers({int page = 0, int size = 200}) async =>
      const [
        UserSummary(
          id: 'owner-1',
          username: 'owner',
          displayName: 'Owner',
          email: 'owner@example.com',
        ),
        UserSummary(
          id: 'u2',
          username: 'jdoe',
          displayName: null,
          email: 'j@example.com',
        ),
        UserSummary(
          id: 'u3',
          username: 'amy',
          displayName: 'Amy',
          email: 'a@example.com',
        ),
      ];
}

/// Records opens and saves instead of touching the platform downloader.
class FakeFileDownloads extends FileDownloads {
  FakeFileDownloads() : super(FakeFilesApi(), () async => 'bearer');

  final fetched = <String>[];
  final opened = <String>[];
  final saved = <List<String>>[];

  /// Result of [open]: whether an app could open the file.
  bool canOpen = true;

  @override
  Future<String> fetchForOpening(
    FileItem file, {
    void Function(double progress)? onProgress,
    void Function(String taskId)? onStarted,
  }) async {
    fetched.add(file.id);
    return '/tmp/${file.name}';
  }

  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return canOpen;
  }

  @override
  Future<SavedDownload> save(
    List<FileItem> files, {
    void Function(double progress)? onProgress,
    void Function(String taskId)? onStarted,
  }) async {
    saved.add([for (final f in files) f.id]);
    return const SavedDownload(path: '/Download/x', inDownloads: true);
  }
}
