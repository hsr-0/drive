import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/data/repo/dashboard/dashboard_repo.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgroundLocationService extends TaskHandler {
  ForgroundLocationService();

  StreamSubscription<Position>? _positionStream;
  late DashBoardRepo dashBoardRepo;
  late SharedPreferences _sharedPreferences;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      _sharedPreferences = await SharedPreferences.getInstance();
      ApiClient apiClient = ApiClient(sharedPreferences: _sharedPreferences);
      dashBoardRepo = DashBoardRepo(apiClient: apiClient);

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: Environment.driverLocationUpdateAfterNmetersOrMovements,
        ),
      ).listen((Position? location) async {
        if (location != null) {
          final double lat = location.latitude;
          final double lon = location.longitude;

          final isOnline = dashBoardRepo.apiClient.getUserOnlineStatus();
          final isLoggedIn = dashBoardRepo.apiClient.isLoggedIn();

          if (isOnline && isLoggedIn) {
            FlutterForegroundTask.updateService(
              notificationText: "نظام التتبع المزدوج نشط 🟢",
            );

            // جلب معرف الرحلة الحالية من الذاكرة المحلية (مهم جداً)
            final String currentRideId = _sharedPreferences.getString('current_ride_id') ?? '';

            // استدعاء الدالة الموحدة التي تقوم بـ (حفظ MySQL + بث Reverb) معاً
            await sendLocationToUnifiedSystem(lat: lat, long: lon, rideId: currentRideId);

          } else {
            printE("🛑 [SERVICE] توقف التتبع: الحالة Offline");
            FlutterForegroundTask.stopService();
            _positionStream?.cancel();
            _positionStream = null;
          }
        }
      });
    } catch (e) {
      printE("❌ [SERVICE] خطأ فادح في بدء الخدمة: $e");
    }
  }

  // دالة موحدة ونظيفة ترسل الموقع للنظام القديم والجديد في آن واحد
  Future<void> sendLocationToUnifiedSystem({
    required double lat,
    required double long,
    required String rideId
  }) async {
    try {
      var response = await dashBoardRepo.updateLiveLocation(
        lat: "$lat",
        long: "$long",
        rideId: rideId, // ✅ هذا هو المعامل الذي كان يسبب الخطأ
      );

      if (response.statusCode == 200) {
        printX("✅ [SYSTEM] تم حفظ الموقع وبثه بنجاح (MySQL + Reverb)");
      } else {
        printE("⚠️ [SYSTEM] فشل التحديث. كود الرد: ${response.statusCode}");
        printE("تفاصيل الخطأ: ${response.responseJson}");
      }
    } catch (e) {
      printE("❌ [SYSTEM] خطأ اتصال: $e");
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _positionStream?.cancel();
    _positionStream = null;
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}