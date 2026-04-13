import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

// استيراد مكتبات الخرائط المجانية
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as ap;

import 'package:ovoride_driver/core/utils/helper.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';

class RideMapController extends GetxController {
  bool isLoading = false;
  bool isMapReady = false;

  // لمنع طلب المسار أكثر من مرة
  bool isRouteFetched = false;

  // الإحداثيات الأساسية
  double pickupLat = 0.0;
  double pickupLng = 0.0;
  double destLat = 0.0;
  double destLng = 0.0;

  // إحداثيات واتجاه السائق
  double driverLat = 0.0;
  double driverLng = 0.0;
  double driverHeading = 0.0; // 🌟 المتغير الجديد لحفظ زاوية دوران السيارة

  // متغير لحل مشكلة "الخريطة ليست جاهزة" - يحفظ الموقع المؤقت
  bool _hasPendingDriverLocation = false;

  // مراجع الخرائط
  ml.MapLibreMapController? mapLibreController;
  ap.AppleMapController? appleController;

  // متغيرات مخصصة لآيفون
  Set<ap.Annotation> appleMarkers = {};
  Set<ap.Polyline> applePolylines = {};

  // متغيرات مخصصة لأندرويد
  ml.Symbol? pickupSymbol;
  ml.Symbol? driverLibreSymbol;
  ml.Line? routeLine;

  // دبابيس آيفون
  ap.Annotation? driverAppleMarker;

  // الأيقونات
  Uint8List? pickupIcon;
  Uint8List? driverCarIcon;

  List<ml.LatLng> polylinePointsML = [];
  List<ap.LatLng> polylinePointsAP = [];

  bool _isFittingBounds = false;

  // ===========================================================================
  // 1. إعداد الخريطة
  // ===========================================================================

  void onMapLibreCreated(ml.MapLibreMapController controller) {
    print("✅ [MAP] تم تهيئة خريطة MapLibre");
    mapLibreController = controller;
    isMapReady = true;
    _drawIfReady();
  }

  void onAppleMapCreated(ap.AppleMapController controller) {
    print("✅ [MAP] تم تهيئة خريطة Apple");
    appleController = controller;
    isMapReady = true;
    _drawIfReady();
  }

  void loadMap({required double pLat, required double pLng, required double dLat, required double dLng}) {
    pickupLat = pLat;
    pickupLng = pLng;
    destLat = dLat;
    destLng = dLng;
    _drawIfReady();
  }

  Future<void> _drawIfReady() async {
    if (!isMapReady || pickupLat == 0.0) return;

    await setCustomMarkerIcon();
    await _drawCustomerMarkers();

    // إذا كان هناك موقع سائق وصل قبل أن تجهز الخريطة، قم برسمه الآن!
    if (_hasPendingDriverLocation) {
      print("🔄 [MAP] رسم موقع السائق الذي كان معلقاً...");
      _hasPendingDriverLocation = false;
      await updateDriverLocation(driverLat, driverLng, heading: driverHeading);
    }
  }

  // ===========================================================================
  // 2. تحديث موقع السائق الحي مع الاتجاه
  // ===========================================================================

  // 🌟 أضفنا heading كمتغير اختياري
  Future<void> updateDriverLocation(double newLat, double newLng, {double heading = 0.0}) async {
    driverLat = newLat;
    driverLng = newLng;
    driverHeading = heading; // حفظ الزاوية الجديدة

    // حل مشكلة "الخريطة ليست جاهزة"
    if (!isMapReady) {
      print("⏳ [MAP] الخريطة غير جاهزة بعد، تم حفظ موقع السائق مؤقتاً.");
      _hasPendingDriverLocation = true;
      return;
    }

    print("📡 [MAP] تحديث سيارة السائق على الخريطة: $newLat, $newLng | زاوية: $heading");

    if (Platform.isIOS && appleController != null) {
      // كود الأيفون
      if (driverAppleMarker != null) appleMarkers.remove(driverAppleMarker);
      if (driverCarIcon != null) {
        driverAppleMarker = ap.Annotation(
          annotationId:  ap.AnnotationId('driver_car_marker'),
          position: ap.LatLng(driverLat, driverLng),
          icon: ap.BitmapDescriptor.fromBytes(driverCarIcon!),
        );
        appleMarkers.add(driverAppleMarker!);
      }
      update();
    } else if (!Platform.isIOS && mapLibreController != null) {
      // كود الأندرويد مع الدوران
      if (driverCarIcon != null) {
        await mapLibreController!.addImage('driver_car_icon', driverCarIcon!);
      }

      if (driverLibreSymbol != null) {
        await mapLibreController!.updateSymbol(
          driverLibreSymbol!,
          ml.SymbolOptions(
            geometry: ml.LatLng(driverLat, driverLng),
            iconRotate: driverHeading, // 🌟 تطبيق الدوران الحي
          ),
        );
      } else {
        driverLibreSymbol = await mapLibreController!.addSymbol(ml.SymbolOptions(
          geometry: ml.LatLng(driverLat, driverLng),
          iconImage: 'driver_car_icon',
          iconSize: 1.0,
          iconAnchor: 'center',
          iconRotate: driverHeading, // 🌟 تطبيق الدوران عند الإنشاء
        ));
      }
    }

    // رسم المسار من السائق للزبون (لأول مرة فقط)
    if (!isRouteFetched && pickupLat != 0.0) {
      isRouteFetched = true;
      await getRouteToCustomer();
    }
  }

  // ===========================================================================
  // 3. جلب المسار من OSRM (من السائق للزبون)
  // ===========================================================================
  Future<void> getRouteToCustomer() async {
    print("🛰️ [MAP] طلب المسار من السائق للزبون...");
    isLoading = true;
    update();

    try {
      final String url =
          'https://router.project-osrm.org/route/v1/driving/$driverLng,$driverLat;$pickupLng,$pickupLat?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List coords = data['routes'][0]['geometry']['coordinates'];

          polylinePointsML.clear();
          polylinePointsAP.clear();

          for (var c in coords) {
            polylinePointsML.add(ml.LatLng(c[1].toDouble(), c[0].toDouble()));
            polylinePointsAP.add(ap.LatLng(c[1].toDouble(), c[0].toDouble()));
          }

          await _drawPolyline();
          fitPolylineBounds();
        }
      }
    } catch (e) {
      print('🔴 [MAP] خطأ في جلب المسار: $e');
    }

    isLoading = false;
    update();
  }

  // ===========================================================================
  // 4. رسم الخط والدبابيس الثابتة
  // ===========================================================================
  Future<void> _drawPolyline() async {
    if (Platform.isIOS) {
      applePolylines.clear();
      applePolylines.add(
          ap.Polyline(
            polylineId:  ap.PolylineId('route_line_to_customer'),
            points: polylinePointsAP,
            color: MyColor.primaryColor,
            width: 6,
            jointType: ap.JointType.round,
          )
      );
      update();
    } else {
      if (mapLibreController == null) return;
      if (routeLine != null) await mapLibreController!.removeLine(routeLine!);

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

  Future<void> _drawCustomerMarkers() async {
    if (Platform.isIOS) {
      if (pickupIcon != null) {
        appleMarkers.add(ap.Annotation(
          annotationId:  ap.AnnotationId('pickup_marker'),
          position: ap.LatLng(pickupLat, pickupLng),
          icon: ap.BitmapDescriptor.fromBytes(pickupIcon!),
        ));
      }
      update();
    } else {
      if (mapLibreController == null || pickupIcon == null) return;

      await mapLibreController!.addImage('pickup_icon', pickupIcon!);

      if (pickupSymbol != null) await mapLibreController!.removeSymbol(pickupSymbol!);

      pickupSymbol = await mapLibreController!.addSymbol(ml.SymbolOptions(
        geometry: ml.LatLng(pickupLat, pickupLng),
        iconImage: 'pickup_icon',
        iconSize: 1.0,
        iconAnchor: 'bottom',
      ));
    }
  }

  // ===========================================================================
  // 5. كاميرا احترافية (توسيع الرؤية لتشمل السائق والزبون بوضوح)
  // ===========================================================================
  void fitPolylineBounds() {
    if (_isFittingBounds) return;
    _isFittingBounds = true;

    try {
      if (Platform.isIOS && appleController != null && polylinePointsAP.isNotEmpty) {
        _fitAppleMapBounds();
      } else if (!Platform.isIOS && mapLibreController != null && polylinePointsML.isNotEmpty) {
        _fitMapLibreBounds();
      }
    } catch (e) {
      print("🔴 [MAP] خطأ في زوم الكاميرا: $e");
    }

    // الانتظار 4 ثواني لمنع التحديث المزعج للكاميرا إذا تحرك السائق بسرعة
    Future.delayed(const Duration(seconds: 4), () {
      _isFittingBounds = false;
    });
  }

  void _fitAppleMapBounds() {
    double minLat = driverLat < pickupLat ? driverLat : pickupLat;
    double maxLat = driverLat > pickupLat ? driverLat : pickupLat;
    double minLng = driverLng < pickupLng ? driverLng : pickupLng;
    double maxLng = driverLng > pickupLng ? driverLng : pickupLng;

    ap.LatLngBounds bounds = ap.LatLngBounds(
        southwest: ap.LatLng(minLat, minLng),
        northeast: ap.LatLng(maxLat, maxLng)
    );
    appleController!.animateCamera(ap.CameraUpdate.newLatLngBounds(bounds, 120));
  }

  void _fitMapLibreBounds() {
    double minLat = driverLat < pickupLat ? driverLat : pickupLat;
    double maxLat = driverLat > pickupLat ? driverLat : pickupLat;
    double minLng = driverLng < pickupLng ? driverLng : pickupLng;
    double maxLng = driverLng > pickupLng ? driverLng : pickupLng;

    ml.LatLngBounds bounds = ml.LatLngBounds(
        southwest: ml.LatLng(minLat, minLng),
        northeast: ml.LatLng(maxLat, maxLng)
    );
    mapLibreController!.animateCamera(
        ml.CameraUpdate.newLatLngBounds(bounds, left: 160, right: 160, top: 220, bottom: 220)
    );
  }

  // ===========================================================================
  // 6. تحميل أيقونة الزبون وصورة السيارة الجديدة
  // ===========================================================================
  Future<void> setCustomMarkerIcon() async {
    if (pickupIcon != null && driverCarIcon != null) return;

    try {
      pickupIcon = await Helper.getBytesFromAsset(MyIcons.mapMarkerPickUpIcon, 120);

      // تحميل سيارة البيضاء الجديدة (تأكد أن الصورة في مجلد assets/images واسمها car_top.png)
      driverCarIcon = await Helper.getBytesFromAsset('assets/images/car_top.png', 180);

      print("🖼️ [MAP] تم تحميل صورة السيارة الاحترافية بنجاح");
    } catch (e) {
      print("🔴 [MAP] فشل تحميل صورة السيارة، سيتم استخدام الأيقونة الافتراضية: $e");
      driverCarIcon = await Helper.getBytesFromAsset(MyIcons.mapMarkerPickUpIcon, 120);
    }
  }
}