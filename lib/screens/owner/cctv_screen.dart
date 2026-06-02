import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/cctv_service.dart';
import '../../services/cctv_config.dart';
import '../../models/camera.dart';
import '../../models/cctv_timestamp.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/camera_feed_widget.dart';
import 'dart:io' show Platform;

class CCTVScreen extends StatefulWidget {
  final DateTime? timestamp;

  const CCTVScreen({super.key, this.timestamp});

  @override
  State<CCTVScreen> createState() => _CCTVScreenState();
}

class _CCTVScreenState extends State<CCTVScreen> {
  late CCTVService _cctvService;
  Camera? _fullscreenCamera;

  @override
  void initState() {
    super.initState();
    _cctvService = CCTVService.instance;
    _cctvService.addListener(_onCCTVStateChanged);
    _loadCameras();
  }

  void _onCCTVStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCameras() async {
    await _cctvService.loadCameras();
    await _cctvService.loadTimestamps();

    // If timestamp is passed from sale record, auto-open save timestamp dialog
    if (widget.timestamp != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveTimestampWithDate(widget.timestamp!);
      });
    }
  }

  Future<void> _scanCameraQRCode() async {
    try {
      debugPrint('QR Scanner: Starting camera permission request...');

      // Check current permission status first
      var status = await Permission.camera.status;
      debugPrint('QR Scanner: Current permission status: $status');

      // If not granted, request permission
      if (!status.isGranted) {
        status = await Permission.camera.request();
        debugPrint('QR Scanner: Permission status after request: $status');
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status.isPermanentlyDenied
                    ? 'Camera permission permanently denied. Please enable it in Settings.'
                    : 'Camera permission is required to scan QR codes',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      debugPrint('QR Scanner: Opening scanner dialog...');
      String? scannedData;
      bool isDisposed = false;
      final MobileScannerController controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan Camera QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && scannedData == null) {
                          scannedData = barcodes.first.rawValue;
                          debugPrint('QR Scanner: Detected code: $scannedData');
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Point camera at QR code on CCTV device',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ).then((_) {
        // Safely dispose controller after dialog is closed
        if (!isDisposed) {
          isDisposed = true;
          try {
            controller.dispose();
            debugPrint('QR Scanner: Controller disposed');
          } catch (e) {
            debugPrint('QR Scanner: Error disposing controller - $e');
          }
        }
      });

      if (scannedData != null && scannedData!.isNotEmpty) {
        _processCameraQRData(scannedData!);
      }
    } catch (e) {
      debugPrint('QR Scanner: Error - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open QR scanner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processCameraQRData(String qrData) {
    try {
      // Parse QR code data - supports multiple formats:
      // 1. Full URL: rtsp://192.168.1.100:554/stream
      // 2. JSON: {"ip":"192.168.1.100","port":"554","user":"admin","pass":"12345"}
      // 3. Key-value: ip=192.168.1.100&port=554&user=admin&pass=12345

      String? cameraUrl;
      String? username;
      String? password;
      String? cameraName;

      if (qrData.startsWith('rtsp://') ||
          qrData.startsWith('http://') ||
          qrData.startsWith('https://')) {
        // Direct URL format
        cameraUrl = qrData;
      } else if (qrData.trim().startsWith('{')) {
        // JSON format - use proper JSON parsing
        try {
          final Map<String, dynamic> jsonData = json.decode(qrData);

          final ip = jsonData['ip'] ?? jsonData['host'];
          final port = jsonData['port']?.toString() ?? '554';
          final path = jsonData['path']?.toString() ?? '/stream';
          final protocol = jsonData['protocol']?.toString() ?? 'rtsp';
          username = jsonData['user'] ?? jsonData['username'];
          password = jsonData['pass'] ?? jsonData['password'];
          cameraName = jsonData['name'];

          // Handle full URL in JSON
          if (jsonData['url'] != null) {
            cameraUrl = jsonData['url'].toString();
          } else if (ip != null) {
            // Construct URL from components
            cameraUrl = '$protocol://$ip:$port$path';
          }
        } catch (e) {
          debugPrint('Failed to parse JSON QR: $e');
          // Try old parsing method as fallback
          final data = qrData
              .replaceAll('{', '')
              .replaceAll('}', '')
              .replaceAll('"', '')
              .split(',');

          Map<String, String> params = {};
          for (var item in data) {
            final colonIndex = item.indexOf(':');
            if (colonIndex != -1) {
              final key = item.substring(0, colonIndex).trim();
              final value = item.substring(colonIndex + 1).trim();
              params[key] = value;
            }
          }

          final ip = params['ip'];
          final port = params['port'] ?? '554';
          final path = params['path'] ?? '/stream';
          username = params['user'] ?? params['username'];
          password = params['pass'] ?? params['password'];
          cameraName = params['name'];

          if (ip != null) {
            cameraUrl = 'rtsp://$ip:$port$path';
          }
        }
      } else if (qrData.contains('=')) {
        // Key-value format
        final parts = qrData.split('&');
        Map<String, String> params = {};
        for (var part in parts) {
          final kv = part.split('=');
          if (kv.length == 2) {
            params[kv[0].trim()] = kv[1].trim();
          }
        }

        final ip = params['ip'];
        final port = params['port'] ?? '554';
        final path = params['path'] ?? '/stream';
        username = params['user'] ?? params['username'];
        password = params['pass'] ?? params['password'];
        cameraName = params['name'];

        if (ip != null) {
          cameraUrl = 'rtsp://$ip:$port$path';
        }
      }

      if (cameraUrl != null) {
        _addCameraFromQR(cameraUrl, username, password, cameraName);
      } else {
        _showQRErrorDialog('Invalid QR code format');
      }
    } catch (e) {
      _showQRErrorDialog('Failed to parse QR code: $e');
    }
  }

  void _addCameraFromQR(
    String url,
    String? username,
    String? password,
    String? suggestedName,
  ) {
    final nameController = TextEditingController(
      text: suggestedName ?? 'Camera ${_cctvService.cameras.length + 1}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Camera Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Camera Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 16),
              Text('URL: $url', style: const TextStyle(fontSize: 12)),
              if (username != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Username: $username',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (password != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Password: ${'*' * password.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              String type = 'rtsp';
              if (url.startsWith('http://')) type = 'http';
              if (url.startsWith('https://')) type = 'https';

              final newCamera = Camera(
                name: name,
                url: url,
                type: type,
                position: _cctvService.cameras.length,
                username: username,
                password: password,
              );

              final success = await _cctvService.addCamera(newCamera);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Camera "$name" added successfully'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to add camera'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Add Camera'),
          ),
        ],
      ),
    );
  }

  void _showQRErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cctvService.removeListener(_onCCTVStateChanged);
    super.dispose();
  }

  void _showAddCameraDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final ipController = TextEditingController();
    String selectedType = 'rtsp';
    String? selectedPreset;
    bool showAuthFields = false;
    bool useV380Builder = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(AppLocalizations.t('add_camera'))),
              if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan QR Code',
                  onPressed: () async {
                    debugPrint('QR Scanner button pressed');
                    Navigator.pop(context);
                    await _scanCameraQRCode();
                  },
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR Scan hint (only show on mobile)
                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: Tap QR icon above to scan camera QR code',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('camera_name'),
                    hintText: 'Front Entrance, Cashier Area, etc.',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                // Camera brand preset dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedPreset,
                  decoration: InputDecoration(
                    labelText: 'Camera Brand (Optional)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.camera),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Custom URL'),
                    ),
                    ...CCTVConfig.getSupportedBrands().map(
                      (brand) =>
                          DropdownMenuItem(value: brand, child: Text(brand)),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPreset = value;
                      useV380Builder =
                          value != null && value.startsWith('V380');
                      showAuthFields = useV380Builder;

                      if (value != null && !useV380Builder) {
                        urlController.text =
                            CCTVConfig.getExampleUrl(value) ?? '';
                        selectedType = 'rtsp';
                      } else if (useV380Builder) {
                        selectedType = 'v380';
                        usernameController.text = 'admin';
                      } else {
                        urlController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (useV380Builder) ...[
                  // V380 Pro IP address builder
                  TextField(
                    controller: ipController,
                    decoration: const InputDecoration(
                      labelText: 'Camera IP Address',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.router),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!useV380Builder) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('camera_type'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'rtsp', child: Text('RTSP')),
                      DropdownMenuItem(value: 'http', child: Text('HTTP')),
                      DropdownMenuItem(value: 'https', child: Text('HTTPS')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.t('camera_url'),
                      hintText: '$selectedType://192.168.1.100:554/stream',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  // Show auth toggle for manual URL
                  Row(
                    children: [
                      Checkbox(
                        value: showAuthFields,
                        onChanged: (value) {
                          setDialogState(() {
                            showAuthFields = value ?? false;
                          });
                        },
                      ),
                      const Text('Requires Authentication'),
                    ],
                  ),
                ],
                if (showAuthFields) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'admin',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  return;
                }

                String finalUrl;
                if (useV380Builder && ipController.text.trim().isNotEmpty) {
                  // Build V380 Pro URL
                  finalUrl = CCTVConfig.buildV380Url(
                    ip: ipController.text.trim(),
                    username: usernameController.text.trim(),
                    password: passwordController.text.trim(),
                    useSubStream: selectedPreset?.contains('Sub') ?? false,
                  );
                } else if (urlController.text.trim().isNotEmpty) {
                  finalUrl = urlController.text.trim();
                } else {
                  return;
                }

                final newCamera = Camera(
                  name: nameController.text.trim(),
                  url: finalUrl,
                  type: selectedType,
                  position: _cctvService.cameras.length,
                  username: showAuthFields
                      ? usernameController.text.trim()
                      : null,
                  password: showAuthFields
                      ? passwordController.text.trim()
                      : null,
                );

                final success = await _cctvService.addCamera(newCamera);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.t('camera_added')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.t('add')),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigureCameraDialog(Camera camera) {
    final nameController = TextEditingController(text: camera.name);
    final urlController = TextEditingController(text: camera.url);
    final usernameController = TextEditingController(
      text: camera.username ?? '',
    );
    final passwordController = TextEditingController(
      text: camera.password ?? '',
    );
    String selectedType = camera.type;
    bool showAuthFields =
        camera.username != null && camera.username!.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.t('configure_camera')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('camera_name'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('camera_type'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'rtsp', child: Text('RTSP')),
                    DropdownMenuItem(value: 'http', child: Text('HTTP')),
                    DropdownMenuItem(value: 'https', child: Text('HTTPS')),
                    DropdownMenuItem(value: 'v380', child: Text('V380 Pro')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.t('camera_url'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: showAuthFields,
                      onChanged: (value) {
                        setDialogState(() {
                          showAuthFields = value ?? false;
                        });
                      },
                    ),
                    const Text('Requires Authentication'),
                  ],
                ),
                if (showAuthFields) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'admin',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    urlController.text.trim().isEmpty) {
                  return;
                }

                final updatedCamera = camera.copyWith(
                  name: nameController.text.trim(),
                  url: urlController.text.trim(),
                  type: selectedType,
                  username: showAuthFields
                      ? usernameController.text.trim()
                      : null,
                  password: showAuthFields
                      ? passwordController.text.trim()
                      : null,
                );

                final success = await _cctvService.updateCamera(
                  camera.id!,
                  updatedCamera,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.t('camera_updated')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCameraDialog(Camera camera) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t('confirm_delete_camera')),
        content: Text(camera.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await _cctvService.deleteCamera(camera.id!);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.t('camera_deleted')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.t('delete')),
          ),
        ],
      ),
    );
  }

  void _showCameraFullscreen(Camera camera) {
    setState(() {
      _fullscreenCamera = camera;
      _cctvService.selectCamera(camera);
    });
  }

  void _exitFullscreen() {
    setState(() {
      _fullscreenCamera = null;
      _cctvService.disconnect();
    });
  }

  void _showTimestampsLog() async {
    await _cctvService.loadTimestamps();
    if (!mounted) return;

    final List<CCTVTimestamp> timestamps = _cctvService.savedTimestamps;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.access_time),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.t('saved_timestamps'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: timestamps.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.t('no_timestamps_saved'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: timestamps.length,
                  itemBuilder: (context, idx) {
                    final ts = timestamps[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 0,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          ts.formattedTimestamp,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${ts.formattedDate}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (ts.description != null &&
                                ts.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  ts.description!,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View footage button
                            IconButton(
                              tooltip: AppLocalizations.t('view_footage'),
                              icon: const Icon(
                                Icons.play_circle_outline,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                // Navigate to timestamp view (if needed)
                              },
                            ),
                            // Export video button
                            IconButton(
                              tooltip: ts.videoPath != null
                                  ? AppLocalizations.t('video_exported')
                                  : AppLocalizations.t('export_video'),
                              icon: Icon(
                                ts.videoPath != null
                                    ? Icons.check_circle
                                    : Icons.download,
                                color: ts.videoPath != null
                                    ? Colors.green
                                    : Colors.blue,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: ts.id == null
                                  ? null
                                  : () async {
                                      if (ts.videoPath != null) {
                                        // Show exported video path
                                        if (context.mounted) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text(
                                                AppLocalizations.t(
                                                  'video_exported',
                                                ),
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    AppLocalizations.t(
                                                      'file_path',
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(ts.videoPath!),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    AppLocalizations.t('close'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      // Export footage
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final navigator = Navigator.of(context);

                                      // Show loading dialog
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(
                                          child: Card(
                                            child: Padding(
                                              padding: EdgeInsets.all(24),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(),
                                                  SizedBox(height: 16),
                                                  Text('Exporting footage...'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );

                                      final filePath = await _cctvService
                                          .exportFootage(
                                            ts.id!,
                                            ts.timestamp,
                                            durationSeconds: 60,
                                          );

                                      if (context.mounted) {
                                        navigator.pop(); // Close loading dialog
                                      }

                                      if (filePath != null) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${AppLocalizations.t('video_export_success')}: $filePath',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(
                                              seconds: 4,
                                            ),
                                          ),
                                        );
                                        if (context.mounted) {
                                          navigator
                                              .pop(); // Close timestamps dialog
                                          _showTimestampsLog(); // Refresh list
                                        }
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              AppLocalizations.t(
                                                'video_export_failed',
                                              ),
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                            ),
                            // Delete button
                            IconButton(
                              tooltip: AppLocalizations.t('delete'),
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(
                                      AppLocalizations.t('confirm_delete'),
                                    ),
                                    content: Text(
                                      AppLocalizations.t(
                                        'delete_timestamp_confirm',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          AppLocalizations.t('cancel'),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Text(
                                          AppLocalizations.t('delete'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && ts.id != null) {
                                  await _cctvService.deleteTimestamp(ts.id!);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _showTimestampsLog();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (timestamps.isNotEmpty)
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(AppLocalizations.t('clear_all')),
                    content: Text(
                      AppLocalizations.t('clear_all_timestamps_confirm'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppLocalizations.t('cancel')),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text(AppLocalizations.t('clear_all')),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _cctvService.clearAllTimestamps();
                  if (context.mounted) {
                    navigator.pop();
                  }
                }
              },
              child: Text(AppLocalizations.t('clear_all')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  void _saveTimestampWithDate(DateTime timestamp) async {
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Sale Record Timestamp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sale Time: ${timestamp.toLocal()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Sale transaction recorded',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    final ok = await _cctvService.seekTo(
      timestamp,
      description: result.isEmpty ? null : result,
    );

    if (!mounted || !context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timestamp saved: ${timestamp.toLocal()}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save timestamp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showManualTimestampDialog() async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.access_time_filled),
                  const SizedBox(width: 8),
                  const Text('Manual Timestamp'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Date and Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Date Picker
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Time Picker
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'e.g., Security incident, Important event',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Timestamp'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    // Combine date and time
    final timestamp = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final description = descriptionController.text.trim();
    final ok = await _cctvService.seekTo(
      timestamp,
      description: description.isEmpty ? null : description,
    );

    if (!mounted || !context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timestamp saved: ${timestamp.toLocal()}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save timestamp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCameraTile(Camera camera) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showCameraFullscreen(camera),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Real camera feed
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CameraFeedWidget(
                camera: camera,
                autoPlay: true,
                showControls: false,
              ),
            ),
            // Action buttons
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => _showConfigureCameraDialog(camera),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _showDeleteCameraDialog(camera),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.t('no_cameras'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.t('add_first_camera'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddCameraDialog,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.t('add_camera')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraGrid() {
    final cameras = _cctvService.cameras;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200
                  ? 4
                  : MediaQuery.of(context).size.width > 800
                  ? 3
                  : 2,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCameraTile(cameras[index]),
              childCount: cameras.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenView() {
    if (_fullscreenCamera == null) return const SizedBox();

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Real camera feed
          Center(
            child: CameraFeedWidget(
              camera: _fullscreenCamera!,
              autoPlay: true,
              showControls: true,
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _exitFullscreen,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fullscreenCamera!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _fullscreenCamera!.url,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () =>
                          _showConfigureCameraDialog(_fullscreenCamera!),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreenCamera != null) {
      return Scaffold(body: _buildFullscreenView());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('cctv_monitoring')),
        actions: [
          if (_cctvService.cameras.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCameraDialog,
              tooltip: AppLocalizations.t('add_camera'),
            ),
        ],
      ),
      body: _cctvService.cameras.isEmpty
          ? _buildEmptyState()
          : _buildCameraGrid(),
      floatingActionButton: _cctvService.cameras.isNotEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'manual_timestamp',
                  onPressed: _showManualTimestampDialog,
                  tooltip: 'Manual Timestamp',
                  child: const Icon(Icons.bookmark_add),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'timestamps_log',
                  onPressed: _showTimestampsLog,
                  tooltip: AppLocalizations.t('saved_timestamps'),
                  child: const Icon(Icons.access_time),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: 'add_camera',
                  onPressed: _showAddCameraDialog,
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.t('add_camera')),
                ),
              ],
            )
          : null,
    );
  }
}
