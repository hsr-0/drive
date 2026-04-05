import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

// استيراد مكتبات الخرائط المجانية (بدل Mapbox)
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as ap;

import 'package:ovoride_driver/core/utils/helper.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';

class RideMapController extends GetxController {
  bool isLoading = false;
  bool isMapReady = false;

  // الإحداثيات
  double pickupLat = 0.0;
  double pickupLng = 0.0;
  double destLat = 0.0;
  double destLng = 0.0;

  // مراجع الخرائط الجديدة
  ml.MapLibreMapController? mapLibreController;
  ap.AppleMapController? appleController;

  // متغيرات مخصصة لخرائط آيفون (تعتمد على State)
  Set<ap.Annotation> appleMarkers = {};
  Set<ap.Polyline> applePolylines = {};

  // متغيرات مخصصة لخرائط أندرويد (MapLibre)
  ml.Symbol? pickupSymbol;
  ml.Symbol? destSymbol;
  ml.Line? routeLine;

  List<ml.LatLng> polylinePointsML = [];
  List<ap.LatLng> polylinePointsAP = [];

  // متغير لمنع تكرار ضبط الكاميرا بشكل لانهائي
  bool _isFittingBounds = false;

  // ===========================================================================
  // 1. إعداد الخريطة
  // ===========================================================================

  // دالة تهيئة خرائط أندرويد
  void onMapLibreCreated(ml.MapLibreMapController controller) {
    print("🎬 [Controller] تم إنشاء خريطة MapLibre (Android)");
    mapLibreController = controller;
    isMapReady = true;
    _drawIfReady();
  }

  // دالة تهيئة خرائط آيفون
  void onAppleMapCreated(ap.AppleMapController controller) {
    print("🎬 [Controller] تم إنشاء خريطة Apple (iOS)");
    appleController = controller;
    isMapReady = true;
    _drawIfReady();
  }

  void loadMap({required double pLat, required double pLng, required double dLat, required double dLng}) {
    print("🗺️ [Controller] تهيئة إحداثيات الرحلة...");
    pickupLat = pLat;
    pickupLng = pLng;
    destLat = dLat;
    destLng = dLng;

    _drawIfReady();
  }

  Future<void> _drawIfReady() async {
    if (!isMapReady || pickupLat == 0.0) return;
    print("🔄 [Controller] الخريطة جاهزة، يتم الرسم الآن...");

    await setCustomMarkerIcon();
    await _drawStaticMarkers();
    await getRouteFromOSRM();
  }

  // ===========================================================================
  // 2. جلب المسار من API مجاني (OSRM بديل Mapbox Directions)
  // ===========================================================================
  Future<void> getRouteFromOSRM() async {
    print("🛰️ [Controller] طلب المسار من خادم OSRM المجاني...");
    isLoading = true;
    update();

    try {
      // OSRM Public API (لا يحتاج Access Token ومجاني بالكامل)
      final String url =
          'https://router.project-osrm.org/route/v1/driving/$pickupLng,$pickupLat;$destLng,$destLat?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          print("✅ [Controller] تم استلام المسار بنجاح");
          final List coords = data['routes'][0]['geometry']['coordinates'];

          polylinePointsML.clear();
          polylinePointsAP.clear();

          // OSRM يُرجع الإحداثيات بصيغة [Lng, Lat]
          for (var c in coords) {
            polylinePointsML.add(ml.LatLng(c[1].toDouble(), c[0].toDouble()));
            polylinePointsAP.add(ap.LatLng(c[1].toDouble(), c[0].toDouble()));
          }

          await _drawPolyline();
          fitPolylineBounds();
        } else {
          print("⚠️ [Controller] لا يوجد مسار متاح بين النقطتين");
        }
      } else {
        print("🔴 [Controller] خطأ في جلب المسار: ${response.statusCode}");
      }
    } catch (e) {
      print('🔴 [Controller] Error fetching route: $e');
    }

    isLoading = false;
    update();
  }

  // ===========================================================================
  // 3. الرسم (الدبابيس والخطوط)
  // ===========================================================================
  Future<void> _drawPolyline() async {
    print("✏️ [Controller] جاري رسم مسار الرحلة...");

    if (Platform.isIOS) {
      applePolylines.clear();
      applePolylines.add(
          ap.Polyline(
            polylineId:  ap.PolylineId('route_line'),
            points: polylinePointsAP,
            color: MyColor.primaryColor,
            width: 5,
            jointType: ap.JointType.round,
          )
      );
      update(); // تحديث الواجهة لخرائط أبل
    } else {
      if (mapLibreController == null) return;

      // مسح الخط القديم إن وجد
      if (routeLine != null) await mapLibreController!.removeLine(routeLine!);

      // تحويل لون التطبيق إلى صيغة HEX لـ MapLibre
      String hexColor = '#${MyColor.primaryColor.value.toRadixString(16).substring(2, 8)}';

      routeLine = await mapLibreController!.addLine(
          ml.LineOptions(
            geometry: polylinePointsML,
            lineColor: hexColor,
            lineWidth: 5.0,
            lineJoin: "round",
          )
      );
    }
  }

  Future<void> _drawStaticMarkers() async {
    print("📌 [Controller] جاري وضع دبابيس الانطلاق والوجهة...");

    if (Platform.isIOS) {
      appleMarkers.clear();
      if (pickupIcon != null) {
        appleMarkers.add(ap.Annotation(
          annotationId:  ap.AnnotationId('pickup_marker'),
          position: ap.LatLng(pickupLat, pickupLng),
          icon: ap.BitmapDescriptor.fromBytes(pickupIcon!),
        ));
      }
      if (destinationIcon != null) {
        appleMarkers.add(ap.Annotation(
          annotationId:  ap.AnnotationId('dest_marker'),
          position: ap.LatLng(destLat, destLng),
          icon: ap.BitmapDescriptor.fromBytes(destinationIcon!),
        ));
      }
      update();
    } else {
      if (mapLibreController == null) return;

      // MapLibre يطلب إضافة الصور للستايل أولاً قبل الاستخدام
      if (pickupIcon != null) {
        await mapLibreController!.addImage('pickup_icon', pickupIcon!);
      }
      if (destinationIcon != null) {
        await mapLibreController!.addImage('dest_icon', destinationIcon!);
      }

      // مسح الدبابيس القديمة إن وجدت
      if (pickupSymbol != null) await mapLibreController!.removeSymbol(pickupSymbol!);
      if (destSymbol != null) await mapLibreController!.removeSymbol(destSymbol!);

      pickupSymbol = await mapLibreController!.addSymbol(ml.SymbolOptions(
        geometry: ml.LatLng(pickupLat, pickupLng),
        iconImage: 'pickup_icon',
        iconSize: 1.0,
        iconAnchor: 'bottom',
      ));

      destSymbol = await mapLibreController!.addSymbol(ml.SymbolOptions(
        geometry: ml.LatLng(destLat, destLng),
        iconImage: 'dest_icon',
        iconSize: 1.0,
        iconAnchor: 'bottom',
      ));
    }
  }

  // ===========================================================================
  // 4. ضبط زوم الكاميرا لاحتواء المسار بالكامل
  // ===========================================================================
  void fitPolylineBounds() {
    if (_isFittingBounds) return;
    _isFittingBounds = true;
    print("🔭 [Controller] جاري ضبط زوم الكاميرا لمرة واحدة...");

    try {
      if (Platform.isIOS && appleController != null && polylinePointsAP.isNotEmpty) {
        _fitAppleMapBounds();
      } else if (!Platform.isIOS && mapLibreController != null && polylinePointsML.isNotEmpty) {
        _fitMapLibreBounds();
      }
    } catch (e) {
      print("🔴 [Controller] خطأ في زوم الكاميرا: $e");
    }

    Future.delayed(const Duration(seconds: 3), () {
      _isFittingBounds = false;
    });
  }

  void _fitAppleMapBounds() {
    double minLat = polylinePointsAP.first.latitude;
    double minLng = polylinePointsAP.first.longitude;
    double maxLat = polylinePointsAP.first.latitude;
    double maxLng = polylinePointsAP.first.longitude;

    for (var p in polylinePointsAP) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    ap.LatLngBounds bounds = ap.LatLngBounds(
        southwest: ap.LatLng(minLat, minLng),
        northeast: ap.LatLng(maxLat, maxLng)
    );
    appleController!.animateCamera(ap.CameraUpdate.newLatLngBounds(bounds, 80)); // 80 Padding
  }

  void _fitMapLibreBounds() {
    double minLat = polylinePointsML.first.latitude;
    double minLng = polylinePointsML.first.longitude;
    double maxLat = polylinePointsML.first.latitude;
    double maxLng = polylinePointsML.first.longitude;

    for (var p in polylinePointsML) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    ml.LatLngBounds bounds = ml.LatLngBounds(
        southwest: ml.LatLng(minLat, minLng),
        northeast: ml.LatLng(maxLat, maxLng)
    );
    mapLibreController!.animateCamera(
        ml.CameraUpdate.newLatLngBounds(bounds, left: 60, right: 60, top: 120, bottom: 120)
    );
  }

  // ===========================================================================
  // 5. الأيقونات المخصصة
  // ===========================================================================
  Uint8List? pickupIcon;
  Uint8List? destinationIcon;

  Future<void> setCustomMarkerIcon() async {
    if (pickupIcon != null && destinationIcon != null) return;
    try {
      pickupIcon = await Helper.getBytesFromAsset(MyIcons.mapMarkerPickUpIcon, 120);
      destinationIcon = await Helper.getBytesFromAsset(MyIcons.mapMarkerIcon, 120);
      print("🖼️ [Controller] تم تحميل الأيقونات المخصصة");
    } catch (e) {
      print("🔴 [Controller] فشل تحميل أيقونات الماركر: $e");
    }
  }
}