import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import '../models/form_model.dart';
import '../models/substation_model.dart';
import '../services/pdf_generator_service.dart';
import 'pdf_preview_screen.dart';

class SampleAcknowledgementScreen extends StatefulWidget {
  final FormModel form;
  final SubstationModel initialSubstation;
  final TransformerInfo? initialEquipment;
  final String initialWorkOrder;

  const SampleAcknowledgementScreen({
    super.key,
    required this.form,
    required this.initialSubstation,
    this.initialEquipment,
    this.initialWorkOrder = '',
  });

  @override
  State<SampleAcknowledgementScreen> createState() =>
      _SampleAcknowledgementScreenState();
}

class _SampleAcknowledgementScreenState
    extends State<SampleAcknowledgementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Substation & Equipment state (from NationalGridData)
  late SubstationModel _selectedSubstation;
  TransformerInfo? _selectedEquipment;

  // Controllers for Step 1: SAMPLE & SUBSTATION INFO
  late TextEditingController _workOrderController;
  late TextEditingController _refNoController;
  String _selectedLab = 'RYD';
  late TextEditingController _externalLabController;
  late TextEditingController _ibmMaximoController;
  late TextEditingController _cityNameController;
  late TextEditingController _substationNameController;
  late TextEditingController _reportSendToController;
  late TextEditingController _sampleByController;
  late String _sampleDate;
  late String _receivedDate;

  // Controllers for Step 2: EQUIPMENT & TESTS
  String _equipmentType = 'Transformer';
  late TextEditingController _equipmentDetailController;
  late TextEditingController _otherEquipmentController;
  late TextEditingController _manufacturerController;
  late TextEditingController _manufacturerYearController;
  late TextEditingController _oilTempController;
  late TextEditingController _voltageController;
  late TextEditingController _capacityController;
  late TextEditingController _serialNoController;
  String _reasonOfSample = 'PM';
  late TextEditingController _otherReasonController;
  final Set<String> _selectedTests = {
    'Quality Test',
    'D.G.A',
    'Breakdown & Water',
  };

  // Controllers for Step 3: RECEIVING SAMPLE
  late TextEditingController _senderNameController;
  late TextEditingController _senderIdController;
  late TextEditingController _senderSignatureController;
  Uint8List? _senderSignatureBytes;
  late TextEditingController _syringeCaseController;
  late TextEditingController _bottleCaseController;
  late TextEditingController _remarksController;
  late TextEditingController _receivedByController;
  late TextEditingController _employeeIdController;
  late TextEditingController _receiverSignatureController;

  // Test definitions matching Stitch prototype with bilingual subtitles and icons
  static const List<Map<String, dynamic>> _testsList = [
    {
      'key': 'Quality Test',
      'title': 'Quality Test',
      'subtitle': 'اختبار الجودة وخصائص الزيت العازل',
      'icon': Icons.verified_outlined,
    },
    {
      'key': 'D.G.A',
      'title': 'D.G.A',
      'subtitle': 'تحليل الغازات الذائبة بالزيت',
      'icon': Icons.bubble_chart_rounded,
    },
    {
      'key': 'SF-6',
      'title': 'SF-6',
      'subtitle': 'غاز سداسي فلوريد الكبريت',
      'icon': Icons.air_rounded,
    },
    {
      'key': 'Breakdown & Water',
      'title': 'Breakdown & Water',
      'subtitle': 'جهد الانهيار ونسبة الماء',
      'icon': Icons.water_drop_outlined,
    },
    {
      'key': 'D.B.D.S',
      'title': 'D.B.D.S',
      'subtitle': 'مركب DBDS المانع',
      'icon': Icons.science_rounded,
    },
    {
      'key': 'Corrosive',
      'title': 'Corrosive',
      'subtitle': 'الكبريت الأكّال والترسيب النحاسي',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'key': 'Furanic',
      'title': 'Furanic',
      'subtitle': 'مركبات الفوران لتقييم تآكل العوازل',
      'icon': Icons.biotech_rounded,
    },
    {
      'key': 'Passivator',
      'title': 'Passivator',
      'subtitle': 'المثبطات الحامية والمواد المانعة للأكسدة',
      'icon': Icons.shield_outlined,
    },
    {
      'key': 'MeOHc',
      'title': 'MeOHc',
      'subtitle': 'فحص الميثانول MeOHc لتقييم العوازل الورقية',
      'icon': Icons.opacity_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _selectedSubstation = widget.initialSubstation;
    final allUnits = [
      ..._selectedSubstation.transformers,
      ..._selectedSubstation.auxTransformers,
    ];
    _selectedEquipment = widget.initialEquipment ??
        (allUnits.isNotEmpty ? allUnits.first : null);

    _workOrderController =
        TextEditingController(text: widget.initialWorkOrder);
    _refNoController = TextEditingController(text: '');
    _externalLabController = TextEditingController(text: '');
    _ibmMaximoController = TextEditingController(text: '');
    _cityNameController =
        TextEditingController(text: _selectedSubstation.region);
    _substationNameController =
        TextEditingController(text: _selectedSubstation.name);
    _reportSendToController = TextEditingController(text: '');
    _sampleByController = TextEditingController(text: '');
    _sampleDate = DateFormat('yyyy/MM/dd').format(DateTime.now());
    _receivedDate = '';

    _equipmentDetailController =
        TextEditingController(text: _selectedEquipment?.number ?? '');
    _otherEquipmentController = TextEditingController(text: '');
    _manufacturerController =
        TextEditingController(text: _selectedEquipment?.manufacturer ?? '');
    _manufacturerYearController = TextEditingController(
        text: _selectedEquipment?.effectiveYearManufacture ?? '');
    _oilTempController = TextEditingController(text: '');
    _voltageController = TextEditingController(
        text: _cleanVoltage(_selectedEquipment?.voltage ?? ''));
    _capacityController = TextEditingController(
        text: _cleanMva(_selectedEquipment?.mva ?? ''));
    _serialNoController =
        TextEditingController(text: _selectedEquipment?.serial ?? '');
    _otherReasonController = TextEditingController(text: '');

    _senderNameController = TextEditingController(text: '');
    _senderIdController = TextEditingController(text: '');
    _senderSignatureController = TextEditingController(text: '');
    _syringeCaseController = TextEditingController(text: '');
    _bottleCaseController = TextEditingController(text: '');
    _remarksController = TextEditingController(text: '');
    _receivedByController = TextEditingController(text: '');
    _employeeIdController = TextEditingController(text: '');
    _receiverSignatureController = TextEditingController(text: '');
  }

  String _cleanVoltage(String v) {
    return v.replaceAll(RegExp(r'\s*kv\s*', caseSensitive: false), '').trim();
  }

  String _cleanMva(String m) {
    return m.replaceAll(RegExp(r'\s*mva\s*', caseSensitive: false), '').trim();
  }



  @override
  void dispose() {
    _tabController.dispose();
    _workOrderController.dispose();
    _refNoController.dispose();
    _externalLabController.dispose();
    _ibmMaximoController.dispose();
    _cityNameController.dispose();
    _substationNameController.dispose();
    _reportSendToController.dispose();
    _sampleByController.dispose();
    _equipmentDetailController.dispose();
    _otherEquipmentController.dispose();
    _manufacturerController.dispose();
    _manufacturerYearController.dispose();
    _oilTempController.dispose();
    _voltageController.dispose();
    _capacityController.dispose();
    _serialNoController.dispose();
    _otherReasonController.dispose();
    _senderNameController.dispose();
    _senderIdController.dispose();
    _senderSignatureController.dispose();
    _syringeCaseController.dispose();
    _bottleCaseController.dispose();
    _remarksController.dispose();
    _receivedByController.dispose();
    _employeeIdController.dispose();
    _receiverSignatureController.dispose();
    super.dispose();
  }

  Future<Uint8List> _generatePdfBytes() async {
    return await PdfGeneratorService.generateSampleAcknowledgementPdf(
      workOrder: _workOrderController.text.trim(),
      refNo: _refNoController.text.trim(),
      selectedLab: _selectedLab,
      externalLabName: _externalLabController.text.trim(),
      ibmMaximoAssetNumber: _ibmMaximoController.text.trim(),
      equipmentType: _equipmentType,
      equipmentTypeDetail: _equipmentType == 'Others'
          ? _otherEquipmentController.text.trim()
          : _equipmentDetailController.text.trim(),
      cityName: _cityNameController.text.trim(),
      substationName: _substationNameController.text.trim(),
      manufacturer: _manufacturerController.text.trim(),
      manufacturerYear: _manufacturerYearController.text.trim(),
      equipmentOilTemp: _oilTempController.text.trim(),
      voltage: _voltageController.text.trim(),
      capacity: _capacityController.text.trim(),
      serialNo: _serialNoController.text.trim(),
      reasonOfSample: _reasonOfSample,
      otherReasonDetail: _otherReasonController.text.trim(),
      reportSendTo: _reportSendToController.text.trim(),
      sampleBy: _sampleByController.text.trim(),
      sampleDate: _sampleDate,
      receivedDate: _receivedDate,
      testsRequired: _selectedTests,
      senderName: _senderNameController.text.trim().isNotEmpty
          ? _senderNameController.text.trim()
          : _sampleByController.text.trim(),
      senderId: _senderIdController.text.trim(),
      senderSignature: _senderSignatureController.text.trim(),
      senderSignatureImage: _senderSignatureBytes,
      // بيانات المستلم تُترك فارغة للتعبئة اليدوية فقط من قِبل مستلم المختبر
      syringeCase: '',
      bottleCase: '',
      receivingDate: '',
      sampleStatus: '',
      remarks: '',
      receivedBy: '',
      employeeId: '',
      receiverSignature: '',
    );
  }

  Future<void> _handleExportPdf() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF0F766E)),
                SizedBox(width: 16),
                Text(
                  'جاري إعداد وتصدير ملف PDF...',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final pdfBytes = await _generatePdfBytes();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final cleanSubName = _selectedSubstation.name.replaceAll('/', '_');
      final dateStr = _sampleDate.replaceAll('/', '_');
      final fileName = 'Sample_Acknowledgement_${cleanSubName}_$dateStr.pdf';

      final resolvedEquipment = _equipmentType == 'Others'
          ? _otherEquipmentController.text.trim()
          : (_equipmentDetailController.text.trim().isNotEmpty
              ? _equipmentDetailController.text.trim()
              : _equipmentType);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            workOrder: _workOrderController.text.trim(),
            substationName: _selectedSubstation.name,
            equipment: resolvedEquipment,
            formType: 'Sample Acknowledgement Form (FM-GM-3200-001-001)',
            technician: _sampleByController.text.trim().isNotEmpty
                ? _sampleByController.text.trim()
                : _senderNameController.text.trim(),
            notes: _reasonOfSample,
            pageTitle: 'Sample Acknowledgement Form (FM-GM-3200-001-001)',
            pdfFileName: fileName,
            initialPageFormat: PdfPageFormat.a4,
            showUploadAction: false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصدير ملف PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Stitch Top Corporate Header
              _buildStitchTopHeader(isDark),

              // 2. Scrollable Body containing Stepper & Active Tab
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    children: [
                      // Form Code Meta Card (FM-GM-3200-001-001 / Procedure Spec)
                      _buildProcedureMetaCard(isDark),
                      const SizedBox(height: 12),

                      // Stepper Tab Bar (Tabs 1, 2, 3 with Progress Tracker)
                      _buildStitchStepperBar(isDark),
                      const SizedBox(height: 14),

                      // Active Tab Panel
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                        child: _buildCurrentTabPanel(isDark),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Sticky Action Bar
              _buildStitchBottomBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TOP CORPORATE HEADER (Stitch Design)
  // =========================================================================
  Widget _buildStitchTopHeader(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1F3F),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Navigation Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                // Back Button
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded, // RTL back
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Brand & Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'NATIONAL GRID SA',
                            style: TextStyle(
                              color: Color(0xFFFB7185), // Rose accent
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                          ),
                          const Text(
                            'نقل الكهرباء',
                            style: TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'إقرار استلام العينات الميدانية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Security / Classification Badge (عام داخلي)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: const Text(
                    'عام (داخلي)',
                    style: TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PROCEDURE META CARD (Stitch Design)
  // =========================================================================
  Widget _buildProcedureMetaCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF1D4ED8),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROCEDURE SPEC',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'FM-GM-3200-001-001',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'قيد المعالجة',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEPPER TAB BAR & PROGRESS TRACKER (Stitch Design)
  // =========================================================================
  Widget _buildStitchStepperBar(bool isDark) {
    final currentTab = _tabController.index;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildTabButton(
                index: 0,
                stepNumber: 1,
                title: 'بيانات العينة',
                sub: 'Sample Info',
                icon: Icons.assignment_outlined,
                isActive: currentTab == 0,
                isCompleted: currentTab > 0,
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              _buildTabButton(
                index: 1,
                stepNumber: 2,
                title: 'الفحوصات المطلوبة',
                sub: 'Tests Required',
                icon: Icons.science_outlined,
                isActive: currentTab == 1,
                isCompleted: currentTab > 1,
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              _buildTabButton(
                index: 2,
                stepNumber: 3,
                title: 'الاستلام والاعتماد',
                sub: 'Receiving',
                icon: Icons.verified_user_outlined,
                isActive: currentTab == 2,
                isCompleted: false,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress Bar Trackers
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: currentTab >= 0
                        ? (currentTab > 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFF1D4ED8))
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: currentTab >= 1
                        ? (currentTab > 1
                            ? const Color(0xFF10B981)
                            : const Color(0xFF1D4ED8))
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: currentTab == 2
                        ? const Color(0xFF1D4ED8)
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required int stepNumber,
    required String title,
    required String sub,
    required IconData icon,
    required bool isActive,
    required bool isCompleted,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _tabController.animateTo(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF0B1F3F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive
                ? null
                : (isDark ? Colors.transparent : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : (isActive
                              ? const Color(0xFF3B82F6)
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1))),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isCompleted
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : Text(
                            '$stepNumber',
                            style: TextStyle(
                              color: isActive || isCompleted
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    icon,
                    size: 13,
                    color: isActive
                        ? Colors.white
                        : (isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 8.5,
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.8)
                      : (isDark ? Colors.grey.shade400 : const Color(0xFF94A3B8)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ACTIVE TAB DISPATCHER
  // =========================================================================
  Widget _buildCurrentTabPanel(bool isDark) {
    switch (_tabController.index) {
      case 0:
        return _buildTab1SampleInfo(isDark);
      case 1:
        return _buildTab2EquipmentAndTests(isDark);
      case 2:
      default:
        return _buildTab3ReceivingAndExport(isDark);
    }
  }

  // =========================================================================
  // TAB 1: بيانات العينة (Section 01: Sample Information)
  // =========================================================================
  Widget _buildTab1SampleInfo(bool isDark) {
    return Column(
      key: const ValueKey('tab_1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Gradient Header Card
        _buildSectionHeaderCard(
          title: 'بيانات العينة',
          subTitle: '/ Sample Information',
          sectionNumber: 'Section 01',
          accentColor: const Color(0xFFE11D48), // Rose
          gradientColors: const [Color(0xFF0F172A), Color(0xFF0B1F3F)],
        ),

        // Section Content Card (White rounded card)
        _buildContentCard(
          isDark: isDark,
          children: [
            // Work Order (Title on Line 1, Field on Line 2)
            _buildStitchInputField(
              controller: _workOrderController,
              labelAr: 'رقم أمر العمل',
              labelEn: '(Work Order) *',
              hint: 'e.g. WO-2026-XXXX',
              icon: Icons.confirmation_number_outlined,
              isDark: isDark,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Ref No (Title on Line 1, Field on Line 2)
            _buildStitchInputField(
              controller: _refNoController,
              labelAr: 'رقم المرجع',
              labelEn: '(Ref No)',
              hint: 'e.g. REF-2026-01',
              icon: Icons.tag_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            // Target Laboratory Selection (6 Grid Options)
            _buildStitchLabSelector(isDark),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Asset & Location Information
            _buildStitchInputField(
              controller: _ibmMaximoController,
              labelAr: 'رقم أصل ماكسيمو',
              labelEn: '(IBM-Maximo Asset Number)',
              hint: 'امسح أو أدخل رقم الأصل...',
              icon: Icons.qr_code_2_rounded,
              isDark: isDark,
              suffixWidget: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    size: 20, color: Color(0xFF1D4ED8)),
                tooltip: 'مسح الباركود',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاهز لمسح الباركود أو الكود الخاص بالأصل'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // City & S/S (2 Columns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildStitchInputField(
                    controller: _cityNameController,
                    labelAr: 'اسم المدينة',
                    labelEn: '/ City',
                    hint: 'المدينة',
                    icon: Icons.location_city_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStitchInputField(
                    controller: _substationNameController,
                    labelAr: 'محطة التحويل',
                    labelEn: '/ S/S Name/ID',
                    hint: 'اسم أو رمز المحطة',
                    icon: Icons.apartment_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Equipment Type Selector (6 options in 3 cols)
            _buildStitchEquipmentTypeSelector(isDark),
            const SizedBox(height: 12),

            // Equipment Name / Number
            _buildStitchInputField(
              controller: _equipmentDetailController,
              labelAr: 'اسم أو رقم المعدة',
              labelEn: '(Equipment Name/Number)',
              hint: 'مثال: T101 أو T102',
              icon: Icons.badge_outlined,
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Technical Specs in 2-Column Grid
            const Text(
              'البيانات الفنية للمعدة (Technical Specs)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStitchInputField(
                    controller: _manufacturerController,
                    labelAr: 'الشركة المصنعة',
                    labelEn: '/ Manufacturer',
                    hint: 'الشركة المصنعة',
                    icon: Icons.factory_rounded,
                    isDark: isDark,
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStitchInputField(
                    controller: _manufacturerYearController,
                    labelAr: 'سنة الصنع',
                    labelEn: '/ Year',
                    hint: 'YYYY',
                    icon: Icons.calendar_month_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStitchInputField(
                    controller: _oilTempController,
                    labelAr: 'حرارة الزيت',
                    labelEn: '/ Oil Temp (°C)',
                    hint: '°C',
                    icon: Icons.thermostat_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                    readOnly: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStitchInputField(
                    controller: _serialNoController,
                    labelAr: 'الرقم التسلسلي',
                    labelEn: '/ Serial No.',
                    hint: 'SN-XXXXX',
                    icon: Icons.tag_rounded,
                    isDark: isDark,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStitchInputField(
                    controller: _voltageController,
                    labelAr: 'الجهد',
                    labelEn: '/ Voltage (KV)',
                    hint: 'KV',
                    icon: Icons.bolt_rounded,
                    isDark: isDark,
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStitchInputField(
                    controller: _capacityController,
                    labelAr: 'السعة',
                    labelEn: '/ Capacity (MVA)',
                    hint: 'MVA',
                    icon: Icons.speed_rounded,
                    isDark: isDark,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Reason of Sample
            _buildStitchReasonOfSample(isDark),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Logistics info
            // 1. القائم بالسحب (Sample By)
            _buildStitchInputField(
              controller: _sampleByController,
              labelAr: 'القائم بالسحب',
              labelEn: '(Sample By)',
              hint: 'اسم الفني القائم بالسحب...',
              icon: Icons.person_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // 2. إرسال التقرير إلى (Report Send To)
            _buildStitchInputField(
              controller: _reportSendToController,
              labelAr: 'إرسال التقرير إلى',
              labelEn: '(Report Send To)',
              hint: 'اسم المهندس / البريد الإلكتروني للقسم...',
              icon: Icons.send_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // 3. تاريخ السحب (Sample Date)
            _buildStitchDatePicker(
              labelAr: 'تاريخ السحب',
              labelEn: '(Sample Date)',
              value: _sampleDate,
              onPicked: (d) => setState(() => _sampleDate = d),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: الفحوصات المطلوبة (Section 02: Tests Required)
  // =========================================================================
  Widget _buildTab2EquipmentAndTests(bool isDark) {
    return Column(
      key: const ValueKey('tab_2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Gradient Header Card
        _buildSectionHeaderCard(
          title: 'الفحوصات المطلوبة',
          subTitle: '/ Tests Required',
          sectionNumber: 'Section 02',
          accentColor: const Color(0xFF06B6D4), // Cyan
          gradientColors: const [Color(0xFF1E3A8A), Color(0xFF312E81)],
        ),

        // Section Content Card
        _buildContentCard(
          isDark: isDark,
          children: [
            // Header bar inside card with Select All / Deselect All
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر الفحوصات والتحاليل المخبرية:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'تم تحديد ${_selectedTests.length} من إجمالي ${_testsList.length} فحوصات',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedTests.length == _testsList.length) {
                        _selectedTests.clear();
                      } else {
                        _selectedTests.clear();
                        _selectedTests.addAll(
                            _testsList.map((t) => t['key'] as String));
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedTests.length == _testsList.length
                              ? Icons.remove_done_rounded
                              : Icons.done_all_rounded,
                          size: 14,
                          color: const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedTests.length == _testsList.length
                              ? 'إلغاء التحديد'
                              : 'تحديد الكل',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2-Column Grid of 9 Test Cards (Stitch layout)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _testsList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.85,
              ),
              itemBuilder: (context, index) {
                final t = _testsList[index];
                final key = t['key'] as String;
                final title = t['title'] as String;
                final subtitle = t['subtitle'] as String;
                final icon = t['icon'] as IconData;
                final isChecked = _selectedTests.contains(key);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isChecked) {
                        _selectedTests.remove(key);
                      } else {
                        _selectedTests.add(key);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? const Color(0xFFEFF6FF)
                          : (isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isChecked
                            ? const Color(0xFF2563EB)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1)),
                        width: isChecked ? 1.8 : 1.0,
                      ),
                      boxShadow: isChecked
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            isChecked
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isChecked
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isChecked
                                            ? const Color(0xFF1E3A8A)
                                            : (isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A)),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    icon,
                                    size: 13,
                                    color: isChecked
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF64748B),
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: الاستلام والاعتماد (Section 03: Receiving & Approval)
  // =========================================================================
  Widget _buildTab3ReceivingAndExport(bool isDark) {
    return Column(
      key: const ValueKey('tab_3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Gradient Header Card
        _buildSectionHeaderCard(
          title: 'الاستلام والاعتماد',
          subTitle: '/ Receiving & Approval',
          sectionNumber: 'Section 03',
          accentColor: const Color(0xFF10B981), // Emerald
          gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),

        // Section Content Card
        _buildContentCard(
          isDark: isDark,
          children: [
            // Notice: Receiving & Approval non-editable in app
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'قسم الاستلام والاعتماد غير متاح للتعديل',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تُترك حقول وتوقيعات الاستلام واعتماد العينات فارغة ليتم فحصها واستلامها وتوقيعها رسمياً يدوياً في المختبر.\nيمكنك مراجعة ملخص بيانات النموذج بالكامل أدناه ثم التصدير بصيغة PDF.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Comprehensive Form Summary Card before export
            _buildFullSummaryReviewCard(isDark),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // BOTTOM STICKY ACTION BAR (Stitch Design)
  // =========================================================================
  Widget _buildStitchBottomBar(bool isDark) {
    final currentTab = _tabController.index;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0B1F3F)
            : Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
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
      child: Row(
        children: [
          // Previous button (if tab > 0)
          if (currentTab > 0) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded,
                  size: 16, color: Color(0xFF0F2C59)), // RTL back
              label: const Text(
                'السابق',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F2C59),
                ),
              ),
              onPressed: () => _tabController.animateTo(currentTab - 1),
            ),
            const SizedBox(width: 10),
          ],

          // Single Action Button: تصدير PDF
          if (currentTab == 2) ...[
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  shadowColor: const Color(0xFF0F766E).withValues(alpha: 0.35),
                ),
                icon: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'تصدير PDF',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: _handleExportPdf,
              ),
            ),
          ] else ...[
            // Next button for tabs 0 & 1
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8), // Blue for next
                  foregroundColor: Colors.white,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                ),
                icon: const Icon(
                  Icons.arrow_back_rounded, // RTL next
                  size: 18,
                ),
                label: Text(
                  currentTab == 0
                      ? 'التالي: الفحوصات المطلوبة'
                      : 'التالي: الاستلام والاعتماد',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                onPressed: () => _tabController.animateTo(currentTab + 1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION & CONTENT CARDS HELPERS (Stitch Style)
  // =========================================================================

  Widget _buildSectionHeaderCard({
    required String title,
    required String subTitle,
    required String sectionNumber,
    required Color accentColor,
    required List<Color> gradientColors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    subTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sectionNumber,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildStitchInputField({
    required TextEditingController controller,
    required String labelAr,
    required String labelEn,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffixWidget,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 5),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: labelAr,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.grey.shade200
                        : const Color(0xFF334155),
                  ),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: labelEn,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                    color: isDark
                        ? Colors.grey.shade400
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(
              icon,
              size: 17,
              color: readOnly ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
            suffixIcon: suffixWidget,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            fillColor: isDark
                ? (readOnly
                    ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                    : const Color(0xFF0F172A))
                : (readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC)),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF1D4ED8), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStitchDatePicker({
    required String labelAr,
    required String labelEn,
    required String value,
    required Function(String) onPicked,
    required bool isDark,
  }) {
    final hasValue = value.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 5),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: labelAr,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.grey.shade200
                        : const Color(0xFF334155),
                  ),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: labelEn,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                    color: isDark
                        ? Colors.grey.shade400
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              onPicked(DateFormat('yyyy/MM/dd').format(picked));
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 17, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasValue ? value : 'dd/mm/yyyy',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          hasValue ? FontWeight.bold : FontWeight.normal,
                      color: hasValue
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStitchLabSelector(bool isDark) {
    final labs = [
      {'code': 'RYD', 'name': 'RYD (الرياض)'},
      {'code': 'JED', 'name': 'JED (جدة)'},
      {'code': 'DMM', 'name': 'DMM (الدمام)'},
      {'code': 'QSM', 'name': 'QSM (القصيم)'},
      {'code': 'ABH', 'name': 'ABH (أبها)'},
      {'code': 'EXTERNAL', 'name': 'خارجي EXTERNAL'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'المختبر المعني',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.grey.shade200
                      : const Color(0xFF334155),
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: '(Target Lab) *',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                  color: isDark
                      ? Colors.grey.shade400
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: labs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
          ),
          itemBuilder: (ctx, i) {
            final lab = labs[i];
            final code = lab['code']!;
            final name = lab['name']!;
            final isSelected = _selectedLab == code;

            return InkWell(
              onTap: () => setState(() => _selectedLab = code),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFEFF6FF)
                      : (isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1D4ED8)
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF1D4ED8)
                        : (isDark
                            ? Colors.grey.shade300
                            : const Color(0xFF334155)),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
        if (_selectedLab == 'EXTERNAL') ...[
          const SizedBox(height: 10),
          _buildStitchInputField(
            controller: _externalLabController,
            labelAr: 'اسم المختبر الخارجي المعتمد',
            labelEn: '(External Lab Name)',
            hint: 'أدخل اسم المختبر الخارجي...',
            icon: Icons.business_rounded,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildStitchEquipmentTypeSelector(bool isDark) {
    final types = [
      {'key': 'Transformer', 'label': 'محول (Transformer)'},
      {'key': 'Reactor', 'label': 'مفاعل (Reactor)'},
      {'key': 'Cable', 'label': 'كيبل (Cable)'},
      {'key': 'UG cable', 'label': 'كيبل أرضي (UG cable)'},
      {'key': 'OLTC', 'label': 'OLTC'},
      {'key': 'Others', 'label': 'أخرى (Others)'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'نوع المعدة',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.grey.shade200
                      : const Color(0xFF334155),
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: '(Equipment Type)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                  color: isDark
                      ? Colors.grey.shade400
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: types.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (ctx, i) {
            final t = types[i];
            final key = t['key']!;
            final label = t['label']!;
            final isSelected = _equipmentType == key;

            return InkWell(
              onTap: () => setState(() => _equipmentType = key),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFEFF6FF)
                      : (isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1D4ED8)
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF1D4ED8)
                        : (isDark
                            ? Colors.grey.shade300
                            : const Color(0xFF334155)),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
        if (_equipmentType == 'Others') ...[
          const SizedBox(height: 10),
          _buildStitchInputField(
            controller: _otherEquipmentController,
            labelAr: 'تحديد نوع وبيانات المعدة الأخرى',
            labelEn: '(Specify Other Equipment)',
            hint: 'اكتب اسم ونوع المعدة لتنطبع بجانب خيار Others...',
            icon: Icons.edit_note_rounded,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildStitchReasonOfSample(bool isDark) {
    final reasons = [
      {'key': 'annual', 'label': 'سنوي (annual)'},
      {'key': 'PM', 'label': 'PM (وقائية)'},
      {'key': 'CM', 'label': 'CM (علاجية)'},
      {'key': 'A/F filtration', 'label': 'A/F filtration'},
      {'key': 'Failure', 'label': 'عطل / خلل (Failure)'},
      {'key': 'Other', 'label': 'أخرى (Other)'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'سبب أخذ العينة',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.grey.shade200
                      : const Color(0xFF334155),
                ),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: '(Reason of Sample)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                  color: isDark
                      ? Colors.grey.shade400
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: reasons.map((r) {
            final key = r['key']!;
            final label = r['label']!;
            final isSelected = _reasonOfSample == key;

            return InkWell(
              onTap: () => setState(() => _reasonOfSample = key),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (key == 'Failure'
                          ? const Color(0xFFE11D48)
                          : const Color(0xFF1D4ED8))
                      : (isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? (key == 'Failure'
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF1D4ED8))
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                    width: isSelected ? 1.6 : 1.0,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? Colors.grey.shade300
                            : const Color(0xFF334155)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_reasonOfSample == 'Other') ...[
          const SizedBox(height: 10),
          _buildStitchInputField(
            controller: _otherReasonController,
            labelAr: 'تحديد سبب الفحص الآخر',
            labelEn: '(Other Reason)',
            hint: 'اكتب سبب أخذ العينة...',
            icon: Icons.edit_note_rounded,
            isDark: isDark,
          ),
        ],
      ],
    );
  }



  /// Comprehensive Form Summary Card before PDF Export
  Widget _buildFullSummaryReviewCard(bool isDark) {
    final workOrder = _workOrderController.text.trim().isNotEmpty
        ? _workOrderController.text.trim()
        : 'غير محدد';
    final refNo = _refNoController.text.trim().isNotEmpty
        ? _refNoController.text.trim()
        : '-';
    final ibmMaximo = _ibmMaximoController.text.trim().isNotEmpty
        ? _ibmMaximoController.text.trim()
        : '-';
    final cityName = _cityNameController.text.trim().isNotEmpty
        ? _cityNameController.text.trim()
        : _selectedSubstation.region;
    final targetLab = _selectedLab == 'Other'
        ? (_externalLabController.text.trim().isNotEmpty
            ? _externalLabController.text.trim()
            : 'Other')
        : _selectedLab;
    final sampleBy = _sampleByController.text.trim().isNotEmpty
        ? _sampleByController.text.trim()
        : '-';
    final reportSendTo = _reportSendToController.text.trim().isNotEmpty
        ? _reportSendToController.text.trim()
        : '-';

    final equipDetail = _equipmentDetailController.text.trim().isNotEmpty
        ? _equipmentDetailController.text.trim()
        : (_selectedEquipment?.number ?? '-');
    final manufacturer = _manufacturerController.text.trim().isNotEmpty
        ? _manufacturerController.text.trim()
        : (_selectedEquipment?.manufacturer ?? '-');
    final mfgYear = _manufacturerYearController.text.trim().isNotEmpty
        ? _manufacturerYearController.text.trim()
        : (_selectedEquipment?.effectiveYearManufacture ?? '-');
    final voltage = _voltageController.text.trim().isNotEmpty
        ? '${_voltageController.text.trim()} kV'
        : '-';
    final capacity = _capacityController.text.trim().isNotEmpty
        ? '${_capacityController.text.trim()} MVA'
        : '-';
    final serialNo = _serialNoController.text.trim().isNotEmpty
        ? _serialNoController.text.trim()
        : (_selectedEquipment?.serial ?? '-');
    final oilTemp = _oilTempController.text.trim().isNotEmpty
        ? '${_oilTempController.text.trim()} °C'
        : '-';
    final reason = _reasonOfSample == 'Other'
        ? (_otherReasonController.text.trim().isNotEmpty
            ? _otherReasonController.text.trim()
            : 'Other')
        : _reasonOfSample;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F2C59),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملخص النموذج قبل التصدير إلى PDF',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'مراجعة شاملة لكافة البيانات المدخلة قبل إصدار التقرير',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'جاهز للتصدير',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. بيانات المحطة وأمر العمل
                _buildSummarySectionHeader(
                  title: 'بيانات أمر العمل والمحطة',
                  subtitle: 'Work Order & Substation Info',
                  icon: Icons.apartment_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryDataRow('أمر العمل (Work Order):', workOrder, 'المحطة (Substation):', _selectedSubstation.name, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('المدينة / المنطقة:', cityName, 'المختبر المطلوب:', targetLab, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('الرقم المرجعي (Ref No):', refNo, 'رقم ماكسيمو (Asset No):', ibmMaximo, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('تاريخ السحب:', _sampleDate, 'ساحب العينة:', sampleBy, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('ترسل التقارير إلى:', reportSendTo, 'تاريخ الاستلام الميداني:', _receivedDate.isNotEmpty ? _receivedDate : '-', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. بيانات المعدة والمحول
                _buildSummarySectionHeader(
                  title: 'بيانات المعدة والمحول',
                  subtitle: 'Equipment & Transformer Info',
                  icon: Icons.bolt_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryDataRow('نوع المعدة:', _equipmentType, 'رقم / مسمى المعدة:', equipDetail, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('الشركة الصانعة:', manufacturer, 'سنة الصنع:', mfgYear, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('الجهد المقنن:', voltage, 'القدرة المقننة:', capacity, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('الرقم التسلسلي:', serialNo, 'حرارة الزيت:', oilTemp, isDark),
                      const Divider(height: 14, thickness: 0.5),
                      _buildSummaryDataRow('سبب سحب العينة:', reason, '', '', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. الفحوصات المطلوبة
                _buildSummarySectionHeader(
                  title: 'الفحوصات المخبرية المطلوبة (${_selectedTests.length})',
                  subtitle: 'Selected Tests',
                  icon: Icons.science_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: _selectedTests.isEmpty
                      ? const Text(
                          'لم يتم تحديد أي فحص مخبري',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedTests.map((testKey) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D4ED8).withValues(alpha: isDark ? 0.2 : 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    testKey,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F2C59),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2C59).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF0F2C59)),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F2C59),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($subtitle)',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDataRow(
    String label1,
    String value1,
    String label2,
    String value2,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSummaryDataItem(label1, value1, isDark),
        ),
        if (label2.isNotEmpty) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryDataItem(label2, value2, isDark),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryDataItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '-',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
