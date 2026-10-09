import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_colors.dart';
import '../../logging/app_logger.dart';
import '../../model/file_item.dart';
import '../media_providers.dart';

/// One video in `FileViewerScreen`: streamed from [videoSourceProvider]
/// with Chewie controls; [placeholder] until the first frame is ready. No
/// web equivalent (the web only shows video thumbnails).
///
/// Plays while [active] (the page on screen), pauses when swiped away. A
/// playback error (typically the 5-minute link expiring before a seek) gets
/// a fresh link, resuming where it was. Formats the platform can't play
/// (e.g. MKV/AVI, WebM on iOS) fall back to [onOpenWith].
class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({
    super.key,
    required this.file,
    required this.active,
    required this.placeholder,
    required this.onOpenWith,
  });

  final FileItem file;
  final bool active;
  final Widget placeholder;
  final VoidCallback onOpenWith;

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  /// Fresh links tried after playback errors before giving up.
  static const _maxRecoveries = 2;

  VideoPlayerController? _video;
  ChewieController? _chewie;
  var _failed = false;
  var _recoveries = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) _video?.pause();
    if (!oldWidget.active && widget.active) _video?.play();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  Future<void> _load({Duration? startAt}) async {
    VideoPlayerController? video;
    try {
      final uri = await ref.read(videoSourceProvider)(widget.file);
      if (!mounted) return;
      video = VideoPlayerController.networkUrl(uri);
      await video.initialize();
      if (startAt != null) await video.seekTo(startAt);
    } catch (e, stack) {
      await video?.dispose();
      if (!mounted) return;
      AppLogger.error(e, stack, 'Could not play ${widget.file.name}');
      setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await video.dispose();
      return;
    }

    video.addListener(_onVideoChanged);
    setState(() {
      _video = video;
      _chewie = ChewieController(
        videoPlayerController: video!,
        autoPlay: widget.active,
        allowFullScreen: false,
        allowedScreenSleep: false,
        showOptions: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.darkPrimary,
          handleColor: AppColors.darkPrimary,
          bufferedColor: AppColors.darkForeground.withValues(alpha: 0.4),
          backgroundColor: AppColors.darkForeground.withValues(alpha: 0.2),
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: AppColors.darkPrimary,
          handleColor: AppColors.darkPrimary,
          bufferedColor: AppColors.darkForeground.withValues(alpha: 0.4),
          backgroundColor: AppColors.darkForeground.withValues(alpha: 0.2),
        ),
      );
    });
  }

  void _onVideoChanged() {
    final value = _video?.value;
    if (value == null || !value.hasError) return;
    final position = value.position;
    AppLogger.error(
      value.errorDescription ?? 'Playback error',
      StackTrace.current,
      'Playback of ${widget.file.name} failed',
    );
    _release();
    if (_recoveries >= _maxRecoveries) {
      setState(() => _failed = true);
      return;
    }
    _recoveries++;
    setState(() {});
    _load(startAt: position);
  }

  void _release() {
    _video?.removeListener(_onVideoChanged);
    _chewie?.dispose();
    _video?.dispose();
    _chewie = null;
    _video = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not play this video.',
                style: TextStyle(color: AppColors.darkForeground),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onOpenWith,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open with another app'),
              ),
            ],
          ),
        ),
      );
    }

    final chewie = _chewie;
    if (chewie == null) return widget.placeholder;
    // Below the translucent app bar, so controls never sit under it.
    return SafeArea(child: Chewie(controller: chewie));
  }
}
