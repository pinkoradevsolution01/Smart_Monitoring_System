import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../models/business_info.dart';
import '../services/business_info_service.dart';

class PurchaseOrderPdfService {
  static Future<void> generateAndPrintPdf(
    PurchaseOrder order,
    Supplier supplier,
  ) async {
    final pdf = pw.Document();

    // Get business info
    final businessInfoService = GetIt.I.get<BusinessInfoService>();
    final businessInfo = businessInfoService.businessInfo;

    // Decode signature if available
    pw.ImageProvider? signatureImage;
    if (order.signatureData != null && order.signatureData!.isNotEmpty) {
      try {
        final signatureBytes = base64Decode(order.signatureData!);
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
              _buildHeader(order, businessInfo),
              pw.SizedBox(height: 20),

              // Supplier Info
              _buildSupplierInfo(supplier),
              pw.SizedBox(height: 20),

              // Order Info
              _buildOrderInfo(order),
              pw.SizedBox(height: 20),

              // Items Table
              _buildItemsTable(order.items),
              pw.SizedBox(height: 20),

              // Total
              _buildTotal(order.totalAmount),
              pw.SizedBox(height: 20),

              // Notes
              if (order.notes.isNotEmpty) ...[
                _buildNotes(order.notes),
                pw.SizedBox(height: 20),
              ],

              // Approval Section
              pw.Spacer(),
              _buildApprovalSection(order, signatureImage),
            ],
          );
        },
      ),
    );

    // Preview and print
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: '${order.orderNumber}.pdf',
    );
  }

  static pw.Widget _buildHeader(
    PurchaseOrder order,
    BusinessInfo? businessInfo,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PURCHASE ORDER',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              businessInfo?.storeName ?? 'Smart Monitoring System',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
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
            border: pw.Border.all(width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Order #: ${order.orderNumber}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Date: ${_formatDate(order.orderDate)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (order.expectedDeliveryDate != null)
                pw.Text(
                  'Expected: ${_formatDate(order.expectedDeliveryDate!)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSupplierInfo(Supplier supplier) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUPPLIER INFORMATION',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Name: ${supplier.name}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Contact: ${supplier.contactPerson}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Phone: ${supplier.phone}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (supplier.email.isNotEmpty)
            pw.Text(
              'Email: ${supplier.email}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (supplier.address.isNotEmpty)
            pw.Text(
              'Address: ${supplier.address}',
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildOrderInfo(PurchaseOrder order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Status: ${order.status.toUpperCase()}',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _getStatusColor(order.status),
          ),
        ),
        if (order.approvedBy != null)
          pw.Text(
            'Approved by: ${order.approvedBy}',
            style: const pw.TextStyle(fontSize: 10),
          ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(List<PurchaseOrderItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('#', isHeader: true),
            _buildTableCell('Product', isHeader: true),
            _buildTableCell('Quantity', isHeader: true),
            _buildTableCell('Unit Price', isHeader: true),
            _buildTableCell('Total', isHeader: true),
          ],
        ),
        // Items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _buildTableCell('${index + 1}'),
              _buildTableCell(item.productName),
              _buildTableCell('${item.quantity}'),
              _buildTableCell('₱${item.unitPrice.toStringAsFixed(2)}'),
              _buildTableCell('₱${item.totalPrice.toStringAsFixed(2)}'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildTotal(double totalAmount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1),
            color: PdfColors.grey200,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'TOTAL AMOUNT',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '₱${totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNotes(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildApprovalSection(
    PurchaseOrder order,
    pw.ImageProvider? signatureImage,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Prepared by
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 150,
              height: 50,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 1)),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text('Prepared By', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),

        // Approved by with signature
        if ((order.status == 'approved' ||
                order.status == 'completed' ||
                order.status == 'received') &&
            signatureImage != null)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 150,
                height: 50,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey),
                ),
                child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Approved By: ${order.approvedBy}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (order.approvalDate != null)
                pw.Text(
                  _formatDate(order.approvalDate!),
                  style: const pw.TextStyle(fontSize: 8),
                ),
            ],
          )
        else
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 150,
                height: 50,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 1)),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Approved By', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PdfColors.orange;
      case 'approved':
        return PdfColors.green;
      case 'completed':
        return PdfColors.blue;
      case 'received':
        return PdfColors.purple;
      case 'cancelled':
        return PdfColors.red;
      default:
        return PdfColors.black;
    }
  }
}
