import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Files',
      icon: Icons.cloud_rounded,
      message: 'Browse, upload and share your files here.',
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.create_new_folder_outlined),
          tooltip: 'New folder',
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.upload_outlined),
          tooltip: 'Upload',
        ),
      ],
    );
  }
}
