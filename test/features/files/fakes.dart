import 'dart:async';

import 'package:dio/dio.dart';

import 'package:r16a_cloud_app/core/session/current_user.dart';
import 'package:r16a_cloud_app/core/session/session_api.dart';
import 'package:r16a_cloud_app/core/session/user_preferences.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/domain/file_item.dart';
import 'package:r16a_cloud_app/features/files/domain/file_page.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';

FileItem fakeFile(String id, {bool isDirectory = false, String? parentId}) =>
    FileItem(
      id: id,
      name: isDirectory ? id : '$id.txt',
      description: null,
      fsPath: '/$id',
      isDirectory: isDirectory,
      visibility: 'PRIVATE',
      parentId: parentId,
      ownerId: 'owner-1',
      ownerDisplayName: 'Owner',
      sharedWithIds: const [],
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
  FilesCall(this.parentId, this.cursor, this.sortField, this.sortDirection);

  final String? parentId;
  final String? cursor;
  final FileSortField sortField;
  final FileSortDirection sortDirection;
  final response = Completer<FileCursorPage>();
}

/// [FilesApi] whose listing calls stay pending until the test answers them.
class FakeFilesApi extends FilesApi {
  FakeFilesApi() : super(Dio());

  final calls = <FilesCall>[];
  final sharedCalls = <Completer<List<FileItem>>>[];

  @override
  Future<FileCursorPage> getFiles({
    required String ownerId,
    String? parentId,
    FileSortField sortField = FileSortField.name,
    FileSortDirection sortDirection = FileSortDirection.asc,
    String? cursor,
    int limit = FilesApi.pageSize,
  }) {
    final call = FilesCall(parentId, cursor, sortField, sortDirection);
    calls.add(call);
    return call.response.future;
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
}
