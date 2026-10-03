import 'package:flutter/material.dart';

/// A not-yet-loaded photo — the web's skeleton grid. Asks for the next
/// page once it is laid out (i.e. scrolled near the screen), which stands
/// in for the web's per-year `inViewport` trigger and scroll sentinel.
class PhotoPlaceholderTile extends StatefulWidget {
  const PhotoPlaceholderTile({
    super.key,
    required this.failed,
    required this.onVisible,
  });

  /// The page request failed: show that instead of asking again.
  final bool failed;
  final VoidCallback onVisible;

  @override
  State<PhotoPlaceholderTile> createState() => _PhotoPlaceholderTileState();
}

class _PhotoPlaceholderTileState extends State<PhotoPlaceholderTile> {
  @override
  void initState() {
    super.initState();
    _requestIfNeeded();
  }

  @override
  void didUpdateWidget(PhotoPlaceholderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refresh clears the failure; ask again.
    if (oldWidget.failed && !widget.failed) _requestIfNeeded();
  }

  /// After the frame: providers can't change while widgets build.
  void _requestIfNeeded() {
    if (widget.failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: widget.failed
          ? Icon(
              Icons.cloud_off_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            )
          : null,
    );
  }
}
