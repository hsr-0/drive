import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/data/repo/dashboard/dashboard_repo.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgroundLocationService extends TaskHandler {
  ForgroundLocationService();

  StreamSubscription<Position>? _positionStream;
  late DashBoardRepo dashBoardRepo;
  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
      ApiClient apiClient = ApiClient(sharedPreferences: sharedPreferences);
      dashBoardRepo = DashBoardRepo(apiClient: apiClient);
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          // timeLimit: Duration(seconds: 30),
          distanceFilter: Environment.driverLocationUpdateAfterNmetersOrMovements, // Only update every 10 meters of movement
        ),
      ).listen((Position? location) async {
        if (location != null) {
          final double lat = location.latitude;
          final double lon = location.longitude;
          final isOnline = dashBoardRepo.apiClient.getUserOnlineStatus();
          final isLoggedIn = dashBoardRepo.apiClient.isLoggedIn();
          printX("Is online -> $isOnline | isLoggedIn -> $isLoggedIn");
          if (isOnline && isLoggedIn) {
            FlutterForegroundTask.updateService(
              notificationText: "Current Location: $lat , $lat",
            );
            await sendLocationToServer(lat: lat, long: lon);
            // FlutterForegroundTask.updateService(notificationText: "Refreshing location....");
          } else {
            printE("Stoped Foreground Task");
            FlutterForegroundTask.stopService();
            _positionStream?.cancel();
            _positionStream = null;
          }
        }
      });
    } catch (e) {
      printE(e);
      // FlutterForegroundTask.stopService();
    }
  }

  Future<void> sendLocationToServer({
    required double lat,
    required double long,
  }) async {
    try {
      var response = await dashBoardRepo.updateLiveLocation(
        lat: "$lat",
        long: "$long",
      );
      if (response.statusCode == 200) {
        FlutterForegroundTask.updateService(
          notificationText: "Data synced successfully",
        );
      }
    } catch (e) {
      printE(e);
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {}

  // Called when the task is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    printX('onDestroy:::::::::::: Forground Task');
    _positionStream?.cancel();
    _positionStream = null;
  }

  // Called when data is sent using [FlutterForegroundTask.sendDataToTask].
  @override
  void onReceiveData(Object data) {
    printX('onReceiveData999: $data');
    FlutterForegroundTask.sendDataToMain(data);
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    printX('onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  //
  // AOS: "android.permission.SYSTEM_ALERT_WINDOW" permission must be granted
  // for this function to be called.
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
    printX('onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  //
  // AOS: only work Android 14+
  // iOS: only work iOS 10+
  @override
  void onNotificationDismissed() {
    printX('onNotificationDismissed');
  }
}
