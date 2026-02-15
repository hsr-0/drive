import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/theme/light/light.dart';
import 'package:ovoride_driver/core/utils/audio_utils.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/messages.dart';
import 'package:ovoride_driver/data/controller/localization/localization_controller.dart';
import 'package:ovoride_driver/core/di_service/di_services.dart' as di_service;
import 'package:ovoride_driver/presentation/screens/dashboard/forground_task_widget.dart';
import 'package:ovoride_driver/data/services/forground_location_service.dart';
import 'package:ovoride_driver/data/services/push_notification_service.dart';
import 'package:ovoride_driver/environment.dart';
import 'data/services/api_client.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:toastification/toastification.dart';

//APP ENTRY POINT
Future<void> main() async {
  // Ensures that widget binding is initialized before calling native code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the API client for network communication
  await ApiClient.init();

  // Load and initialize localization/language support
  Map<String, Map<String, String>> languages = await di_service.init();

  // Configure app UI to support all screen sizes
  MyUtils.allScreen();

  // Lock device orientation to portrait mode
  MyUtils().stopLandscape();

  // Initialize audio utilities (e.g., background music, sound effects)
  AudioUtils();

  try {
    // Initialize push notification service and handle interaction messages
    await PushNotificationService(
      apiClient: Get.find(),
    ).setupInteractedMessage();
  } catch (e) {
    // Print error to console if FCM setup fails
    printX(e);
  }

  // Override HTTP settings (e.g., SSL certificate handling)
  HttpOverrides.global = MyHttpOverrides();
  tz.initializeTimeZones();
  FlutterForegroundTask.initCommunicationPort();
  runApp(OvoApp(languages: languages));
}

@pragma('vm:entry-point')
void startForgroundTask() {
  FlutterForegroundTask.setTaskHandler(ForgroundLocationService());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (X509Certificate cert, String host, int port) => false;
  }
}

class OvoApp extends StatefulWidget {
  final Map<String, Map<String, String>> languages;

  const OvoApp({super.key, required this.languages});

  @override
  State<OvoApp> createState() => _OvoAppState();
}

class _OvoAppState extends State<OvoApp> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MyUtils.precacheImagesFromPathList(context, [MyImages.backgroundImage, MyImages.logoWhite, MyImages.noDataImage]);
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalizationController>(
      builder: (localizeController) => ToastificationWrapper(
        config: ToastificationConfig(maxToastLimit: 10),
        child: GetMaterialApp(
          title: Environment.appName,
          debugShowCheckedModeBanner: false,
          theme: lightThemeData,
          defaultTransition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 300),

          // 🔥🔥🔥 التعديل الجوهري هنا 🔥🔥🔥
          // جعلنا نقطة البداية هي شاشة الأقسام بدلاً من السبلاش
          initialRoute: RouteHelper.sectionsScreen,

          getPages: RouteHelper().routes,
          locale: localizeController.locale,
          translations: Messages(languages: widget.languages),
          fallbackLocale: Locale(
            localizeController.locale.languageCode,
            localizeController.locale.countryCode,
          ),
          builder: (context, child) => ForGroundTaskWidget(
            key: foregroundTaskKey,
            onWillStart: () {
              return Future.value(true);
            },
            callback: startForgroundTask,
            child: child ?? Container(),
          ),
        ),
      ),
    );
  }
}