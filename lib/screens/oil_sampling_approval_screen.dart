import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import '../services/pdf_generator_service.dart';
import 'pdf_preview_screen.dart';

class OilSamplingApprovalScreen extends StatefulWidget {
  final FormModel form;
  final SubstationModel selectedSubstation;
  final List<TransformerInfo> selectedTransformers;
  final String initialDivision;
  final String initialDepartment;
  final String initialContactPerson;
  final String initialSampleTemp;
  final String initialInspectionDate;
  final Set<String> equipmentTypes;
  final Set<String> samplingPoints;
  final Set<String> otherSamplingPoints;
  final Set<String> testsRequired;
  final Set<String> reasonsForTest;

  const OilSamplingApprovalScreen({
    super.key,
    required this.form,
    required this.selectedSubstation,
    required this.selectedTransformers,
    required this.initialDivision,
    required this.initialDepartment,
    required this.initialContactPerson,
    required this.initialSampleTemp,
    required this.initialInspectionDate,
    required this.equipmentTypes,
    required this.samplingPoints,
    required this.otherSamplingPoints,
    required this.testsRequired,
    required this.reasonsForTest,
  });

  @override
  State<OilSamplingApprovalScreen> createState() =>
      _OilSamplingApprovalScreenState();
}

class _OilSamplingApprovalScreenState extends State<OilSamplingApprovalScreen> {
  final _formKey = GlobalKey<FormState>();

  // RESULTS SEND TO Controllers
  late TextEditingController _resultsNameController;
  late TextEditingController _resultsEmailController;
  late TextEditingController _resultsPhoneController;

  // Sampler Details Controllers
  late TextEditingController _samplerNameController;
  late TextEditingController _samplerIdController;
  late TextEditingController _samplerPhoneController;
  late TextEditingController _sampleTempController;

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _resultsNameController = TextEditingController(text: '');
    _resultsEmailController = TextEditingController(text: '');
    _resultsPhoneController = TextEditingController(text: '');

    _samplerNameController =
        TextEditingController(text: widget.initialContactPerson);
    _samplerIdController = TextEditingController(text: '');
    _samplerPhoneController = TextEditingController(text: '');
    _sampleTempController =
        TextEditingController(text: widget.initialSampleTemp);
  }

  @override
  void dispose() {
    _resultsNameController.dispose();
    _resultsEmailController.dispose();
    _resultsPhoneController.dispose();
    _samplerNameController.dispose();
    _samplerIdController.dispose();
    _samplerPhoneController.dispose();
    _sampleTempController.dispose();
    super.dispose();
  }

  Future<void> _handleExportPdf() async {
    setState(() => _isGenerating = true);

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
      final pdfBytes = await PdfGeneratorService.generateOilSamplingPdf(
        substation: widget.selectedSubstation,
        selectedTransformers: widget.selectedTransformers,
        workOrder: '',
        sampleTemp: _sampleTempController.text.trim(),
        resultsSendToName: _resultsNameController.text.trim(),
        resultsSendToEmail: _resultsEmailController.text.trim(),
        resultsSendToPhone: _resultsPhoneController.text.trim(),
        samplerName: _samplerNameController.text.trim(),
        samplerId: _samplerIdController.text.trim(),
        samplerPhone: _samplerPhoneController.text.trim(),
        inspectionDate: widget.initialInspectionDate,
        division: widget.initialDivision,
        department: widget.initialDepartment,
        equipmentTypes: widget.equipmentTypes,
        samplingPoints: widget.samplingPoints,
        otherSamplingPoints: widget.otherSamplingPoints,
        testsRequired: widget.testsRequired,
        reasonsForTest: widget.reasonsForTest,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      setState(() => _isGenerating = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            workOrder: '',
            substationName: widget.selectedSubstation.name,
            pageTitle: 'نموذج عينات الزيت (INSULATING OIL SAMPLE)',
            pdfFileName:
                'OIL_SAMPLING_${widget.selectedSubstation.name}_${widget.initialInspectionDate.replaceAll('/', '_')}.pdf',
            initialPageFormat: PdfPageFormat.a4,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        setState(() => _isGenerating = false);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اعتماد وتصدير نموذج عينات الزيت',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Substation & Inspection Summary Card
                    _buildSummaryCard(isDark),
                    const SizedBox(height: 16),

                    // 2. RESULTS SEND TO : (إرسال النتائج إلى)
                    _buildResultsSendToCard(isDark),
                    const SizedBox(height: 16),

                    // 3. Sampler & Inspection Verification Card
                    _buildSamplerVerificationCard(isDark),
                    const SizedBox(height: 16),

                    // 4. Samples & Tests Summary Card
                    _buildTestsSummaryCard(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom Action Bar with "تصدير PDF"
              _buildBottomBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Color(0xFF0F766E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'محطة ${widget.selectedSubstation.name} (${widget.selectedSubstation.region})',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.initialDivision,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Text(
                'المعدات المختارة:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.selectedTransformers.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        t.number,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تاريخ السحب: ${widget.initialInspectionDate}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                ),
              ),
              if (widget.initialSampleTemp.isNotEmpty)
                Text(
                  'حرارة العينة: ${widget.initialSampleTemp} °C',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSendToCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0F766E).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESULTS SEND TO :',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'إرسال نتائج التحليل المخبري إلى:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Name:
          const Text(
            'Name :',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: _resultsNameController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'مثال: Substation Maintenance Dept',
              prefixIcon: const Icon(Icons.business_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),

          // 2. E-mail :
          const Text(
            'E-mail (البريد الإلكتروني):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: _resultsEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'مثال: email@sec.com.sa',
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),

          // 3. Phone/Mobile :
          const Text(
            'Phone/Mobile (الهاتف / الجوال):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: _resultsPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'مثال: 05xxxxxxxx / 013xxxxxxx',
              prefixIcon: const Icon(Icons.phone_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              filled: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSamplerVerificationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'بيانات القائم بسحب العينة (SAMPLE DRAWN BY)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sampler Name
          const Text(
            'SAMPLE DRAWN BY (اسم الفني / المهندس):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: _samplerNameController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'اسم الشخص القائم بالسحب',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),

          // Row: ID & Phone
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ID (الرقم الوظيفي):',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _samplerIdController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'الرقم الوظيفي',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 17),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TEL/MOB (رقم الجوال):',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _samplerPhoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'رقم الاتصال',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 17),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestsSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الفحوصات المطلوبة وأماكن العينات المحددة:',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...widget.samplingPoints.map((p) => _buildChip(p, const Color(0xFF2563EB))),
              ...widget.otherSamplingPoints.map((o) => _buildChip(o, const Color(0xFF7C3AED))),
              ...widget.testsRequired.map((t) => _buildChip(t, const Color(0xFF059669))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Main Action Button: تصدير PDF
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 20,
              color: Colors.white,
            ),
            label: const Text(
              'تصدير PDF',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: _isGenerating ? null : _handleExportPdf,
          ),

          // Back Button: رجوع
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.grey.shade300 : const Color(0xFF334155),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'رجوع',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
