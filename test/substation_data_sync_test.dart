import 'package:flutter_test/flutter_test.dart';
import 'package:e_forms_app/models/substation_model.dart';
import 'package:e_forms_app/services/substation_data_service.dart';

void main() {
  group('SubstationDataService & Model Serialization Tests', () {
    test('SubstationModel and TransformerInfo JSON serialization roundtrip', () {
      const transformer = TransformerInfo(
        number: 'T601',
        voltage: '132/13.8 Kv',
        serial: 'SN-123456',
        manufacturer: 'ABB',
        mva: '67',
        yearManufacture: '2015',
        connectionHv: 'Oil Cable Box',
        connectionLv: 'Air Bushing',
        connectionTv: 'Outdoor Bushings',
      );

      final jsonMap = transformer.toJson();
      final restoredTransformer = TransformerInfo.fromJson(jsonMap);

      expect(restoredTransformer.number, 'T601');
      expect(restoredTransformer.voltage, '132/13.8 Kv');
      expect(restoredTransformer.serial, 'SN-123456');
      expect(restoredTransformer.manufacturer, 'ABB');
      expect(restoredTransformer.mva, '67');
      expect(restoredTransformer.yearManufacture, '2015');
      expect(restoredTransformer.connectionHv, 'Oil Cable Box');
      expect(restoredTransformer.connectionLv, 'Air Bushing');
      expect(restoredTransformer.connectionTv, 'Outdoor Bushings');

      const substation = SubstationModel(
        id: 'sub_test_1',
        name: 'Test Substation Alpha',
        region: 'SOD',
        division: 'SOD / Southern Operating Division',
        department: 'Substation Maintenance Dept',
        transformers: [transformer],
      );

      final subJson = substation.toJson();
      final restoredSubstation = SubstationModel.fromJson(subJson);

      expect(restoredSubstation.id, 'sub_test_1');
      expect(restoredSubstation.name, 'Test Substation Alpha');
      expect(restoredSubstation.region, 'SOD');
      expect(restoredSubstation.transformers.length, 1);
      expect(restoredSubstation.transformers.first.number, 'T601');
    });

    test('parseCsvData correctly extracts substations and transformers from CSV', () {
      const sampleCsv = '''
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,write model of OLTC,,,,,,,,,,,,,,,,,,,,,,,,,,,
NO.,Area,Substation ,Transformer number,Voltage level,Equipment referance (SAP),Serial number,Energizing date,Manufacturer,Year of Manufacture,Type / Model No.,Rating (MVA),Type of connection HV side ,Type of connection LV side,Type of connection TV side
1,Najran,Najran East,T601,132/33/13.8 KV,3400NG-S-6501,N422092,1998-,SIEMENS,1996-,TLPN7852,60,oil cable box ,air bushing ,,core
2,Najran,Najran East,T602,132/33/13.8 KV,3400NG-S-6502,N422093,1998-,SIEMENS,1996-,TLPN7852,60,oil cable box ,air bushing ,,core
3,Jizan,Atuwal,T601,132/13.8,20090519TGC010001,20090519TGC010001,,Hyundai,2009,,67,Oil Cable Box,Air Bushing,N/A
''';

      final result = SubstationDataService.parseCsvData(sampleCsv);
      expect(result.isSuccess, isTrue);
      expect(result.substations.length, 2);

      final najranEast = result.substations.firstWhere((s) => s.name == 'Najran East');
      expect(najranEast.region, 'Najran');
      expect(najranEast.transformers.length, 2);
      expect(najranEast.transformers[0].number, 'T601');
      expect(najranEast.transformers[0].manufacturer, 'SIEMENS');
      expect(najranEast.transformers[0].mva, '60');
      expect(najranEast.transformers[1].number, 'T602');

      final atuwal = result.substations.firstWhere((s) => s.name == 'Atuwal');
      expect(atuwal.transformers.length, 1);
      expect(atuwal.transformers[0].number, 'T601');
      expect(atuwal.transformers[0].manufacturer, 'Hyundai');
      expect(atuwal.transformers[0].yearManufacture, '2009');
    });

    test('parseCsvData handles parallel column and merged substation rows correctly', () {
      const complexCsv = '''
Area,Substation ,Transformer number,Voltage level,Serial number,Manufacturer,Year of Manufacture,Rating (MVA),,,,,,,,,,,,,,,,,,,Parallel operation in the substation (Status)
JIC,JIC,T601,132/13.8 Kv,SN-001,ABB,2010,67,,,,,,,,,,,,,,,,,,,Tow transformer parallel ( other indepentent)
JIC,,T602,132/13.8 Kv,SN-002,ABB,2010,67,,,,,,,,,,,,,,,,,,,Tow transformer parallel ( other indepentent)
JIC,,T603,132/13.8 Kv,SN-003,ABB,2010,67,,,,,,,,,,,,,,,,,,,Tow transformer parallel ( other indepentent)
MAH,MAH,T601,132/13.8 Kv,SN-004,Siemens,2015,50,,,,,,,,,,,,,,,,,,,Independent
MAH,,T602,132/13.8 Kv,SN-005,Siemens,2015,50,,,,,,,,,,,,,,,,,,,Independent
''';

      final result = SubstationDataService.parseCsvData(complexCsv);
      expect(result.isSuccess, isTrue);
      expect(result.substations.length, 2);

      final jic = result.substations.firstWhere((s) => s.name == 'JIC');
      expect(jic.transformers.length, 3);
      expect(jic.transformers.map((t) => t.number).toList(), ['T601', 'T602', 'T603']);

      final mah = result.substations.firstWhere((s) => s.name == 'MAH');
      expect(mah.transformers.length, 2);
      expect(mah.transformers.map((t) => t.number).toList(), ['T601', 'T602']);
    });

    test('NationalGridData.substations updates dynamically when applied', () {
      expect(NationalGridData.substations.isNotEmpty, isTrue);
      final initialCount = NationalGridData.substations.length;

      const newSub = SubstationModel(
        id: 'sub_dynamic_1',
        name: 'Dynamic Test Substation',
        region: 'TEST',
        transformers: [
          TransformerInfo(
            number: 'T999',
            voltage: '132/13.8 Kv',
          ),
        ],
      );

      SubstationDataService.applySubstations([newSub], source: 'Unit Test');

      expect(NationalGridData.substations.length, 1);
      expect(NationalGridData.substations.first.name, 'Dynamic Test Substation');
      expect(SubstationDataService.substationsNotifier.value.first.name, 'Dynamic Test Substation');
      expect(SubstationDataService.lastSyncSource, 'Unit Test');

      // Reset to default
      NationalGridData.substations = NationalGridData.defaultSubstations;
      expect(NationalGridData.substations.length, initialCount);
    });

    test('NationalGridData.jizanSubstations returns strictly Jizan substations', () {
      final jizanList = NationalGridData.jizanSubstations;
      expect(jizanList.isNotEmpty, isTrue);
      expect(jizanList.length, 42);
      for (final s in jizanList) {
        expect(NationalGridData.isJizan(s), isTrue);
        expect(SubstationDataService.isJizanRegion(s.region), isTrue);
      }
    });
  });
}
