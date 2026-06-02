import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../services/pos_service.dart';
import '../services/business_info_service.dart';
import '../models/sale.dart';
import 'app_localizations.dart';

class ReceiptGenerator {
  static Future<void> generateAndPrint({
    required BuildContext context,
    required POSService pos,
    required String cashierName,
  }) async {
    await pos.loadRecentSales(days: 1);
    if (pos.recentSales.isEmpty) {
      // No recent sale to print; let the caller decide on user feedback.
      return;
    }
    final sale = pos.recentSales.first;

    // Get business information
    final businessInfo = BusinessInfoService().businessInfo;
    final businessName = businessInfo?.storeName ?? 'Smart Store';
    final businessAddress = businessInfo?.storeAddress;

    // Load fonts that support the Peso sign - with fallback
    pw.Font? font;
    pw.Font? fontBold;

    try {
      font = await PdfGoogleFonts.notoSansRegular();
      fontBold = await PdfGoogleFonts.notoSansBold();
    } catch (e) {
      // If Google Fonts fails, we'll use fallback fonts
      debugPrint('Failed to load Google Fonts: $e');
    }

    final pdf = pw.Document();
    final df = DateFormat('yyyy-MM-dd HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          55 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 0 * PdfPageFormat.mm,
        ),
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: pw.EdgeInsets.zero,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (businessAddress != null && businessAddress.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      businessAddress,
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 7)
                          : const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(height: 2),
                pw.Divider(),
                pw.Text(
                  '${AppLocalizations.t('receipt_number')}: ${sale.saleNumber}',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 7)
                      : const pw.TextStyle(fontSize: 7),
                ),
                pw.Text(
                  '${AppLocalizations.t('date')}: ${df.format(sale.saleDate)}',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 7)
                      : const pw.TextStyle(fontSize: 7),
                ),
                pw.Text(
                  '${AppLocalizations.t('cashier')}: $cashierName',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 7)
                      : const pw.TextStyle(fontSize: 7),
                ),
                pw.Text(
                  '${AppLocalizations.t('payment_method')}: ${sale.paymentMethod.toUpperCase()}',
                  style: font != null
                      ? pw.TextStyle(font: font, fontSize: 7)
                      : const pw.TextStyle(fontSize: 7),
                ),
                if (sale.referenceCode != null &&
                    sale.referenceCode!.isNotEmpty)
                  pw.Text(
                    'Reference: ${sale.referenceCode}',
                    style: font != null
                        ? pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          )
                        : pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                  ),
                // Delivery Information
                if (sale.transactionType == TransactionType.delivery) ...[
                  pw.SizedBox(height: 4),
                  pw.Divider(),
                  pw.Text(
                    'DELIVERY ORDER',
                    style: fontBold != null
                        ? pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          )
                        : pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                  ),
                  pw.SizedBox(height: 2),
                  if (sale.notes != null && sale.notes!.isNotEmpty)
                    ..._extractDeliveryInfo(sale.notes!, font),
                  pw.Text(
                    'Status: ${sale.status == SaleStatus.pending ? "RESERVATION (${AppLocalizations.t('pending_payment')})" : AppLocalizations.t('payment_completed')}',
                    style: font != null
                        ? pw.TextStyle(
                            font: fontBold,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          )
                        : pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                  ),
                  if (sale.reservationFee != null &&
                      sale.status == SaleStatus.pending) ...[
                    pw.Text(
                      'Reservation Fee: ₱${sale.reservationFee!.toStringAsFixed(2)}',
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 7)
                          : const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      'Remaining Balance: ₱${(sale.totalAmount - sale.reservationFee!).toStringAsFixed(2)}',
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 7)
                          : const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ],
                pw.SizedBox(height: 4),
                pw.Divider(),
                pw.ListView.builder(
                  itemCount: sale.items.length,
                  itemBuilder: (c, i) {
                    final it = sale.items[i];
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    '${it.productName} x${it.quantity}',
                                    maxLines: 2,
                                    style: font != null
                                        ? pw.TextStyle(font: font, fontSize: 7)
                                        : const pw.TextStyle(fontSize: 7),
                                  ),
                                  if (it.shoeSize != null)
                                    pw.Text(
                                      '  (Size: ${it.shoeSize})',
                                      style: font != null
                                          ? pw.TextStyle(
                                              font: font,
                                              fontSize: 6,
                                              color: PdfColors.grey700,
                                            )
                                          : pw.TextStyle(
                                              fontSize: 6,
                                              color: PdfColors.grey700,
                                            ),
                                    ),
                                ],
                              ),
                            ),
                            pw.Container(
                              width: 12 * PdfPageFormat.mm,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                'PHP ${it.subtotal.toStringAsFixed(2)}',
                                style: font != null
                                    ? pw.TextStyle(font: font, fontSize: 8)
                                    : const pw.TextStyle(fontSize: 8),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 1),
                      ],
                    );
                  },
                ),
                pw.Divider(),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${AppLocalizations.t('subtotal')}:',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 8)
                            : const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.Container(
                      width: 14 * PdfPageFormat.mm,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '₱${sale.subtotal.toStringAsFixed(2)}',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 8)
                            : const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${AppLocalizations.t('discount')}:',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 8)
                            : const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.Container(
                      width: 14 * PdfPageFormat.mm,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '-₱${(sale.subtotal - sale.totalAmount).toStringAsFixed(2)}',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 8)
                            : const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${AppLocalizations.t('grand_total')}:',
                        style: fontBold != null
                            ? pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              )
                            : pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                      ),
                    ),
                    pw.Container(
                      width: 14 * PdfPageFormat.mm,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '₱${sale.totalAmount.toStringAsFixed(2)}',
                        style: fontBold != null
                            ? pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              )
                            : pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    AppLocalizations.t('thank_you'),
                    style: font != null
                        ? pw.TextStyle(font: font, fontSize: 8)
                        : const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final receiptFormat = PdfPageFormat(
      55 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 0 * PdfPageFormat.mm,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      format: receiptFormat,
    );
  }

  static Future<Uint8List> buildPdfBytes({
    required POSService pos,
    required String cashierName,
    PdfPageFormat? pageFormat,
  }) async {
    await pos.loadRecentSales(days: 1);
    if (pos.recentSales.isEmpty) {
      return Uint8List.fromList(<int>[]);
    }
    final sale = pos.recentSales.first;

    final businessInfo = BusinessInfoService().businessInfo;
    final businessName = businessInfo?.storeName ?? 'Smart Store';
    final businessAddress = businessInfo?.storeAddress;

    pw.Font? font;
    pw.Font? fontBold;
    try {
      font = await PdfGoogleFonts.notoSansRegular();
      fontBold = await PdfGoogleFonts.notoSansBold();
    } catch (_) {}

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat:
            pageFormat ??
            PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 0),
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: pw.EdgeInsets.zero,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    businessName,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (businessAddress != null && businessAddress.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      businessAddress,
                      style: font != null
                          ? pw.TextStyle(font: font, fontSize: 8)
                          : const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Divider(),
                pw.Text(
                  '${AppLocalizations.t('receipt_number')}: ${sale.saleNumber}',
                  style: font != null ? pw.TextStyle(font: font) : null,
                ),
                pw.Text(
                  '${AppLocalizations.t('date')}: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.saleDate)}',
                  style: font != null ? pw.TextStyle(font: font) : null,
                ),
                pw.Text(
                  '${AppLocalizations.t('cashier')}: $cashierName',
                  style: font != null ? pw.TextStyle(font: font) : null,
                ),
                pw.Text(
                  '${AppLocalizations.t('payment_method')}: ${sale.paymentMethod.toUpperCase()}',
                  style: font != null ? pw.TextStyle(font: font) : null,
                ),
                // Delivery Information
                if (sale.transactionType == TransactionType.delivery) ...[
                  pw.SizedBox(height: 4),
                  pw.Divider(),
                  pw.Text(
                    'DELIVERY ORDER',
                    style: fontBold != null
                        ? pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          )
                        : pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                  ),
                  pw.SizedBox(height: 2),
                  if (sale.notes != null && sale.notes!.isNotEmpty)
                    ..._extractDeliveryInfo(sale.notes!, font),
                  pw.Text(
                    'Status: ${sale.status == SaleStatus.pending ? "RESERVATION (${AppLocalizations.t('pending_payment')})" : AppLocalizations.t('payment_completed')}',
                    style: font != null
                        ? pw.TextStyle(
                            font: fontBold,
                            fontWeight: pw.FontWeight.bold,
                          )
                        : pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if (sale.reservationFee != null &&
                      sale.status == SaleStatus.pending) ...[
                    pw.Text(
                      'Reservation Fee: ₱${sale.reservationFee!.toStringAsFixed(2)}',
                      style: font != null ? pw.TextStyle(font: font) : null,
                    ),
                    pw.Text(
                      'Remaining Balance: ₱${(sale.totalAmount - sale.reservationFee!).toStringAsFixed(2)}',
                      style: font != null ? pw.TextStyle(font: font) : null,
                    ),
                  ],
                ],
                pw.SizedBox(height: 6),
                pw.Divider(),
                pw.Column(
                  children: sale.items.map((it) {
                    return pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${it.productName} x${it.quantity}',
                                maxLines: 2,
                                style: font != null
                                    ? pw.TextStyle(font: font, fontSize: 7)
                                    : const pw.TextStyle(fontSize: 7),
                              ),
                              if (it.shoeSize != null)
                                pw.Text(
                                  '  (Size: ${it.shoeSize})',
                                  style: font != null
                                      ? pw.TextStyle(
                                          font: font,
                                          fontSize: 7,
                                          color: PdfColors.grey700,
                                        )
                                      : pw.TextStyle(
                                          fontSize: 7,
                                          color: PdfColors.grey700,
                                        ),
                                ),
                            ],
                          ),
                        ),
                        pw.Container(
                          width: 12 * PdfPageFormat.mm,
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            '₱${it.subtotal.toStringAsFixed(2)}',
                            style: font != null
                                ? pw.TextStyle(font: font, fontSize: 8)
                                : const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                pw.Divider(),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${AppLocalizations.t('subtotal')}:',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 8)
                            : const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.Container(
                      width: 14 * PdfPageFormat.mm,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '₱${sale.subtotal.toStringAsFixed(2)}',
                        style: font != null
                            ? pw.TextStyle(font: font, fontSize: 8)
                            : const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${AppLocalizations.t('grand_total')}:',
                        style: fontBold != null
                            ? pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              )
                            : pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                      ),
                    ),
                    pw.Container(
                      width: 14 * PdfPageFormat.mm,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '₱${sale.totalAmount.toStringAsFixed(2)}',
                        style: fontBold != null
                            ? pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              )
                            : pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    AppLocalizations.t('thank_you'),
                    style: font != null
                        ? pw.TextStyle(font: font, fontSize: 9)
                        : const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Helper method to extract delivery information from sale notes
  static List<pw.Widget> _extractDeliveryInfo(String notes, pw.Font? font) {
    final widgets = <pw.Widget>[];
    final lines = notes.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty || line.trim() == 'DELIVERY ORDER') continue;

      widgets.add(
        pw.Text(
          line.trim(),
          style: font != null
              ? pw.TextStyle(font: font, fontSize: 7)
              : const pw.TextStyle(fontSize: 7),
        ),
      );
    }

    if (widgets.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 2));
    }

    return widgets;
  }
}
