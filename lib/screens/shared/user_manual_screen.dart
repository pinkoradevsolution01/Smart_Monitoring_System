import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
// 'dart:typed_data' not required; provided by other imports
import '../../utils/app_localizations.dart';

class UserManualScreen extends StatefulWidget {
  const UserManualScreen({super.key});

  @override
  State<UserManualScreen> createState() => _UserManualScreenState();
}

class _UserManualScreenState extends State<UserManualScreen> {
  bool _isExporting = false;
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _sectionKeys;

  @override
  void initState() {
    super.initState();
    _sectionKeys = List.generate(
      11, // Updated to 11 sections
      (index) => GlobalKey(debugLabel: 'section_$index'),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(int index) {
    setState(() => _selectedIndex = index);

    // Wait for the UI to update before scrolling
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      final key = _sectionKeys[index];
      final keyContext = key.currentContext;

      if (keyContext != null) {
        try {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            alignment: 0.0,
          );
        } catch (e) {
          debugPrint('Error scrolling to section $index: $e');
        }
      }
    });
  }

  List<ManualSection> get _sections => [
    ManualSection(
      title: AppLocalizations.t('manual_installation'),
      content: AppLocalizations.t('manual_installation_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_getting_started'),
      content: AppLocalizations.t('manual_getting_started_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_roles'),
      content: AppLocalizations.t('manual_roles_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_create_admin'),
      content: AppLocalizations.t('manual_create_admin_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_admin_features'),
      content: AppLocalizations.t('manual_admin_features_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_owner_features'),
      content: AppLocalizations.t('manual_owner_features_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_cashier_features'),
      content: AppLocalizations.t('manual_cashier_features_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_backup'),
      content: AppLocalizations.t('manual_backup_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_quick_start'),
      content: AppLocalizations.t('manual_quick_start_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_troubleshooting'),
      content: AppLocalizations.t('manual_troubleshooting_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_support'),
      content: AppLocalizations.t('manual_support_content'),
    ),
  ];

  Future<void> _exportToPdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('generating_pdf')),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final pdf = pw.Document();
      pw.Font? font;
      pw.Font? fontBold;

      try {
        WidgetsFlutterBinding.ensureInitialized();
        font = await PdfGoogleFonts.openSansRegular();
        fontBold = await PdfGoogleFonts.openSansBold();
      } catch (e) {
        debugPrint('Font loading error: $e');
      }

      final headingStyle = fontBold != null
          ? pw.TextStyle(fontSize: 11, font: fontBold)
          : pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);
      final normalStyle = font != null
          ? pw.TextStyle(fontSize: 9, font: font, lineSpacing: 1.2)
          : pw.TextStyle(fontSize: 9, lineSpacing: 1.2);
      final smallStyle = font != null
          ? pw.TextStyle(fontSize: 7, font: font)
          : pw.TextStyle(fontSize: 7);
      final titleStyle = fontBold != null
          ? pw.TextStyle(fontSize: 20, font: fontBold)
          : pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold);
      final subtitleStyle = fontBold != null
          ? pw.TextStyle(fontSize: 14, font: fontBold)
          : pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            final List<pw.Widget> content = [];

            // Title page
            content.addAll([
              pw.Text(
                'Smart Store Monitoring System',
                style: titleStyle,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'User Manual',
                style: subtitleStyle,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Version 1.0 - December 19, 2025',
                style: normalStyle,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),
            ]);

            // Table of Contents
            content.add(pw.Text('Table of Contents', style: subtitleStyle));
            content.add(pw.SizedBox(height: 5));
            for (int i = 0; i < _sections.length; i++) {
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(_sections[i].title, style: normalStyle),
                ),
              );
            }
            content.add(pw.SizedBox(height: 15));
            content.add(pw.Divider(thickness: 0.5));
            content.add(pw.SizedBox(height: 10));

            // Sections
            for (final section in _sections) {
              content.add(pw.Text(section.title, style: headingStyle));
              content.add(pw.SizedBox(height: 5));

              final lines = section.content.split('\n');
              for (final line in lines) {
                if (line.trim().isEmpty) {
                  content.add(pw.SizedBox(height: 3));
                } else {
                  content.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(line, style: normalStyle),
                    ),
                  );
                }
              }
              content.add(pw.SizedBox(height: 10));
              content.add(pw.Divider(thickness: 0.3));
              content.add(pw.SizedBox(height: 8));
            }

            // Footer
            content.addAll([
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 5),
              pw.Text(
                'Copyright © 2025 Pinkora Dev. All rights reserved.',
                style: smallStyle,
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Smart Store Monitoring System',
                style: smallStyle,
                textAlign: pw.TextAlign.center,
              ),
            ]);

            return content;
          },
        ),
      );

      if (!mounted) return;

      // Platform-specific file saving
      final bool isMobilePlatform =
          !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      String? savedPath;

      if (isMobilePlatform) {
        // Mobile: Save to Downloads directory
        try {
          Directory? directory;

          if (Platform.isAndroid) {
            // Try multiple possible Downloads locations for Android
            final possiblePaths = [
              '/storage/emulated/0/Download',
              '/storage/emulated/0/Downloads',
              '/sdcard/Download',
              '/sdcard/Downloads',
            ];

            for (final path in possiblePaths) {
              final dir = Directory(path);
              if (await dir.exists()) {
                directory = dir;
                break;
              }
            }

            // If no Downloads folder found, create it
            if (directory == null) {
              directory = Directory('/storage/emulated/0/Download');
              try {
                await directory.create(recursive: true);
              } catch (e) {
                debugPrint('Could not create Downloads folder: $e');
                // Fallback to external storage directory
                directory = await getExternalStorageDirectory();
              }
            }
          } else if (Platform.isIOS) {
            // For iOS, use documents directory
            directory = await getApplicationDocumentsDirectory();
          }

          if (directory != null) {
            final fileName =
                'smart_store_user_manual_${DateTime.now().millisecondsSinceEpoch}.pdf';
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(await pdf.save());
            savedPath = filePath;
          }
        } catch (e) {
          debugPrint('Mobile save error: $e');
          // Fallback: try app documents directory
          final directory = await getApplicationDocumentsDirectory();
          final fileName =
              'smart_store_user_manual_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(await pdf.save());
          savedPath = filePath;
        }
      } else {
        // Desktop: Use file picker
        final result = await FilePicker.saveFile(
          dialogTitle: 'Save User Manual PDF',
          fileName:
              'smart_store_user_manual_${DateTime.now().millisecondsSinceEpoch}.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: Uint8List.fromList(await pdf.save()),
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsBytes(await pdf.save());
          savedPath = result;
        }
      }

      if (savedPath != null && mounted) {
        // Extract just the filename for mobile display
        final fileName = savedPath.split('/').last;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMobilePlatform
                            ? 'PDF saved successfully!'
                            : AppLocalizations.t(
                                'pdf_exported_to',
                              ).replaceAll('{path}', savedPath),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (isMobilePlatform) ...[
                  SizedBox(height: 8),
                  Text(
                    'Location: Downloads folder',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    'File: $fileName',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Open your Files app → Downloads to view',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: isMobilePlatform ? 8 : 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.t('export_failed').replaceAll('{error}', '$e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  List<IconData> get _sectionIcons => [
    Icons.download,
    Icons.rocket_launch,
    Icons.people,
    Icons.admin_panel_settings,
    Icons.settings,
    Icons.store,
    Icons.point_of_sale,
    Icons.backup,
    Icons.flash_on,
    Icons.help_outline,
    Icons.support_agent,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: isDark ? null : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          AppLocalizations.t('user_manual'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: _isExporting ? null : _exportToPdf,
              icon: _isExporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.picture_as_pdf),
              tooltip: AppLocalizations.t('export_pdf'),
              iconSize: 24,
            ),
          ),
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showMobileMenu(context, isDark),
              tooltip: AppLocalizations.t('contents'),
              child: Icon(Icons.menu_book),
            )
          : null,
      body: Row(
        children: [
          // Left sidebar - Section navigation (Desktop only)
          if (!isMobile)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: _buildNavigationMenu(isDark),
            ),
          // Right side - Content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Column(
                children: List.generate(_sections.length, (index) {
                  final section = _sections[index];
                  return Container(
                    key: _sectionKeys[index],
                    margin: EdgeInsets.only(bottom: isMobile ? 16 : 32),
                    child: Card(
                      elevation: isDark ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section header with icon
                          Container(
                            padding: EdgeInsets.all(isMobile ? 16 : 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _sectionIcons[index],
                                    color: Colors.white,
                                    size: isMobile ? 20 : 28,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Text(
                                    section.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontSize: isMobile ? 16 : null,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Content
                          Padding(
                            padding: EdgeInsets.all(isMobile ? 16 : 24),
                            child: SelectableText(
                              section.content,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    height: 1.6,
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMenu(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.library_books,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.t('contents'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      AppLocalizations.t(
                        'sections_count',
                      ).replaceAll('{n}', '${_sections.length}'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                ),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : isDark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _sectionIcons[index],
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    _sections[index].title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => _scrollToSection(index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMobileMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.library_books,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.t('contents'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          AppLocalizations.t(
                            'sections_count',
                          ).replaceAll('{n}', '${_sections.length}'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Menu list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _sections.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : isDark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _sectionIcons[index],
                          size: 20,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        _sections[index].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToSection(index);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManualSection {
  final String title;
  final String content;

  ManualSection({required this.title, required this.content});
}
