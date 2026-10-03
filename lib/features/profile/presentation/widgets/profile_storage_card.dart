import 'package:flutter/material.dart';

import 'profile_card.dart';

/// Local storage: lets the user drop cached listings, thumbnails and
/// opened-file copies. No web equivalent (the browser manages its caches).
class ProfileStorageCard extends StatefulWidget {
  const ProfileStorageCard({super.key, required this.onClearCache});

  final Future<void> Function() onClearCache;

  @override
  State<ProfileStorageCard> createState() => _ProfileStorageCardState();
}

class _ProfileStorageCardState extends State<ProfileStorageCard> {
  var _clearing = false;

  Future<void> _clear() async {
    setState(() => _clearing = true);
    try {
      await widget.onClearCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Cache cleared')));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSectionHeader(
            title: 'Storage',
            subtitle: 'Data saved on this device',
          ),
          const SizedBox(height: 12),
          Text(
            'Saved folder listings, thumbnails and copies of files kept '
            'inside the app. Your files in the cloud, and anything saved to '
            'your Downloads folder, are not affected.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearing ? null : _clear,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: Text(_clearing ? 'Clearing…' : 'Clear cache'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
