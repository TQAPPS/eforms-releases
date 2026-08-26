import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import 'inspection_approval_screen.dart';

class GridMaintenanceScreen extends StatefulWidget {
  final FormModel form;
  final SubstationModel? selectedSubstation;
  final String? initialWorkOrder;
  final String? initialInspectionDate;

  const GridMaintenanceScreen({
    super.key,
    required this.form,
    this.selectedSubstation,
    this.initialWorkOrder,
    this.initialInspectionDate,
  });

  @override
  State<GridMaintenanceScreen> createState() => _GridMaintenanceScreenState();
}

class _GridMaintenanceScreenState extends State<GridMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Scroll controllers for auto-scrolling to top when navigating
  final ScrollController _powerScrollController = ScrollController();
  final ScrollController _auxScrollController = ScrollController();
  final ScrollController _spareScrollController = ScrollController();

  late SubstationModel _currentSubstation;
  late TextEditingController _workOrderController;
  late String _inspectionDate;

  // Active transformer selection
  int _selectedPowerTxIndex = 0;
  int _selectedAuxTxIndex = 0;

  // Dynamic Inspection Data Store for Power Transformers
  late List<Map<String, dynamic>> _powerTransformersData;

  // Inspection Data Store for Auxiliary Transformers / Shunt Reactor (4 units)
  late List<Map<String, dynamic>> _auxTransformersData;

  // Spare Transformers state
  bool? _hasSpareTransformer;
  int _spareCount = 1;
  final List<Map<String, TextEditingController>> _spareTransformersControllers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _currentSubstation = widget.selectedSubstation ??
        NationalGridData.substations.firstWhere(
          (s) => s.name == 'JIC',
          orElse: () => NationalGridData.substations.first,
        );

    _workOrderController =
        TextEditingController(text: widget.initialWorkOrder ?? '');
    _inspectionDate = widget.initialInspectionDate ??
        DateFormat('yyyy/MM/dd').format(DateTime.now());

    _initTransformersData();
  }

  void _scrollToTop(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _editWorkOrderDialog() {
    final tempController = TextEditingController(text: _workOrderController.text);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text(
                'رقم أمر العمل (Work Order)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: TextField(
            controller: tempController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              hintText: 'أدخل رقم أمر العمل (أرقام فقط مثال: 8842910)',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _workOrderController.text = tempController.text.trim();
                });
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _initSpareTransformers(int count) {
    for (var m in _spareTransformersControllers) {
      m['number']?.dispose();
      m['condition']?.dispose();
    }
    _spareTransformersControllers.clear();
    for (int i = 0; i < count; i++) {
      _spareTransformersControllers.add({
        'number': TextEditingController(text: 'T-SPARE-0${i + 1}'),
        'condition': TextEditingController(text: ''),
      });
    }
  }

  bool _isSpareTabComplete() {
    if (_hasSpareTransformer == null) return false;
    if (_hasSpareTransformer == false) return true;
    for (var m in _spareTransformersControllers) {
      if ((m['number']?.text.trim() ?? '').isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _initTransformersData() {
    // Generate power transformer inspection data dynamically based on the current substation
    final txList = _currentSubstation.transformers;
    if (txList.isNotEmpty) {
      _powerTransformersData = txList.map((t) => _createDefaultTxData(t.number, t.voltage)).toList();
    } else {
      _powerTransformersData = List.generate(
          6, (index) => _createDefaultTxData('T${index + 1}', '132/13.8 kV'));
    }

    // Generate auxiliary transformers dynamically based on the current substation
    final auxList = _currentSubstation.auxTransformers;
    if (auxList.isNotEmpty) {
      _auxTransformersData = auxList.map((t) => _createDefaultTxData(t.number, t.voltage)).toList();
    } else {
      // Dynamic generation based on substation capacity (2 to 4 aux units)
      final isMajorStation = _currentSubstation.transformers.any((t) => t.voltage.contains('380')) ||
          _currentSubstation.transformers.length >= 3;
      final int auxCount = isMajorStation ? 3 : 2;

      _auxTransformersData = List.generate(
        auxCount,
        (index) => _createDefaultTxData(
          'AUX-T${index + 1}',
          '13.8/0.4 kV (${index == 0 ? "2 MVA" : "1.5 MVA"})',
        ),
      );
    }

    _selectedPowerTxIndex = 0;
    _selectedAuxTxIndex = 0;
  }

  // Get list of missing/empty inspection items for a transformer
  List<String> _getIncompleteFields(Map<String, dynamic> txData) {
    final Map<String, String> requiredFields = {
      'oilLeakage': '1. تسريب ومستوى الزيت',
      'silicaGelMainTank': '2. سيليكا جل الخزان الرئيسي',
      'silicaGelTapChanger': '3. سيليكا جل مغير الجهد',
      'oilLevelMainConservator': '4. مستوى زيت التمدد الرئيسي',
      'oilLevelTapChanger': '5. مستوى زيت مغير الجهد',
      'tapPosition': '6. موضع المغيّر (Tap Position)',
      'tapCounter': '7. عداد المغيّر (Counter Reading)',
      'oilTemp': '8. حرارة الزيت (°C)',
      'hvWindingTemp': '9. حرارة ملفات الجهد العالي (°C)',
      'lvWindingTemp': '10. حرارة ملفات الجهد المنخفض (°C)',
      'coolingFansPump': '11. مراوح ومضخات التبريد',
      'controlCabinetSealed': '12. إحكام إغلاق الكابينة',
      'heaterOperation': '13. السخانات والإنارة',
      'dgaMonitor': '14. مراقبة الغازات الذائبة (DGA)',
      'generalCondition': '15. التأريض والصدأ والدهان',
      'bushings': '16. العوازل والاختراقات',
    };

    final List<String> missing = [];
    requiredFields.forEach((key, label) {
      final val = txData[key];
      if (val == null || val.toString().trim().isEmpty) {
        missing.add(label);
      }
    });

    return missing;
  }

  // Check if all 16 items of a transformer are filled
  bool _isTxComplete(Map<String, dynamic> txData) {
    return _getIncompleteFields(txData).isEmpty;
  }

  // Count how many items out of 16 are filled
  int _completedItemsCount(Map<String, dynamic> txData) {
    return 16 - _getIncompleteFields(txData).length;
  }

  // Show warning dialog when attempting to skip an incomplete transformer
  void _showIncompleteWarningDialog({
    required String txName,
    required List<String> missingFields,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 26),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تنبيه: يلزم إكمال الفحص',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لا يمكن تخطي ($txName) إلى جهاز آخر حتى يتم تعبئة كافة عناصر الفحص الـ 16 كاملة.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? Colors.grey.shade300 : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.checklist_rtl_rounded,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'العناصر غير المكتملة (${missingFields.length} عنصر):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: missingFields.map((f) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'استكمال تعبئة المحول الآن',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Switch power transformer with validation
  void _switchPowerTransformer(int targetIndex) {
    if (targetIndex == _selectedPowerTxIndex) return;

    final currentTx = _powerTransformersData[_selectedPowerTxIndex];
    final missing = _getIncompleteFields(currentTx);

    if (missing.isNotEmpty) {
      _showIncompleteWarningDialog(
        txName: currentTx['txName'] ?? 'المحول الحالي',
        missingFields: missing,
      );
      return;
    }

    setState(() {
      _selectedPowerTxIndex = targetIndex;
    });
    _scrollToTop(_powerScrollController);
  }

  // Switch auxiliary transformer with validation
  void _switchAuxTransformer(int targetIndex) {
    if (targetIndex == _selectedAuxTxIndex) return;

    final currentTx = _auxTransformersData[_selectedAuxTxIndex];
    final missing = _getIncompleteFields(currentTx);

    if (missing.isNotEmpty) {
      _showIncompleteWarningDialog(
        txName: currentTx['txName'] ?? 'محول المساعدات الحالي',
        missingFields: missing,
      );
      return;
    }

    setState(() {
      _selectedAuxTxIndex = targetIndex;
    });
    _scrollToTop(_auxScrollController);
  }

  Map<String, dynamic> _createDefaultTxData(String txName, String voltage) {
    return {
      'txName': txName,
      'voltage': voltage,
      'oilLeakage': '',
      'silicaGelMainTank': '',
      'silicaGelTapChanger': '',
      'oilLevelMainConservator': '',
      'oilLevelTapChanger': '',
      'tapPosition': '',
      'tapCounter': '',
      'oilTemp': '',
      'hvWindingTemp': '',
      'lvWindingTemp': '',
      'coolingFansPump': '',
      'controlCabinetSealed': '',
      'heaterOperation': '',
      'dgaMonitor': '',
      'generalCondition': '',
      'bushings': '',
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _workOrderController.dispose();
    _powerScrollController.dispose();
    _auxScrollController.dispose();
    _spareScrollController.dispose();
    for (var m in _spareTransformersControllers) {
      m['number']?.dispose();
      m['condition']?.dispose();
    }
    super.dispose();
  }

  void _pickInspectionDate() async {
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
      setState(() {
        _inspectionDate = DateFormat('yyyy/MM/dd').format(picked);
      });
    }
  }

  // Interactive Tap Position Slider Modal (1 to maxTap)
  void _showTapPositionSliderModal(
    BuildContext context,
    Map<String, dynamic> txData,
    bool isDark,
    VoidCallback onUpdated, {
    int maxTap = 32,
  }) {
    final rawVal = (txData['tapPosition'] ?? '').toString();
    int currentTap = maxTap == 5 ? 3 : 9;
    final parsed = int.tryParse(rawVal.replaceAll(RegExp(r'[^0-9]'), ''));
    if (parsed != null && parsed >= 1 && parsed <= maxTap) {
      currentTap = parsed;
    }

    int selectedTap = currentTap;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF0284C7),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تحديد موضع المغيّر (Tap Position)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'اسحب شريط السلايدر لاختيار موضع مغير الجهد من 1 إلى $maxTap',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Big Display Badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0284C7)
                                .withValues(alpha: isDark ? 0.25 : 0.1),
                            const Color(0xFF0369A1)
                                .withValues(alpha: isDark ? 0.35 : 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF0284C7)
                              .withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFF0284C7),
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tap $selectedTap',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0284C7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedTap == (maxTap == 5 ? 3 : 9)
                                ? 'الموضع الاسمي / الوسطي القياسي (Nominal Tap)'
                                : 'موضع مغير الجهد: $selectedTap من $maxTap',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Slider Controls Row (-1, Slider, +1)
                    Row(
                      children: [
                        // Minus 1 Button
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7)
                                .withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFF0284C7),
                          ),
                          icon: const Icon(Icons.remove_rounded),
                          tooltip: 'إنقاص 1',
                          onPressed: selectedTap > 1
                              ? () => setModalState(() => selectedTap--)
                              : null,
                        ),

                        // The Slider (1 to maxTap)
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF0284C7),
                              thumbColor: const Color(0xFF0284C7),
                              overlayColor: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.2),
                              valueIndicatorColor: const Color(0xFF0284C7),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12,
                                elevation: 4,
                              ),
                            ),
                            child: Slider(
                              value: selectedTap.toDouble(),
                              min: 1.0,
                              max: maxTap.toDouble(),
                              divisions: maxTap > 1 ? maxTap - 1 : 1,
                              label: 'Tap $selectedTap',
                              onChanged: (val) {
                                setModalState(() {
                                  selectedTap = val.round();
                                });
                              },
                            ),
                          ),
                        ),

                        // Plus 1 Button
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7)
                                .withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFF0284C7),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'زيادة 1',
                          onPressed: selectedTap < maxTap
                              ? () => setModalState(() => selectedTap++)
                              : null,
                        ),
                      ],
                    ),

                    // Min and Max Labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '1 (الحد الأدنى)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${(maxTap + 1) ~/ 2} (المنتصف)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$maxTap (الحد الأقصى)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons (Confirm and Clear)
                    Row(
                      children: [
                        // Clear / Empty button
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('مسح (فارغ)'),
                            onPressed: () {
                              txData['tapPosition'] = '';
                              Navigator.pop(ctx);
                              onUpdated();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Confirm Tap Position Button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.check_rounded,
                                color: Colors.white),
                            label: Text(
                              'تأكيد الموضع (Tap $selectedTap)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              txData['tapPosition'] = 'Tap $selectedTap';
                              Navigator.pop(ctx);
                              onUpdated();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }



  void _navigateToApprovalScreen() {
    // 1. Validate all Power Transformers are 100% complete
    for (int i = 0; i < _powerTransformersData.length; i++) {
      final tx = _powerTransformersData[i];
      final missing = _getIncompleteFields(tx);
      if (missing.isNotEmpty) {
        setState(() {
          _tabController.index = 0;
          _selectedPowerTxIndex = i;
        });
        _showIncompleteWarningDialog(
          txName: 'محول القدرة (${tx['txName']})',
          missingFields: missing,
        );
        return;
      }
    }

    // 2. Validate all Auxiliary Transformers are 100% complete
    for (int i = 0; i < _auxTransformersData.length; i++) {
      final tx = _auxTransformersData[i];
      final missing = _getIncompleteFields(tx);
      if (missing.isNotEmpty) {
        setState(() {
          _tabController.index = 1;
          _selectedAuxTxIndex = i;
        });
        _showIncompleteWarningDialog(
          txName: 'محول المساعدات (${tx['txName']})',
          missingFields: missing,
        );
        return;
      }
    }

    // 3. Validate Spare Tab is answered
    if (!_isSpareTabComplete()) {
      setState(() {
        _tabController.index = 2;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد حالة محولات الاحتياط أولاً'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final List<Map<String, String>> spareData =
        _spareTransformersControllers.map((m) {
      return {
        'number': m['number']?.text ?? '',
        'condition': m['condition']?.text ?? '',
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => InspectionApprovalScreen(
          substation: _currentSubstation,
          workOrder: _workOrderController.text,
          inspectionDate: _inspectionDate,
          powerTransformersData: _powerTransformersData,
          auxTransformersData: _auxTransformersData,
          hasSpareTransformer: _hasSpareTransformer ?? false,
          spareTransformersData: spareData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'الرجوع إلى الصفحة الرئيسية',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.form.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'نقل الكهرباء | ${_currentSubstation.name}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: const [
          SizedBox(width: 48), // Balancing leading back button for true center alignment
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF0284C7),
          unselectedLabelColor:
              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          indicatorColor: const Color(0xFF0284C7),
          indicatorWeight: 3,
          onTap: _handleTabTap,
          tabs: [
            Tab(
              icon: const Icon(Icons.bolt_rounded, size: 20),
              text: 'محولات القدرة (${_powerTransformersData.length})',
            ),
            Tab(
              icon: const Icon(Icons.transform_rounded, size: 20),
              text: 'محولات المساعدات (${_auxTransformersData.length})',
            ),
            const Tab(
              icon: Icon(Icons.inventory_2_outlined, size: 20),
              text: 'محولات الاحتياط',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Tab 1: Power Transformers
                    _buildPowerTransformersTab(isDark),

                    // Tab 2: Auxiliary Transformers / Shunt Reactor
                    _buildAuxTransformersTab(isDark),

                    // Tab 3: Spare Transformers & Verification
                    _buildSpareAndVerificationTab(isDark),
                  ],
                ),
              ),

              // Bottom Action Bar
              _buildBottomSubmitBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // Tab 1: Power Transformers (Dynamically based on substation)
  Widget _buildPowerTransformersTab(bool isDark) {
    return SingleChildScrollView(
      controller: _powerScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unified Header Card (Substation + Work Order + Inspection Date)
              _buildSectionTitleBadge(
                title: 'Power Transformer - Detailed Monthly Inspection',
                arabicTitle:
                    'فحص محولات القدرة في محطة (${_currentSubstation.name})',
                icon: Icons.electric_bolt_rounded,
                color: const Color(0xFF0369A1),
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              // Transformer Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(_powerTransformersData.length, (index) {
                    final txData = _powerTransformersData[index];
                    final txName = txData['txName'] ?? 'T${index + 1}';
                    final voltage = txData['voltage'] ?? '';
                    final isSelected = _selectedPowerTxIndex == index;
                    final isComplete = _isTxComplete(txData);
                    final completedCount = _completedItemsCount(txData);

                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          '$txName ${voltage.isNotEmpty ? "($voltage)" : ""} ${isComplete ? "✓" : "($completedCount/16)"}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.grey.shade300
                                    : const Color(0xFF1E293B)),
                          ),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        selectedColor: const Color(0xFF0284C7),
                        avatar: Icon(
                          isComplete
                              ? Icons.check_circle_rounded
                              : (isSelected
                                  ? Icons.power_rounded
                                  : Icons.pending_actions_rounded),
                          size: 16,
                          color: isComplete
                              ? (isSelected ? Colors.greenAccent : Colors.green)
                              : (isSelected
                                  ? Colors.white
                                  : Colors.amber.shade700),
                        ),
                        onSelected: (val) {
                          if (val) {
                            _switchPowerTransformer(index);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Active Transformer Inspection Form Card
              if (_powerTransformersData.isNotEmpty)
                _buildTransformerInspectionCard(
                  txData: _powerTransformersData[_selectedPowerTxIndex],
                  isDark: isDark,
                  maxTap: 32,
                  isAux: false,
                  onChanged: () => setState(() {}),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab 2: Auxiliary Transformers / Shunt Reactor (Dynamically based on substation)
  Widget _buildAuxTransformersTab(bool isDark) {
    return SingleChildScrollView(
      controller: _auxScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unified Header Card (Substation + Work Order + Inspection Date)
              _buildSectionTitleBadge(
                title:
                    'Auxiliary Transformers / Shunt Reactor - Detailed Monthly Inspection',
                arabicTitle:
                    'محولات المساعدات في محطة (${_currentSubstation.name})',
                icon: Icons.transform_rounded,
                color: const Color(0xFF0D9488),
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              // Transformer Selector Chips dynamically from _auxTransformersData
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(_auxTransformersData.length, (index) {
                    final txData = _auxTransformersData[index];
                    final txName = txData['txName'] ?? 'AUX-T${index + 1}';
                    final voltage = txData['voltage'] ?? '';
                    final isSelected = _selectedAuxTxIndex == index;
                    final isComplete = _isTxComplete(txData);
                    final completedCount = _completedItemsCount(txData);

                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          '$txName ${voltage.isNotEmpty ? "($voltage)" : ""} ${isComplete ? "✓" : "($completedCount/16)"}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.grey.shade300
                                    : const Color(0xFF1E293B)),
                          ),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        selectedColor: const Color(0xFF0D9488),
                        avatar: Icon(
                          isComplete
                              ? Icons.check_circle_rounded
                              : (isSelected
                                  ? Icons.settings_input_component_rounded
                                  : Icons.pending_actions_rounded),
                          size: 16,
                          color: isComplete
                              ? (isSelected ? Colors.greenAccent : Colors.green)
                              : (isSelected
                                  ? Colors.white
                                  : Colors.amber.shade700),
                        ),
                        onSelected: (val) {
                          if (val) {
                            _switchAuxTransformer(index);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Active Transformer Inspection Form Card
              if (_auxTransformersData.isNotEmpty)
                _buildTransformerInspectionCard(
                  txData: _auxTransformersData[_selectedAuxTxIndex],
                  isDark: isDark,
                  maxTap: 5,
                  isAux: true,
                  onChanged: () => setState(() {}),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 16 Items Detailed Inspection Card Widget
  Widget _buildTransformerInspectionCard({
    required Map<String, dynamic> txData,
    required bool isDark,
    int maxTap = 32,
    bool isAux = false,
    required VoidCallback onChanged,
  }) {
    final String voltageInfo =
        txData['voltage'] != null && txData['voltage'].toString().isNotEmpty
            ? ' - الجهد: ${txData['voltage']}'
            : '';

    final int completedCount = _completedItemsCount(txData);
    final bool isComplete = completedCount == 16;

    return Container(
      key: ValueKey('tx_card_${txData['txName']}'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isComplete
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          width: isComplete ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header for selected unit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'عناصر فحص المحول (${txData['txName']})$voltageInfo',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isComplete
                          ? const Color(0xFF10B981)
                          : Colors.amber)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      size: 14,
                      color: isComplete
                          ? const Color(0xFF10B981)
                          : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isComplete
                          ? 'مكتمل (16/16)'
                          : '$completedCount / 16 عنصر مكتمل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isComplete
                            ? const Color(0xFF10B981)
                            : (isDark
                                ? Colors.amber.shade300
                                : Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // 1. Oil Leakage & Level
          _buildDropdownItem(
            label: '1. Oil Leakage (تسريب ومستوى الزيت)',
            subtitle: 'Check level and leakage',
            value: txData['oilLeakage'],
            options: const [
              '',
              'N/A',
              'سليم - لا يوجد تسريب',
              'ترشيح طفيف في الصمامات (متابعة)',
              'يوجد تسريب نشط (إصلاح عاجل)',
            ],
            icon: Icons.opacity_rounded,
            isDark: isDark,
            onChanged: (val) {
              txData['oilLeakage'] = val;
              onChanged();
            },
          ),

          // 2. Silica gel Color main Tank
          _buildDropdownItem(
            label: '2. Silica gel Color main Tank (سيليكا جل الخزان الرئيسي)',
            subtitle: 'Check color & moisture saturation',
            value: txData['silicaGelMainTank'],
            options: const [
              '',
              'N/A',
              'أزرق (جاف وسليم)',
              'تغير لون خفيف (متابعة بالدورية)',
              'وردي مشبع بالكامل (استبدال عاجل)',
            ],
            icon: Icons.colorize_rounded,
            isDark: isDark,
            onChanged: (val) {
              txData['silicaGelMainTank'] = val;
              onChanged();
            },
          ),

          // 3. Silica gel Color Tap Changer
          _buildDropdownItem(
            label: '3. Silica gel Color Tap Changer (سيليكا جل مغير الجهد)',
            subtitle: 'Check color & condition',
            value: txData['silicaGelTapChanger'],
            options: const [
              '',
              'N/A',
              'أزرق (جاف وسليم)',
              'تغير لون خفيف (متابعة بالدورية)',
              'وردي مشبع بالكامل (استبدال عاجل)',
            ],
            icon: Icons.water_drop_outlined,
            isDark: isDark,
            onChanged: (val) {
              txData['silicaGelTapChanger'] = val;
              onChanged();
            },
          ),

          // 4. Oil Level Gauge Main Tank Conservator
          _buildDropdownItem(
            label: '4. Oil Level Gauge Main Tank Conservator (مستوى زيت التمدد)',
            subtitle: 'Check level and leakage',
            value: txData['oilLevelMainConservator'],
            options: const [
              '',
              'N/A',
              'طبيعي (50% عند 30°C)',
              'مرتفع (فوق المعدل)',
              'منخفض (يحتاج تزويد زيت)',
            ],
            icon: Icons.speed_rounded,
            isDark: isDark,
            onChanged: (val) {
              txData['oilLevelMainConservator'] = val;
              onChanged();
            },
          ),

          // 5. Oil Level Gauge Tap Changer
          _buildDropdownItem(
            label: '5. Oil Level Gauge Tap Changer (مستوى زيت مغير الجهد)',
            subtitle: 'Check level and leakage',
            value: txData['oilLevelTapChanger'],
            options: const [
              '',
              'N/A',
              'طبيعي (Normal)',
              'مرتفع (High)',
              'منخفض (Low)',
            ],
            icon: Icons.straighten_rounded,
            isDark: isDark,
            onChanged: (val) {
              txData['oilLevelTapChanger'] = val;
              onChanged();
            },
          ),

          // 6. Tap Position (Interactive Slider) & 7. Counter Reading
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(builder: (context, constraints) {
              final counterWidget = _buildNumericOrNAField(
                label: '7. Counter Reading (عداد المغيّر)',
                value: txData['tapCounter'] ?? '',
                icon: Icons.pin_outlined,
                isDark: isDark,
                onChanged: (val) {
                  txData['tapCounter'] = val;
                  onChanged();
                },
              );

              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    _buildTapPositionField(
                      txData: txData,
                      isDark: isDark,
                      maxTap: maxTap,
                      onChanged: onChanged,
                    ),
                    const SizedBox(height: 10),
                    counterWidget,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildTapPositionField(
                      txData: txData,
                      isDark: isDark,
                      maxTap: maxTap,
                      onChanged: onChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: counterWidget,
                  ),
                ],
              );
            }),
          ),

          // 8. Oil Temp, 9. HV Winding Temp, 10. LV Winding Temp
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(builder: (context, constraints) {
              final oilTempWidget = _buildNumericOrNAField(
                label: '8. Oil Temp (°C)',
                value: txData['oilTemp'] ?? '',
                icon: Icons.device_thermostat_rounded,
                isDark: isDark,
                suffix: '°C',
                onChanged: (val) {
                  txData['oilTemp'] = val;
                  onChanged();
                },
              );

              final hvWidget = _buildNumericOrNAField(
                label: '9. HV Winding Temp (°C)',
                value: txData['hvWindingTemp'] ?? '',
                icon: Icons.thermostat_auto_rounded,
                isDark: isDark,
                suffix: '°C',
                onChanged: (val) {
                  txData['hvWindingTemp'] = val;
                  onChanged();
                },
              );

              final lvWidget = _buildNumericOrNAField(
                label: '10. LV Winding Temp (°C)',
                value: txData['lvWindingTemp'] ?? '',
                icon: Icons.thermostat_rounded,
                isDark: isDark,
                suffix: '°C',
                onChanged: (val) {
                  txData['lvWindingTemp'] = val;
                  onChanged();
                },
              );

              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    oilTempWidget,
                    const SizedBox(height: 10),
                    hvWidget,
                    const SizedBox(height: 10),
                    lvWidget,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: oilTempWidget,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: hvWidget,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: lvWidget,
                  ),
                ],
              );
            }),
          ),

          // 11. Cooling Fans & Pump Operation
          _buildDropdownItem(
            label: '11. Cooling Fans & Pump Operation (مراوح ومضخات التبريد)',
            subtitle:
                'Manually run and return to auto; report abnormal noise',
            value: txData['coolingFansPump'],
            options: const [
              '',
              'N/A',
              'تم التشغيل اليدوي والرجوع للأوتوماتيك - سليم',
              'يوجد اهتزاز أو ضجيج غير طبيعي (ملاحظة)',
              'عطل في إحدى المراوح أو المضخات',
            ],
            icon: Icons.air_rounded,
            isDark: isDark,
            onChanged: (val) {
              txData['coolingFansPump'] = val;
              onChanged();
            },
          ),

          // 12. Control Cabinet Properly Sealed
          _buildDropdownItem(
            label: '12. Control Cabinet Properly Sealed (إحكام إغلاق الكابينة)',
            subtitle:
                'Check that they are properly sealed against dust & rain',
            value: txData['controlCabinetSealed'],
            options: const [
              '',
              'N/A',
              'محكمة الإغلاق ومحمية',
              'تحتاج تبديل حشوة الإغلاق (Gasket)',
              'غير محكمة الإغلاق وبحاجة صيانة',
            ],
            icon: Icons.meeting_room_outlined,
            isDark: isDark,
            onChanged: (val) {
              txData['controlCabinetSealed'] = val;
              onChanged();
            },
          ),

          // 13. Heater Operation in Control Cabinet
          _buildDropdownItem(
            label: '13. Heater & Lights in Cabinet (السخانات والإنارة)',
            subtitle: 'Check operation of lights and heaters',
            value: txData['heaterOperation'],
            options: const [
              '',
              'N/A',
              'السخانات والإنارة تعمل بكفاءة',
              'السخان عاطل وبحاجة صيانة',
              'الإنارة الداخلية لا تعمل',
            ],
            icon: Icons.lightbulb_outline_rounded,
            isDark: isDark,
            onChanged: (val) {
              txData['heaterOperation'] = val;
              onChanged();
            },
          ),

          // 14. On Line DGA Monitor
          _buildDropdownItem(
            label: '14. On Line DGA Monitor (مراقبة الغازات الذائبة)',
            subtitle: 'Check operation and alarm status',
            value: txData['dgaMonitor'],
            options: const [
              '',
              'N/A',
              'يعمل بشكل طبيعي - لا توجد إنذارات',
              'يوجد إنذار ارتفاع غازات (Gas Warning)',
              'عطل في جهاز المراقبة (DGA Fault)',
            ],
            icon: Icons.monitor_heart_outlined,
            isDark: isDark,
            onChanged: (val) {
              txData['dgaMonitor'] = val;
              onChanged();
            },
          ),

          // 15. General condition (Grounding & Corrosion)
          _buildDropdownItem(
            label: '15. General condition (التأريض والصدأ والدهان)',
            subtitle:
                'Check Grounding Securely Connected; Report corrosion & painting',
            value: txData['generalCondition'],
            options: const [
              '',
              'N/A',
              'التأريض محكم ولا يوجد صدأ',
              'صدأ سطحي خفيف يحتاج دهان بالصيانة الدورية',
              'انفصال أو ارتخاء في التأريض (عاجل)',
            ],
            icon: Icons.shield_outlined,
            isDark: isDark,
            onChanged: (val) {
              txData['generalCondition'] = val;
              onChanged();
            },
          ),

          // 16. Bushings
          _buildDropdownItem(
            label: '16. Bushings (العوازل والاختراقات)',
            subtitle:
                'Check condition for drips & cracks, dust; Check oil level',
            value: txData['bushings'],
            options: const [
              '',
              'N/A',
              'العوازل نظيفة وخالية من الشروخ والترشيح',
              'تراكم أتربة خفيف يحتاج تنظيف في الغسيل الدوري',
              'شروخ أو ترشيح زيت يستدعي الاستبدال',
            ],
            icon: Icons.electrical_services_rounded,
            isDark: isDark,
            onChanged: (val) {
              txData['bushings'] = val;
              onChanged();
            },
          ),
        ],
      ),
    );
  }

  // Tab 3: Spare Transformers
  Widget _buildSpareAndVerificationTab(bool isDark) {
    return SingleChildScrollView(
      controller: _spareScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spare Transformers Section Title
              _buildSectionTitleBadge(
                title: 'Spare Transformers Detailed Monthly Inspection',
                arabicTitle: 'محولات الاحتياط في محطة (${_currentSubstation.name})',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFFD97706),
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Question: Is there a spare transformer?
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D33) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'هل يوجد محول احتياطي بالمحطة؟',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Choice Buttons (نعم / لا)
                    Row(
                      children: [
                        // Option: نعم
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _hasSpareTransformer = true;
                                if (_spareTransformersControllers.isEmpty) {
                                  _initSpareTransformers(_spareCount);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _hasSpareTransformer == true
                                    ? const Color(0xFF0284C7)
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasSpareTransformer == true
                                      ? const Color(0xFF0284C7)
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1)),
                                  width: _hasSpareTransformer == true ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasSpareTransformer == true
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: _hasSpareTransformer == true
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.grey.shade400
                                            : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'نعم (يوجد)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _hasSpareTransformer == true
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.grey.shade200
                                                : const Color(0xFF1E293B)),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Option: لا
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _hasSpareTransformer = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _hasSpareTransformer == false
                                    ? const Color(0xFF10B981)
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasSpareTransformer == false
                                      ? const Color(0xFF10B981)
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1)),
                                  width: _hasSpareTransformer == false ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasSpareTransformer == false
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: _hasSpareTransformer == false
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.grey.shade400
                                            : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'لا (لا يوجد)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _hasSpareTransformer == false
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.grey.shade200
                                                : const Color(0xFF1E293B)),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // If YES: Count picker and dynamically generated cards
              if (_hasSpareTransformer == true) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131D33) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'كم عدد المحولات الاحتياطية بالمحطة؟',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_spareCount محول',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Count Chips
                      Wrap(
                        spacing: 10,
                        children: [1, 2, 3, 4].map((count) {
                          final isChosen = _spareCount == count;
                          return ChoiceChip(
                            label: Text('$count محول${count > 2 ? "ات" : ""}'),
                            selected: isChosen,
                            selectedColor: const Color(0xFF0284C7),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                              color: isChosen
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _spareCount = count;
                                  _initSpareTransformers(_spareCount);
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Spare Transformers Inspection Cards
                ...List.generate(_spareTransformersControllers.length, (index) {
                  final controllers = _spareTransformersControllers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131D33) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'محول احتياط ${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: controllers['number'],
                          decoration: const InputDecoration(
                            labelText:
                                'Transformer Number / Specs (رقم ومواصفات المحول الاحتياطي)',
                            prefixIcon: Icon(Icons.tag_rounded, size: 18),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: controllers['condition'],
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText:
                                'General Condition (الحالة العامة وضغط النيتروجين ومستوى الزيت)',
                            prefixIcon: Icon(Icons.checklist_rounded, size: 18),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (_hasSpareTransformer == false) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF10B981),
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تم توثيق عدم وجود محولات احتياطية',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'يمكنك الآن الانتقال مباشرة إلى صفحة الاعتماد والتوقيع الإلكتروني.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Unified Section Header Card (Substation + Work Order + Inspection Date)
  Widget _buildSectionTitleBadge({
    required String title,
    required String arabicTitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool showMetadata = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arabicTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showMetadata) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Right in RTL = Start = Work Order (Interactive)
                  InkWell(
                    onTap: _editWorkOrderDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 13, color: color),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              _workOrderController.text.isNotEmpty
                                  ? 'أمر العمل: ${_workOrderController.text}'
                                  : 'أمر العمل: (انقر للإدخال)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_note_rounded,
                              size: 13, color: color),
                        ],
                      ),
                    ),
                  ),

                  // Left in RTL = End = Inspection Date (Interactive)
                  InkWell(
                    onTap: _pickInspectionDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: color),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              _inspectionDate,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_calendar_rounded,
                              size: 13, color: color),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Dropdown Field Item Helper
  Widget _buildDropdownItem({
    required String label,
    required String subtitle,
    required String value,
    required List<String> options,
    required IconData icon,
    required bool isDark,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: options.contains(value) ? value : options.first,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: options.map((opt) {
              Widget itemChild;
              if (opt.isEmpty) {
                itemChild = Text(
                  '-- فارغ --',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                );
              } else if (opt == 'N/A') {
                itemChild = const Text(
                  'N/A',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                  ),
                );
              } else {
                itemChild = Text(opt, style: const TextStyle(fontSize: 13));
              }

              return DropdownMenuItem<String>(
                value: opt,
                child: itemChild,
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                onChanged(val);
              }
            },
          ),
        ],
      ),
    );
  }

  // Field supporting either numeric typing OR quick N/A toggle
  Widget _buildNumericOrNAField({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    String? suffix,
    required ValueChanged<String> onChanged,
  }) {
    final bool isNA = value.trim().toUpperCase() == 'N/A';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('field_${label}_$isNA'),
            initialValue: isNA ? 'N/A' : value,
            readOnly: isNA,
            keyboardType: isNA
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true, signed: false),
            onChanged: (val) {
              if (!isNA) {
                onChanged(val);
              }
            },
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 18),
              suffixText: (!isNA && suffix != null && value.isNotEmpty) ? suffix : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            if (isNA) {
              onChanged('');
            } else {
              onChanged('N/A');
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: isNA
                  ? const Color(0xFFD97706)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isNA
                    ? const Color(0xFFD97706)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNA ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  size: 16,
                  color: isNA
                      ? Colors.white
                      : (isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 4),
                Text(
                  'N/A',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isNA
                        ? Colors.white
                        : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Interactive Tap Position Input Field Helper
  Widget _buildTapPositionField({
    required Map<String, dynamic> txData,
    required bool isDark,
    int maxTap = 32,
    required VoidCallback onChanged,
  }) {
    final String currentVal = (txData['tapPosition'] ?? '').toString();
    final bool hasValue = currentVal.isNotEmpty;

    return InkWell(
      onTap: () => _showTapPositionSliderModal(
        context,
        txData,
        isDark,
        onChanged,
        maxTap: maxTap,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? const Color(0xFF0284C7)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: hasValue ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded,
                size: 20,
                color: hasValue
                    ? const Color(0xFF0284C7)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '6. Tap Position (موضع المغيّر 1-$maxTap)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? currentVal : '-- اضغط لاختيار السلايدر (1-$maxTap) --',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          hasValue ? FontWeight.bold : FontWeight.normal,
                      color: hasValue
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400),
                      fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.linear_scale_rounded,
                size: 16,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Intercept TabBar taps to validate section completion before allowing section navigation
  void _handleTabTap(int targetIndex) {
    if (targetIndex == 1) {
      // Trying to navigate to Auxiliary Transformers tab
      final bool allPowerComplete =
          _powerTransformersData.every(_isTxComplete);
      if (!allPowerComplete) {
        _tabController.animateTo(0);
        final int incompleteIdx =
            _powerTransformersData.indexWhere((tx) => !_isTxComplete(tx));
        if (incompleteIdx != -1) {
          setState(() {
            _selectedPowerTxIndex = incompleteIdx;
          });
          _showIncompleteWarningDialog(
            txName: _powerTransformersData[incompleteIdx]['txName'] ??
                'محول القدرة',
            missingFields: _getIncompleteFields(
                _powerTransformersData[incompleteIdx]),
          );
        }
      }
    } else if (targetIndex == 2) {
      // Trying to navigate to Spare & Verification tab
      final bool allPowerComplete =
          _powerTransformersData.every(_isTxComplete);
      if (!allPowerComplete) {
        _tabController.animateTo(0);
        final int incompleteIdx =
            _powerTransformersData.indexWhere((tx) => !_isTxComplete(tx));
        if (incompleteIdx != -1) {
          setState(() {
            _selectedPowerTxIndex = incompleteIdx;
          });
          _showIncompleteWarningDialog(
            txName: _powerTransformersData[incompleteIdx]['txName'] ??
                'محول القدرة',
            missingFields: _getIncompleteFields(
                _powerTransformersData[incompleteIdx]),
          );
        }
        return;
      }

      final bool allAuxComplete = _auxTransformersData.every(_isTxComplete);
      if (!allAuxComplete) {
        _tabController.animateTo(1);
        final int incompleteIdx =
            _auxTransformersData.indexWhere((tx) => !_isTxComplete(tx));
        if (incompleteIdx != -1) {
          setState(() {
            _selectedAuxTxIndex = incompleteIdx;
          });
          _showIncompleteWarningDialog(
            txName: _auxTransformersData[incompleteIdx]['txName'] ??
                'محول المساعدات',
            missingFields: _getIncompleteFields(
                _auxTransformersData[incompleteIdx]),
          );
        }
      }
    }
  }

  void _handleNextAction() {
    if (_tabController.index == 0) {
      // Power transformers tab
      if (_selectedPowerTxIndex < _powerTransformersData.length - 1) {
        setState(() {
          _selectedPowerTxIndex++;
        });
        _scrollToTop(_powerScrollController);
      } else {
        // We are on the last power transformer -> Move to Auxiliary Transformers if all power units complete
        final bool allPowerComplete =
            _powerTransformersData.every(_isTxComplete);
        if (allPowerComplete) {
          setState(() {
            _tabController.animateTo(1);
            _selectedAuxTxIndex = 0;
          });
          _scrollToTop(_auxScrollController);
        } else {
          final int incompleteIdx =
              _powerTransformersData.indexWhere((tx) => !_isTxComplete(tx));
          if (incompleteIdx != -1) {
            setState(() {
              _selectedPowerTxIndex = incompleteIdx;
            });
            _showIncompleteWarningDialog(
              txName: _powerTransformersData[incompleteIdx]['txName'] ??
                  'محول القدرة',
              missingFields: _getIncompleteFields(
                  _powerTransformersData[incompleteIdx]),
            );
          }
        }
      }
    } else if (_tabController.index == 1) {
      // Auxiliary transformers tab
      if (_selectedAuxTxIndex < _auxTransformersData.length - 1) {
        setState(() {
          _selectedAuxTxIndex++;
        });
        _scrollToTop(_auxScrollController);
      } else {
        // We are on the last auxiliary transformer -> Move to Spare Transformers if all aux units complete
        final bool allAuxComplete = _auxTransformersData.every(_isTxComplete);
        if (allAuxComplete) {
          setState(() {
            _tabController.animateTo(2);
          });
          _scrollToTop(_spareScrollController);
        } else {
          final int incompleteIdx =
              _auxTransformersData.indexWhere((tx) => !_isTxComplete(tx));
          if (incompleteIdx != -1) {
            setState(() {
              _selectedAuxTxIndex = incompleteIdx;
            });
            _showIncompleteWarningDialog(
              txName: _auxTransformersData[incompleteIdx]['txName'] ??
                  'محول المساعدات',
              missingFields: _getIncompleteFields(
                  _auxTransformersData[incompleteIdx]),
            );
          }
        }
      }
    } else {
      // Tab 3: Spare Transformers -> Open Approval Screen
      _navigateToApprovalScreen();
    }
  }

  // Centered Bottom Action Bar (Next / Approval Screen Button)
  Widget _buildBottomSubmitBar(bool isDark) {
    final int currentTab = _tabController.index;

    bool isActionEnabled = false;
    String buttonText = 'التالي';
    IconData buttonIcon = Icons.arrow_forward_rounded;
    VoidCallback? buttonCallback;

    if (currentTab == 0) {
      // Power Transformers tab
      final bool isLastPowerTx =
          _selectedPowerTxIndex == _powerTransformersData.length - 1;

      if (isLastPowerTx) {
        // On last power unit: enabled ONLY if ALL power transformers in this section are complete
        final bool allPowerComplete =
            _powerTransformersData.every(_isTxComplete);
        isActionEnabled = allPowerComplete;
        buttonText = 'التالي (محولات المساعدات)';
        buttonIcon = Icons.transform_rounded;
      } else {
        // On intermediate power units: enabled if current unit is complete
        final currentTx = _powerTransformersData.isNotEmpty
            ? _powerTransformersData[_selectedPowerTxIndex]
            : null;
        isActionEnabled = currentTx != null && _isTxComplete(currentTx);
        buttonText = 'التالي';
        buttonIcon = Icons.arrow_forward_rounded;
      }
      buttonCallback = isActionEnabled ? _handleNextAction : null;
    } else if (currentTab == 1) {
      // Auxiliary Transformers tab
      final bool isLastAuxTx =
          _selectedAuxTxIndex == _auxTransformersData.length - 1;

      if (isLastAuxTx) {
        // On last aux unit: enabled ONLY if ALL aux transformers in this section are complete
        final bool allAuxComplete = _auxTransformersData.every(_isTxComplete);
        isActionEnabled = allAuxComplete;
        buttonText = 'التالي (محولات الاحتياط)';
        buttonIcon = Icons.inventory_2_outlined;
      } else {
        // On intermediate aux units: enabled if current unit is complete
        final currentTx = _auxTransformersData.isNotEmpty
            ? _auxTransformersData[_selectedAuxTxIndex]
            : null;
        isActionEnabled = currentTx != null && _isTxComplete(currentTx);
        buttonText = 'التالي';
        buttonIcon = Icons.arrow_forward_rounded;
      }
      buttonCallback = isActionEnabled ? _handleNextAction : null;
    } else {
      // Tab 3: Spare Transformers
      final bool allPowerComplete =
          _powerTransformersData.every(_isTxComplete);
      final bool allAuxComplete = _auxTransformersData.every(_isTxComplete);
      final bool isSpareComplete = _isSpareTabComplete();
      final bool isReady =
          allPowerComplete && allAuxComplete && isSpareComplete;

      isActionEnabled = isReady;
      buttonText = 'الانتقال إلى صفحة الاعتماد والتوقيع';
      buttonIcon = Icons.assignment_turned_in_rounded;
      buttonCallback = isActionEnabled ? _navigateToApprovalScreen : null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActionEnabled
                    ? const Color(0xFF0284C7)
                    : (isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0)),
                foregroundColor: isActionEnabled
                    ? Colors.white
                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                disabledBackgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
                disabledForegroundColor:
                    isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                elevation: isActionEnabled ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(buttonIcon, size: 20),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: buttonCallback,
            ),
          ),
        ),
      ),
    );
  }
}
