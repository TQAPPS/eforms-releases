import 'package:flutter/material.dart';
import '../models/draft_model.dart';
import '../models/annual_detail_inspection_model.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import '../services/draft_storage_service.dart';
import 'annual_detail_inspection_screen.dart';
import 'grid_maintenance_screen.dart';
import 'transformer_checklist_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<DraftModel> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    DraftStorageService.draftsChangeNotifier.addListener(_loadDrafts);
    _loadDrafts();
  }

  @override
  void dispose() {
    DraftStorageService.draftsChangeNotifier.removeListener(_loadDrafts);
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    try {
      final list = await DraftStorageService.getActiveDrafts();
      if (mounted) {
        setState(() {
          _drafts = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openDraft(DraftModel draft) async {
    if (draft.formId == 'annual_detail_inspection') {
      final annualModel = AnnualDetailInspectionModel.fromMap(draft.data);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnnualDetailInspectionScreen(
            existingInspection: annualModel,
            initialWorkOrder: annualModel.workOrderNo,
          ),
        ),
      );
    } else if (draft.formId == 'grid_maintenance') {
      final sub = NationalGridData.substations.firstWhere(
        (s) => s.name == draft.substation,
        orElse: () => NationalGridData.substations.first,
      );
      final form = SampleFormData.defaultForms.firstWhere(
        (f) => f.id == 'grid_maintenance',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GridMaintenanceScreen(
            form: form,
            selectedSubstation: sub,
            initialWorkOrder: draft.workOrderNo,
            initialInspectionDate: draft.data['inspectionDate'] as String?,
            draftData: draft.data,
          ),
        ),
      );
    } else if (draft.formId == 'transformer_checklist') {
      final sub = NationalGridData.substations.firstWhere(
        (s) => s.name == draft.substation,
        orElse: () => NationalGridData.substations.first,
      );
      final form = SampleFormData.defaultForms.firstWhere(
        (f) => f.id == 'transformer_checklist',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransformerChecklistScreen(
            form: form,
            selectedSubstation: sub,
            initialWorkOrder: draft.workOrderNo,
            initialDivision: draft.data['division'] as String?,
            initialDepartment: draft.data['department'] as String?,
            initialContactPerson: draft.data['contactPerson'] as String?,
            initialInspectionDate: draft.data['inspectionDate'] as String?,
            draftData: draft.data,
          ),
        ),
      );
    }

    if (mounted) _loadDrafts();
  }

  Future<void> _confirmDeleteDraft(DraftModel draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'حذف المسودة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل ترغب في حذف مسودة ${draft.formTitle} (${draft.substation} - ${draft.workOrderNo})؟\nلن تتمكن من استرجاع البيانات بعد الحذف.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DraftStorageService.deleteDraft(draft);
      await _loadDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المسودة بنجاح'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getFormColor(String formId) {
    switch (formId) {
      case 'grid_maintenance':
        return const Color(0xFF0284C7);
      case 'transformer_checklist':
        return const Color(0xFF0F766E);
      case 'annual_detail_inspection':
      default:
        return const Color(0xFF0F2C59);
    }
  }

  IconData _getFormIcon(String formId) {
    switch (formId) {
      case 'grid_maintenance':
        return Icons.offline_bolt_rounded;
      case 'transformer_checklist':
        return Icons.checklist_rtl_rounded;
      case 'annual_detail_inspection':
      default:
        return Icons.assignment_turned_in_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'المسودات المحفوظة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'صلاحية الحفظ 24 ساعة فقط',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث المسودات',
              onPressed: _loadDrafts,
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _drafts.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadDrafts,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        children: [
                          // Info alert banner
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'يتم الاحتفاظ بمسودات النماذج غير المكتملة لمدة 24 ساعة من آخر حفظ، وبعدها يتم حذفها تلقائياً.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : const Color(0xFF78350F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Header count
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.bookmark_rounded,
                                  color: Color(0xFFD97706),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'الملفات بانتظار استكمال التعبئة',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F2C59),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_drafts.length} مسودة',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // List of Draft Cards
                          ..._drafts.map((draft) => _buildDraftItem(draft, isDark)),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.drafts_outlined,
                size: 64,
                color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد مسودات محفوظة حالياً',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'عند التوقف عن إكمال أي نموذج والضغط على "حفظ المسودة"، سيتم حفظ الملف هنا لتتمكن من استكماله خلال 24 ساعة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftItem(DraftModel draft, bool isDark) {
    final remainingStr = DraftStorageService.formatRemainingDraftTime(draft);
    final formColor = _getFormColor(draft.formId);
    final formIcon = _getFormIcon(draft.formId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: formColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  formIcon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.formTitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'محطة: ${draft.substation} • كود: ${draft.formCode}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Remaining Time Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 12, color: Color(0xFFB45309)),
                    const SizedBox(width: 4),
                    Text(
                      remainingStr,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details Box (Where user stopped)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pin_drop_rounded,
                    size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'توقفت عند: ${draft.stepDescription}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                    ),
                  ),
                ),
                Text(
                  'أمر عمل: ${draft.workOrderNo}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'استكمال تعبئة النموذج',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _openDraft(draft),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'حذف المسودة',
                onPressed: () => _confirmDeleteDraft(draft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
