import 'dart:io';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/form_model.dart';
import '../models/substation_model.dart';
import '../services/pdf_generator_service.dart';
import 'pdf_preview_screen.dart';
import 'transformer_checklist_screen.dart';

class ExportedEquipmentPdf {
  final TransformerInfo transformer;
  final Uint8List pdfBytes;
  final String filename;
  final int checkedCount;

  ExportedEquipmentPdf({
    required this.transformer,
    required this.pdfBytes,
    required this.filename,
    required this.checkedCount,
  });
}

class TransformerReviewApprovalScreen extends StatefulWidget {
  final FormModel form;
  final SubstationModel selectedSubstation;
  final TransformerInfo? selectedTransformer;
  final List<TransformerInfo>? substationTransformers;
  final Map<String, List<ChecklistItemModel>>? transformerItemsMap;
  final String initialDivision;
  final String initialDepartment;
  final String initialContactPerson;
  final String initialWorkOrder;
  final String initialInspectionDate;
  final List<ChecklistItemModel> items;

  const TransformerReviewApprovalScreen({
    super.key,
    required this.form,
    required this.selectedSubstation,
    this.selectedTransformer,
    this.substationTransformers,
    this.transformerItemsMap,
    required this.initialDivision,
    required this.initialDepartment,
    required this.initialContactPerson,
    required this.initialWorkOrder,
    required this.initialInspectionDate,
    required this.items,
  });

  @override
  State<TransformerReviewApprovalScreen> createState() =>
      _TransformerReviewApprovalScreenState();
}

class _TransformerReviewApprovalScreenState
    extends State<TransformerReviewApprovalScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _divisionController;
  late TextEditingController _contactPersonController;
  late TextEditingController _departmentController;
  late TextEditingController _workOrderController;
  late TextEditingController _substationController;
  late String _inspectionDate;
  late SubstationModel _selectedSubstation;
  late TransformerInfo _activeTransformer;

  // Electronic Signature / Verification (مخفي ومحفوظ للاستخدام المستقبلي)
  static const bool _showElectronicVerification = false;
  bool _hasSignature = false;
  final TextEditingController _inspectorIdController = TextEditingController();
  final TextEditingController _supervisorNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSubstation = widget.selectedSubstation;

    _activeTransformer = widget.selectedTransformer ??
        (widget.substationTransformers?.isNotEmpty == true
            ? widget.substationTransformers!.first
            : (_selectedSubstation.transformers.isNotEmpty
                ? _selectedSubstation.transformers.first
                : const TransformerInfo(
                    number: 'T1',
                    voltage: '132/13.8 kV',
                    serial: '54190',
                    manufacturer: 'National Grid',
                    mva: '67',
                  )));

    _substationController = TextEditingController(
      text: '${_selectedSubstation.name} (${_selectedSubstation.region})',
    );
    _divisionController = TextEditingController(
      text: widget.initialDivision.isNotEmpty
          ? widget.initialDivision
          : _selectedSubstation.division,
    );
    _departmentController = TextEditingController(
      text: widget.initialDepartment.isNotEmpty
          ? widget.initialDepartment
          : _selectedSubstation.department,
    );
    _contactPersonController = TextEditingController(
      text: widget.initialContactPerson,
    );
    _workOrderController = TextEditingController(
      text: widget.initialWorkOrder,
    );
    _inspectionDate = widget.initialInspectionDate.isNotEmpty
        ? widget.initialInspectionDate
        : DateFormat('yyyy/MM/dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _divisionController.dispose();
    _contactPersonController.dispose();
    _departmentController.dispose();
    _workOrderController.dispose();
    _substationController.dispose();
    _inspectorIdController.dispose();
    _supervisorNameController.dispose();
    super.dispose();
  }

  void _applySubstation(SubstationModel sub) {
    setState(() {
      _selectedSubstation = sub;
      _substationController.text = '${sub.name} (${sub.region})';
      _divisionController.text = sub.division;
      _departmentController.text = sub.department;
    });
  }

  Future<void> _previewOfficialPdf() async {
    final tx = _activeTransformer;
    final itemsToUse = widget.transformerItemsMap?[tx.number] ?? widget.items;
    final pdfBytes = await PdfGeneratorService.generateTransformerChecklistPdf(
      division: _divisionController.text.trim(),
      contactPerson: _contactPersonController.text.trim(),
      department: _departmentController.text.trim(),
      workOrder: _workOrderController.text.trim(),
      substationName: _substationController.text.trim(),
      inspectionDate: _inspectionDate,
      equipmentNo: tx.number,
      equipmentVoltage: tx.voltage,
      equipmentMva: tx.mva ?? '',
      equipmentSerial: tx.serial ?? '',
      equipmentManufacturer: tx.manufacturer ?? '',
      itemsData: itemsToUse.map((item) {
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
          workOrder: _workOrderController.text.trim().isNotEmpty
              ? _workOrderController.text.trim()
              : 'CL-GM-1400',
          substationName: _substationController.text.trim().isNotEmpty
              ? _substationController.text.trim()
              : 'Transformer Checklist',
        ),
      ),
    );
  }

  Future<String?> _savePdfToDevice(Uint8List bytes, String filename) async {
    try {
      String cleanName = filename;
      if (cleanName.toLowerCase().endsWith('.pdf')) {
        cleanName = cleanName.substring(0, cleanName.length - 4);
      }

      // 1. Primary: Save via FileSaver (Native MediaStore / Public Downloads - Visible in phone files)
      final savedPath = await FileSaver.instance.saveFile(
        name: cleanName,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );

      // 2. Also ensure saving to local download / documents as backup
      try {
        if (Platform.isAndroid) {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final f = File('${downloadDir.path}/$filename');
            await f.writeAsBytes(bytes, flush: true);
          }
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final d = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
          final f = File('${d.path}/$filename');
          await f.writeAsBytes(bytes, flush: true);
        }
      } catch (_) {}

      return savedPath;
    } catch (e) {
      debugPrint('Error with FileSaver: $e');
      try {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        } else {
          dir = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        }
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } catch (err) {
        debugPrint('Fallback save error: $err');
      }
    }
    return null;
  }



  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'يرجى استكمال الحقول المطلوبة (رقم أمر العمل، اسم المحطة، المسؤول)',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'جاري اعتماد وتصدير نماذج فحص كافة المعدات...',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'يتم إنشاء ملف PDF رسمي ومستقل لكل محول على حدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final txList = widget.substationTransformers?.isNotEmpty == true
        ? widget.substationTransformers!
        : [
            if (widget.selectedTransformer != null)
              widget.selectedTransformer!
            else
              _activeTransformer
          ];

    final List<ExportedEquipmentPdf> exportedList = [];

    final cleanStation = _substationController.text
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
    final cleanOrder = _workOrderController.text
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');

    for (var tx in txList) {
      final unitItems =
          widget.transformerItemsMap?[tx.number] ?? widget.items;
      final unitCheckedCount = unitItems.where((i) => i.isChecked).length;

      final pdfBytes =
          await PdfGeneratorService.generateTransformerChecklistPdf(
        division: _divisionController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        department: _departmentController.text.trim(),
        workOrder: _workOrderController.text.trim(),
        substationName: _substationController.text.trim(),
        inspectionDate: _inspectionDate,
        equipmentNo: tx.number,
        equipmentVoltage: tx.voltage,
        equipmentMva: tx.mva ?? '',
        equipmentSerial: tx.serial ?? '',
        equipmentManufacturer: tx.manufacturer ?? '',
        itemsData: unitItems.map((item) {
          return {
            'title': item.title,
            'subTasks': item.subTasks,
            'checked': item.isChecked,
            'comments': item.comment,
          };
        }).toList(),
      );

      final filename =
          'Checklist_${tx.number}_${cleanStation}_$cleanOrder.pdf';

      exportedList.add(
        ExportedEquipmentPdf(
          transformer: tx,
          pdfBytes: pdfBytes,
          filename: filename,
          checkedCount: unitCheckedCount,
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    // Show Export Hub Modal Bottom Sheet
    _showExportHubDialog(exportedList);
  }

  void _showExportHubDialog(List<ExportedEquipmentPdf> exportedList) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF0F766E),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تم اعتماد وتصدير نماذج المعدات بنجاح!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'تم إنشاء ${exportedList.length} نموذج رسمي منفصل (نموذج PDF لكل معدة)',
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
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Summary Info Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.assignment_outlined,
                                          size: 18, color: Color(0xFF0F766E)),
                                      SizedBox(width: 6),
                                      Text(
                                        'رقم أمر العمل (W.O):',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F766E),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _workOrderController.text.trim().isNotEmpty
                                          ? _workOrderController.text.trim()
                                          : 'N/A',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المحطة: ${_substationController.text}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    'التاريخ: $_inspectionDate',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        const Text(
                          'نماذج المعدات والمحولات الجاهزة للمشاركة والحفظ:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                            // Equipment PDF Cards List
                            ...exportedList.map((item) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF0F766E)
                                        .withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F766E).withValues(
                                          alpha: isDark ? 0.15 : 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Header: Transformer Number & Badges
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(7),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF0F766E)
                                                          .withValues(
                                                              alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .electric_bolt_rounded,
                                                  color:
                                                      Color(0xFF0F766E),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      'المحول ${item.transformer.number}',
                                                      style: const TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                    Text(
                                                      '${item.transformer.voltage} | ${item.transformer.mva} MVA',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? Colors
                                                                .grey.shade400
                                                            : Colors
                                                                .grey.shade600,
                                                      ),
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F766E)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFF0F766E)
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_rounded,
                                                  size: 13,
                                                  color: Color(0xFF0F766E)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${item.checkedCount}/20 بند',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F766E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // File Info Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.picture_as_pdf_rounded,
                                              size: 16,
                                              color: Color(0xFFEF4444)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              item.filename,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.grey.shade300
                                                    : Colors.grey.shade800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Action Buttons: Share & Save/Print & Preview
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        // 1. Share Button
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0284C7),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(Icons.share_rounded,
                                              size: 16),
                                          label: const Text(
                                            'مشاركة عبر الإيميل / التطبيقات',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () async {
                                            await Printing.sharePdf(
                                              bytes: item.pdfBytes,
                                              filename: item.filename,
                                            );
                                          },
                                        ),

                                        // 2. Save / Print Button
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            side: const BorderSide(
                                                color: Color(0xFF0F766E)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                              Icons.save_alt_rounded,
                                              size: 16,
                                              color: Color(0xFF0F766E)),
                                          label: const Text(
                                            'حفظ على الجهاز / طباعة',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF0F766E),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () async {
                                            final savedPath =
                                                await _savePdfToDevice(
                                                    item.pdfBytes,
                                                    item.filename);
                                            if (mounted && ctx.mounted) {
                                              ScaffoldMessenger.of(ctx)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    savedPath != null
                                                        ? 'تم حفظ ملف المحول ${item.transformer.number} بنجاح على الجهاز.'
                                                        : 'جاري فتح خيارات الحفظ والطباعة...',
                                                  ),
                                                  backgroundColor:
                                                      const Color(0xFF0F766E),
                                                  behavior: SnackBarBehavior
                                                      .floating,
                                                ),
                                              );
                                            }
                                            await Printing.layoutPdf(
                                              onLayout: (format) async =>
                                                  item.pdfBytes,
                                              name: item.filename,
                                            );
                                          },
                                        ),

                                        // 3. Preview Button
                                        IconButton(
                                          tooltip: 'معاينة النموذج',
                                          icon: const Icon(
                                              Icons.visibility_rounded,
                                              size: 20,
                                              color: Color(0xFF0F766E)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PdfPreviewScreen(
                                                  pdfBytes: item.pdfBytes,
                                                  workOrder:
                                                      _workOrderController
                                                          .text,
                                                  substationName:
                                                      '${_substationController.text} (${item.transformer.number})',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),

                            // Back to Home Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.home_rounded),
                                label: const Text(
                                  'الانتهاء والعودة للشاشة الرئيسية',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx); // pop modal
                                  Navigator.pop(context); // pop review
                                  Navigator.pop(context); // pop checklist
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الاعتماد وتأكيد البيانات',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              'بيانات أمر العمل والمحطة وتصدير النماذج',
              style: TextStyle(fontSize: 11, color: Color(0xFF14B8A6)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'معاينة PDF',
            onPressed: _previewOfficialPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step Progress & Checklist Completion Badge
                    _buildCompletionSuccessBanner(isDark),
                    const SizedBox(height: 16),

                    // Section 1: بيانات أمر العمل والمحطة (Header Information)
                    _buildMetadataCard(isDark),
                    const SizedBox(height: 24),

                    // Section 2: قسم الاعتماد والإقرار الإلكتروني (مخفي ومحفوظ للاستخدام المستقبلي)
                    if (_showElectronicVerification) ...[
                      _buildVerificationSection(isDark),
                      const SizedBox(height: 24),
                    ],

                    // Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF0F766E)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xFF0F766E),
                            ),
                            label: const Text(
                              'معاينة PDF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            onPressed: _previewOfficialPdf,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded),
                            label: const Text(
                              'اعتماد وحفظ النموذج',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _submitForm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionSuccessBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0F766E).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.done_all_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تم إكمال فحص كافة البنود الـ 20 بنجاح ✓',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'يرجى مراجعة بيانات أمر العمل والمحطة أدناه ثم إتمام الاعتماد الإلكتروني وحفظ النموذج.',
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildMetadataCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بيانات أمر العمل والمحطة (Header Information)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 1: Division & Department
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildDatasetSelectableField(
                      controller: _divisionController,
                      label: 'Division (القطاع)',
                      hint: 'مثال: SOD / Southern Operating Division',
                      icon: Icons.domain_rounded,
                      options: NationalGridData.allDivisions,
                    ),
                    const SizedBox(height: 12),
                    _buildDatasetSelectableField(
                      controller: _departmentController,
                      label: 'Department (الإدارة / القسم)',
                      hint: 'Substation Maintenance Dept',
                      icon: Icons.business_center_rounded,
                      options: NationalGridData.allDepartments,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDatasetSelectableField(
                      controller: _divisionController,
                      label: 'Division (القطاع)',
                      hint: 'مثال: SOD',
                      icon: Icons.domain_rounded,
                      options: NationalGridData.allDivisions,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDatasetSelectableField(
                      controller: _departmentController,
                      label: 'Department (الإدارة / القسم)',
                      hint: 'Substation Maintenance Dept',
                      icon: Icons.business_center_rounded,
                      options: NationalGridData.allDepartments,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Row 2: Substation Name/No (Under Division & Department)
          _buildSubstationSelector(isDark),
          const SizedBox(height: 12),

          // Row 2.5: Equipment / Transformer Details (رقم المعدة والمحول)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E)
                  .withValues(alpha: isDark ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0F766E).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.substationTransformers != null &&
                    widget.substationTransformers!.length > 1) ...[
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded,
                          size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'المحولات المفحوصة في المحطة (${widget.substationTransformers!.length} محولات مكتملة):',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: widget.substationTransformers!.map((tx) {
                      final isSelected =
                          tx.number == _activeTransformer.number;
                      return ChoiceChip(
                        label: Text('${tx.number} (${tx.voltage})',
                            style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0F766E),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _activeTransformer = tx;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'رقم المعدة / المحول المفحوص:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F766E),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _activeTransformer.number,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                _activeTransformer.voltage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (_activeTransformer.mva != null)
                                'السعة: ${_activeTransformer.mva} MVA',
                              if (_activeTransformer.manufacturer != null)
                                'المصنع: ${_activeTransformer.manufacturer}',
                              if (_activeTransformer.serial != null &&
                                  _activeTransformer.serial != 'N/A')
                                'الرقم التسلسلي: ${_activeTransformer.serial}',
                            ].join(' | '),
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
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 3: Contact Person & Work Order No.
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildTextField(
                      controller: _contactPersonController,
                      label: 'Contact Person (الشخص المسؤول)',
                      hint: 'اسم المهندس أو الفني القائم بالفحص',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _workOrderController,
                      label: 'Work Order No. (رقم أمر العمل)',
                      hint: 'مثال: 8842910',
                      icon: Icons.receipt_long_rounded,
                      isNumeric: true,
                      isRequired: true,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _contactPersonController,
                      label: 'Contact Person (الشخص المسؤول)',
                      hint: 'اسم المهندس / الفني',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _workOrderController,
                      label: 'Work Order No. (رقم أمر العمل)',
                      hint: 'مثال: 8842910',
                      icon: Icons.receipt_long_rounded,
                      isNumeric: true,
                      isRequired: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Row 4: Date Picker
          _buildDatePickerWidget(isDark),
        ],
      ),
    );
  }

  Widget _buildDatasetSelectableField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(icon, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0F766E), size: 22),
              ),
              tooltip: 'اختيار من القائمة الرسمية',
              onSelected: (val) {
                setState(() {
                  controller.text = val;
                });
              },
              itemBuilder: (context) {
                return options.map((opt) {
                  return PopupMenuItem<String>(
                    value: opt,
                    child: Text(opt, style: const TextStyle(fontSize: 12.5)),
                  );
                }).toList();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
          validator: isRequired
              ? (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSubstationSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Substation Name/No (المحطة)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _substationController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'يرجى إدخال اسم المحطة';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText: 'مثال: JIC 380/110kV',
                  prefixIcon: Icon(Icons.account_balance_rounded, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF0F766E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.list_alt_rounded, size: 20),
              tooltip: 'اختيار محطة تحويل (48 محطة)',
              onPressed: () => _showSubstationSearchDialog(isDark),
            ),
          ],
        ),
        if (_selectedSubstation.transformers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _selectedSubstation.transformers.map((tx) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.22 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
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
      ],
    );
  }

  void _showSubstationSearchDialog(bool isDark) {
    String query = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = NationalGridData.substations.where((s) {
              final q = query.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.region.toLowerCase().contains(q) ||
                  s.transformers.any((t) => t.number.toLowerCase().contains(q));
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.power_rounded, color: Color(0xFF0F766E)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'اختر محطة التحويل (National Grid Substations)',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (val) => setModalState(() => query = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم المحطة أو المنطقة أو رقم المحول...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا توجد محطات مطابقة للبحث'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final sub = filtered[idx];
                                final isCur = sub.id == _selectedSubstation.id;
                                return ListTile(
                                  selected: isCur,
                                  selectedTileColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  title: Text(
                                    '${sub.name} (${sub.region})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCur ? const Color(0xFF0F766E) : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${sub.transformers.length} محولات: ${sub.transformers.map((t) => t.number).join(", ")}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: isCur
                                      ? const Icon(Icons.check_circle, color: Color(0xFF0F766E))
                                      : null,
                                  onTap: () {
                                    _applySubstation(sub);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
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

  Widget _buildDatePickerWidget(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date (تاريخ الفحص)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
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
              setState(() {
                _inspectionDate = DateFormat('yyyy/MM/dd').format(picked);
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
                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0F766E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _inspectionDate,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(
                  'تغيير التاريخ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'الاعتماد والإقرار الإلكتروني (Electronic Verification)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inspector ID & Supervisor Name
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildTextField(
                      controller: _inspectorIdController,
                      label: 'الرقم الوظيفي للقائم بالفحص (Inspector ID)',
                      hint: 'مثال: 56980',
                      icon: Icons.badge_rounded,
                      isNumeric: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _supervisorNameController,
                      label: 'اسم المشرف المعتمد (Supervisor Name)',
                      hint: 'اسم مهندس الصيانة المشرف',
                      icon: Icons.manage_accounts_rounded,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _inspectorIdController,
                      label: 'الرقم الوظيفي للقائم بالفحص (Inspector ID)',
                      hint: 'مثال: 56980',
                      icon: Icons.badge_rounded,
                      isNumeric: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _supervisorNameController,
                      label: 'اسم المشرف المعتمد (Supervisor Name)',
                      hint: 'اسم مهندس الصيانة المشرف',
                      icon: Icons.manage_accounts_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Electronic Declaration Checkbox
          InkWell(
            onTap: () {
              setState(() {
                _hasSignature = !_hasSignature;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasSignature
                    ? const Color(0xFF0F766E).withValues(alpha: isDark ? 0.2 : 0.08)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasSignature
                      ? const Color(0xFF0F766E)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  width: _hasSignature ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _hasSignature,
                    activeColor: const Color(0xFF0F766E),
                    onChanged: (val) {
                      setState(() {
                        _hasSignature = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إقرار صحة الفحص الميداني',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'أقر وأتعهد بأن كافة الفحوصات والقراءات الموضحة في النموذج تمت ميدانياً بدقة وفق معايير شركة نقل الكهرباء (National Grid SA).',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
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
}
