import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/backend_api_service.dart';

class ActivationCodeGeneratorScreen extends StatefulWidget {
  const ActivationCodeGeneratorScreen({super.key});

  @override
  State<ActivationCodeGeneratorScreen> createState() =>
      _ActivationCodeGeneratorScreenState();
}

class _ActivationCodeGeneratorScreenState
    extends State<ActivationCodeGeneratorScreen> {
  final List<ActivationCode> _generatedCodes = [];
  bool _isGenerating = false;
  String _selectedPackage = 'Basic';
  final List<String> _packages = ['Basic', 'Standard', 'Premium'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎟️ Activation Code Generator'),
        backgroundColor: Colors.grey[900],
        actions: [
          if (_generatedCodes.isNotEmpty)
            IconButton(
              tooltip: 'Export All to CSV',
              icon: const Icon(Icons.file_download),
              onPressed: _exportAllToCSV,
            ),
            if (_generatedCodes.isNotEmpty)
              IconButton(
                tooltip: 'Store to Backend',
                icon: const Icon(Icons.cloud_upload),
                onPressed: _storeCodesToBackend,
              ),
          if (_generatedCodes.isNotEmpty)
            IconButton(
              tooltip: 'Clear All',
              icon: const Icon(Icons.delete_sweep),
              onPressed: _showClearAllDialog,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.grey[800]!],
          ),
        ),
        child: Column(
          children: [
            // Generator Controls
            _buildGeneratorControls(),

            // Statistics
            _buildStatistics(),

            // Generated Codes List
            Expanded(
              child: _generatedCodes.isEmpty
                  ? _buildEmptyState()
                  : _buildCodesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratorControls() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.grey[850],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Text(
                  'Code Generator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Package Selection
            const Text(
              'Select Package',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPackage,
                  isExpanded: true,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _packages.map((package) {
                    return DropdownMenuItem(
                      value: package,
                      child: Row(
                        children: [
                          Icon(
                            _getPackageIcon(package),
                            color: _getPackageColor(package),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(package),
                          const SizedBox(width: 8),
                          Text(
                            _getPackagePrice(package),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPackage = value!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Generate Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _generateCodes(1),
                    icon: const Icon(Icons.add),
                    label: const Text('Generate 1'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _generateCodes(100),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate 100'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final basicCount = _generatedCodes
        .where((c) => c.packageName == 'Basic')
        .length;
    final standardCount = _generatedCodes
        .where((c) => c.packageName == 'Standard')
        .length;
    final premiumCount = _generatedCodes
        .where((c) => c.packageName == 'Premium')
        .length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', _generatedCodes.length, Colors.white),
            _buildStatItem('Basic', basicCount, Colors.blue),
            _buildStatItem('Standard', standardCount, Colors.orange),
            _buildStatItem('Premium', premiumCount, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, size: 100, color: Colors.grey[700]),
          const SizedBox(height: 20),
          Text(
            'No codes generated yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate codes for your packages above',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCodesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _generatedCodes.length,
      itemBuilder: (context, index) {
        final code = _generatedCodes[index];
        return Card(
          color: Colors.grey[850],
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getPackageColor(
                  code.packageName,
                ).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getPackageIcon(code.packageName),
                color: _getPackageColor(code.packageName),
                size: 24,
              ),
            ),
            title: Text(
              code.code,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${code.packageName} - ${code.status}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blue),
                  tooltip: 'Copy Code',
                  onPressed: () => _copyCode(code.code),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _deleteCode(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _generateCodes(int count) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      for (int i = 0; i < count; i++) {
        final code = _generateRandomCode();
        _generatedCodes.add(
          ActivationCode(
            code: code,
            packageName: _selectedPackage,
            status: 'unused',
          ),
        );

        // Update UI every 10 codes for better UX
        if (i % 10 == 0) {
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Generated $count codes for $_selectedPackage'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating codes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _storeCodesToBackend() async {
    if (_generatedCodes.isEmpty) return;

    setState(() => _isGenerating = true);
    final api = ApiClient();

    try {
      // Prepare payload
      final codesPayload = _generatedCodes
          .map((c) => {
                'code': c.code,
                'package_name': c.packageName,
                'status': c.status,
              })
          .toList();

      final body = {'codes': codesPayload};

      final resp = await api.post('license/codes', body: body);

      // Expect backend to return success flag
      if (resp['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Stored ${_generatedCodes.length} codes to backend'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Optionally clear local list after successful store
        setState(() => _generatedCodes.clear());
      } else {
        throw Exception('Unexpected server response: $resp');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to store codes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();

    // Generate unique code (20 characters)
    String code;
    do {
      code = List.generate(
        20,
        (index) => chars[random.nextInt(chars.length)],
      ).join();
    } while (_generatedCodes.any((c) => c.code == code));

    return code;
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteCode(int index) {
    setState(() {
      _generatedCodes.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Code deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          '⚠️ Clear All Codes?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will delete all ${_generatedCodes.length} generated codes. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _generatedCodes.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ All codes cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAllToCSV() async {
    if (_generatedCodes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No codes to export')));
      return;
    }

    try {
      // Generate CSV content
      final csvContent = _generateCSV();

      String filePath;

      // For Windows/Desktop, save to Documents folder
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/activation_codes_import.csv';

        // Write file
        final file = File(filePath);
        await file.writeAsString(csvContent);

        if (mounted) {
          // Show success with file location
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[850],
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Export Successful',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exported ${_generatedCodes.length} activation codes to:',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      filePath,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You can now import this CSV file to Supabase.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: filePath));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 File path copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Copy Path'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // For mobile, use temporary directory and share
        final directory = await getTemporaryDirectory();
        filePath = '${directory.path}/activation_codes_import.csv';

        // Write file
        final file = File(filePath);
        await file.writeAsString(csvContent);

        // Share file
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Activation Codes Export',
          text:
              'Generated ${_generatedCodes.length} activation codes for Smart Monitoring System',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📤 Exported ${_generatedCodes.length} codes to CSV',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _generateCSV() {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('code,package_name,status');

    // CSV Data
    for (final code in _generatedCodes) {
      buffer.writeln('${code.code},${code.packageName},${code.status}');
    }

    return buffer.toString();
  }

  IconData _getPackageIcon(String package) {
    switch (package) {
      case 'Basic':
        return Icons.star_border;
      case 'Standard':
        return Icons.star_half;
      case 'Premium':
        return Icons.star;
      default:
        return Icons.card_giftcard;
    }
  }

  Color _getPackageColor(String package) {
    switch (package) {
      case 'Basic':
        return Colors.blue;
      case 'Standard':
        return Colors.orange;
      case 'Premium':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPackagePrice(String package) {
    switch (package) {
      case 'Basic':
        return '₱1,799/mo';
      case 'Standard':
        return '₱3,799/mo';
      case 'Premium':
        return '₱6,799/mo';
      default:
        return '';
    }
  }
}

class ActivationCode {
  final String code;
  final String packageName;
  final String status;

  ActivationCode({
    required this.code,
    required this.packageName,
    required this.status,
  });
}
