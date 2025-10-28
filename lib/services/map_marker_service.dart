import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Service to create custom map marker icons
class MapMarkerService {
  /// Create a pickup marker icon (green pin shape)
  static Future<Uint8List> createPickupMarker({
    double size = 120,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    // Draw pin shape shadow
    final shadowPath = Path();
    shadowPath.moveTo(size * 0.5 + 2, size * 0.2 + 2); // Top center + shadow offset
    shadowPath.arcToPoint(
      Offset(size * 0.5 + 2, size * 0.8 + 2),
      radius: Radius.circular(size * 0.3),
      clockwise: true,
    );
    shadowPath.lineTo(size * 0.5 + 2, size + 2); // Point to bottom
    shadowPath.close();
    
    paint.color = Colors.black.withOpacity(0.3);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(shadowPath, paint);

    // Draw pin shape
    final path = Path();
    path.moveTo(size * 0.5, size * 0.2); // Top center
    path.arcToPoint(
      Offset(size * 0.5, size * 0.8),
      radius: Radius.circular(size * 0.3),
      clockwise: true,
    );
    path.lineTo(size * 0.5, size); // Point to bottom
    path.close();

    // Green gradient fill
    paint.maskFilter = null;
    paint.shader = ui.Gradient.linear(
      Offset(size * 0.5, size * 0.2),
      Offset(size * 0.5, size),
      [
        const Color(0xFF00FF88), // Neon green
        const Color(0xFF00CC66), // Darker green
      ],
    );
    canvas.drawPath(path, paint);

    // White border
    paint.shader = null;
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.white;
    paint.strokeWidth = 4;
    canvas.drawPath(path, paint);

    // Draw white circle in the pin
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(Offset(size * 0.5, size * 0.45), size * 0.15, paint);

    // Draw store icon
    paint.color = const Color(0xFF00FF88);
    final iconRect = Rect.fromCenter(
      center: Offset(size * 0.5, size * 0.45),
      width: size * 0.2,
      height: size * 0.2,
    );
    
    // Simple store/shop icon (house shape)
    final storePath = Path();
    storePath.moveTo(iconRect.center.dx, iconRect.top);
    storePath.lineTo(iconRect.right, iconRect.center.dy);
    storePath.lineTo(iconRect.right, iconRect.bottom);
    storePath.lineTo(iconRect.left, iconRect.bottom);
    storePath.lineTo(iconRect.left, iconRect.center.dy);
    storePath.close();
    canvas.drawPath(storePath, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), (size + 10).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Create a delivery marker icon (red house pin shape)
  static Future<Uint8List> createDeliveryMarker({
    double size = 120,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    // Draw pin shape shadow
    final shadowPath = Path();
    shadowPath.moveTo(size * 0.5 + 2, size * 0.2 + 2);
    shadowPath.arcToPoint(
      Offset(size * 0.5 + 2, size * 0.8 + 2),
      radius: Radius.circular(size * 0.3),
      clockwise: true,
    );
    shadowPath.lineTo(size * 0.5 + 2, size + 2);
    shadowPath.close();
    
    paint.color = Colors.black.withOpacity(0.3);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(shadowPath, paint);

    // Draw pin shape
    final path = Path();
    path.moveTo(size * 0.5, size * 0.2);
    path.arcToPoint(
      Offset(size * 0.5, size * 0.8),
      radius: Radius.circular(size * 0.3),
      clockwise: true,
    );
    path.lineTo(size * 0.5, size);
    path.close();

    // Red gradient fill
    paint.maskFilter = null;
    paint.shader = ui.Gradient.linear(
      Offset(size * 0.5, size * 0.2),
      Offset(size * 0.5, size),
      [
        const Color(0xFFFF0066), // Neon red
        const Color(0xFFCC0044), // Darker red
      ],
    );
    canvas.drawPath(path, paint);

    // White border
    paint.shader = null;
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.white;
    paint.strokeWidth = 4;
    canvas.drawPath(path, paint);

    // Draw white circle in the pin
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(Offset(size * 0.5, size * 0.45), size * 0.15, paint);

    // Draw home icon
    paint.color = const Color(0xFFFF0066);
    final iconRect = Rect.fromCenter(
      center: Offset(size * 0.5, size * 0.45),
      width: size * 0.18,
      height: size * 0.18,
    );
    
    // Home icon (roof + house)
    final homePath = Path();
    // Roof
    homePath.moveTo(iconRect.center.dx, iconRect.top);
    homePath.lineTo(iconRect.right, iconRect.center.dy - iconRect.height * 0.1);
    homePath.lineTo(iconRect.left, iconRect.center.dy - iconRect.height * 0.1);
    homePath.close();
    canvas.drawPath(homePath, paint);
    
    // House body
    final houseRect = Rect.fromLTRB(
      iconRect.left,
      iconRect.center.dy - iconRect.height * 0.1,
      iconRect.right,
      iconRect.bottom,
    );
    canvas.drawRect(houseRect, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), (size + 10).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Create a driver marker icon (circular with car icon) - when no profile pic
  static Future<Uint8List> createDriverMarker({
    double size = 100,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    final center = Offset(size * 0.5, size * 0.5);
    final radius = size * 0.35;

    // Draw shadow
    paint.color = Colors.black.withOpacity(0.3);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx + 2, center.dy + 2), radius, paint);

    // Draw outer white ring
    paint.maskFilter = null;
    paint.color = Colors.white;
    canvas.drawCircle(center, radius + 6, paint);

    // Draw orange gradient circle
    paint.shader = ui.Gradient.radial(
      center,
      radius,
      [
        const Color(0xFFFF9500), // Bright orange
        const Color(0xFFFF6B00), // Darker orange
      ],
    );
    canvas.drawCircle(center, radius, paint);

    // Draw car icon
    paint.shader = null;
    paint.color = Colors.white;
    
    // Simple car shape
    final carRect = Rect.fromCenter(
      center: center,
      width: size * 0.35,
      height: size * 0.25,
    );
    
    // Car body
    final carBody = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        carRect.left,
        carRect.top + carRect.height * 0.3,
        carRect.right,
        carRect.bottom,
      ),
      Radius.circular(size * 0.02),
    );
    canvas.drawRRect(carBody, paint);
    
    // Car roof
    final carRoof = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        carRect.left + carRect.width * 0.2,
        carRect.top,
        carRect.right - carRect.width * 0.2,
        carRect.top + carRect.height * 0.4,
      ),
      Radius.circular(size * 0.02),
    );
    canvas.drawRRect(carRoof, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Create a circular marker with profile picture and border
  static Future<Uint8List> createProfileMarker({
    required Uint8List profileImage,
    double size = 100,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    final center = Offset(size * 0.5, size * 0.5);
    final radius = size * 0.35;

    // Draw shadow
    paint.color = Colors.black.withOpacity(0.3);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx + 2, center.dy + 2), radius, paint);

    // Draw outer white ring
    paint.maskFilter = null;
    paint.color = Colors.white;
    canvas.drawCircle(center, radius + 6, paint);

    // Draw profile image in circle
    final codec = await ui.instantiateImageCodec(profileImage);
    final frame = await codec.getNextFrame();
    final profileImg = frame.image;
    
    // Clip to circle
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    
    // Draw image
    paintImage(
      canvas: canvas,
      rect: Rect.fromCircle(center: center, radius: radius),
      image: profileImg,
      fit: BoxFit.cover,
    );
    
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
