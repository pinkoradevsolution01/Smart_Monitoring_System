import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../utils/app_localizations.dart';
import '../../utils/locale_controller.dart';

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
    // Initialize keys for each section with unique debug labels
    _sectionKeys = List.generate(
      9,
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

    // Multiple frame callbacks to ensure ListView builds off-screen items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Schedule another callback to give ListView time to build items
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final key = _sectionKeys[index];
        final keyContext = key.currentContext;

        if (keyContext != null) {
          try {
            Scrollable.ensureVisible(
              keyContext,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.1,
            );
          } catch (e) {
            debugPrint('Error scrolling to section $index: $e');
          }
        } else {
          // If context still not available, try scrolling to approximate position
          final approximateOffset = index * 400.0; // Rough estimate per section
          _scrollController.animateTo(
            approximateOffset.clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  // Dynamic getter to always fetch current language content
  List<ManualSection> get _sections => [
    ManualSection(
      title: AppLocalizations.t('manual_installation'),
      content: AppLocalizations.t('manual_installation_content'),
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
      title: AppLocalizations.t('manual_add_products'),
      content: AppLocalizations.t('manual_add_products_content'),
    ),
    ManualSection(
      title: AppLocalizations.t('manual_use_pos'),
      content: AppLocalizations.t('manual_use_pos_content'),
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
      title: AppLocalizations.t('manual_common_tasks'),
      content: AppLocalizations.t('manual_common_tasks_content'),
    ),
  ];

  Future<void> _exportToPdf() async {
    if (_isExporting) {
      return; // Prevent double-clicking
    }

    setState(() => _isExporting = true);

    try {
      // Show starting message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating PDF...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final pdf = pw.Document();

      // Load Unicode-compatible font with proper error handling
      pw.Font? font;
      pw.Font? fontBold;

      try {
        // Ensure Flutter bindings are initialized before loading fonts
        WidgetsFlutterBinding.ensureInitialized();
        font = await PdfGoogleFonts.openSansRegular();
        fontBold = await PdfGoogleFonts.openSansBold();
      } catch (e) {
        // Fallback to default fonts if Google fonts fail to load
        // Using default Helvetica font for special characters
      }

      // Text styles with Unicode-compatible font or fallback to default
      final titleStyle = fontBold != null
          ? pw.TextStyle(fontSize: 16, font: fontBold)
          : pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
      final subtitleStyle = fontBold != null
          ? pw.TextStyle(fontSize: 12, font: fontBold)
          : pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
      final headingStyle = fontBold != null
          ? pw.TextStyle(fontSize: 10, font: fontBold)
          : pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
      final normalStyle = font != null
          ? pw.TextStyle(fontSize: 7, font: font, lineSpacing: 1.1)
          : pw.TextStyle(fontSize: 7, lineSpacing: 1.1);
      final smallStyle = font != null
          ? pw.TextStyle(fontSize: 5.5, font: font)
          : pw.TextStyle(fontSize: 5.5);

      // All content in one MultiPage to prevent height issues
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          build: (context) => [
            // Title
            pw.Text(
              'Smart Store Monitoring System - User Manual',
              style: titleStyle,
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Version 1.0 - December 19, 2025',
              style: normalStyle,
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 6),

            // Table of Contents
            pw.Text('Table of Contents', style: subtitleStyle),
            pw.SizedBox(height: 3),
            for (int i = 0; i < _sections.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 1.5),
                child: pw.Text(
                  '${i + 1}. ${_sections[i].title}',
                  style: normalStyle,
                ),
              ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5),

            // All sections
            for (final section in _sections) ...[
              pw.SizedBox(height: 6),
              pw.Text(section.title, style: headingStyle),
              pw.SizedBox(height: 2),
              pw.Text(
                section.content,
                style: normalStyle,
                textAlign: pw.TextAlign.left,
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.3),
            ],

            // Footer
            pw.SizedBox(height: 6),
            pw.Text(
              'Thank you for choosing Smart Store Monitoring System!',
              style: subtitleStyle,
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'For support: support@pinkoradev.com',
              style: normalStyle,
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '© 2025 Pinkora Dev. All rights reserved.',
              style: smallStyle,
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      // Save PDF
      final bytes = await pdf.save();

      // Let user choose where to save the file
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF Manual',
        fileName: 'Smart_Store_User_Manual.pdf',
        allowedExtensions: ['pdf'],
      );

      if (outputPath == null) {
        // User cancelled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Write the PDF file
      final file = File(outputPath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $outputPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () async {
                // Open file location
                final directory = file.parent.path;
                if (Platform.isWindows) {
                  await Process.run('explorer', [directory]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.locale,
      builder: (context, locale, child) {
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.t('user_manual')),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: _isExporting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    tooltip: 'Export to PDF',
                    onPressed: _isExporting ? null : _exportToPdf,
                  ),
                ],
              ),
              body: Row(
                children: [
                  // Left Navigation Menu
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        right: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.menu_book, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Contents',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _sections.length,
                            itemBuilder: (context, index) {
                              final isSelected = _selectedIndex == index;
                              return InkWell(
                                onTap: () => _scrollToSection(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.15)
                                        : null,
                                    border: Border(
                                      left: BorderSide(
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.transparent,
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isSelected
                                            ? primaryColor
                                            : Colors.grey[300],
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _sections[index].title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.chevron_right,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportToPdf,
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download, size: 18),
                              label: Text(
                                _isExporting ? 'Exporting...' : 'Download PDF',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Content Area
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      cacheExtent: 2000,
                      padding: const EdgeInsets.all(24),
                      itemCount: _sections
                          .length, // Pre-render more items for smooth scrolling
                      itemBuilder: (context, index) {
                        final section = _sections[index];
                        return Container(
                          key: _sectionKeys[index],
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: primaryColor
                                            .withValues(alpha: 0.1),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          section.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  SelectableText(
                                    section.content,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isExporting)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 4,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Generating PDF...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please wait while we create your manual',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ManualSection {
  final String title;
  final String content;

  ManualSection({required this.title, required this.content});
}
