import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import '../../utils/receipt_generator.dart';
import '../../services/pos_service.dart';
import '../../utils/print_settings.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final POSService pos;
  final String cashierName;
  final bool showPrintDialogOnOpen;

  const ReceiptPreviewScreen({
    super.key,
    required this.pos,
    required this.cashierName,
    this.showPrintDialogOnOpen = false,
  });

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  late String _selectedFormatKey;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    // Initialize shared print settings and subscribe for live updates
    PrintSettings.loadFromPrefs()
        .then((_) {
          if (mounted) {
            setState(() {
              _selectedFormatKey = PrintSettings.paperSize.value;
              _prefsLoaded = true;
            });
          }
        })
        .whenComplete(() {
          if (widget.showPrintDialogOnOpen) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _showPrintDialog(),
            );
          }
        });

    PrintSettings.paperSize.addListener(_onPaperSizeChanged);
  }

  void _onPaperSizeChanged() {
    if (!mounted) return;
    setState(() {
      _selectedFormatKey = PrintSettings.paperSize.value;
    });
  }

  Future<void> _showPrintDialog() async {
    final pageFormat = _formatForKey(_selectedFormatKey);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future<void> printNow() async {
          Navigator.of(ctx).pop(); // close dialog while printing
          await _doPrint(pageFormat);
        }

        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<Intent>(
                onInvoke: (intent) => printNow(),
              ),
              DismissIntent: CallbackAction<Intent>(
                onInvoke: (intent) => Navigator.of(ctx).pop(false),
              ),
            },
            child: AlertDialog(
              title: Row(
                children: [
                  Expanded(child: Text('Print Receipt')),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
              content: const Text('Would you like to print the receipt now?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(onPressed: printNow, child: const Text('Print')),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    // If user cancelled (false or null) then close preview and return false
    if (result == false || result == null) Navigator.of(context).pop(false);
  }

  Future<void> _doPrint(PdfPageFormat pageFormat) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final bytes = await ReceiptGenerator.buildPdfBytes(
        pos: widget.pos,
        cashierName: widget.cashierName,
        pageFormat: pageFormat,
      );
      if (bytes.isEmpty) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        format: pageFormat,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Print failed: ${e.toString()}')));
    }
  }

  Future<void> _handlePrintAndClose(PdfPageFormat pageFormat) async {
    await _doPrint(pageFormat);
  }

  PdfPageFormat _formatForKey(String key) {
    switch (key) {
      case 'A4':
        return PdfPageFormat.a4;
      case 'Letter':
        return PdfPageFormat.letter;
      case 'Thermal 50mm':
        return PdfPageFormat(
          50 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 0,
        );
      case 'Thermal 48mm':
        return PdfPageFormat(
          48 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 0,
        );
      case 'Thermal 58mm':
        return PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 0,
        );
      case 'Thermal 55mm':
      default:
        return PdfPageFormat(
          55 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return Scaffold(
        appBar: AppBar(title: Text('Receipt Preview')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pageFormat = _formatForKey(_selectedFormatKey);
    double previewWidthForFormat(PdfPageFormat fmt) {
      // Convert PDF points to approximate logical pixels: px = points * 4/3
      // Then clamp to reasonable min/max so preview doesn't over-zoom.
      final points = fmt.width;
      if (points.isInfinite || points.isNaN) return 600;
      final px = points * 4.0 / 3.0;
      return px.clamp(240.0, 1200.0);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt Preview'),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print),
            onPressed: () => _handlePrintAndClose(pageFormat),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Page Size:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedFormatKey,
                  items:
                      <String>[
                            'A4',
                            'Letter',
                            'Thermal 48mm',
                            'Thermal 50mm',
                            'Thermal 55mm',
                            'Thermal 58mm',
                          ]
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedFormatKey = v);
                  },
                ),
                const Spacer(),
                Text(
                  _selectedFormatKey.contains('Thermal')
                      ? 'Width: ${(_formatForKey(_selectedFormatKey).width / PdfPageFormat.mm).toStringAsFixed(0)} mm'
                      : '',
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final targetWidth = previewWidthForFormat(pageFormat);
                // use up to 85% of available width but not larger than target
                final previewWidth = (constraints.maxWidth * 0.85).clamp(
                  240.0,
                  targetWidth,
                );
                // Give the preview a finite height (fraction of available height)
                final previewHeight = (constraints.maxHeight * 0.9).clamp(
                  200.0,
                  1600.0,
                );
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: previewWidth,
                      maxHeight: previewHeight,
                    ),
                    child: Card(
                      elevation: 2,
                      clipBehavior: Clip.hardEdge,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: PdfPreview(
                          initialPageFormat: pageFormat,
                          build: (format) async {
                            return await ReceiptGenerator.buildPdfBytes(
                              pos: widget.pos,
                              cashierName: widget.cashierName,
                              pageFormat: pageFormat,
                            );
                          },
                          allowPrinting: true,
                          allowSharing: true,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    PrintSettings.paperSize.removeListener(_onPaperSizeChanged);
    super.dispose();
  }
}
