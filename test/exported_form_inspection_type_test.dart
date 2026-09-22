import 'package:flutter_test/flutter_test.dart';
import 'package:e_forms_app/models/exported_form_model.dart';

void main() {
  group('ExportedFormModel Inspection Type Mapping Tests', () {
    test('Power Transformer Detailed Monthly Inspection maps to فحص شهري', () {
      final form = ExportedFormModel(
        id: 'test_monthly_1',
        fileName: 'Salama_T601_Power Transformer Detailed Monthly Inspection.pdf',
        substation: 'Salama',
        equipment: 'T601',
        formType: 'Power Transformer Detailed Monthly Inspection',
        technician: 'Engineer',
        notes: '',
        driveUrl: '',
        exportedAt: DateTime.now(),
        fileSizeBytes: 1024,
      );

      expect(form.canonicalFormTitle, equals('Power Transformer Detailed Monthly Inspection'));
      expect(form.displayInspectionType, equals('فحص شهري'));
    });

    test('Checklist for Substation Power Transformer maps to فحص شهري', () {
      final form = ExportedFormModel(
        id: 'test_substation_1',
        fileName: 'Salama_T602_Checklist for Substation Power Transformer.pdf',
        substation: 'Salama',
        equipment: 'T602',
        formType: 'Checklist for Substation Power Transformer',
        technician: 'Engineer',
        notes: '',
        driveUrl: '',
        exportedAt: DateTime.now(),
        fileSizeBytes: 1024,
      );

      expect(form.canonicalFormTitle, equals('Checklist for Substation Power Transformer'));
      expect(form.displayInspectionType, equals('فحص شهري'));
    });

    test('Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection maps to فحص سنوي', () {
      final form = ExportedFormModel(
        id: 'test_annual_1',
        fileName: 'Salama_T603_Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection.pdf',
        substation: 'Salama',
        equipment: 'T603',
        formType: 'Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection',
        technician: 'Engineer',
        notes: '',
        driveUrl: '',
        exportedAt: DateTime.now(),
        fileSizeBytes: 1024,
      );

      expect(form.canonicalFormTitle, equals('Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection'));
      expect(form.displayInspectionType, equals('فحص سنوي'));
    });

    test('buildFileName formats filename as [Substation]_[Equipment]_[FormType].pdf', () {
      final name1 = ExportedFormModel.buildFileName(
        substation: 'JIC 380/110kV',
        equipment: 'T601',
        formType: 'Power Transformer Detailed Monthly Inspection',
      );
      expect(name1, equals('JIC 380-110kV_T601_Power Transformer Detailed Monthly Inspection.pdf'));

      final name2 = ExportedFormModel.buildFileName(
        substation: 'Salama',
        equipment: 'T602',
        formType: 'Checklist for Substation Power Transformer',
      );
      expect(name2, equals('Salama_T602_Checklist for Substation Power Transformer.pdf'));

      final name3 = ExportedFormModel.buildFileName(
        substation: 'Al-Khishl New',
        equipment: 'T603',
        formType: 'Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection',
      );
      expect(name3, equals('Al-Khishl New_T603_Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection.pdf'));
    });

    test('parseFromFileName and fromJson extract substation, equipment, formType and inspectionType accurately', () {
      const fileName = 'Salama_T603_Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection.pdf';
      final parsed = ExportedFormModel.parseFromFileName(fileName);
      expect(parsed['substation'], equals('Salama'));
      expect(parsed['equipment'], equals('T603'));
      expect(parsed['formType'], equals('Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection'));

      // From JSON with only fileName (e.g. from Google Drive fetch)
      final model = ExportedFormModel.fromJson({
        'id': 'from_drive_1',
        'fileName': fileName,
        'driveUrl': 'https://drive.google.com/test',
      });

      expect(model.substation, equals('Salama'));
      expect(model.equipment, equals('T603'));
      expect(model.canonicalFormTitle, equals('Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection'));
      expect(model.displayInspectionType, equals('فحص سنوي'));
    });
  });
}
