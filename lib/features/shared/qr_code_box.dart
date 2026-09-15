import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// A QR code on a guaranteed-white background — scanners need real
/// contrast, which dark mode's dark background would otherwise break.
///
/// Rendered with a plain [CustomPainter] straight from `package:qr` (the
/// low-level matrix generator), rather than through the higher-level
/// `qr_flutter` widget package: that package's own bundled semantics
/// handling was observed to crash (`!semantics.parentDataDirty`) when
/// rebuilt inside an animating dialog/route transition on a recent Flutter
/// version, and it hasn't been updated since 2023.
class QrCodeBox extends StatelessWidget {
  const QrCodeBox({super.key, required this.data, this.size = 220});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(
      payload: QrPayload.fromString(data),
      errorCorrectLevel: QrErrorCorrectLevel.low,
    ));

    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _QrPainter(image)),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final moduleSize = size.width / image.moduleCount;
    final paint = Paint()..color = Colors.black;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(
                col * moduleSize, row * moduleSize, moduleSize, moduleSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
