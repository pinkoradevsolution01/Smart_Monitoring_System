import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/camera.dart';

/// Fallback camera feed widget using video_player for platforms where VLC is unavailable
/// Use this as a backup when flutter_vlc_player fails to initialize
class CameraFeedFallback extends StatefulWidget {
  final Camera camera;
  final bool showControls;
  final bool autoPlay;

  const CameraFeedFallback({
    super.key,
    required this.camera,
    this.showControls = false,
    this.autoPlay = true,
  });

  @override
  State<CameraFeedFallback> createState() => _CameraFeedFallbackState();
}

class _CameraFeedFallbackState extends State<CameraFeedFallback> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(CameraFeedFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.url != widget.camera.url) {
      _disposePlayer();
      _initializePlayer();
    }
  }

  void _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Note: video_player has limited RTSP support on mobile
      // Works better with HTTP/HTTPS streams
      final uri = Uri.parse(widget.camera.url);

      if (uri.scheme == 'rtsp' &&
          (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS)) {
        // RTSP not supported on web or iOS with video_player
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage =
              'RTSP streams not supported on this platform. Please use HTTP/HTTPS or use flutter_vlc_player.';
        });
        return;
      }

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.camera.url),
      );

      await _controller!.initialize();

      _controller!.addListener(() {
        if (mounted && _controller!.value.hasError) {
          setState(() {
            _hasError = true;
            _errorMessage =
                _controller!.value.errorDescription ?? 'Playback error';
          });
        }
      });

      if (widget.autoPlay) {
        await _controller!.play();
        _controller!.setLooping(true);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing video player fallback: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to connect: ${e.toString()}';
      });
    }
  }

  void _disposePlayer() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Connecting to camera...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              const Text(
                'Camera Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage.isNotEmpty
                      ? _errorMessage
                      : 'Unable to connect to camera stream',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return _buildLoadingState();
    }

    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        // Live indicator
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Camera name overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Text(
              widget.camera.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    return _buildVideoPlayer();
  }
}
