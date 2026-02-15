import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ovoride_driver/core/utils/helper.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/environment.dart';

class RideMapController extends GetxController {
  bool isLoading = false;
  bool isMapReady = false;

  // الإحداثيات
  Position pickupPos = Position(0, 0);
  Position destinationPos = Position(0, 0);

  // مراجع Mapbox
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;

  List<Position> polylinePoints = [];

  // متغير لمنع تكرار ضبط الكاميرا بشكل لانهائي
  bool _isFittingBounds = false;

  // ===========================================================================
  // 1. إعداد الخريطة والمديرين
  // ===========================================================================
  Future<void> onMapCreated(MapboxMap map) async {
    print("🎬 [Controller] تم استدعاء onMapCreated");
    mapboxMap = map;

    try {
      pointAnnotationManager = await map.annotations.createPointAnnotationManager();
      polylineAnnotationManager = await map.annotations.createPolylineAnnotationManager();
      isMapReady = true;
      print("🟢 [Controller] مديرو Annotations جاهزون. الخريطة جاهزة تماماً.");

      // إذا كانت الإحداثيات موجودة مسبقاً (تم جلبها قبل بناء الخريطة)
      if (pickupPos.lat != 0 && pickupPos.lat != 0.0) {
        print("🔄 [Controller] الإحداثيات جاهزة، يتم الرسم الآن...");
        loadMap(
            pLat: pickupPos.lat.toDouble(),
            pLng: pickupPos.lng.toDouble(),
            dLat: destinationPos.lat.toDouble(),
            dLng: destinationPos.lng.toDouble()
        );
      }
    } catch (e) {
      print("🔴 [Controller] خطأ أثناء إنشاء مديري Annotations: $e");
    }
    update();
  }

  void loadMap({required double pLat, required double pLng, required double dLat, required double dLng}) async {
    print("🗺️ [Controller] محاولة تحميل الخريطة (loadMap)...");

    // تصحيح: Mapbox يستخدم Longitude كمعامل أول في كلاس Position
    pickupPos = Position(pLng, pLat);
    destinationPos = Position(dLng, dLat);
    update();

    if (!isMapReady) {
      print("⏳ [Controller] الخريطة لم تجهز بعد، سيتم الرسم لاحقاً عند onMapCreated");
      return;
    }

    await setCustomMarkerIcon();
    await _drawStaticMarkers();
    await getRouteFromMapbox();
  }

  // ===========================================================================
  // 2. جلب المسار من Mapbox Directions API
  // ===========================================================================
  Future<void> getRouteFromMapbox() async {
    print("🛰️ [Controller] طلب المسار من API...");
    isLoading = true;
    update();

    try {
      String accessToken = Environment.mapKey;
      final String url =
          'https://api.mapbox.com/directions/v5/mapbox/driving/${pickupPos.lng},${pickupPos.lat};${destinationPos.lng},${destinationPos.lat}?overview=full&geometries=geojson&access_token=$accessToken';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          print("✅ [Controller] تم استلام المسار بنجاح");
          final geometry = data['routes'][0]['geometry'];
          final List coords = geometry['coordinates'];

          polylinePoints = coords.map((c) => Position(c[0].toDouble(), c[1].toDouble())).toList();
          await _drawPolyline();

          // استدعاء ضبط الكاميرا
          fitPolylineBounds();
        } else {
          print("⚠️ [Controller] لا يوجد مسارات متاحة بين النقطتين");
        }
      } else {
        print("🔴 [Controller] خطأ في API المسار: ${response.statusCode}");
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
    if (polylineAnnotationManager == null) return;
    print("✏️ [Controller] جاري رسم الخط (Polyline)...");
    await polylineAnnotationManager!.deleteAll();

    var options = PolylineAnnotationOptions(
      geometry: LineString(coordinates: polylinePoints),
      lineColor: MyColor.primaryColor.value,
      lineWidth: 5.0,
      lineJoin: LineJoin.ROUND,
    );
    await polylineAnnotationManager!.create(options);
  }

  Future<void> _drawStaticMarkers() async {
    if (pointAnnotationManager == null) return;
    print("📌 [Controller] جاري رسم الدبابيس (Markers)...");
    await pointAnnotationManager!.deleteAll();

    List<PointAnnotationOptions> markers = [];

    if (pickupIcon != null) {
      markers.add(PointAnnotationOptions(
        geometry: Point(coordinates: pickupPos),
        image: pickupIcon!,
        iconSize: 1.0,
        iconAnchor: IconAnchor.BOTTOM,
      ));
    }

    if (destinationIcon != null) {
      markers.add(PointAnnotationOptions(
        geometry: Point(coordinates: destinationPos),
        image: destinationIcon!,
        iconSize: 1.0,
        iconAnchor: IconAnchor.BOTTOM,
      ));
    }

    await pointAnnotationManager!.createMulti(markers);
  }

  // ===========================================================================
  // 4. الكاميرا والهوامش (مع منع التكرار اللانهائي)
  // ===========================================================================
  void fitPolylineBounds() {
    if (polylinePoints.isEmpty || mapboxMap == null || _isFittingBounds) return;

    _isFittingBounds = true; // قفل لمنع التكرار
    print("🔭 [Controller] جاري ضبط زوم الكاميرا لمرة واحدة...");

    List<Point> points = polylinePoints.map((e) => Point(coordinates: e)).toList();
    MbxEdgeInsets padding = MbxEdgeInsets(top: 100, left: 60, bottom: 100, right: 60);

    mapboxMap!.cameraForCoordinates(points, padding, null, null).then((cameraOptions) {
      mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1500));

      // نفتح القفل بعد انتهاء التحريك بمدة بسيطة
      Future.delayed(const Duration(seconds: 3), () {
        _isFittingBounds = false;
      });
    });
  }

  // ===========================================================================
  // 5. الأيقونات المخصصة
  // ===========================================================================
  Uint8List? pickupIcon;
  Uint8List? destinationIcon;

  Future<void> setCustomMarkerIcon() async {
    if (pickupIcon != null) return;
    try {
      pickupIcon = await Helper.getBytesFromAsset(MyIcons.mapMarkerPickUpIcon, 120);
      destinationIcon = await Helper.getBytesFromAsset(MyIcons.mapMarkerIcon, 120);
      print("🖼️ [Controller] تم تحميل الأيقونات المخصصة");
      update();
    } catch (e) {
      print("🔴 [Controller] فشل تحميل أيقونات الماركر: $e");
    }
  }
}
