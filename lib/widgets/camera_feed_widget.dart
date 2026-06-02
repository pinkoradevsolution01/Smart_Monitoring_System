import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../models/camera.dart';

/// Widget to display live camera feed using VLC player
/// Supports RTSP, HTTP, HTTPS streams with authentication
class CameraFeedWidget extends StatefulWidget {
  final Camera camera;
  final bool showControls;
  final bool autoPlay;

  const CameraFeedWidget({
    super.key,
    required this.camera,
    this.showControls = false,
    this.autoPlay = true,
  });

  @override
  State<CameraFeedWidget> createState() => _CameraFeedWidgetState();
}

class _CameraFeedWidgetState extends State<CameraFeedWidget> {
  VlcPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(CameraFeedWidget oldWidget) {
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
      // Build URL with authentication if provided
      String streamUrl = widget.camera.url;
      if (widget.camera.username != null &&
          widget.camera.username!.isNotEmpty) {
        // Insert credentials into URL
        final uri = Uri.parse(widget.camera.url);
        final credentials =
            '${widget.camera.username}:${widget.camera.password ?? ''}';
        streamUrl = widget.camera.url.replaceFirst(
          '${uri.scheme}://',
          '${uri.scheme}://$credentials@',
        );
      }

      _controller = VlcPlayerController.network(
        streamUrl,
        hwAcc: HwAcc.full,
        autoPlay: widget.autoPlay,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(1000),
            VlcAdvancedOptions.clockJitter(0),
          ]),
          rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(true)]),
          video: VlcVideoOptions([
            VlcVideoOptions.dropLateFrames(true),
            VlcVideoOptions.skipFrames(true),
          ]),
        ),
      );

      await _controller!.initialize();

      // Listen for errors
      _controller!.addListener(() {
        if (mounted) {
          final state = _controller!.value.playingState;
          if (state == PlayingState.error) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Stream connection failed';
            });
          } else if (state == PlayingState.playing) {
            setState(() {
              _isLoading = false;
              _hasError = false;
            });
          }
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing camera feed: $e');
      String userFriendlyError = 'Failed to connect to camera';

      if (e.toString().contains('Connection refused')) {
        userFriendlyError = 'Connection refused. Check camera IP and port.';
      } else if (e.toString().contains('timeout')) {
        userFriendlyError = 'Connection timeout. Camera may be offline.';
      } else if (e.toString().contains('Network is unreachable')) {
        userFriendlyError = 'Network unreachable. Check WiFi connection.';
      } else if (e.toString().contains('401') ||
          e.toString().contains('Unauthorized')) {
        userFriendlyError = 'Authentication failed. Check username/password.';
      } else if (e.toString().contains('404')) {
        userFriendlyError = 'Stream not found. Check camera URL path.';
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = userFriendlyError;
      });
    }
  }

  void _disposePlayer() {
    _controller?.stopRendererScanning();
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
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
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
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Common issues:\n'
                  '• Camera and phone on different WiFi networks\n'
                  '• Wrong camera URL or credentials\n'
                  '• Camera is offline or powered off\n'
                  '• Firewall blocking connection',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.left,
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
              const SizedBox(height: 8),
              Text(
                'Camera: ${widget.camera.name}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'URL: ${widget.camera.url}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null) {
      return _buildLoadingState();
    }

    return Stack(
      children: [
        VlcPlayer(
          controller: _controller!,
          aspectRatio: 16 / 9,
          placeholder: _buildLoadingState(),
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
