import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'remote_config_helper.dart';

class OneDriveService {
  /// دالة رفع النموذج باستخدام كائن File
  static Future<bool> uploadFormPdf({
    required File pdfFile,
    required String formTitle,
    String? fileName,
    String? formId,
    String? employeeName,
    String? formType,
  }) async {
    return uploadPdf(
      pdfFile: pdfFile,
      formTitle: formTitle,
      fileName: fileName,
      formId: formId,
      employeeName: employeeName,
      formType: formType,
    );
  }

  /// دالة رفع ملف الـ PDF إلى ون درايف (باستخدام كائن File)
  static Future<bool> uploadPdf({
    required File pdfFile,
    required String formTitle,
    String? fileName,
    String? formId,
    String? employeeName,
    String? formType,
  }) async {
    try {
      // 1. قراءة محتوى ملف الـ PDF وتحويله إلى Uint8List
      final List<int> bytes = await pdfFile.readAsBytes();
      return await uploadPdfBytes(
        pdfBytes: Uint8List.fromList(bytes),
        formTitle: formTitle,
        fileName: fileName,
        formId: formId,
        employeeName: employeeName,
        formType: formType,
      );
    } catch (e) {
      debugPrint('استثناء أثناء عملية الرفع: $e');
      return false;
    }
  }

  /// دالة رفع ملف الـ PDF إلى ون درايف مباشرة من الذاكرة (Uint8List)
  static Future<bool> uploadPdfBytes({
    required Uint8List pdfBytes,
    required String formTitle,
    String? fileName,
    String? formId,
    String? employeeName,
    String? formType,
  }) async {
    try {
      // 1. جلب الرابط الديناميكي من RemoteConfigHelper
      final String flowUrl = await RemoteConfigHelper.getEffectiveUrl();

      // 2. تحويل محتوى الـ PDF إلى Base64
      final String base64Content = base64Encode(pdfBytes);

      // 3. صياغة اسم للملف لضمان عدم تكراره
      String resolvedFileName;
      if (fileName != null && fileName.trim().isNotEmpty) {
        resolvedFileName = fileName.trim();
        if (!resolvedFileName.toLowerCase().endsWith('.pdf')) {
          resolvedFileName = '$resolvedFileName.pdf';
        }
      } else {
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String safeTitle = formTitle.replaceAll(' ', '_');
        resolvedFileName = '${safeTitle}_$timestamp.pdf';
      }

      // 4. تجهيز بيانات الحقول المطلوبة لتدوينها في ملف Excel السحابي مع قيم احتياطية موثوقة
      final String resolvedFormId = (formId != null && formId.trim().isNotEmpty)
          ? formId.trim()
          : 'WO-${DateTime.now().millisecondsSinceEpoch}';

      final String resolvedEmployeeName =
          (employeeName != null && employeeName.trim().isNotEmpty)
              ? employeeName.trim()
              : 'الفاحص المعتمد';

      final String resolvedFormType =
          (formType != null && formType.trim().isNotEmpty)
              ? formType.trim()
              : formTitle.trim();

      final Map<String, dynamic> payload = {
        'fileName': resolvedFileName,
        'pdfBase64': base64Content,
        'formId': resolvedFormId,
        'employeeName': resolvedEmployeeName,
        'formType': resolvedFormType,
      };

      // 5. إرسال الطلب لـ Power Automate عبر POST
      http.Response response = await http.post(
        Uri.parse(flowUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      // إذا فشل الرد وكان الرابط المستخدم مختلفاً عن الرابط الاحتياطي، نحاول فوراً بالرابط الاحتياطي المضمون
      if (response.statusCode != 200 &&
          response.statusCode != 202 &&
          flowUrl != RemoteConfigHelper.fallbackUrl) {
        debugPrint(
            'فشل الرفع بالرابط المسترجع (${response.statusCode})، جاري المحاولة بالرابط الاحتياطي المباشر...');
        response = await http.post(
          Uri.parse(RemoteConfigHelper.fallbackUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );
      }

      // 6. التحقق من رد السيرفر (كود 200 أو 202)
      if (response.statusCode == 200 || response.statusCode == 202) {
        debugPrint('تم رفع الملف وتدوين بياناته في Excel بنجاح: $resolvedFileName');
        return true;
      } else {
        debugPrint(
            'خطأ في استجابة الخادم: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('استثناء أثناء عملية الرفع: $e');
      return false;
    }
  }
}
