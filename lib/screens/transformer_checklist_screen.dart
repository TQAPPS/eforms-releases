import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import '../services/pdf_generator_service.dart';
import 'pdf_preview_screen.dart';
import 'transformer_review_approval_screen.dart';

class ChecklistItemModel {
  final int number;
  final String id;
  final String title;
  final String arabicTitle;
  final List<String> subTasks;
  final List<String> arabicSubTasks;
  final List<String> quickComments;
  final String defaultComment;
  bool isChecked = false;
  String comment = '';

  ChecklistItemModel({
    required this.number,
    required this.id,
    required this.title,
    required this.arabicTitle,
    required this.subTasks,
    required this.arabicSubTasks,
    required this.quickComments,
    this.defaultComment = 'OK',
  });
}

class TransformerChecklistScreen extends StatefulWidget {
  final FormModel form;
  final SubstationModel? selectedSubstation;
  final String? initialDivision;
  final String? initialContactPerson;
  final String? initialDepartment;
  final String? initialWorkOrder;
  final String? initialInspectionDate;

  const TransformerChecklistScreen({
    super.key,
    required this.form,
    this.selectedSubstation,
    this.initialDivision,
    this.initialContactPerson,
    this.initialDepartment,
    this.initialWorkOrder,
    this.initialInspectionDate,
  });

  static String getDivisionForSubstation(SubstationModel sub) {
    final r = sub.region.toUpperCase();
    if (r.contains('JIZAN') || r.contains('SOUTH') || r.contains('ASIR') || r.contains('NAJRAN')) {
      return 'SOD / Southern Operating Division';
    } else if (r.contains('EAST') || r.contains('DAMMAM') || r.contains('JUBAIL') || r.contains('KHOBAR')) {
      return 'EOD / Eastern Operating Division';
    } else if (r.contains('WEST') || r.contains('JEDDAH') || r.contains('MAKKAH') || r.contains('MADINAH')) {
      return 'WOD / Western Operating Division';
    } else if (r.contains('CENTRAL') || r.contains('RIYADH') || r.contains('QASSIM')) {
      return 'CPD / Central Operating Division';
    }
    return 'SOD / Southern Operating Division';
  }

  static String getDepartmentForSubstation(SubstationModel sub) {
    return 'Substation Maintenance Dept - ${sub.region}';
  }

  @override
  State<TransformerChecklistScreen> createState() =>
      _TransformerChecklistScreenState();
}

class _TransformerChecklistScreenState
    extends State<TransformerChecklistScreen> {
  // Selected Substation & Active Transformer Unit
  late SubstationModel _selectedSubstation;
  late TransformerInfo _selectedTransformer;
  late String _inspectionDate;
  final ScrollController _scrollController = ScrollController();

  // The 20 Checklist Items & Controllers per Transformer Unit (e.g. 'T601', 'T602')
  final Map<String, List<ChecklistItemModel>> _transformerItemsMap = {};
  final Map<String, Map<String, TextEditingController>> _transformerControllersMap = {};

  // Current active unit's items and controllers
  late List<ChecklistItemModel> _items;
  late Map<String, TextEditingController> _commentControllers;

  List<TransformerInfo> get _transformers =>
      _selectedSubstation.transformers.isNotEmpty
          ? _selectedSubstation.transformers
          : [_selectedTransformer];

  int get _currentTransformerIndex {
    final idx = _transformers.indexWhere((t) => t.number == _selectedTransformer.number);
    return idx >= 0 ? idx : 0;
  }

  bool get _isLastTransformer => _currentTransformerIndex == _transformers.length - 1;

  TransformerInfo? get _nextTransformer =>
      !_isLastTransformer ? _transformers[_currentTransformerIndex + 1] : null;

  bool _isTransformerComplete(String txNumber) {
    final items = _transformerItemsMap[txNumber];
    return items != null && items.isNotEmpty && items.every((i) => i.isChecked);
  }

  bool _isTransformerUnlocked(int targetIdx) {
    if (targetIdx == 0) return true;
    for (int j = 0; j < targetIdx; j++) {
      if (!_isTransformerComplete(_transformers[j].number)) {
        return false;
      }
    }
    return true;
  }

  bool get _areAllSubstationTransformersCompleted {
    return _transformers.every((t) => _isTransformerComplete(t.number));
  }

  @override
  void initState() {
    super.initState();

    _selectedSubstation = widget.selectedSubstation ??
        NationalGridData.substations.firstWhere(
          (s) => s.name == 'JIC',
          orElse: () => NationalGridData.substations.first,
        );

    _inspectionDate = widget.initialInspectionDate ??
        DateFormat('yyyy/MM/dd').format(DateTime.now());

    final txList = _selectedSubstation.transformers.isNotEmpty
        ? _selectedSubstation.transformers
        : [
            const TransformerInfo(
              number: 'T1',
              voltage: '132/13.8 kV',
              serial: '54190',
              manufacturer: 'National Grid',
              mva: '67',
            ),
          ];

    for (var tx in txList) {
      final items = _createDefaultChecklistItems();
      final controllers = <String, TextEditingController>{};
      for (var item in items) {
        controllers[item.id] = TextEditingController(text: item.comment);
      }
      _transformerItemsMap[tx.number] = items;
      _transformerControllersMap[tx.number] = controllers;
    }

    _selectedTransformer = txList.first;
    _items = _transformerItemsMap[_selectedTransformer.number]!;
    _commentControllers = _transformerControllersMap[_selectedTransformer.number]!;
  }

  void _selectTransformer(TransformerInfo tx) {
    if (_selectedTransformer.number == tx.number) return;
    setState(() {
      _selectedTransformer = tx;
      if (!_transformerItemsMap.containsKey(tx.number)) {
        final items = _createDefaultChecklistItems();
        final controllers = <String, TextEditingController>{};
        for (var item in items) {
          controllers[item.id] = TextEditingController(text: item.comment);
        }
        _transformerItemsMap[tx.number] = items;
        _transformerControllersMap[tx.number] = controllers;
      }
      _items = _transformerItemsMap[tx.number]!;
      _commentControllers = _transformerControllersMap[tx.number]!;
    });
  }

  void _onTapTransformerChip(int index, TransformerInfo tx) {
    if (index == _currentTransformerIndex) return;
    if (!_isTransformerUnlocked(index)) {
      String blockingUnit = '';
      for (int j = 0; j < index; j++) {
        if (!_isTransformerComplete(_transformers[j].number)) {
          blockingUnit = _transformers[j].number;
          break;
        }
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يمكن تجاوز المعدة الحالية. يرجى إكمال نموذج فحص المحول ($blockingUnit) أولاً.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _selectTransformer(tx);
  }

  List<ChecklistItemModel> _createDefaultChecklistItems() {
    return [
      ChecklistItemModel(
        number: 1,
        id: 'oil_leakage',
        title: 'Oil Leakage',
        arabicTitle: 'تسريب ومستوى الزيت',
        subTasks: ['Check level and leakage'],
        arabicSubTasks: ['فحص مستوى الزيت والتأكد من خلوه من أي ترشيح أو تسريب'],
        quickComments: ['OK - No Leakage', 'Normal Level', 'Minor Seepage', 'Active Leak', 'N/A'],
        defaultComment: 'OK',
      ),
      ChecklistItemModel(
        number: 2,
        id: 'silica_gel_main_tank',
        title: 'Silica gel Color main Tank',
        arabicTitle: 'لون السيليكا جل للخزان الرئيسي',
        subTasks: ['Check color'],
        arabicSubTasks: ['فحص اللون ومستوى امتصاص الرطوبة'],
        quickComments: ['Blue (Dry & Healthy)', 'Pink (Saturated - Need Replace)', 'Orange (Healthy)', 'N/A'],
        defaultComment: 'Blue (Dry & Healthy)',
      ),
      ChecklistItemModel(
        number: 3,
        id: 'silica_gel_tap_changer',
        title: 'Silica gel Color Tap Changer',
        arabicTitle: 'لون السيليكا جل لمغير الجهد',
        subTasks: ['Check color'],
        arabicSubTasks: ['فحص اللون ومستوى الرطوبة لمغير الجهد'],
        quickComments: ['Blue (Dry & Healthy)', 'Pink (Saturated - Need Replace)', 'Orange (Healthy)', 'N/A'],
        defaultComment: 'Blue (Dry & Healthy)',
      ),
      ChecklistItemModel(
        number: 4,
        id: 'oil_level_main_tank',
        title: 'Oil Level Gauge Main Tank Conservator',
        arabicTitle: 'مؤشر مستوى زيت خزان التمدد الرئيسي',
        subTasks: ['Check level and leakage'],
        arabicSubTasks: ['فحص عداد المستوى وعدم وجود تسريب أو انسداد'],
        quickComments: ['Normal (Level 45%)', 'Normal (Level 50%)', 'Low Level', 'High Level', 'OK', 'N/A'],
        defaultComment: 'Normal (Level 45%)',
      ),
      ChecklistItemModel(
        number: 5,
        id: 'oil_level_tap_changer',
        title: 'Oil Level Gauge Tap Changer',
        arabicTitle: 'مؤشر مستوى زيت خزان مغير الجهد',
        subTasks: ['Check level and leakage'],
        arabicSubTasks: ['فحص عداد مستوى الزيت والتسريب لمغير الجهد'],
        quickComments: ['Normal (Level 40%)', 'Normal (Level 50%)', 'Low Level', 'OK', 'N/A'],
        defaultComment: 'Normal (Level 40%)',
      ),
      ChecklistItemModel(
        number: 6,
        id: 'tap_position',
        title: 'Tap Position',
        arabicTitle: 'موضع خطوة مغير الجهد الحالي (1 إلى 32)',
        subTasks: ['Record Tap Position.'],
        arabicSubTasks: ['تسجيل رقم خطوة مغير الجهد الحالية باستخدام شريط التمرير (Slider) من 1 إلى 32'],
        quickComments: [],
        defaultComment: 'Tap 9',
      ),
      ChecklistItemModel(
        number: 7,
        id: 'tap_counter_reading',
        title: 'Tap Changer Counter Reading',
        arabicTitle: 'قراءة عداد عمليات مغير الجهد',
        subTasks: ['Record reading.'],
        arabicSubTasks: ['تسجيل قراءة العداد التراكمي (أرقام فقط)'],
        quickComments: [],
        defaultComment: '12450',
      ),
      ChecklistItemModel(
        number: 8,
        id: 'oil_temperature',
        title: 'Oil Temperature',
        arabicTitle: 'درجة حرارة زيت المحول (OTI)',
        subTasks: ['Record reading.'],
        arabicSubTasks: ['تسجيل درجة حرارة زيت المحول بالمئوية (°C)'],
        quickComments: [],
        defaultComment: '48',
      ),
      ChecklistItemModel(
        number: 9,
        id: 'hv_winding_temp',
        title: 'HV Winding Temperature',
        arabicTitle: 'حرارة ملفات الجهد العالي (HV WTI)',
        subTasks: ['Record reading.'],
        arabicSubTasks: ['تسجيل قراءة حرارة ملفات الجهد العالي بالمئوية (°C)'],
        quickComments: [],
        defaultComment: '55',
      ),
      ChecklistItemModel(
        number: 10,
        id: 'lv_winding_temp',
        title: 'LV Winding Temperature',
        arabicTitle: 'حرارة ملفات الجهد المنخفض (LV WTI)',
        subTasks: ['Record reading.'],
        arabicSubTasks: ['تسجيل قراءة حرارة ملفات الجهد المنخفض بالمئوية (°C)'],
        quickComments: [],
        defaultComment: '52',
      ),
      ChecklistItemModel(
        number: 11,
        id: 'cooling_fans_pump',
        title: 'Cooling Fans & Pump Operation',
        arabicTitle: 'تشغيل مراوح ومضخات التبريد',
        subTasks: ['Manually run and return to auto; report abnormal noise'],
        arabicSubTasks: ['التشغيل اليدوي والرجوع للأوتوماتيك؛ الإبلاغ عن أي صوت غير طبيعي'],
        quickComments: ['Tested OK - Returned to Auto', 'Normal - No Noise', 'Abnormal Noise Reported', 'Fans OK', 'N/A'],
        defaultComment: 'Tested OK - Returned to Auto',
      ),
      ChecklistItemModel(
        number: 12,
        id: 'control_cabinet_sealed',
        title: 'Control Cabinet Properly Sealed',
        arabicTitle: 'إحكام إغلاق كابينة التحكم',
        subTasks: ['Check that they are properly sealed.'],
        arabicSubTasks: ['التأكد من سلامة الجوانات وإحكام الإغلاق ضد الأتربة والحرارة'],
        quickComments: ['Properly Sealed & Clean', 'Weatherstripping OK', 'Dust Ingress Observed', 'Needs Resealing'],
        defaultComment: 'Properly Sealed & Clean',
      ),
      ChecklistItemModel(
        number: 13,
        id: 'heater_operation',
        title: 'Heater Operation in Control Cabinet',
        arabicTitle: 'عمل السخانات والإنارة في كابينة التحكم',
        subTasks: ['Check operation of lights and heaters.'],
        arabicSubTasks: ['فحص تشغيل السخانات الداخلية ولمبات الإضاءة'],
        quickComments: ['Heaters & Lights Operational', 'Thermostat Working OK', 'Heater Malfunction', 'Light Fault'],
        defaultComment: 'Heaters & Lights Operational',
      ),
      ChecklistItemModel(
        number: 14,
        id: 'dga_monitor',
        title: 'On Line DGA Monitor',
        arabicTitle: 'جهاز مراقبة الغازات الذائبة المتصل',
        subTasks: ['Check operation'],
        arabicSubTasks: ['فحص عمل الجهاز والتحقق من عدم وجود إنذارات غازية'],
        quickComments: ['Normal - No Gas Alarms', 'Operational (ppm Normal)', 'Alarm Active - Dispatched', 'N/A (Not Fitted)'],
        defaultComment: 'Normal - No Gas Alarms',
      ),
      ChecklistItemModel(
        number: 15,
        id: 'general_condition',
        title: 'General condition',
        arabicTitle: 'الحالة العامة والتأريض ومقاومة الصدأ',
        subTasks: [
          'Check Grounding Securely Connected',
          'Report corrosion and painting if required',
        ],
        arabicSubTasks: [
          'فحص تأريض جسم المحول والتأكد من إحكام التوصيل',
          'الإبلاغ عن الصدأ وحاجة الدهان إن وجدت',
        ],
        quickComments: ['Grounding Secure - No Corrosion', 'Good Condition', 'Surface Rust Reported', 'Painting Required'],
        defaultComment: 'Grounding Secure - No Corrosion',
      ),
      ChecklistItemModel(
        number: 16,
        id: 'safety_valves_gauges',
        title: 'Safety Valves & Pressure Gauges',
        arabicTitle: 'صمامات الأمان ومقاييس الضغط',
        subTasks: [
          'Check PRV (Pressure Relief Valve) visual status',
          'Check Sudden Pressure Relay (SPR)',
        ],
        arabicSubTasks: [
          'فحص صمام تنفيس الضغط الميكانيكي ومؤشر الحركة',
          'فحص ريليه الضغط المفاجئ وعدم وجود تنبيهات',
        ],
        quickComments: ['Normal - No Tripping Flag', 'Gauges Normal', 'Flag Reset Needed', 'Oil Trace Observed'],
        defaultComment: 'Normal - No Tripping Flag',
      ),
      ChecklistItemModel(
        number: 17,
        id: 'buchholz_relay',
        title: 'Buchholz Relay & Gas Collection',
        arabicTitle: 'ريليه بوخهولتز وتجمع الغازات',
        subTasks: ['Visual inspection of glass oil level and gas collection'],
        arabicSubTasks: ['فحص المؤشر الزجاجي والتأكد من امتلاء حجرة الزيت وخلوها من فقاعات الغاز'],
        quickComments: ['Full Oil - No Gas Accumulation', 'Gas Bubbles Detected', 'Visual Inspection OK', 'N/A'],
        defaultComment: 'Full Oil - No Gas Accumulation',
      ),
      ChecklistItemModel(
        number: 18,
        id: 'bushings_condition',
        title: 'High & Low Voltage Bushings',
        arabicTitle: 'عوازل الاختراق (البوشينج) للجهد العالي والمنخفض',
        subTasks: [
          'Check for oil level in bushings (if applicable)',
          'Check for cracks, flashover marks, or severe dust',
        ],
        arabicSubTasks: [
          'فحص مستوى الزيت في عوازل البوشينج الزيتية',
          'التأكد من خلو البورسلين من أي شروخ أو آثار تفريغ كهربائي أو اتساخ شديد',
        ],
        quickComments: ['Clean - No Cracks or Flashover', 'Oil Level Normal', 'Surface Dust Reported', 'Needs Washing'],
        defaultComment: 'Clean - No Cracks or Flashover',
      ),
      ChecklistItemModel(
        number: 19,
        id: 'fire_protection_system',
        title: 'Fire Protection System Status',
        arabicTitle: 'جاهزية نظام الإطفاء والحماية من الحريق',
        subTasks: ['Check water spray nozzles / deluge valve ready status'],
        arabicSubTasks: ['فحص رشاشات المياه ومحبس الديلوج والتأكد من عدم وجود عوائق أو تسريب'],
        quickComments: ['System In-Service & Ready', 'Nozzles Clean & Aligned', 'Deluge Valve Healthy', 'N/A'],
        defaultComment: 'System In-Service & Ready',
      ),
      ChecklistItemModel(
        number: 20,
        id: 'sound_level_abnormalities',
        title: 'Check Sound Level Abnormalities',
        arabicTitle: 'فحص مستوى الضجيج والأصوات غير الطبيعية',
        subTasks: [],
        arabicSubTasks: ['الاستماع لأصوات التشغيل وملاحظة أي طنين أو اهتزاز غير مألوف'],
        quickComments: ['Sound Level Normal (Standard Hum)', 'No Abnormal Humming', 'Vibration/Noise Observed', 'Quiet Operation'],
        defaultComment: 'Sound Level Normal (Standard Hum)',
      ),
    ];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var controllerMap in _transformerControllersMap.values) {
      for (var controller in controllerMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }



  void _resetChecklist() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('تفريغ قائمة الفحص'),
          ],
        ),
        content: const Text('هل أنت متأكد من رغبتك في إعادة ضبط وتفريغ جميع البنود والملاحظات لهذا المحول؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (var item in _items) {
                  item.isChecked = false;
                  item.comment = '';
                  _commentControllers[item.id]?.clear();
                }
              });
            },
            child: const Text('نعم، إعادة الضبط'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewOfficialPdf() async {
    final pdfBytes = await PdfGeneratorService.generateTransformerChecklistPdf(
      division: widget.initialDivision ?? _selectedSubstation.division,
      contactPerson: widget.initialContactPerson ?? '',
      department: widget.initialDepartment ?? _selectedSubstation.department,
      workOrder: widget.initialWorkOrder ?? '',
      substationName:
          '${_selectedSubstation.name} (${_selectedSubstation.region})',
      inspectionDate: widget.initialInspectionDate ?? _inspectionDate,
      equipmentNo: _selectedTransformer.number,
      equipmentVoltage: _selectedTransformer.voltage,
      equipmentMva: _selectedTransformer.mva ?? '',
      equipmentSerial: _selectedTransformer.serial ?? '',
      equipmentManufacturer: _selectedTransformer.manufacturer ?? '',
      itemsData: _items.map((item) {
        return {
          'title': item.title,
          'subTasks': item.subTasks,
          'checked': item.isChecked,
          'comments': item.comment,
        };
      }).toList(),
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          pdfBytes: pdfBytes,
          workOrder: (widget.initialWorkOrder != null &&
                  widget.initialWorkOrder!.isNotEmpty)
              ? widget.initialWorkOrder!
              : 'CL-GM-1400',
          substationName: '${_selectedSubstation.name} (${_selectedSubstation.region})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final checkedCount = _items.where((i) => i.isChecked).length;
    final double completionProgress =
        _items.isEmpty ? 0.0 : checkedCount / _items.length;
    final bool isAllCompleted = _items.isNotEmpty && checkedCount == _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Checklist for Substation Power Transformer',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'قائمة فحص محولات القدرة - CL-GM-1400-002-002',
              style: TextStyle(fontSize: 11, color: Color(0xFF14B8A6)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'معاينة ملف PDF الرسمي',
            onPressed: _previewOfficialPdf,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'إعادة ضبط الفحص',
            onPressed: _resetChecklist,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Official Header Banner
                  _buildOfficialHeaderCard(isDark),
                  const SizedBox(height: 14),

                  // Equipment / Transformer Details Card (Above Checklist Widget)
                  _buildEquipmentSelectorCard(isDark),
                  const SizedBox(height: 14),

                  // Checklist Controls & Progress Bar
                  _buildChecklistControlsBar(
                      isDark, checkedCount, completionProgress),
                  const SizedBox(height: 14),

                  // The 20 Checklist Items
                  ..._items.map((item) => _buildChecklistItemCard(item, isDark)),
                  const SizedBox(height: 20),

                  // Next Step Action Card & Conditional Next Button
                  _buildNextActionBar(isDark, checkedCount, isAllCompleted),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToReviewApprovalPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TransformerReviewApprovalScreen(
          form: widget.form,
          selectedSubstation: _selectedSubstation,
          selectedTransformer: _selectedTransformer,
          substationTransformers: _transformers,
          transformerItemsMap: _transformerItemsMap,
          initialDivision: widget.initialDivision ?? _selectedSubstation.division,
          initialDepartment:
              widget.initialDepartment ?? _selectedSubstation.department,
          initialContactPerson: widget.initialContactPerson ?? '',
          initialWorkOrder: widget.initialWorkOrder ?? '',
          initialInspectionDate: widget.initialInspectionDate ?? _inspectionDate,
          items: _items,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.05, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
  }

  Widget _buildNextActionBar(bool isDark, int checkedCount, bool isAllCompleted) {
    final remainingCount = _items.length - checkedCount;
    final isLast = _isLastTransformer;
    final nextTx = _nextTransformer;
    final allDone = _areAllSubstationTransformersCompleted;

    final bool canProceed = isLast ? allDone : isAllCompleted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canProceed
              ? const Color(0xFF0F766E)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: canProceed ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (canProceed ? const Color(0xFF0F766E) : Colors.black)
                .withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAllCompleted
                      ? const Color(0xFF0F766E).withValues(alpha: 0.15)
                      : (isDark
                          ? const Color(0xFF334155).withValues(alpha: 0.5)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAllCompleted
                      ? Icons.check_circle_rounded
                      : Icons.pending_actions_rounded,
                  color: isAllCompleted
                      ? const Color(0xFF0F766E)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAllCompleted
                          ? 'اكتمل نموذج المحول الحالي (${_selectedTransformer.number}) بنجاح ✓'
                          : 'حالة إنجاز فحص (${_selectedTransformer.number}): $checkedCount من ${_items.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isAllCompleted
                            ? const Color(0xFF0F766E)
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isAllCompleted
                          ? (!isLast
                              ? 'اضغط أدناه للانتقال للمعدة التالية (${nextTx?.number}).'
                              : 'اكتملت كافة محولات المحطة بنجاح! يمكنك الآن الانتقال للاعتماد الإلكتروني.')
                          : 'يتبقى $remainingCount بند لم يتم فحصه بعد. يجب إكمال النموذج للانتقال ${!isLast ? "للمعدة التالية" : "للاعتماد"}.',
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                disabledBackgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
                foregroundColor: Colors.white,
                disabledForegroundColor: isDark
                    ? Colors.grey.shade600
                    : Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: canProceed ? 3 : 0,
              ),
              icon: Icon(
                isLast
                    ? (allDone ? Icons.verified_rounded : Icons.arrow_forward_rounded)
                    : Icons.arrow_forward_rounded,
                size: 22,
                color: canProceed
                    ? Colors.white
                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              ),
              label: Text(
                !isLast
                    ? (isAllCompleted
                        ? 'المعدة التالية (${nextTx?.number})'
                        : 'المعدة التالية (متبقي $remainingCount بند)')
                    : (allDone
                        ? 'التالي (الانتقال للاعتماد)'
                        : 'التالي (متبقي $remainingCount بند)'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: canProceed
                      ? Colors.white
                      : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                ),
              ),
              onPressed: canProceed
                  ? () {
                      if (!isLast && nextTx != null) {
                        _selectTransformer(nextTx);
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم الانتقال لفحص المحول التالي: ${nextTx.number} (${nextTx.voltage})'),
                            backgroundColor: const Color(0xFF0F766E),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        _goToReviewApprovalPage();
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Logo/Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRID MAINTENANCE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'نقل الكهرباء National Grid SA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'CL-GM-1400-002-002',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Title: Checklist for Substation Power Transformer',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Wrap(
                spacing: 12,
                children: [
                  Text(
                    'Rev: 00',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Page: 1 of 1',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSelectorCard(bool isDark) {
    final transformers = _selectedSubstation.transformers.isNotEmpty
        ? _selectedSubstation.transformers
        : [_selectedTransformer];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF0F766E).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Substation Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  size: 20,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'بيانات المعدات والمحولات',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'اختر المحول لبدء فحص قائمته على حدة',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  'المحطة: ${_selectedSubstation.name}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Transformer Unit Selection Tabs / Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(transformers.length, (idx) {
              final tx = transformers[idx];
              final isSelected = tx.number == _selectedTransformer.number;
              final unitItems = _transformerItemsMap[tx.number] ?? [];
              final unitCheckedCount = unitItems.where((i) => i.isChecked).length;
              final isUnitComplete = unitCheckedCount == 20 && unitItems.isNotEmpty;
              final isUnlocked = _isTransformerUnlocked(idx);

              return InkWell(
                onTap: () => _onTapTransformerChip(idx, tx),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : (!isUnlocked
                            ? (isDark
                                ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                                : const Color(0xFFF1F5F9).withValues(alpha: 0.6))
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0F766E)
                          : (!isUnlocked
                              ? (isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFCBD5E1).withValues(alpha: 0.7))
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : (!isUnlocked
                                ? Icons.lock_outline_rounded
                                : (isUnitComplete ? Icons.task_alt_rounded : Icons.bolt_rounded)),
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (!isUnlocked
                                ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                                : (isUnitComplete ? const Color(0xFF0F766E) : const Color(0xFF0F766E))),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tx.number,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (!isUnlocked
                                  ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                                  : (isDark ? Colors.white : const Color(0xFF0F172A))),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${tx.voltage})',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : (!isUnlocked
                                  ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : (!isUnlocked
                                  ? (isDark ? const Color(0xFF0F172A) : Colors.grey.shade200)
                                  : (isUnitComplete
                                      ? const Color(0xFF0F766E).withValues(alpha: 0.15)
                                      : (isDark ? const Color(0xFF0F172A) : Colors.white))),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          !isUnlocked
                              ? 'مقفل'
                              : (isUnitComplete ? '20/20 ✓' : '$unitCheckedCount/20'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (!isUnlocked
                                    ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                                    : (isUnitComplete
                                        ? const Color(0xFF0F766E)
                                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Selected Unit Specs Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildSpecItem('رقم المعدة (Bay No.)', _selectedTransformer.number, isDark, isHighlight: true),
                _buildSpecItem('الجهد (Voltage)', _selectedTransformer.voltage, isDark),
                if (_selectedTransformer.mva != null)
                  _buildSpecItem('السعة (Rating)', '${_selectedTransformer.mva} MVA', isDark),
                if (_selectedTransformer.manufacturer != null)
                  _buildSpecItem('المصنع (Mfr)', _selectedTransformer.manufacturer!, isDark),
                if (_selectedTransformer.serial != null && _selectedTransformer.serial != 'N/A')
                  _buildSpecItem('الرقم التسلسلي (S/N)', _selectedTransformer.serial!, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight
            ? const Color(0xFF0F766E).withValues(alpha: isDark ? 0.25 : 0.12)
            : (isDark ? const Color(0xFF0F172A) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFF0F766E).withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? const Color(0xFF0F766E)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistControlsBar(
    bool isDark,
    int checkedCount,
    double completionProgress,
  ) {
    final isAllDone = checkedCount == _items.length && _items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF134E4A), const Color(0xFF042F2E)]
              : [const Color(0xFFCCFBF1), const Color(0xFF99F6E4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'قائمة التدقيق والفحص (Checklist Items)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تم فحص وإكمال $checkedCount من أصل ${_items.length} بنود',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade300
                            : const Color(0xFF115E59),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAllDone
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF0F766E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAllDone) ...[
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isAllDone
                          ? '20/20 مكتمل'
                          : '$checkedCount/${_items.length} مكتمل',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isAllDone
                            ? Colors.white
                            : (isDark
                                ? Colors.tealAccent
                                : const Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completionProgress,
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : Colors.white.withValues(alpha: 0.6),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItemCard(ChecklistItemModel item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isChecked
              ? const Color(0xFF0F766E).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: item.isChecked ? 1.4 : 1.0,
        ),
        boxShadow: item.isChecked
            ? [
                BoxShadow(
                  color: const Color(0xFF0F766E)
                      .withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Checkbox + Number + English Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.isChecked,
                  activeColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      item.isChecked = val ?? false;
                      if (item.isChecked && item.comment.isEmpty) {
                        item.comment = item.defaultComment;
                        _commentControllers[item.id]?.text =
                            item.defaultComment;
                      }
                    });
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${item.number}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.arabicTitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Sub-tasks list if any
            if (item.subTasks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 38, left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(item.subTasks.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${item.subTasks[idx]} ',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (idx < item.arabicSubTasks.length)
                                    TextSpan(
                                      text: '(${item.arabicSubTasks[idx]})',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Item-Specific Interactive Input Controls
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 12),
              child: _buildItemInputSection(item, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemInputSection(ChecklistItemModel item, bool isDark) {
    if (item.number == 6) {
      // Item #6: Tap Position Slider (1 to 32)
      return _buildTapPositionSlider(item, isDark);
    } else if (item.number == 7) {
      // Item #7: Tap Changer Counter Reading (Numeric keyboard - digits only)
      return _buildCounterReadingField(item, isDark);
    } else if (item.number == 8) {
      // Item #8: Oil Temperature (Numeric keyboard with °C)
      return _buildTemperatureField(
        item,
        isDark,
        label: 'درجة حرارة زيت المحول OTI (أرقام فقط بالمئوية):',
        hint: 'أدخل قراءة حرارة الزيت (مثال: 48)',
      );
    } else if (item.number == 9) {
      // Item #9: HV Winding Temperature (Numeric keyboard with °C)
      return _buildTemperatureField(
        item,
        isDark,
        label: 'حرارة ملفات الجهد العالي HV WTI (أرقام فقط بالمئوية):',
        hint: 'أدخل قراءة حرارة ملفات الجهد العالي (مثال: 55)',
      );
    } else if (item.number == 10) {
      // Item #10: LV Winding Temperature (Numeric keyboard with °C)
      return _buildTemperatureField(
        item,
        isDark,
        label: 'حرارة ملفات الجهد المنخفض LV WTI (أرقام فقط بالمئوية):',
        hint: 'أدخل قراءة حرارة ملفات الجهد المنخفض (مثال: 52)',
      );
    } else {
      // Standard Comments / Observations Area with Quick Selector Chips
      return _buildStandardCommentSection(item, isDark);
    }
  }

  /// Item #6: Interactive Slider for Tap Position (1 to 32)
  Widget _buildTapPositionSlider(ChecklistItemModel item, bool isDark) {
    // Extract integer value from current comment, defaulting to 9
    int currentTap = 9;
    final match = RegExp(r'\d+').firstMatch(item.comment);
    if (match != null) {
      currentTap = int.tryParse(match.group(0) ?? '9') ?? 9;
    }
    currentTap = currentTap.clamp(1, 32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 16, color: Color(0xFF0F766E)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'موضع التفريع (Tap Position 1 - 32):',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Tap $currentTap',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Slider with - and + step buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 24,
                  color: Color(0xFF0F766E),
                ),
                tooltip: 'إنقاص خطوة (Tap - 1)',
                onPressed: currentTap > 1
                    ? () {
                        setState(() {
                          final newVal = currentTap - 1;
                          item.comment = 'Tap $newVal';
                          _commentControllers[item.id]?.text = item.comment;
                          item.isChecked = true;
                        });
                      }
                    : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF0F766E),
                    inactiveTrackColor:
                        const Color(0xFF0F766E).withValues(alpha: 0.2),
                    thumbColor: const Color(0xFF0F766E),
                    overlayColor:
                        const Color(0xFF0F766E).withValues(alpha: 0.15),
                    valueIndicatorColor: const Color(0xFF0F766E),
                    valueIndicatorTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Slider(
                    value: currentTap.toDouble(),
                    min: 1.0,
                    max: 32.0,
                    divisions: 31,
                    label: 'Tap $currentTap',
                    onChanged: (val) {
                      setState(() {
                        final newTap = val.round();
                        item.comment = 'Tap $newTap';
                        _commentControllers[item.id]?.text = item.comment;
                        item.isChecked = true;
                      });
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 24,
                  color: Color(0xFF0F766E),
                ),
                tooltip: 'زيادة خطوة (Tap + 1)',
                onPressed: currentTap < 32
                    ? () {
                        setState(() {
                          final newVal = currentTap + 1;
                          item.comment = 'Tap $newVal';
                          _commentControllers[item.id]?.text = item.comment;
                          item.isChecked = true;
                        });
                      }
                    : null,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1 (أدنى موضع)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  '16 (الوسط)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  '32 (أعلى موضع)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Item #7: Numeric Input for Counter Reading (digits only)
  Widget _buildCounterReadingField(ChecklistItemModel item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pin_rounded, size: 16, color: Color(0xFF0F766E)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'قراءة عداد العمليات (Counter Reading - أرقام فقط):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _commentControllers[item.id],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              hintText: 'أدخل قراءة العداد التراكمي (مثال: 12450)',
              prefixIcon: const Icon(
                Icons.speed_rounded,
                size: 18,
                color: Color(0xFF0F766E),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              filled: true,
              suffixIcon: item.comment.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          item.comment = '';
                          _commentControllers[item.id]?.clear();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              item.comment = val.trim();
              if (val.trim().isNotEmpty && !item.isChecked) {
                setState(() {
                  item.isChecked = true;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  /// Items #8, #9, #10: Numeric Input for Temperatures (°C)
  Widget _buildTemperatureField(
    ChecklistItemModel item,
    bool isDark, {
    required String label,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.device_thermostat_rounded,
                size: 16,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _commentControllers[item.id],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(
                Icons.thermostat_rounded,
                size: 18,
                color: Color(0xFF0F766E),
              ),
              suffixText: '°C',
              suffixStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              filled: true,
              suffixIcon: item.comment.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          item.comment = '';
                          _commentControllers[item.id]?.clear();
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              item.comment = val.trim();
              if (val.trim().isNotEmpty && !item.isChecked) {
                setState(() {
                  item.isChecked = true;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  /// Standard Comments Section with Choice Chips for Other Items
  Widget _buildStandardCommentSection(ChecklistItemModel item, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.quickComments.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Comments / القراءات:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              ...item.quickComments.map((chipText) {
                final isSelected = item.comment == chipText;
                return ChoiceChip(
                  label: Text(chipText, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  selectedColor:
                      const Color(0xFF0F766E).withValues(alpha: 0.25),
                  onSelected: (selected) {
                    setState(() {
                      item.comment = selected ? chipText : '';
                      _commentControllers[item.id]?.text = item.comment;
                      if (selected) {
                        item.isChecked = true;
                      }
                    });
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
        ],
        // Comment Text Field
        TextFormField(
          controller: _commentControllers[item.id],
          onChanged: (val) {
            item.comment = val.trim();
            if (val.trim().isNotEmpty && !item.isChecked) {
              setState(() {
                item.isChecked = true;
              });
            }
          },
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            hintText:
                'سجل الملاحظات، القيم، أو القراءات هنا (مثال: ${item.defaultComment})',
            hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: item.comment.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        item.comment = '';
                        _commentControllers[item.id]?.clear();
                      });
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
