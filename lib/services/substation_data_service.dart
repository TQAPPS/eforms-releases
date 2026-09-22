import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/substation_model.dart';

/// نتيجة عملية المزامنة أو استيراد البيانات
class SyncResult {
  final bool isSuccess;
  final String message;
  final int substationsCount;
  final int transformersCount;

  const SyncResult({
    required this.isSuccess,
    required this.message,
    this.substationsCount = 0,
    this.transformersCount = 0,
  });

  factory SyncResult.success({
    required int substationsCount,
    required int transformersCount,
    String? message,
  }) {
    return SyncResult(
      isSuccess: true,
      substationsCount: substationsCount,
      transformersCount: transformersCount,
      message: message ??
          'تم تحديث البيانات بنجاح: $substationsCount محطة و $transformersCount محول.',
    );
  }

  factory SyncResult.error(String message) {
    return SyncResult(
      isSuccess: false,
      message: message,
    );
  }
}

/// خدمة إدارة وتحديث بيانات المحطات والمحولات
/// تدعم المزامنة التلقائية من Google Sheets، استيراد ملفات CSV المحلية، والتخزين المحلي Offline
class SubstationDataService {
  /// رابط تصدير Google Sheet CSV المباشر لشيت main form
  static const String defaultSheetCsvUrl =
      'https://docs.google.com/spreadsheets/d/1KEGv5Th6xmG8mZk3cMNazjK2TqBNNKONnaY2GVgiUuc/export?format=csv&gid=1885500567';

  static String sheetCsvUrl = defaultSheetCsvUrl;

  /// Notifier لقائمة المحطات لإعادة بناء الواجهات فور التحديث
  static final ValueNotifier<List<SubstationModel>> substationsNotifier =
      ValueNotifier<List<SubstationModel>>(NationalGridData.defaultSubstations);

  /// حالة المزامنة الحالية (جاري التحديث أم لا)
  static final ValueNotifier<bool> isSyncingNotifier =
      ValueNotifier<bool>(false);

  /// تاريخ ووقت آخر مزامنة ناجحة
  static DateTime? lastSyncTime;

  /// مصدر البيانات الحالي (Google Sheets أونلاين / ملف محلي / مدمجة)
  static String lastSyncSource = 'البيانات المدمجة بالتطبيق';

  static const String _cacheFileName = 'substations_cache.json';
  static const String _metaFileName = 'substations_meta.json';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'text/csv, application/json, text/plain, */*',
        'User-Agent': 'Mozilla/5.0 (compatible; EFormsApp/1.0)',
      },
    ),
  );

  /// تمكين أو تعطيل المزامنة التلقائية عند الإقلاع (مفيد لبيئة الاختبارات)
  static bool isAutoSyncEnabled = true;

  /// مؤقت المزامنة التلقائية الدورية في الخلفية
  static Timer? _autoSyncTimer;

  /// التحقق إن كانت المحطة تتبع لمنطقة جازان
  static bool isJizanRegion(String region) {
    final r = region.trim().toUpperCase();
    return r.contains('JIZAN') ||
        r.contains('JAZAN') ||
        r.contains('جازان') ||
        r.contains('جيزان');
  }

  static Future<void> init() async {
    // التحقق من سلامة البيانات في الذاكرة والتأكد من أنها لمنطقة جازان فقط
    final hasNonJizan = NationalGridData.substations.any((s) => !isJizanRegion(s.region));
    if (hasNonJizan ||
        NationalGridData.substations.any((s) =>
            s.name.toLowerCase().contains('parallel') ||
            s.transformers.length > 20)) {
      NationalGridData.substations = NationalGridData.defaultSubstations;
      substationsNotifier.value = NationalGridData.defaultSubstations;
      lastSyncSource = 'البيانات المدمجة بالتطبيق (منطقة جازان)';
      try {
        final dir = await getApplicationDocumentsDirectory();
        final cacheFile = File('${dir.path}/$_cacheFileName');
        final metaFile = File('${dir.path}/$_metaFileName');
        if (await cacheFile.exists()) await cacheFile.delete();
        if (await metaFile.exists()) await metaFile.delete();
      } catch (_) {}
    }

    try {
      final loaded = await loadFromLocalCache();
      if (!loaded) {
        NationalGridData.substations = NationalGridData.defaultSubstations;
        substationsNotifier.value = NationalGridData.defaultSubstations;
        lastSyncSource = 'البيانات المدمجة بالتطبيق';
      }
    } catch (e) {
      debugPrint('Error loading substation cache: $e');
      NationalGridData.substations = NationalGridData.defaultSubstations;
      substationsNotifier.value = NationalGridData.defaultSubstations;
    }

    if (isAutoSyncEnabled) {
      // 1. تشغيل المزامنة التلقائية الصامتة فور فتح التطبيق
      syncFromOnline(silent: true).catchError((e) {
        debugPrint('Initial background auto-sync failed: $e');
        return SyncResult.error(e.toString());
      });

      // 2. جدولة المزامنة التلقائية الدورية في الخلفية (كل 15 دقيقة) أثناء عمل التطبيق
      _startPeriodicAutoSync();
    }
  }

  /// تشغيل مؤقت المزامنة التلقائية الدورية في الخلفية
  static void _startPeriodicAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (isAutoSyncEnabled) {
        syncFromOnline(silent: true).catchError((e) {
          debugPrint('Periodic background auto-sync failed: $e');
          return SyncResult.error(e.toString());
        });
      }
    });
  }

  /// إيقاف مؤقت المزامنة التلقائية
  static void stopPeriodicAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// مزامنة البيانات تلقائياً من رابط Google Sheets أونلاين
  static Future<SyncResult> syncFromOnline({bool silent = false}) async {
    if (isSyncingNotifier.value) {
      return const SyncResult(
        isSuccess: false,
        message: 'جاري التحديث بالفعل، يرجى الانتظار...',
      );
    }

    isSyncingNotifier.value = true;

    try {
      final response = await _dio.get<String>(
        sheetCsvUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode != 200 ||
          response.data == null ||
          response.data!.trim().isEmpty) {
        throw Exception('فشل في جلب البيانات من الخادم (رمز ${response.statusCode})');
      }

      final csvContent = response.data!;
      final parseResult = parseCsvData(csvContent);

      if (!parseResult.isSuccess || parseResult.substations.isEmpty) {
        throw Exception(
            parseResult.errorMessage ?? 'لم يتم العثور على بيانات محطات صالحة في الملف.');
      }

      // تصفية المحطات لتقتصر على منطقة جازان فقط
      final jizanSubstations = parseResult.substations
          .where((s) => isJizanRegion(s.region))
          .toList();

      if (jizanSubstations.isEmpty) {
        debugPrint(
            'Online sync: Sheet contains no Jizan substations. Retaining built-in Jizan list.');
        return const SyncResult(
          isSuccess: false,
          message:
              'الملف المتاح أونلاين لا يحتوي على محطات لمنطقة جازان. تم الإبقاء على قائمة محطات جازان المعتمدة.',
        );
      }

      // تطبيق البيانات وتحديث الحالة
      applySubstations(
        jizanSubstations,
        source: 'Google Sheets (أونلاين)',
      );

      // حفظ الكاش محلياً
      await _saveToLocalCache(jizanSubstations);

      final totalTransformers = jizanSubstations.fold<int>(
        0,
        (sum, s) => sum + s.transformers.length,
      );

      return SyncResult.success(
        substationsCount: jizanSubstations.length,
        transformersCount: totalTransformers,
      );
    } catch (e) {
      debugPrint('Online sync error: $e');
      return SyncResult.error('تعذر تحديث البيانات: ${e.toString()}');
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// تطبيق قائمة المحطات الجديدة في الذاكرة وإشعار الواجهات
  static void applySubstations(List<SubstationModel> list, {required String source}) {
    NationalGridData.substations = list;
    substationsNotifier.value = list;
    lastSyncTime = DateTime.now();
    lastSyncSource = source;
  }

  /// استعادة البيانات المدمجة الافتراضية
  static Future<void> resetToDefault() async {
    applySubstations(
      NationalGridData.defaultSubstations,
      source: 'البيانات المدمجة بالتطبيق',
    );
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/$_cacheFileName');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      final metaFile = File('${dir.path}/$_metaFileName');
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// تحليل نص الـ CSV واستخراج المحطات والمحولات
  static ({bool isSuccess, List<SubstationModel> substations, String? errorMessage})
      parseCsvData(String csvString) {
    try {
      final rows = const CsvDecoder().convert(csvString);

      if (rows.isEmpty) {
        return (
          isSuccess: false,
          substations: <SubstationModel>[],
          errorMessage: 'ملف البيانات فارغ.',
        );
      }

      // البحث عن صف الترويسة (Header)
      int headerRowIdx = -1;
      int subCol = 2;
      int trfCol = 3;
      int voltCol = 4;
      int serialCol = 6;
      int mfrCol = 8;
      int yearCol = 9;
      int mvaCol = 11;
      int hvCol = 12;
      int lvCol = 13;
      int tvCol = 14;
      int areaCol = 1;

      bool foundSub = false;
      bool foundTrf = false;

      for (int i = 0; i < rows.length && i < 15; i++) {
        final row = rows[i];
        for (int j = 0; j < row.length; j++) {
          final cell = row[j].toString().trim().toLowerCase();
          if (!foundSub &&
              (cell == 'substation' ||
                  cell.startsWith('substation ') ||
                  cell == 'substation name' ||
                  cell == 'اسم المحطة' ||
                  cell == 'المحطة') &&
              !cell.contains('parallel') &&
              !cell.contains('operation') &&
              !cell.contains('status')) {
            subCol = j;
            foundSub = true;
            headerRowIdx = i;
          } else if (!foundTrf &&
              (cell == 'transformer' ||
                  cell.contains('transformer number') ||
                  cell.contains('transformer no') ||
                  cell == 'رقم المحول' ||
                  cell == 'المحول') &&
              !cell.contains('manufacture') &&
              !cell.contains('parallel') &&
              !cell.contains('operation')) {
            trfCol = j;
            foundTrf = true;
          } else if (cell.contains('voltage level') || cell == 'voltage') {
            voltCol = j;
          } else if (cell.contains('serial number') || cell == 'serial') {
            serialCol = j;
          } else if (cell.contains('manufacturer') && !cell.contains('oltc')) {
            mfrCol = j;
          } else if (cell.contains('year of manufacture') || cell == 'year') {
            yearCol = j;
          } else if (cell.contains('rating (mva)') || cell == 'rating' || cell.contains('mva')) {
            mvaCol = j;
          } else if (cell.contains('connection hv')) {
            hvCol = j;
          } else if (cell.contains('connection lv')) {
            lvCol = j;
          } else if (cell.contains('connection tv')) {
            tvCol = j;
          } else if (cell == 'area' || cell.contains('region')) {
            areaCol = j;
          }
        }
        if (foundSub && foundTrf) break;
      }

      final startIdx = headerRowIdx != -1 ? headerRowIdx + 1 : 0;
      final Map<String, ({
        String name,
        String region,
        List<TransformerInfo> transformers,
      })> groups = {};

      String currentArea = 'SOD';
      String currentSubName = '';

      for (int i = startIdx; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        String getCell(int col) {
          if (col >= 0 && col < row.length) {
            return row[col].toString().trim();
          }
          return '';
        }

        final areaVal = getCell(areaCol);
        if (areaVal.isNotEmpty && !areaVal.toLowerCase().contains('area')) {
          currentArea = areaVal;
        }

        final subVal = getCell(subCol);
        if (subVal.isNotEmpty &&
            subVal.toLowerCase() != 'substation' &&
            !subVal.toLowerCase().startsWith('substation ') &&
            !subVal.toLowerCase().contains('parallel') &&
            !subVal.toLowerCase().contains('operation')) {
          currentSubName = subVal;
        }

        if (currentSubName.isEmpty) {
          continue;
        }

        final trfNum = getCell(trfCol);
        if (trfNum.isEmpty ||
            trfNum.toLowerCase().contains('transformer') ||
            trfNum.toLowerCase() == 'no.' ||
            trfNum.toLowerCase() == 'number') {
          continue;
        }

        final volt = getCell(voltCol);
        final serial = getCell(serialCol);
        final mfr = getCell(mfrCol);
        final year = getCell(yearCol);
        final mva = getCell(mvaCol);
        final hv = getCell(hvCol);
        final lv = getCell(lvCol);
        final tv = getCell(tvCol);

        final trf = TransformerInfo(
          number: trfNum,
          voltage: volt.isNotEmpty ? volt : '132/13.8 Kv',
          serial: serial.isNotEmpty ? serial : null,
          manufacturer: mfr.isNotEmpty ? mfr : null,
          mva: mva.isNotEmpty ? mva : null,
          yearManufacture: year.isNotEmpty ? year : null,
          connectionHv: hv.isNotEmpty ? hv : null,
          connectionLv: lv.isNotEmpty ? lv : null,
          connectionTv: tv.isNotEmpty ? tv : null,
        );

        if (!groups.containsKey(currentSubName)) {
          groups[currentSubName] = (
            name: currentSubName,
            region: currentArea,
            transformers: <TransformerInfo>[trf],
          );
        } else {
          // منع تكرار نفس رقم المحول داخل المحطة الواحدة
          final existing = groups[currentSubName]!.transformers;
          if (!existing.any((t) => t.number.trim().toUpperCase() == trfNum.trim().toUpperCase())) {
            existing.add(trf);
          }
        }
      }

      if (groups.isEmpty) {
        return (
          isSuccess: false,
          substations: <SubstationModel>[],
          errorMessage: 'لم يتم العثور على صفوف محطات صحيحة.',
        );
      }

      int subIdCounter = 1;
      final resultList = <SubstationModel>[];

      for (final entry in groups.entries) {
        resultList.add(
          SubstationModel(
            id: 'sub_$subIdCounter',
            name: entry.value.name,
            region: entry.value.region,
            division: 'SOD / Southern Operating Division',
            department: 'Substation Maintenance Dept',
            transformers: entry.value.transformers,
            auxTransformers: const [],
          ),
        );
        subIdCounter++;
      }

      return (
        isSuccess: true,
        substations: resultList,
        errorMessage: null,
      );
    } catch (e) {
      return (
        isSuccess: false,
        substations: <SubstationModel>[],
        errorMessage: 'خطأ أثناء تحليل ملف CSV: $e',
      );
    }
  }

  /// حفظ البيانات في ملف الكاش المحلي
  static Future<void> _saveToLocalCache(List<SubstationModel> list) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/$_cacheFileName');
      final metaFile = File('${dir.path}/$_metaFileName');

      final jsonList = list.map((s) => s.toJson()).toList();
      await cacheFile.writeAsString(jsonEncode(jsonList), flush: true);

      final meta = {
        'lastSyncTime': (lastSyncTime ?? DateTime.now()).toIso8601String(),
        'lastSyncSource': lastSyncSource,
        'count': list.length,
      };
      await metaFile.writeAsString(jsonEncode(meta), flush: true);
    } catch (e) {
      debugPrint('Error saving to cache: $e');
    }
  }

  /// تحميل البيانات من ملف الكاش المحلي (إن وجد)
  static Future<bool> loadFromLocalCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/$_cacheFileName');
      final metaFile = File('${dir.path}/$_metaFileName');

      if (!await cacheFile.exists()) {
        return false;
      }

      final content = await cacheFile.readAsString();
      final dynamic decoded = jsonDecode(content);

      if (decoded is List && decoded.isNotEmpty) {
        final list = decoded
            .map((e) => SubstationModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        // التحقق من أن جميع محطات الكاش تتبع منطقة جازان حصراً وخلوها من التلف
        final hasNonJizan = list.any((s) => !isJizanRegion(s.region));
        final hasCorruptedData = hasNonJizan ||
            list.any((s) =>
                s.name.toLowerCase().contains('parallel') ||
                s.name.toLowerCase().contains('operation') ||
                s.transformers.length > 20);

        if (hasCorruptedData) {
          debugPrint('Detected non-Jizan or corrupted substation cache. Deleting cache files...');
          if (await cacheFile.exists()) await cacheFile.delete();
          if (await metaFile.exists()) await metaFile.delete();
          return false;
        }

        String source = 'الكاش المحلي (Offline)';
        DateTime? syncTime;

        if (await metaFile.exists()) {
          try {
            final metaContent = await metaFile.readAsString();
            final metaMap = jsonDecode(metaContent) as Map<String, dynamic>;
            if (metaMap['lastSyncSource'] != null) {
              source = '${metaMap['lastSyncSource']} (محلي)';
            }
            if (metaMap['lastSyncTime'] != null) {
              syncTime = DateTime.tryParse(metaMap['lastSyncTime'].toString());
            }
          } catch (_) {}
        }

        NationalGridData.substations = list;
        substationsNotifier.value = list;
        lastSyncSource = source;
        lastSyncTime = syncTime;

        debugPrint('Loaded ${list.length} substations from local cache.');
        return true;
      }
    } catch (e) {
      debugPrint('Error reading local cache: $e');
    }
    return false;
  }
}
