import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../utils/app_localizations.dart';

class ProductCameraScreen extends StatefulWidget {
  const ProductCameraScreen({super.key});

  @override
  State<ProductCameraScreen> createState() => _ProductCameraScreenState();
}

class _ProductCameraScreenState extends State<ProductCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  int _selectedCameraIndex = 0;
  bool _flashOn = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No cameras available')));
        }
        return;
      }

      _controller = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (_flashOn) {
        await _controller!.setFlashMode(FlashMode.torch);
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await _controller!.takePicture();

      // Save to app directory
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/product_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = path.join(imagesDir.path, fileName);
      await File(image.path).copy(savedPath);

      if (mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });

    await _controller?.dispose();
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _flashOn = !_flashOn;
    });

    try {
      await _controller!.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Flash not supported: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      // On Windows (image_picker limited), use file_picker as fallback
      if (!kIsWeb && Platform.isWindows) {
        final file = await FilePicker.pickFile(type: FileType.image);
        if (file?.path != null) {
          final saved = await _persistImage(File(file!.path!));
          if (mounted) Navigator.pop(context, saved);
        }
        return;
      }

      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final saved = await _persistImage(File(picked.path));
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<String> _persistImage(File file) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/product_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final fileName =
        'product_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
    final savedPath = path.join(imagesDir.path, fileName);
    await file.copy(savedPath);
    return savedPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('capture_product_image')),
        backgroundColor: Colors.black,
        actions: [
          if (_isInitialized && _cameras != null && _cameras!.length > 1)
            IconButton(
              tooltip: 'Switch Camera',
              icon: const Icon(Icons.flip_camera_android),
              onPressed: _toggleCamera,
            ),
          if (_isInitialized)
            IconButton(
              tooltip: _flashOn ? 'Flash Off' : 'Flash On',
              icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
            ),
          IconButton(
            tooltip: 'Pick from Gallery',
            icon: const Icon(Icons.photo_library),
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _isInitialized
          ? Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                ),
                if (_isCapturing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Tap to capture',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isInitialized
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'galleryBtn',
                  onPressed: _pickFromGallery,
                  backgroundColor: Colors.white70,
                  child: const Icon(Icons.photo, color: Colors.black),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.large(
                  heroTag: 'cameraBtn',
                  onPressed: _isCapturing ? null : _captureImage,
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ],
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
