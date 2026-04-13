import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// استيراد مكتبات الخرائط المجانية بدلاً من Mapbox
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as ap;

import 'package:ovoride_driver/data/controller/map/ride_map_controller.dart';
import '../../../../../environment.dart';

class PolyLineMapScreen extends StatefulWidget {
  const PolyLineMapScreen({super.key});

  @override
  State<PolyLineMapScreen> createState() => _PolyLineMapScreenState();
}

class _PolyLineMapScreenState extends State<PolyLineMapScreen> {

  @override
  void initState() {
    super.initState();
    // 🗑️ تم إزالة MapboxOptions.setAccessToken لأننا نستخدم خرائط مجانية بالكامل
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<RideMapController>(
        builder: (controller) {

          // سجل تتبع للإحداثيات
          print("📍 [MAP] بناء الخريطة في: Lat ${controller.pickupLat}, Lng ${controller.pickupLng}");

          // إذا كان النظام iOS (آيفون) -> استخدم Apple Maps
          if (Platform.isIOS) {
            return ap.AppleMap(
              key: const ValueKey("apple_driver_map"),
              initialCameraPosition: ap.CameraPosition(
                target: ap.LatLng(
                  controller.pickupLat,
                  controller.pickupLng,
                ),
                zoom: Environment.mapDefaultZoom.toDouble(),
              ),
              onMapCreated: (appleMapController) {
                print("✅ [APPLE MAPS] الخريطة تم إنشاؤها بنجاح");
                controller.onAppleMapCreated(appleMapController);
              },
              // هذه المتغيرات ضرورية في الآيفون لرسم الدبابيس والمسار
              annotations: controller.appleMarkers,
              polylines: controller.applePolylines,
              // 🌟 [تعديل]: تم إيقاف النقطة الزرقاء لأننا نستخدم أيقونة السيارة المخصصة
              myLocationEnabled: false,
              compassEnabled: false,
            );
          }

          // إذا كان النظام Android -> استخدم MapLibre / OpenStreetMap
          else {
            return ml.MapLibreMap(
              key: const ValueKey("maplibre_driver_map"),
              styleString: 'https://tiles.openfreemap.org/styles/liberty', // ستايل مجاني مفتوح المصدر
              initialCameraPosition: ml.CameraPosition(
                target: ml.LatLng(
                  controller.pickupLat,
                  controller.pickupLng,
                ),
                zoom: Environment.mapDefaultZoom.toDouble(),
              ),
              onMapCreated: (mapLibreController) {
                print("✅ [MAPLIBRE] الخريطة تم إنشاؤها بنجاح");
                // 🌟 [تعديل]: هنا نحفظ الكنترولر فقط ولا نرسم الدبابيس لتجنب الكراش
                controller.mapLibreController = mapLibreController;
              },
              onStyleLoadedCallback: () {
                print("🎨 [MAPLIBRE] الستايل تم تحميله - يمكننا رسم الدبابيس والسيارة الآن");
                // 🌟 [تعديل]: هنا نقوم باستدعاء دالة الرسم بعد التأكد من تحميل الخريطة بالكامل
                if (controller.mapLibreController != null) {
                  controller.onMapLibreCreated(controller.mapLibreController!);
                }
              },
              // 🌟 [تعديل]: تم إيقاف النقطة الزرقاء لأننا نستخدم أيقونة السيارة المخصصة
              myLocationEnabled: false,
              compassEnabled: false,
            );
          }

        },
      ),
    );
  }
}