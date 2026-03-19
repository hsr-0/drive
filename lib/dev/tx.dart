import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:vibration/vibration.dart';

// =============================================================================
// 🔑 BALANCE MANAGER (المصدر الوحيد للرصيد - احترافي V3)
// =============================================================================
// =============================================================================
// 🔑 BALANCE MANAGER (المصدر الوحيد للرصيد - احترافي V3)
// =============================================================================
// =============================================================================
// 🔑 BALANCE MANAGER (المصدر الوحيد للرصيد - احترافي V3)
// =============================================================================
class BalanceManager {
  static int _balance = 0;
  static String _token = '';
  static bool _isInitialized = false;

  // للمراقبة في الواجهة
  static final ValueNotifier<int> balanceNotifier = ValueNotifier<int>(0);

  // للإشعارات المحلية
  static final _localParams = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'balance_channel',
    'تنبيهات الرصيد',
    description: 'تنبيهات رصيد النقاط',
    importance: Importance.high,
  );

  // ✅ دالة أمان: تحول أي نوع بيانات إلى رقم صحيح
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  // ✅ التهيئة الأولية
  static Future<bool> initialize(String token) async {
    _token = token;
    try {
      await _initLocalNotifications();
      // نجبر التحديث عند الفتح
      _balance = await getPointsV3(token);
      _isInitialized = true;
      balanceNotifier.value = _balance;
      print("✅ BalanceManager initialized with $_balance points (V3 - AntiCache)");
      return _balance > 0;
    } catch (e) {
      print("⚠️ BalanceManager initialization failed: $e");
      _isInitialized = false;
      return false;
    }
  }

  // ✅ الدالة الأساسية لجلب الرصيد (معدلة لمنع الكاش)
  static Future<int> getPointsV3(String token) async {
    try {
      // 1. إضافة طابع زمني فريد لكسر الكاش (TimeStamp)
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // ملاحظة: تأكد من أن ApiService.baseUrl لا ينتهي بـ /
      final String url = '${ApiService.baseUrl}/taxi/v3/driver/hub?_t=$timestamp';
      final uri = Uri.parse(url);

      print("🔍 [DEBUG] Fetching balance (No-Cache): $uri");

      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          // 2. هيدرز إضافية لمنع السيرفر والوسيط من تخزين الاستجابة
          'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));

      print("🔍 [DEBUG] Status Code: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data['success'] == true) {
          dynamic rawBalance;

          // محاولة العثور على الرصيد في أماكن مختلفة محتملة في الاستجابة
          if (data['data'] != null && data['data']['wallet_balance'] != null) {
            rawBalance = data['data']['wallet_balance'];
          } else if (data['wallet_balance'] != null) {
            rawBalance = data['wallet_balance'];
          }

          final finalBalance = _safeInt(rawBalance);
          print("🔍 [DEBUG] Realtime Server Balance: $finalBalance");

          setCurrent(finalBalance);
          return finalBalance;
        }
      }
    } catch (e) {
      print("❌ [DEBUG] Error in getPointsV3: $e");
    }
    return _balance;
  }

  // ✅ تحديث الرصيد محلياً وتحديث الواجهة
  static void setCurrent(int newBalance) {
    if (_balance != newBalance) {
      _balance = newBalance;
      balanceNotifier.value = newBalance;
      _showBalanceAlert(newBalance);
    }
  }

  // ✅ خصم النقاط (تفاؤلي - يخصم فوراً في الواجهة)
  static Future<bool> deductOptimistic(int points) async {
    if (_balance >= points) {
      _balance -= points;
      balanceNotifier.value = _balance;
      return true;
    }
    return false;
  }

  // ✅ استرداد النقاط (في حال فشل الطلب)
  static void refund(int points) {
    _balance += points;
    balanceNotifier.value = _balance;
  }

  // ✅ تحديث الرصيد من السيرفر يدوياً
  static Future<void> refresh() async {
    if (_token.isEmpty) return;
    await getPointsV3(_token);
  }

  // ✅ معالجة تحديث الرصيد القادم من الإشعارات الخلفية
  static Future<void> handleBalanceUpdate(Map<String, dynamic> data) async {
    // نبحث عن الرصيد الجديد في البيانات القادمة من الإشعار
    final newBalanceRaw = data['new_balance'] ?? data['current_balance'];

    if (newBalanceRaw != null) {
      final newBalance = _safeInt(newBalanceRaw);
      // نقبل حتى الصفر (لأنه قد يكون تحديث بانتهاء الرصيد)
      if (newBalance >= 0) {
        setCurrent(newBalance);
        print("✅ Balance updated via notification payload: $newBalance");
      }
    } else {
      // إذا لم يكن الرصيد موجوداً في الإشعار، نطلبه من السيرفر
      await refresh();
    }
  }

  // 🔔 إعداد الإشعارات المحلية
  static Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettings = const InitializationSettings(android: android);
    await _localParams.initialize(initializationSettings);
    await _localParams
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // 🔔 منطق التنبيه عند انخفاض الرصيد
  static void _showBalanceAlert(int points) {
    if (points == 10 || points == 5 || points == 1) {
      _showLocalBalanceNotification(points);
    }
  }

  static void _showLocalBalanceNotification(int points) {
    String title = 'تنبيه رصيد';
    String body = '';
    int id = 1000 + points; // ID مميز لكل تنبيه

    switch (points) {
      case 10:
        body = 'متبقي لديك 10 نقاط فقط.';
        break;
      case 5:
        title = '🚨 رصيد منخفض جداً';
        body = 'متبقي 5 نقاط! اشحن الآن.';
        break;
      case 1:
        title = '🔴 آخر نقطة!';
        body = 'رصيدك يكفي لطلب واحد فقط.';
        break;
      default:
        return;
    }

    _localParams.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  // 📤 Getters للوصول السريع
  static int get current => _balance;
  static bool get hasBalance => _balance > 0;
  static bool get isInitialized => _isInitialized;
}





// =============================================================================
// PermissionService - إدارة أذونات الموقع
// =============================================================================
class PermissionService {
  /// التحقق من إذن الموقع وطلبه إذا لزم الأمر
  /// Returns: true إذا تم منح الإذن، false إذا تم رفضه
  static Future<bool> handleLocationPermission(BuildContext context) async {
    // 1. التحقق من تفعيل خدمات الموقع (GPS)
    bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تفعيل خدمات الموقع (GPS) من إعدادات الجهاز'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    // 2. التحقق من الإذن الحالي
    geolocator.LocationPermission permission = await geolocator.Geolocator.checkPermission();

    if (permission == geolocator.LocationPermission.denied) {
      // 3. طلب الإذن إذا كان مرفوضاً
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض إذن الوصول للموقع. لا يمكن متابعة الخدمة بدون الموقع.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }

    // 4. التحقق من الرفض النهائي (Denied Forever)
    if (permission == geolocator.LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من إعدادات التطبيق.'),
            backgroundColor: Colors.red,
          ),
        );
        // اختياري: فتح إعدادات التطبيق
        // await openAppSettings();
      }
      return false;
    }

    // 5. الإذن ممنوح بنجاح
    return true;
  }

  /// التحقق مما إذا كان لدينا إذن الموقع بالفعل
  static Future<bool> hasLocationPermission() async {
    final permission = await geolocator.Geolocator.checkPermission();
    return permission == geolocator.LocationPermission.whileInUse ||
        permission == geolocator.LocationPermission.always;
  }

  /// فتح إعدادات التطبيق لتمكين الإذن
  static Future<void> openLocationSettings() async {
    // ملاحظة: قد تحتاج لمكتبة مثل permission_handler لفتح الإعدادات
    print("يرجى فتح إعدادات الموقع يدوياً");
  }
}























// =============================================================================
// دوال مساعدة للوقت
// =============================================================================
String timeAgo(DateTime input) {
  final now = DateTime.now();
  final duration = now.difference(input);
  if (duration.inSeconds < 60) return 'الآن';
  if (duration.inMinutes < 60) return 'منذ ${duration.inMinutes} دقيقة';
  if (duration.inHours < 24) return 'منذ ${duration.inHours} ساعة';
  if (duration.inDays < 7) return 'منذ ${duration.inDays} يوم';
  if (duration.inDays < 30) {
    final weeks = (duration.inDays / 7).floor();
    return 'منذ $weeks أسبوع';
  }
  return '${input.day}/${input.month}/${input.year}';
}

String detailedTime(DateTime input) {
  return '${input.hour.toString().padLeft(2, '0')}:${input.minute.toString().padLeft(2, '0')} - ${input.day}/${input.month}';
}

// =============================================================================
// GLOBAL VARIABLES
// =============================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> orderRefreshCounter = ValueNotifier(0);
//final ValueNotifier<bool> refreshTrigger = ValueNotifier(false);

// =============================================================================
// MAIN ENTRY POINT
// ===


// =============================================================================
// MAIN ENTRY POINT
// =============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();

  // ❌ لا تضع DebugOverlay هنا
  runApp(const DeliveryApp());
}

// =============================================================================
// 🔥 التطبيق الرئيسي مع DebugOverlay
// =============================================================================
class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'كابتن توصيل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: Colors.grey[100],
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      // ✅ تم حذف builder: (context, child) => DebugOverlay(...)
      // الآن التطبيق يعمل بشكل مباشر ونظيف
      home: const AuthGate(),
    );
  }
}
// =============================================================================
// 🔍 أداة التشخيص العائمة (NotificationDebugger)
// =============================================================================
class NotificationDebugger {
  static bool _isInitialized = false;
  static OverlayEntry? _overlayEntry;
  static final ValueNotifier<bool> _isVisible = ValueNotifier(false);
  static final List<String> _logs = [];
  static String? _lastFcmToken;
  static bool _isTesting = false;

  static void initialize(BuildContext context) {
    if (_isInitialized) return;
    _isInitialized = true;
    _showFloatingButton(context);
    _refreshFcmToken();

    // الاستماع للإشعارات الواردة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _log('🔔 [Foreground] تلقى إشعار: ${message.notification?.title}');
      _log('📦 البيانات: ${message.data}');
      Vibration.vibrate(duration: 300);
    });
  }

  static void _showFloatingButton(BuildContext context) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 30,
        right: 20,
        child: ValueListenableBuilder<bool>(
          valueListenable: _isVisible,
          builder: (context, isVisible, child) {
            if (isVisible) return const SizedBox.shrink();

            return GestureDetector(
              onTap: () => _showDebuggerSheet(context),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.bug_report, color: Colors.white, size: 32),
              ),
            );
          },
        ),
      ),
    );

    Overlay.of(context)?.insert(_overlayEntry!);
  }

  static void _showDebuggerSheet(BuildContext context) {
    _isVisible.value = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _isVisible,
        builder: (context, _, child) {
          if (!_isVisible.value) return const SizedBox.shrink();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🔍 تشخيص الإشعارات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => _isVisible.value = false,
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // بطاقة التوكن
                _buildInfoCard(
                  title: 'FCM Token',
                  value: (_lastFcmToken != null && _lastFcmToken!.length > 15)
                      ? '${_lastFcmToken!.substring(0, 20)}...'
                      : (_lastFcmToken ?? 'غير موجود'),
                  status: _lastFcmToken != null ? 'success' : 'error',
                ),
                const SizedBox(height: 10),

                // بطاقة الرصيد
                _buildInfoCard(
                  title: 'الرصيد الحالي',
                  value: '${BalanceManager.current} نقطة',
                  status: BalanceManager.current > 0 ? 'success' : 'error',
                ),
                const SizedBox(height: 20),

                // أزرار الاختبار
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildTestButton(context, '🧪 فحص التوكن', _testFcmToken),
                    _buildTestButton(context, '🔊 اختبار الصوت', _testSound),
                    _buildTestButton(context, '📡 فحص السيرفر', _testServer),
                    _buildTestButton(context, '🌙 اختبار الخلفية', _testBackground),
                    _buildTestButton(context, '🧹 مسح السجل', _clearLogs),
                  ],
                ),
                const SizedBox(height: 20),

                // سجل الأحداث
                Expanded(
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final color = log.contains('✅') ? Colors.green :
                      log.contains('❌') ? Colors.red :
                      log.contains('⚠️') ? Colors.yellow : Colors.grey;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: color,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => _isVisible.value = false);
  }

  static Widget _buildInfoCard({
    required String title,
    required String value,
    required String status,
  }) {
    Color statusColor;
    switch (status) {
      case 'success': statusColor = Colors.green; break;
      case 'warning': statusColor = Colors.yellow; break;
      default: statusColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  static Widget _buildTestButton(BuildContext context, String label, VoidCallback onTap) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 60) / 2,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade800,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _isTesting ? null : onTap,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }

  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().split('.').first;
    _logs.insert(0, '[$timestamp] $message');
    if (_logs.length > 50) _logs.removeLast();
    print('DEBUG: $message');
  }

  static Future<void> _refreshFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      _lastFcmToken = token;
      _log(token != null
          ? '✅ FCM Token: ${token.toString().substring(0, 20)}...'
          : '❌ فشل جلب التوكن');
    } catch (e) {
      _log('❌ خطأ في جلب التوكن: $e');
    }
  }

  static Future<void> _testFcmToken() async {
    _isTesting = true;
    _log('🧪 بدء فحص التوكن...');
    await _refreshFcmToken();

    if (_lastFcmToken == null) {
      _log('❌ التوكن غير موجود - الحل: اخرج من التطبيق وأعد الدخول');
      _isTesting = false;
      return;
    }

    // إرسال التوكن للسيرفر
    final storedAuth = await ApiService.getStoredAuthData();
    if (storedAuth != null) {
      try {
        await ApiService.updateFcmToken(storedAuth.token, _lastFcmToken!);
        _log('✅ تم إرسال التوكن للسيرفر بنجاح');
      } catch (e) {
        _log('❌ فشل إرسال التوكن: $e');
      }
    }
    _isTesting = false;
  }

  static Future<void> _testSound() async {
    _log('🔊 اختبار الصوت والاهتزاز...');
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) Vibration.vibrate(duration: 500);
      _log('✅ نجاح: الصوت والاهتزاز يعملان');
    } catch (e) {
      _log('❌ فشل: $e');
    }
  }

  static Future<void> _testServer() async {
    _log('📡 فحص اتصال السيرفر...');
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty) {
        _log('✅ اتصال الإنترنت يعمل');
      } else {
        _log('❌ لا يوجد اتصال بالإنترنت');
        return;
      }
    } catch (_) {
      _log('❌ خطأ في اتصال الإنترنت');
      return;
    }

    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/taxi/v3/driver/hub'));
      if (res.statusCode == 200) {
        _log('✅ سيرفر التطبيق يعمل (الكود: 200)');
      } else {
        _log('❌ سيرفر التطبيق أرجع خطأ (الكود: ${res.statusCode})');
      }
    } catch (e) {
      _log('❌ خطأ في الاتصال بالسيرفر: $e');
    }
  }

  static Future<void> _testBackground() async {
    _log('🌙 اختبار الإشعارات في الخلفية...');
    _log('⚠️ 1. اضغط زر الرئيسية لوضع التطبيق في الخلفية');
    _log('⚠️ 2. انتظر 10 ثوانٍ');
    _log('⚠️ 3. سيظهر إشعار تجريبي');

    final storedAuth = await ApiService.getStoredAuthData();
    if (storedAuth == null) {
      _log('❌ لم يتم العثور على بيانات اعتماد');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/taxi/v3/test-notification'),
        headers: {
          'Authorization': 'Bearer ${storedAuth.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'fcm_token': _lastFcmToken,
        }),
      );

      if (response.statusCode == 200) {
        _log('✅ تم إرسال طلب الإشعار التجريبي للسيرفر');
        _log('📱 انتظر 10-20 ثانية لوصول الإشعار (حتى لو كان التطبيق مغلقاً)');
      } else {
        _log('❌ فشل إرسال الطلب: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ خطأ: $e');
    }
  }

  static void _clearLogs() {
    _logs.clear();
    _log('🧹 تم مسح السجلات');
  }
}

// =============================================================================
// 🔌 غلاف التشغيل الآلي للزر العائم (DebugOverlay)
// =============================================================================
class DebugOverlay extends StatefulWidget {
  final Widget child;
  const DebugOverlay({super.key, required this.child});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationDebugger.initialize(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// =============================================================================
// باقي الكود الأصلي (BalanceManager, NotificationService, ApiService, etc.)
// =============================================================================
// ... (ضع هنا باقي الكود من ملفك الأصلي دون تغيير) ...
// =============================================================================
// SERVICES
// =============================================================================
// =============================================================================
// 🔔 NOTIFICATION SERVICE (المصدر الوحيد لاستقبال الإشعارات - احترافي V3)
// =============================================================================
// =============================================================================
// 🔔 NOTIFICATION SERVICE (التعديل الهام هنا)
// =============================================================================
// =============================================================================
// 🔔 NOTIFICATION SERVICE (تم الإصلاح: سريع وفوري مع نظام الرصيد V3)
// =============================================================================
// =============================================================================
// 🔔 NOTIFICATION SERVICE (المصدر الوحيد لاستقبال الإشعارات - احترافي V3)
// =============================================================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localParams = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'beytei_urgent_call',
    'طلبات التوصيل العاجلة',
    description: 'تنبيهات صوتية عالية للطلبات الجديدة',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('woo_sound'),
    enableVibration: true,
  );

  static Future<void> initialize() async {
    // 1️⃣ طلب أذونات الإشعارات
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      criticalAlert: true,
    );

    // 2️⃣ تهيئة الإشعارات المحلية
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    await _localParams.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (payload) {
        if (payload.notificationResponseType == NotificationResponseType.selectedNotification) {
          _handleNotificationClick(payload);
        }
      },
    );

    // 3️⃣ إنشاء قناة أندرويد
    await _localParams
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4️⃣ 🔥 الاستماع للإشعارات الواردة (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      Map<String, dynamic> data = message.data;
      print("🔔 [NotificationService] Received: ${notification?.title} | Data: $data");

      // إظهار الإشعار فوراً
      String title = notification?.title ?? data['title'] ?? "🔔 طلب جديد!";
      String body = notification?.body ?? data['body'] ?? "يوجد طلب بالقرب منك، اضغط للفتح.";
      int notifId = notification?.hashCode ?? DateTime.now().millisecond;

      _localParams.show(
        notifId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('woo_sound'),
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: true,
            sound: 'woo_sound.caf',
          ),
        ),
      );

      // تشغيل الاهتزاز الفوري
      Vibration.hasVibrator().then((hasVib) {
        if (hasVib == true) Vibration.vibrate(duration: 500);
      });

      // تحديث قوائم الطلبات في الواجهة فوراً
      //refreshTrigger.value = !refreshTrigger.value;


// ✅ أضف هذا السطر (زيادة العداد تضمن التنبيه دائماً):
      orderRefreshCounter.value++;
      print("🔔 [SERVICE] 🔥 تم زيادة عداد التحديث إلى: ${orderRefreshCounter.value}");

      // معالجة الرصيد وعمليات السيرفر في الخلفية
      _handleBackgroundData(data);
    });

    // 5️⃣ الاستماع عند فتح التطبيق من الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🔔 [NotificationService] App opened from notification: ${message.data}");
    });

    // ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅
    // 🔥🔥🔥 التعديل الأهم: الاستماع لتجديد توكن FCM تلقائيًا 🔥🔥🔥
    // ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print("🔄 [TOKEN REFRESH] New FCM token generated: ${newToken.substring(0, 20)}...");

      final storedAuth = await ApiService.getStoredAuthData();
      if (storedAuth != null && storedAuth.token.isNotEmpty) {
        try {
          await ApiService.updateFcmToken(storedAuth.token, newToken);
          print("✅ [TOKEN REFRESH] New token saved to server successfully");
        } catch (e) {
          print("❌ [TOKEN REFRESH] Failed to update token: $e");
        }
      }
    });
    // ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅ ✅✅✅

    print("✅ NotificationService initialized successfully");
  }

  // ✅ دالة جديدة لمعالجة بيانات الرصيد في الخلفية بهدوء
  static Future<void> _handleBackgroundData(Map<String, dynamic> data) async {
    try {
      if (data['type'] == 'balance_update' || data['new_balance'] != null || data['current_balance'] != null) {
        await BalanceManager.handleBalanceUpdate(data);
      }

      await BalanceManager.refresh();

      // التحقق من الرصيد الصفري هنا (بعد أن ضمنّا أن الإشعار ظهر وعمل الصوت)
      if (BalanceManager.current == 0) {
        // تأخير بسيط لضمان رؤية السائق للإشعار قبل قفل الشاشة
        await Future.delayed(const Duration(seconds: 1));
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(
            builder: (_) => ZeroBalanceLockScreen(
              token: '',
              onRecharge: _recharge,
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ [NotificationService] Background Error: $e");
    }
  }

  static void _handleNotificationClick(NotificationResponse response) {
    if (response.payload == 'recharge') {
      _recharge();
    }
  }

  static void _recharge() {
    try {
      launchUrl(
        Uri.parse("https://wa.me/+9647854076931"),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print("Could not launch WhatsApp: $e");
    }
  }

  static Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print("Error getting FCM token: $e");
      return null;
    }
  }
}
class Helper {
  static double safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static Future<bool> handleLocationPermission(BuildContext context) async {
    bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تفعيل الموقع (GPS)')));
      return false;
    }
    var perm = await geolocator.Geolocator.checkPermission();
    if (perm == geolocator.LocationPermission.denied) {
      perm = await geolocator.Geolocator.requestPermission();
      if (perm == geolocator.LocationPermission.denied) return false;
    }
    return perm != geolocator.LocationPermission.deniedForever;
  }
}

class AuthResult {
  final String token, userId, displayName;
  final bool isDriver;
  final String? driverStatus;
  final int points;

  AuthResult({
    required this.token,
    required this.userId,
    required this.displayName,
    required this.isDriver,
    this.driverStatus,
    this.points = 0,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: json['token'],
    userId: json['user_id'].toString(),
    displayName: json['display_name'],
    isDriver: json['is_driver'] ?? false,
    driverStatus: json['driver_status'],
    points: json['points'] ?? 0,
  );
}
class Order {
  final String id;
  final String? orderStatus;
  final String pickupLocationName;
  final String? pickupLat;
  final String? pickupLng;
  final String destinationAddress;
  final String? destinationLat;
  final String? destinationLng;
  final int deliveryFee;
  final String dateCreated;
  final String itemsDescription;
  final String? notes;
  final String? customerPhone;
  final String? pickupCode;
  final String? sourceType;
  final String? driver;

  Order({
    required this.id,
    this.orderStatus,
    required this.pickupLocationName,
    this.pickupLat,
    this.pickupLng,
    required this.destinationAddress,
    this.destinationLat,
    this.destinationLng,
    required this.deliveryFee,
    required this.dateCreated,
    required this.itemsDescription,
    this.notes,
    this.customerPhone,
    this.pickupCode,
    this.sourceType,
    this.driver,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      orderStatus: json['order_status'],
      pickupLocationName: json['pickup_location_name'] ?? '',
      pickupLat: json['pickup_lat'],
      pickupLng: json['pickup_lng'],
      destinationAddress: json['destination_address'] ?? '',
      destinationLat: json['destination_lat'],
      destinationLng: json['destination_lng'],
      deliveryFee: json['delivery_fee'] ?? 0,
      dateCreated: json['date_created'] ?? '',
      itemsDescription: json['items_description'] ?? '',
      notes: json['notes'],
      customerPhone: json['end_customer_phone'],
      pickupCode: json['pickup_code'],
      sourceType: json['source_type'],
      driver: json['driver'],
    );
  }
}

class ApiService {
  static const String baseUrl = 'https://banner.beytei.com/wp-json';
  static const _storage = FlutterSecureStorage();



  static Future<void> storeAuthData(AuthResult auth) async {
    await _storage.write(key: 'token', value: auth.token);
    await _storage.write(key: 'uid', value: auth.userId);
    await _storage.write(key: 'name', value: auth.displayName);
    await _storage.write(key: 'status', value: auth.driverStatus);
    await _storage.write(key: 'points', value: auth.points.toString());
  }
  static Future<AuthResult?> getStoredAuthData() async {
    try {
      final t = await _storage.read(key: 'token');
      final u = await _storage.read(key: 'uid');
      final n = await _storage.read(key: 'name');
      final s = await _storage.read(key: 'status');
      final p = await _storage.read(key: 'points') ?? '0';
      if (t != null && u != null)
        return AuthResult(
          token: t,
          userId: u,
          displayName: n ?? '',
          isDriver: true,
          driverStatus: s,
          points: int.tryParse(p) ?? 0,
        );
    } catch (e) {
      await _storage.deleteAll();
    }
    return null;
  }

  static Future<void> logout() async {
    await _storage.deleteAll();
    await fb_auth.FirebaseAuth.instance.signOut();
  }

  static Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/taxi-auth/v1/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone_number': phone, 'password': password}),
      );
      return json.decode(res.body);
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }
  // استخدام الإصدار 3 لقبول الطلب
  static Future<void> acceptOrderV3(String token, String orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/taxi/v3/delivery/accept'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: json.encode({'order_id': orderId}),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'فشل في قبول الطلب');
    }

    final data = json.decode(response.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'فشل في قبول الطلب');
    }
  }

  // استخدام الإصدار 3 لجلب الطلبات المتاحة
  static Future<List<Order>> getAvailableOrdersV3(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/taxi/v3/delivery/available'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('فشل في جلب الطلبات');
    }

    final data = json.decode(response.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'فشل في جلب الطلبات');
    }

    return (data['orders'] as List)
        .map((item) => Order.fromJson(item))
        .toList();
  }
  static Future<void> updateFcmToken(String token, String fcmToken) async {
    try {
      print("📡 [FCM Update] Sending to server: ${fcmToken.substring(0, 20)}...");

      // ✅ تصحيح الرابط ليطابق السيرفر (taxi-auth/v1/update-fcm-token)
      final response = await http.post(
        Uri.parse('$baseUrl/taxi-auth/v1/update-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token' // ضروري لأن السيرفر يطلب taxi_api_permission_check
        },
        body: json.encode({
          'fcm_token': fcmToken,
        }),
      ).timeout(const Duration(seconds: 10));

      // طباعة النتيجة للمراقبة
      if (response.statusCode == 200) {
        print("✅ [FCM Update] Success: Token updated on server.");
      } else {
        print("❌ [FCM Update] Server Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ [FCM Update] Exception: $e");
    }
  }
  static Future<Map<String, dynamic>> registerDriverV3(Map<String, String> fields, Map<String, XFile> files) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/taxi-auth/v3/register/driver'));
      request.fields.addAll(fields);
      for (var entry in files.entries) {
        request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path));
      }
      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      return json.decode(res.body);
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  // 🔥 دالة الطلبات فقط (أسرع - لا تطلب النقاط)
// في ملف ApiService
  static Future<Map<String, dynamic>> getAvailableDeliveriesOnly(String t) async {
    try {
      // 🔥 1. إضافة طابع زمني لكسر الكاش (ضروري جداً للتحديث الفوري)
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final res = await http.get(
        // 🔥 2. إضافة الطابع الزمني للرابط ليصبح فريداً في كل طلب
        Uri.parse('$baseUrl/taxi/v3/delivery/available?_t=$timestamp'),
        headers: {
          'Authorization': 'Bearer $t',
          // 🔥 3. هيدرز إجبارية لمنع تخزين الاستجابة (Force No-Cache)
          'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
        },
      );

      // 🔥 طباعة حالة الاستجابة للتشخيص
      print('📡 [API DEBUG] Status Code: ${res.statusCode}');

      // 🔥 فحص إذا كانت الاستجابة HTML بدلاً من JSON
      if (res.body.trim().startsWith('<!DOCTYPE') || res.body.trim().startsWith('<html')) {
        print('❌ [API ERROR] Server returned HTML instead of JSON!');
        return {
          'success': false,
          'message': 'خطأ في السيرفر (استجابة HTML)',
          'orders': []
        };
      }

      final data = json.decode(res.body);

      if (res.statusCode == 403) {
        return {
          'success': false,
          'error': 'low_balance',
          'message': data['message'] ?? 'رصيد منخفض',
        };
      }

      if (res.statusCode == 200) {
        return {
          'success': true,
          'orders': data['orders'] ?? [],
        };
      }

      // أي كود حالة آخر يعتبر خطأ
      return {
        'success': false,
        'message': 'خطأ في الاتصال (${res.statusCode})',
        'orders': []
      };

    } catch (e) {
      print("❌ [API EXCEPTION] Error fetching orders: $e");
      // 🔥 العودة بـ success: false ليتمكن التطبيق من معالجة الخطأ
      return {
        'success': false,
        'message': 'فشل في الاتصال: ${e.toString()}',
        'orders': []
      };
    }
  }
  static Future<Map<String, dynamic>> acceptDeliveryV3(String t, String id, {int fee = 1}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/taxi/v3/delivery/accept'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
        body: json.encode({
          'order_id': id,
          'fee': fee,
          'driver_post_id': id,
        }),
      );
      return json.decode(res.body);
    } catch (e) {
      print("Error accepting delivery: $e");
      return {'success': false, 'message': 'فشل في قبول الطلب'};
    }
  }

  static Future<Map<String, dynamic>?> getMyActiveDelivery(String t) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/taxi/v3/driver/my-active-delivery'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        if (d['success'] == true) return d['delivery_order'];
      }
    } catch (_) {}
    return null;
  }
  static Future<http.Response> updateDeliveryStatus(String t, String id, String s) => http.post(
    Uri.parse('$baseUrl/taxi/v3/delivery/update-status'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
    body: json.encode({'order_id': id, 'status': s}),
  );

  static Future<void> updateDriverLocation(String t, double lat, double lng) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/taxi/v3/driver/update-location'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
        body: json.encode({'lat': lat, 'lng': lng}),
      );
    } catch (_) {}
  }

// 🔥 دالة مخصصة لتحديث النقاط فقط (نسخة V3 - آمنة ومصححة)
  static Future<int> getPoints(String t) async {
    try {
      // 🔥 1. إضافة طابع زمني لكسر الكاش
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final res = await http.get(
        // 🔥 2. إضافة الطابع الزمني للرابط
        Uri.parse('$baseUrl/taxi/v3/driver/hub?_t=$timestamp'),
        headers: {
          'Authorization': 'Bearer $t',
          // 🔥 3. هيدرز منع الكاش الإجبارية
          'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          final val = data['data']['wallet_balance'];
          if (val is int) return val;
          if (val is double) return val.toInt();
          if (val is String) {
            return int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          }
        }
      }
    } catch (e) {
      print("❌ Error: $e");
    }
    return 0;
  }
  static Future<List<dynamic>> getHistoryV3(String t) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/taxi/v3/driver/history'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        return d['history'] ?? [];
      }
    } catch (_) {}
    return [];
  }
}

// =============================================================================
// 🎨 شاشة الفحص الأولى (عصري وحديث)
// =============================================================================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthResult? _auth;
  bool _isLoading = true;
  bool _hasBalance = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // ✅ إضافة مستمع لتحديث الشاشة تلقائياً عند تغير الرصيد
    BalanceManager.balanceNotifier.addListener(_onBalanceChanged);
  }

  // دالة جديدة للتعامل مع تغير الرصيد
  void _onBalanceChanged() {
    if (mounted) {
      setState(() {
        _hasBalance = BalanceManager.hasBalance;
      });
      print("🔄 [AuthGate] Balance changed: $_hasBalance");
    }
  }

  @override
  void dispose() {
    // ✅ تنظيف المستمع لمنع تسرب الذاكرة
    BalanceManager.balanceNotifier.removeListener(_onBalanceChanged);
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. تسجيل الدخول المجهول (سريع جداً)
      if (fb_auth.FirebaseAuth.instance.currentUser == null) {
        try {
          await fb_auth.FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 3));
        } catch (_) {}
      }

      // 2. جلب بيانات التخزين المحلي
      final storedAuth = await ApiService.getStoredAuthData();
      if (storedAuth == null) {
        if (mounted) setState(() {
          _auth = null;
          _isLoading = false;
        });
        return;
      }

      // 3. 🔥 الفحص المركزي للرصيد (قبل عرض أي شاشة)
      _hasBalance = await BalanceManager.initialize(storedAuth.token);

      // ✅✅✅ 4. تحديث FCM Token فوراً (مع معالجة الأخطاء والتسجيل) ✅✅✅
      try {
        final fcm = await NotificationService.getFcmToken();
        if (fcm != null && fcm.isNotEmpty) {
          // تحديث التوكن في السيرفر مع الانتظار للتأكد من النجاح
          await ApiService.updateFcmToken(storedAuth.token, fcm);
          print("✅ [AuthGate] FCM Token updated successfully: ${fcm.substring(0, 20)}...");
        } else {
          print("⚠️ [AuthGate] FCM Token is null or empty, will retry later");
        }
      } catch (e) {
        print("❌ [AuthGate] Failed to update FCM Token: $e");
        // لا نوقف التطبيق إذا فشل تحديث التوكن
      }

      // 5. تخزين بيانات المصادقة وتحديث الواجهة
      if (mounted) setState(() {
        _auth = storedAuth;
        _isLoading = false;
      });

    } catch (e) {
      print("AuthGate initialization error: $e");
      if (mounted) setState(() {
        _auth = null;
        _isLoading = false;
      });
    }
  }

  void _recharge() {
    launchUrl(
      Uri.parse("https://wa.me/+9647854076931"),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 شاشة فحص عصري وحديث
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔥 Spinner حديث ومتطور
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.white.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF667eea),
                        ),
                        strokeWidth: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // 🔥 نص عصري
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    'جارٍ فحص حسابك...\nانتظر لحظات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // 🔥 مؤشر تقدم بصري
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // 🔥 رسالة ثانوية
                Text(
                  'نعمل على توفير أفضل تجربة لك',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // حالة 1: لا يوجد بيانات اعتماد
    if (_auth == null) return const DriverAuthGate();

    // حالة 2: الحساب غير معتمد
    if (_auth!.driverStatus != 'approved')
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, size: 60, color: Colors.orange),
              const SizedBox(height: 20),
              const Text("الحساب قيد المراجعة"),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await ApiService.logout();
                  setState(() => _auth = null);
                },
                child: const Text("خروج"),
              )
            ],
          ),
        ),
      );

    // 🔥 حالة 3: الرصيد = 0 → شاشة الإيقاف الفوري
    // ✅ الآن: إذا تغير الرصيد، _onBalanceChanged ستعيد بناء الشاشة فوراً
    if (!_hasBalance) {
      return ZeroBalanceLockScreen(
        token: _auth!.token,
        onRecharge: _recharge,
      );
    }

    // 🔥 حالة 4: كل شيء طبيعي → الواجهة الرئيسية
    return MainDeliveryLayout(
      authResult: _auth!,
      onLogout: () async {
        await ApiService.logout();
        setState(() => _auth = null);
      },
    );
  }
}
// =============================================================================
// شاشة إيقاف الحساب عند 0 نقاط (محسّنة وصحيحة)
// =============================================================================
class ZeroBalanceLockScreen extends StatelessWidget {
  final String token;
  final VoidCallback onRecharge;
  const ZeroBalanceLockScreen({super.key, required this.token, required this.onRecharge,});

  // 🔥 زر "تم الشحن؟" يعيد فحص الرصيد من السيرفر مباشرة
// في ملف main.dart - داخل كلاس ZeroBalanceLockScreen
  Future<void> _refreshBalance(BuildContext context) async {
    try {
      // 1. تحديث الرصيد من السيرفر
      await BalanceManager.refresh();

      // 2. الانتظار قليلاً لضمان اكتمال التحديث
      await Future.delayed(const Duration(milliseconds: 300));

      // 3. التحقق من الرصيد الجديد
      if (BalanceManager.hasBalance) {
        // ✅ الحل: إعادة توجيه كامل بدلاً من pop فقط
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AuthGate(), // إعادة تهيئة AuthGate من الصفر
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ تم شحن المحفظة بنجاح!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ الرصيد لا يزال منخفضًا. يرجى الشحن مرة أخرى"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ فشل في تحديث الرصيد: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.credit_card, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                'رصيدك ${BalanceManager.current} نقطة',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    const Text(
                      "لقد نفذت نقاطك",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "للاستمرار في قبول الطلبات، عليك شحن محفظتك",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onRecharge,
                      icon: const Icon(Icons.phone, color: Colors.green),
                      label: const Text(
                        "شحن عبر واتساب",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () => _refreshBalance(context),
                      child: const Text(
                        "تم الشحن؟ اضغط للتحديث",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// =============================================================================
// AUTH SYSTEM
// =============================================================================
class DriverAuthGate extends StatefulWidget {
  const DriverAuthGate({super.key});

  @override
  State<DriverAuthGate> createState() => _DriverAuthGateState();
}

class _DriverAuthGateState extends State<DriverAuthGate> {
  bool _isLogin = true;
  void _toggle() => setState(() => _isLogin = !_isLogin);

  void _onSuccess(AuthResult a) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainDeliveryLayout(
          authResult: a,
          onLogout: () async {
            await ApiService.logout();
            setState(() {});
          },
        ),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) =>
      _isLogin ? DriverLogin(onToggle: _toggle, onSuccess: _onSuccess) : DriverRegisterV3(onToggle: _toggle);
}

class DriverLogin extends StatefulWidget {
  final VoidCallback onToggle;
  final Function(AuthResult) onSuccess;
  const DriverLogin({super.key, required this.onToggle, required this.onSuccess});

  @override
  State<DriverLogin> createState() => _DriverLoginState();
}

class _DriverLoginState extends State<DriverLogin> {
  final p = TextEditingController(), pass = TextEditingController();
  bool _load = false;

  Future<void> _go() async {
    setState(() => _load = true);

    try {
      final res = await ApiService.login(p.text, pass.text);

      setState(() => _load = false);

      if (res['success'] == true) {
        final a = AuthResult.fromJson(res);

        if (res['is_driver'] == true) {
          // 1. حفظ بيانات المصادقة محلياً
          await ApiService.storeAuthData(a);

          // ✅✅✅ 2. تحديث FCM Token فوراً بعد تسجيل الدخول (مع معالجة الأخطاء) ✅✅✅
          try {
            final fcm = await NotificationService.getFcmToken();

            if (fcm != null && fcm.isNotEmpty) {
              // استخدام await لضمان اكتمال التحديث قبل المتابعة
              await ApiService.updateFcmToken(a.token, fcm);
              print("✅ [Login] FCM Token updated successfully: ${fcm.substring(0, 20)}...");
            } else {
              print("⚠️ [Login] FCM Token is null or empty, will retry on next app start");
            }
          } catch (e) {
            // لا نوقف التطبيق إذا فشل تحديث التوكن، لكن نسجل الخطأ
            print("❌ [Login] Failed to update FCM Token: $e");
          }

          // 3. الانتقال للشاشة الرئيسية
          widget.onSuccess(a);

        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ليس حساب سائق'))
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'فشل تسجيل الدخول'))
        );
      }
    } catch (e) {
      setState(() => _load = false);
      print("❌ [Login] Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping, size: 80, color: Colors.indigo),
            const SizedBox(height: 30),
            TextField(
              controller: p,
              decoration: const InputDecoration(labelText: "رقم الهاتف", prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: pass,
              decoration: const InputDecoration(labelText: "كلمة المرور", prefixIcon: Icon(Icons.lock)),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _load ? null : _go,
                child: _load
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("دخول"),
              ),
            ),
            TextButton(
                onPressed: widget.onToggle,
                child: const Text("ليس لديك حساب؟ سجل الآن")
            ),
          ],
        ),
      ),
    );
  }
}
class DriverRegisterV3 extends StatefulWidget {
  final VoidCallback onToggle;
  const DriverRegisterV3({super.key, required this.onToggle});

  @override
  State<DriverRegisterV3> createState() => _DriverRegisterV3State();
}

class _DriverRegisterV3State extends State<DriverRegisterV3> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      pass = TextEditingController(),
      model = TextEditingController(),
      color = TextEditingController();
  String vType = 'Car';
  XFile? imgReg, imgId, imgSelfie, imgRes;
  bool _load = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pick(String type) async {
    final f = await _picker.pickImage(
      source: type == 'selfie' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 60,
    );
    if (f != null)
      setState(() {
        if (type == 'reg') imgReg = f;
        if (type == 'id') imgId = f;
        if (type == 'selfie') imgSelfie = f;
        if (type == 'res') imgRes = f;
      });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (imgReg == null || imgId == null || imgSelfie == null || imgRes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب رفع جميع الصور الأربعة')));
      return;
    }
    setState(() => _load = true);
    final fields = {
      'name': name.text,
      'phone': phone.text,
      'password': pass.text,
      'vehicle_type': vType,
      'car_model': model.text,
      'car_color': color.text
    };
    final files = {
      'vehicle_registration_image': imgReg!,
      'personal_id_image': imgId!,
      'selfie_image': imgSelfie!,
      'residence_card_image': imgRes!
    };
    final res = await ApiService.registerDriverV3(fields, files);
    setState(() => _load = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم التسجيل بنجاح! انتظر الموافقة.'),
        backgroundColor: Colors.green,
      ));
      widget.onToggle();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'فشل'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل سائق جديد (V3)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: "الاسم الكامل"),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: "الهاتف"),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: pass,
                decoration: const InputDecoration(labelText: "كلمة المرور"),
                obscureText: true,
                validator: (v) => v!.length < 6 ? "قصيرة جداً" : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                value: vType,
                items: const [
                  DropdownMenuItem(value: 'Car', child: Text('دراجة')),
                  DropdownMenuItem(value: 'Tuktuk', child: Text('تكتك')),
                ],
                onChanged: (v) => setState(() => vType = v!),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: model,
                decoration: const InputDecoration(labelText: "موديل المركبة"),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: color,
                decoration: const InputDecoration(labelText: "اللون"),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 20),
              const Text(
                "المستمسكات المطلوبة",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _imgBtn("السنوية", imgReg, () => _pick('reg')),
                  _imgBtn("الهوية", imgId, () => _pick('id')),
                  _imgBtn("السيلفي", imgSelfie, () => _pick('selfie')),
                  _imgBtn("بطاقة السكن", imgRes, () => _pick('res')),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _load ? null : _submit,
                  child: _load ? const CircularProgressIndicator(color: Colors.white) : const Text("إرسال الطلب"),
                ),
              ),
              TextButton(onPressed: widget.onToggle, child: const Text("لديك حساب؟ سجل دخول")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgBtn(String t, XFile? f, VoidCallback tap) => InkWell(
    onTap: tap,
    child: Container(
      decoration: BoxDecoration(
        color: f != null ? Colors.green[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            f != null ? Icons.check_circle : Icons.camera_alt,
            color: f != null ? Colors.green : Colors.grey,
          ),
          Text(t),
        ],
      ),
    ),
  );
}

// =============================================================================
// MAIN LAYOUT
// =============================================================================
// =============================================================================
// MAIN LAYOUT
// =============================================================================
// =============================================================================
// MAIN LAYOUT - الإصدار النهائي (مع orderRefreshCounter)
// =============================================================================
class MainDeliveryLayout extends StatefulWidget {
  final AuthResult authResult;
  final VoidCallback onLogout;
  const MainDeliveryLayout({super.key, required this.authResult, required this.onLogout});

  @override
  State<MainDeliveryLayout> createState() => _MainDeliveryLayoutState();
}

class _MainDeliveryLayoutState extends State<MainDeliveryLayout> {
  int _idx = 0;
  Map<String, dynamic>? _active;
  Timer? _locationTimer;
  bool _isRefreshingOrders = false;

  // ✅ مفاتيح ثابتة للحفاظ على حالة الشاشات الفرعية
  static const _deliveriesKey = ValueKey('deliveries_screen');
  static const _historyKey = ValueKey('history_screen');
  static const _pointsKey = ValueKey('points_screen');
  static const _currentDeliveryKey = ValueKey('current_delivery_screen');

  @override
  void initState() {
    super.initState();
    print("🔹 [MAIN-LAYOUT] initState: تهيئة الواجهة الرئيسية");

    _chk();
    _startLocationTracking();

    // 🔥🔥🔥 الحل النهائي: الاستماع للعداد الرقمي بدلاً من refreshTrigger
    orderRefreshCounter.addListener(_handleGlobalRefresh);
    print("🔹 [MAIN-LAYOUT] ✅ تم إضافة مستمع لـ orderRefreshCounter");
  }

  @override
  void dispose() {
    _locationTimer?.cancel();

    // 🔥 إزالة المستمع من العداد الجديد
    orderRefreshCounter.removeListener(_handleGlobalRefresh);
    print("🔹 [MAIN-LAYOUT] dispose: تنظيف مستمع orderRefreshCounter");

    super.dispose();
  }

  // 🔥 دالة معالجة التحديث العالمي (لجلب الطلب النشط)
  void _handleGlobalRefresh() {
    print("🔔 [MAIN-LAYOUT] 🔄 وصل تحديث عالمي، جاري فحص الطلب النشط...");
    if (mounted) _chk();
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_active != null && _idx == 0) {
        try {
          final position = await geolocator.Geolocator.getCurrentPosition(
            desiredAccuracy: geolocator.LocationAccuracy.high,
          );
          ApiService.updateDriverLocation(widget.authResult.token, position.latitude, position.longitude);
        } catch (_) {}
      }
    });
  }

  Future<void> _chk() async {
    final o = await ApiService.getMyActiveDelivery(widget.authResult.token);
    if (mounted) setState(() => _active = o);
  }

  // 🔥 عند قبول الطلب - الانتقال الفوري لشاشة الطلب النشط
  void _onDeliveryAccepted(Map<String, dynamic> order) {
    print("✅ [MAIN-LAYOUT] 🎯 تم قبول طلب جديد، الانتقال للشاشة النشطة");
    setState(() {
      _active = order;
      _idx = 0;
    });
    BalanceManager.refresh();
  }

  // 🔥 عند انتهاء الطلب
  void _handleDeliveryFinished() {
    print("✅ [MAIN-LAYOUT] 🏁 انتهى الطلب النشط، جاري التحديث");
    setState(() {
      _active = null;
    });
    BalanceManager.refresh();

    // 🔥🔥🔥 الحل النهائي: زيادة العداد بدلاً من عكس القيمة
    orderRefreshCounter.value++;
    print("🔔 [MAIN-LAYOUT] 🔥 تم زيادة orderRefreshCounter إلى: ${orderRefreshCounter.value}");
  }

  @override
  Widget build(BuildContext context) {
    print("🎨 [MAIN-LAYOUT] 🔄 إعادة بناء الواجهة الرئيسية، _idx=$_idx, _active=${_active != null ? 'نعم' : 'لا'}");

    final pages = [
      // الصفحة 0: إما طلب جاري أو قائمة الطلبات
      _active != null
          ? DriverCurrentDeliveryScreen(
        key: _currentDeliveryKey, // ✅ مفتاح للحفاظ على الحالة
        initialDelivery: _active!,
        authResult: widget.authResult,
        onDeliveryFinished: _handleDeliveryFinished,
        onDataChanged: _chk,
      )
          : DriverAvailableDeliveriesV3Screen(
        key: _deliveriesKey, // ✅ هذا هو التعديل الأهم: يمنع إعادة تهيئة الشاشة
        authResult: widget.authResult,
        onDeliveryAccepted: _onDeliveryAccepted,
        onRefresh: _chk,
      ),
      // الصفحة 1: السجل
      HistoryTabV3(
        key: _historyKey, // ✅ مفتاح للحفاظ على الحالة
        token: widget.authResult.token,
        onOpenActive: (order) {
          print("🔹 [MAIN-LAYOUT] 📂 فتح طلب من السجل: #${order['id']}");
          setState(() {
            _active = order;
            _idx = 0;
          });
        },
      ),
      // الصفحة 2: الحساب
      PointsTab(
        key: _pointsKey, // ✅ مفتاح للحفاظ على الحالة
        token: widget.authResult.token,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _idx == 0
              ? (_active != null ? "طلب جاري" : "الطلبات")
              : (_idx == 1 ? "السجل" : "حسابي"),
        ),
        actions: [
          if (_idx == 0 && _active == null)
            IconButton(
              icon: _isRefreshingOrders
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.refresh),
              onPressed: () async {
                print("🔄 [MAIN-LAYOUT] 🔄 ضغط على زر التحديث اليدوي");
                setState(() => _isRefreshingOrders = true);

                // 🔥🔥🔥 الحل النهائي: زيادة العداد بدلاً من عكس القيمة
                orderRefreshCounter.value++;
                print("🔔 [MAIN-LAYOUT] 🔥 تم زيادة orderRefreshCounter يدوياً إلى: ${orderRefreshCounter.value}");

                await Future.delayed(const Duration(seconds: 2));
                if (mounted) setState(() => _isRefreshingOrders = false);
              },
            ),
          if (_idx == 0 && _active == null) _buildBalanceWidget(),
          if (_idx != 0 || _active != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                print("🔄 [MAIN-LAYOUT] 🔄 تحديث الطلب النشط يدوياً");
                _chk();
              },
            ),
        ],
      ),
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) {
          print("🔹 [MAIN-LAYOUT] 📱 تغيير التبويب إلى: $i");
          setState(() => _idx = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "الرئيسية"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "السجل"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "حسابي"),
        ],
      ),
    );
  }

  Widget _buildBalanceWidget() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, size: 18, color: Colors.amber),
          const SizedBox(width: 4),
          ValueListenableBuilder<int>(
            valueListenable: BalanceManager.balanceNotifier,
            builder: (context, balance, child) {
              return Text('$balance', style: const TextStyle(fontWeight: FontWeight.bold));
            },
          ),
        ],
      ),
    );
  }
}





















// =============================================================================



// شاشة الطلبات المتاحة (محسّنة)
// =============================================================================

// =============================================================================
// شاشة الطلبات المتاحة (بدون تحديث تلقائي + تحديث يدوي محسّن)
// =============================================================================
// =============================================================================
// شاشة الطلبات المتاحة (خصم 1 نقطة فقط + إصلاح الوقت والتفاصيل)
// =============================================================================
// =============================================================================
// 🔥 إصلاح شاشة الطلبات المتاحة (بدون شاشة سوداء)
// =============================================================================
// =============================================================================
// شاشة الطلبات المتاحة (محسّنة)
// =============================================================================
// شاشة الطلبات المتاحة V3 (محسّنة + تشخيص مطبوع)
// =============================================================================
class DriverAvailableDeliveriesV3Screen extends StatefulWidget {
  final AuthResult authResult;
  final Function(Map<String, dynamic>) onDeliveryAccepted;
  final VoidCallback onRefresh;

  // ✅ المفتاح ضروري للحفاظ على الحالة عند إعادة بناء الأب
  const DriverAvailableDeliveriesV3Screen({
    super.key, // <--- هذا هو التعديل الأهم
    required this.authResult,
    required this.onDeliveryAccepted,
    required this.onRefresh,
  });

  @override
  State<DriverAvailableDeliveriesV3Screen> createState() =>
      _DriverAvailableDeliveriesV3ScreenState();
}

class _DriverAvailableDeliveriesV3ScreenState extends State<DriverAvailableDeliveriesV3Screen> {
  List<dynamic> _ordersList = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;
  Set<String> _newOrderIds = {};
  final int _costInPoints = 1;
  bool _isProcessingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadDataSafe(isInitial: true);
    orderRefreshCounter.addListener(_handleNotification);
    BalanceManager.balanceNotifier.addListener(() {
      if (mounted && _isFirstLoad) setState(() => _isFirstLoad = false);
    });
  }

  @override
  void dispose() {
    orderRefreshCounter.removeListener(_handleNotification);
    super.dispose();
  }

  Future<void> _handleNotification() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await _loadDataSafe(isSilent: true);
      Vibration.vibrate(duration: 100);
    }
  }

  Future<void> _loadDataSafe({bool isInitial = false, bool isSilent = false}) async {
    if (!mounted) return;
    if (isInitial) setState(() => _isFirstLoad = true);
    if (!isInitial && !isSilent) setState(() => _isLoading = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final result = await ApiService.getAvailableDeliveriesOnly(widget.authResult.token);

      if (!mounted) return;

      if (result['success'] == true) {
        final dynamic ordersRaw = result['orders'];
        final List<dynamic> newOrders = (ordersRaw is List) ? ordersRaw : [];

        if (_ordersList.isNotEmpty && newOrders.isNotEmpty) {
          final currentIds = _ordersList.map((o) => o['id'].toString()).toSet();
          final incomingIds = newOrders.map((o) => o['id'].toString()).toSet();
          final newlyAdded = Set<String>.from(incomingIds.difference(currentIds));
          if (newlyAdded.isNotEmpty) _newOrderIds = newlyAdded;
        }

        newOrders.sort((a, b) {
          try {
            final dateA = DateTime.tryParse(a['date_created']?.toString() ?? '') ?? DateTime.now();
            final dateB = DateTime.tryParse(b['date_created']?.toString() ?? '') ?? DateTime.now();
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });

        setState(() {
          _ordersList = newOrders;
          _isLoading = false;
          _isFirstLoad = false;
        });

      } else {
        if (!isSilent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'فشل جلب الطلبات'), backgroundColor: Colors.red));
        }
        if (mounted && _ordersList.isEmpty) setState(() => _ordersList = []);
      }
    } catch (e) {
      if (!isSilent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; _isFirstLoad = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!BalanceManager.isInitialized) return const Center(child: CircularProgressIndicator());

    if (BalanceManager.current < _costInPoints) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 60, color: Colors.red),
            const SizedBox(height: 20),
            const Text("رصيدك منتهي", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("يتطلب $_costInPoints نقطة لقبول الطلبات"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse("https://wa.me/+9647854076931"), mode: LaunchMode.externalApplication),
              child: const Text("شحن الرصيد"),
            ),
          ],
        ),
      );
    }

    if (_isFirstLoad) return const Center(child: CircularProgressIndicator());

    if (_ordersList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 60, color: Colors.grey),
            const SizedBox(height: 15),
            const Text("لا توجد طلبات متاحة حالياً"),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _loadDataSafe, icon: const Icon(Icons.refresh), label: const Text("تحديث")),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[200],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("الطلبات المتاحة: ${_ordersList.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_isLoading) const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
              else InkWell(onTap: _loadDataSafe, child: const Icon(Icons.refresh, size: 20)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => await _loadDataSafe(),
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _ordersList.length,
              itemBuilder: (context, index) => _buildOrderCard(_ordersList[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = order['id'].toString();
    final isNew = _newOrderIds.contains(id);
    final shopName = order['pickup_location_name']?.toString() ?? 'المتجر';
    final address = order['destination_address']?.toString() ?? 'العنوان';
    final deliveryFee = order['delivery_fee']?.toString() ?? '---';

    return Card(
      elevation: isNew ? 8 : 2,
      shadowColor: isNew ? Colors.green.withOpacity(0.5) : Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: isNew ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.storefront, color: Colors.indigo, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Row(children: [const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(_calculateTimeAgo(order['date_created']), style: const TextStyle(fontSize: 12, color: Colors.blueGrey))]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(deliveryFee, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(address, style: const TextStyle(fontSize: 14, color: Colors.black87), maxLines: 2)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDetailsDialog(order, deliveryFee),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text("التفاصيل", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: Colors.indigo, side: const BorderSide(color: Colors.indigo)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text("قبول الطلب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                    onPressed: _isProcessingOrder || BalanceManager.current < _costInPoints ? null : () => _acceptDelivery(id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 💡 دالة لترجمة الأوزان الكسرية إلى نصوص عربية مفهومة
  String _formatFractionWeight(String qtyStr) {
    double? qty = double.tryParse(qtyStr);
    if (qty == null) return qtyStr;

    if (qty == 0.25) return "ربع كيلو";
    if (qty == 0.5) return "نصف كيلو";
    if (qty == 0.75) return "كيلو إلا ربع";
    if (qty == 1.25) return "كيلو وربع";
    if (qty == 1.5) return "كيلو ونصف";
    if (qty == 1.75) return "كيلو و 750 غرام";
    if (qty == 2.25) return "كيلوين وربع";
    if (qty == 2.5) return "كيلوين ونصف";

    // إذا كان كسراً غير معروف في القائمة نرجعه مع كلمة كيلو
    return "$qty كيلو";
  }

  // 🔥 عرض تفاصيل الطلب (التصميم الجديد والذكي للأوزان)
  void _showDetailsDialog(Map<String, dynamic> order, String priceStr) {
    final String orderId = order['id']?.toString() ?? '...';
    final String sourceType = order['source_type']?.toString() ?? 'restaurant';

    List<dynamic> items = [];
    dynamic rawItems = order['line_items'] ?? order['items'];
    if (rawItems != null) {
      if (rawItems is List) {
        items = rawItems;
      } else if (rawItems is String && rawItems.isNotEmpty) {
        try {
          items = json.decode(rawItems);
        } catch (_) {}
      }
    }

    final double deliveryFee = double.tryParse(order['delivery_fee']?.toString() ?? '0') ?? 0;
    final double orderTotal = double.tryParse(order['order_total']?.toString() ?? '0') ?? 0;
    final double totalToCollect = double.tryParse(order['total_to_collect']?.toString() ?? '0') ?? 0;

    double finalItemsPrice = orderTotal > 0 ? orderTotal : (totalToCollect > deliveryFee ? totalToCollect - deliveryFee : 0);
    double finalGrandTotal = totalToCollect > 0 ? totalToCollect : (finalItemsPrice + deliveryFee);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: controller,
              children: [
                Center(child: Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("تفاصيل الطلب #$orderId", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Row(
                      children: [
                        Text(sourceType == 'market' ? "مسواك" : "مطعم", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 6),
                        Icon(sourceType == 'market' ? Icons.shopping_cart : Icons.fastfood, color: Colors.orange, size: 22),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 30, color: Colors.black12),

                if (items.isNotEmpty)
                  ...items.map((item) {
                    final String rawQty = item['quantity']?.toString() ?? '1';
                    final double qtyDouble = double.tryParse(rawQty) ?? 1.0;

                    // 💡 التحقق: هل هو كسر والمصدر مسواك؟
                    final bool isFraction = qtyDouble % 1 != 0 && sourceType == 'market';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ),
                                    // 🍊 شارة الوزن المخصص (تظهر فقط إذا كان كسراً)
                                    if (isFraction)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.orange.shade200)
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.scale, size: 14, color: Colors.orange.shade800),
                                            const SizedBox(width: 4),
                                            Text(_formatFractionWeight(rawQty), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("${NumberFormat('#,###').format(double.tryParse(item['total']?.toString() ?? '0') ?? 0)} د.ع", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade700)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          // 📦 المربع سيتغير تصميمه حسب نوع الكمية (صحيح = أزرق / كسر = مخفي أو برتقالي حسب الشارة)
                          // بما أن الشارة البرتقالية تكفي للمسواك، سنبقي المربع للعدد الصحيح فقط للترتيب
                          if (!isFraction)
                            Container(
                                width: 45, height: 45,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade100)),
                                child: Text("${rawQty}x", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16))
                            ),
                        ],
                      ),
                    );
                  }).toList()
                else
                  Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text(order['items_description'] ?? "لا توجد تفاصيل للمنتجات", style: const TextStyle(fontSize: 16, height: 1.5), textAlign: TextAlign.center))),

                const Divider(height: 30, color: Colors.black12),

                _summaryRow("سعر الطلب:", finalItemsPrice),
                const SizedBox(height: 12),
                _summaryRow("سعر التوصيل:", deliveryFee),
                const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(color: Colors.black12)),
                _summaryRow("الإجمالي الكلي:", finalGrandTotal, isBold: true, color: Colors.green.shade700, size: 18),

                const SizedBox(height: 30),
                SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[100], foregroundColor: Colors.black87, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("إغلاق", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                    )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, double amount, {bool isBold = false, Color? color, double size = 16}) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: Colors.black87)),
          Text("${NumberFormat('#,###').format(amount)} د.ع", style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
        ]
    );
  }

  Future<void> _acceptDelivery(String id) async {
    if (_isProcessingOrder) return;

    if (BalanceManager.current < _costInPoints) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ رصيدك غير كافٍ'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessingOrder = true);

    try {
      final deducted = await BalanceManager.deductOptimistic(_costInPoints);
      if (!deducted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل الخصم - الرصيد غير كافٍ'), backgroundColor: Colors.red));
        setState(() => _isProcessingOrder = false);
        return;
      }

      setState(() {
        _ordersList.removeWhere((o) => o['id'].toString() == id);
        _newOrderIds.remove(id);
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم القبول! جاري التوصيل...'), backgroundColor: Colors.green));

      final res = await ApiService.acceptDeliveryV3(widget.authResult.token, id, fee: _costInPoints);

      if (res['success'] == true) {
        final newBalance = res['current_balance'] ?? BalanceManager.current;
        BalanceManager.setCurrent(newBalance);

        if (mounted && res['delivery_order'] != null) {
          widget.onDeliveryAccepted(res['delivery_order']);
        }
      } else {
        BalanceManager.refund(_costInPoints);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'فشل في قبول الطلب'), backgroundColor: Colors.red));
        setState(() => _isProcessingOrder = false);
      }
    } catch (e) {
      BalanceManager.refund(_costInPoints);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: Colors.red));
      setState(() => _isProcessingOrder = false);
    }
  }

  String _calculateTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "الآن";
    try {
      final date = DateTime.tryParse(dateStr);
      if (date == null) return "غير محدد";
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return "الآن";
      if (diff.inMinutes < 60) return "منذ ${diff.inMinutes} دقيقة";
      if (diff.inHours < 24) return "منذ ${diff.inHours} ساعة";
      return "${date.day}/${date.month} ${date.hour}:${date.minute}";
    } catch (_) {
      return "وقت غير صالح";
    }
  }
}// =============================================================================
class DriverCurrentDeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> initialDelivery;
  final AuthResult authResult;
  final VoidCallback onDeliveryFinished;
  final VoidCallback onDataChanged;

  const DriverCurrentDeliveryScreen({
    super.key,
    required this.initialDelivery,
    required this.authResult,
    required this.onDeliveryFinished,
    required this.onDataChanged,
  });

  @override
  State<DriverCurrentDeliveryScreen> createState() => _DriverCurrentDeliveryScreenState();
}

class _DriverCurrentDeliveryScreenState extends State<DriverCurrentDeliveryScreen> {
  late Map<String, dynamic> _currentDelivery;
  bool _isLoading = false;
  StreamSubscription<geolocator.Position>? _positionStream;
  String _distanceToTargetString = "جاري الحساب...";
  int _callAttempts = 0;
  bool _canShowNumber = false;

  @override
  void initState() {
    super.initState();
    _currentDelivery = widget.initialDelivery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLiveTracking();
      _debugCoordinates();
    });
    Future.delayed(const Duration(minutes: 3), () {
      if (mounted) setState(() => _canShowNumber = true);
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // ========================================================================
  // 🔥 عرض تفاصيل الطلب (نفس تصميم التيم ليدر)
  // ========================================================================
// ========================================================================
  // 🔥 عرض تفاصيل الطلب (التصميم الجديد المطابق للصور)
  // ========================================================================

  void _showOrderDetailsDialog() {
    final String orderId = _currentDelivery['id']?.toString() ?? '...';
    final String sourceType = _currentDelivery['source_type']?.toString() ?? 'restaurant';

    // محاولة استخراج المنتجات كقائمة (إذا كان السيرفر يرسلها كـ Array)
    List<dynamic> items = [];
    if (_currentDelivery['line_items'] != null && _currentDelivery['line_items'] is List) {
      items = _currentDelivery['line_items'];
    } else if (_currentDelivery['items'] != null && _currentDelivery['items'] is List) {
      items = _currentDelivery['items'];
    }

    // حساب الأسعار بأمان
    final double deliveryFee = double.tryParse(_currentDelivery['delivery_fee']?.toString() ?? '0') ?? 0;
    final double totalToCollect = double.tryParse(_currentDelivery['total_to_collect']?.toString() ?? '0') ?? 0;

    // إذا كان الإجمالي الكلي غير متوفر، نعتبره سعر التوصيل + سعر الطلب (إن وجد)
    final double orderTotal = totalToCollect > deliveryFee ? totalToCollect - deliveryFee : totalToCollect;
    final double finalGrandTotal = totalToCollect > 0 ? totalToCollect : (orderTotal + deliveryFee);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: controller,
              children: [
                // شريط السحب العلوي (المؤشر الرمادي)
                Center(
                    child: Container(
                        width: 50, height: 5,
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))
                    )
                ),

                // الرأس (رقم الطلب وأيقونة المصدر)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("تفاصيل الطلب #$orderId", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Icon(sourceType == 'market' ? Icons.shopping_cart : Icons.fastfood, color: Colors.orange, size: 20),
                        const SizedBox(width: 5),
                        Text(sourceType == 'market' ? "مسواك" : "مطعم", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 30),

                // 📋 قائمة المنتجات
                if (items.isNotEmpty)
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        // مربع الكمية الأزرق الفاتح
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text("${item['quantity'] ?? '1'}x", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))
                        ),
                        const SizedBox(width: 12),
                        // اسم المنتج
                        Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 16))),
                        // السعر
                        Text("${NumberFormat('#,###').format(double.tryParse(item['total']?.toString() ?? '0') ?? 0)} د.ع", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList()
                else
                // حل بديل: إذا كان السيرفر يرسل المنتجات كنص عادي (items_description)
                  Center(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          _currentDelivery['items_description'] ?? "لا توجد تفاصيل للمنتجات",
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      )
                  ),

                const Divider(height: 30),

                // 💰 الملخص المالي
                _buildSummaryRow("سعر الطلب:", orderTotal),
                const SizedBox(height: 10),
                _buildSummaryRow("سعر التوصيل:", deliveryFee),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(),
                ),
                _buildSummaryRow("الإجمالي الكلي:", finalGrandTotal, isBold: true, color: Colors.green),

                const SizedBox(height: 30),

                // زر الإغلاق
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                        ),
                        child: const Text("إغلاق", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                    )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // دالة مساعدة لبناء صفوف الأسعار
  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
          Text("${NumberFormat('#,###').format(amount)} د.ع", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
        ]
    );
  }


  double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) {
      return (value == 0.0) ? null : value;
    }
    if (value is int) {
      return (value == 0) ? null : value.toDouble();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == "null" ||
          trimmed == "0" || trimmed == "0.0") {
        return null;
      }
      final parsed = double.tryParse(trimmed);
      return (parsed != null && parsed != 0.0) ? parsed : null;
    }
    return null;
  }

  LatLng? _getPickupPoint() {
    final lat = _safeParseDouble(_currentDelivery['pickup_lat']);
    final lng = _safeParseDouble(_currentDelivery['pickup_lng']);
    if (lat != null && lng != null &&
        lat.abs() > 0.001 && lng.abs() > 0.001) {
      return LatLng(lat, lng);
    }
    return null;
  }

  LatLng? _getDestinationPoint() {
    final lat = _safeParseDouble(_currentDelivery['destination_lat']);
    final lng = _safeParseDouble(_currentDelivery['destination_lng']);
    if (lat != null && lng != null &&
        lat.abs() > 0.001 && lng.abs() > 0.001) {
      return LatLng(lat, lng);
    }
    return null;
  }

  LatLng? _getTargetPoint() {
    final status = _currentDelivery['order_status'];
    if (status == 'accepted' || status == 'at_store') {
      return _getPickupPoint();
    } else if (status == 'picked_up') {
      return _getDestinationPoint();
    }
    return null;
  }

  void _debugCoordinates() {
    print("🔍 === بدء تشخيص الإحداثيات ===");
    final pickupParsed = _getPickupPoint();
    print("📍 المطعم: ${pickupParsed?.toString() ?? 'NULL'}");
    final destParsed = _getDestinationPoint();
    print("🎯 الزبون: ${destParsed?.toString() ?? 'NULL'}");
    print("🔍 === نهاية التشخيص ===");
  }

  Future<void> _startLiveTracking() async {
    final hasPermission = await PermissionService.handleLocationPermission(context);
    if (!hasPermission) return;

    const locationSettings = geolocator.LocationSettings(
      accuracy: geolocator.LocationAccuracy.high,
      distanceFilter: 20,
    );

    _positionStream = geolocator.Geolocator.getPositionStream(
        locationSettings: locationSettings
    ).listen((geolocator.Position pos) {
      if (!mounted) return;
      final newLoc = LatLng(pos.latitude, pos.longitude);
      final target = _getTargetPoint();
      String distString = "...";

      if (target != null) {
        final distMeters = geolocator.Geolocator.distanceBetween(
          newLoc.latitude,
          newLoc.longitude,
          target.latitude,
          target.longitude,
        );
        distString = distMeters < 1000
            ? "${distMeters.round()} متر"
            : "${(distMeters / 1000).toStringAsFixed(1)} كم";
      } else {
        distString = "العنوان نصي";
      }

      setState(() => _distanceToTargetString = distString);

      ApiService.updateDriverLocation(
        widget.authResult.token,
        newLoc.latitude,
        newLoc.longitude,
      );
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.updateDeliveryStatus(
        widget.authResult.token,
        _currentDelivery['id'].toString(),
        newStatus,
      );
      final data = json.decode(response.body);

      if (mounted && response.statusCode == 200 && data['success'] == true) {
        if (newStatus == 'delivered' || newStatus == 'cancelled') {
          widget.onDeliveryFinished();
        } else {
          setState(() => _currentDelivery = data['delivery_order']);
          widget.onDataChanged();
        }
      } else {
        throw Exception(data['message'] ?? 'فشل التحديث');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchWazeWithCoords(double lat, double lng) async {
    final wazeUri = Uri.parse("https://waze.com/ul?ll=$lat,$lng&navigate=yes");
    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ يرجى تثبيت تطبيق Waze (ويز) على جهازك أولاً"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchWazeWithAddress(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final wazeUri = Uri.parse("https://waze.com/ul?q=$encodedAddress&navigate=yes");
    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ يرجى تثبيت تطبيق Waze (ويز) على جهازك أولاً"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchRestaurantMap() async {
    final pickup = _getPickupPoint();
    if (pickup != null) {
      await _launchWazeWithCoords(pickup.latitude, pickup.longitude);
    } else {
      final pickupName = _currentDelivery['pickup_location_name'] ?? '';
      if (pickupName.isNotEmpty && pickupName != 'غير محدد') {
        await _launchWazeWithAddress(pickupName);
      } else {
        _showMapError("المطعم");
      }
    }
  }

  Future<void> _launchCustomerMap() async {
    final destination = _getDestinationPoint();
    if (destination != null) {
      await _launchWazeWithCoords(destination.latitude, destination.longitude);
    } else {
      final destAddress = _currentDelivery['destination_address'] ?? '';
      if (destAddress.isNotEmpty && destAddress != 'غير معروف') {
        await _launchWazeWithAddress(destAddress);
      } else {
        _showMapError("الزبون");
      }
    }
  }

  Future<void> _launchWaze() async {
    final target = _getTargetPoint();
    if (target != null) {
      await _launchWazeWithCoords(target.latitude, target.longitude);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ الإحداثيات غير متوفرة"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showMapError(String target) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ تعذر إيجاد إحداثيات أو عنوان واضح لـ $target"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _callCustomer() async {
    final phone = _currentDelivery['end_customer_phone'] ??
        _currentDelivery['customer_phone'];
    if (phone == null || phone.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("رقم الهاتف غير متوفر"))
      );
      return;
    }
    setState(() => _callAttempts++);
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
    if (_callAttempts >= 3) {
      setState(() => _canShowNumber = true);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _startInternalCall() async {
    print("📞 [CALL] ========== بدء المكالمة الداخلية ==========");
    print("📞 [CALL] Order ID: ${_currentDelivery['id']}");
    print("📞 [CALL] Customer Phone: ${_currentDelivery['end_customer_phone']}");

    setState(() => _isLoading = true);

    try {
      final orderId = _currentDelivery['id'].toString();
      final customerPhone = _currentDelivery['end_customer_phone'] ?? '';
      final driverName = widget.authResult.displayName ?? 'سائق';
      final driverPhone = widget.authResult.userId ?? '';

      print("📡 [CALL] إرسال طلب المكالمة للسيرفر...");

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/restaurant-app/v1/incoming-call'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'secret_key': 'BEYTEI_SECURE_2025',
          'order_id': orderId,
          'driver_name': driverName,
          'driver_phone': driverPhone,
          'customer_phone': customerPhone,
        }),
      );

      print("📡 [CALL] استجابة السيرفر: ${response.statusCode}");
      print("📡 [CALL] Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ [CALL] تم إنشاء قناة المكالمة: ${data['channel_name']}");

        if (data['success'] == true) {
          // الانتقال لشاشة المكالمة
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverCallPage(
                  channelName: data['channel_name'],
                  customerName: 'الزبون',
                  customerPhone: customerPhone,
                  agoraAppId: data['agora_app_id'],
                ),
              ),
            );
          }
        } else {
          print("❌ [CALL] فشل بدء المكالمة: ${data['message']}");
          _showError('فشل بدء المكالمة: ${data['message']}');
        }
      } else {
        print("❌ [CALL] خطأ من السيرفر: ${response.statusCode}");
        _showError('خطأ في الاتصال بالسيرفر');
      }
    } catch (e, stackTrace) {
      print("❌ [CALL] استثناء: $e");
      print("❌ [CALL] Stack Trace: $stackTrace");
      _showError('خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    print("📞 [CALL] ========== نهاية محاولة المكالمة ==========\n");
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Widget _buildMapButtons() {
    final status = _currentDelivery['order_status'];
    if (status == 'accepted' || status == 'at_store') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _launchRestaurantMap,
              icon: const Icon(Icons.store, size: 18),
              label: const Text("خريطة المتجر",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.blue.shade300),
                elevation: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _launchCustomerMap,
              icon: const Icon(Icons.person_pin, size: 18),
              label: const Text("خريطة الزبون",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade50,
                foregroundColor: Colors.green.shade800,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.green.shade300),
                elevation: 1,
              ),
            ),
          ),
        ],
      );
    } else if (status == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _launchCustomerMap,
          icon: const Icon(Icons.person_pin, size: 20),
          label: const Text("خريطة الزبون",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActionButton() {
    final status = _currentDelivery['order_status'];
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      elevation: 5,
    );

    switch (status) {
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.store, size: 28),
            label: const Text('وصلت للمتجر'),
            onPressed: _isLoading ? null : () => _updateStatus('at_store'),
            style: buttonStyle.copyWith(
              backgroundColor: const WidgetStatePropertyAll(Colors.blue),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
          ),
        );
      case 'at_store':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.delivery_dining, size: 28),
            label: const Text('استلمت الطلب (الذهاب للزبون)'),
            onPressed: _isLoading ? null : () => _updateStatus('picked_up'),
            style: buttonStyle.copyWith(
              backgroundColor: const WidgetStatePropertyAll(Colors.orange),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
          ),
        );
      case 'picked_up':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, size: 28),
            label: const Text('تم التسليم'),
            onPressed: _isLoading ? null : () => _updateStatus('delivered'),
            style: buttonStyle.copyWith(
              backgroundColor: const WidgetStatePropertyAll(Colors.green),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentDelivery['order_status'] ?? 'pending';
    IconData stateIcon = Icons.local_shipping;
    String stateTitle = "جارِ التوصيل";
    Color stateColor = Colors.blue;
    String locationText = _currentDelivery['pickup_location_name'] ?? '';

    if (status == 'accepted') {
      stateIcon = Icons.store_mall_directory;
      stateTitle = "تجه للمتجر";
      stateColor = Colors.blue;
      locationText = "المتجر: ${_currentDelivery['pickup_location_name']}";
    } else if (status == 'picked_up') {
      stateIcon = Icons.person_pin_circle;
      stateTitle = "تجه للزبون";
      stateColor = Colors.orange;
      locationText = "الزبون: ${_currentDelivery['destination_address']}";
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(stateTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: stateColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: "اتصل بالزبون",
            onPressed: _callCustomer,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 📦 بطاقة الحالة والمسافة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5)
                  )
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: stateColor.withOpacity(0.1),
                    child: Icon(stateIcon, size: 40, color: stateColor),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _distanceToTargetString,
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: stateColor
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                      "المسافة المتبقية",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)
                  ),
                  const Divider(height: 30),
                  Text(
                    locationText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 📞 أزرار الاتصال
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _callCustomer,
                    icon: const Icon(Icons.phone, size: 20),
                    label: const Text("اتصال عادي",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.green, width: 2),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startInternalCall,
                    icon: const Icon(Icons.headset_mic, size: 20),
                    label: const Text("اتصال مجاني",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🗺️ أزرار الخرائط
            _buildMapButtons(),
            const SizedBox(height: 15),

            // 📋 بطاقة تفاصيل الطلب (التصميم الحديث)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: _showOrderDetailsDialog,
                leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.shopping_basket, color: Colors.white)
                ),
                title: const Text("عرض محتويات الطلب",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ),
            const SizedBox(height: 40),

            // 🗺️ زر الخريطة العامة
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _launchWaze,
                icon: const Icon(Icons.map, size: 26),
                label: const Text("فتح الخريطة العامة في Waze",
                    style: TextStyle(fontSize: 18)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: stateColor, width: 2),
                  foregroundColor: stateColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ زر تغيير الحالة
            _buildActionButton(),
            const SizedBox(height: 20),

            // ❌ زر الإلغاء
            if (status != 'delivered' && status != 'cancelled')
              TextButton(
                onPressed: () => _updateStatus('cancelled'),
                child: const Text("إلغاء الرحلة",
                    style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}


// =============================================================================
// HISTORY & POINTS
// =============================================================================
class HistoryTabV3 extends StatelessWidget {
  final String token;
  // 🔥 دالة لفتح الطلب في الرئيسية
  final Function(Map<String, dynamic>) onOpenActive;

  const HistoryTabV3({
    super.key,
    required this.token,
    required this.onOpenActive
  });

  String _mask(String? p) => (p == null || p.length < 8) ? "****" : "${p.substring(0, 4)}****${p.substring(p.length - 3)}";

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.indigo,
            tabs: [
              Tab(text: "نشطة"),
              Tab(text: "أرشيف"),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: ApiService.getHistoryV3(token),
              builder: (c, s) {
                if (s.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final all = s.data ?? [];
                // الطلبات النشطة
                final active = all
                    .where((o) => ['accepted', 'at_store', 'picked_up'].contains(o['status']))
                    .toList();

                final archive = all
                    .where((o) => ['delivered', 'cancelled'].contains(o['status']))
                    .toList();

                return TabBarView(
                  children: [
                    _list(active, isArchive: false),
                    _list(archive, isArchive: true)
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<dynamic> list, {required bool isArchive}) {
    if (list.isEmpty) return const Center(child: Text("لا توجد بيانات"));

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (c, i) {
        final o = list[i];
        final status = o['status'];
        final isDone = status == 'delivered';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            // 🔥 عند الضغط على طلب نشط، نرسله للرئيسية
            onTap: isArchive
                ? null
                : () {
              // تحويل هيكل البيانات ليتناسب مع Active Order
              final activeMap = {
                'id': o['id'],
                'order_status': o['status'],
                'delivery_fee': o['delivery_fee'],
                'pickup_location_name': o['pickup_location'],
                'items_description': o['items_description'] ?? 'تفاصيل الطلب',
                'destination_address': o['destination_address'] ?? 'العنوان',
                'destination_lat': o['destination_lat'],
                'destination_lng': o['destination_lng'],
                'pickup_lat': o['pickup_lat'],
                'pickup_lng': o['pickup_lng'],
                'customer_phone': o['customer_phone'],
                'end_customer_phone': o['end_customer_phone'],
                'customer_name': o['customer_name'] ?? 'زبون',
              };
              onOpenActive(activeMap);
            },
            leading: Icon(
              isArchive ? (isDone ? Icons.check_circle : Icons.cancel) : Icons.directions_bike,
              color: isDone ? Colors.green : (status == 'cancelled' ? Colors.red : Colors.blue),
            ),
            title: Text("طلب #${o['id']} - $status"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("تاريخ: ${o['date']}"),
                Text("المصدر: ${o['pickup_location']}"),
                if (isArchive) Text("هاتف: ${_mask(o['customer_phone'])}"),
                if (!isArchive) const Text("اضغط للفتح", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: Text(
              "${o['delivery_fee']} التوصيل ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
class PointsTab extends StatelessWidget {
  final String token;
  final VoidCallback onLogout;
  const PointsTab({super.key, required this.token, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    // ✅ استخدام ValueListenableBuilder يجعل الرقم يتحدث فوراً دون إعادة تحميل الصفحة
    return ValueListenableBuilder<int>(
      valueListenable: BalanceManager.balanceNotifier,
      builder: (context, balance, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.stars,
                size: 80,
                color: balance <= 3 ? Colors.red : Colors.amber,
              ),
              const SizedBox(height: 10),
              Text(
                "$balance",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const Text("نقطة"),
              const SizedBox(height: 20),

              // زر تحديث يدوي إضافي
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => BalanceManager.refresh(),
              ),

              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => launchUrl(
                  Uri.parse("https://wa.me/+9647854076931"),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text("شحن"),
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onLogout, child: const Text("خروج")),
            ],
          ),
        );
      },
    );
  }
}

class DriverCallPage extends StatefulWidget {
  final String channelName;
  final String customerName;
  final String customerPhone;
  final String agoraAppId;

  const DriverCallPage({
    super.key,
    required this.channelName,
    required this.customerName,
    required this.customerPhone,
    required this.agoraAppId,
  });

  @override
  State<DriverCallPage> createState() => _DriverCallPageState();
}

class _DriverCallPageState extends State<DriverCallPage> {
  late RtcEngine _engine;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeaker = false; // السبيكر مغلق افتراضياً ليكون كالمكالمة العادية
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. طلب صلاحية المايكروفون
    await [Permission.microphone].request();

    // 2. تهيئة محرك الصوت باستخدام الـ App ID القادم من السيرفر
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: widget.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. الاستماع لأحداث المكالمة
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _isJoined = true);
          // ضبط السماعة بعد الانضمام
          _engine.setEnableSpeakerphone(_isSpeaker);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          // إذا خرج الزبون، ننهي المكالمة للسائق أيضاً
          _endCall();
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          setState(() => _isJoined = false);
        },
      ),
    );

    // 4. تمكين الصوت والانضمام للغرفة (باستخدام القناة المشتركة)
    await _engine.enableAudio();
    await _engine.joinChannel(
      token: '', // نتركها فارغة إذا لم تكن تستخدم Security Token في حساب Agora
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeaker = !_isSpeaker);
    _engine.setEnableSpeakerphone(_isSpeaker);
  }

  void _endCall() async {
    await _engine.leaveChannel();
    await _engine.release();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // صورة المتصل
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 20),
            // اسم المتصل
            Text(
              widget.customerName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              widget.customerPhone,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 10),
            // حالة المكالمة
            Text(
              _remoteUid != null ? '00:00 (متصل)' : (_isJoined ? 'جاري الاتصال...' : 'تهيئة...'),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),

            // أزرار التحكم
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: const BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // المايكروفون
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.white : Colors.white24,
                    iconColor: _isMuted ? Colors.black : Colors.white,
                    onPressed: _toggleMute,
                  ),
                  // إنهاء المكالمة
                  _buildControlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    iconColor: Colors.white,
                    size: 65,
                    onPressed: _endCall,
                  ),
                  // السبيكر
                  _buildControlButton(
                    icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                    color: _isSpeaker ? Colors.white : Colors.white24,
                    iconColor: _isSpeaker ? Colors.black : Colors.white,
                    onPressed: _toggleSpeaker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    double size = 55,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}

