import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/helper/shared_preference_helper.dart';
import '../../core/utils/method.dart';
import '../../core/utils/url_container.dart';
import '../../firebase_options.dart';
import 'api_client.dart';
import 'package:get/get.dart' as getx;

// تعريف القناة الصوتية
// التعديل هنا: غيرنا الـ id والـ name لنجبر الهاتف على نسيان الإعدادات القديمة
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'beytei_urgent_call', // غيرنا الاسم هنا (ID)
  'Beytei Urgent Alerts', // غيرنا العنوان هنا
  description: 'This channel is used for important notifications.',
  importance: Importance.max, // هذا السطر سيتم تفعيله بقوة الآن
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notification'),
);


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _messageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  ApiClient apiClient;
  PushNotificationService({required this.apiClient});

  Future<void> setupInteractedMessage() async {
    FirebaseMessaging.onBackgroundMessage(_messageHandler);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await _requestPermissions();

    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageInteraction(message);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage event) {
      _showNotification(event);
    });

    await enableIOSNotifications();
    await registerNotificationListeners();
  }

  void _handleMessageInteraction(RemoteMessage message) {
    try {
      Map<String, dynamic> data = message.data;
      String? remark = data['for_app'];

      if (remark != null && remark.isNotEmpty) {
        String route = remark.split('-')[0];
        String id = remark.split('-')[1];
        getx.Get.toNamed(route, arguments: id);
      }
    } catch (e) {
      if (kDebugMode) print("Error handling interaction: $e");
    }
  }

  Future<void> registerNotificationListeners() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    var androidSettings = const AndroidInitializationSettings('@mipmap/ic_launcher');
    var iOSSettings = const DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    var initSettings = InitializationSettings(android: androidSettings, iOS: iOSSettings);

    flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          try {
            Map<String, dynamic> data = jsonDecode(response.payload!);
            if (data['for_app'] != null) {
              String remark = data['for_app'];
              String route = remark.split('-')[0];
              String id = remark.split('-')[1];
              getx.Get.toNamed(route, arguments: id);
            }
          } catch (e) {
            if (kDebugMode) print(e);
          }
        }
      },
    );
  }

  Future<void> _showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    Map<String, dynamic> data = message.data;

    // إصلاح الخطأ: استخدام String بدلاً من String? وقيم افتراضية
    String title = notification?.title ?? data['title']?.toString() ?? 'رحلة بالقرب منك ';
    String body = notification?.body ?? data['body']?.toString() ?? 'لديك طلب رحلة جديد';

    BigPictureStyleInformation? bigPictureStyle;

    String? imageUrl = android?.imageUrl ?? data['image'];
    if (imageUrl != null) {
      try {
        Dio dio = Dio();
        Response<List<int>> response = await dio.get<List<int>>(
          imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        Uint8List bytes = Uint8List.fromList(response.data!);
        final String localImagePath = await _saveImageLocally(bytes);
        bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(localImagePath),
          contentTitle: title,
          summaryText: body,
        );
      } catch (e) {
        bigPictureStyle = null;
      }
    }

    flutterLocalNotificationsPlugin.show(
      notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, // سيأخذ الاسم الجديد تلقائياً من المتغير بالأعلى
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          // إعدادات الصوت والرنين
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification'),
          enableVibration: true,
          enableLights: true,
          fullScreenIntent: true,
          priority: Priority.high,
          importance: Importance.max,
          styleInformation: bigPictureStyle ?? BigTextStyleInformation(body),
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> enableIOSNotifications() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<String> _saveImageLocally(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/notification_image.png';
    final file = File(imagePath);
    await file.writeAsBytes(bytes);
    return imagePath;
  }

  Future<bool> sendUserToken() async {
    String deviceToken;
    if (apiClient.sharedPreferences.containsKey(SharedPreferenceHelper.fcmDeviceKey)) {
      deviceToken = apiClient.sharedPreferences.getString(SharedPreferenceHelper.fcmDeviceKey) ?? '';
    } else {
      deviceToken = '';
    }

    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
    bool success = false;
    if (deviceToken.isEmpty) {
      firebaseMessaging.getToken().then((fcmDeviceToken) async {
        success = await sendUpdatedToken(fcmDeviceToken ?? '');
      });
    } else {
      firebaseMessaging.onTokenRefresh.listen((fcmDeviceToken) async {
        if (deviceToken == fcmDeviceToken) {
          success = true;
        } else {
          apiClient.sharedPreferences.setString(SharedPreferenceHelper.fcmDeviceKey, fcmDeviceToken);
          success = await sendUpdatedToken(fcmDeviceToken);
        }
      });
    }
    return success;
  }

  Future<bool> sendUpdatedToken(String deviceToken) async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.deviceTokenEndPoint}';
    Map<String, String> map = deviceTokenMap(deviceToken);
    await apiClient.request(url, Method.postMethod, map, passHeader: true);
    return true;
  }

  Map<String, String> deviceTokenMap(String deviceToken) {
    Map<String, String> map = {'token': deviceToken.toString()};
    return map;
  }
}
