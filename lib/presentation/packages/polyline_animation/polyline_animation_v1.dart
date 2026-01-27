import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; //
import 'package:ovoride_driver/core/utils/my_color.dart';

class PolylineAnimator {
  final Map<String, Timer> _polylinesTimers = {};

  void animatePolyline({
    required List<Position> points,
    required String id,
    required Color color,
    required Color backgroundColor,
    required PolylineAnnotationManager? manager,
    required Function updateUI,
  }) async {
    if (manager == null || points.isEmpty) return;

    _polylinesTimers[id]?.cancel();

    // 1. إنشاء خط الحدود (الطبقة السفلية - أعرض طبقة)
    PolylineAnnotation borderLine = await manager.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: points),
      lineColor: MyColor.primaryColor.value, //
      lineWidth: 7.0, // أعرض من البقية ليعمل كإطار
      lineJoin: LineJoin.ROUND,
    ));

    // 2. إنشاء خط الخلفية (الطبقة الوسطى)
    PolylineAnnotation bgLine = await manager.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: points),
      lineColor: backgroundColor.value, //
      lineWidth: 5.0,
      lineJoin: LineJoin.ROUND,
    ));

    // 3. إنشاء الخط المتحرك (الطبقة العلوية - الأنيكيشن)
    PolylineAnnotation animatedLine = await manager.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: []),
      lineColor: color.value, //
      lineWidth: 5.0,
      lineJoin: LineJoin.ROUND,
    ));

    int forwardIndex = 0;
    int backwardIndex = -1;
    List<Position> currentPoints = [];

    //

    Timer timer = Timer.periodic(const Duration(milliseconds: 100), (Timer timer) async {

      if (forwardIndex < points.length) {
        currentPoints.add(points[forwardIndex]);
        forwardIndex++;
      }

      // منطق الحذف التدريجي من الخلف (نفس ميزة كود جوجل القديم)
      if (forwardIndex > points.length / 2 && backwardIndex < forwardIndex - 1) {
        backwardIndex = (backwardIndex == -1) ? 0 : backwardIndex;
        if (backwardIndex < currentPoints.length) {
          currentPoints.removeAt(0);
          backwardIndex++;
        }
      }

      // إعادة التصفير عند اكتمال المسار
      if (backwardIndex >= points.length - 1 || currentPoints.isEmpty && forwardIndex >= points.length) {
        forwardIndex = 0;
        backwardIndex = -1;
        currentPoints = [];
      }

      // تحديث الجيومتري للخط المتحرك في ماب بوكس
      animatedLine.geometry = LineString(coordinates: currentPoints);
      await manager.update(animatedLine);

      updateUI();
    });

    _polylinesTimers[id] = timer;
  }

  void dispose() {
    _polylinesTimers.forEach((id, timer) => timer.cancel());
    _polylinesTimers.clear();
  }
}