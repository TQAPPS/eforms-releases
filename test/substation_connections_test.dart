import 'package:flutter_test/flutter_test.dart';
import 'package:e_forms_app/models/substation_model.dart';

void main() {
  group('Substation Connections Verification Tests - JIZAN Only', () {
    test('Exactly 42 Jizan substations are loaded', () {
      expect(NationalGridData.substations.length, equals(42));
      for (final s in NationalGridData.substations) {
        expect(s.region, equals('JIZAN'));
      }
    });

    test('JIC T601 retrieves Oil Cable Box for HV and Air Bushing for LV', () {
      final sub = NationalGridData.substations.firstWhere((s) => s.name == 'JIC');
      final tr = sub.transformers.firstWhere((t) => t.number == 'T601');
      expect(tr.effectiveConnectionHv, equals('Oil Cable Box'));
      expect(tr.effectiveConnectionLv, equals('Air Bushing'));
      expect(tr.effectiveConnectionTv, equals('N/A'));
    });

    test('Atuwal T601 retrieves Oil Cable Box for HV and Air Bushing for LV', () {
      final sub = NationalGridData.substations.firstWhere((s) => s.name == 'Atuwal');
      final tr = sub.transformers.firstWhere((t) => t.number == 'T601');
      expect(tr.effectiveConnectionHv, equals('Oil Cable Box'));
      expect(tr.effectiveConnectionLv, equals('Air Bushing'));
    });

    test('Kudmi T801 retrieves GIB for HV and Oil Cable Box for LV', () {
      final sub = NationalGridData.substations.firstWhere((s) => s.name == 'Kudmi');
      final tr = sub.transformers.firstWhere((t) => t.number == 'T801');
      expect(tr.effectiveConnectionHv, equals('GIB'));
      expect(tr.effectiveConnectionLv, equals('Oil Cable Box'));
      expect(tr.effectiveConnectionTv, equals('Outdoor Bushings')); // 380/132/13.8 (3-winding)
    });

    test('Ayban T601 retrieves Air Bushing for HV and Air Bushing for LV', () {
      final sub = NationalGridData.substations.firstWhere((s) => s.name == 'Ayban');
      final tr = sub.transformers.firstWhere((t) => t.number == 'T601');
      expect(tr.effectiveConnectionHv, equals('Air Bushing'));
      expect(tr.effectiveConnectionLv, equals('Air Bushing'));
      expect(tr.effectiveConnectionTv, equals('Outdoor Bushings')); // 132/33/13.8 (3-winding)
    });

    test('KFH T601 retrieves Oil Cable Box for HV and Air Bushing for LV', () {
      final sub = NationalGridData.substations.firstWhere((s) => s.name == 'KFH');
      final tr = sub.transformers.firstWhere((t) => t.number == 'T601');
      expect(tr.effectiveConnectionHv, equals('Oil Cable Box'));
      expect(tr.effectiveConnectionLv, equals('Air Bushing'));
    });
  });
}
