import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../utils/print_settings.dart';

class EWalletReceiptPreviewScreen extends StatefulWidget {
  final String cashierName;
  final String transactionType; // 'cash_in' or 'cash_out'
  final double amount;
  final double tendered;
  final double fee;
  final double totalWithFee;
  final String? reference;
  final String? capturedImagePath;
  final bool showPrintDialogOnOpen;

  const EWalletReceiptPreviewScreen({
    super.key,
    required this.cashierName,
    required this.transactionType,
    required this.amount,
    required this.tendered,
    required this.fee,
    required this.totalWithFee,
    this.reference,
    this.capturedImagePath,
    this.showPrintDialogOnOpen = false,
  });

  @override
  State<EWalletReceiptPreviewScreen> createState() =>
      _EWalletReceiptPreviewScreenState();
}

class _EWalletReceiptPreviewScreenState
    extends State<EWalletReceiptPreviewScreen> {
  late String _selectedFormatKey;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    // Initialize print settings and subscribe for live updates
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
          Navigator.of(ctx).pop();
          await _doPrint(pageFormat);
        }

        return AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Print Receipt')),
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
        );
      },
    );

    if (!mounted) return;
    if (result == false || result == null) Navigator.of(context).pop(false);
  }

  Future<void> _doPrint(PdfPageFormat pageFormat) async {
    try {
      final Uint8List bytes = await _buildPdfBytes(pageFormat);
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

  Future<Uint8List> _buildPdfBytes(PdfPageFormat pageFormat) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    pw.Font? font;
    pw.Font? fontBold;
    // Leave fonts null to use default PDF fonts (avoid external dependency)

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'E-Wallet Transfer',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  widget.transactionType == 'cash_in' ? 'CASH-IN' : 'CASH-OUT',
                  style: pw.TextStyle(font: fontBold, fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.Text(
                'Reference: EWT${now.millisecondsSinceEpoch}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                'Date: ${df.format(now)}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.Text(
                'Cashier: ${widget.cashierName}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              if (widget.reference != null && widget.reference!.isNotEmpty)
                pw.Text(
                  'Customer Ref: ${widget.reference}',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Transfer Amount:',
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                  pw.Text(
                    'PHP ${widget.amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Transfer Fee:',
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                  pw.Text(
                    'PHP ${widget.fee.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount:',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'PHP ${widget.totalWithFee.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (widget.transactionType == 'cash_in')
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Cash Tendered:',
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                    pw.Text(
                      'PHP ${widget.tendered.toStringAsFixed(2)}',
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                  ],
                ),
              if (widget.capturedImagePath != null)
                pw.Text(
                  '✓ Receipt Captured',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Thank you!',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    return Uint8List.fromList(bytes);
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

  double previewWidthForFormat(PdfPageFormat fmt) {
    final points = fmt.width;
    if (points.isInfinite || points.isNaN) return 600;
    final px = points * 4.0 / 3.0;
    return px.clamp(240.0, 1200.0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt Preview')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pageFormat = _formatForKey(_selectedFormatKey);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print),
            onPressed: () => _doPrint(pageFormat),
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
                final previewWidth = (constraints.maxWidth * 0.85).clamp(
                  240.0,
                  targetWidth,
                );
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
                          build: (format) => _buildPdfBytes(format),
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
