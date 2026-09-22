import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../models/exported_form_model.dart';
import '../services/exported_forms_service.dart';
import 'pdf_preview_screen.dart';

/// شاشة استعراض وتنزيل النماذج المصدرة والمرفوعة إلى Google Drive
class ExportedFormsScreen extends StatefulWidget {
  const ExportedFormsScreen({super.key});

  @override
  State<ExportedFormsScreen> createState() => _ExportedFormsScreenState();
}

class _ExportedFormsScreenState extends State<ExportedFormsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSubstationFilter = 'الكل';

  // تتبع حالة ونسبة تقدم التنزيل لكل نموذج حسب معرفه (id)
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingIds = {};

  // مؤقت التحديث التلقائي المباشر من Google Drive
  Timer? _liveSyncTimer;

  @override
  void initState() {
    super.initState();
    // تهيئة الخدمة وتشغيل المزامنة الفورية من Google Drive فور فتح الصفحة
    ExportedFormsService.init().then((_) {
      if (mounted) {
        ExportedFormsService.refreshFromDrive(silent: false);
      }
    });

    // تحديث تلقائي ومباشر دوري كل 12 ثانية أثناء فتح الصفحة لمزامنة النماذج الجديدة فورياً
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        ExportedFormsService.refreshFromDrive(silent: true);
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// تنزيل النموذج المصدّر وحفظه على الجهاز بصيغة PDF
  Future<void> _handleDownload(ExportedFormModel form) async {
    if (_downloadingIds.contains(form.id)) return;

    setState(() {
      _downloadingIds.add(form.id);
      _downloadProgress[form.id] = 0.05;
    });

    final result = await ExportedFormsService.downloadFormFile(
      form: form,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[form.id] = progress;
          });
        }
      },
    );

    if (!mounted) return;

    setState(() {
      _downloadingIds.remove(form.id);
      _downloadProgress.remove(form.id);
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم تنزيل ${form.fileName} بصيغة PDF بنجاح!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (result.filePath != null)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ExportedFormsService.openFile(
                      result.filePath!,
                      form: form,
                      context: context,
                    );
                  },
                  child: const Text(
                    'فتح الملف',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // فتح ملف الـ PDF تلقائياً ومباشرة بعد اكتمال التنزيل
      if (result.filePath != null) {
        ExportedFormsService.openFile(
          result.filePath!,
          form: form,
          context: context,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// فتح معاينة مستند الـ PDF مباشرة داخل التطبيق
  Future<void> _previewPdf(ExportedFormModel form) async {
    Uint8List? bytes;
    if (form.localFilePath != null && File(form.localFilePath!).existsSync()) {
      final f = File(form.localFilePath!);
      if (f.lengthSync() >= 100) {
        final b = await f.readAsBytes();
        if (ExportedFormsService.isValidPdf(b)) {
          bytes = b;
        }
      }
    }

    if (bytes == null) {
      final dlResult = await ExportedFormsService.downloadFormFile(form: form);
      bytes = dlResult.bytes;
    }

    if (bytes != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PdfPreviewScreen(
            pdfBytes: bytes!,
            workOrder: form.equipment,
            substationName: form.substation,
            pdfFileName: form.fileName,
            equipment: form.equipment,
            formType: form.canonicalFormTitle,
            technician: form.technician,
            notes: form.notes,
            initialDriveUrl: form.driveUrl,
          ),
        ),
      );
    }
  }

  /// مشاركة ملف الـ PDF عبر تطبيقات التواصل
  Future<void> _sharePdf(ExportedFormModel form) async {
    Uint8List? bytes;
    if (form.localFilePath != null && File(form.localFilePath!).existsSync()) {
      final f = File(form.localFilePath!);
      if (f.lengthSync() >= 100) {
        final b = await f.readAsBytes();
        if (ExportedFormsService.isValidPdf(b)) {
          bytes = b;
        }
      }
    }

    if (bytes == null) {
      final dlResult = await ExportedFormsService.downloadFormFile(form: form);
      bytes = dlResult.bytes;
    }

    if (bytes != null) {
      await Printing.sharePdf(bytes: bytes, filename: form.fileName);
    }
  }

  /// نسخ رابط Google Drive إلى الحافظة
  void _copyDriveLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.link_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'تم نسخ رابط Google Drive إلى الحافظة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    color: Color(0xFF0284C7),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'النماذج المصدرة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: ExportedFormsService.isLoadingNotifier,
              builder: (context, isLoading, _) {
                return IconButton(
                  tooltip: isLoading
                      ? 'جاري المزامنة مع Google Drive...'
                      : 'تحديث فوري من Google Drive (مباشر)',
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0284C7),
                          ),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 22),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF10B981),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await ExportedFormsService.refreshFromDrive(silent: false);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'تم تحديث النماذج تلقائياً من Google Drive بنجاح'
                                    : 'تم التحقق من النماذج في Google Drive',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              backgroundColor: const Color(0xFF0F766E),
                            ),
                          );
                        },
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ValueListenableBuilder<List<ExportedFormModel>>(
          valueListenable: ExportedFormsService.exportedFormsNotifier,
          builder: (context, allForms, _) {
            // استخراج قائمة المحطات المتاحة للتصفية
            final substations = <String>{'الكل'};
            for (final f in allForms) {
              if (f.substation.isNotEmpty) {
                substations.add(f.substation);
              }
            }

            // تطبيق التصفية والبحث
            final filteredForms = allForms.where((f) {
              // فلتر المحطة
              if (_selectedSubstationFilter != 'الكل' &&
                  f.substation != _selectedSubstationFilter) {
                return false;
              }
              // فلتر البحث
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                final matchName = f.fileName.toLowerCase().contains(query);
                final matchSub = f.substation.toLowerCase().contains(query);
                final matchEq = f.equipment.toLowerCase().contains(query);
                final matchType = f.formType.toLowerCase().contains(query) ||
                    f.displayInspectionType.toLowerCase().contains(query);
                final matchTech = f.technician.toLowerCase().contains(query);
                return matchName || matchSub || matchEq || matchType || matchTech;
              }
              return true;
            }).toList();

            return Column(
              children: [
                // لوحة الإحصائيات السريعة والبحث
                _buildHeaderPanel(isDark, allForms.length, substations.toList()),

                // قائمة النماذج المصدرة
                Expanded(
                  child: filteredForms.isEmpty
                      ? _buildEmptyView(isDark, allForms.isEmpty)
                      : RefreshIndicator(
                          onRefresh: () =>
                              ExportedFormsService.refreshFromDrive(),
                          color: const Color(0xFF0284C7),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: filteredForms.length,
                            itemBuilder: (context, index) {
                              final form = filteredForms[index];
                              return _buildFormCard(context, form, isDark);
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// لوحة الإحصائيات وحقل البحث وتصفية المحطات
  Widget _buildHeaderPanel(
    bool isDark,
    int totalCount,
    List<String> substations,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط معلومات سريع
          Row(
            children: [
              _buildStatChip(
                label: 'إجمالي النماذج',
                value: '$totalCount',
                icon: Icons.description_rounded,
                color: const Color(0xFF2563EB),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'Google Drive',
                value: '$totalCount ملف',
                icon: Icons.cloud_done_rounded,
                color: const Color(0xFF059669),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'تنسيق الملفات',
                value: 'PDF معتمد',
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFDC2626),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // حقل البحث
          TextField(
            controller: _searchController,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'ابحث باسم الملف، المحطة، المعدة، أو نوع النموذج...',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF0284C7),
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF0284C7),
                  width: 1.5,
                ),
              ),
            ),
          ),

          if (substations.length > 2) ...[
            const SizedBox(height: 10),
            // أشرطة التصفية السريعة للمحطات
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: substations.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final sub = substations[idx];
                  final isSelected = sub == _selectedSubstationFilter;
                  return ChoiceChip(
                    label: Text(sub),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedSubstationFilter = sub;
                      });
                    },
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF0284C7)
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// بطاقة شريحة إحصائية
  Widget _buildStatChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة عرض النموذج المصدّر
  Widget _buildFormCard(
    BuildContext context,
    ExportedFormModel form,
    bool isDark,
  ) {
    final isDownloading = _downloadingIds.contains(form.id);
    final progress = _downloadProgress[form.id] ?? 0.0;
    final hasLocal =
        form.localFilePath != null && form.localFilePath!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D36) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2E4A) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // السطر العلوي: أيقونة PDF + اسم الملف + قائمة الخيارات
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // أيقونة الـ PDF
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFEF4444),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // اسم الملف ونوع النموذج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: form.displayInspectionType == 'فحص سنوي'
                                  ? const Color(0xFF7C3AED).withValues(alpha: 0.14)
                                  : const Color(0xFF0284C7).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: form.displayInspectionType == 'فحص سنوي'
                                    ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                                    : const Color(0xFF0284C7).withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  form.displayInspectionType == 'فحص سنوي'
                                      ? Icons.event_repeat_rounded
                                      : Icons.calendar_today_rounded,
                                  size: 11,
                                  color: form.displayInspectionType == 'فحص سنوي'
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  form.displayInspectionType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: form.displayInspectionType == 'فحص سنوي'
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (form.formattedFileSize.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              form.formattedFileSize,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // زر خيارات إضافية (معاينة / مشاركة / نسخ الرابط / حذف من السجل)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    if (val == 'preview') {
                      _previewPdf(form);
                    } else if (val == 'share') {
                      _sharePdf(form);
                    } else if (val == 'copy') {
                      _copyDriveLink(form.driveUrl);
                    } else if (val == 'delete') {
                      ExportedFormsService.deleteExportedForm(form.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'preview',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('معاينة PDF داخل التطبيق', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, size: 16, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text('مشاركة ملف PDF', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (form.driveUrl.isNotEmpty)
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('نسخ رابط Google Drive', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('إزالة من السجل', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // شارات التفاصيل (المحطة - المعدة - الفاحص - التاريخ)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0B1426)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // المحطة
                      Expanded(
                        child: _buildMetaRow(
                          icon: Icons.location_on_rounded,
                          label: 'المحطة:',
                          value: form.substation,
                          color: const Color(0xFF0284C7),
                          isDark: isDark,
                        ),
                      ),
                      // المعدة
                      Expanded(
                        child: _buildMetaRow(
                          icon: Icons.bolt_rounded,
                          label: 'المعدة:',
                          value: form.equipment,
                          color: const Color(0xFFD97706),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // نوع الفحص
                      Expanded(
                        child: _buildMetaRow(
                          icon: form.displayInspectionType == 'فحص سنوي'
                              ? Icons.event_repeat_rounded
                              : Icons.calendar_today_rounded,
                          label: 'نوع الفحص:',
                          value: form.displayInspectionType,
                          color: form.displayInspectionType == 'فحص سنوي'
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF0284C7),
                          isDark: isDark,
                        ),
                      ),
                      // النموذج المستخدم
                      Expanded(
                        child: _buildMetaRow(
                          icon: Icons.description_outlined,
                          label: 'النموذج:',
                          value: form.canonicalFormTitle,
                          color: const Color(0xFF2563EB),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // التاريخ
                      Expanded(
                        child: _buildMetaRow(
                          icon: Icons.access_time_filled_rounded,
                          label: 'التاريخ:',
                          value: form.formattedDate,
                          color: const Color(0xFF059669),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // شريط التقدم أثناء التنزيل
            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                  color: const Color(0xFF0284C7),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'جاري تنزيل الملف من Google Drive...',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // أزرار العمليات (تنزيل الملف + فتح في Drive / فتح محلي)
            Row(
              children: [
                // زر "تنزيل الملف" الرئيسي المطلوب أو "فتح الملف"
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasLocal
                          ? const Color(0xFF059669)
                          : const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            hasLocal
                                ? Icons.file_open_rounded
                                : Icons.file_download_rounded,
                            size: 19,
                          ),
                    label: Text(
                      isDownloading
                          ? 'جاري التنزيل...'
                          : (hasLocal ? 'فتح الملف' : 'تنزيل الملف'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: isDownloading
                        ? null
                        : () {
                            if (hasLocal) {
                              ExportedFormsService.openFile(
                                form.localFilePath!,
                                form: form,
                                context: context,
                              );
                            } else {
                              _handleDownload(form);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),

                // زر معاينة PDF السريعة داخل التطبيق
                IconButton.filledTonal(
                  tooltip: 'معاينة PDF داخل التطبيق',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF0284C7).withValues(alpha: 0.2)
                        : const Color(0xFFE0F2FE),
                    foregroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_rounded, size: 20),
                  onPressed: () => _previewPdf(form),
                ),
                const SizedBox(width: 6),

                // زر معاينة أو نسخ رابط Google Drive
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                            : const Color(0xFF0284C7).withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.cloud_queue_rounded, size: 17),
                    label: const Text(
                      'رابط Drive',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _copyDriveLink(form.driveUrl),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// سطر معلومات وصفي
  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  /// حالة عدم وجود نماذج تطابق البحث
  Widget _buildEmptyView(bool isDark, bool isCompletelyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                isCompletelyEmpty
                    ? Icons.cloud_off_rounded
                    : Icons.search_off_rounded,
                size: 42,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isCompletelyEmpty
                  ? 'لا توجد نماذج مصدرة مسجلة بعد'
                  : 'لم يتم العثور على أي نتائج مطابقة',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCompletelyEmpty
                  ? 'يتم جلب النماذج الحقيقية المرفوعة فقط عبر التطبيق أو المسجلة في ملف "سجل نماذج الفحص والصيانة".'
                  : 'جرب البحث باسم محطة أو معدة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            if (isCompletelyEmpty)
              FilledButton.tonalIcon(
                onPressed: () => ExportedFormsService.refreshFromDrive(),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('تحديث السجلات الآن'),
              )
            else
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedSubstationFilter = 'الكل';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة ضبط البحث'),
              ),
          ],
        ),
      ),
    );
  }
}
