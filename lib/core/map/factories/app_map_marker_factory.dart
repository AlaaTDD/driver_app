import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Centralized marker creation — replaces duplicated marker construction logic
/// in multiple screens.
class AppMapMarkerFactory {
  AppMapMarkerFactory._();

  /// Marker for rider pickup (origin).
  static Marker origin({
    required String id,
    required LatLng position,
  }) =>
      Marker(
        markerId: MarkerId('origin_$id'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        zIndexInt: 1,
      );

  /// Marker for rider destination.
  static Marker destination({
    required String id,
    required LatLng position,
  }) =>
      Marker(
        markerId: MarkerId('dest_$id'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        zIndexInt: 1,
      );

  /// Marker for a driver (car icon).
  static Marker driver({
    required String driverId,
    required LatLng position,
    required BitmapDescriptor icon,
    double rotation = 0,
  }) =>
      Marker(
        markerId: MarkerId('driver_$driverId'),
        position: position,
        icon: icon,
        rotation: rotation,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 2,
      );

  /// Generic custom marker.
  static Marker custom({
    required String id,
    required LatLng position,
    required BitmapDescriptor icon,
    int zIndex = 1,
  }) =>
      Marker(
        markerId: MarkerId(id),
        position: position,
        icon: icon,
        zIndexInt: zIndex,
      );

  /// A labeled route point marker. The label is baked into the bitmap so it is
  /// visible without requiring a Google Maps info window tap.
  static Future<BitmapDescriptor> labeledPin({
    required String label,
    required Color color,
    TextDirection textDirection = TextDirection.ltr,
    IconData icon = Icons.location_on_rounded,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const double scale = 3;
    const double horizontalPadding = 8 * scale;
    const double labelHeight = 22 * scale;
    const double gap = 4 * scale;
    const double pinSize = 24 * scale;
    const double pointerHeight = 6 * scale;
    const double minWidth = 76 * scale;
    const double maxWidth = 132 * scale;

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5 * scale,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: textDirection,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth - horizontalPadding * 2);

    final width = (labelPainter.width + horizontalPadding * 2)
        .clamp(minWidth, maxWidth)
        .toDouble();
    const height = labelHeight + pointerHeight + gap + pinSize;
    final centerX = width / 2;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5 * scale);

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, labelHeight),
      Radius.circular(11 * scale),
    );
    canvas.drawRRect(labelRect.shift(Offset(0, 1.5 * scale)), shadowPaint);

    final labelPaint = Paint()..color = color;
    canvas.drawRRect(labelRect, labelPaint);

    final pointerPath = Path()
      ..moveTo(centerX - 6 * scale, labelHeight - 1)
      ..lineTo(centerX + 6 * scale, labelHeight - 1)
      ..lineTo(centerX, labelHeight + pointerHeight)
      ..close();
    canvas.drawPath(pointerPath.shift(Offset(0, 1.5 * scale)), shadowPaint);
    canvas.drawPath(pointerPath, labelPaint);

    labelPainter.paint(
      canvas,
      Offset(
        (width - labelPainter.width) / 2,
        (labelHeight - labelPainter.height) / 2 + 1,
      ),
    );

    final pinCenter =
        Offset(centerX, labelHeight + pointerHeight + gap + 12 * scale);
    final outerPaint = Paint()..color = color.withValues(alpha: 0.20);
    final innerPaint = Paint()..color = color;
    final whitePaint = Paint()..color = Colors.white;

    canvas.drawCircle(pinCenter, 12 * scale, shadowPaint);
    canvas.drawCircle(pinCenter, 12 * scale, outerPaint);
    canvas.drawCircle(pinCenter, 8 * scale, innerPaint);
    canvas.drawCircle(pinCenter, 3.4 * scale, whitePaint);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 10.5 * scale,
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(centerX - iconPainter.width / 2,
          pinCenter.dy - iconPainter.height / 2 + 0.5 * scale),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.bytes(bytes, imagePixelRatio: scale);
  }

  /// Load a car icon from assets — one-liner replaces the 15+ line pattern
  /// duplicated across home screens.
  static Future<BitmapDescriptor> loadCarIcon({
    String assetPath = 'assets/images/carr.png',
    int targetWidth = 40,
  }) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec =
        await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
    final frame = await codec.getNextFrame();
    final pngBytes =
        (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
    return BitmapDescriptor.bytes(pngBytes);
  }
}
