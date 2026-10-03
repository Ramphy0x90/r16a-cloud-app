import 'dart:async';

import 'package:dio/dio.dart';

import 'package:r16a_cloud_app/core/model/file_item.dart';
import 'package:r16a_cloud_app/features/files/domain/file_page.dart';
import 'package:r16a_cloud_app/features/photos/data/photos_api.dart';
import 'package:r16a_cloud_app/features/photos/domain/photo_year.dart';

import '../files/fakes.dart';

/// A photo dated [taken] (UTC).
FileItem fakePhoto(String id, DateTime taken, {String owner = 'owner-1'}) =>
    FileItem(
      id: id,
      name: '$id.jpg',
      description: null,
      fsPath: '/$id.jpg',
      isDirectory: false,
      visibility: 'PRIVATE',
      parentId: null,
      ownerId: owner,
      ownerDisplayName: owner == 'owner-1' ? 'Owner' : 'Friend',
      sharedWithIds: const [],
      createdAt: taken,
      updatedAt: taken,
      takenAt: taken,
      blurHash: null,
    );

/// One `getPhotos` request; complete [response] to answer it.
class PhotosCall {
  PhotosCall(this.year, this.cursor);

  final int year;
  final String? cursor;
  final response = Completer<FileCursorPage>();
}

/// Years and shared media answer immediately; year pages wait for the
/// test, like [FakeFilesApi]'s listings.
class FakePhotosApi extends PhotosApi {
  FakePhotosApi({this.years = const [], this.shared = const []}) : super(Dio());

  List<PhotoYear> years;
  List<FileItem> shared;
  Object? yearsError;
  Object? sharedError;
  final calls = <PhotosCall>[];

  @override
  Future<List<PhotoYear>> getPhotoYears(String ownerId) async {
    if (yearsError case final e?) throw e;
    return years;
  }

  @override
  Future<List<FileItem>> getSharedMedia() async {
    if (sharedError case final e?) throw e;
    return shared;
  }

  @override
  Future<FileCursorPage> getPhotos({
    required String ownerId,
    required int year,
    String? cursor,
    int limit = PhotosApi.pageSize,
  }) {
    final call = PhotosCall(year, cursor);
    calls.add(call);
    return call.response.future;
  }
}

/// Re-exported so photos tests need one fakes import.
FileCursorPage photoPage(List<FileItem> items, {String? nextCursor}) =>
    fakePage(items, nextCursor: nextCursor);
