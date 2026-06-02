import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../models/camera.dart';

/// Widget that displays a camera feed using appropriate player based on platform
/// Uses VLC player for desktop/Android, video_player for iOS, and fallback for web
class CameraPlayerWidget extends StatefulWidget {
  final Camera camera;
  final bool showControls;
  final VoidCallback? onError;

  const CameraPlayerWidget({
    super.key,
    required this.camera,
    this.showControls = false,
    this.onError,
  });

  @override
  State<CameraPlayerWidget> createState() => _CameraPlayerWidgetState();
}

class _CameraPlayerWidgetState extends State<CameraPlayerWidget> {
  // Video player for iOS and HTTP streams
  VideoPlayerController? _videoController;
  
  // VLC player for RTSP and desktop
  VlcPlayerController? _vlcController;
  
  bool _isLoading = true;
  String? _errorMessage;
  bool _useVlc = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(CameraPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.url != widget.camera.url) {
      _disposeControllers();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Determine which player to use
      _useVlc = _shouldUseVlc();

      if (_useVlc) {
        await _initializeVlcPlayer();
      } else {
        await _initializeVideoPlayer();
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      widget.onError?.call();
    }
  }

  bool _shouldUseVlc() {
    // Use VLC for RTSP streams and desktop platforms
    // VLC has better RTSP support than video_player
    if (kIsWeb) return false; // VLC not supported on web
    
    final url = widget.camera.url.toLowerCase();
    final isRtsp = url.startsWith('rtsp://');
    
    // Use VLC for RTSP or on desktop platforms
    if (isRtsp) return true;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return true;
    }
    
    return false;
  }

  Future<void> _initializeVlcPlayer() async {
    String streamUrl = widget.camera.url;

    // Add authentication if provided
    if (widget.camera.username != null && widget.camera.username!.isNotEmpty) {
      final uri = Uri.parse(widget.camera.url);
      final userInfo = '${widget.camera.username}:${widget.camera.password ?? ''}';
      streamUrl = widget.camera.url.replaceFirst(
        '${uri.scheme}://',
        '${uri.scheme}://$userInfo@',
      );
    }

    _vlcController = VlcPlayerController.network(
      streamUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(1000),
        ]),
        rtp: VlcRtpOptions([
          VlcRtpOptions.rtpOverRtsp(true),
        ]),
        video: VlcVideoOptions([
          VlcVideoOptions.dropLateFrames(true),
          VlcVideoOptions.skipFrames(true),
        ]),
      ),
    );

    await _vlcController!.initialize();

    _vlcController!.addListener(() {
      if (mounted) {
        final playbackState = _vlcController!.value.playingState;
        if (playbackState == PlayingState.playing) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        } else if (playbackState == PlayingState.error) {
          setState(() {
            _errorMessage = 'Failed to connect to camera stream';
            _isLoading = false;
          });
          widget.onError?.call();
        }
      }
    });

    // Start playing
    await _vlcController!.play();
  }

  Future<void> _initializeVideoPlayer() async {
    String streamUrl = widget.camera.url;

    // video_player supports HTTP/HTTPS but has limited RTSP support
    if (streamUrl.startsWith('rtsp://') && !kIsWeb) {
      // Try to use video_player anyway, but expect it might fail
      debugPrint('Warning: video_player has limited RTSP support');
    }

    _videoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));

    _videoController!.addListener(() {
      if (mounted) {
        if (_videoController!.value.hasError) {
          setState(() {
            _errorMessage = _videoController!.value.errorDescription ??
                'Failed to connect to camera';
            _isLoading = false;
          });
          widget.onError?.call();
        } else if (_videoController!.value.isInitialized) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }
    });

    await _videoController!.initialize();
    await _videoController!.play();
    _videoController!.setLooping(true);
  }

  void _disposeControllers() {
    _videoController?.dispose();
    _videoController = null;
    _vlcController?.dispose();
    _vlcController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_useVlc && _vlcController != null) {
      return _buildVlcPlayer();
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      return _buildVideoPlayer();
    }

    return _buildLoadingWidget();
  }

  Widget _buildVlcPlayer() {
    return VlcPlayer(
      controller: _vlcController!,
      aspectRatio: 16 / 9,
      placeholder: _buildLoadingWidget(),
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }

  Widget _buildLoadingWidget() {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting to ${widget.camera.name}...',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              widget.camera.type.toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Failed',
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'Unable to connect to camera stream',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Show camera info
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Camera Details'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name: ${widget.camera.name}'),
                        const SizedBox(height: 8),
                        Text('Type: ${widget.camera.type.toUpperCase()}'),
                        const SizedBox(height: 8),
                        Text('URL: ${widget.camera.url}'),
                        const SizedBox(height: 8),
                        if (widget.camera.username != null)
                          Text('Username: ${widget.camera.username}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'View Details',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
