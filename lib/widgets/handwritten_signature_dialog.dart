import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A modal dialog that allows users to draw a signature with their finger.
/// Provides a "Reset" (إعادة تعيين) button and a "Confirm" (تأكيد) button.
/// Returns the rendered PNG bytes as [Uint8List] on confirmation.
class HandwrittenSignatureDialog extends StatefulWidget {
  final bool isDark;

  const HandwrittenSignatureDialog({
    super.key,
    this.isDark = false,
  });

  static Future<Uint8List?> show(BuildContext context, {bool isDark = false}) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HandwrittenSignatureDialog(isDark: isDark),
    );
  }

  @override
  State<HandwrittenSignatureDialog> createState() =>
      _HandwrittenSignatureDialogState();
}

class _HandwrittenSignatureDialogState
    extends State<HandwrittenSignatureDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  final GlobalKey _canvasKey = GlobalKey();

  void _resetSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  Future<void> _confirmSignature() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'يرجى رسم التوقيع بإصبعك أولاً قبل التأكيد',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(340, 190);

    // Calculate bounding box of the actual drawn strokes to eliminate empty margins
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in _strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    if (minX.isInfinite || minY.isInfinite || maxX <= minX || maxY <= minY) {
      minX = 0;
      minY = 0;
      maxX = size.width;
      maxY = size.height;
    }

    const padding = 10.0;
    final cropLeft = (minX - padding).clamp(0.0, size.width);
    final cropTop = (minY - padding).clamp(0.0, size.height);
    final cropRight = (maxX + padding).clamp(0.0, size.width);
    final cropBottom = (maxY + padding).clamp(0.0, size.height);

    final cropWidth = (cropRight - cropLeft).clamp(24.0, size.width);
    final cropHeight = (cropBottom - cropTop).clamp(16.0, size.height);

    // Render at 3x resolution for ultra-sharp high-DPI signature in PDF and UI
    const scale = 3.0;
    final width = cropWidth * scale;
    final height = cropHeight * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.scale(scale, scale);
    canvas.translate(-cropLeft, -cropTop);

    final paint = Paint()
      ..color = const Color(0xFF0F2C59)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          1.8,
          Paint()
            ..color = const Color(0xFF0F2C59)
            ..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();

    if (mounted) {
      Navigator.of(context).pop(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.draw_rounded,
                    color: Color(0xFF1D4ED8),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التوقيع اليدوي بالإصبع',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F2C59),
                        ),
                      ),
                      Text(
                        'Handwritten Signature • وقع داخل المستطيل أدناه',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    size: 22,
                  ),
                  tooltip: 'إغلاق',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Signature Drawing Canvas Area
            Container(
              key: _canvasKey,
              height: 200,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  width: 1.4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    // Dotted baseline guide
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 40,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Row(
                                  children: List.generate(
                                    (constraints.maxWidth / 8).floor(),
                                    (index) => Container(
                                      width: 4,
                                      height: 1.5,
                                      margin: const EdgeInsets.only(right: 4),
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'خط التوقيع / Sign here',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Empty prompt
                    if (_strokes.isEmpty && _currentStroke == null)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gesture_rounded,
                              size: 32,
                              color: isDark
                                  ? Colors.grey.shade600
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ارسم توقيعك هنا بإصبعك',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Sign with your finger here',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey.shade600
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Pan gesture painter
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        setState(() {
                          _currentStroke = [details.localPosition];
                          _strokes.add(_currentStroke!);
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _currentStroke?.add(details.localPosition);
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _currentStroke = null;
                        });
                      },
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _SignaturePainter(
                          strokes: _strokes,
                          strokeColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F2C59),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tool actions (زر إعادة تعيين التوقيع)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetSignature,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text(
                    'إعادة تعيين التوقيع',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
                    backgroundColor: const Color(0xFFFFF1F2).withValues(alpha: isDark ? 0.08 : 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _strokes.isEmpty ? 'المساحة جاهزة للرسم' : 'تم رسم التوقيع بنجاح ✓',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _strokes.isEmpty
                          ? (isDark ? Colors.grey.shade500 : const Color(0xFF64748B))
                          : const Color(0xFF10B981),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            // Bottom Buttons (تأكيد / إلغاء)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _confirmSignature,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text(
                      'تأكيد',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color strokeColor;

  _SignaturePainter({
    required this.strokes,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          1.8,
          Paint()
            ..color = strokeColor
            ..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
