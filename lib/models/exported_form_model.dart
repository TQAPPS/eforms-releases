import 'package:intl/intl.dart';

/// نموذج بيانات النموذج المصدّر والمحفوظ على Google Drive أو محلياً
class ExportedFormModel {
  final String id;
  final String fileName;
  final String substation;
  final String equipment;
  final String formType;
  final String technician;
  final String? notes;
  final String driveUrl;
  final DateTime exportedAt;
  final int? fileSizeBytes;
  final String? localFilePath;

  const ExportedFormModel({
    required this.id,
    required this.fileName,
    required this.substation,
    required this.equipment,
    required this.formType,
    required this.technician,
    this.notes,
    required this.driveUrl,
    required this.exportedAt,
    this.fileSizeBytes,
    this.localFilePath,
  });

  /// استخراج معرّف الملف (File ID) من رابط Google Drive
  String? get driveFileId {
    if (driveUrl.isEmpty) return null;

    // نمط 1: https://drive.google.com/file/d/FILE_ID/view...
    final fileMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(driveUrl);
    if (fileMatch != null) {
      return fileMatch.group(1);
    }

    // نمط 2: https://drive.google.com/open?id=FILE_ID أو ?id=FILE_ID
    final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(driveUrl);
    if (idMatch != null) {
      return idMatch.group(1);
    }

    return null;
  }

  /// رابط التنزيل المباشر من Google Drive
  String get directDownloadUrl {
    final fileId = driveFileId;
    if (fileId != null && fileId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    return driveUrl;
  }

  /// تاريخ التصدير المنسق باللغة العربية
  String get formattedDate {
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(exportedAt);
  }

  /// حجم الملف بتنسيق مقروء (كيلوبايت / ميجابايت)
  String get formattedFileSize {
    if (fileSizeBytes == null || fileSizeBytes == 0) return '';
    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// اسم النموذج المعتمد المستخدم:
  /// - Power Transformer Detailed Monthly Inspection
  /// - Checklist for Substation Power Transformer
  /// - Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection
  String get canonicalFormTitle {
    final type = formType.trim().toLowerCase();
    final name = fileName.trim().toLowerCase();

    // 1. Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection
    if (type.contains('annual') ||
        type.contains('سنوي') ||
        type.contains('mineral oil') ||
        type.contains('reactors') ||
        name.contains('annual') ||
        name.contains('سنوي')) {
      return 'Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection';
    }

    // 2. Checklist for Substation Power Transformer
    if (type.contains('checklist') ||
        type.contains('cl-gm') ||
        name.contains('checklist')) {
      return 'Checklist for Substation Power Transformer';
    }

    // 3. Power Transformer Detailed Monthly Inspection
    if (type.contains('power transformer') ||
        type.contains('detailed monthly') ||
        type.contains('grid maintenance') ||
        type.contains('grid_maintenance') ||
        type.contains('grid') ||
        type.contains('monthly') ||
        type.contains('شهري') ||
        name.contains('monthly') ||
        name.contains('inspection_') ||
        name.contains('شهري')) {
      return 'Power Transformer Detailed Monthly Inspection';
    }

    if (formType.trim().isNotEmpty) {
      return formType;
    }

    return 'Power Transformer Detailed Monthly Inspection';
  }

  /// نوع الفحص المعتمد المعروض في صفحة النماذج المصدرة:
  /// - Power Transformer Detailed Monthly Inspection -> فحص شهري
  /// - Checklist for Substation Power Transformer -> فحص شهري
  /// - Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection -> فحص سنوي
  String get displayInspectionType {
    final canon = canonicalFormTitle;

    // فحص سنوي: Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection
    if (canon == 'Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection' ||
        canon == 'Annual Detail Inspection') {
      return 'فحص سنوي';
    }

    // فحص شهري:
    // Power Transformer Detailed Monthly Inspection أو Checklist for Substation Power Transformer
    if (canon == 'Power Transformer Detailed Monthly Inspection' ||
        canon == 'Checklist for Substation Power Transformer' ||
        canon == 'GRID MAINTENANCE') {
      return 'فحص شهري';
    }

    final type = formType.trim().toLowerCase();
    final name = fileName.trim().toLowerCase();

    if (type.contains('annual') ||
        type.contains('سنوي') ||
        type.contains('mineral oil') ||
        type.contains('reactors') ||
        name.contains('annual') ||
        name.contains('سنوي')) {
      return 'فحص سنوي';
    }

    return 'فحص شهري';
  }

  ExportedFormModel copyWith({
    String? id,
    String? fileName,
    String? substation,
    String? equipment,
    String? formType,
    String? technician,
    String? notes,
    String? driveUrl,
    DateTime? exportedAt,
    int? fileSizeBytes,
    String? localFilePath,
  }) {
    return ExportedFormModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      substation: substation ?? this.substation,
      equipment: equipment ?? this.equipment,
      formType: formType ?? this.formType,
      technician: technician ?? this.technician,
      notes: notes ?? this.notes,
      driveUrl: driveUrl ?? this.driveUrl,
      exportedAt: exportedAt ?? this.exportedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'substation': substation,
      'equipment': equipment,
      'formType': formType,
      'technician': technician,
      'notes': notes,
      'driveUrl': driveUrl,
      'exportedAt': exportedAt.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'localFilePath': localFilePath,
    };
  }

  /// توليد اسم الملف المعتمد عند الرفع على Google Drive:
  /// اسم المحطة_رقم المعدة_نوع النموذج.pdf
  static String buildFileName({
    required String substation,
    required String equipment,
    required String formType,
  }) {
    final cleanSub = substation.trim().replaceAll('/', '-').replaceAll('\\', '-');
    final cleanEq = equipment.trim().replaceAll('/', '-').replaceAll('\\', '-');
    final cleanType = formType.trim().replaceAll('/', '-').replaceAll('\\', '-');
    return '${cleanSub}_${cleanEq}_$cleanType.pdf';
  }

  /// استخراج اسم المحطة، رقم المعدة، ونوع النموذج من اسم الملف
  static Map<String, String> parseFromFileName(String rawFileName) {
    var name = rawFileName.trim();
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4).trim();
    }

    String detectedFormType = '';
    final lower = name.toLowerCase();

    if (lower.contains('annual') ||
        lower.contains('سنوي') ||
        lower.contains('mineral oil') ||
        lower.contains('reactors')) {
      detectedFormType =
          'Checklist for Mineral Oil Power Transformers and Reactors Annual Detail Inspection';
    } else if (lower.contains('checklist for substation') ||
        lower.contains('substation power transformer') ||
        (lower.contains('checklist') && !lower.contains('mineral'))) {
      detectedFormType = 'Checklist for Substation Power Transformer';
    } else if (lower.contains('power transformer') ||
        lower.contains('detailed monthly') ||
        lower.contains('monthly') ||
        lower.contains('شهري')) {
      detectedFormType = 'Power Transformer Detailed Monthly Inspection';
    }

    List<String> parts = [];
    if (name.contains(' - ')) {
      parts = name.split(' - ');
    } else if (name.contains('_')) {
      parts = name.split('_');
    }

    String extractedSub = '';
    String extractedEq = '';

    if (parts.length >= 3) {
      extractedSub = parts[0].trim();
      extractedEq = parts[1].trim();
      if (detectedFormType.isEmpty) {
        detectedFormType = parts.sublist(2).join('_').trim();
      }
    } else if (parts.length == 2) {
      extractedSub = parts[0].trim();
      extractedEq = parts[1].trim();
    }

    return {
      'substation': extractedSub,
      'equipment': extractedEq,
      'formType': detectedFormType,
    };
  }

  factory ExportedFormModel.fromJson(Map<String, dynamic> json) {
    final rawFileName = json['fileName']?.toString() ?? 'نموذج.pdf';
    var sub = json['substation']?.toString() ?? '';
    var eq = json['equipment']?.toString() ?? '';
    var type = json['formType']?.toString() ?? '';

    // إذا كانت البيانات غير مكتملة، نستخرجها بدقة من اسم الملف
    if (sub.isEmpty || eq.isEmpty || type.isEmpty || type == 'نموذج فحص') {
      final parsed = parseFromFileName(rawFileName);
      if (sub.isEmpty && parsed['substation']!.isNotEmpty) {
        sub = parsed['substation']!;
      }
      if (eq.isEmpty && parsed['equipment']!.isNotEmpty) {
        eq = parsed['equipment']!;
      }
      if ((type.isEmpty || type == 'نموذج فحص') &&
          parsed['formType']!.isNotEmpty) {
        type = parsed['formType']!;
      }
    }

    final id = json['id']?.toString() ?? json['fileId']?.toString() ?? '';
    final driveUrl = json['driveUrl']?.toString() ??
        json['fileUrl']?.toString() ??
        json['url']?.toString() ??
        '';

    DateTime exportedDate = DateTime.now();
    final rawDate = json['exportedAt'] ?? json['timestamp'] ?? json['date'] ?? json['createdAt'];
    if (rawDate != null) {
      final parsed = DateTime.tryParse(rawDate.toString());
      if (parsed != null) {
        exportedDate = parsed;
      } else {
        try {
          exportedDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(rawDate.toString());
        } catch (_) {}
      }
    }

    final model = ExportedFormModel(
      id: id.isNotEmpty ? id : 'form_${exportedDate.millisecondsSinceEpoch}_${rawFileName.hashCode}',
      fileName: rawFileName,
      substation: sub,
      equipment: eq,
      formType: type.isNotEmpty ? type : 'Power Transformer Detailed Monthly Inspection',
      technician: json['technician']?.toString() ?? 'الفاحص',
      notes: json['notes']?.toString(),
      driveUrl: driveUrl,
      exportedAt: exportedDate,
      fileSizeBytes: json['fileSizeBytes'] is int
          ? json['fileSizeBytes'] as int
          : int.tryParse(json['fileSizeBytes']?.toString() ?? ''),
      localFilePath: json['localFilePath']?.toString(),
    );

    return model.copyWith(formType: model.canonicalFormTitle);
  }
}
