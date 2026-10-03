import 'package:flutter/material.dart';

import '../upload_picker.dart';

/// "Upload from…" choices. Resolves to `null` when dismissed.
Future<UploadPick?> showUploadSourceSheet(BuildContext context) {
  return showModalBottomSheet<UploadPick>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      Widget tile(UploadPick pick, IconData icon, String label) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.of(context).pop(pick),
      );

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(UploadPick.files, Icons.folder_open_outlined, 'Files'),
              tile(
                UploadPick.media,
                Icons.photo_library_outlined,
                'Photos & videos',
              ),
              tile(UploadPick.camera, Icons.photo_camera_outlined, 'Camera'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
