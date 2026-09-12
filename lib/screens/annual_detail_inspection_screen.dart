import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/annual_detail_inspection_model.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import '../services/annual_detail_inspection_storage_service.dart';
import '../services/draft_storage_service.dart';
import '../services/pdf_generator_service.dart';
import '../widgets/export_upload_dialog.dart';
import '../widgets/handwritten_signature_dialog.dart';
import 'pdf_preview_screen.dart';

// ============================================================================
// STITCH DESIGN TOKENS (National Grid SA - Responsive Digital Form)
// Project ID: 1191988459271573099
// ============================================================================
class StitchColors {
  static const Color brandNavy = Color(0xFF0B1F3A);
  static const Color brandBlue = Color(0xFF0F294A);
  static const Color brandAccent = Color(0xFF0284C7);
  static const Color brandSuccess = Color(0xFF059669);
  static const Color brandWarning = Color(0xFFD97706);
  static const Color brandDanger = Color(0xFFDC2626);
  static const Color brandSurface = Color(0xFFF8FAFC);
  static const Color brandCard = Color(0xFFFFFFFF);

  // Sky Palette
  static const Color sky900 = Color(0xFF0C4A6E);
  static const Color sky800 = Color(0xFF075985);
  static const Color sky700 = Color(0xFF0369A1);
  static const Color sky600 = Color(0xFF0284C7);
  static const Color sky500 = Color(0xFF0EA5E9);
  static const Color sky400 = Color(0xFF38BDF8);
  static const Color sky300 = Color(0xFF7DD3FC);
  static const Color sky100 = Color(0xFFE0F2FE);
  static const Color sky50 = Color(0xFFF0F9FF);

  // Emerald / Success Palette
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald50 = Color(0xFFECFDF5);

  // Amber / Warning Palette
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber50 = Color(0xFFFFFBEB);

  // Rose / Red Palette
  static const Color rose700 = Color(0xFFBE123C);
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose50 = Color(0xFFFFF1F2);

  // Purple / Violet Palette
  static const Color purple700 = Color(0xFF7E22CE);
  static const Color purple600 = Color(0xFF9333EA);
  static const Color purple100 = Color(0xFFF3E8FF);
  static const Color purple50 = Color(0xFFFAF5FF);

  // Slate Neutral Palette
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);
}

class AnnualDetailInspectionScreen extends StatefulWidget {
  final FormModel? form;
  final SubstationModel? initialSubstation;
  final TransformerInfo? initialEquipment;
  final String initialWorkOrder;
  final AnnualDetailInspectionModel? existingInspection;

  const AnnualDetailInspectionScreen({
    super.key,
    this.form,
    this.initialSubstation,
    this.initialEquipment,
    this.initialWorkOrder = '',
    this.existingInspection,
  });

  @override
  State<AnnualDetailInspectionScreen> createState() =>
      _AnnualDetailInspectionScreenState();
}

class _AnnualDetailInspectionScreenState
    extends State<AnnualDetailInspectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late String _inspectionId;
  late String _createdAt;
  late String _inspectionStatus;

  // Controllers for Section A: General Information
  late TextEditingController _divisionController;
  late TextEditingController _departmentController;
  late TextEditingController _workOrderController;
  late TextEditingController _workGroupController;
  late TextEditingController _substationController;
  late TextEditingController _locationController;
  late TextEditingController _transformerDesigController;
  late TextEditingController _manufacturerController;
  late TextEditingController _makeTypeController;
  late TextEditingController _mvaRatingController;
  late TextEditingController _voltageRatioController;
  late String _typeConnectionHv;
  late String _typeConnectionLv;
  late String _typeConnectionTv;

  // Section 1 Collapsible state
  bool _generalInfoExpanded = true;
  bool _showTabs = true;

  // 35 Inspection Items State
  late List<AnnualInspectionItemModel> _items;
  final Map<int, TextEditingController> _remarksControllers = {};

  // Specialized controllers for Tap Changer readings
  late TextEditingController _tapPositionController;
  late TextEditingController _tapCounterController;

  // Verification & Signatures
  late TextEditingController _commentsController;
  late TextEditingController _inspectedByNameController;
  late TextEditingController _inspectedByBadgeController;
  late String _inspectedDate;
  Uint8List? _inspectedBySignatureBytes;

  late TextEditingController _checkedByNameController;
  late TextEditingController _checkedByBadgeController;
  late String _checkedDate;
  Uint8List? _checkerSignatureBytes;
  bool _isSaving = false;

  static const List<String> _connectionTypeOptions = [
    'GIB',
    'Oil- To-Oil Cable Box',
    'Air Bushing',
    'Outdoor Bushings',
  ];

  static String _normalizeConnectionType(String? val) {
    if (val == null || val.trim().isEmpty) return 'Outdoor Bushings';
    final s = val.trim();
    final low = s.toLowerCase();
    if (low == 'gib') return 'GIB';
    if (low.contains('oil- to-oil') ||
        low.contains('oil-to-oil') ||
        low.contains('oil cable box') ||
        low.contains('cable box') ||
        low.contains('oil')) {
      return 'Oil- To-Oil Cable Box';
    }
    if (low.contains('air bushing') ||
        (low.contains('air') && low.contains('bushing')) ||
        low == 'bushing') {
      return 'Air Bushing';
    }
    if (low.contains('outdoor')) {
      return 'Outdoor Bushings';
    }
    return 'Outdoor Bushings';
  }

  final List<String> _hvConnectionOptions = _connectionTypeOptions;
  final List<String> _lvConnectionOptions = _connectionTypeOptions;
  final List<String> _tvConnectionOptions = _connectionTypeOptions;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF07172B),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF07172B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    // 5 tabs: General Info, Detailed (1-15), Electrical (16-27), DGA & Grounding (28-35), Sign-Off
    _tabController = TabController(length: 5, vsync: this);
    int lastTabIndex = 0;
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.index != lastTabIndex) {
        lastTabIndex = _tabController.index;
        if (!_showTabs) {
          _showTabs = true;
        }
        setState(() {});
      }
    });

    final existing = widget.existingInspection;
    if (existing != null) {
      if (existing.tabIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && existing.tabIndex < _tabController.length) {
            _tabController.animateTo(existing.tabIndex);
          }
        });
      }
      _inspectionId = existing.id;
      _createdAt = existing.createdAt;
      _inspectionStatus = existing.status;

      _divisionController = TextEditingController(text: existing.division);
      _departmentController = TextEditingController(text: existing.department);
      _workOrderController = TextEditingController(text: existing.workOrderNo);
      _workGroupController = TextEditingController(text: existing.workGroup);
      _substationController = TextEditingController(text: existing.substation);
      _locationController = TextEditingController(text: existing.location);
      _transformerDesigController =
          TextEditingController(text: existing.transformerDesignation);
      _manufacturerController =
          TextEditingController(text: existing.manufacturer);
      _makeTypeController = TextEditingController(text: existing.makeType);
      _mvaRatingController = TextEditingController(text: existing.mvaRating);
      _voltageRatioController =
          TextEditingController(text: existing.voltageRatio);

      SubstationModel? matchedSub;
      for (final s in NationalGridData.substations) {
        if (s.name.trim().toLowerCase() ==
                existing.substation.trim().toLowerCase() ||
            s.id.trim().toLowerCase() ==
                existing.substation.trim().toLowerCase()) {
          matchedSub = s;
          break;
        }
      }
      matchedSub ??= widget.initialSubstation ??
          (NationalGridData.substations.isNotEmpty
              ? NationalGridData.substations.first
              : null);

      TransformerInfo? matchedEq;
      if (matchedSub != null) {
        final allUnits = [
          ...matchedSub.transformers,
          ...matchedSub.auxTransformers
        ];
        for (final t in allUnits) {
          if (t.number.trim().toLowerCase() ==
              existing.transformerDesignation.trim().toLowerCase()) {
            matchedEq = t;
            break;
          }
        }
      }
      matchedEq ??= widget.initialEquipment;

      _typeConnectionHv = _normalizeConnectionType(
          existing.typeConnectionHv.trim().isNotEmpty
              ? existing.typeConnectionHv.trim()
              : matchedEq?.effectiveConnectionHv);
      _typeConnectionLv = _normalizeConnectionType(
          existing.typeConnectionLv.trim().isNotEmpty
              ? existing.typeConnectionLv.trim()
              : matchedEq?.effectiveConnectionLv);
      _typeConnectionTv = _normalizeConnectionType(
          existing.typeConnectionTv.trim().isNotEmpty
              ? existing.typeConnectionTv.trim()
              : matchedEq?.effectiveConnectionTv);

      _items = List.from(existing.items);
      if (_items.isEmpty) {
        _items = List<AnnualInspectionItemModel>.from(
            AnnualDetailInspectionModel.defaultItems());
      }

      // Tap position & counter
      final tapPosItem = _items.firstWhere((e) => e.number == 13,
          orElse: () => _items.length > 12 ? _items[12] : _items.first);
      final tapCounterItem = _items.firstWhere((e) => e.number == 14,
          orElse: () => _items.length > 13 ? _items[13] : _items.first);
      _tapPositionController = TextEditingController(
          text: tapPosItem.auxValue?.isNotEmpty == true
              ? tapPosItem.auxValue!
              : (tapPosItem.remarks.isNotEmpty ? tapPosItem.remarks : '9'));
      _tapCounterController = TextEditingController(
          text: tapCounterItem.auxValue?.isNotEmpty == true
              ? tapCounterItem.auxValue!
              : (tapCounterItem.remarks.isNotEmpty
                  ? tapCounterItem.remarks
                  : '048392'));

      _commentsController = TextEditingController(text: existing.comments);
      _inspectedByNameController =
          TextEditingController(text: existing.inspectedByName);
      _inspectedByBadgeController =
          TextEditingController(text: existing.inspectedByBadge);
      _inspectedDate = existing.inspectedDate.isNotEmpty
          ? (existing.inspectedDate.contains(' ')
              ? existing.inspectedDate.split(' ')[0]
              : existing.inspectedDate.split('T')[0])
          : DateFormat('yyyy/MM/dd').format(DateTime.now());
      if (existing.inspectedBySignatureBase64 != null &&
          existing.inspectedBySignatureBase64!.isNotEmpty) {
        try {
          _inspectedBySignatureBytes =
              base64Decode(existing.inspectedBySignatureBase64!);
        } catch (_) {}
      }

      _checkedByNameController =
          TextEditingController(text: existing.checkedByName);
      _checkedByBadgeController =
          TextEditingController(text: existing.checkedByBadge);
      _checkedDate = existing.checkedDate.isNotEmpty
          ? (existing.checkedDate.contains(' ')
              ? existing.checkedDate.split(' ')[0]
              : existing.checkedDate.split('T')[0])
          : DateFormat('yyyy/MM/dd').format(DateTime.now());
      if (existing.checkedBySignatureBase64 != null &&
          existing.checkedBySignatureBase64!.isNotEmpty) {
        try {
          _checkerSignatureBytes =
              base64Decode(existing.checkedBySignatureBase64!);
        } catch (_) {}
      }
    } else {
      _inspectionId = 'ADI_${DateTime.now().millisecondsSinceEpoch}';
      _createdAt = DateTime.now().toIso8601String();
      _inspectionStatus = 'draft';

      SubstationModel? sub = widget.initialSubstation;
      TransformerInfo? eq = widget.initialEquipment;

      // If substation is missing, but equipment is provided, locate the substation
      if (sub == null && eq != null) {
        for (final s in NationalGridData.substations) {
          if (s.transformers.contains(eq) || s.auxTransformers.contains(eq)) {
            sub = s;
            break;
          }
        }
      }

      // If substation still missing, fallback to KFH or first substation
      if (sub == null && NationalGridData.substations.isNotEmpty) {
        sub = NationalGridData.substations.firstWhere(
          (s) => s.name == 'KFH',
          orElse: () => NationalGridData.substations.first,
        );
      }

      // If equipment is missing, find equipment from the substation
      if (eq == null && sub != null) {
        if (sub.transformers.isNotEmpty) {
          eq = sub.transformers.firstWhere(
            (t) => t.number == 'T601',
            orElse: () => sub!.transformers.first,
          );
        } else if (sub.auxTransformers.isNotEmpty) {
          eq = sub.auxTransformers.first;
        }
      }

      _divisionController =
          TextEditingController(text: sub?.division ?? 'SOD / Southern Operating Division');
      _departmentController = TextEditingController(
          text: sub?.department ?? 'Substation Maintenance Dept');
      _workOrderController = TextEditingController(
          text: widget.initialWorkOrder.trim());
      _workGroupController =
          TextEditingController(text: 'Substation Maint. Team 4');
      _substationController =
          TextEditingController(text: sub?.name ?? 'KFH');
      _locationController =
          TextEditingController(text: sub?.region ?? 'JIZAN');
      _transformerDesigController = TextEditingController(
          text: eq?.number ?? 'T601');
      _manufacturerController =
          TextEditingController(text: eq?.manufacturer ?? 'Siemens');
      _makeTypeController =
          TextEditingController(text: 'ONAN / ONAF / OFAF');
      _mvaRatingController =
          TextEditingController(text: eq?.mva ?? '67');
      _voltageRatioController =
          TextEditingController(text: eq?.voltage ?? '132/13.8');

      _typeConnectionHv =
          _normalizeConnectionType(eq?.effectiveConnectionHv);
      _typeConnectionLv =
          _normalizeConnectionType(eq?.effectiveConnectionLv);
      _typeConnectionTv =
          _normalizeConnectionType(eq?.effectiveConnectionTv);

      _items = List<AnnualInspectionItemModel>.from(
          AnnualDetailInspectionModel.defaultItems());

      _tapPositionController = TextEditingController(text: '');
      _tapCounterController = TextEditingController(text: '');

      _commentsController = TextEditingController(text: '');
      _inspectedByNameController = TextEditingController(text: '');
      _inspectedByBadgeController = TextEditingController(text: '');
      _inspectedDate = DateFormat('yyyy/MM/dd').format(DateTime.now());

      _checkedByNameController = TextEditingController(text: '');
      _checkedByBadgeController = TextEditingController(text: '');
      _checkedDate = DateFormat('yyyy/MM/dd').format(DateTime.now());
    }

    // Initialize remarks controllers for items 1 to 35
    for (final it in _items) {
      _remarksControllers[it.number] = TextEditingController(text: it.remarks);
    }

    _tapPositionController.addListener(_onFieldChanged);
    _tapCounterController.addListener(_onFieldChanged);
    _inspectedByNameController.addListener(_onFieldChanged);
    _inspectedByBadgeController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tapPositionController.removeListener(_onFieldChanged);
    _tapCounterController.removeListener(_onFieldChanged);
    _inspectedByNameController.removeListener(_onFieldChanged);
    _inspectedByBadgeController.removeListener(_onFieldChanged);
    _tabController.dispose();
    _divisionController.dispose();
    _departmentController.dispose();
    _workOrderController.dispose();
    _workGroupController.dispose();
    _substationController.dispose();
    _locationController.dispose();
    _transformerDesigController.dispose();
    _manufacturerController.dispose();
    _makeTypeController.dispose();
    _mvaRatingController.dispose();
    _voltageRatioController.dispose();
    _tapPositionController.dispose();
    _tapCounterController.dispose();
    _commentsController.dispose();
    _inspectedByNameController.dispose();
    _inspectedByBadgeController.dispose();
    _checkedByNameController.dispose();
    _checkedByBadgeController.dispose();
    for (final ctrl in _remarksControllers.values) {
      ctrl.dispose();
    }
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  AnnualDetailInspectionModel _buildCurrentModel(String status) {
    // Sync tap values and user remarks to items
    final updatedItems = List<AnnualInspectionItemModel>.from(_items);
    for (int i = 0; i < updatedItems.length; i++) {
      final num = updatedItems[i].number;
      final text = _remarksControllers[num]?.text.trim();
      if (text != null) {
        updatedItems[i] = updatedItems[i].copyWith(remarks: text);
      }
    }

    final idx13 = updatedItems.indexWhere((e) => e.number == 13);
    if (idx13 != -1) {
      updatedItems[idx13] = updatedItems[idx13].copyWith(
        auxValue: _tapPositionController.text.trim(),
        remarks: _tapPositionController.text.trim().isNotEmpty
            ? 'Tap Position: ${_tapPositionController.text.trim()}'
            : '',
      );
    }
    final idx14 = updatedItems.indexWhere((e) => e.number == 14);
    if (idx14 != -1) {
      updatedItems[idx14] = updatedItems[idx14].copyWith(
        auxValue: _tapCounterController.text.trim(),
        remarks: _tapCounterController.text.trim().isNotEmpty
            ? 'Counter: ${_tapCounterController.text.trim()}'
            : '',
      );
    }

    return AnnualDetailInspectionModel(
      id: _inspectionId,
      createdAt: _createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      status: status,
      division: _divisionController.text.trim(),
      department: _departmentController.text.trim(),
      workOrderNo: _workOrderController.text.trim(),
      workGroup: _workGroupController.text.trim(),
      substation: _substationController.text.trim(),
      location: _locationController.text.trim(),
      transformerDesignation: _transformerDesigController.text.trim(),
      manufacturer: _manufacturerController.text.trim(),
      makeType: _makeTypeController.text.trim(),
      mvaRating: _mvaRatingController.text.trim(),
      voltageRatio: _voltageRatioController.text.trim(),
      typeConnectionHv: _typeConnectionHv,
      typeConnectionLv: _typeConnectionLv,
      typeConnectionTv: _typeConnectionTv,
      items: updatedItems,
      comments: _commentsController.text.trim(),
      inspectedByName: _inspectedByNameController.text.trim(),
      inspectedByBadge: _inspectedByBadgeController.text.trim(),
      inspectedDate: _inspectedDate,
      inspectedBySignatureBase64: _inspectedBySignatureBytes != null
          ? base64Encode(_inspectedBySignatureBytes!)
          : null,
      checkedByName: _checkedByNameController.text.trim(),
      checkedByBadge: _checkedByBadgeController.text.trim(),
      checkedDate: _checkedDate,
      checkedBySignatureBase64: _checkerSignatureBytes != null
          ? base64Encode(_checkerSignatureBytes!)
          : null,
      tabIndex: _tabController.index,
    );
  }

  Future<void> _saveInspectionDraft({bool showSnackBar = true}) async {
    setState(() => _isSaving = true);
    final model = _buildCurrentModel('draft');
    final success =
        await AnnualDetailInspectionStorageService.saveInspection(model);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _inspectionStatus = 'draft';
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    success
                        ? 'تم حفظ المسودة بنجاح (صالحة لمدة 24 ساعة للخانة الحالية)'
                        : 'حدث خطأ أثناء حفظ المسودة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: success
                ? StitchColors.emerald600
                : StitchColors.rose600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _handleExportAndUpload() async {
    if (_workOrderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'يلزم إدخال رقم أمر العمل (Work Order No.) قبل المتابعة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: StitchColors.rose600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final model = _buildCurrentModel('completed');
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeSub = model.substation.replaceAll('/', '_').replaceAll(' ', '_');
    final safeEq = model.transformerDesignation.isNotEmpty
        ? model.transformerDesignation.replaceAll('/', '_').replaceAll(' ', '_')
        : 'Transformer';
    final fileName = 'AnnualInspection_${safeSub}_${safeEq}_$dateStr.pdf';

    await ExportUploadProgressDialog.show(
      context: context,
      substation: model.substation,
      equipment: model.transformerDesignation.isNotEmpty
          ? model.transformerDesignation
          : 'Transformer',
      formType: 'Mineral Oil Power Transformers & Reactors Annual Inspection',
      technician: model.inspectedByName.isNotEmpty
          ? model.inspectedByName
          : 'Technician',
      notes: model.comments,
      fileName: fileName,
      onGeneratePdf: () async {
        await AnnualDetailInspectionStorageService.saveInspection(model);
        if (mounted) {
          setState(() => _inspectionStatus = 'completed');
        }
        await DraftStorageService.deleteDraftForForm(
          formId: 'annual_detail_inspection',
          workOrderNo: model.workOrderNo,
          substation: model.substation,
          id: model.id,
        );
        return await PdfGeneratorService.generateAnnualDetailInspectionPdf(
          inspection: model,
          inspectorSignatureBytes: _inspectedBySignatureBytes,
          checkerSignatureBytes: _checkerSignatureBytes,
        );
      },
      onPreview: (pdfBytes, driveUrl) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              workOrder: model.workOrderNo,
              substationName: model.substation,
              equipment: model.transformerDesignation.isNotEmpty
                  ? model.transformerDesignation
                  : 'Transformer',
              formType:
                  'Mineral Oil Power Transformers & Reactors Annual Inspection',
              technician: model.inspectedByName,
              notes: model.comments,
              initialDriveUrl: driveUrl,
              pageTitle:
                  'Mineral Oil Power Transformers & Reactors Annual Inspection',
              pdfFileName:
                  'CL-GM-1600-004-002_${model.workOrderNo.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      },
    );
  }

  void _showSavedInspectionsSheet() async {
    final inspections =
        await AnnualDetailInspectionStorageService.getAllInspections();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? StitchColors.slate900 : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سجل الفحوصات المحفوظة',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '(${inspections.length}) فحص',
                        style: const TextStyle(
                            fontSize: 12, color: StitchColors.slate500),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: inspections.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد فحوصات محفوظة حتى الآن',
                              style: TextStyle(color: StitchColors.slate500),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: inspections.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final it = inspections[idx];
                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? StitchColors.slate800
                                      : StitchColors.slate50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? StitchColors.slate700
                                        : StitchColors.slate200,
                                  ),
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: StitchColors.brandNavy,
                                    child: Icon(Icons.bolt_rounded,
                                        color: Colors.amber, size: 22),
                                  ),
                                  title: Text(
                                    '${it.substation} - ${it.transformerDesignation}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'أمر العمل: ${it.workOrderNo} • ${it.status == "completed" ? "مكتمل" : "مسودة"}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded,
                                            size: 20,
                                            color: StitchColors.sky700),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AnnualDetailInspectionScreen(
                                                existingInspection: it,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: StitchColors.rose600),
                                        onPressed: () async {
                                          await AnnualDetailInspectionStorageService
                                              .deleteInspection(it.id);
                                          if (!ctx.mounted) return;
                                          Navigator.pop(ctx);
                                          _showSavedInspectionsSheet();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateItem(int number,
      {bool? isDone, String? status, String? remarks, String? auxValue}) {
    final idx = _items.indexWhere((e) => e.number == number);
    if (idx != -1) {
      setState(() {
        _items = List<AnnualInspectionItemModel>.from(_items);
        _items[idx] = _items[idx].copyWith(
          isDone: isDone,
          status: status,
          remarks: remarks,
          auxValue: auxValue,
        );
      });
    }
  }

  bool _isItemStatusSelected(int number) {
    final item = _items.firstWhere(
      (e) => e.number == number,
      orElse: () => _items[number - 1],
    );
    return item.status.trim().isNotEmpty;
  }

  int _getTab2CompletedCount() {
    int count = 0;
    for (final num in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15]) {
      if (_isItemStatusSelected(num)) count++;
    }
    if (_tapPositionController.text.trim().isNotEmpty) count++;
    if (_tapCounterController.text.trim().isNotEmpty) count++;
    return count;
  }

  bool _isTab2Complete() => _getTab2CompletedCount() == 15;

  int _getTab3CompletedCount() {
    int count = 0;
    for (int num = 16; num <= 27; num++) {
      if (_isItemStatusSelected(num)) count++;
    }
    return count;
  }

  bool _isTab3Complete() => _getTab3CompletedCount() == 12;

  int _getTab4CompletedCount() {
    int count = 0;
    for (int num = 28; num <= 35; num++) {
      if (_isItemStatusSelected(num)) count++;
    }
    return count;
  }

  bool _isTab4Complete() => _getTab4CompletedCount() == 8;

  bool _isInspectorSignOffComplete() {
    return _inspectedByNameController.text.trim().isNotEmpty &&
        _inspectedByBadgeController.text.trim().isNotEmpty &&
        _inspectedBySignatureBytes != null &&
        _inspectedBySignatureBytes!.isNotEmpty;
  }

  void _showIncompleteTabSnackBar(int tabNumber) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'يرجى إكمال جميع العناصر والخيارات في التبويبة رقم $tabNumber للمتابعة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: StitchColors.amber700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double _calculateProgress() {
    final tabIndex = _tabController.index;
    return ((tabIndex + 1) / 5.0).clamp(0.2, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _calculateProgress();
    final topPadding = MediaQuery.of(context).padding.top;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: const Color(0xFF07172B),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: isDark ? StitchColors.slate950 : const Color(0xFF07172B),
      systemNavigationBarIconBrightness: Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor:
            isDark ? StitchColors.slate950 : const Color(0xFFF1F5F9),
        body: Column(
          children: [
            // Top Section (Unified Status Bar Background + Progress Bar + Executive Header)
            Container(
              color: const Color(0xFF07172B),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ultra-slim glowing gradient progress bar at the very top edge of the app (above status bar / clock & battery)
                  Container(
                    height: 3.5,
                    width: double.infinity,
                    color: const Color(0xFF07172B),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0284C7),
                              Color(0xFF06B6D4),
                              Color(0xFF10B981),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF10B981),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Seamless Status Bar Gap (Dark Navy Color matching the app header behind clock/battery)
                  SizedBox(height: topPadding),

                  // 1. Executive Top Header (National Grid SA)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1024),
                      child: _buildExecutiveHeader(isDark),
                    ),
                  ),
                ],
              ),
            ),

            // Content below header
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1024),
                    child: Column(
                      children: [
                        // 2. Quick Navigation Tabs (Animated Collapsible)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          child: _showTabs
                              ? _buildQuickNavigationTabs(isDark)
                              : const SizedBox.shrink(),
                        ),

                        if (!_showTabs)
                          InkWell(
                            onTap: () => setState(() => _showTabs = true),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              alignment: Alignment.center,
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? StitchColors.slate700
                                      : StitchColors.slate300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),

                        // 3. Tab Content
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is UserScrollNotification) {
                                if (notification.direction == ScrollDirection.reverse) {
                                  // User is scrolling down: collapse tabs to save vertical space
                                  if (_showTabs) {
                                    setState(() => _showTabs = false);
                                  }
                                } else if (notification.direction == ScrollDirection.forward) {
                                  // User is scrolling up: reveal tabs
                                  if (!_showTabs) {
                                    setState(() => _showTabs = true);
                                  }
                                }
                              } else if (notification is ScrollUpdateNotification) {
                                if (notification.metrics.pixels <= 10 && !_showTabs) {
                                  setState(() => _showTabs = true);
                                }
                              }
                              return false;
                            },
                            child: Form(
                              key: _formKey,
                              child: TabBarView(
                                controller: _tabController,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  // Tab 1: General Info
                                  _buildTab1GeneralInfo(isDark),

                                  // Tab 2: Detailed Inspection (Items 1 to 15)
                                  _buildTab2DetailedInspection(isDark),

                                  // Tab 3: Electrical & Temperature Protection (Items 16 to 27)
                                  _buildTab3ElectricalProtection(isDark),

                                  // Tab 4: DGA Sampling, Quality & Grounding (Items 28 to 35)
                                  _buildTab4DgaQualityGrounding(isDark),

                                  // Tab 5: Comments & Sign-Off
                                  _buildTab5CommentsAndSignOff(isDark),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 4. Fixed Bottom Action Bar (Floating Bar)
                        _buildBottomActionBar(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 1. EXECUTIVE HEADER (Redesigned Modern Industrial Theme)
  // ==========================================================================
  Widget _buildExecutiveHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07172B),
            Color(0xFF0C2442),
            Color(0xFF0A1C33),
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF16345C), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Brand Navigation & Status (RTL layout: Back button on the right)
          Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Right side: Back button + National Grid SA brand identity
                Expanded(
                  child: Row(
                    children: [
                      // Back Button to Home Page on the Right
                      Tooltip(
                        message: 'الرجوع إلى الصفحة الرئيسية',
                        child: InkWell(
                          onTap: () => Navigator.maybePop(context),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Directionality(
                              textDirection: TextDirection.ltr,
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                textDirection: TextDirection.ltr,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Red bolt logo on white badge
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFDC2626),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'NATIONAL GRID SA',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Text(
                                      'نقل الكهرباء',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFCA5A5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'GRID MAINTENANCE SYSTEM',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Left side: Saved Inspections & Live Status Pill
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _showSavedInspectionsSheet,
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.folder_shared_rounded,
                          color: Color(0xFFE2E8F0),
                          size: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _inspectionStatus == 'completed'
                            ? StitchColors.emerald500.withValues(alpha: 0.18)
                            : StitchColors.sky500.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _inspectionStatus == 'completed'
                              ? StitchColors.emerald400.withValues(alpha: 0.5)
                              : StitchColors.sky400.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _inspectionStatus == 'completed'
                                  ? StitchColors.emerald400
                                  : StitchColors.sky400,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_inspectionStatus == 'completed'
                                          ? StitchColors.emerald400
                                          : StitchColors.sky400)
                                      .withValues(alpha: 0.7),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _inspectionStatus == 'completed'
                                ? 'مكتمل'
                                : 'جاري الفحص',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: _inspectionStatus == 'completed'
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFF7DD3FC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Row 2: Document Hero Card (Cleaned without CL code, Ref/Rev, or step chip)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2643).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1D4775),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                // Form Main Titles (English & Arabic)
                Text(
                  'Mineral Oil Power Transformers & Reactors Annual Inspection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'الفحص السنوي الدوري للمحولات والمفاعلات الكهربائية الزيتية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF93C5FD),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. QUICK NAVIGATION TABS (Enlarged, Clear & Professional)
  // ==========================================================================
  Widget _buildQuickNavigationTabs(bool isDark) {
    final activeIndex = _tabController.index;

    Widget buildPill(int index, String label, String number) {
      final isActive = activeIndex == index;

      return GestureDetector(
        onTap: () {
          if (index > activeIndex) {
            if (index > 1 && !_isTab2Complete()) {
              _showIncompleteTabSnackBar(2);
              return;
            }
            if (index > 2 && !_isTab3Complete()) {
              _showIncompleteTabSnackBar(3);
              return;
            }
            if (index > 3 && !_isTab4Complete()) {
              _showIncompleteTabSnackBar(4);
              return;
            }
          }
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [
                      Color(0xFF0284C7),
                      Color(0xFF0369A1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive
                ? null
                : (isDark ? StitchColors.slate900 : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF0284C7)
                  : (isDark ? StitchColors.slate700 : const Color(0xFFCBD5E1)),
              width: isActive ? 1.4 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isActive ? 8 : 4,
                offset: Offset(0, isActive ? 3 : 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : (isDark ? StitchColors.slate800 : const Color(0xFFF1F5F9)),
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isActive ? const Color(0xFF0284C7) : StitchColors.slate600,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : (isDark ? StitchColors.slate200 : StitchColors.slate700),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? StitchColors.slate800 : StitchColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            buildPill(0, 'General', '1'),
            const SizedBox(width: 8),
            buildPill(1, 'Detailed (1-15)', '2'),
            const SizedBox(width: 8),
            buildPill(2, 'Protection (16-27)', '3'),
            const SizedBox(width: 8),
            buildPill(3, 'DGA & Ground (28-35)', '4'),
            const SizedBox(width: 8),
            buildPill(4, 'Sign-Off', '5'),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: GENERAL INFORMATION
  // ==========================================================================
  Widget _buildTab1GeneralInfo(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Section Card Container
        Container(
          decoration: BoxDecoration(
            color: isDark ? StitchColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? StitchColors.slate800 : StitchColors.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row (Click to toggle expand)
              InkWell(
                onTap: () {
                  setState(() {
                    _generalInfoExpanded = !_generalInfoExpanded;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? StitchColors.slate800
                        : const Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? StitchColors.slate700
                            : StitchColors.slate200,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: StitchColors.sky100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '1',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: StitchColors.sky800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        '1. GENERAL INFORMATION',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : StitchColors.slate800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Text(
                                        '| البيانات العامة',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: StitchColors.slate500,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? StitchColors.slate700
                                              : StitchColors.slate200,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 10,
                                              color: isDark
                                                  ? StitchColors.slate300
                                                  : StitchColors.slate600,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'للقراءة فقط',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? StitchColors.slate300
                                                    : StitchColors.slate700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Substation, Transformer Spec & Work Order details',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: StitchColors.slate500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _generalInfoExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: StitchColors.slate400,
                      ),
                    ],
                  ),
                ),
              ),

              // Content Fields
              if (_generalInfoExpanded)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      // Grid 2 columns: Work Order & Division
                      Row(
                        children: [
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Work Order No.',
                              isRequired: true,
                              controller: _workOrderController,
                              isDark: isDark,
                              readOnly: false,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Division',
                              controller: _divisionController,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Department & Work Group
                      Row(
                        children: [
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Department',
                              controller: _departmentController,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Work Group',
                              controller: _workGroupController,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Substation & Location
                      Row(
                        children: [
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Substation (SS)',
                              isRequired: true,
                              controller: _substationController,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Location',
                              controller: _locationController,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Transformer Desig & Manufacturer
                      Row(
                        children: [
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Transformer Desig.',
                              controller: _transformerDesigController,
                              isDark: isDark,
                              isBold: true,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Manufacturer',
                              controller: _manufacturerController,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Make / Type & MVA Rating
                      Row(
                        children: [
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'Make / Type',
                              controller: _makeTypeController,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStitchInputField(
                              label: 'MVA Rating',
                              controller: _mvaRatingController,
                              isDark: isDark,
                              isBold: true,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Voltage Ratio (Full Width)
                      _buildStitchInputField(
                        label: 'Voltage Ratio',
                        controller: _voltageRatioController,
                        isDark: isDark,
                        isMonospace: true,
                        readOnly: true,
                      ),
                      const SizedBox(height: 14),

                      // Connection Types Sub-section
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? StitchColors.slate800
                                  : StitchColors.slate100,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Connection Types (HV, LV, TV):',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? StitchColors.slate300
                                          : StitchColors.slate700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? StitchColors.sky900.withValues(alpha: 0.4)
                                        : StitchColors.sky50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark
                                          ? StitchColors.sky700
                                          : StitchColors.sky300,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.touch_app_rounded,
                                        size: 11,
                                        color: StitchColors.sky600,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Selectable',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: StitchColors.sky600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStitchDropdown(
                                    label: 'HV side',
                                    value: _typeConnectionHv,
                                    options: _hvConnectionOptions,
                                    onChanged: (newVal) {
                                      if (newVal != null) {
                                        setState(() => _typeConnectionHv = newVal);
                                      }
                                    },
                                    isDark: isDark,
                                    readOnly: false,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStitchDropdown(
                                    label: 'LV side',
                                    value: _typeConnectionLv,
                                    options: _lvConnectionOptions,
                                    onChanged: (newVal) {
                                      if (newVal != null) {
                                        setState(() => _typeConnectionLv = newVal);
                                      }
                                    },
                                    isDark: isDark,
                                    readOnly: false,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStitchDropdown(
                                    label: 'TV side',
                                    value: _typeConnectionTv,
                                    options: _tvConnectionOptions,
                                    onChanged: (newVal) {
                                      if (newVal != null) {
                                        setState(() => _typeConnectionTv = newVal);
                                      }
                                    },
                                    isDark: isDark,
                                    readOnly: false,
                                  ),
                                ),
                              ],
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

        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================================================
  // TAB 2: DETAILED INSPECTION (Items 1-15 & remaining items)
  // ==========================================================================
  Widget _buildTab2DetailedInspection(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Header: Title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text(
                  '2. Detailed Inspection (Items 1-15)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : StitchColors.slate900,
                  ),
                ),
                Text(
                  '(الفحص التفصيلي)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? StitchColors.slate400 : StitchColors.slate500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Check each component carefully against instructions',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? StitchColors.slate400 : StitchColors.slate500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Item 1: Oil level Main Tank
        _buildSingleInspectionCard(
          itemNumber: 1,
          title: 'Oil level Main Tank',
          desc:
              'Check oil levels and if require correct it in accordance with manufacturer\'s instructions.',
          options: const ['Normal', 'Low Refill', 'Defect', 'N/A'],
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // Item 2: Oil level Tap Changer
        _buildSingleInspectionCard(
          itemNumber: 2,
          title: 'Oil level Tap Changer',
          desc:
              'Check oil levels and if require correct it in accordance with manufacturer\'s instructions.',
          options: const ['Normal', 'Action Req.', 'Defect', 'N/A'],
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // Item 3: Oil level Bushing
        _buildSingleInspectionCard(
          itemNumber: 3,
          title: 'Oil level Bushing',
          desc:
              'Check oil levels across high/low bushings and correct per manufacturer limits.',
          options: const ['Normal', 'Action', 'Defect', 'N/A'],
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // Item 4: Oil level Cable Box Conservator (if applicable)
        _buildSingleInspectionCard(
          itemNumber: 4,
          title: 'Oil level Cable Box Conservator (if applicable)',
          desc:
              'Check oil levels and if require correct it in accordance with manufacturer instructions.',
          options: const ['Normal', 'Low', 'Defect', 'N/A'],
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // Items 5, 6, 7: Silica Gel Grouped Card
        _buildSilicaGelGroupedCard(isDark),
        const SizedBox(height: 10),

        // Items 8-12: Oil Leakage Checks Grouped Card
        _buildOilLeakageGroupedCard(isDark),
        const SizedBox(height: 10),

        // Items 13 & 14: Tap Changer Readings (Grouped Card)
        _buildTapChangerReadingsGroupedCard(isDark),
        const SizedBox(height: 10),

        // Item 15: Bushings Physical Condition
        _buildBushingsConditionCard(isDark),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================================================
  // TAB 3: ELECTRICAL & TEMPERATURE PROTECTION (Items 16 - 27)
  // ==========================================================================
  Widget _buildTab3ElectricalProtection(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Section Header Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? StitchColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? StitchColors.slate800 : StitchColors.slate200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StitchColors.brandAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.electric_meter_outlined,
                  color: StitchColors.brandAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Electrical & Temperature Protection',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : StitchColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'البنود 16 - 27: مقاييس الحرارة، أجهزة الوقاية، المراوح وخزانة التحكم',
                      style: TextStyle(
                        fontSize: 10,
                        color: StitchColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(12, (i) {
          final num = 16 + i;
          final item = _items.firstWhere((e) => e.number == num,
              orElse: () => _items[num - 1]);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildExtendedItemRow(item, isDark),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================================================
  // TAB 4: DGA SAMPLING, QUALITY & GROUNDING (Items 28 - 35)
  // ==========================================================================
  Widget _buildTab4DgaQualityGrounding(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Section Header Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? StitchColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? StitchColors.slate800 : StitchColors.slate200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StitchColors.purple700.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.science_outlined,
                  color: StitchColors.purple700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DGA Sampling, Quality & Grounding',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : StitchColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'البنود 28 - 35: تحاليل الغازات المذابة بالزيت، الجودة، وتأريض جسم المحول',
                      style: TextStyle(
                        fontSize: 10,
                        color: StitchColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(8, (i) {
          final num = 28 + i;
          final item = _items.firstWhere((e) => e.number == num,
              orElse: () => _items[num - 1]);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildExtendedItemRow(item, isDark),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================================================
  // TAB 5: COMMENTS & SIGN-OFF
  // ==========================================================================
  Widget _buildTab5CommentsAndSignOff(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Comments Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? StitchColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? StitchColors.slate800 : StitchColors.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.chat_bubble_outline_rounded,
                          color: StitchColors.sky600, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Comments (if Any):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: StitchColors.slate800,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '| ملاحظات الفحص',
                        style: TextStyle(
                          fontSize: 11,
                          color: StitchColors.slate400,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: StitchColors.slate100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: StitchColors.slate500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentsController,
                maxLines: 4,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText:
                      'Enter findings, anomalies, weather condition or immediate maintenance remarks...',
                  hintStyle: const TextStyle(
                      fontSize: 11.5, color: StitchColors.slate400),
                  filled: true,
                  fillColor:
                      isDark ? StitchColors.slate800 : StitchColors.slate50,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? StitchColors.slate700
                          : StitchColors.slate200,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? StitchColors.slate700
                          : StitchColors.slate200,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: StitchColors.sky500),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Field Sign-Off Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? StitchColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? StitchColors.slate800 : StitchColors.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.draw_rounded,
                          color: StitchColors.slate700, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'FIELD SIGN-OFF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: StitchColors.slate900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '| الاعتماد والتوقيع',
                        style: TextStyle(
                          fontSize: 11,
                          color: StitchColors.slate500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: StitchColors.slate100,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'SEC ID Verified',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: StitchColors.slate600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // ========================================================
              // 1. INSPECTOR SIGN-OFF BLOCK
              // ========================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? StitchColors.slate800.withValues(alpha: 0.5) : StitchColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? StitchColors.slate700 : StitchColors.slate200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 16, color: StitchColors.sky600),
                        const SizedBox(width: 6),
                        Text(
                          'Inspected By (الفاحص)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : StitchColors.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildStitchInputField(
                            label: 'Inspected By',
                            controller: _inspectedByNameController,
                            isDark: isDark,
                            isBold: true,
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _buildStitchInputField(
                            label: 'Badge No.',
                            controller: _inspectedByBadgeController,
                            isDark: isDark,
                            isMonospace: true,
                            isBold: true,
                            isRequired: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Digital Signature (توقيع الفاحص)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: StitchColors.slate700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text('*',
                            style: TextStyle(
                                color: StitchColors.rose600, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSignatureTarget(
                      title: 'Tap to draw or verify inspector signature',
                      signatureBytes: _inspectedBySignatureBytes,
                      onTap: () async {
                        final bytes = await HandwrittenSignatureDialog.show(
                          context,
                          isDark: isDark,
                        );
                        if (bytes != null) {
                          setState(() => _inspectedBySignatureBytes = bytes);
                        }
                      },
                      onClear: () {
                        setState(() => _inspectedBySignatureBytes = null);
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final parsed = DateTime.tryParse(_inspectedDate.replaceAll('/', '-')) ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: parsed,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _inspectedDate = DateFormat('yyyy/MM/dd').format(picked);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 13, color: StitchColors.sky600),
                            const SizedBox(width: 6),
                            const Text(
                              'Date: ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: StitchColors.slate500,
                              ),
                            ),
                            Text(
                              _inspectedDate,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: isDark ? StitchColors.slate300 : StitchColors.slate700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ========================================================
              // 2. SUPERVISOR / CHECKED BY SIGN-OFF BLOCK
              // ========================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? StitchColors.slate800.withValues(alpha: 0.5) : StitchColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? StitchColors.slate700 : StitchColors.slate200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            size: 16, color: StitchColors.emerald600),
                        const SizedBox(width: 6),
                        Text(
                          'Checked By / Supervisor (اعتماد المشرف)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : StitchColors.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildStitchInputField(
                            label: 'Checked By (Supervisor)',
                            controller: _checkedByNameController,
                            isDark: isDark,
                            isBold: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: _buildStitchInputField(
                            label: 'Badge No.',
                            controller: _checkedByBadgeController,
                            isDark: isDark,
                            isMonospace: true,
                            isBold: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Supervisor Signature (توقيع المشرف)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: StitchColors.slate700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildSignatureTarget(
                      title: 'Tap to draw supervisor verification signature',
                      signatureBytes: _checkerSignatureBytes,
                      onTap: () async {
                        final bytes = await HandwrittenSignatureDialog.show(
                          context,
                          isDark: isDark,
                        );
                        if (bytes != null) {
                          setState(() => _checkerSignatureBytes = bytes);
                        }
                      },
                      onClear: () {
                        setState(() => _checkerSignatureBytes = null);
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final parsed = DateTime.tryParse(_checkedDate.replaceAll('/', '-')) ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: parsed,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _checkedDate = DateFormat('yyyy/MM/dd').format(picked);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 13, color: StitchColors.emerald600),
                            const SizedBox(width: 6),
                            const Text(
                              'Date: ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: StitchColors.slate500,
                              ),
                            ),
                            Text(
                              _checkedDate,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: isDark ? StitchColors.slate300 : StitchColors.slate700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Policies & Procedures Portal Reference Link
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? StitchColors.slate800
                          : StitchColors.slate100,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Policies & Procedures Portal:',
                      style: TextStyle(
                          fontSize: 10, color: StitchColors.slate400),
                    ),
                    Text(
                      'ngridsa-apps/amas',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: StitchColors.sky600,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================================================
  // FLOATING BOTTOM BAR (Stitch BottomNavigationFloatingBar)
  // ==========================================================================
  Widget _buildBottomActionBar(bool isDark) {
    final currentTab = _tabController.index;
    final isSubmit = currentTab == 4;

    bool isNextEnabled = true;
    String nextText = 'Next: Detailed Inspection (1-15)';
    if (currentTab == 1) {
      final count = _getTab2CompletedCount();
      isNextEnabled = count == 15;
      nextText = isNextEnabled
          ? 'Next: Protection (16-27)'
          : 'Next: Protection ($count/15)';
    } else if (currentTab == 2) {
      final count = _getTab3CompletedCount();
      isNextEnabled = count == 12;
      nextText = isNextEnabled
          ? 'Next: DGA & Grounding (28-35)'
          : 'Next: DGA & Grounding ($count/12)';
    } else if (currentTab == 3) {
      final count = _getTab4CompletedCount();
      isNextEnabled = count == 8;
      nextText = isNextEnabled
          ? 'Next: Comments & Sign-Off'
          : 'Next: Comments ($count/8)';
    } else if (currentTab == 4) {
      nextText = 'Submit Inspection';
    }

    final isExportEnabled = _isInspectorSignOffComplete();

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? StitchColors.slate900.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? StitchColors.slate800 : StitchColors.slate200,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Save Draft button
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => _saveInspectionDraft(),
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    isDark ? StitchColors.slate800 : StitchColors.slate100,
                foregroundColor:
                    isDark ? StitchColors.slate300 : StitchColors.slate700,
                side: BorderSide(
                  color: isDark ? StitchColors.slate700 : StitchColors.slate300,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.bookmark_border_rounded, size: 16),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'حفظ المسودة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 8),

          // Unified Submit & Export Button
          if (isSubmit) ...[
            Expanded(
              flex: 3,
              child: ElevatedButton(
                onPressed: isExportEnabled ? _handleExportAndUpload : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: StitchColors.emerald600,
                  disabledBackgroundColor: isDark
                      ? StitchColors.slate800
                      : StitchColors.slate200,
                  disabledForegroundColor: isDark
                      ? StitchColors.slate600
                      : StitchColors.slate400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isExportEnabled ? 3 : 0,
                  shadowColor:
                      StitchColors.emerald600.withValues(alpha: 0.35),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.send_and_archive_rounded, size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'تصدير وإرسال PDF',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Next Tab Button
            Expanded(
              flex: currentTab > 0 ? 2 : 2,
              child: ElevatedButton(
                onPressed: isNextEnabled
                    ? () {
                        if (currentTab < 4) {
                          _tabController.animateTo(currentTab + 1);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: StitchColors.sky700,
                  disabledBackgroundColor: isDark
                      ? StitchColors.slate800
                      : StitchColors.slate200,
                  disabledForegroundColor: isDark
                      ? StitchColors.slate600
                      : StitchColors.slate400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isNextEnabled ? 2 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        nextText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER WIDGETS: CARDS & INPUTS
  // ==========================================================================

  Widget _buildStitchInputField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    bool isRequired = false,
    bool isBold = false,
    bool isMonospace = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? StitchColors.slate400 : StitchColors.slate600,
                ),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 2),
              const Text('*',
                  style: TextStyle(color: StitchColors.rose600, fontSize: 11)),
            ],
            if (readOnly) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.lock_outline_rounded,
                size: 11,
                color: isDark ? StitchColors.slate500 : StitchColors.slate400,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          enableInteractiveSelection: !readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontFamily: isMonospace ? 'monospace' : null,
            color: readOnly
                ? (isDark ? Colors.white70 : StitchColors.slate800)
                : (isDark ? Colors.white : StitchColors.slate900),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: readOnly
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                : (isDark ? StitchColors.slate800 : StitchColors.slate50),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? StitchColors.slate700 : StitchColors.slate300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: readOnly
                    ? (isDark ? StitchColors.slate800 : const Color(0xFFCBD5E1))
                    : (isDark ? StitchColors.slate700 : StitchColors.slate300),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: readOnly
                    ? (isDark ? StitchColors.slate800 : const Color(0xFFCBD5E1))
                    : StitchColors.sky500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStitchDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?>? onChanged,
    required bool isDark,
    bool readOnly = false,
  }) {
    final effectiveValue = readOnly
        ? (value.trim().isNotEmpty ? value.trim() : options.first)
        : (options.contains(value) ? value : options.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: StitchColors.slate500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (readOnly) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.lock_outline_rounded,
                size: 10,
                color: isDark ? StitchColors.slate500 : StitchColors.slate400,
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: readOnly ? 8 : 2),
          decoration: BoxDecoration(
            color: readOnly
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                : (isDark ? StitchColors.slate800 : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: readOnly
                  ? (isDark ? StitchColors.slate800 : const Color(0xFFCBD5E1))
                  : (isDark ? StitchColors.slate700 : StitchColors.sky400),
            ),
          ),
          child: readOnly
              ? SizedBox(
                  height: 24,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      effectiveValue,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : StitchColors.slate800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveValue,
                    isExpanded: true,
                    isDense: true,
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: isDark ? StitchColors.slate400 : StitchColors.sky600,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : StitchColors.slate800,
                    ),
                    dropdownColor:
                        isDark ? StitchColors.slate900 : Colors.white,
                    items: options
                        .map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(
                                opt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : StitchColors.slate800,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSingleInspectionCard({
    required int itemNumber,
    required String title,
    required String desc,
    required List<String> options,
    required bool isDark,
  }) {
    final item = _items.firstWhere((e) => e.number == itemNumber,
        orElse: () => _items[itemNumber - 1]);
    final currentStatus = item.status;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? StitchColors.slate800 : StitchColors.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Number, Title & Camera Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$itemNumber',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : StitchColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: StitchColors.slate500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'ملاحظات البند',
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: item.remarks.isNotEmpty
                      ? StitchColors.sky600
                      : StitchColors.slate400,
                  size: 22,
                ),
                onPressed: () {
                  _showItemNotesDialog(itemNumber, title);
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Options Row
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? StitchColors.slate800
                      : StitchColors.slate100,
                ),
              ),
            ),
            child: Row(
              children: options.map((opt) {
                // Map standard options to model status
                bool isSelected = false;
                if (opt == 'Normal' &&
                    (currentStatus == 'Done' || currentStatus == 'Normal')) {
                  isSelected = true;
                } else if ((opt == 'Low Refill' ||
                        opt == 'Action Req.' ||
                        opt == 'Action' ||
                        opt == 'Low') &&
                    (currentStatus == 'Check' || currentStatus == opt)) {
                  isSelected = true;
                } else if (opt == 'Defect' && currentStatus == 'Defect') {
                  isSelected = true;
                } else if (opt == 'N/A' && currentStatus == 'N/A') {
                  isSelected = true;
                }

                Color activeBg = StitchColors.emerald600;
                if (opt.contains('Low') || opt.contains('Action')) {
                  activeBg = StitchColors.amber500;
                } else if (opt == 'Defect') {
                  activeBg = StitchColors.rose600;
                } else if (opt == 'N/A') {
                  activeBg = StitchColors.slate700;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () {
                        String newStatus = 'Done';
                        if (opt.contains('Low') || opt.contains('Action')) {
                          newStatus = 'Check';
                        } else if (opt == 'Defect') {
                          newStatus = 'Defect';
                        } else if (opt == 'N/A') {
                          newStatus = 'N/A';
                        }
                        _updateItem(itemNumber, status: newStatus);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeBg
                              : (isDark
                                  ? StitchColors.slate800
                                  : StitchColors.slate50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? activeBg
                                : (isDark
                                    ? StitchColors.slate700
                                    : StitchColors.slate200),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? StitchColors.slate400
                                    : StitchColors.slate600),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSilicaGelGroupedCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? StitchColors.slate800 : StitchColors.slate200,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 24,
                decoration: BoxDecoration(
                  color: StitchColors.amber50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: StitchColors.amber100),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '5-7',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: StitchColors.amber700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Silica Gel Breathers Condition',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: StitchColors.slate900,
                      ),
                    ),
                    Text(
                      'Check color saturation (replace if pink/moist, standard blue/orange dry)',
                      style:
                          TextStyle(fontSize: 10, color: StitchColors.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Item 5: Main Tank
          _buildSilicaRow(
            itemNumber: 5,
            label: '5. Silica gel Main Tank',
            sublabel: 'Check color (Dry / Blue or Amber)',
            isDark: isDark,
          ),
          const Divider(height: 14),

          // Item 6: Cable Box
          _buildSilicaRow(
            itemNumber: 6,
            label: '6. Silica gel Cable Box',
            sublabel: 'If applicable',
            isDark: isDark,
          ),
          const Divider(height: 14),

          // Item 7: Tap Changer
          _buildSilicaRow(
            itemNumber: 7,
            label: '7. Silica gel Tap Changer',
            sublabel: 'Check color & oil cup level',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSilicaRow({
    required int itemNumber,
    required String label,
    required String sublabel,
    required bool isDark,
  }) {
    final item = _items.firstWhere((e) => e.number == itemNumber,
        orElse: () => _items[itemNumber - 1]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : StitchColors.slate800,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: StitchColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'ملاحظات البند',
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: item.remarks.isNotEmpty
                      ? StitchColors.sky600
                      : StitchColors.slate400,
                  size: 20,
                ),
                onPressed: () {
                  _showItemNotesDialog(itemNumber, label);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildExtendedStatusBtn(itemNumber, 'Normal', 'Done',
                  StitchColors.emerald600, item.status == 'Done', isDark),
              const SizedBox(width: 4),
              _buildExtendedStatusBtn(itemNumber, 'Action', 'Check',
                  StitchColors.amber500, item.status == 'Check', isDark),
              const SizedBox(width: 4),
              _buildExtendedStatusBtn(itemNumber, 'Defect', 'Defect',
                  StitchColors.rose600, item.status == 'Defect', isDark),
              const SizedBox(width: 4),
              _buildExtendedStatusBtn(itemNumber, 'N/A', 'N/A',
                  StitchColors.slate700, item.status == 'N/A', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOilLeakageGroupedCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? StitchColors.slate800 : StitchColors.slate200,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 24,
                      decoration: BoxDecoration(
                        color: StitchColors.rose50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: StitchColors.rose100),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '8-12',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: StitchColors.rose700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Oil Leakage Inspection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : StitchColors.slate900,
                            ),
                          ),
                          const Text(
                            'Inspect seams, valves, gaskets & rectify if necessary',
                            style: TextStyle(
                                fontSize: 10, color: StitchColors.slate500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: StitchColors.emerald50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: StitchColors.emerald100),
                ),
                child: const Text(
                  'All Clear',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: StitchColors.emerald700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Items 8 to 12
          _buildLeakageRow(8, '8. Oil leakage Main Tank', isDark),
          const SizedBox(height: 6),
          _buildLeakageRow(9, '9. Oil leakage Tap Changer', isDark),
          const SizedBox(height: 6),
          _buildLeakageRow(10, '10. Oil leakage Radiators', isDark),
          const SizedBox(height: 6),
          _buildLeakageRow(11, '11. Oil leakage Cable Boxes', isDark),
          const SizedBox(height: 6),
          _buildLeakageRow(12, '12. Oil leakage Bushing', isDark),
        ],
      ),
    );
  }

  Widget _buildLeakageRow(int itemNumber, String label, bool isDark) {
    final item = _items.firstWhere((e) => e.number == itemNumber,
        orElse: () => _items[itemNumber - 1]);
    final isNoLeak = item.status == 'Done';
    final isLeak = item.status == 'Defect';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate800 : StitchColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? StitchColors.slate700
              : StitchColors.slate200.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : StitchColors.slate800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'ملاحظات البند',
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: item.remarks.isNotEmpty
                      ? StitchColors.sky600
                      : StitchColors.slate400,
                  size: 20,
                ),
                onPressed: () => _showItemNotesDialog(itemNumber, label),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // No Leak button
              Expanded(
                child: InkWell(
                  onTap: () {
                    _updateItem(itemNumber, status: 'Done');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isNoLeak
                          ? StitchColors.emerald600
                          : (isDark ? StitchColors.slate900 : Colors.white),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isNoLeak
                            ? StitchColors.emerald600
                            : (isDark
                                ? StitchColors.slate700
                                : StitchColors.slate300),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'No Leak',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isNoLeak
                            ? Colors.white
                            : (isDark
                                ? StitchColors.slate400
                                : StitchColors.slate600),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Leakage button
              Expanded(
                child: InkWell(
                  onTap: () {
                    _updateItem(itemNumber, status: 'Defect');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isLeak
                          ? StitchColors.rose600
                          : (isDark ? StitchColors.slate900 : Colors.white),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLeak
                            ? StitchColors.rose600
                            : (isDark
                                ? StitchColors.slate700
                                : StitchColors.slate300),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Leakage',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isLeak
                            ? Colors.white
                            : (isDark
                                ? StitchColors.slate400
                                : StitchColors.slate600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTapChangerReadingsGroupedCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? StitchColors.slate800 : StitchColors.slate200,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 24,
                decoration: BoxDecoration(
                  color: StitchColors.purple50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: StitchColors.purple100),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '13-14',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: StitchColors.purple700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Tap Changer Readings',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: StitchColors.slate900,
                      ),
                    ),
                    Text(
                      'Record current tap mechanism status and mechanical operations counter',
                      style: TextStyle(
                          fontSize: 10, color: StitchColors.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Two side-by-side containers
          Row(
            children: [
              // 13: Tap Position
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? StitchColors.slate800 : StitchColors.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? StitchColors.slate700
                          : StitchColors.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '13. Tap Position',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: StitchColors.slate700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('Pos:',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: StitchColors.slate400)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextFormField(
                              controller: _tapPositionController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: isDark
                                    ? StitchColors.slate900
                                    : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? StitchColors.slate700
                                        : StitchColors.slate300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Nominal range: 1 to 17',
                        style: TextStyle(
                            fontSize: 9.5, color: StitchColors.slate500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 14: Counter Reading
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? StitchColors.slate800 : StitchColors.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? StitchColors.slate700
                          : StitchColors.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '14. Counter Reading',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: StitchColors.slate700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined,
                              color: StitchColors.slate400, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextFormField(
                              controller: _tapCounterController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                letterSpacing: 1,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: isDark
                                    ? StitchColors.slate900
                                    : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? StitchColors.slate700
                                        : StitchColors.slate300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Total mechanical ops',
                        style: TextStyle(
                            fontSize: 9.5, color: StitchColors.slate500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBushingsConditionCard(bool isDark) {
    final item = _items.firstWhere((e) => e.number == 15,
        orElse: () => _items[14]);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? StitchColors.slate800 : StitchColors.slate200,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '15',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Bushings Condition',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: StitchColors.slate900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Check condition for drips, cracks, dust contamination and take corrective action (earliest feasible).',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: StitchColors.slate500,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'ملاحظات البند',
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: item.remarks.isNotEmpty
                      ? StitchColors.sky600
                      : StitchColors.slate400,
                  size: 22,
                ),
                onPressed: () => _showItemNotesDialog(15, 'Bushings Condition'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3-Option selector
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? StitchColors.slate800
                      : StitchColors.slate100,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildBushingOptionPill(
                  itemNumber: 15,
                  label: 'Clean / Intact',
                  status: 'Done',
                  activeColor: StitchColors.emerald600,
                  isSelected: item.status == 'Done',
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildBushingOptionPill(
                  itemNumber: 15,
                  label: 'Dusty / Wash Req.',
                  status: 'Check',
                  activeColor: StitchColors.amber500,
                  isSelected: item.status == 'Check',
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildBushingOptionPill(
                  itemNumber: 15,
                  label: 'Chipped / Defect',
                  status: 'Defect',
                  activeColor: StitchColors.rose600,
                  isSelected: item.status == 'Defect',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBushingOptionPill({
    required int itemNumber,
    required String label,
    required String status,
    required Color activeColor,
    required bool isSelected,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _updateItem(itemNumber, status: status);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : (isDark ? StitchColors.slate800 : StitchColors.slate50),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? StitchColors.slate700 : StitchColors.slate200),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? StitchColors.slate400 : StitchColors.slate600),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }


  Widget _buildExtendedItemRow(AnnualInspectionItemModel item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? StitchColors.slate800 : StitchColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? StitchColors.slate700 : StitchColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: StitchColors.sky100,
                child: Text(
                  '${item.number}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: StitchColors.sky800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.nameEn,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : StitchColors.slate800,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'ملاحظات البند',
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: item.remarks.isNotEmpty
                      ? StitchColors.sky600
                      : StitchColors.slate400,
                  size: 22,
                ),
                onPressed: () => _showItemNotesDialog(item.number, item.nameEn),
              ),
            ],
          ),
          if (item.desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              item.desc,
              style:
                  const TextStyle(fontSize: 9.5, color: StitchColors.slate500),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _buildExtendedStatusBtn(item.number, 'Normal', 'Done',
                  StitchColors.emerald600, item.status == 'Done', isDark),
              const SizedBox(width: 4),
              _buildExtendedStatusBtn(item.number, 'Check', 'Check',
                  StitchColors.amber500, item.status == 'Check', isDark),
              const SizedBox(width: 4),
              _buildExtendedStatusBtn(item.number, 'Defect', 'Defect',
                  StitchColors.rose600, item.status == 'Defect', isDark),
              const SizedBox(width: 4),
              _buildExtendedStatusBtn(item.number, 'N/A', 'N/A',
                  StitchColors.slate700, item.status == 'N/A', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtendedStatusBtn(
    int number,
    String label,
    String statusValue,
    Color activeColor,
    bool isSelected,
    bool isDark,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => _updateItem(number, status: statusValue),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : (isDark ? StitchColors.slate900 : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? StitchColors.slate700 : StitchColors.slate300),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isDark ? StitchColors.slate400 : StitchColors.slate600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureTarget({
    required String title,
    required Uint8List? signatureBytes,
    required VoidCallback onTap,
    required VoidCallback onClear,
    required bool isDark,
  }) {
    if (signatureBytes != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? StitchColors.slate800 : StitchColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: StitchColors.emerald500.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: StitchColors.slate200),
              ),
              child: Image.memory(signatureBytes, fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_rounded,
                            color: StitchColors.emerald600, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Verified Digital Sign',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: StitchColors.emerald600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'National Grid SA Standard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: StitchColors.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: StitchColors.sky500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: StitchColors.sky700, size: 16),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: StitchColors.rose500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded,
                    color: StitchColors.rose600, size: 16),
              ),
            ),
          ],
        ),
      );
    }

    // Empty signature target with dashed border
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isDark
              ? StitchColors.slate800.withValues(alpha: 0.5)
              : StitchColors.slate50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: StitchColors.slate300,
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_note_rounded,
                color: StitchColors.slate400, size: 22),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: StitchColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemNotesDialog(int number, String title) {
    final item = _items.firstWhere((e) => e.number == number,
        orElse: () => _items[number - 1]);
    final textCtrl = TextEditingController(text: item.remarks);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notes_rounded, color: StitchColors.sky700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Item $number: $title',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: TextField(
            controller: textCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter specific note, observation or remark...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateItem(number, remarks: textCtrl.text.trim());
              Navigator.pop(ctx);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: StitchColors.sky700),
            child: const Text('Save Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
