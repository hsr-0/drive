import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as ap;

/// Free standby map used when the driver has no assigned offers.
/// Challenges/rewards remain in the parent screen.
class DriverStandbyMap extends StatefulWidget {
  final Position? position;
  final bool online;
  const DriverStandbyMap({super.key, required this.position, required this.online});
  @override
  State<DriverStandbyMap> createState() => _DriverStandbyMapState();
}
class _DriverStandbyMapState extends State<DriverStandbyMap> {
  ml.MapLibreMapController? _mapLibre;
  ap.AppleMapController? _apple;
  @override
  void didUpdateWidget(covariant DriverStandbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != null &&
        (oldWidget.position?.latitude != widget.position?.latitude ||
         oldWidget.position?.longitude != widget.position?.longitude)) {
      final lat = widget.position!.latitude, lng = widget.position!.longitude;
      _mapLibre?.animateCamera(ml.CameraUpdate.newLatLng(ml.LatLng(lat, lng)));
      _apple?.animateCamera(ap.CameraUpdate.newLatLng(ap.LatLng(lat, lng)));
    }
  }
  @override
  Widget build(BuildContext context) {
    final lat = widget.position?.latitude ?? 32.9;
    final lng = widget.position?.longitude ?? 45.1;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: ClipRRect(borderRadius: BorderRadius.circular(18),
        child: SizedBox(height: 385, child: Stack(children: [
          if (Platform.isIOS)
            ap.AppleMap(
              initialCameraPosition: ap.CameraPosition(
                target: ap.LatLng(lat, lng), zoom: 15),
              myLocationEnabled: true, compassEnabled: false,
              onMapCreated: (map) => _apple = map,
            )
          else
            ml.MapLibreMap(
              styleString: 'https://tiles.openfreemap.org/styles/liberty',
              initialCameraPosition: ml.CameraPosition(
                target: ml.LatLng(lat, lng), zoom: 15),
              myLocationEnabled: true, compassEnabled: false,
              onMapCreated: (map) => _mapLibre = map,
            ),
          Positioned(top: 12, right: 12, left: 12, child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(12))),
              child: Padding(padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.circle, size: 10,
                    color: widget.online ? Colors.green : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    widget.online
                      ? 'أنت متصل • نبحث لك عن طلبات قريبة'
                      : 'أنت غير متصل • فعّل التواجد لاستقبال الطلبات',
                    textAlign: TextAlign.center, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13))),
                ]),
              ),
            ),
          )),
          const Positioned(bottom: 12, right: 12, left: 12,
            child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(12))),
              child: Padding(padding: EdgeInsets.all(10),
                child: Text('راح يظهر طلب الركوب هنا أول ما يتم اختياره إلك',
                  textAlign: TextAlign.center)),
            )),
          ),
        ])),
      ),
    );
  }
}
