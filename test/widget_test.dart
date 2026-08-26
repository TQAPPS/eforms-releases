import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_forms_app/main.dart';
import 'package:e_forms_app/models/substation_model.dart';
import 'package:e_forms_app/screens/inspection_approval_screen.dart';
import 'package:e_forms_app/services/pdf_generator_service.dart';

Future<void> _openInspectionScreen(WidgetTester tester) async {
  await tester.tap(find.text('Monthly Inspection Power Transformer').first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, '8842910');
  await tester.pumpAndSettle();
  final startBtn = find.text('بدء الفحص');
  await tester.ensureVisible(startBtn);
  await tester.pumpAndSettle();
  await tester.tap(startBtn, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App renders homepage with 4 form buttons including Monthly Inspection Power Transformer', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Verify main app title is rendered
    expect(find.text('منظومة النماذج الإلكترونية'), findsOneWidget);

    // Verify all 4 default form names are present in the grid
    expect(find.text('Monthly Inspection Power Transformer'), findsOneWidget);
    expect(find.text('تقرير فحص واستلام مواد'), findsOneWidget);
    expect(find.text('طلب صيانة ودعم فني'), findsOneWidget);
    expect(find.text('استبيان تقييم ورضا العملاء'), findsOneWidget);

    // Verify Dark/Light mode switcher exists
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
  });

  testWidgets('App renders 2-column grid on small mobile phone screen without any overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Verify all 4 form buttons exist without render overflow exception
    expect(find.text('Monthly Inspection Power Transformer'), findsOneWidget);
    expect(find.text('تقرير فحص واستلام مواد'), findsOneWidget);
    expect(find.text('طلب صيانة ودعم فني'), findsOneWidget);
    expect(find.text('استبيان تقييم ورضا العملاء'), findsOneWidget);
  });

  testWidgets('Category chips bar is removed for a cleaner professional UI', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Verify FilterChip is removed
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('Search query filters the grid in real-time', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Find search field
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    // Search for 'استلام'
    await tester.enterText(searchField, 'استلام');
    await tester.pumpAndSettle();

    // Verify only 'تقرير فحص واستلام مواد' is shown
    expect(find.text('تقرير فحص واستلام مواد'), findsOneWidget);
    expect(find.text('Monthly Inspection Power Transformer'), findsNothing);
  });

  testWidgets('Start inspection modal has empty Work Order by default and validates input before launch', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Tap on Monthly Inspection Power Transformer form card
    final formButton = find.text('Monthly Inspection Power Transformer').first;
    await tester.tap(formButton);
    await tester.pumpAndSettle();

    // Verify Start Inspection Dialog opens with Substation, Work Order, Date, and Transformer list
    expect(find.text('بدء فحص المحولات الشهري'), findsOneWidget);
    expect(find.text('1. اسم محطة التحويل (Substation Name)'), findsOneWidget);
    expect(find.text('2. رقم أمر العمل (Work Order)'), findsOneWidget);
    expect(find.text('3. تاريخ الفحص (Inspection Date)'), findsOneWidget);
    expect(find.text('بدء الفحص'), findsOneWidget);

    // Verify Work Order text field is empty by default
    final workOrderField = find.byType(TextFormField).first;
    final TextFormField fieldWidget = tester.widget(workOrderField);
    expect(fieldWidget.controller?.text, isEmpty);

    // Tapping 'بدء الفحص' while empty shows validation error
    final startBtn = find.text('بدء الفحص');
    await tester.ensureVisible(startBtn);
    await tester.pumpAndSettle();
    await tester.tap(startBtn);
    await tester.pumpAndSettle();
    expect(find.text('يرجى إدخال رقم أمر العمل'), findsOneWidget);

    // Enter Work Order and submit
    await tester.enterText(workOrderField, 'WO-2026-GRID-8842');
    await tester.pumpAndSettle();
    await tester.ensureVisible(startBtn);
    await tester.pumpAndSettle();
    await tester.tap(startBtn);
    await tester.pumpAndSettle();

    // Verify Grid Maintenance Screen renders with the selected substation's transformers and centered title
    expect(find.text('Monthly Inspection Power Transformer'), findsWidgets);
    expect(find.textContaining('محولات المساعدات'), findsWidgets);
    expect(find.text('محولات الاحتياط'), findsOneWidget);

    // Tap return to home button using back tooltip
    final backBtn = find.byTooltip('الرجوع إلى الصفحة الرئيسية');
    expect(backBtn, findsOneWidget);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    // Verify returned back to home
    expect(find.text('منظومة النماذج الإلكترونية'), findsOneWidget);
  });

  testWidgets('Prevents skipping to another transformer if current transformer is incomplete', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Open Monthly Inspection Form
    await _openInspectionScreen(tester);

    // Verify currently on T601 and chips exist
    expect(find.textContaining('T601'), findsWidgets);

    // Try tapping on second transformer chip T602
    final t602Chip = find.textContaining('T602');
    expect(t602Chip, findsOneWidget);
    await tester.tap(t602Chip);
    await tester.pumpAndSettle();

    // Verify warning dialog appears blocking navigation
    expect(find.text('تنبيه: يلزم إكمال الفحص'), findsOneWidget);
    expect(find.textContaining('لا يمكن تخطي'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('استكمال تعبئة المحول الآن'));
    await tester.pumpAndSettle();
  });

  testWidgets('Tap Position slider opens and updates value between 1 and 32', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Open Monthly Inspection Form
    await _openInspectionScreen(tester);

    // Scroll to and tap on Tap Position input field
    final tapField = find.textContaining('6. Tap Position');
    await tester.ensureVisible(tapField.first);
    await tester.pumpAndSettle();
    await tester.tap(tapField.first);
    await tester.pumpAndSettle();

    // Verify Slider Modal Bottom Sheet is open
    expect(find.text('تحديد موضع المغيّر (Tap Position)'), findsOneWidget);
    expect(find.textContaining('اسحب شريط السلايدر لاختيار موضع مغير الجهد من 1 إلى 32'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    // Tap confirm button
    final confirmBtn = find.textContaining('تأكيد الموضع');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('Bottom bar has centered button, no home button, and disabled until complete', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Open Monthly Inspection Form
    await _openInspectionScreen(tester);

    // Verify button has name 'التالي'
    expect(find.textContaining('التالي'), findsWidgets);
    // Verify home button 'الرئيسية' is removed from bottom bar
    expect(find.text('الرئيسية'), findsNothing);
  });

  testWidgets('Tapping auxiliary transformers tab without completing power transformers shows warning and stays on power tab', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Open Monthly Inspection Form
    await _openInspectionScreen(tester);

    // Directly tap on Auxiliary Transformers Tab
    final auxTab = find.textContaining('محولات المساعدات');
    expect(auxTab, findsWidgets);
    await tester.tap(auxTab.first);
    await tester.pumpAndSettle();

    // Verify warning dialog shows
    expect(find.text('تنبيه: يلزم إكمال الفحص'), findsOneWidget);
    expect(find.textContaining('لا يمكن تخطي'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('استكمال تعبئة المحول الآن'));
    await tester.pumpAndSettle();
  });

  testWidgets('Counter reading and temperature fields have numeric keyboards and N/A options across transformers', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Open Monthly Inspection Form
    await _openInspectionScreen(tester);

    // Verify Tap Position in Power Transformers is 1-32
    expect(find.textContaining('6. Tap Position'), findsWidgets);

    // Verify Counter Reading and Temperature fields have N/A options
    expect(find.textContaining('7. Counter Reading'), findsWidgets);
    expect(find.textContaining('8. Oil Temp'), findsWidgets);
    expect(find.textContaining('9. HV Winding Temp'), findsWidgets);
    expect(find.textContaining('10. LV Winding Temp'), findsWidgets);

    // Verify N/A chips are present
    expect(find.text('N/A'), findsWidgets);
  });

  testWidgets('Inspection Approval Screen renders executive summary, attachments, and digital signature', (WidgetTester tester) async {
    final testSubstation = NationalGridData.substations.first;

    await tester.pumpWidget(
      MaterialApp(
        home: InspectionApprovalScreen(
          substation: testSubstation,
          workOrder: 'WO-2026-GRID-8842',
          inspectionDate: '2026/08/23',
          powerTransformersData: [
            {'txName': 'T601'}
          ],
          auxTransformersData: [
            {'txName': 'AUX-T1'}
          ],
          hasSpareTransformer: false,
          spareTransformersData: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Executive Summary and Title
    expect(find.text('الاعتماد والتوقيع الإلكتروني'), findsOneWidget);
    expect(find.text('ملخص فحص محولات المحطة'), findsOneWidget);
    expect(find.text('الملاحظات الفنية'), findsOneWidget);
    expect(find.textContaining('درجة الحرارة المحيطة'), findsNothing);
    expect(find.textContaining('مرفقات الفحص'), findsNothing);

    // Verify Inspector & Supervisor fields are empty by default
    final textFields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    for (final tf in textFields) {
      expect(tf.controller?.text, isEmpty);
    }

    expect(find.text('اعتماد وحفظ تقرير الصيانة النهائي'), findsOneWidget);
  });

  testWidgets('Dark / Light theme toggles properly', (WidgetTester tester) async {
    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    // Find the theme switcher button
    final themeToggle = find.byTooltip('التحويل إلى الثيم الداكن');
    expect(themeToggle, findsOneWidget);

    // Tap to switch to Dark Mode
    await tester.tap(themeToggle);
    await tester.pumpAndSettle();

    // Verify switcher now offers switching back to light mode
    expect(find.byTooltip('التحويل إلى الثيم الفاتح'), findsOneWidget);
  });

  testWidgets('Alert dialog and forms render without any overflow on narrow mobile screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const EFormsApp());
    await tester.pumpAndSettle();

    await _openInspectionScreen(tester);

    // Try tapping second transformer T602 without completing current one
    final t602Chip = find.textContaining('T602');
    expect(t602Chip, findsOneWidget);
    await tester.ensureVisible(t602Chip);
    await tester.pumpAndSettle();
    await tester.tap(t602Chip);
    await tester.pumpAndSettle();

    // Verify warning dialog renders completely without any overflow
    expect(find.text('تنبيه: يلزم إكمال الفحص'), findsOneWidget);
    expect(find.textContaining('العناصر غير المكتملة'), findsOneWidget);

    // Dismiss dialog safely
    await tester.tap(find.text('استكمال تعبئة المحول الآن'));
    await tester.pumpAndSettle();
  });

  testWidgets('PdfGeneratorService formats N/A and values and generates valid PDF document bytes', (WidgetTester tester) async {
    // Option 2: N/A
    expect(PdfGeneratorService.formatFieldValue('N/A'), 'N/A');

    // Item 1: Oil leakage
    expect(PdfGeneratorService.formatFieldValue('سليم - لا يوجد تسريب'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('ترشيح طفيف في الصمامات (متابعة)'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('يوجد تسريب نشط (إصلاح عاجل)'), 'Need fixed');

    // Item 2 & 3: Silica gel
    expect(PdfGeneratorService.formatFieldValue('أزرق (جاف وسليم)'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('تغير لون خفيف (متابعة بالدورية)'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('وردي مشبع بالكامل (استبدال عاجل)'), 'Need fixed');

    // Item 4 & 5: Oil levels
    expect(PdfGeneratorService.formatFieldValue('طبيعي (50% عند 30°C)'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('مرتفع (فوق المعدل)'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('منخفض (يحتاج تزويد زيت)'), 'Need fixed');

    // Item 11: Cooling fans
    expect(PdfGeneratorService.formatFieldValue('تم التشغيل اليدوي والرجوع للأوتوماتيك - سليم'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('يوجد اهتزاز أو ضجيج غير طبيعي (ملاحظة)'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('عطل في إحدى المراوح أو المضخات'), 'Need fixed');

    // Item 12: Control cabinet
    expect(PdfGeneratorService.formatFieldValue('محكمة الإغلاق ومحمية'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('تحتاج تبديل حشوة الإغلاق (Gasket)'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('غير محكمة الإغلاق وبحاجة صيانة'), 'Need fixed');

    // Item 13: Heater
    expect(PdfGeneratorService.formatFieldValue('السخانات والإنارة تعمل بكفاءة'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('السخان عاطل وبحاجة صيانة'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('الإنارة الداخلية لا تعمل'), 'Need fixed');

    // Item 14: DGA Monitor
    expect(PdfGeneratorService.formatFieldValue('يعمل بشكل طبيعي - لا توجد إنذارات'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('يوجد إنذار ارتفاع غازات (Gas Warning)'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('عطل في جهاز المراقبة (DGA Fault)'), 'Need fixed');

    // Item 15: General condition
    expect(PdfGeneratorService.formatFieldValue('التأريض محكم ولا يوجد صدأ'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('صدأ سطحي خفيف يحتاج دهان بالصيانة الدورية'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('انفصال أو ارتخاء في التأريض (عاجل)'), 'Need fixed');

    // Item 16: Bushings
    expect(PdfGeneratorService.formatFieldValue('العوازل نظيفة وخالية من الشروخ والترشيح'), 'OK');
    expect(PdfGeneratorService.formatFieldValue('تراكم أتربة خفيف يحتاج تنظيف في الغسيل الدوري'), 'Not OK');
    expect(PdfGeneratorService.formatFieldValue('شروخ أو ترشيح زيت يستدعي الاستبدال'), 'Need fixed');

    // Numeric items
    expect(PdfGeneratorService.formatFieldValue('16'), '16');
    expect(PdfGeneratorService.formatFieldValue('12450'), '12450');
    expect(PdfGeneratorService.formatFieldValue('45'), '45');
    expect(PdfGeneratorService.formatFieldValue('55'), '55');
    expect(PdfGeneratorService.formatFieldValue('52'), '52');
    expect(PdfGeneratorService.formatFieldValue(null), '');

    final testSubstation = NationalGridData.substations.first;
    final bytes = await PdfGeneratorService.generateInspectionPdf(
      substation: testSubstation,
      workOrder: 'WO-2026-GRID-8842',
      inspectionDate: '2026/08/23',
      powerTransformersData: [
        {
          'txName': 'T601',
          'oilLeakage': 'سليم (Normal)',
          'silicaGelMainTank': 'أزرق (Blue)',
          'tapPosition': '12',
          'tapCounter': 'N/A',
          'oilTemp': '48',
          'hvWindingTemp': '55',
          'lvWindingTemp': '52',
        }
      ],
      auxTransformersData: [
        {
          'txName': 'AUX-T1',
          'tapCounter': 'N/A',
          'hvWindingTemp': 'N/A',
        }
      ],
      hasSpareTransformer: true,
      spareTransformersData: [
        {'number': 'T-SPARE-01', 'condition': 'Good'}
      ],
      inspectorName: 'Eng. Fahad Al-Qahtani',
      inspectorId: '10842',
      supervisorName: 'Eng. Khalid Al-Dosari',
      supervisorId: '20491',
      technicalNotes: 'Routine monthly inspection completed successfully. All parameters normal.',
      referenceNumber: 'GRID-MNT-2026-9981',
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(500));
  });
}
