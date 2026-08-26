import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';

/// نموذج بيانات معلومات التحديث
class AppUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final String? publishDate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
    this.publishDate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] ?? json['version'] ?? '1.0.0',
      buildNumber: json['build_number'] is int
          ? json['build_number']
          : int.tryParse(json['build_number']?.toString() ?? '1') ?? 1,
      apkUrl: json['apk_url'] ?? json['download_url'] ?? '',
      releaseNotes: json['release_notes'] ?? 'تحسينات عامة وإصلاحات في الأداء.',
      forceUpdate: json['force_update'] ?? false,
      publishDate: json['publish_date'],
    );
  }
}

/// خدمة إدارة وتثبيت التحديثات الداخلية للتطبيق بدون متجر Google Play
class AppUpdateService {
  /// رابط فحص التحديثات المباشر (GitHub Raw version.json)
  static String versionCheckUrl =
      'https://raw.githubusercontent.com/TQAPPS/eforms-releases/refs/heads/main/version.json';

  /// متوافق أيضاً مع التسمية updateInfoUrl
  static String get updateInfoUrl => versionCheckUrl;
  static set updateInfoUrl(String val) => versionCheckUrl = val;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  /// فحص وجود تحديث جديد ومقارنته بالإصدار الحالي
  static Future<AppUpdateInfo?> checkUpdate({String? customUrl}) async {
    try {
      final url = customUrl ?? versionCheckUrl;
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Cache-Control': 'no-cache'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawData = response.data;
        if (rawData is String) {
          rawData = jsonDecode(rawData);
        }

        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData);
          final updateInfo = AppUpdateInfo.fromJson(data);
          final packageInfo = await PackageInfo.fromPlatform();

          final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
          final currentVersion = packageInfo.version;

          final hasNewBuild = updateInfo.buildNumber > currentBuildNumber;
          final hasNewVersion = _isVersionGreaterThan(
            updateInfo.latestVersion,
            currentVersion,
          );

          if (hasNewBuild || hasNewVersion) {
            return updateInfo;
          }
        }
      }
    } catch (e) {
      debugPrint('AppUpdateService.checkUpdate Error: $e');
    }
    return null;
  }

  /// فحص التحديث وعرض النافذة المنبثقة تلقائياً
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool showNoUpdateMessage = false,
  }) async {
    // التأكد من أن النظام يعمل على Android فقط للتحديث المباشر
    if (!Platform.isAndroid) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final updateInfo = await checkUpdate();

      if (!context.mounted) return;

      if (updateInfo != null && updateInfo.apkUrl.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: !updateInfo.forceUpdate,
          builder: (dialogContext) => PopScope(
            canPop: !updateInfo.forceUpdate,
            child: UpdateDialog(
              updateInfo: updateInfo,
              currentVersion: packageInfo.version,
              currentBuild: packageInfo.buildNumber,
            ),
          ),
        );
      } else if (showNoUpdateMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'أنت تستخدم أحدث إصدار متاح حالياً (${packageInfo.version}+${packageInfo.buildNumber})',
            ),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    } catch (e) {
      if (showNoUpdateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر التحقق من التحديثات: $e'),
            backgroundColor: AppTheme.roseRed,
          ),
        );
      }
    }
  }

  /// مقارنة إصدارين سيمانتيكياً (Semantic Versioning)
  static bool _isVersionGreaterThan(String newVersion, String currentVersion) {
    try {
      final newParts = newVersion
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final currentParts = currentVersion
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      for (int i = 0; i < 3; i++) {
        final n = i < newParts.length ? newParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (n > c) return true;
        if (n < c) return false;
      }
    } catch (_) {}
    return false;
  }
}

/// نافذة الحوار المخصصة لعرض تفاصيل التحديث وتحميله
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final String currentVersion;
  final String currentBuild;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    required this.currentBuild,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _downloadedSize = '0 MB';
  String _totalSize = '...';
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    _cancelToken = CancelToken();

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/update_${widget.updateInfo.latestVersion}_${widget.updateInfo.buildNumber}.apk';

      // حذف الملف القديم إن وجد مسبقاً
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        widget.updateInfo.apkUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _downloadedSize =
                  '${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
              _totalSize = '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _progress = 1.0;
      });

      // فتح وتشغيل مثبت الحزم لنظام الأندرويد مباشرة
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        setState(() {
          _errorMessage =
              'يرجى السماح للتطبيق بتثبيت التطبيقات من مصادر غير معروفة: ${result.message}';
          _isDownloading = false;
        });
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'فشل تحميل التحديث: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'حدث خطأ أثناء التحديث: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.darkCardBg : Colors.white,
      elevation: 12,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // أيقونة التحديث ورأس النافذة
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // عنوان التحديث
            Text(
              'تحديث جديد متوفر!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // بطاقة مقارنة الإصدارات
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface
                    : AppTheme.primaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'الإصدار الحالي',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.currentVersion}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_back_rounded, size: 20, color: primaryColor),
                  Column(
                    children: [
                      Text(
                        'الإصدار الجديد',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.updateInfo.latestVersion}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // قسم الملاحظات والجديد في التحديث
            Text(
              'ما الجديد في هذا التحديث:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface.withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFEDF2F7),
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.updateInfo.releaseNotes,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // حالة التحميل أو الأزرار
            if (_isDownloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جاري تحميل التحديث...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? AppTheme.darkBorder
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_downloadedSize / $_totalSize',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.roseRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.roseRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.roseRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // أزرار التحكم
              Row(
                children: [
                  if (!widget.updateInfo.forceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('لاحقاً'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: widget.updateInfo.forceUpdate ? 1 : 2,
                    child: ElevatedButton.icon(
                      onPressed: _startDownloadAndInstall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        _errorMessage != null ? 'إعادة المحاولة' : 'تحديث الآن',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
