import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'grid_maintenance_screen.dart';
import 'oil_sampling_screen.dart';
import 'transformer_checklist_screen.dart';
import 'sample_acknowledgement_screen.dart';
import 'annual_detail_inspection_screen.dart';
import 'drafts_screen.dart';
import '../models/draft_model.dart';
import '../services/draft_storage_service.dart';
import '../models/annual_detail_inspection_model.dart';
import '../services/app_update_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const HomeScreen({
    super.key,
    required this.themeModeNotifier,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _appVersion = '';
  List<DraftModel> _activeDrafts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppVersion();
    _loadActiveDrafts();
    DraftStorageService.draftsChangeNotifier.addListener(_loadActiveDrafts);
    // فحص التحديثات المتاحة تلقائياً عند فتح التطبيق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DraftStorageService.draftsChangeNotifier.removeListener(_loadActiveDrafts);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadActiveDrafts();
    }
  }

  Future<void> _loadActiveDrafts() async {
    try {
      final drafts = await DraftStorageService.getActiveDrafts();
      if (mounted) {
        setState(() {
          _activeDrafts = drafts;
        });
      }
    } catch (e) {
      debugPrint('Error loading active drafts: $e');
    }
  }

  Future<void> _navigateToDraftsScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DraftsScreen(),
      ),
    );
    if (mounted) _loadActiveDrafts();
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
    } else {
      await _navigateToDraftsScreen(context);
    }
    if (mounted) _loadActiveDrafts();
  }


  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {}
  }


  void _openForm(BuildContext context, FormModel form) {
    if (form.id == 'grid_maintenance') {
      _showStartInspectionDialog(context, form);
      return;
    }

    if (form.id == 'transformer_checklist') {
      _showStartChecklistDialog(context, form);
      return;
    }

    if (form.id == 'oil_sampling') {
      _showStartOilSamplingDialog(context, form);
      return;
    }

    if (form.id == 'sample_acknowledgement') {
      _showStartSampleAcknowledgementDialog(context, form);
      return;
    }

    if (form.id == 'annual_detail_inspection') {
      _showStartAnnualInspectionDialog(context, form);
      return;
    }
  }

  void _showStartSampleAcknowledgementDialog(
      BuildContext context, FormModel form) {
    SubstationModel selectedSubstation = NationalGridData.substations.firstWhere(
      (s) => s.name == 'JIC',
      orElse: () => NationalGridData.substations.first,
    );
    final allUnits = <TransformerInfo>[
      ...selectedSubstation.transformers,
      ...selectedSubstation.auxTransformers,
    ];
    TransformerInfo? selectedEquipment =
        allUnits.isNotEmpty ? allUnits.first : null;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final units = <TransformerInfo>[
              ...selectedSubstation.transformers,
              ...selectedSubstation.auxTransformers,
            ];
            if (selectedEquipment == null ||
                !units.contains(selectedEquipment)) {
              selectedEquipment = units.isNotEmpty ? units.first : null;
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Header card matching Image 1
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1D4ED8)
                              .withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1D4ED8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Color(0xFFFACC15),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المحطة والمعدة (National Grid Dataset)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F2C59),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'يتم استرجاع بيانات الجهد والسعة والشركة المصنعة تلقائياً',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Substation Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'محطة التحويل (Substation):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<SubstationModel>(
                              value: selectedSubstation,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1D4ED8),
                              ),
                              items: NationalGridData.substations.map((sub) {
                                return DropdownMenuItem<SubstationModel>(
                                  value: sub,
                                  child: Text(
                                    '${sub.name} (${sub.region})',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (newSub) {
                                if (newSub != null) {
                                  setDialogState(() {
                                    selectedSubstation = newSub;
                                    final newUnits = <TransformerInfo>[
                                      ...newSub.transformers,
                                      ...newSub.auxTransformers,
                                    ];
                                    selectedEquipment = newUnits.isNotEmpty
                                        ? newUnits.first
                                        : null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Equipment Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المعدة / المحول (Equipment / Transformer):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TransformerInfo>(
                              value: units.contains(selectedEquipment)
                                  ? selectedEquipment
                                  : (units.isNotEmpty ? units.first : null),
                              isExpanded: true,
                              hint: const Text('اختر المعدة',
                                  style: TextStyle(fontSize: 12)),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1D4ED8),
                              ),
                              items: units.map((tx) {
                                return DropdownMenuItem<TransformerInfo>(
                                  value: tx,
                                  child: Text(
                                    '${tx.number} (${tx.voltage.isNotEmpty ? "${tx.voltage} Kv" : ""})',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (newTx) {
                                setDialogState(() {
                                  selectedEquipment = newTx;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('إلغاء',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18),
                            label: const Text(
                              'بدء تعبئة النموذج',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              Navigator.pop(dialogCtx);
                              await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      SampleAcknowledgementScreen(
                                    form: form,
                                    initialSubstation: selectedSubstation,
                                    initialEquipment: selectedEquipment,
                                  ),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    const begin = Offset(0.0, 0.05);
                                    const end = Offset.zero;
                                    const curve = Curves.easeOutCubic;
                                    var tween = Tween(begin: begin, end: end)
                                        .chain(CurveTween(curve: curve));
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: animation.drive(tween),
                                        child: child,
                                      ),
                                    );
                                  },
                                ),
                              );
                              if (mounted) _loadActiveDrafts();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  void _showStartAnnualInspectionDialog(
      BuildContext context, FormModel form) {
    SubstationModel selectedSubstation = NationalGridData.substations.firstWhere(
      (s) => s.name == 'JIC',
      orElse: () => NationalGridData.substations.first,
    );
    final allUnits = <TransformerInfo>[
      ...selectedSubstation.transformers,
      ...selectedSubstation.auxTransformers,
    ];
    TransformerInfo? selectedEquipment =
        allUnits.isNotEmpty ? allUnits.first : null;
    final workOrderController = TextEditingController(text: '');
    String? workOrderError;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final units = <TransformerInfo>[
              ...selectedSubstation.transformers,
              ...selectedSubstation.auxTransformers,
            ];
            if (selectedEquipment == null ||
                !units.contains(selectedEquipment)) {
              selectedEquipment = units.isNotEmpty ? units.first : null;
            }

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF0F2C59).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2C59),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.assignment_turned_in_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Annual Detail Inspection',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'CL-GM-1600-004-002 • نقل الكهرباء',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF0F2C59),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Substation Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'محطة التحويل (Substation):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<SubstationModel>(
                              value: selectedSubstation,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF0F2C59),
                              ),
                              items: NationalGridData.substations.map((sub) {
                                return DropdownMenuItem<SubstationModel>(
                                  value: sub,
                                  child: Text(
                                    '${sub.name} (${sub.region})',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (newSub) {
                                if (newSub != null) {
                                  setDialogState(() {
                                    selectedSubstation = newSub;
                                    final currentUnits = <TransformerInfo>[
                                      ...newSub.transformers,
                                      ...newSub.auxTransformers,
                                    ];
                                    selectedEquipment = currentUnits.isNotEmpty
                                        ? currentUnits.first
                                        : null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Transformer Designation Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مسمى المحول / المعدة (Transformer Designation):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TransformerInfo>(
                              value: units.contains(selectedEquipment)
                                  ? selectedEquipment
                                  : (units.isNotEmpty ? units.first : null),
                              isExpanded: true,
                              hint: const Text('اختر المعدة',
                                  style: TextStyle(fontSize: 12)),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF0F2C59),
                              ),
                              items: units.map((tx) {
                                return DropdownMenuItem<TransformerInfo>(
                                  value: tx,
                                  child: Text(
                                    '${tx.number} • ${tx.voltage}${tx.mva != null && tx.mva!.isNotEmpty ? " • ${tx.mva}" : ""}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (newTx) {
                                setDialogState(() {
                                  selectedEquipment = newTx;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Builder(builder: (ctx) {
                      final annualDrafts = _activeDrafts
                          .where((d) => d.formId == 'annual_detail_inspection')
                          .toList();
                      if (annualDrafts.isEmpty) return const SizedBox.shrink();
                      final draft = annualDrafts.first;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF312E81).withValues(alpha: 0.3)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark_added_rounded,
                                    color: Color(0xFFD97706), size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'توجد مسودة محفوظة لهذا النموذج',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'أمر عمل: ${draft.workOrderNo} • محطة: ${draft.substation}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : const Color(0xFF78350F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text(
                                  'استكمال المسودة المحفوظة',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  _openDraft(draft);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Work Order Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رقم أمر العمل (Work Order No.):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: workOrderController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) {
                            if (workOrderError != null) {
                              setDialogState(() {
                                workOrderError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'أدخل رقم أمر العمل...',
                            errorText: workOrderError,
                            prefixIcon: const Icon(Icons.confirmation_number_outlined),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0F2C59),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('إلغاء',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F2C59),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18),
                            label: const Text(
                              'بدء تعبئة النموذج',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final wo = workOrderController.text.trim();
                              if (wo.isEmpty) {
                                setDialogState(() {
                                  workOrderError =
                                      'يلزم إدخال رقم أمر العمل (Work Order No.) قبل بدء تعبئة النموذج';
                                });
                                return;
                              }
                              Navigator.pop(dialogCtx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AnnualDetailInspectionScreen(
                                    form: form,
                                    initialSubstation: selectedSubstation,
                                    initialEquipment: selectedEquipment ??
                                        (units.isNotEmpty ? units.first : null),
                                    initialWorkOrder: wo,
                                  ),
                                ),
                              );
                              if (mounted) _loadActiveDrafts();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  void _showStartChecklistDialog(BuildContext context, FormModel form) {
    SubstationModel selectedSubstation = NationalGridData.substations.firstWhere(
      (s) => s.name == 'JIC',
      orElse: () => NationalGridData.substations.first,
    );
    String selectedDivision = selectedSubstation.division;
    String selectedDepartment = selectedSubstation.department;
    final contactPersonController = TextEditingController(text: '');
    final workOrderController = TextEditingController(text: '');
    String inspectionDate = DateFormat('yyyy/MM/dd').format(DateTime.now());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.checklist_rtl_rounded,
                                color: Color(0xFF0F766E),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'بيانات أمر العمل والمحطة',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Checklist for Substation Power Transformer (CL-GM-1400-002-002)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Substation Selection & Transformers
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.15 : 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.account_balance_rounded, size: 15, color: Color(0xFF0F766E)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'محطة التحويل (Substation Name/No)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<SubstationModel>(
                                    value: selectedSubstation,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F766E)),
                                    items: NationalGridData.substations.map((sub) {
                                      return DropdownMenuItem<SubstationModel>(
                                        value: sub,
                                        child: Text(
                                          '${sub.name} (${sub.transformers.length} محولات - ${sub.region})',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newSub) {
                                      if (newSub != null) {
                                        setDialogState(() {
                                          selectedSubstation = newSub;
                                          selectedDivision = newSub.division;
                                          selectedDepartment = newSub.department;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Transformer Units Preview
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: selectedSubstation.transformers.map((tx) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${tx.number} ${tx.voltage.isNotEmpty ? "(${tx.voltage})" : ""}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Contact Person
                        const Text(
                          'الشخص المسؤول للتواصل (Contact Person)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: contactPersonController,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'اسم المهندس أو الفني القائم بالفحص',
                            prefixIcon: const Icon(Icons.person_rounded, size: 17),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Work Order
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'أمر العمل (W.O)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: workOrderController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'مثال: 8842910',
                            prefixIcon: const Icon(Icons.receipt_long_rounded, size: 16),
                            prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            filled: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'مطلوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Date Picker
                        const Text(
                          'تاريخ الفحص (Date)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              helpText: 'تاريخ الفحص',
                              cancelText: 'إلغاء',
                              confirmText: 'تأكيد',
                            );
                            if (picked != null) {
                              setDialogState(() {
                                inspectionDate = DateFormat('yyyy/MM/dd').format(picked);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F766E)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    inspectionDate,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF0F766E)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Start Checklist Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text(
                              'بدء الفحص',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(dialogCtx);
                                await Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        TransformerChecklistScreen(
                                      form: form,
                                      selectedSubstation: selectedSubstation,
                                      initialDivision: selectedDivision,
                                      initialDepartment: selectedDepartment,
                                      initialContactPerson: contactPersonController.text.trim(),
                                      initialWorkOrder: workOrderController.text.trim(),
                                      initialInspectionDate: inspectionDate,
                                    ),
                                    transitionsBuilder:
                                        (context, animation, secondaryAnimation, child) {
                                      const begin = Offset(0.0, 0.05);
                                      const end = Offset.zero;
                                      const curve = Curves.easeOutCubic;
                                      var tween = Tween(begin: begin, end: end)
                                          .chain(CurveTween(curve: curve));
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                );
                                if (mounted) _loadActiveDrafts();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStartOilSamplingDialog(BuildContext context, FormModel form) {
    SubstationModel selectedSubstation = NationalGridData.substations.firstWhere(
      (s) => s.name == 'JIC',
      orElse: () => NationalGridData.substations.first,
    );
    final Set<String> selectedEquipmentNumbers = <String>{};
    bool showEquipmentError = false;
    final sampleTempController = TextEditingController(text: '');
    String inspectionDate = DateFormat('yyyy/MM/dd').format(DateTime.now());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final allUnits = [
              ...selectedSubstation.transformers,
              ...selectedSubstation.auxTransformers,
            ];

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.science_rounded,
                                color: Color(0xFFD97706),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'بيانات أمر العمل والمحطة',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'نموذج عينة الزيت (Transformer Oil Sampling Form)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Substation Selection & Interactive Equipment Selection
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.15 : 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD97706).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.account_balance_rounded, size: 15, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'محطة التحويل (Substation Name/No)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<SubstationModel>(
                                    value: selectedSubstation,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFD97706)),
                                    items: NationalGridData.substations.map((sub) {
                                      return DropdownMenuItem<SubstationModel>(
                                        value: sub,
                                        child: Text(
                                          '${sub.name} (${sub.transformers.length} محولات - ${sub.region})',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newSub) {
                                      if (newSub != null) {
                                        setDialogState(() {
                                          selectedSubstation = newSub;
                                          selectedEquipmentNumbers.clear();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Interactive Equipment Selection Section
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.checklist_rounded,
                                          size: 17,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'اختر المعدات المطلوب فحصها:',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        ' *',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        showEquipmentError = false;
                                        if (selectedEquipmentNumbers.length ==
                                            allUnits.length) {
                                          selectedEquipmentNumbers.clear();
                                        } else {
                                          selectedEquipmentNumbers.clear();
                                          selectedEquipmentNumbers.addAll(
                                              allUnits.map((u) => u.number));
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.2 : 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFD97706).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        selectedEquipmentNumbers.length ==
                                                allUnits.length
                                            ? 'إلغاء تحديد الكل'
                                            : 'تحديد كل المعدات (${allUnits.length})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Equipment Selection Chips (Multi-Select)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allUnits.map((tx) {
                                  final isSelected =
                                      selectedEquipmentNumbers.contains(tx.number);

                                  return InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        showEquipmentError = false;
                                        if (isSelected) {
                                          selectedEquipmentNumbers.remove(tx.number);
                                        } else {
                                          selectedEquipmentNumbers.add(tx.number);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFD97706)
                                            : (isDark
                                                ? const Color(0xFF1E293B)
                                                : Colors.white),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFD97706)
                                              : (isDark
                                                  ? const Color(0xFF475569)
                                                  : const Color(0xFFCBD5E1)),
                                          width: isSelected ? 1.6 : 1.1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isSelected
                                                ? const Color(0xFFD97706).withValues(alpha: 0.3)
                                                : Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_circle_rounded
                                                : Icons.radio_button_unchecked_rounded,
                                            size: 18,
                                            color: isSelected
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.grey.shade400
                                                    : const Color(0xFF64748B)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            tx.number,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1E293B)),
                                            ),
                                          ),
                                          if (tx.voltage.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${tx.voltage})',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.white.withValues(alpha: 0.9)
                                                    : (isDark
                                                        ? Colors.grey.shade400
                                                        : Colors.grey.shade600),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Sample Temp
                        const Text(
                          'حرارة العينة (Temp °C)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: sampleTempController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'مثال: 45',
                            suffixText: '°C',
                            suffixStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            prefixIcon: const Icon(Icons.thermostat_rounded, size: 17, color: Color(0xFFD97706)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date Picker
                        const Text(
                          'تاريخ السحب (Date)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              helpText: 'تاريخ سحب العينات',
                              cancelText: 'إلغاء',
                              confirmText: 'تأكيد',
                            );
                            if (picked != null) {
                              setDialogState(() {
                                inspectionDate = DateFormat('yyyy/MM/dd').format(picked);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    inspectionDate,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFFD97706)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Validation Alert Card inside Dialog Window
                        if (showEquipmentError && selectedEquipmentNumbers.isEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'تنبيه: يجب اختيار معدة واحدة على الأقل للمتابعة',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Submit Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text(
                              'بدء سحب العينات',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              if (selectedEquipmentNumbers.isEmpty) {
                                setDialogState(() {
                                  showEquipmentError = true;
                                });
                                return;
                              }

                              if (formKey.currentState!.validate()) {
                                final selectedList = allUnits
                                    .where((u) => selectedEquipmentNumbers.contains(u.number))
                                    .toList();

                                Navigator.pop(dialogCtx);
                                await Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        OilSamplingScreen(
                                      form: form,
                                      selectedSubstation: selectedSubstation,
                                      selectedTransformers: selectedList,
                                      initialDivision: selectedSubstation.division,
                                      initialDepartment: selectedSubstation.department,
                                      initialContactPerson: '',
                                      initialSampleTemp: sampleTempController.text.trim(),
                                      initialWorkOrder: '',
                                      initialInspectionDate: inspectionDate,
                                    ),
                                    transitionsBuilder:
                                        (context, animation, secondaryAnimation, child) {
                                      const begin = Offset(0.0, 0.05);
                                      const end = Offset.zero;
                                      const curve = Curves.easeOutCubic;
                                      var tween = Tween(begin: begin, end: end)
                                          .chain(CurveTween(curve: curve));
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                );
                                if (mounted) _loadActiveDrafts();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStartInspectionDialog(BuildContext context, FormModel form) {
    SubstationModel selectedSubstation = NationalGridData.substations.firstWhere(
      (s) => s.name == 'JIC',
      orElse: () => NationalGridData.substations.first,
    );
    final workOrderController = TextEditingController(text: '');
    String inspectionDate = DateFormat('yyyy/MM/dd').format(DateTime.now());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 550,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.power_rounded,
                                color: Color(0xFF0284C7),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'بدء فحص المحولات الشهري',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Monthly Inspection Power Transformer - نقل الكهرباء',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // 1. Substation Selection
                        const Text(
                          '1. اسم محطة التحويل (Substation Name)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<SubstationModel>(
                              value: selectedSubstation,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0284C7)),
                              items: NationalGridData.substations.map((sub) {
                                return DropdownMenuItem<SubstationModel>(
                                  value: sub,
                                  child: Text(
                                    '${sub.name} (${sub.transformers.length} محولات - ${sub.region})',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (newSub) {
                                if (newSub != null) {
                                  setDialogState(() {
                                    selectedSubstation = newSub;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Transformer Numbers Preview
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'المحولات الموجودة في محطة (${selectedSubstation.name}):',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0284C7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: selectedSubstation.transformers.map((tx) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tx.number,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                        if (tx.voltage.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${tx.voltage})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Work Order Input
                        const Text(
                          '2. رقم أمر العمل (Work Order)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: workOrderController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: 'مثال: 8842910',
                            prefixIcon: Icon(Icons.receipt_long_rounded, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال رقم أمر العمل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 3. Inspection Date
                        const Text(
                          '3. تاريخ الفحص (Inspection Date)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              helpText: 'تاريخ الفحص الشهري',
                              cancelText: 'إلغاء',
                              confirmText: 'تأكيد',
                            );
                            if (picked != null) {
                              setDialogState(() {
                                inspectionDate = DateFormat('yyyy/MM/dd').format(picked);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0284C7)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    inspectionDate,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Text(
                                  'تغيير التاريخ',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 4. Start Inspection Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0369A1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: const Text(
                              'بدء الفحص',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(dialogCtx);
                                await Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        GridMaintenanceScreen(
                                      form: form,
                                      selectedSubstation: selectedSubstation,
                                      initialWorkOrder: workOrderController.text.trim(),
                                      initialInspectionDate: inspectionDate,
                                    ),
                                    transitionsBuilder:
                                        (context, animation, secondaryAnimation, child) {
                                      const begin = Offset(0.0, 0.05);
                                      const end = Offset.zero;
                                      const curve = Curves.easeOutCubic;
                                      var tween = Tween(begin: begin, end: end)
                                          .chain(CurveTween(curve: curve));
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                );
                                if (mounted) _loadActiveDrafts();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allForms = SampleFormData.defaultForms;

    // Filter forms based on search query
    final filteredForms = allForms.where((form) {
      final matchesSearch = _searchQuery.isEmpty ||
          form.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          form.subtitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          form.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          form.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildSideDrawer(context, isDark),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'منظومة النماذج الإلكترونية',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          // 3-Bars Menu Button to open sleek Side Drawer
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: IconButton(
              tooltip: 'القائمة الجانبية',
              icon: const Icon(
                Icons.menu_rounded,
                size: 22,
              ),
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;

            // Responsive columns & aspect ratios:
            // Ensures 2 columns on small/medium phones (< 600px)
            int crossAxisCount;
            double childAspectRatio;
            double horizontalPadding;
            double gridSpacing;
            bool isCompact;

            if (screenWidth < 375) {
              // Extra small phones (e.g. 320-360px) -> 2 columns
              crossAxisCount = 2;
              childAspectRatio = 0.96;
              horizontalPadding = 10;
              gridSpacing = 10;
              isCompact = true;
            } else if (screenWidth < 600) {
              // Standard & Large Phones (375-600px) -> Exactly 2 buttons per row
              crossAxisCount = 2;
              childAspectRatio = 1.05;
              horizontalPadding = 14;
              gridSpacing = 12;
              isCompact = true;
            } else if (screenWidth < 900) {
              // Small Tablets (600-900px) -> 3 buttons per row
              crossAxisCount = 3;
              childAspectRatio = 1.16;
              horizontalPadding = 18;
              gridSpacing = 14;
              isCompact = false;
            } else if (screenWidth < 1250) {
              // Large Tablets / Laptops (900-1250px) -> 4 buttons per row
              crossAxisCount = 4;
              childAspectRatio = 1.25;
              horizontalPadding = 24;
              gridSpacing = 16;
              isCompact = false;
            } else {
              // Desktop & Wide Monitors (> 1250px)
              crossAxisCount = 4;
              childAspectRatio = 1.35;
              horizontalPadding = 32;
              gridSpacing = 20;
              isCompact = false;
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1350),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header Banner / Quick Info & Filter
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          14,
                          horizontalPadding,
                          10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Banner Card
                            _buildHeroBanner(
                              context,
                              isDark,
                              isCompact,
                              allForms.length,
                            ),
                            if (_activeDrafts.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildDraftsAlertBanner(context, isDark),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Forms Grid
                    filteredForms.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 56,
                                    color: isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا توجد نماذج متطابقة مع التصنيف المحدد',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              6,
                              horizontalPadding,
                              24,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: gridSpacing,
                                mainAxisSpacing: gridSpacing,
                                childAspectRatio: childAspectRatio,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final form = filteredForms[index];
                                  return _buildFormButtonCard(
                                    context,
                                    form,
                                    isDark,
                                    isCompact,
                                  );
                                },
                                childCount: filteredForms.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _appVersion.isNotEmpty
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                child: Center(
                  heightFactor: 1.0,
                  child: Opacity(
                    opacity: 0.35,
                    child: Text(
                      'الإصدار $_appVersion',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // Sleek Modern Side Drawer
  Widget _buildSideDrawer(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.dynamic_form_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'منظومة النماذج',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'التحول الرقمي المعتمد',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Drawer Options List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                children: [
                  // Section: المسودة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'المسودات والمتابعة',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),

                  // Drafts Option Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activeDrafts.isNotEmpty
                            ? const Color(0xFFD97706).withValues(alpha: 0.5)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: _activeDrafts.isNotEmpty ? 1.4 : 1.0,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bookmark_rounded,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'المسودة',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _activeDrafts.isNotEmpty
                              ? '${_activeDrafts.length} ملفات غير مكتملة'
                              : 'لا توجد مسودات حالية',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_activeDrafts.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_activeDrafts.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToDraftsScreen(context);
                        },
                      ),
                    ),
                  ),

                  // Section: Appearance
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'المظهر والإعدادات',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),

                  // Dark / Light Mode Switch
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: widget.themeModeNotifier,
                    builder: (context, currentMode, _) {
                      final isCurrentlyDark = currentMode == ThemeMode.dark ||
                          (currentMode == ThemeMode.system &&
                              MediaQuery.of(context).platformBrightness ==
                                  Brightness.dark);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isCurrentlyDark ? Colors.amber : primaryColor)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isCurrentlyDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                color: isCurrentlyDark ? Colors.amber.shade400 : primaryColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              isCurrentlyDark ? 'الوضع الداكن مفعّل' : 'الوضع الفاتح مفعّل',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              isCurrentlyDark ? 'اضغط للتحويل إلى الثيم الفاتح' : 'اضغط للتحويل إلى الثيم الداكن',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            trailing: Switch.adaptive(
                              value: isCurrentlyDark,
                              activeTrackColor: primaryColor,
                              onChanged: (val) {
                                widget.themeModeNotifier.value =
                                    val ? ThemeMode.dark : ThemeMode.light;
                              },
                            ),
                            onTap: () {
                              widget.themeModeNotifier.value =
                                  isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Section: System & Updates
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'التحديثات والنظام',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),

                  // Check for Updates Option
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.system_update_alt_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'التحقق من وجود تحديثات',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'فحص الإصدارات الجديدة المتاحة',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.pop(context);
                          AppUpdateService.checkForUpdates(
                            context,
                            showNoUpdateMessage: true,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Drawer Footer Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'النماذج الرقمية',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        _appVersion.isNotEmpty ? 'الإصدار $_appVersion' : 'v1.0.7',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'نظام رسمي',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hero Banner Widget
  Widget _buildHeroBanner(
    BuildContext context,
    bool isDark,
    bool isCompact,
    int totalFormsCount,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14.0 : 18.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFEFF6FF),
                  const Color(0xFFDBEAFE),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: isDark ? 0.3 : 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'لوحة النماذج الذكية',
                            style: TextStyle(
                              fontSize: isCompact ? 10.5 : 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        Text(
                          '$totalFormsCount نماذج مفعلة',
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اختر النموذج لبدء تعبئة المعاملة',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  color: const Color(0xFF2563EB),
                  size: isCompact ? 22 : 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search Input Bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                fontSize: isCompact ? 12.5 : 13.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'ابحث باسم النموذج، التصنيف، أو الرمز...',
                hintStyle: TextStyle(
                  fontSize: isCompact ? 11.5 : 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF2563EB),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DRAFTS (المسودة) UI COMPONENTS (Auto-purge after 24 Hours)
  // ============================================================================


  Widget _buildDraftsAlertBanner(BuildContext context, bool isDark) {
    final count = _activeDrafts.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToDraftsScreen(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF78350F).withValues(alpha: 0.28)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD97706),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFB45309)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bookmark_added_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'تنبيه: ملفات في المسودة',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'لديك $count نموذج بانتظار استكمال التعبئة (صالح لمدة 24 ساعة). اضغط هنا للمتابعة.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'فتح',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // Form Button Card Widget - Fully Responsive & Optimized for 2-column mobile
  Widget _buildFormButtonCard(
    BuildContext context,
    FormModel form,
    bool isDark,
    bool isCompact,
  ) {
    final double iconSize = isCompact ? 38 : 48;
    final double iconInsideSize = isCompact ? 20 : 26;
    final double cardPadding = isCompact ? 10 : 16;
    final double titleFontSize = isCompact ? 13 : 16.5;
    final double categoryFontSize = isCompact ? 10 : 12;
    final double subtitleFontSize = isCompact ? 10 : 12;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => _openForm(context, form),
        borderRadius: BorderRadius.circular(16),
        splashColor: form.primaryColor.withValues(alpha: 0.15),
        highlightColor: form.primaryColor.withValues(alpha: 0.08),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top: Form Icon (Centered)
              Center(
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [form.primaryColor, form.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: form.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    form.icon,
                    color: Colors.white,
                    size: iconInsideSize,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Title and Category & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Category & Time Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            form.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: categoryFontSize,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.timer_outlined,
                            size: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            form.estimatedTime,
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
                    const SizedBox(height: 4),
                    Text(
                      form.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(height: 3),
                      Text(
                        form.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
