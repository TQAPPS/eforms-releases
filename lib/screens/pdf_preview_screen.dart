import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String workOrder;
  final String substationName;
  final String? pageTitle;
  final String? pdfFileName;
  final PdfPageFormat? initialPageFormat;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.workOrder,
    required this.substationName,
    this.pageTitle,
    this.pdfFileName,
    this.initialPageFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedFileName = pdfFileName ??
        'GRID_MAINTENANCE_${workOrder.replaceAll('/', '_')}.pdf';
    final resolvedTitle = pageTitle ?? 'تقرير الصيانة الرسمي (PDF Document)';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              resolvedTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '$substationName | $workOrder',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'مشاركة التقرير',
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: resolvedFileName,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: PdfPreview(
          build: (format) => pdfBytes,
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: 900,
          pdfFileName: resolvedFileName,
          initialPageFormat: initialPageFormat ?? PdfPageFormat.a4,
          loadingWidget: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
