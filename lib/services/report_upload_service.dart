import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../config/app_upload_config.dart';

class ReportUploadResult {
  final bool isSuccess;
  final String message;
  final String? driveFileUrl;
  final String? fileName;
  final Map<String, dynamic>? rawResponse;

  const ReportUploadResult({
    required this.isSuccess,
    required this.message,
    this.driveFileUrl,
    this.fileName,
    this.rawResponse,
  });
}

class ReportUploadService {
  /// Uploads inspection report PDF and metadata to Google Apps Script Web App.
  static Future<ReportUploadResult> uploadInspectionPdf({
    required String substation,
    required String equipment,
    required String formType,
    required String technician,
    String? notes,
    String? fileName,
    required Uint8List pdfBytes,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 45);

    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safeSub = substation.trim().replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '_').replaceAll(' ', '_');
      final safeEq = equipment.trim().replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '_').replaceAll(' ', '_');
      final resolvedFileName = fileName != null && fileName.trim().isNotEmpty
          ? fileName.trim()
          : '${safeSub}_${safeEq}_$timestamp.pdf';

      final pdfBase64 = base64Encode(pdfBytes);

      final payload = {
        'substation': substation.trim(),
        'equipment': equipment.trim(),
        'formType': formType.trim(),
        'technician': technician.trim().isNotEmpty ? technician.trim() : 'Technician',
        'notes': (notes ?? '').trim(),
        'fileName': resolvedFileName,
        'pdfBase64': pdfBase64,
      };

      final url = AppUploadConfig.webAppUrl;
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Accept', 'application/json');
      request.followRedirects = false; // We handle 302 manually to ensure GET method on echo URL
      request.write(jsonEncode(payload));

      final response = await request.close();
      final location = response.headers.value('location');

      String responseBody;
      int finalStatusCode = response.statusCode;

      // Handle Google Apps Script 302 Found redirect to script.googleusercontent.com
      if ((response.statusCode == 302 ||
              response.statusCode == 301 ||
              response.statusCode == 307) &&
          location != null &&
          location.isNotEmpty) {
        final redirectReq = await client.getUrl(Uri.parse(location));
        redirectReq.headers.set('Accept', 'application/json');
        final redirectResp = await redirectReq.close();
        finalStatusCode = redirectResp.statusCode;
        responseBody = await utf8.decoder.bind(redirectResp).join();
      } else {
        responseBody = await utf8.decoder.bind(response).join();
      }

      dynamic data;
      try {
        data = jsonDecode(responseBody);
      } catch (_) {
        data = {'message': responseBody};
      }

      if (data is Map) {
        final status = data['status']?.toString().toLowerCase() ??
            data['result']?.toString().toLowerCase() ??
            '';
        final fileUrl = data['fileUrl']?.toString() ??
            data['url']?.toString() ??
            data['link']?.toString() ??
            data['driveUrl']?.toString();
        final returnedFileName =
            data['fileName']?.toString() ?? resolvedFileName;
        final msg = data['message']?.toString() ??
            'تم رفع الملف وتسجيل البيانات بنجاح في Google Drive';

        if (status == 'success' ||
            status == 'ok' ||
            fileUrl != null ||
            finalStatusCode == 200) {
          return ReportUploadResult(
            isSuccess: true,
            message: msg,
            driveFileUrl: fileUrl,
            fileName: returnedFileName,
            rawResponse: Map<String, dynamic>.from(data),
          );
        } else {
          return ReportUploadResult(
            isSuccess: false,
            message: data['error']?.toString() ??
                data['message']?.toString() ??
                'فشل إرسال التقرير',
            fileName: returnedFileName,
            rawResponse: Map<String, dynamic>.from(data),
          );
        }
      }

      return ReportUploadResult(
        isSuccess: finalStatusCode == 200,
        message: finalStatusCode == 200
            ? 'تم استلام التقرير بنجاح'
            : 'فشل في إرسال التقرير (كود: $finalStatusCode)',
        fileName: resolvedFileName,
      );
    } catch (e) {
      return ReportUploadResult(
        isSuccess: false,
        message: 'حدث خطأ في الاتصال بالخادم: $e',
      );
    } finally {
      client.close();
    }
  }

  /// Displays an executive styled dialog indicating successful upload with Drive link.
  static void showSuccessDialog(
    BuildContext context,
    ReportUploadResult result, {
    String? substation,
    String? equipment,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor:
                isDark ? const Color(0xFF0F2643) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? const Color(0xFF1E40AF) : const Color(0xFF93C5FD),
                width: 1.2,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Success Badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'تم إرسال النموذج بنجاح!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle / message
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),

                // Report Details Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF07172B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E324F)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (substation != null && substation.isNotEmpty)
                        _buildInfoRow('المحطة:', substation, isDark),
                      if (equipment != null && equipment.isNotEmpty)
                        _buildInfoRow('المعدة:', equipment, isDark),
                      if (result.fileName != null)
                        _buildInfoRow('اسم الملف:', result.fileName!, isDark),
                    ],
                  ),
                ),

                if (result.driveFileUrl != null &&
                    result.driveFileUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Drive Link Action Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.driveFileUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF38BDF8),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: result.driveFileUrl!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم نسخ رابط ملف Google Drive'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'نسخ الرابط',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'تم',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildInfoRow(String title, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
