import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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
    // ✅ ضبط التوكن عالمياً باستخدام المسمى الموجود في ملف environment.dart
    MapboxOptions.setAccessToken(Environment.mapKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<RideMapController>(
        builder: (controller) {

          // سجل تتبع للإحداثيات
          print("📍 [MAPBOX] بناء الخريطة في: Lat ${controller.pickupPos.lat}, Lng ${controller.pickupPos.lng}");

          return MapWidget(
            key: const ValueKey("mapbox_driver_map"),
            styleUri: MapboxStyles.MAPBOX_STREETS,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  controller.pickupPos.lng, // Longitude أولاً
                  controller.pickupPos.lat,
                ),
              ),
              zoom: Environment.mapDefaultZoom,
            ),
            onMapCreated: (mapboxMap) {
              print("✅ [MAPBOX] الخريطة تم إنشاؤها بنجاح");
              controller.onMapCreated(mapboxMap);
            },
            onStyleLoadedListener: (styleLoadedEvent) {
              print("🎨 [MAPBOX] الستايل تم تحميله - الخريطة مرئية الآن");
            },
          );
        },
      ),
    );
  }
}