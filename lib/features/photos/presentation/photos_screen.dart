import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_screen.dart';

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Photos',
      icon: Icons.photo_library_rounded,
      message: 'Your photos and videos, grouped by year.',
    );
  }
}
