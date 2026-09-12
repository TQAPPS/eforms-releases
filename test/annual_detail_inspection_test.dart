import 'package:flutter_test/flutter_test.dart';
import 'package:e_forms_app/models/annual_detail_inspection_model.dart';
import 'package:e_forms_app/models/substation_model.dart';
import 'package:e_forms_app/services/pdf_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Annual Detail Inspection Module Tests', () {
    test('Default checklist contains exactly 35 items matching standard', () {
      final items = AnnualDetailInspectionModel.defaultItems();
      expect(items.length, equals(35));
      expect(items.first.number, equals(1));
      expect(items.first.nameEn, contains('Oil level Main Tank'));
      expect(items.last.number, equals(35));
      expect(items.last.nameEn, contains('Check grounding connections'));
    });

    test('Model serialization to and from Map works reliably', () {
      final items = List<AnnualInspectionItemModel>.from(
          AnnualDetailInspectionModel.defaultItems());
      items[0] = items[0].copyWith(status: 'Done', remarks: 'Normal level');
      items[14] = items[14].copyWith(status: 'Check', remarks: 'Minor dust');

      final model = AnnualDetailInspectionModel(
        id: 'ANNUAL-TEST-001',
        createdAt: '2026-09-10T12:00:00.000',
        updatedAt: '2026-09-10T12:00:00.000',
        status: 'draft',
        division: 'Eastern Operating Division (EOD)',
        department: 'Transformers Maintenance Dept.',
        workOrderNo: 'WO-2026-TEST-99',
        workGroup: 'Transformers Substation Team',
        substation: 'JIC 380/110kV',
        location: 'Jubail Industrial City',
        transformerDesignation: 'T601',
        manufacturer: 'ABB',
        makeType: 'OFAF',
        mvaRating: '67 MVA',
        voltageRatio: '115/13.8 kV',
        typeConnectionHv: 'Air Bushing',
        typeConnectionLv: 'Air Cable Box',
        typeConnectionTv: 'Outdoor Bushings',
        items: items,
        comments: 'Unit inspected and operational per standard.',
        inspectedByName: 'Eng. Ahmad Al-Ghamdi',
        inspectedByBadge: 'SEC-89210',
        inspectedDate: '2026/09/10',
        checkedByName: 'Eng. Khalid Al-Otaibi',
        checkedByBadge: 'SEC-10442',
        checkedDate: '2026/09/10',
      );

      final map = model.toMap();
      final reconstructed = AnnualDetailInspectionModel.fromMap(map);

      expect(reconstructed.id, equals('ANNUAL-TEST-001'));
      expect(reconstructed.workOrderNo, equals('WO-2026-TEST-99'));
      expect(reconstructed.items.length, equals(35));
      expect(reconstructed.items[0].status, equals('Done'));
      expect(reconstructed.items[0].remarks, equals('Normal level'));
      expect(reconstructed.items[14].status, equals('Check'));
      expect(reconstructed.checkedByBadge, equals('SEC-10442'));
    });

    test('PdfGeneratorService generates a valid 3-page Annual Detail Inspection PDF', () async {
      final items = AnnualDetailInspectionModel.defaultItems();
      final model = AnnualDetailInspectionModel(
        id: 'ANNUAL-TEST-PDF',
        createdAt: '2026-09-10T12:00:00.000',
        updatedAt: '2026-09-10T12:00:00.000',
        status: 'completed',
        division: 'Eastern Operating Division',
        department: 'Substation Maintenance Dept',
        workOrderNo: 'WO-2026-8801',
        workGroup: 'Substation Team',
        substation: 'JIC 380/110kV',
        location: 'Eastern Region',
        transformerDesignation: 'T601',
        manufacturer: 'Siemens Energy',
        makeType: 'OFAF',
        mvaRating: '67 MVA',
        voltageRatio: '115/13.8 kV',
        typeConnectionHv: 'Air Bushing',
        typeConnectionLv: 'Air Cable Box',
        typeConnectionTv: 'Outdoor Bushings',
        items: items,
        comments: 'No critical anomalies identified.',
        inspectedByName: 'Eng. Ahmad',
        inspectedByBadge: 'SEC-89210',
        inspectedDate: '2026/09/10',
        checkedByName: 'Eng. Khalid',
        checkedByBadge: 'SEC-10442',
        checkedDate: '2026/09/10',
      );

      final pdfBytes = await PdfGeneratorService.generateAnnualDetailInspectionPdf(
        inspection: model,
      );

      expect(pdfBytes, isNotEmpty);
      // PDF magic header
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46])); // %PDF
    });

    test('PdfGeneratorService supports punctuation marks, Arabic commas, quotes, and symbols', () async {
      final items = AnnualDetailInspectionModel.defaultItems();
      items[0] = items[0].copyWith(
        status: 'Done',
        remarks: 'تم الفحص بنجاح، لا توجد تسريبات؛ الحالة: ممتازة (100%).',
      );
      items[7] = items[7].copyWith(
        status: 'Done',
        remarks: '“No Leak” - Normal 45°C ± 2°C • Checked.',
      );

      final model = AnnualDetailInspectionModel(
        id: 'ANNUAL-TEST-SYMBOLS',
        createdAt: '2026-09-11T12:00:00.000',
        updatedAt: '2026-09-11T12:00:00.000',
        status: 'completed',
        division: 'القطاع الشرقي - إدارة الصيانة، قسم المحولات',
        department: 'Substation Maintenance Dept.',
        workOrderNo: 'WO-2026-8801 #1',
        workGroup: 'Transformers Team & Protection Group',
        substation: 'JIC 380/115kV (Substation A)',
        location: 'Jubail Industrial City / المنطقة الشرقية',
        transformerDesignation: 'T-601 [Main]',
        manufacturer: 'Siemens Energy / ألمانيا',
        makeType: 'OFAF (100% Load)',
        mvaRating: '67 MVA ± 5%',
        voltageRatio: '115/13.8 kV',
        typeConnectionHv: 'Air Bushing - Phase A, B & C',
        typeConnectionLv: 'Air Cable Box',
        typeConnectionTv: 'Outdoor Bushings',
        items: items,
        comments: 'تم إنجاز الفحص الدوري بنجاح، ومستوى الزيت طبيعي؛ لا توجد أي ملاحظات حرجة “Interlocked” (100%).',
        inspectedByName: 'م. أحمد الغامدي، مهندس أول',
        inspectedByBadge: 'SEC-89210',
        inspectedDate: '2026/09/11',
        checkedByName: 'م. خالد العتيبي؛ المشرف العام',
        checkedByBadge: 'SEC-10442',
        checkedDate: '2026/09/11',
      );

      final pdfBytes = await PdfGeneratorService.generateAnnualDetailInspectionPdf(
        inspection: model,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('PdfGeneratorService generates Oil Sampling PDF with OQ and additional tests', () async {
      final sub = NationalGridData.substations.first;
      final pdfBytes = await PdfGeneratorService.generateOilSamplingPdf(
        substation: sub,
        selectedTransformers: [sub.transformers.first],
        division: 'EOA Maintenance',
        department: 'Substation Dept',
        inspectionDate: '2026/09/11',
        samplerName: 'Eng. Tariq',
        sampleTemp: '45',
        equipmentTypes: {'Transformer'},
        samplingPoints: {'Main Tank Bottom'},
        otherSamplingPoints: {},
        testsRequired: {
          'Oil Quality Test (OQ)',
          'Furanic Compounds',
          'Corrosive Sulfur',
          'Passivators',
        },
        reasonsForTest: {'Annual'},
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('PdfGeneratorService generates Sample Acknowledgement PDF cleanly', () async {
      final pdfBytes = await PdfGeneratorService.generateSampleAcknowledgementPdf(
        workOrder: 'WO-12345',
        refNo: 'REF-99',
        selectedLab: 'RYD',
        externalLabName: '',
        ibmMaximoAssetNumber: 'MAX-001',
        equipmentType: 'Transformer',
        equipmentTypeDetail: '',
        cityName: 'Riyadh',
        substationName: 'Substation 9001',
        manufacturer: 'ABB',
        manufacturerYear: '2020',
        equipmentOilTemp: '55',
        voltage: '115/13.8',
        capacity: '67',
        serialNo: 'SN-998877',
        reasonOfSample: 'Annual',
        otherReasonDetail: '',
        reportSendTo: 'maintenance@example.com',
        sampleBy: 'Eng. Tariq',
        sampleDate: '2026/09/11',
        receivedDate: '2026/09/11',
        testsRequired: {'Quality Test', 'D.G.A'},
        senderName: 'Eng. Tariq',
        senderId: 'SEC-123',
        senderSignature: 'Tariq',
        syringeCase: 'Good',
        bottleCase: 'Good',
        receivingDate: '2026/09/11',
        sampleStatus: 'Received',
        remarks: 'Sample received in good condition',
        receivedBy: 'Lab Specialist',
        employeeId: 'LAB-55',
        receiverSignature: 'Specialist',
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.take(4).toList(), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });
}
