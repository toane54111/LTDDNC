import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printRecord(String title, Map<String, String> values) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans.ttf'));
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Text(
          'TRỌ AN',
          style: pw.TextStyle(fontSize: 28, color: PdfColors.blue600),
        ),
        pw.SizedBox(height: 12),
        pw.Text(title, style: const pw.TextStyle(fontSize: 20)),
        pw.SizedBox(height: 24),
        pw.TableHelper.fromTextArray(
          headers: ['Thông tin', 'Nội dung'],
          data: values.entries.map((e) => [e.key, e.value]).toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellPadding: const pw.EdgeInsets.all(8),
        ),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Chủ trọ\n(Ký, ghi rõ họ tên)'),
            pw.Text('Khách thuê\n(Ký, ghi rõ họ tên)'),
          ],
        ),
      ],
    ),
  );
  await Printing.layoutPdf(
    onLayout: (_) => document.save(),
    name: 'tro-an.pdf',
  );
}
