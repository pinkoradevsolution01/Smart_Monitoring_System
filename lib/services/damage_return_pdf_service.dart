import 'dart:convert';
import '../utils/currency_formatter.dart';
import 'package:get_it/get_it.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/damage_report.dart';
import '../models/business_info.dart';
import '../services/business_info_service.dart';

class DamageReturnPdfService {
  static Future<void> generateAndPrintPdf(DamageReport report) async {
    final pdf = pw.Document();

    // Get business info
    final businessInfoService = GetIt.I.get<BusinessInfoService>();
    final businessInfo = businessInfoService.businessInfo;

    // Decode signature if available
    pw.ImageProvider? signatureImage;
    if (report.returnSignature != null && report.returnSignature!.isNotEmpty) {
      try {
        final signatureBytes = base64Decode(report.returnSignature!);
        signatureImage = pw.MemoryImage(signatureBytes);
      } catch (e) {
        // If decoding fails, skip signature
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(report, businessInfo),
              pw.SizedBox(height: 30),

              // Report Details
              _buildReportDetails(report),
              pw.SizedBox(height: 30),

              // Damage Information
              _buildDamageInfo(report),
              pw.SizedBox(height: 30),

              // Return Information
              _buildReturnInfo(report),
              pw.SizedBox(height: 20),

              // Approval Section
              pw.Spacer(),
              _buildApprovalSection(report, signatureImage),
            ],
          );
        },
      ),
    );

    // Preview and print
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Damage_Return_${report.id ?? 'Report'}.pdf',
    );
  }

  static pw.Widget _buildHeader(
    DamageReport report,
    BusinessInfo? businessInfo,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DAMAGE RETURN REPORT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  businessInfo?.storeName ?? 'Smart Monitoring System',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (businessInfo?.storeAddress != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    businessInfo!.storeAddress!,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(width: 1, color: PdfColors.red),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Report ID: ${report.id ?? 'N/A'}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Status: ${report.returnStatus?.toUpperCase() ?? 'PENDING'}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.Divider(height: 20, thickness: 2),
      ],
    );
  }

  static pw.Widget _buildReportDetails(DamageReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'REPORT DETAILS',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildDetailRow('Report Date:', _formatDate(report.reportDate)),
          _buildDetailRow('Reported By:', report.reportedBy),
          if (report.returnDate != null)
            _buildDetailRow('Return Date:', _formatDate(report.returnDate!)),
        ],
      ),
    );
  }

  static pw.Widget _buildDamageInfo(DamageReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DAMAGE INFORMATION',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          // Product table
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell('Product', isHeader: true),
                  _tableCell('Quantity', isHeader: true),
                  _tableCell('Unit Price', isHeader: true),
                  _tableCell('Total Value', isHeader: true),
                ],
              ),
              // Data
              pw.TableRow(
                children: [
                  _tableCell(report.productName),
                  _tableCell('${report.quantity}'),
                  _tableCell(AppCurrency.peso(report.unitPrice)),
                  _tableCell(AppCurrency.peso(report.totalValue)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Text(
            'Reason for Damage:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              report.reason,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReturnInfo(DamageReport report) {
    if (report.returnStatus != 'returned') {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.orange50,
          border: pw.Border.all(width: 1, color: PdfColors.orange),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Row(
          children: [
            pw.Icon(
              const pw.IconData(0xe88f), // warning icon
              color: PdfColors.orange,
              size: 20,
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              'This item has not been returned to supplier yet.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(width: 1, color: PdfColors.green),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Icon(
                const pw.IconData(0xe86c), // check_circle icon
                color: PdfColors.green,
                size: 20,
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                'RETURNED TO SUPPLIER',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _buildDetailRow('Return Date:', _formatDate(report.returnDate!)),
          _buildDetailRow('Approved By:', report.returnApprovedBy ?? 'N/A'),
        ],
      ),
    );
  }

  static pw.Widget _buildApprovalSection(
    DamageReport report,
    pw.ImageProvider? signatureImage,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),
        pw.Text(
          'AUTHORIZATION',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 15),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (signatureImage != null) ...[
                    pw.Container(
                      height: 60,
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 1),
                      ),
                      child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 5),
                  ] else
                    pw.Container(
                      height: 60,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1)),
                      ),
                    ),
                  pw.Text(
                    report.returnApprovedBy ?? 'Authorized Signature',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Owner/Manager',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 40),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    height: 60,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 1)),
                    ),
                  ),
                  pw.Text(
                    'Date',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    report.returnDate != null
                        ? _formatDate(report.returnDate!)
                        : '________________',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
