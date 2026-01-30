import 'dart:io';
import 'package:flutter/services.dart';
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
import 'package:firebase_messaging/firebase_messaging.dart'; // تأكد من وجود هذا الاستيراد

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
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => false;
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
          initialRoute: RouteHelper.splashScreen,
          getPages: RouteHelper().routes,
          locale: localizeController.locale,
          translations: Messages(languages: widget.languages),
          fallbackLocale: Locale(
            localizeController.locale.languageCode,
            localizeController.locale.countryCode,
          ),
          builder: (context, child) => Stack(
            children: [
              ForGroundTaskWidget(
                key: foregroundTaskKey,
                onWillStart: () {
                  return Future.value(true);
                },
                callback: startForgroundTask,
                child: child ?? Container(),
              ),
              // !!! زر التشخيص الذكي المضاف !!!
              if (Platform.isIOS) // يظهر فقط في الآيفون لأن المشكلة هناك
                const Positioned(
                  bottom: 100,
                  left: 20,
                  child: SmartNotificationDebugger(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Smart Notification Debugger Widget
/// هذا الودجت سيساعدك في معرفة مكان الخلل بالضبط
/// -------------------------------------------------------------------------
class SmartNotificationDebugger extends StatefulWidget {
  const SmartNotificationDebugger({super.key});

  @override
  State<SmartNotificationDebugger> createState() => _SmartNotificationDebuggerState();
}

class _SmartNotificationDebuggerState extends State<SmartNotificationDebugger> {
  String status = "اضغط للفحص";
  Color statusColor = Colors.red;
  bool isLoading = false;

  Future<void> runDiagnostics() async {
    setState(() {
      isLoading = true;
      status = "جاري الفحص...";
    });

    StringBuffer report = StringBuffer();

    try {
      // 1. فحص الصلاحيات
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
      );

      report.writeln("1. Permission: ${settings.authorizationStatus}");

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        throw "لم يتم منح صلاحية الإشعارات من إعدادات الهاتف!";
      }

      // 2. فحص APNS Token (الأهم بالنسبة للآيفون)
      // إذا كان هذا null، فهذا يعني أن التطبيق لا يتصل بسيرفرات أبل
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      report.writeln("2. APNS Token: ${apnsToken != null ? 'OK (Found)' : 'NULL (Error!)'}");

      if (apnsToken == null) {
        throw "مشكلة كارثية: APNS Token غير موجود.\n"
            "السبب: CodeMagic لم يقم بتوقيع التطبيق بصلاحية 'Push Notifications' أو ملف Provisioning Profile خطأ.\n"
            "الحل: تأكد من تفعيل Push Notifications في Apple Developer Portal للـ Identifier الخاص بك.";
      }

      // 3. فحص FCM Token
      // إذا فشل هذا، فالمشكلة في ملف GoogleService-Info.plist
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      report.writeln("3. FCM Token: ${fcmToken != null ? 'OK' : 'NULL'}");

      if (fcmToken == null) {
        throw "APNS يعمل ولكن الاتصال بـ Firebase فشل.\nتأكد من أن GoogleService-Info.plist موجود وصحيح.";
      }

      print("--- MY FCM TOKEN ---");
      print(fcmToken);
      print("--------------------");

      // نسخ التوكين للحافظة
      await Clipboard.setData(ClipboardData(text: fcmToken));

      setState(() {
        status = "نجح الفحص!\nالتوكين تم نسخه للحافظة.\nAPNS: OK\nFCM: OK";
        statusColor = Colors.green;
      });

      Get.defaultDialog(
        title: "تقرير الفحص",
        content: SelectableText(
          "كل شيء يبدو سليماً من جانب التطبيق!\n\nToken:\n$fcmToken\n\nإذا لم تصل الإشعارات الآن، فالمشكلة في 'Server Key' في لوحة تحكم Firebase أو شهادة p8.",
          style: const TextStyle(fontSize: 12),
        ),
      );

    } catch (e) {
      setState(() {
        status = "خطأ: $e";
        statusColor = Colors.orange;
      });
      Get.defaultDialog(
        title: "تم اكتشاف الخطأ",
        content: Text(e.toString()),
        confirm: ElevatedButton(onPressed: () => Get.back(), child: const Text("حسناً")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: runDiagnostics,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bug_report, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                "فحص الإشعارات (iOS)",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}