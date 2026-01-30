import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();
  Map<String, Map<String, String>> languages = await di_service.init();
  MyUtils.allScreen();
  MyUtils().stopLandscape();
  AudioUtils();

  try {
    await PushNotificationService(apiClient: Get.find()).setupInteractedMessage();
  } catch (e) {
    printX("FCM Setup Error: $e");
  }

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
          fallbackLocale: Locale(localizeController.locale.languageCode, localizeController.locale.countryCode),
          builder: (context, child) => Stack(
            children: [
              ForGroundTaskWidget(
                key: foregroundTaskKey,
                onWillStart: () => Future.value(true),
                callback: startForgroundTask,
                child: child ?? Container(),
              ),
              // زر التشخيص الاحترافي
              if (Platform.isIOS)
                Positioned(
                  bottom: 120,
                  right: 20,
                  child: ProfessionalNotificationDebugger(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// ويدجت التشخيص الاحترافي - يحلل المشكلة ويعطيك التوكين
/// -------------------------------------------------------------------------
class ProfessionalNotificationDebugger extends StatefulWidget {
  const ProfessionalNotificationDebugger({super.key});

  @override
  State<ProfessionalNotificationDebugger> createState() => _ProfessionalNotificationDebuggerState();
}

class _ProfessionalNotificationDebuggerState extends State<ProfessionalNotificationDebugger> {
  bool _isChecking = false;

  Future<void> runFullCheck() async {
    setState(() => _isChecking = true);

    String report = "";
    String? fcmToken;
    bool hasApns = false;

    try {
      // 1. طلب الصلاحيات بشكل صريح
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      report += "• الصلاحيات: ${settings.authorizationStatus.name}\n";

      // 2. محاولة جلب APNS Token
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        hasApns = true;
        report += "• APNS Token: ✅ موجود\n";
      } else {
        report += "• APNS Token: ❌ غير موجود (Null)\n";
      }

      // 3. جلب FCM Token (حتى لو APNS مفقود لنرى الاستجابة)
      fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        report += "• FCM Token: ✅ تم استخراجه بنجاح\n";
        await Clipboard.setData(ClipboardData(text: fcmToken));
      } else {
        report += "• FCM Token: ❌ فشل الجلب\n";
      }

    } catch (e) {
      report += "• خطأ تقني: $e\n";
    }

    _showResult(report, fcmToken, hasApns);
    setState(() => _isChecking = false);
  }

  void _showResult(String report, String? token, bool hasApns) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("تقرير تشخيص الإشعارات", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(),
              Text(report, textAlign: TextAlign.right),
              if (!hasApns) ...[
                const SizedBox(height: 10),
                const Text(
                  "تحذير: مشكلة الـ APNS تعني أن CodeMagic لم يرفق ملف الـ Entitlements الصحيح. تأكد من وجود ملف Runner.entitlements في مشروعك.",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              if (token != null) ...[
                const SizedBox(height: 15),
                const Text("تم نسخ التوكين للحافظة تلقائياً:", style: TextStyle(color: Colors.green)),
                SelectableText(token, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Get.back(), child: const Text("إغلاق")),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.blueAccent,
      onPressed: _isChecking ? null : runFullCheck,
      child: _isChecking ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.flash_on),
    );
  }
}