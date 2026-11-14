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
import 'package:ovoride_driver/core/route/route.dart';
import 'api_client.dart';
import 'package:get/get.dart' as getx;

// تعريف المتغيرات لتكون متاحة للنظام في الخلفية
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'beytei_urgent_call',
  'Beytei Urgent Alerts',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notification'),
);

// 🔥 دالة المعالجة في الخلفية (تمت إضافة المنطق المفقود) 🔥
@pragma('vm:entry-point')
Future<void> _messageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // إعادة إنشاء القناة في هذه العملية المنفصلة
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // FCM automatically displays notification+data in the background; avoid a second local copy.
  if (message.notification != null && Platform.isAndroid) return;

  // إظهار الإشعار يدوياً
  String title = message.notification?.title ?? message.data['title']?.toString() ?? 'طلب جديد';
  String body = message.notification?.body ?? message.data['body']?.toString() ?? 'يوجد رحلة جديدة بانتظارك';

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        // ✅ الصوت يعمل الآن في الخلفية
        sound: const RawResourceAndroidNotificationSound('notification'),
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

class PushNotificationService {
  ApiClient apiClient;
  PushNotificationService({required this.apiClient});

  Future<void> setupInteractedMessage() async {
    // ربط دالة الخلفية
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

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleMessageInteraction(initialMessage);

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
      if ((data['type'] == 'ride_request' || data['type'] == 'NEW_RIDE')) {
        getx.Get.toNamed(RouteHelper.dashboard);
        return;
      }
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
            if (data['type'] == 'ride_request') {
              getx.Get.toNamed(RouteHelper.dashboard);
              return;
            }
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
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
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
    final messaging = FirebaseMessaging.instance;
    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        apiClient.sharedPreferences.setString(
            SharedPreferenceHelper.fcmDeviceKey, token);
        await sendUpdatedToken(token);
      }
      messaging.onTokenRefresh.listen((updated) async {
        apiClient.sharedPreferences.setString(
            SharedPreferenceHelper.fcmDeviceKey, updated);
        await sendUpdatedToken(updated);
      });
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
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
