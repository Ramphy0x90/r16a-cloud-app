import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';

import '../data/upload_source.dart';

/// Where the upload sheet picks from — the native replacement for the web's
/// `<input type="file" multiple>` and drag & drop.
enum UploadPick { files, media, camera }

/// Opens the system picker for [pick] and returns what was chosen (empty
/// when cancelled). Platform failures (e.g. denied camera permission)
/// propagate to the caller.
Future<List<UploadSource>> pickUploadSources(UploadPick pick) async {
  final List<XFile> files;
  switch (pick) {
    case UploadPick.files:
      final picked = await fp.FilePicker.pickFiles();
      files = [for (final f in picked) f.xFile];
    case UploadPick.media:
      files = await ImagePicker().pickMultipleMedia();
    case UploadPick.camera:
      final photo = await ImagePicker().pickImage(source: ImageSource.camera);
      files = [?photo];
  }
  return [for (final file in files) await _toSource(file)];
}

Future<UploadSource> _toSource(XFile file) async => UploadSource(
  name: file.name,
  size: await file.length(),
  openRead: file.openRead,
);
