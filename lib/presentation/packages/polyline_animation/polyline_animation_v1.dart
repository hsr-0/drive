import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

// استيراد مكتبات الخرائط المجانية
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as ap;

import 'package:ovoride_driver/core/utils/my_color.dart';

class PolylineAnimator {
  final Map<String, Timer> _polylinesTimers = {};

  // مراجع الخطوط الخاصة بـ MapLibre (أندرويد)
  ml.Line? _mlBorderLine;
  ml.Line? _mlBgLine;
  ml.Line? _mlAnimatedLine;

  void animatePolyline({
    required String id,
    required Color color,
    required Color backgroundColor,
    required Function updateUI,
    // معطيات خاصة بالآيفون (Apple Maps)
    List<ap.LatLng>? applePoints,
    Set<ap.Polyline>? applePolylines,
    // معطيات خاصة بالأندرويد (MapLibre)
    List<ml.LatLng>? mapLibrePoints,
    ml.MapLibreMapController? mapLibreController,
  }) async {
    // إلغاء أي أنميشن شغال مسبقاً لنفس الخط
    _polylinesTimers[id]?.cancel();

    if (Platform.isIOS) {
      if (applePoints != null && applePoints.isNotEmpty && applePolylines != null) {
        _animateAppleMaps(id, applePoints, color, backgroundColor, applePolylines, updateUI);
      }
    } else {
      if (mapLibrePoints != null && mapLibrePoints.isNotEmpty && mapLibreController != null) {
        _animateMapLibre(id, mapLibrePoints, color, backgroundColor, mapLibreController, updateUI);
      }
    }
  }

  // =========================================================================
  // 1. أنميشن الآيفون (Apple Maps)
  // =========================================================================
  void _animateAppleMaps(
      String id,
      List<ap.LatLng> points,
      Color color,
      Color bg,
      Set<ap.Polyline> polylines,
      Function updateUI) {

    // مسح الخطوط القديمة
    polylines.removeWhere((p) => p.polylineId.value.startsWith(id));

    // 1. إنشاء خط الحدود
    polylines.add(ap.Polyline(
      polylineId: ap.PolylineId('${id}_border'),
      points: points,
      color: MyColor.primaryColor,
      width: 7,
      jointType: ap.JointType.round,
    ));

    // 2. إنشاء خط الخلفية
    polylines.add(ap.Polyline(
      polylineId: ap.PolylineId('${id}_bg'),
      points: points,
      color: bg,
      width: 5,
      jointType: ap.JointType.round,
    ));

    int forwardIndex = 0;
    int backwardIndex = -1;
    List<ap.LatLng> currentPoints = [];

    Timer timer = Timer.periodic(const Duration(milliseconds: 100), (Timer timer) {
      if (forwardIndex < points.length) {
        currentPoints.add(points[forwardIndex]);
        forwardIndex++;
      }

      if (forwardIndex > points.length / 2 && backwardIndex < forwardIndex - 1) {
        backwardIndex = (backwardIndex == -1) ? 0 : backwardIndex;
        if (backwardIndex < currentPoints.length) {
          currentPoints.removeAt(0);
          backwardIndex++;
        }
      }

      if (backwardIndex >= points.length - 1 || (currentPoints.isEmpty && forwardIndex >= points.length)) {
        forwardIndex = 0;
        backwardIndex = -1;
        currentPoints = [];
      }

      // تحديث الخط المتحرك
      polylines.removeWhere((p) => p.polylineId.value == '${id}_animated');
      polylines.add(ap.Polyline(
        polylineId: ap.PolylineId('${id}_animated'),
        points: List.from(currentPoints),
        color: color,
        width: 5,
        jointType: ap.JointType.round,
      ));

      updateUI();
    });

    _polylinesTimers[id] = timer;
  }

  // =========================================================================
  // 2. أنميشن الأندرويد (MapLibre / OpenStreetMap)
  // =========================================================================
  void _animateMapLibre(
      String id,
      List<ml.LatLng> points,
      Color color,
      Color bg,
      ml.MapLibreMapController controller,
      Function updateUI) async {

    // مسح الخطوط القديمة إن وجدت
    if (_mlBorderLine != null) await controller.removeLine(_mlBorderLine!);
    if (_mlBgLine != null) await controller.removeLine(_mlBgLine!);
    if (_mlAnimatedLine != null) await controller.removeLine(_mlAnimatedLine!);

    // تحويل الألوان لصيغة HEX المدعومة في MapLibre (#RRGGBB)
    String hexBorder = '#${MyColor.primaryColor.value.toRadixString(16).substring(2, 8).padLeft(6, '0')}';
    String hexBg = '#${bg.value.toRadixString(16).substring(2, 8).padLeft(6, '0')}';
    String hexAnim = '#${color.value.toRadixString(16).substring(2, 8).padLeft(6, '0')}';

    // 1. إنشاء خط الحدود
    _mlBorderLine = await controller.addLine(ml.LineOptions(
      geometry: points,
      lineColor: hexBorder,
      lineWidth: 7.0,
      lineJoin: "round",
    ));

    // 2. إنشاء خط الخلفية
    _mlBgLine = await controller.addLine(ml.LineOptions(
      geometry: points,
      lineColor: hexBg,
      lineWidth: 5.0,
      lineJoin: "round",
    ));

    // 3. الخط المتحرك (يبدأ فارغاً)
    _mlAnimatedLine = await controller.addLine(ml.LineOptions(
      geometry: [],
      lineColor: hexAnim,
      lineWidth: 5.0,
      lineJoin: "round",
    ));

    int forwardIndex = 0;
    int backwardIndex = -1;
    List<ml.LatLng> currentPoints = [];

    Timer timer = Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {
      if (forwardIndex < points.length) {
        currentPoints.add(points[forwardIndex]);
        forwardIndex++;
      }

      if (forwardIndex > points.length / 2 && backwardIndex < forwardIndex - 1) {
        backwardIndex = (backwardIndex == -1) ? 0 : backwardIndex;
        if (backwardIndex < currentPoints.length) {
          currentPoints.removeAt(0);
          backwardIndex++;
        }
      }

      if (backwardIndex >= points.length - 1 || (currentPoints.isEmpty && forwardIndex >= points.length)) {
        forwardIndex = 0;
        backwardIndex = -1;
        currentPoints = [];
      }

      // تحديث إحداثيات الخط المتحرك مباشرة في الكنترولر (Imperative)
      if (_mlAnimatedLine != null) {
        await controller.updateLine(
            _mlAnimatedLine!,
            ml.LineOptions(geometry: currentPoints)
        );
      }
    });

    _polylinesTimers[id] = timer;
  }

  void dispose() {
    _polylinesTimers.forEach((id, timer) => timer.cancel());
    _polylinesTimers.clear();
  }
}