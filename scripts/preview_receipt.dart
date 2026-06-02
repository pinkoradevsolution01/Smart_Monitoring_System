import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final pdf = pw.Document();

  final items = [
    {
      'name': 'Long Product Name Example That Might Wrap',
      'qty': 2,
      'price': 199.99,
    },
    {'name': 'Socks', 'qty': 1, 'price': 49.50},
    {'name': 'Shoelaces Extra Long', 'qty': 3, 'price': 25.00},
  ];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        58 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 0,
      ),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Smart Store',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text('123 Market St, City', style: pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Receipt #0001', style: pw.TextStyle(fontSize: 9)),
            ),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                '2026-01-27 15:30',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Column(
              children: items.map((it) {
                return pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "${it['name']} x${it['qty']}",
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 16 * PdfPageFormat.mm,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        "PHP ${((it['price'] as double) * (it['qty'] as int)).toStringAsFixed(2)}",
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 9)),
                pw.Text('PHP 500.00', style: pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Grand Total:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'PHP 500.00',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text('Thank you', style: pw.TextStyle(fontSize: 9)),
            ),
          ],
        );
      },
    ),
  );

  final out = File('build/receipt_preview.pdf');
  await out.create(recursive: true);
  final bytes = await pdf.save();
  await out.writeAsBytes(bytes);
  stdout.writeln('Wrote ${out.path}');
}
