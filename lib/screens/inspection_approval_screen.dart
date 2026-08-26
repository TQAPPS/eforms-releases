import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../models/substation_model.dart';
import '../services/pdf_generator_service.dart';
import 'pdf_preview_screen.dart';

class InspectionApprovalScreen extends StatefulWidget {
  final SubstationModel substation;
  final String workOrder;
  final String inspectionDate;
  final List<Map<String, dynamic>> powerTransformersData;
  final List<Map<String, dynamic>> auxTransformersData;
  final bool hasSpareTransformer;
  final List<Map<String, String>> spareTransformersData;

  const InspectionApprovalScreen({
    super.key,
    required this.substation,
    required this.workOrder,
    required this.inspectionDate,
    required this.powerTransformersData,
    required this.auxTransformersData,
    required this.hasSpareTransformer,
    required this.spareTransformersData,
  });

  @override
  State<InspectionApprovalScreen> createState() =>
      _InspectionApprovalScreenState();
}

class _InspectionApprovalScreenState extends State<InspectionApprovalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _inspectorController;
  late final TextEditingController _inspectorIdController;
  late final TextEditingController _supervisorController;
  late final TextEditingController _supervisorIdController;
  late final TextEditingController _notesController;

  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _inspectorController = TextEditingController();
    _inspectorIdController = TextEditingController();
    _supervisorController = TextEditingController();
    _supervisorIdController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _inspectorController.dispose();
    _inspectorIdController.dispose();
    _supervisorController.dispose();
    _supervisorIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitFinalReport() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'يرجى تعبئة أسماء المهندسين أو الفنيين وأرقامهم الوظيفية قبل الاعتماد (إجباري)',
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('يرجى تأكيد الإقرار والاعتماد الإلكتروني أسفل الصفحة'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final refNumber =
        'GRID-MNT-${DateTime.now().year}-${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'تم اعتماد وحفظ تقرير الصيانة بنجاح!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تم إنشاء تقرير الفحص الشهري بصيغة PDF الرسمية (GRID MAINTENANCE) لمحطة (${widget.substation.name}).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 14),

              // Reference Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded,
                        size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'الرقم المرجعي: $refNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Button 1: Preview PDF
              SizedBox(
                width: double.infinity,
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
                    'معاينة وحفظ تقرير PDF الرسمي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx); // dismiss dialog
                    final pdfBytes =
                        await PdfGeneratorService.generateInspectionPdf(
                      substation: widget.substation,
                      workOrder: widget.workOrder,
                      inspectionDate: widget.inspectionDate,
                      powerTransformersData: widget.powerTransformersData,
                      auxTransformersData: widget.auxTransformersData,
                      hasSpareTransformer: widget.hasSpareTransformer,
                      spareTransformersData: widget.spareTransformersData,
                      inspectorName: _inspectorController.text.trim(),
                      inspectorId: _inspectorIdController.text.trim(),
                      supervisorName: _supervisorController.text.trim(),
                      supervisorId: _supervisorIdController.text.trim(),
                      technicalNotes: _notesController.text.trim(),
                      referenceNumber: refNumber,
                    );
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfPreviewScreen(
                          pdfBytes: pdfBytes,
                          workOrder: widget.workOrder,
                          substationName: widget.substation.name,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Button 2: Print/Share Direct
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'طباعة ومشاركة PDF مباشرة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    await Printing.layoutPdf(
                      name: 'GRID_MAINTENANCE_${widget.workOrder}',
                      onLayout: (format) async =>
                          PdfGeneratorService.generateInspectionPdf(
                        substation: widget.substation,
                        workOrder: widget.workOrder,
                        inspectionDate: widget.inspectionDate,
                        powerTransformersData: widget.powerTransformersData,
                        auxTransformersData: widget.auxTransformersData,
                        hasSpareTransformer: widget.hasSpareTransformer,
                        spareTransformersData: widget.spareTransformersData,
                        inspectorName: _inspectorController.text.trim(),
                        inspectorId: _inspectorIdController.text.trim(),
                        supervisorName: _supervisorController.text.trim(),
                        supervisorId: _supervisorIdController.text.trim(),
                        technicalNotes: _notesController.text.trim(),
                        referenceNumber: refNumber,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Button 3: Return to Home
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // dismiss dialog
                    Navigator.popUntil(
                        context, (route) => route.isFirst); // back to home
                  },
                  child: const Text(
                    'العودة إلى القائمة الرئيسية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'الاعتماد والتوقيع الإلكتروني',
                style: TextStyle(
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
                '${widget.substation.name} | ${widget.workOrder}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF0284C7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'معاينة تقرير PDF الرسمي',
            onPressed: () async {
              final refNumber =
                  'GRID-MNT-${DateTime.now().year}-${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';
              final pdfBytes = await PdfGeneratorService.generateInspectionPdf(
                substation: widget.substation,
                workOrder: widget.workOrder,
                inspectionDate: widget.inspectionDate,
                powerTransformersData: widget.powerTransformersData,
                auxTransformersData: widget.auxTransformersData,
                hasSpareTransformer: widget.hasSpareTransformer,
                spareTransformersData: widget.spareTransformersData,
                inspectorName: _inspectorController.text.trim(),
                inspectorId: _inspectorIdController.text.trim(),
                supervisorName: _supervisorController.text.trim(),
                supervisorId: _supervisorIdController.text.trim(),
                technicalNotes: _notesController.text.trim(),
                referenceNumber: refNumber,
              );
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfPreviewScreen(
                    pdfBytes: pdfBytes,
                    workOrder: widget.workOrder,
                    substationName: widget.substation.name,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Executive Inspection Summary Card
                          _buildSummaryCard(isDark),
                          const SizedBox(height: 16),

                          // 2. Technical Notes Section
                          _buildTechnicalNotesSection(isDark),
                          const SizedBox(height: 16),

                          // 3. Digital Signatures & Declaration
                          _buildSignaturesSection(isDark),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Action Button
              _buildBottomSubmitBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final powerCount = widget.powerTransformersData.length;
    final auxCount = widget.auxTransformersData.length;
    final spareCount = widget.hasSpareTransformer
        ? widget.spareTransformersData.length
        : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
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
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assessment_rounded,
                    color: Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ملخص فحص محولات المحطة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  title: 'محولات القدرة',
                  count: '$powerCount محولات',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  title: 'محولات المساعدات',
                  count: '$auxCount محولات',
                  icon: Icons.transform_rounded,
                  color: const Color(0xFF0D9488),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  title: 'محولات الاحتياط',
                  count: widget.hasSpareTransformer
                      ? '$spareCount محولات'
                      : 'لا يوجد',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFFD97706),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalNotesSection(bool isDark) {
    return Container(
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
          const Row(
            children: [
              Icon(Icons.note_alt_outlined,
                  size: 20, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text(
                'الملاحظات الفنية',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'الملاحظات الفنية والتوصيات (Notes & Recommendations)',
              hintText: 'اكتب أي ملاحظات أو أعطال أو توصيات للصيانة الدورية...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 50),
                child: Icon(Icons.comment_outlined, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturesSection(bool isDark) {
    return Container(
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
          const Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 20, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'الاعتماد والتوقيع الرقمي المعتمد',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Person 1 (الفاحص / المنفذ)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Text(
                      'المهندس / الفني (الفاحص / المنفذ) - إجباري',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade200 : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _inspectorController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المهندس او الفني',
                    hintText: 'أدخل اسم المهندس أو الفني...',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال اسم المهندس أو الفني (إجباري)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _inspectorIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'الرقم الوظيفي',
                    hintText: 'أدخل الرقم الوظيفي (أرقام فقط)...',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال الرقم الوظيفي (إجباري)';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Person 2 (المشرف / المعتمد)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.engineering_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'المهندس / الفني (المشرف / المعتمد) - إجباري',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade200 : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _supervisorController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المهندس او الفني',
                    hintText: 'أدخل اسم المهندس أو الفني...',
                    prefixIcon: Icon(Icons.engineering_outlined, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال اسم المهندس أو الفني (إجباري)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _supervisorIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'الرقم الوظيفي',
                    hintText: 'أدخل الرقم الوظيفي (أرقام فقط)...',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال الرقم الوظيفي (إجباري)';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() {
                _hasSignature = !_hasSignature;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_hasSignature ? const Color(0xFF10B981) : Colors.grey)
                    .withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_hasSignature ? const Color(0xFF10B981) : Colors.grey)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _hasSignature,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setState(() {
                        _hasSignature = val ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'أقر بصحة واكتمال فحص كافة المحولات والأنظمة المذكورة وفق معايير واشتراطات الشركة السعودية لنقل الكهرباء National Grid SA.',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSubmitBar(bool isDark) {
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
                backgroundColor: _hasSignature
                    ? const Color(0xFF10B981)
                    : (isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0)),
                foregroundColor: _hasSignature
                    ? Colors.white
                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                disabledBackgroundColor:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                disabledForegroundColor:
                    isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                elevation: _hasSignature ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                _hasSignature
                    ? Icons.verified_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
              ),
              label: const Text(
                'اعتماد وحفظ تقرير الصيانة النهائي',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _hasSignature ? _submitFinalReport : null,
            ),
          ),
        ),
      ),
    );
  }
}
