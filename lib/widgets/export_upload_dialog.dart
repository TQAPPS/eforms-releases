import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/exported_form_model.dart';
import '../services/exported_forms_service.dart';
import '../services/onedrive_service.dart';
import '../services/report_upload_service.dart';

enum ExportUploadPhase { generatingPdf, uploadingCloud, completed, error }

class ExportUploadProgressDialog extends StatefulWidget {
  final String substation;
  final String equipment;
  final String formType;
  final String technician;
  final String? formId;
  final String? notes;
  final String? fileName;
  final Future<Uint8List> Function() onGeneratePdf;
  final void Function(Uint8List pdfBytes, String? driveUrl)? onPreview;

  const ExportUploadProgressDialog({
    super.key,
    required this.substation,
    required this.equipment,
    required this.formType,
    required this.technician,
    this.formId,
    this.notes,
    this.fileName,
    required this.onGeneratePdf,
    this.onPreview,
  });

  /// Static helper to show the dialog and execute the unified process.
  static Future<void> show({
    required BuildContext context,
    required String substation,
    required String equipment,
    required String formType,
    required String technician,
    String? formId,
    String? notes,
    String? fileName,
    required Future<Uint8List> Function() onGeneratePdf,
    void Function(Uint8List pdfBytes, String? driveUrl)? onPreview,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ExportUploadProgressDialog(
        substation: substation,
        equipment: equipment,
        formType: formType,
        technician: technician,
        formId: formId,
        notes: notes,
        fileName: fileName,
        onGeneratePdf: onGeneratePdf,
        onPreview: onPreview,
      ),
    );
  }

  @override
  State<ExportUploadProgressDialog> createState() =>
      _ExportUploadProgressDialogState();
}

class _ExportUploadProgressDialogState extends State<ExportUploadProgressDialog>
    with SingleTickerProviderStateMixin {
  ExportUploadPhase _phase = ExportUploadPhase.generatingPdf;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  Uint8List? _generatedPdfBytes;
  ReportUploadResult? _uploadResult;
  bool? _oneDriveSuccess;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Kick off the unified export & upload process immediately
    _startProcess();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startProcess() async {
    try {
      // Step 1: Generate PDF
      if (mounted) setState(() => _phase = ExportUploadPhase.generatingPdf);
      final pdfBytes = await widget.onGeneratePdf();
      _generatedPdfBytes = pdfBytes;

      // Step 2: Upload to Cloud (Google Drive & OneDrive in parallel)
      if (mounted) setState(() => _phase = ExportUploadPhase.uploadingCloud);

      final formTitle =
          '${widget.substation}_${widget.equipment}_${widget.formType}';
      final standardFileName = ExportedFormModel.buildFileName(
        substation: widget.substation,
        equipment: widget.equipment,
        formType: widget.formType,
      );
      final resolvedFileName =
          (widget.fileName != null && widget.fileName!.trim().isNotEmpty)
          ? widget.fileName!.trim()
          : standardFileName;

      final uploadResults = await Future.wait([
        ReportUploadService.uploadInspectionPdf(
          substation: widget.substation,
          equipment: widget.equipment,
          formType: widget.formType,
          technician: widget.technician,
          notes: widget.notes,
          fileName: resolvedFileName,
          pdfBytes: pdfBytes,
        ),
        OneDriveService.uploadPdfBytes(
          pdfBytes: pdfBytes,
          formTitle: formTitle,
          fileName: resolvedFileName,
          formId: widget.formId ?? widget.equipment,
          employeeName: widget.technician,
          formType: widget.formType,
        ),
      ]);

      final result = uploadResults[0] as ReportUploadResult;
      final oneDriveSuccess = uploadResults[1] as bool;

      _uploadResult = result;
      _oneDriveSuccess = oneDriveSuccess;

      if (!mounted) return;

      if (result.isSuccess) {
        String? localPath;
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName =
              result.fileName ?? widget.fileName ?? 'تقرير_فحص.pdf';
          String cleanName = fileName.trim();
          if (cleanName.toLowerCase().endsWith('.pdf')) {
            cleanName = cleanName.substring(0, cleanName.length - 4);
          }
          cleanName = cleanName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final localFile = File('${appDir.path}/$cleanName.pdf');
          await localFile.writeAsBytes(pdfBytes, flush: true);
          localPath = localFile.path;
        } catch (_) {}

        final exportedForm = ExportedFormModel(
          id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
          fileName: result.fileName ?? widget.fileName ?? 'تقرير_فحص.pdf',
          substation: widget.substation,
          equipment: widget.equipment,
          formType: widget.formType,
          technician: widget.technician,
          notes: widget.notes,
          driveUrl: result.driveFileUrl ?? '',
          exportedAt: DateTime.now(),
          fileSizeBytes: pdfBytes.length,
          localFilePath: localPath,
        );
        ExportedFormsService.saveExportedForm(exportedForm);
        setState(() => _phase = ExportUploadPhase.completed);
      } else {
        setState(() {
          _phase = ExportUploadPhase.error;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = ExportUploadPhase.error;
        _errorMessage = 'حدث خطأ غير متوقع: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop:
          _phase == ExportUploadPhase.completed ||
          _phase == ExportUploadPhase.error,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F2643) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFFBAE6FD),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _buildPhaseContent(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(bool isDark) {
    switch (_phase) {
      case ExportUploadPhase.generatingPdf:
      case ExportUploadPhase.uploadingCloud:
        return _buildProgressView(isDark);
      case ExportUploadPhase.completed:
        return _buildSuccessView(isDark);
      case ExportUploadPhase.error:
        return _buildErrorView(isDark);
    }
  }

  /// Interactive animated progress view (PDF generation -> Cloud Upload)
  Widget _buildProgressView(bool isDark) {
    final isGenerating = _phase == ExportUploadPhase.generatingPdf;
    final primaryColor = isGenerating
        ? const Color(0xFF0284C7) // Sky Blue
        : const Color(0xFF059669); // Emerald

    return Column(
      key: ValueKey('progress_$_phase'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Animated Central Icon
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.25),
                      primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.8),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  isGenerating
                      ? Icons.picture_as_pdf_rounded
                      : Icons.cloud_upload_rounded,
                  color: primaryColor,
                  size: 38,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 22),

        // Title
        Text(
          isGenerating
              ? 'جاري إعداد وتصدير ملف PDF...'
              : 'جاري الأرشفة والرفع إلى المجلد السحابي...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),

        // Subtitle description
        Text(
          isGenerating
              ? 'يتم الآن تجميع الجداول، الرسوم، والتوقيعات الرقمية المعتمدة.'
              : 'يتم تشفير الملف ورفعه تلقائياً إلى المجلد السحابي بالتزامن.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),

        // Multi-Step Progress Tracker Bar
        _buildMultiStepTracker(
          activeStep: isGenerating ? 1 : 2,
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // Linear Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: isGenerating ? 0.45 : 0.85,
            backgroundColor: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFE2E8F0),
            color: primaryColor,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  /// Multi-step indicator: [1. إنشاء PDF] ➔ [2. رفع Drive]
  Widget _buildMultiStepTracker({
    required int activeStep,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStepItem(
            stepNumber: '1',
            title: 'توليد الـ PDF',
            isActive: activeStep >= 1,
            isDone: activeStep > 1,
            isDark: isDark,
          ),
        ),
        Container(
          width: 24,
          height: 2,
          color: activeStep > 1
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        Expanded(
          child: _buildStepItem(
            stepNumber: '2',
            title: 'الرفع السحابي',
            isActive: activeStep >= 2,
            isDone: false,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String stepNumber,
    required String title,
    required bool isActive,
    required bool isDone,
    required bool isDark,
  }) {
    final color = isDone
        ? const Color(0xFF10B981)
        : (isActive ? const Color(0xFF0284C7) : Colors.grey);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check, size: 13, color: Color(0xFF10B981))
              : Text(
                  stepNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// Complete Success View with Google Drive link and immediate preview option
  Widget _buildSuccessView(bool isDark) {
    final driveUrl = _uploadResult?.driveFileUrl;

    return Column(
      key: const ValueKey('success_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Success Badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            border: Border.all(color: const Color(0xFF10B981), width: 2.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.cloud_done_rounded,
            color: Color(0xFF10B981),
            size: 40,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        const Text(
          'تم التصدير والرفع بنجاح!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),

        // Subtitle message
        Text(
          _uploadResult?.message ??
              'تم حفظ التقرير محلياً وأرشفته بنجاح في المجلد السحابي.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),

        // Details Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF07172B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF1E324F) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              _buildDetailRow('المحطة:', widget.substation, isDark),
              _buildDetailRow('المعدة:', widget.equipment, isDark),
              if (_uploadResult?.fileName != null)
                _buildDetailRow('اسم الملف:', _uploadResult!.fileName!, isDark),
            ],
          ),
        ),

        // Cloud Storage Status Card
        if (_oneDriveSuccess != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _oneDriveSuccess == true
                  ? const Color(0xFF0078D4).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _oneDriveSuccess == true
                    ? const Color(0xFF0078D4).withValues(alpha: 0.35)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _oneDriveSuccess == true
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: _oneDriveSuccess == true
                      ? const Color(0xFF0078D4)
                      : const Color(0xFFF59E0B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _oneDriveSuccess == true
                        ? 'تم الرفع والأرشفة في المجلد السحابي بنجاح'
                        : 'تعذر الرفع المباشر إلى المجلد السحابي',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _oneDriveSuccess == true
                          ? (isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF0078D4))
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                if (_oneDriveSuccess == true)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            // Preview PDF Button
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text(
                  'معاينة ملف PDF',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  if (widget.onPreview != null && _generatedPdfBytes != null) {
                    widget.onPreview!(_generatedPdfBytes!, driveUrl);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),

            // Home / الرئيسية Button
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white70
                      : const Color(0xFF334155),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text(
                  'الرئيسية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Error or Partial Failure View (lets user open local PDF regardless)
  Widget _buildErrorView(bool isDark) {
    final hasPdf = _generatedPdfBytes != null;

    return Column(
      key: const ValueKey('error_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Warning / Error Badge
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasPdf
                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                : const Color(0xFFEF4444).withValues(alpha: 0.15),
            border: Border.all(
              color: hasPdf ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
              width: 2.0,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            hasPdf ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
            color: hasPdf ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          hasPdf
              ? 'تم تصدير الـ PDF ولكن تعذر الرفع السحابي'
              : 'حدث خطأ أثناء العملية',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),

        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            if (hasPdf) ...[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text(
                    'معاينة الـ PDF',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onPreview != null &&
                        _generatedPdfBytes != null) {
                      widget.onPreview!(_generatedPdfBytes!, null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white70
                      : const Color(0xFF334155),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
