import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/substation_model.dart';

class _InspectionRowDef {
  final String title;
  final String subtitle;
  final String key;

  const _InspectionRowDef({
    required this.title,
    required this.subtitle,
    required this.key,
  });
}

class PdfGeneratorService {
  /// Converts internal digital form values according to the official rules:
  /// - Option 1: Empty -> "" (Strictly enforces completion before moving to next device)
  /// - Option 2: N/A -> "N/A"
  /// - Option 3: Normal / Healthy -> "OK"
  /// - Option 4: Warning / Minor issue -> "Not OK"
  /// - Option 5: Defect / Urgent -> "Need fixed"
  /// - Numbers -> Exact numeric value
  static String formatFieldValue(dynamic val) {
    if (val == null) return '';
    final String s = val.toString().trim();
    if (s.isEmpty) return '';
    if (s.toUpperCase() == 'N/A') return 'N/A';

    // Pure numbers (e.g. 12, 12450, 45, 55, 52)
    final isNumeric = RegExp(r'^-?[0-9]+(\.[0-9]+)?$').hasMatch(s);
    if (isNumeric) {
      return s;
    }

    final lower = s.toLowerCase();
    if (lower == 'ok' || lower == 'normal' || lower == 'good') return 'OK';
    if (lower == 'not ok' || lower == 'warning') return 'Not OK';
    if (lower == 'need fixed' || lower == 'fault' || lower == 'defect') return 'Need fixed';

    // ==========================================
    // OPTION 5: URGENT DEFECT / REPAIR -> "Need fixed"
    // ==========================================
    if (s.contains('تسريب نشط') ||
        s.contains('إصلاح عاجل') ||
        s.contains('مشبع بالكامل') ||
        s.contains('استبدال عاجل') ||
        s.contains('منخفض') ||
        s.contains('عطل في') ||
        s.contains('غير محكمة') ||
        s.contains('لا تعمل') ||
        s.contains('انفصال') ||
        s.contains('ارتخاء') ||
        (s.contains('شروخ') && !s.contains('خالية')) ||
        s.contains('يستدعي الاستبدال') ||
        s.contains('Defective') ||
        s.contains('Fault') ||
        s.contains('Damaged')) {
      return 'Need fixed';
    }

    // ==========================================
    // OPTION 4: MINOR ISSUE / WARNING -> "Not OK"
    // ==========================================
    if (s.contains('ترشيح طفيف') ||
        s.contains('تغير لون خفيف') ||
        s.contains('متابعة بالدورية') ||
        s.contains('وردي') ||
        s.contains('مرتفع') ||
        s.contains('اهتزاز أو ضجيج') ||
        s.contains('تبديل حشوة') ||
        s.contains('السخان عاطل') ||
        (s.contains('إنذار') && !s.contains('لا توجد')) ||
        s.contains('صدأ سطحي') ||
        s.contains('تراكم أتربة') ||
        s.contains('Unsealed') ||
        s.contains('Alarm') ||
        s.contains('Corroded')) {
      return 'Not OK';
    }

    // ==========================================
    // OPTION 3: SOUND / NORMAL / HEALTHY -> "OK"
    // ==========================================
    if (s.contains('سليم') ||
        s.contains('لا يوجد تسريب') ||
        s.contains('أزرق') ||
        s.contains('طبيعي') ||
        (s.contains('محكمة') && !s.contains('غير')) ||
        s.contains('تعمل بكفاءة') ||
        s.contains('تعمل') ||
        s.contains('جيد') ||
        s.contains('نظيف') ||
        s.contains('متصل') ||
        s.contains('التأريض محكم') ||
        s.contains('خالية من الشروخ') ||
        s.contains('لا توجد إنذارات') ||
        s.contains('Normal') ||
        s.contains('Good') ||
        s.contains('Blue') ||
        s.contains('Sealed') ||
        s.contains('Operational') ||
        s.contains('Clean') ||
        s.contains('Connected')) {
      return 'OK';
    }

    return s;
  }

  /// Generates the Official National Grid SA "GRID MAINTENANCE" Detailed Inspection PDF
  /// 100% English Language representation matching the official template design and layouts.
  static Future<Uint8List> generateInspectionPdf({
    required SubstationModel substation,
    required String workOrder,
    required String inspectionDate,
    required List<Map<String, dynamic>> powerTransformersData,
    required List<Map<String, dynamic>> auxTransformersData,
    required bool hasSpareTransformer,
    required List<Map<String, String>> spareTransformersData,
    required String inspectorName,
    String inspectorId = '',
    required String supervisorName,
    String supervisorId = '',
    required String technicalNotes,
    required String referenceNumber,
  }) async {
    final pdf = pw.Document(
      title: 'TP-GM-1400-002-002 Equipment Inspection Form',
      author: 'National Grid SA',
      creator: 'National Grid Maintenance Automation System',
    );

    // Reliable English typography
    final pw.Font fontRegular = pw.Font.helvetica();
    final pw.Font fontBold = pw.Font.helveticaBold();

    // Load authentic National Grid SA logo image from assets
    pw.ImageProvider? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/national_grid_logo.jpg');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final file = File('assets/images/national_grid_logo.jpg');
        if (file.existsSync()) {
          logoImage = pw.MemoryImage(file.readAsBytesSync());
        }
      } catch (_) {}
    }

    // Power transformers count (template has exactly 6 columns)
    const int powerColumnsCount = 6;
    final List<Map<String, dynamic>> powerList = List.generate(powerColumnsCount, (i) {
      if (i < powerTransformersData.length) {
        return powerTransformersData[i];
      }
      return <String, dynamic>{'txName': ''};
    });

    // Aux transformers count (template has exactly 4 columns)
    const int auxColumnsCount = 4;
    final List<Map<String, dynamic>> auxList = List.generate(auxColumnsCount, (i) {
      if (i < auxTransformersData.length) {
        return auxTransformersData[i];
      }
      return <String, dynamic>{'txName': ''};
    });

    // 16 Inspection items matching the exact official English template text
    const List<_InspectionRowDef> rowsDef = [
      _InspectionRowDef(
        title: 'Oil Leakage, Check level and leakage',
        subtitle: '',
        key: 'oilLeakage',
      ),
      _InspectionRowDef(
        title: 'Silica gel Color main Tank, Check color',
        subtitle: '',
        key: 'silicaGelMainTank',
      ),
      _InspectionRowDef(
        title: 'Silica gel Color Tap Changer, Check color',
        subtitle: '',
        key: 'silicaGelTapChanger',
      ),
      _InspectionRowDef(
        title: 'Oil Level Gauge Main Tank Conservator',
        subtitle: 'Check level and leakage',
        key: 'oilLevelMainConservator',
      ),
      _InspectionRowDef(
        title: 'Oil Level Gauge Tap Changer, Check level and leakage',
        subtitle: '',
        key: 'oilLevelTapChanger',
      ),
      _InspectionRowDef(
        title: 'Tap Position, Record Tap Position.',
        subtitle: '',
        key: 'tapPosition',
      ),
      _InspectionRowDef(
        title: 'Tap Changer Counter Reading, Record reading.',
        subtitle: '',
        key: 'tapCounter',
      ),
      _InspectionRowDef(
        title: 'Oil Temperature, Record reading.',
        subtitle: '',
        key: 'oilTemp',
      ),
      _InspectionRowDef(
        title: 'HV Winding Temperature, Record reading.',
        subtitle: '',
        key: 'hvWindingTemp',
      ),
      _InspectionRowDef(
        title: 'LV Winding Temperature, Record reading.',
        subtitle: '',
        key: 'lvWindingTemp',
      ),
      _InspectionRowDef(
        title: 'Cooling Fans & Pump Operation',
        subtitle: 'Manually run and return to auto; report abnormal noise',
        key: 'coolingFansPump',
      ),
      _InspectionRowDef(
        title: 'Control Cabinet Properly Sealed',
        subtitle: 'Check that they are properly sealed.',
        key: 'controlCabinetSealed',
      ),
      _InspectionRowDef(
        title: 'Heater Operation in Control Cabinet',
        subtitle: 'Check operation of lights and heaters.',
        key: 'heaterOperation',
      ),
      _InspectionRowDef(
        title: 'On Line DGA Monitor, Check operation',
        subtitle: '',
        key: 'dgaMonitor',
      ),
      _InspectionRowDef(
        title: 'General condition',
        subtitle: 'Check Grounding Securely Connected\nReport corrosion and painting if required',
        key: 'generalCondition',
      ),
      _InspectionRowDef(
        title: 'Bushings',
        subtitle: 'Check condition for drips and cracks, dust contamination.\nCheck oil level and leakage',
        key: 'bushings',
      ),
    ];

    const double totalTableWidth = 792.0;
    const double itemWidth = 220.0;
    const double powerWidth = 55.0; // 6 * 55 = 330.0
    const double auxWidth = 60.5; // 4 * 60.5 = 242.0
    const double rightHeaderWidth = 572.0; // 330.0 + 242.0

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Spacer(),

              // ==========================================
              // TOP FORM IDENTIFIER CODE
              // ==========================================
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'TP-GM-1400-002-002 Equipment Inspection Form',
                  style: pw.TextStyle(fontSize: 8, font: fontRegular),
                ),
              ),

              pw.SizedBox(height: 2),

              // ==========================================
              // TOP HEADER METADATA BAR (Substation, Work Order, Date)
              // ==========================================
              _buildTopMetadataBar(
                totalWidth: totalTableWidth,
                substation: substation,
                workOrder: workOrder,
                inspectionDate: inspectionDate,
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),

              pw.SizedBox(height: 3),

              // ==========================================
              // TOP MAIN HEADER (Logo Image + GRID MAINTENANCE + Column Headers)
              // ==========================================
              _buildTopHeaderSection(
                logoImage: logoImage,
                itemWidth: itemWidth,
                rightHeaderWidth: rightHeaderWidth,
                powerWidth: powerWidth,
                auxWidth: auxWidth,
                powerList: powerList,
                auxList: auxList,
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),

              // ==========================================
              // 16 INSPECTION ROWS TABLE
              // ==========================================
              _buildInspectionRowsTable(
                rowsDef: rowsDef,
                itemWidth: itemWidth,
                powerWidth: powerWidth,
                auxWidth: auxWidth,
                powerList: powerList,
                auxList: auxList,
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),

              pw.SizedBox(height: 4),

              // ==========================================
              // FOR SPARE TRANSFORMERS TABLE
              // ==========================================
              _buildSpareSection(
                itemWidth: itemWidth,
                totalWidth: totalTableWidth,
                hasSpareTransformer: hasSpareTransformer,
                spareTransformersData: spareTransformersData,
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),

              pw.SizedBox(height: 4),

              // ==========================================
              // BOTTOM SPLIT SECTION (Left: Notes | Right: Approvals & IDs)
              // ==========================================
              _buildBottomNotesAndApprovalsSection(
                totalWidth: totalTableWidth,
                notes: technicalNotes,
                inspectorName: inspectorName,
                inspectorId: inspectorId,
                supervisorName: supervisorName,
                supervisorId: supervisorId,
                referenceNumber: referenceNumber,
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),

              pw.Spacer(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Top Metadata Bar: Substation, Work Order, Date (100% English)
  static pw.Widget _buildTopMetadataBar({
    required double totalWidth,
    required SubstationModel substation,
    required String workOrder,
    required String inspectionDate,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Container(
      width: totalWidth,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.0),
        color: const PdfColor.fromInt(0xFFF1F5F9),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Substation
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(text: 'Substation: ', style: pw.TextStyle(fontSize: 8.5, font: fontBold)),
                pw.TextSpan(
                  text: '${substation.name} (${substation.region})',
                  style: pw.TextStyle(fontSize: 8.5, font: fontRegular),
                ),
              ],
            ),
          ),

          // Work Order
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(text: 'Work Order: ', style: pw.TextStyle(fontSize: 8.5, font: fontBold)),
                pw.TextSpan(
                  text: workOrder.isNotEmpty ? workOrder : 'N/A',
                  style: pw.TextStyle(fontSize: 8.5, font: fontRegular),
                ),
              ],
            ),
          ),

          // Date
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(text: 'Date: ', style: pw.TextStyle(fontSize: 8.5, font: fontBold)),
                pw.TextSpan(
                  text: inspectionDate,
                  style: pw.TextStyle(fontSize: 8.5, font: fontRegular),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Top Main Header Section: Exact Match with Template & Official Image Logo
  static pw.Widget _buildTopHeaderSection({
    required pw.ImageProvider? logoImage,
    required double itemWidth,
    required double rightHeaderWidth,
    required double powerWidth,
    required double auxWidth,
    required List<Map<String, dynamic>> powerList,
    required List<Map<String, dynamic>> auxList,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // LEFT BOX: LOGO IMAGE (TOP) + "Item" (BOTTOM)
        pw.Container(
          width: itemWidth,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.black, width: 1.2),
              top: pw.BorderSide(color: PdfColors.black, width: 1.2),
              right: pw.BorderSide(color: PdfColors.black, width: 1.2),
              bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
            ),
          ),
          child: pw.Column(
            children: [
              // Logo Area - Embed official image
              pw.Container(
                height: 52,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                alignment: pw.Alignment.center,
                child: logoImage != null
                    ? pw.Image(
                        logoImage,
                        fit: pw.BoxFit.contain,
                      )
                    : pw.Text(
                        'National Grid SA',
                        style: pw.TextStyle(fontSize: 9.5, font: fontBold, color: const PdfColor.fromInt(0xFFD97706)),
                      ),
              ),

              // Item Column Header
              pw.Container(
                height: 18,
                width: double.infinity,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1.0)),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Item',
                  style: pw.TextStyle(fontSize: 8.5, font: fontBold),
                ),
              ),
            ],
          ),
        ),

        // RIGHT BOX: GRID MAINTENANCE + SUB-HEADERS + T___ COLUMNS
        pw.Container(
          width: rightHeaderWidth,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.black, width: 1.2),
              right: pw.BorderSide(color: PdfColors.black, width: 1.2),
              bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
            ),
          ),
          child: pw.Column(
            children: [
              // Row 1: "GRID MAINTENANCE"
              pw.Container(
                height: 25,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'GRID MAINTENANCE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    font: fontBold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              // Row 2: "Power Transformer" (330pt) | "Auxiliary Transformers" (242pt)
              pw.Container(
                height: 27,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 1.0),
                    bottom: pw.BorderSide(color: PdfColors.black, width: 1.0),
                  ),
                ),
                child: pw.Row(
                  children: [
                    // Power Transformer Sub-Header
                    pw.Container(
                      width: 6 * powerWidth,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1.0)),
                      ),
                      child: pw.Text(
                        'Power Transformer\nDetailed Monthly Inspection',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                      ),
                    ),

                    // Aux Transformer Sub-Header
                    pw.Container(
                      width: 4 * auxWidth,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Auxiliary Transformers / Shunt Reactor\nDetailed Monthly Inspection',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                      ),
                    ),
                  ],
                ),
              ),

              // Row 3: 10 T___ Column Headers
              pw.Container(
                height: 18,
                child: pw.Row(
                  children: [
                    // 6 Power Columns
                    ...powerList.map((tx) {
                      final name = tx['txName']?.toString() ?? '';
                      return pw.Container(
                        width: powerWidth,
                        alignment: pw.Alignment.center,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                        ),
                        child: pw.Text(
                          name.isNotEmpty ? name : 'T___',
                          style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                        ),
                      );
                    }),

                    // 4 Aux Columns
                    ...auxList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final tx = entry.value;
                      final name = tx['txName']?.toString() ?? '';
                      final isLast = idx == auxList.length - 1;
                      return pw.Container(
                        width: auxWidth,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            right: isLast ? pw.BorderSide.none : const pw.BorderSide(color: PdfColors.black, width: 0.8),
                          ),
                        ),
                        child: pw.Text(
                          name.isNotEmpty ? name : 'T___',
                          style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 16 Inspection Rows Table: Exact Match with Template
  static pw.Widget _buildInspectionRowsTable({
    required List<_InspectionRowDef> rowsDef,
    required double itemWidth,
    required double powerWidth,
    required double auxWidth,
    required List<Map<String, dynamic>> powerList,
    required List<Map<String, dynamic>> auxList,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Table(
      border: const pw.TableBorder(
        left: pw.BorderSide(color: PdfColors.black, width: 1.2),
        right: pw.BorderSide(color: PdfColors.black, width: 1.2),
        bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
        top: pw.BorderSide(color: PdfColors.black, width: 1.0),
        horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
        verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
      ),
      columnWidths: {
        0: pw.FixedColumnWidth(itemWidth),
        1: pw.FixedColumnWidth(powerWidth),
        2: pw.FixedColumnWidth(powerWidth),
        3: pw.FixedColumnWidth(powerWidth),
        4: pw.FixedColumnWidth(powerWidth),
        5: pw.FixedColumnWidth(powerWidth),
        6: pw.FixedColumnWidth(powerWidth),
        7: pw.FixedColumnWidth(auxWidth),
        8: pw.FixedColumnWidth(auxWidth),
        9: pw.FixedColumnWidth(auxWidth),
        10: pw.FixedColumnWidth(auxWidth),
      },
      children: rowsDef.map((rowDef) {
        return pw.TableRow(
          children: [
            // Item Title & Subtitle (Leftmost Column)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    rowDef.title,
                    style: pw.TextStyle(fontSize: 6.8, font: fontBold),
                  ),
                  if (rowDef.subtitle.isNotEmpty)
                    pw.Text(
                      rowDef.subtitle,
                      style: pw.TextStyle(fontSize: 5.5, font: fontRegular, color: const PdfColor.fromInt(0xFF1E293B)),
                    ),
                ],
              ),
            ),

            // 6 Power Transformer Value Cells
            ...powerList.map((tx) {
              final raw = tx[rowDef.key];
              final text = formatFieldValue(raw);
              final isNA = text == 'N/A';
              final isOK = text == 'OK';
              final isWarningOrDefect = text == 'Not OK' || text == 'Need fixed';
              return pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.8),
                child: pw.Text(
                  text,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 7.2,
                    font: isNA || isOK || isWarningOrDefect ? fontBold : fontRegular,
                    color: isNA ? const PdfColor.fromInt(0xFFD97706) : PdfColors.black,
                  ),
                ),
              );
            }),

            // 4 Auxiliary Transformer Value Cells
            ...auxList.map((tx) {
              final raw = tx[rowDef.key];
              final text = formatFieldValue(raw);
              final isNA = text == 'N/A';
              final isOK = text == 'OK';
              final isWarningOrDefect = text == 'Not OK' || text == 'Need fixed';
              return pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.8),
                child: pw.Text(
                  text,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 7.2,
                    font: isNA || isOK || isWarningOrDefect ? fontBold : fontRegular,
                    color: isNA ? const PdfColor.fromInt(0xFFD97706) : PdfColors.black,
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  // Section: For Spare Transformers (Exact Match with Template)
  static pw.Widget _buildSpareSection({
    required double itemWidth,
    required double totalWidth,
    required bool hasSpareTransformer,
    required List<Map<String, String>> spareTransformersData,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    final double colWidth = (totalWidth - itemWidth) / 3;

    final List<Map<String, String>> spares = hasSpareTransformer && spareTransformersData.isNotEmpty
        ? spareTransformersData
        : [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'For Spare Transformers',
          style: pw.TextStyle(
            fontSize: 8,
            font: fontBold,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
          columnWidths: {
            0: pw.FixedColumnWidth(itemWidth),
            1: pw.FixedColumnWidth(colWidth),
            2: pw.FixedColumnWidth(colWidth),
            3: pw.FixedColumnWidth(colWidth),
          },
          children: [
            // Row 1: Transformer Number
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text('Transformer Number', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text(
                    spares.isNotEmpty ? (spares[0]['number'] ?? 'T .........') : 'T .........',
                    style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text(
                    spares.length > 1 ? (spares[1]['number'] ?? 'T .........') : 'T .........',
                    style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text(
                    spares.length > 2 ? (spares[2]['number'] ?? 'T .........') : 'T .........',
                    style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                  ),
                ),
              ],
            ),

            // Row 2: General Condition
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text('General Condition', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text(
                    spares.isNotEmpty
                        ? (formatFieldValue(spares[0]['condition']).isNotEmpty
                            ? formatFieldValue(spares[0]['condition'])
                            : (hasSpareTransformer ? 'OK' : 'N/A'))
                        : (hasSpareTransformer ? '' : 'N/A'),
                    style: pw.TextStyle(fontSize: 7.2, font: fontRegular),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text(
                    spares.length > 1
                        ? (formatFieldValue(spares[1]['condition']).isNotEmpty
                            ? formatFieldValue(spares[1]['condition'])
                            : 'OK')
                        : '',
                    style: pw.TextStyle(fontSize: 7.2, font: fontRegular),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  child: pw.Text(
                    spares.length > 2
                        ? (formatFieldValue(spares[2]['condition']).isNotEmpty
                            ? formatFieldValue(spares[2]['condition'])
                            : 'OK')
                        : '',
                    style: pw.TextStyle(fontSize: 7.2, font: fontRegular),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Bottom Split Section: Left Side (Technical Notes) & Right Side (Approvals & IDs)
  static pw.Widget _buildBottomNotesAndApprovalsSection({
    required double totalWidth,
    required String notes,
    required String inspectorName,
    required String inspectorId,
    required String supervisorName,
    required String supervisorId,
    required String referenceNumber,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    const double gap = 4.0;
    final double colWidth = (totalWidth - gap) / 2;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ==========================================
        // LEFT SIDE: TECHNICAL NOTES (جهة اليسار)
        // ==========================================
        pw.Container(
          width: colWidth,
          height: 60,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.0),
            color: const PdfColor.fromInt(0xFFFAFAFA),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Technical Notes & Recommendations:',
                style: pw.TextStyle(fontSize: 7.5, font: fontBold, color: const PdfColor.fromInt(0xFF0F172A)),
              ),
              pw.SizedBox(height: 3),
              pw.Expanded(
                child: pw.Text(
                  notes.trim().isNotEmpty ? notes.trim() : 'None',
                  style: pw.TextStyle(fontSize: 7.0, font: fontRegular, color: const PdfColor.fromInt(0xFF334155)),
                  maxLines: 4,
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: gap),

        // ==========================================
        // RIGHT SIDE: APPROVALS & EMPLOYEE IDS (جهة اليمين)
        // ==========================================
        pw.Container(
          width: colWidth,
          height: 60,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.0),
            color: const PdfColor.fromInt(0xFFF8FAFC),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              // Inspector
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Engineer / Technician: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                        pw.TextSpan(
                          text: inspectorName.isNotEmpty ? inspectorName : 'Certified Technician',
                          style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                        ),
                      ],
                    ),
                  ),
                  if (inspectorId.isNotEmpty)
                    pw.Text(
                      'Emp ID: $inspectorId',
                      style: pw.TextStyle(fontSize: 7.5, font: fontBold, color: const PdfColor.fromInt(0xFF0284C7)),
                    ),
                ],
              ),

              // Supervisor
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Engineer / Supervisor: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                        pw.TextSpan(
                          text: supervisorName.isNotEmpty ? supervisorName : 'Section Head',
                          style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                        ),
                      ],
                    ),
                  ),
                  if (supervisorId.isNotEmpty)
                    pw.Text(
                      'Emp ID: $supervisorId',
                      style: pw.TextStyle(fontSize: 7.5, font: fontBold, color: const PdfColor.fromInt(0xFF0284C7)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Generates the Official "Checklist for Substation Power Transformer" (CL-GM-1400-002-002)
  /// Exactly matching the official 1-page National Grid SA template provided in the PDF.
  static Future<Uint8List> generateTransformerChecklistPdf({
    required String division,
    required String contactPerson,
    required String department,
    required String workOrder,
    required String substationName,
    required String inspectionDate,
    String equipmentNo = '',
    String equipmentVoltage = '',
    String equipmentMva = '',
    String equipmentSerial = '',
    String equipmentManufacturer = '',
    required List<Map<String, dynamic>> itemsData,
  }) async {
    final pdf = pw.Document(
      title: 'CL-GM-1400-002-002 Checklist for Substation Power Transformer',
      author: 'National Grid SA',
      creator: 'National Grid Maintenance System',
    );

    final pw.Font fontRegular = pw.Font.helvetica();
    final pw.Font fontBold = pw.Font.helveticaBold();

    pw.ImageProvider? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/national_grid_logo.jpg');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final file = File('assets/images/national_grid_logo.jpg');
        if (file.existsSync()) {
          logoImage = pw.MemoryImage(file.readAsBytesSync());
        }
      } catch (_) {}
    }

    const double tableBorderWidth = 1.0;
    final tableBorderColor = PdfColors.black;

    pw.Widget buildCheckbox(bool checked) {
      return pw.Container(
        width: 7.5,
        height: 7.5,
        margin: const pw.EdgeInsets.only(top: 1, right: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.8),
        ),
        child: checked
            ? pw.Center(
                child: pw.Text(
                  'v',
                  style: pw.TextStyle(fontSize: 6, font: fontBold),
                ),
              )
            : null,
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Spacer(),

              // ==========================================
              // 1. TOP HEADER: LOGO & "GRID MAINTENANCE"
              // ==========================================
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: tableBorderColor, width: tableBorderWidth),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // National Grid SA Logo
                    if (logoImage != null)
                      pw.Container(
                        height: 28,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 14,
                            height: 14,
                            color: const PdfColor.fromInt(0xFF0284C7),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text(
                            'National Grid SA',
                            style: pw.TextStyle(fontSize: 10, font: fontBold),
                          ),
                        ],
                      ),

                    // GRID MAINTENANCE Title
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Text(
                          'GRID MAINTENANCE',
                          style: pw.TextStyle(
                            fontSize: 14,
                            font: fontBold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 2. DOCUMENT TITLE & INDEX NUMBER BLOCK
              // ==========================================
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                    right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                    bottom: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                  ),
                ),
                child: pw.Row(
                  children: [
                    // Title Area (Left ~ 68%)
                    pw.Expanded(
                      flex: 68,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('Title:', style: pw.TextStyle(fontSize: 7.5, font: fontRegular)),
                            pw.SizedBox(height: 2),
                            pw.Center(
                              child: pw.Text(
                                'Checklist for Substation Power\nTransformer',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(fontSize: 11, font: fontBold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Index, Revision, Page Info (Right ~ 32%)
                    pw.Container(
                      width: 170,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          // Index Number
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text('Index Number:', style: pw.TextStyle(fontSize: 7, font: fontRegular)),
                                pw.Text('CL-GM-1400-002-002', style: pw.TextStyle(fontSize: 8.5, font: fontBold)),
                              ],
                            ),
                          ),
                          // Revision & Page Number Row
                          pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border(
                                      right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                                    ),
                                  ),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      pw.Text('Revision Number:', style: pw.TextStyle(fontSize: 6.5, font: fontRegular)),
                                      pw.Text('00', style: pw.TextStyle(fontSize: 8, font: fontBold)),
                                    ],
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      pw.Text('Page Number:', style: pw.TextStyle(fontSize: 6.5, font: fontRegular)),
                                      pw.Text('1 of 1', style: pw.TextStyle(fontSize: 8, font: fontBold)),
                                    ],
                                  ),
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

              // ==========================================
              // 3. METADATA HEADER FIELDS (Division, WO, Substation, etc.)
              // ==========================================
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                    right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                    bottom: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                  ),
                ),
                child: pw.Column(
                  children: [
                    // Row 1: Division & Contact Person
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 55,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                              ),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Text('Division: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                                pw.Expanded(
                                  child: pw.Text(
                                    division.isNotEmpty ? division : 'EOD / Eastern Operating Division',
                                    style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 45,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            child: pw.Row(
                              children: [
                                pw.Text('Contact Person: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                                pw.Expanded(
                                  child: pw.Text(
                                    contactPerson.isNotEmpty ? contactPerson : '',
                                    style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Row 2: Department & Work Order No.
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 55,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                  right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                                ),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Text('Department: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                                  pw.Expanded(
                                    child: pw.Text(
                                      department.isNotEmpty ? department : 'Substation Maintenance Dept',
                                      style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.Expanded(
                            flex: 45,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              child: pw.Row(
                                children: [
                                  pw.Text('Work Order No.: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                                  pw.Expanded(
                                    child: pw.Text(
                                      workOrder.isNotEmpty ? workOrder : '',
                                      style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Row 3: Substation Name/No & Date
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 55,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                  right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                                ),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Text('Substation Name/No: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                                  pw.Expanded(
                                    child: pw.Text(
                                      substationName.isNotEmpty ? substationName : '',
                                      style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.Expanded(
                            flex: 45,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              child: pw.Row(
                                children: [
                                  pw.Text('Date: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                                  pw.Expanded(
                                    child: pw.Text(
                                      inspectionDate.isNotEmpty ? inspectionDate : '',
                                      style: pw.TextStyle(fontSize: 7.5, font: fontRegular),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Row 4: Equipment / Transformer No. (رقم المعدة)
                    if (equipmentNo.isNotEmpty)
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                          ),
                        ),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        child: pw.Row(
                          children: [
                            pw.Text('Equipment / Transformer: ', style: pw.TextStyle(fontSize: 7.5, font: fontBold)),
                            pw.Expanded(
                              child: pw.Text(
                                '$equipmentNo ${equipmentVoltage.isNotEmpty ? "($equipmentVoltage)" : ""}',
                                style: pw.TextStyle(fontSize: 7.5, font: fontBold),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ==========================================
              // 4. CHECKLIST TABLE HEADER ("Proper Template" & "Comments:")
              // ==========================================
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                    right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                    bottom: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 62,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                          ),
                        ),
                        child: pw.Text(
                          'Proper Template',
                          style: pw.TextStyle(fontSize: 8, font: fontBold),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 38,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: pw.Text(
                          'Comments:',
                          style: pw.TextStyle(fontSize: 8, font: fontBold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 5. THE 20 CHECKLIST ITEMS
              // ==========================================
              ...itemsData.map((item) {
                final bool isChecked = item['checked'] == true;
                final String title = item['title']?.toString() ?? '';
                final List<dynamic> subTasks = item['subTasks'] as List<dynamic>? ?? [];
                final String comments = item['comments']?.toString() ?? '';

                return pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                      right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                      bottom: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Left Column: Checkbox + Title + Sub-tasks
                      pw.Expanded(
                        flex: 62,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.2),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              right: pw.BorderSide(color: tableBorderColor, width: tableBorderWidth),
                            ),
                          ),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              buildCheckbox(isChecked),
                              pw.SizedBox(width: 3),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      title,
                                      style: pw.TextStyle(
                                        fontSize: 7.2,
                                        font: fontBold,
                                      ),
                                    ),
                                    ...subTasks.map((st) {
                                      return pw.Padding(
                                        padding: const pw.EdgeInsets.only(left: 4, top: 0.5),
                                        child: pw.Row(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            buildCheckbox(isChecked),
                                            pw.SizedBox(width: 2),
                                            pw.Expanded(
                                              child: pw.Text(
                                                st.toString(),
                                                style: pw.TextStyle(
                                                  fontSize: 6.8,
                                                  font: fontRegular,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right Column: Comments
                      pw.Expanded(
                        flex: 38,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.2),
                          child: pw.Text(
                            (comments.isNotEmpty &&
                                    RegExp(r'^\d+(\.\d+)?$').hasMatch(comments) &&
                                    title.toLowerCase().contains('temp'))
                                ? '$comments°C'
                                : comments,
                            style: pw.TextStyle(
                              fontSize: 7.2,
                              font: fontRegular,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Spacer(),

              // ==========================================
              // 6. FOOTER URL
              // ==========================================
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  'Policies and Procedures Management System Website: http://ngridsa-apps/amas/',
                  style: pw.TextStyle(
                    fontSize: 7,
                    font: fontRegular,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates the Official "INSULATING OIL SAMPLE" & "EQUIPMENT DATA" Form (Central Labs - Dammam)
  /// Exactly matching the official 2-cards-per-page National Grid SA template provided in the PDF.
  static Future<Uint8List> generateOilSamplingPdf({
    required SubstationModel substation,
    required List<TransformerInfo> selectedTransformers,
    String workOrder = '',
    String sampleTemp = '',
    String resultsSendToName = '',
    String resultsSendToEmail = '',
    String resultsSendToPhone = '',
    String samplerId = '',
    String samplerPhone = '',
    required String inspectionDate,
    required String samplerName,
    required String division,
    required String department,
    required Set<String> equipmentTypes,
    required Set<String> samplingPoints,
    required Set<String> otherSamplingPoints,
    required Set<String> testsRequired,
    required Set<String> reasonsForTest,
  }) async {
    final pdf = pw.Document(
      title: 'INSULATING OIL SAMPLE - Central Labs Dammam',
      author: 'National Grid SA',
      creator: 'National Grid Maintenance Automation System',
    );

    final pw.Font fontRegular = pw.Font.helvetica();
    final pw.Font fontBold = pw.Font.helveticaBold();
    pw.Font? fontArabic;
    try {
      fontArabic = await PdfGoogleFonts.cairoBold();
    } catch (_) {}

    // Checkbox builder helper with crisp vector checkmark inside
    pw.Widget buildBox(bool checked, {double size = 8.5}) {
      return pw.Container(
        width: size,
        height: size,
        margin: const pw.EdgeInsets.only(right: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.8),
        ),
        child: checked
            ? pw.CustomPaint(
                size: PdfPoint(size, size),
                painter: (PdfGraphics canvas, PdfPoint pSize) {
                  canvas
                    ..setColor(PdfColors.black)
                    ..setLineWidth(1.1)
                    ..moveTo(pSize.x * 0.18, pSize.y * 0.48)
                    ..lineTo(pSize.x * 0.42, pSize.y * 0.18)
                    ..lineTo(pSize.x * 0.85, pSize.y * 0.82)
                    ..strokePath();
                },
              )
            : null,
      );
    }

    // Underline text field line
    pw.Widget buildUnderlineField({
      required String label,
      required String value,
      double labelWidth = 0,
      double fontSize = 8.0,
      bool isExpanded = true,
    }) {
      final labelWidget = pw.Text(
        label,
        style: pw.TextStyle(fontSize: fontSize, font: fontBold),
      );

      final valWidget = pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
          ),
        ),
        padding: const pw.EdgeInsets.only(bottom: 0.5, left: 2, right: 2),
        child: pw.Text(
          value,
          style: pw.TextStyle(fontSize: fontSize, font: fontBold),
          maxLines: 1,
        ),
      );

      if (!isExpanded) {
        return pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [labelWidget, valWidget],
        );
      }

      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          labelWidget,
          pw.Expanded(child: valWidget),
        ],
      );
    }

    // Helper to build a single oil sample card (half page)
    pw.Widget buildOilSampleCard({
      required TransformerInfo tx,
      required String locationType,
      required String? otherSubLocation,
      required String testName,
    }) {
      final isTransformer = equipmentTypes.contains('Transformer') || equipmentTypes.isEmpty;
      final isShunt = equipmentTypes.contains('Shunt Reactor');
      final isNewOil = equipmentTypes.contains('New Oil');
      final isLoadTap = equipmentTypes.contains('Load Tapchanger');
      final isBreaker = equipmentTypes.contains('Circuit Breaker');
      final isOthersEq = equipmentTypes.contains('Others');

      final isBottom = locationType == 'Main Tank Bottom';
      final isTop = locationType == 'Main Tank Top';
      final isOtherPt = locationType == 'Other';

      final isOQ = testName == 'Oil Quality Test (OQ)';
      final isDGA = testName == 'Dissolved Gas-in-Oil Analysis (DGA)';
      final isFurans = testName == 'Furanic Compounds';
      final isSulfur = testName == 'Corrosive Sulfur';
      final isPassivators = testName == 'Passivators';

      final isCblR = otherSubLocation == 'CBL R';
      final isCblY = otherSubLocation == 'CBL Y';
      final isCblB = otherSubLocation == 'CBL B';
      final isCblN = otherSubLocation == 'CBL N';
      final isOneCbl = otherSubLocation == 'ONE CBL (R-Y-B)';
      final isOltc1 = otherSubLocation == 'OLTC 1';
      final isOltc2 = otherSubLocation == 'OLTC 2';
      final isOltc3 = otherSubLocation == 'OLTC 3';

      final isCommissioning = reasonsForTest.contains('Commissioning');
      final isInvestigate = reasonsForTest.contains('Investigate');
      final isWarranty = reasonsForTest.contains('Warranty');
      final isFailure = reasonsForTest.contains('Failure');
      final isAnnual = reasonsForTest.contains('Annual');
      final isProcessing = reasonsForTest.contains('# Processing Sample');

                      final cleanMva = (tx.mva ?? '')
                          .replaceAll(RegExp(r'\s*mva\s*', caseSensitive: false), '')
                          .trim();
                      String cleanVoltage = tx.voltage
                          .replaceAll(RegExp(r'\s*kv\s*', caseSensitive: false), '')
                          .trim();
                      if (cleanVoltage.isEmpty) cleanVoltage = tx.voltage.trim();

                      return pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 1.0),
                        ),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            // Top Header: Central Labs - Dammam | National Grid sa / نقل الكهرباء
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 2),
                                  child: pw.Text(
                                    'Central Labs - Dammam',
                                    style: pw.TextStyle(
                                      fontSize: 10.5,
                                      font: fontBold,
                                    ),
                                  ),
                                ),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: [
                                    pw.Text(
                                      'National Grid sa',
                                      style: pw.TextStyle(
                                        fontSize: 12.5,
                                        font: fontBold,
                                      ),
                                    ),
                                    if (fontArabic != null)
                                      pw.Text(
                                        'نقل الكهرباء',
                                        style: pw.TextStyle(
                                          fontSize: 10.5,
                                          font: fontArabic,
                                        ),
                                        textDirection: pw.TextDirection.rtl,
                                      )
                                    else
                                      pw.Text(
                                        'National Grid SA',
                                        style: pw.TextStyle(
                                          fontSize: 9.5,
                                          font: fontBold,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Divider(height: 1, thickness: 0.8, color: PdfColors.black),
                            pw.SizedBox(height: 4),

                            // Two Main Columns: EQUIPMENT DATA | INSULATING OIL SAMPLE
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                // 1. LEFT COLUMN: EQUIPMENT DATA
                                pw.Expanded(
                                  flex: 5,
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                                    children: [
                                      pw.Center(
                                        child: pw.Text(
                                          'EQUIPMENT DATA',
                                          style: pw.TextStyle(
                                            fontSize: 10.5,
                                            font: fontBold,
                                            decoration: pw.TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      pw.SizedBox(height: 5),

                                      buildUnderlineField(
                                        label: 'SUBSTATION NAME : ',
                                        value: substation.name,
                                        fontSize: 7.8,
                                      ),
                                      pw.SizedBox(height: 3),

                                      buildUnderlineField(
                                        label: 'AREA : ',
                                        value: substation.region,
                                        fontSize: 7.8,
                                      ),
                                      pw.SizedBox(height: 4),

                                      pw.Text(
                                        'EQUIPMENT TYPE :',
                                        style: pw.TextStyle(fontSize: 7.8, font: fontBold),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Row(
                                        children: [
                                          pw.Expanded(
                                            child: pw.Row(
                                              children: [
                                                buildBox(isTransformer),
                                                pw.Text('Transformer', style: pw.TextStyle(fontSize: 7.2, font: fontRegular)),
                                              ],
                                            ),
                                          ),
                                          pw.Expanded(
                                            child: pw.Row(
                                              children: [
                                                buildBox(isShunt),
                                                pw.Text('Shunt Reactor', style: pw.TextStyle(fontSize: 7.2, font: fontRegular)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Row(
                                        children: [
                                          pw.Expanded(
                                            child: pw.Row(
                                              children: [
                                                buildBox(isNewOil),
                                                pw.Text('New Oil', style: pw.TextStyle(fontSize: 7.2, font: fontRegular)),
                                              ],
                                            ),
                                          ),
                                          pw.Expanded(
                                            child: pw.Row(
                                              children: [
                                                buildBox(isLoadTap),
                                                pw.Text('Load Tapchanger', style: pw.TextStyle(fontSize: 7.2, font: fontRegular)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Row(
                                        children: [
                                          pw.Expanded(
                                            child: pw.Row(
                                              children: [
                                                buildBox(isBreaker),
                                                pw.Text('Circuit Breaker', style: pw.TextStyle(fontSize: 7.2, font: fontRegular)),
                                              ],
                                            ),
                                          ),
                                          pw.Expanded(
                                            child: pw.Row(
                                              children: [
                                                buildBox(isOthersEq),
                                                pw.Text('Others', style: pw.TextStyle(fontSize: 7.2, font: fontRegular)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      pw.SizedBox(height: 4),

                                      buildUnderlineField(
                                        label: 'Dispatch No: ',
                                        value: tx.number,
                                        fontSize: 7.8,
                                      ),
                                      pw.SizedBox(height: 3),

                                      buildUnderlineField(
                                        label: 'Serial Number ',
                                        value: tx.serial?.isNotEmpty == true ? tx.serial! : '',
                                        fontSize: 7.8,
                                      ),
                                      pw.SizedBox(height: 3),

                                      buildUnderlineField(
                                        label: 'Manufacturer : ',
                                        value: tx.manufacturer?.isNotEmpty == true ? tx.manufacturer! : '',
                                        fontSize: 7.8,
                                      ),
                                      pw.SizedBox(height: 3),

                                      buildUnderlineField(
                                        label: 'Year Manufacture : ',
                                        value: tx.effectiveYearManufacture,
                                        fontSize: 7.8,
                                      ),
                                      pw.SizedBox(height: 3),

                                      buildUnderlineField(
                                        label: 'Sample Temp : ',
                                        value: sampleTemp.trim().isNotEmpty
                                            ? (sampleTemp.trim().endsWith('°C') || sampleTemp.trim().endsWith('C')
                                                ? sampleTemp.trim()
                                                : '${sampleTemp.trim()} °C')
                                            : '',
                                        fontSize: 7.8,
                                      ),
                                      pw.SizedBox(height: 3),

                                      pw.Row(
                                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                                        children: [
                                          pw.Text('Rating : ', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                                          pw.Container(
                                            width: 35,
                                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                                            child: pw.Center(
                                              child: pw.Text(cleanMva, style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                                            ),
                                          ),
                                          pw.Text(' MVA   ', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                                          pw.Expanded(
                                            child: pw.Container(
                                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                                              child: pw.Center(
                                                child: pw.Text(cleanVoltage, style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                                              ),
                                            ),
                                          ),
                                          pw.Text(' KV', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                                        ],
                                      ),
                      pw.SizedBox(height: 3),

                      buildUnderlineField(
                        label: 'COMMENTS : ',
                        value: '',
                        fontSize: 7.8,
                      ),
                      pw.SizedBox(height: 4),

                      pw.Divider(height: 1, thickness: 0.6, color: PdfColors.black),
                      pw.SizedBox(height: 3),

                      pw.Text(
                        'RESULTS SEND TO :',
                        style: pw.TextStyle(fontSize: 7.8, font: fontBold),
                      ),
                      pw.SizedBox(height: 2),

                      buildUnderlineField(
                        label: 'Name: ',
                        value: resultsSendToName,
                        fontSize: 7.5,
                      ),
                      pw.SizedBox(height: 2),

                      buildUnderlineField(
                        label: 'E-mail : ',
                        value: resultsSendToEmail,
                        fontSize: 7.5,
                      ),
                      pw.SizedBox(height: 2),

                      buildUnderlineField(
                        label: 'Phone/Mobile : ',
                        value: resultsSendToPhone,
                        fontSize: 7.5,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 8),
                pw.Container(
                  width: 0.8,
                  height: 240,
                  color: PdfColors.black,
                ),
                pw.SizedBox(width: 8),

                // 2. RIGHT COLUMN: INSULATING OIL SAMPLE
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Center(
                        child: pw.Text(
                          'INSULATING OIL SAMPLE',
                          style: pw.TextStyle(
                            fontSize: 10.5,
                            font: fontBold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 5),

                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('DATE : ', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                          pw.Container(
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                            child: pw.Text(inspectionDate, style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text('TIME: ', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                          pw.Expanded(
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                              child: pw.Text('', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),

                      buildUnderlineField(
                        label: 'SAMPLE DRAWN BY : ',
                        value: samplerName.trim().isNotEmpty ? samplerName.trim() : '',
                        fontSize: 7.8,
                      ),
                      pw.SizedBox(height: 3),

                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('ID: ', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                          pw.Container(
                            width: 50,
                            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                            child: pw.Text(samplerId.trim().isNotEmpty ? samplerId.trim() : '', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                          ),
                          pw.Text('   TEL/MOB : ', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                          pw.Expanded(
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                              child: pw.Text(samplerPhone.trim().isNotEmpty ? samplerPhone.trim() : '', style: pw.TextStyle(fontSize: 7.8, font: fontBold)),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),

                      pw.Text(
                        'SAMPLE TAKEN FROM:',
                        style: pw.TextStyle(fontSize: 7.8, font: fontBold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          buildBox(isBottom),
                          pw.Text('Main Tank Bottom   ', style: pw.TextStyle(fontSize: 7.0, font: fontRegular)),
                          buildBox(isTop),
                          pw.Text('Main Tank Top   ', style: pw.TextStyle(fontSize: 7.0, font: fontRegular)),
                          buildBox(isOtherPt),
                          pw.Text('Other', style: pw.TextStyle(fontSize: 7.0, font: fontRegular)),
                        ],
                      ),
                      pw.SizedBox(height: 4),

                      pw.Text(
                        'TEST REQUIRED :',
                        style: pw.TextStyle(fontSize: 7.8, font: fontBold),
                      ),
                      pw.SizedBox(height: 2),

                      // Tests + Other Breakdown side-by-side
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Left: Test Checklist
                          pw.Expanded(
                            flex: 6,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    buildBox(isOQ),
                                    pw.Expanded(
                                      child: pw.Text('Oil Quality Test (OQ)', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    buildBox(isDGA),
                                    pw.Expanded(
                                      child: pw.Text('Dissolved Gas-in-Oil Analysis\n(DGA)', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  children: [
                                    buildBox(isFurans),
                                    pw.Expanded(
                                      child: pw.Text('Furanic Compounds', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  children: [
                                    buildBox(isSulfur),
                                    pw.Expanded(
                                      child: pw.Text('Corrosive Sulfur', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  children: [
                                    buildBox(isPassivators),
                                    pw.Expanded(
                                      child: pw.Text('Passivators', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          pw.SizedBox(width: 4),

                          // Right: Other Sub-points Grid
                          pw.Expanded(
                            flex: 5,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  children: [
                                    buildBox(isCblR, size: 7.5),
                                    pw.Expanded(child: pw.Text('CBL R', style: pw.TextStyle(fontSize: 6.5, font: fontRegular))),
                                    buildBox(isCblY, size: 7.5),
                                    pw.Expanded(child: pw.Text('CBL Y', style: pw.TextStyle(fontSize: 6.5, font: fontRegular))),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  children: [
                                    buildBox(isCblB, size: 7.5),
                                    pw.Expanded(child: pw.Text('CBL B', style: pw.TextStyle(fontSize: 6.5, font: fontRegular))),
                                    buildBox(isCblN, size: 7.5),
                                    pw.Expanded(child: pw.Text('CBL N', style: pw.TextStyle(fontSize: 6.5, font: fontRegular))),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  children: [
                                    buildBox(isOneCbl, size: 7.5),
                                    pw.Expanded(child: pw.Text('ONE CBL (R-Y-B)', style: pw.TextStyle(fontSize: 5.5, font: fontRegular))),
                                    buildBox(isOltc1, size: 7.5),
                                    pw.Expanded(child: pw.Text('OLTC 1', style: pw.TextStyle(fontSize: 6.5, font: fontRegular))),
                                  ],
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  children: [
                                    buildBox(isOltc2, size: 7.5),
                                    pw.Expanded(child: pw.Text('OLTC 2', style: pw.TextStyle(fontSize: 6.5, font: fontRegular))),
                                    buildBox(isOltc3, size: 7.5),
                                    pw.Expanded(child: pw.Text('OLTC 3', style: pw.TextStyle(fontSize: 6.5, font: fontRegular))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),

                      buildUnderlineField(
                        label: 'OTHERS : ',
                        value: otherSubLocation?.isNotEmpty == true ? otherSubLocation! : '',
                        fontSize: 7.5,
                      ),
                      pw.SizedBox(height: 4),

                      pw.Text(
                        'REASON FOR TEST:',
                        style: pw.TextStyle(fontSize: 7.8, font: fontBold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                buildBox(isCommissioning),
                                pw.Text('Commissioning', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                buildBox(isInvestigate),
                                pw.Text('Investigate', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                buildBox(isWarranty),
                                pw.Text('Warranty', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Row(
                              children: [
                                buildBox(isFailure),
                                pw.Text('Failure', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          buildBox(isAnnual),
                          pw.Text('Annual', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          buildBox(isProcessing),
                          pw.Text('Processing Sample # ', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                          pw.Expanded(
                            child: pw.Container(
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                              child: pw.Text('', style: pw.TextStyle(fontSize: 6.8, font: fontRegular)),
                            ),
                          ),
                        ],
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

    // Prepare units list (if empty, create default unit)
    final units = selectedTransformers.isNotEmpty
        ? selectedTransformers
        : [
            const TransformerInfo(
              number: 'T601',
              voltage: '132/13.8 KV',
              mva: '67',
              serial: 'TR-601-SN',
              manufacturer: 'HYUNDAI / ABB',
            ),
          ];

    // 1. Resolve sampling locations list (Item 2 & Other)
    final List<Map<String, String?>> resolvedLocations = [];

    if (samplingPoints.contains('Main Tank Bottom')) {
      resolvedLocations.add({'type': 'Main Tank Bottom', 'sub': null});
    }
    if (samplingPoints.contains('Main Tank Top')) {
      resolvedLocations.add({'type': 'Main Tank Top', 'sub': null});
    }
    if (samplingPoints.contains('Other (أخرى)') || otherSamplingPoints.isNotEmpty) {
      if (otherSamplingPoints.isNotEmpty) {
        for (final sub in otherSamplingPoints) {
          resolvedLocations.add({'type': 'Other', 'sub': sub});
        }
      } else {
        resolvedLocations.add({'type': 'Other', 'sub': null});
      }
    }

    // Fallback if empty
    if (resolvedLocations.isEmpty) {
      resolvedLocations.add({'type': 'Main Tank Bottom', 'sub': null});
    }

    // 2. Resolve tests required list (Item 3)
    final List<String> resolvedTests = testsRequired.isNotEmpty
        ? testsRequired.toList()
        : ['Oil Quality Test (OQ)'];

    // 3. Build all individual sample cards
    final List<pw.Widget> allCards = [];

    for (final tx in units) {
      for (final loc in resolvedLocations) {
        for (final test in resolvedTests) {
          allCards.add(
            buildOilSampleCard(
              tx: tx,
              locationType: loc['type']!,
              otherSubLocation: loc['sub'],
              testName: test,
            ),
          );
        }
      }
    }

    // Chunk cards into pairs (2 per A4 portrait page) centered vertically with equal top/bottom margins
    for (int i = 0; i < allCards.length; i += 2) {
      final card1 = allCards[i];
      final card2 = (i + 1 < allCards.length) ? allCards[i + 1] : null;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
          ),
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Spacer(),
                card1,
                if (card2 != null) ...[
                  pw.SizedBox(height: 14),
                  card2,
                ],
                pw.Spacer(),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }
}


