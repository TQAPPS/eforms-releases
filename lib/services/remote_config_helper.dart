import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfigHelper {
  // 1. ضع هنا رابط الـ Raw Gist الذي نسخته من جيت هب
  static const String _configRawUrl =
      'https://gist.githubusercontent.com/TQAPPS/d79cd611f978cd2863e51613446c2bd2/raw/config.json';

  // 2. رابط Power Automate الحالي (كرابط احتياطي يعمل التطبيق به لو فُتح أول مرة دون إنترنت)
  static const String fallbackUrl =
      'https://default22e3bb8f9a9648bd99f8f652d83d90.4c.environment.api.powerplatform.com:443/powerautomate/automations/direct/cu/26/workflows/5a4347a8df1545b5b8afddeb826228b4/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=bn2jhr1-FimpnfrrEs8XnS5oWgPepBaJiSRpZAf7re4';

  static const String _storageKey = 'cached_onedrive_flow_url';

  /// دالة تحديث الرابط من السحابة وتخزينه في الهاتف
  static Future<void> updateConfig() async {
    try {
      final uri = Uri.parse(_configRawUrl).replace(
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? newUrl = data['onedrive_flow_url'];

        // التأكد من أن الرابط يحتوي على مفتاح التوقيع قبل اعتماده
        if (newUrl != null &&
            newUrl.trim().isNotEmpty &&
            newUrl.contains('sig=')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_storageKey, newUrl.trim());
          debugPrint('تم تحديث رابط الرفع بنجاح: $newUrl');
        }
      }
    } catch (e) {
      // في حال عدم توفر اتصال، يواصل التطبيق عمله دون انهيار
      debugPrint(
        'تعذر جلب الرابط عن بعد، سيتم استخدام الرابط المحفوظ محلياً: $e',
      );
    }
  }

  /// دالة استرجاع الرابط لاستخدامه أثناء الرفع مع حماية كاملة من أي استثناء
  static Future<String> getEffectiveUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_storageKey);
      if (cached != null && cached.trim().isNotEmpty && cached.contains('sig=')) {
        return cached.trim();
      }
    } catch (e) {
      debugPrint('تعذر قراءة الرابط من SharedPreferences: $e');
    }
    // يرجع الرابط الاحتياطي المضمون
    return fallbackUrl;
  }
}
