import 'dart:async';
import 'dart:convert';
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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
      ApiClient apiClient = ApiClient(sharedPreferences: sharedPreferences);
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

            // إرسال للنظام القديم
            await sendLocationToOldServer(lat: lat, long: lon);

            // إرسال للنظام الصاروخي الجديد
            await sendLocationToRedisServer(lat: lat, long: lon);

          } else {
            printE("🛑 [SERVICE] توقف التتبع: السيرفر يقرأ الحالة Offline");
            FlutterForegroundTask.stopService();
            _positionStream?.cancel();
            _positionStream = null;
          }
        }
      });
    } catch (e) {
      printE("❌ [SERVICE] خطأ فادح: $e");
    }
  }

  // 1. إرسال للنظام القديم (MySQL)
  Future<void> sendLocationToOldServer({required double lat, required double long}) async {
    try {
      var response = await dashBoardRepo.updateLiveLocation(lat: "$lat", long: "$long");
      if (response.statusCode == 200) {
        printX("✅ [OLD SYSTEM] تم التحديث في MySQL بنجاح");
      } else {
        printE("⚠️ [OLD SYSTEM] فشل التحديث. كود الرد: ${response.statusCode}");
      }
    } catch (e) {
      printE("❌ [OLD SYSTEM] خطأ اتصال: $e");
    }
  }

  // 2. إرسال للنظام الصاروخي (Redis) مع طباعة تفصيلية للسبب في حال الفشل
  Future<void> sendLocationToRedisServer({required double lat, required double long}) async {
    try {
      final String token = dashBoardRepo.apiClient.sharedPreferences.getString(SharedPreferenceHelper.accessTokenKey) ?? '';
      final String url = 'https://taxi.beytei.com/api/driver/redis/update-location';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          'lat': lat.toString(),
          'lng': long.toString(),
        },
      );

      if (response.statusCode == 200) {
        printX("🚀 [REDIS] تم الإرسال للصاروخ بنجاح! الإحداثيات: ($lat, $long)");
      } else {
        // طباعة سبب الفشل من السيرفر (مثلاً: Unauthenticated أو Validation Error)
        printE("❌ [REDIS FAILED] فشل الإرسال!");
        printE("   - كود الحالة: ${response.statusCode}");
        printE("   - السبب من السيرفر: ${response.body}");
      }
    } catch (e) {
      printE("❌ [REDIS ERROR] فشل في تنفيذ الطلب (مشكلة إنترنت أو سيرفر): $e");
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
