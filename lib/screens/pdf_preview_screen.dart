import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String workOrder;
  final String substationName;
  final String? pageTitle;
  final String? pdfFileName;
  final PdfPageFormat? initialPageFormat;
  final String? equipment;
  final String? formType;
  final String? technician;
  final String? notes;
  final String? initialDriveUrl;
  final bool showUploadAction;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.workOrder,
    required this.substationName,
    this.pageTitle,
    this.pdfFileName,
    this.initialPageFormat,
    this.equipment,
    this.formType,
    this.technician,
    this.notes,
    this.initialDriveUrl,
    this.showUploadAction = false,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedFileName = widget.pdfFileName ??
        'GRID_MAINTENANCE_${widget.workOrder.replaceAll('/', '_')}.pdf';
    final resolvedTitle = widget.pageTitle ??
        (widget.equipment != null && widget.equipment!.isNotEmpty
            ? '${widget.substationName} - ${widget.equipment}'
            : 'تقرير الصيانة الرسمي (PDF Document)');

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
              widget.equipment != null && widget.equipment!.isNotEmpty
                  ? '${widget.substationName} • المعدة: ${widget.equipment} | ${widget.workOrder}'
                  : '${widget.substationName} | ${widget.workOrder}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
                bytes: widget.pdfBytes,
                filename: resolvedFileName,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: PdfPreview(
          build: (format) => widget.pdfBytes,
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: 900,
          pdfFileName: resolvedFileName,
          initialPageFormat: widget.initialPageFormat ?? PdfPageFormat.a4,
          loadingWidget: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}
