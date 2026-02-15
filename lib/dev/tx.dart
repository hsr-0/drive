import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:vibration/vibration.dart';

// =============================================================================
// 🔑 BALANCE MANAGER (المصدر الوحيد للرصيد - احترافي)
// =============================================================================
class BalanceManager {
  static int _balance = 0;
  static String _token = '';

  // التهيئة المركزية (مرة واحدة عند الدخول)
  static Future<bool> initialize(String token) async {
    _token = token;
    try {
      _balance = await ApiService.getPoints(token);
      print("✅ BalanceManager initialized with $_balance points");
      return _balance > 0;
    } catch (e) {
      print("⚠️ BalanceManager initialization failed: $e");
      return false;
    }
  }

  // الوصول الفوري
  static int get current => _balance;

  // تحديث فوري
  static Future<void> refresh() async {
    try {
      _balance = await ApiService.getPoints(_token);
      print("🔄 Balance refreshed: $_balance");
    } catch (e) {
      print("⚠️ Balance refresh failed: $e");
    }
  }

  // تحديث يدوي (للاستخدام مع استجابة السيرفر)
  static void setCurrent(int newBalance) {
    _balance = newBalance;
    print("✅ Balance updated locally to: $_balance");
  }

  // خصم متفائل (فوري في الواجهة)
  static void deductOptimistic(int amount) {
    _balance = (_balance - amount).clamp(0, 999999);
    print("💸 Optimistic deduction: $amount | Remaining: $_balance");
  }

  // استرداد عند الفشل
  static void refund(int amount) {
    _balance += amount;
    print("💰 Refund: $amount | New balance: $_balance");
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
final ValueNotifier<bool> refreshTrigger = ValueNotifier(false);

// =============================================================================
// MAIN ENTRY POINT
// =============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  runApp(const DeliveryApp());
}

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
      home: const AuthGate(),
    );
  }
}

// =============================================================================
// SERVICES
// =============================================================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localParams = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'طلبات التوصيل العاجلة',
    description: 'تنبيهات صوتية عالية للطلبات الجديدة',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('woo_sound'),
    enableVibration: true,
  );

  static Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true, announcement: true, criticalAlert: true);

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    await _localParams.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _localParams
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;

      // 🔥 1. تحديث الرصيد فوراً
      await BalanceManager.refresh();

      // 🔥 2. تحديث الطلبات
      refreshTrigger.value = !refreshTrigger.value;

      // 🔥 3. التحقق الفوري من حالة الرصيد
      if (BalanceManager.current == 0) {
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => ZeroBalanceLockScreen(
              token: BalanceManager._token,
              onRecharge: _recharge
          )),
        );
        return;
      }

      // 🔥 4. عرض إشعار محلي عند الرصيد المنخفض
      _showLocalBalanceNotification(BalanceManager.current);

      // 🔥 5. اهتزاز + إشعار
      if (await Vibration.hasVibrator()) Vibration.vibrate(duration: 500);

      _localParams.show(
        notification.hashCode,
        notification?.title ?? "🔔 طلب جديد!",
        notification?.body ?? "يوجد طلب بالقرب منك",
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('woo_sound'),
            enableVibration: true,
          ),
        ),
      );
    });
  }

  // 🔥 إشعارات محلية للرصيد المنخفض
  static void _showLocalBalanceNotification(int points) {
    if (points == 10) {
      _localParams.show(
        1001,
        '⚠️ تنبيه رصيد',
        'متبقي لديك 10 نقاط فقط. يجب إضافة نقاط حتى لا يتم إيقاف حسابك.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            color: Colors.orange,
          ),
        ),
      );
    } else if (points == 5) {
      _localParams.show(
        1002,
        '🚨 رصيد منخفض جداً',
        'متبقي لديك 5 نقاط فقط! يجب الشحن فوراً لتجنب إيقاف حسابك.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            color: Colors.red,
          ),
        ),
      );
    }
  }

  static Future<String?> getFcmToken() async => await FirebaseMessaging.instance.getToken();

  static void _recharge() {
    launchUrl(Uri.parse("https://wa.me/+9647854076931"), mode: LaunchMode.externalApplication);
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

  static Future<void> updateFcmToken(String t, String fcm) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/taxi-auth/v1/update-fcm-token'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
        body: json.encode({'fcm_token': fcm}),
      );
    } catch (_) {}
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
  static Future<Map<String, dynamic>> getAvailableDeliveriesOnly(String t) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/taxi/v3/delivery/available'),
        headers: {'Authorization': 'Bearer $t'},
      );
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
    } catch (e) {
      print("Error fetching orders: $e");
    }
    return {'success': true, 'orders': []};
  }

  static Future<Map<String, dynamic>> acceptDeliveryV3(String t, String id, {int fee = 1}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/taxi/v3/delivery/accept'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
        body: json.encode({'order_id': id, 'fee': fee}),
      );
      return json.decode(res.body);
    } catch (e) {
      return {'success': false, 'message': '$e'};
    }
  }

  static Future<Map<String, dynamic>?> getMyActiveDelivery(String t) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/taxi/v2/driver/my-active-delivery'),
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
    Uri.parse('$baseUrl/taxi/v2/delivery/update-status'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
    body: json.encode({'order_id': id, 'status': s}),
  );

  static Future<void> updateDriverLocation(String t, double lat, double lng) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/taxi/v2/driver/update-location'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
        body: json.encode({'lat': lat, 'lng': lng}),
      );
    } catch (_) {}
  }

  // 🔥 دالة مخصصة لتحديث النقاط فقط (للتحقق السريع)
  static Future<int> getPoints(String t) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/taxi/v2/driver/hub'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode == 200) {
        return (json.decode(res.body)['data']['wallet_balance'] ?? 0).toInt();
      }
    } catch (_) {}
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

      // 4. تحديث FCM Token في الخلفية (لا يؤثر على الأداء)
      try {
        final fcm = await NotificationService.getFcmToken();
        if (fcm != null) ApiService.updateFcmToken(storedAuth.token, fcm);
      } catch (_) {}

      // 5. تخزين بيانات المصادقة
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

  const ZeroBalanceLockScreen({
    super.key,
    required this.token,
    required this.onRecharge,
  });

  // 🔥 زر "تم الشحن؟" يعيد فحص الرصيد من السيرفر مباشرة
  Future<void> _refreshBalance(BuildContext context) async {
    // 🔥 عرض مؤشر تحميل
    final loading = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'جاري التحقق من الرصيد...',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(days: 1),
      ),
    );

    try {
      // 🔥 1. تحديث الرصيد من السيرفر
      await BalanceManager.refresh();

      // 🔥 2. التحقق من الرصيد المحدث (استخدام BalanceManager.current)
      final hasBalance = BalanceManager.current > 0;

      if (hasBalance) {
        // 🔥 3. نجاح: إخفاء المؤشر ثم العودة للشاشة الرئيسية
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // عرض رسالة نجاح قصيرة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('تم التحقق بنجاح!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // التأخير القصير لإظهار الرسالة ثم الانتقال
        await Future.delayed(const Duration(milliseconds: 1500));

        // 🔥 العودة للشاشة الرئيسية
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
                (route) => false,
          );
        }
      } else {
        // 🔥 4. فشل: الرصيد لا يزال 0
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('الرصيد لا يزال 0. تأكد من إتمام عملية الشحن.'),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () => _refreshBalance(context),
            ),
          ),
        );
      }
    } catch (e) {
      // 🔥 5. خطأ: عرض رسالة خطأ
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'خطأ في التحديث: ${e.toString()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => _refreshBalance(context),
          ),
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
            colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔥 دائرة بيضاء خلف الأيقونة
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.block, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 30),
                // 🔥 عنوان رئيسي
                const Text(
                  'تم إيقاف حسابك مؤقتاً',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                // 🔥 وصف
                const Text(
                  'رصيدك الحالي: 0 نقاط',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'يجب شحن رصيدك لاستئناف استقبال الطلبات',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.white70,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                // 🔥 زر الشحن الرئيسي
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRecharge,
                    icon: const Icon(Icons.payment, size: 24, color: Colors.white),
                    label: const Text(
                      'شحن الرصيد الآن',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                // 🔥 زر التحديث الذكي
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _refreshBalance(context),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'تم الشحن؟ اضغط للتحديث',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
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
                ),
                const SizedBox(height: 20),
                // 🔥 رسالة توضيحية
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'ملاحظة: قد يستغرق تحديث الرصيد 1-2 دقيقة بعد إتمام الشحن',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
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
    final res = await ApiService.login(p.text, pass.text);
    setState(() => _load = false);

    if (res['success'] == true) {
      final a = AuthResult.fromJson(res);
      if (res['is_driver'] == true) {
        await ApiService.storeAuthData(a);
        final fcm = await NotificationService.getFcmToken();
        if (fcm != null) ApiService.updateFcmToken(a.token, fcm);
        widget.onSuccess(a);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ليس حساب سائق')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'فشل')));
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
                child: _load ? const CircularProgressIndicator(color: Colors.white) : const Text("دخول"),
              ),
            ),
            TextButton(onPressed: widget.onToggle, child: const Text("ليس لديك حساب؟ سجل الآن")),
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
                  DropdownMenuItem(value: 'Car', child: Text('سيارة')),
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
  bool _isRefreshingOrders = false; // 🔥 حالة التحديث للطلبات

  @override
  void initState() {
    super.initState();
    _chk();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
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

  // 🔥 دالة التحديث الذكية للطلبات
  Future<void> _refreshOrdersScreen() async {
    if (_isRefreshingOrders) return;

    setState(() => _isRefreshingOrders = true);

    // تحديث الطلبات عبر الـ refreshTrigger العالمي
    refreshTrigger.value = !refreshTrigger.value;

    // إعادة تعيين الحالة بعد 2 ثانية (لضمان اكتمال التحديث)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) setState(() => _isRefreshingOrders = false);
  }

  void _recharge() {
    launchUrl(
      Uri.parse("https://wa.me/+9647854076931"), // 🔥 إصلاح المسافة الزائدة في الرابط
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _active != null
          ? DriverCurrentDeliveryScreen(
        initialDelivery: _active!,
        authResult: widget.authResult,
        onDeliveryFinished: () => setState(() => _active = null),
        onDataChanged: _chk,
      )
          : DriverAvailableDeliveriesV3Screen(
        authResult: widget.authResult,
        onDeliveryAccepted: (o) => setState(() => _active = o), onRefresh: () {  },
      ),
      HistoryTabV3(token: widget.authResult.token),
      PointsTab(token: widget.authResult.token, onLogout: widget.onLogout),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _idx == 0
              ? (_active != null ? "طلب جاري" : "الطلبات")
              : (_idx == 1 ? "السجل" : "حسابي"),
        ),
        actions: [
          // 🔥 زر التحديث الذكي (يظهر دائري مع مؤشر تحميل)
          if (_idx == 0 && _active == null)
            IconButton(
              icon: _isRefreshingOrders
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.refresh, size: 24),
              onPressed: _refreshOrdersScreen,
              tooltip: 'تحديث قائمة الطلبات',
            ),
          // 🔥 عرض الرصيد من BalanceManager (محدث)
          if (_idx == 0 && _active == null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: BalanceManager.current <= 5
                    ? Colors.red.shade100
                    : (BalanceManager.current <= 10 ? Colors.orange.shade100 : Colors.green.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: BalanceManager.current <= 5
                      ? Colors.red.shade300
                      : (BalanceManager.current <= 10 ? Colors.orange.shade300 : Colors.green.shade300),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    BalanceManager.current <= 5
                        ? Icons.error
                        : (BalanceManager.current <= 10 ? Icons.warning : Icons.monetization_on),
                    size: 18,
                    color: BalanceManager.current <= 5
                        ? Colors.red.shade800
                        : (BalanceManager.current <= 10 ? Colors.orange.shade800 : Colors.green.shade800),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${BalanceManager.current}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: BalanceManager.current <= 5
                          ? Colors.red.shade800
                          : (BalanceManager.current <= 10 ? Colors.orange.shade800 : Colors.green.shade800),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'نقطة',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          // زر التحديث العادي للشاشات الأخرى
          if (_idx != 0 || _active != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _chk,
              tooltip: 'تحديث البيانات',
            ),
        ],
      ),
      body: pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "الرئيسية"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "السجل"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "حسابي"),
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
class DriverAvailableDeliveriesV3Screen extends StatefulWidget {
  final AuthResult authResult;
  final Function(Map<String, dynamic>) onDeliveryAccepted;
  final VoidCallback onRefresh; // 🔥 إضافة callback للتحديث اليدوي

  const DriverAvailableDeliveriesV3Screen({
    super.key,
    required this.authResult,
    required this.onDeliveryAccepted,
    required this.onRefresh, // 🔥 تمرير الدالة من الـ MainLayout
  });

  @override
  State<DriverAvailableDeliveriesV3Screen> createState() => _DriverAvailableDeliveriesV3ScreenState();
}

// =============================================================================
// شاشة الطلبات المتاحة (خصم 1 نقطة فقط + إصلاح الوقت والتفاصيل)
// =============================================================================
class DriverAvailableDeliveriesV3Screen extends StatefulWidget {
  final AuthResult authResult;
  final Function(Map<String, dynamic>) onDeliveryAccepted;
  final VoidCallback onRefresh;

  const DriverAvailableDeliveriesV3Screen({
    super.key,
    required this.authResult,
    required this.onDeliveryAccepted,
    required this.onRefresh,
  });

  @override
  State<DriverAvailableDeliveriesV3Screen> createState() => _DriverAvailableDeliveriesV3ScreenState();
}

class _DriverAvailableDeliveriesV3ScreenState extends State<DriverAvailableDeliveriesV3Screen> {
  List<dynamic> _ordersList = [];
  bool _isLoading = false;
  bool _isFirstLoad = true;
  Set<String> _newOrderIds = {};
  DateTime? _lastRefreshTime;

  // 🔥🔥🔥 هنا التعديل الجوهري: الخصم ثابت = 1 نقطة 🔥🔥🔥
  final int _costInPoints = 1;

  @override
  void initState() {
    super.initState();
    _loadDataSafe(isInitial: true);
    refreshTrigger.addListener(_handleNotification);
  }

  @override
  void dispose() {
    refreshTrigger.removeListener(_handleNotification);
    super.dispose();
  }

  Future<void> _handleNotification() async {
    _loadDataSafe(isSilent: true);
  }

  Future<void> _loadDataSafe({bool isInitial = false, bool isSilent = false}) async {
    if (isInitial) setState(() => _isFirstLoad = true);
    if (!isInitial && !isSilent) setState(() => _isLoading = true);

    try {
      final result = await ApiService.getAvailableDeliveriesOnly(widget.authResult.token);

      if (!mounted) return;

      if (result['success'] == true) {
        final List<dynamic> newOrders = result['orders'] ?? [];

        // كشف الطلبات الجديدة
        if (_ordersList.isNotEmpty) {
          final currentIds = _ordersList.map((o) => o['id'].toString()).toSet();
          final incomingIds = newOrders.map((o) => o['id'].toString()).toSet();
          final newlyAdded = Set<String>.from(incomingIds.difference(currentIds));
          if (newlyAdded.isNotEmpty) {
            _showToast(newlyAdded.length);
            _newOrderIds = newlyAdded;
          }
        }

        // ترتيب الطلبات (الأحدث في الأسفل)
        newOrders.sort((a, b) {
          try {
            final dateA = DateTime.tryParse(a['date_created']?.toString() ?? '') ?? DateTime.now();
            final dateB = DateTime.tryParse(b['date_created']?.toString() ?? '') ?? DateTime.now();
            return dateA.compareTo(dateB);
          } catch (_) {
            return 0;
          }
        });

        setState(() {
          _ordersList = newOrders;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      // تجاهل الخطأ الصامت لمنع الشاشة البيضاء
    } finally {
      if (mounted) setState(() {
        _isLoading = false;
        _isFirstLoad = false;
      });
    }
  }

  void _showToast(int count) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Row(children: [const Icon(Icons.notifications, color: Colors.white), const SizedBox(width: 8), Text("وصل $count طلب جديد!")]),
          duration: const Duration(seconds: 3)
      ),
    );
    Vibration.vibrate(duration: 300);
  }

  @override
  Widget build(BuildContext context) {
    // 1. فحص الرصيد مقابل نقطة واحدة فقط
    if (BalanceManager.current < _costInPoints) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_sim, size: 60, color: Colors.red),
            const SizedBox(height: 20),
            Text("رصيدك 0 - يتطلب $_costInPoints نقطة للقبول"),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _recharge, child: const Text("شحن الرصيد"))
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
            const Text("لا توجد طلبات متاحة"),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: () => _loadDataSafe(), icon: const Icon(Icons.refresh), label: const Text("تحديث"))
          ],
        ),
      );
    }

    return Column(
      children: [
        // شريط حالة بسيط
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[200],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("الطلبات: ${_ordersList.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_isLoading)
                const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
              else
                InkWell(onTap: () => _loadDataSafe(), child: const Icon(Icons.refresh, size: 20)),
            ],
          ),
        ),
        // القائمة
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => await _loadDataSafe(),
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _ordersList.length,
              itemBuilder: (context, index) {
                try {
                  return _buildOrderCard(_ordersList[index]);
                } catch (e) {
                  return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("خطأ في بيانات الطلب")));
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 دالة معالجة الوقت القوية
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    // 1. البيانات الأساسية
    final id = order['id'].toString();
    final isNew = _newOrderIds.contains(id);

    // 2. السعر الظاهر (مثلاً 1000)
    final serverPrice = order['delivery_fee']?.toString() ?? '---';

    // 3. معالجة الوقت
    final timeStr = _calculateTimeAgo(order['date_created']);

    // 4. التفاصيل (مع قيم افتراضية لمنع الخطأ)
    final shopName = order['pickup_location_name']?.toString() ?? 'اسم المتجر غير متوفر';
    final address = order['destination_address']?.toString() ?? 'العنوان غير متوفر';
    final items = order['items_description']?.toString() ?? 'لا توجد تفاصيل';

    return Card(
      elevation: isNew ? 5 : 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isNew ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _showDetailsDialog(order, serverPrice),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: الوقت والشارة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                      child: const Text("جديد", style: TextStyle(color: Colors.white, fontSize: 10)),
                    )
                ],
              ),
              const Divider(),

              // الصف الثاني: المتجر والتفاصيل
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.store, color: Colors.indigo, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(items, style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [const Icon(Icons.location_on, size: 12, color: Colors.grey), Text(address, style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 15),

              // الصف الثالث: السعر وزر القبول
              Row(
                children: [
                  // عرض السعر الكبير (1000 مثلاً)
                  Expanded(
                    flex: 2,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$serverPrice", // يظهر 1000
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // زر القبول (يخصم 1 نقطة)
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      // 🔥🔥🔥 الشرط هنا: هل لديك 1 نقطة؟ 🔥🔥🔥
                      onPressed: BalanceManager.current >= _costInPoints
                          ? () => _acceptDelivery(id)
                          : null,
                      child: Column(
                        children: [
                          const Text("قبول الطلب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text("يخصم $_costInPoints نقطة", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> o, String price) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(o['pickup_location_name'] ?? 'تفاصيل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.info_outline), title: Text(o['items_description'] ?? '...')),
              ListTile(leading: const Icon(Icons.location_on), title: Text(o['destination_address'] ?? '...')),
              const Divider(),
              Text("سعر التوصيل: $price", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("تكلفة القبول: $_costInPoints نقطة", style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (BalanceManager.current >= _costInPoints) {
                  _acceptDelivery(o['id'].toString());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("رصيدك غير كافٍ")));
                }
              },
              child: const Text("تأكيد القبول"),
            )
          ],
        )
    );
  }

  Future<void> _acceptDelivery(String id) async {
    // 1. خصم متفائل لنقطة واحدة
    BalanceManager.deductOptimistic(_costInPoints);

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      // 2. إرسال الطلب للسيرفر
      // 🔥 نرسل fee = 1 لضمان أن السيرفر يفهم أن التكلفة هي 1 نقطة
      final res = await ApiService.acceptDeliveryV3(widget.authResult.token, id, fee: _costInPoints);

      Navigator.pop(context);

      if (res['success'] == true) {
        final newBalance = res['new_balance'] as int?;
        if (newBalance != null) BalanceManager.setCurrent(newBalance);
        widget.onDeliveryAccepted(res['delivery_order']);
      } else {
        BalanceManager.refund(_costInPoints);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'فشل'), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context);
      BalanceManager.refund(_costInPoints);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  void _recharge() {
    launchUrl(Uri.parse("https://wa.me/+9647854076931"), mode: LaunchMode.externalApplication);
  }
}// =============================================================================
// شاشة الطلب الحالي
// =============================================================================
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
  late Map<String, dynamic> _o;
  bool _isLoading = false;
  String _dStr = "...";
  StreamSubscription? _sub;
  int _callAttempts = 0;
  bool _canShowNumber = false;
  Timer? _numberRevealTimer;

  @override
  void initState() {
    super.initState();
    _o = widget.initialDelivery;
    _track();
    _numberRevealTimer = Timer(const Duration(minutes: 3), () {
      if (mounted) setState(() => _canShowNumber = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _numberRevealTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiateVoIP() async {
    print("📞 [CALL] Starting VoIP call process...");
    String customerPhone = (_o['end_customer_phone'] ?? _o['customer_phone'] ?? '').toString().trim();
    if (customerPhone.isEmpty || customerPhone == 'null' || customerPhone == '0' || customerPhone.length < 8) {
      customerPhone = '0780000000';
      print("⚠️ [CALL] Short/invalid phone '$customerPhone' replaced with test number '0780000000'");
    }
    customerPhone = customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final driverName = (widget.authResult.displayName ?? 'السائق').trim();
    final orderId = _o['id'].toString();
    print("📞 [DEBUG] Customer Phone: $customerPhone");
    print("📞 [DEBUG] Driver Name: $driverName");
    print("📞 [DEBUG] Order ID: $orderId");

    try {
      print("📞 [CALL] Sending request to /taxi/v3/call/initiate...");
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/taxi/v3/call/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authResult.token}',
        },
        body: json.encode({
          'customer_phone': customerPhone,
          'driver_name': driverName,
          'order_id': orderId,
        }),
      );
      print("📞 [CALL] Response Status: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print("📞 [CALL] Response Data: $data");
        if (data['success'] == true) {
          print("✅ [CALL] Call request sent successfully!");
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverCallPage(
                channelName: data['channel_name'],
                customerName: _o['customer_name'] ?? 'زبون بيتي',
                customerPhone: customerPhone,
                agoraAppId: data['agora_app_id'] ?? '3924f8eebe7048f8a65cb3bd4a4adcec',
              ),
            ),
          );
        } else {
          throw Exception(data['message'] ?? 'فشل في إنشاء المكالمة');
        }
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        final errorData = json.decode(errorBody);
        final errorMsg = errorData['message'] ?? 'فشل الاتصال';
        print("❌ [CALL] Server error ($response.statusCode): $errorMsg");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الاتصال: $errorMsg")),
        );
      }
    } catch (e) {
      print("❌ [CALL] Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل الاتصال: ${e.toString()}")),
      );
    }
  }

  Future<void> _callSmart() async {
    final phone = _o['end_customer_phone'] ?? _o['customer_phone'];
    if (phone == null || phone.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("رقم الهاتف غير متوفر")));
      return;
    }
    setState(() => _callAttempts++);
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يمكن إجراء المكالمة")));
    }
    if (_callAttempts >= 3) {
      setState(() => _canShowNumber = true);
    }
  }

  Future<void> _map() async {
    final status = _o['order_status'];
    double lat = 0.0, lng = 0.0;
    String txt = "";
    if (status == 'accepted' || status == 'at_store') {
      lat = Helper.safeDouble(_o['pickup_lat']);
      lng = Helper.safeDouble(_o['pickup_lng']);
      txt = _o['pickup_location_name'] ?? "";
    } else {
      lat = Helper.safeDouble(_o['destination_lat']);
      lng = Helper.safeDouble(_o['destination_lng']);
      txt = _o['destination_address'] ?? "";
    }
    if (lat != 0.0 && lng != 0.0) {
      final waze = Uri.parse("waze://?ll=$lat,$lng&navigate=yes");
      final google = Uri.parse("google.navigation:q=$lat,$lng");
      if (await canLaunchUrl(waze)) {
        await launchUrl(waze, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(google, mode: LaunchMode.externalApplication);
      }
    } else if (txt.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("جاري البحث بالعنوان..."),
        duration: Duration(seconds: 1),
      ));
      final q = Uri.encodeComponent(txt);
      if (await canLaunchUrl(Uri.parse("waze://?q=$q"))) {
        await launchUrl(Uri.parse("waze://?q=$q"));
      } else {
        await launchUrl(Uri.parse("http://googleusercontent.com/maps.google.com/?q=$q"));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد بيانات موقع!")));
    }
  }

  Future<void> _track() async {
    if (!await Helper.handleLocationPermission(context)) return;
    _sub = geolocator.Geolocator.getPositionStream(
      locationSettings: const geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen((p) {
      if (!mounted) return;
      ApiService.updateDriverLocation(widget.authResult.token, p.latitude, p.longitude);
      double lat = 0, lng = 0;
      if (_o['order_status'] == 'picked_up') {
        lat = Helper.safeDouble(_o['destination_lat']);
        lng = Helper.safeDouble(_o['destination_lng']);
      } else {
        lat = Helper.safeDouble(_o['pickup_lat']);
        lng = Helper.safeDouble(_o['pickup_lng']);
      }
      if (lat != 0) {
        final d = geolocator.Geolocator.distanceBetween(p.latitude, p.longitude, lat, lng);
        setState(() => _dStr = d < 1000 ? "${d.round()} م" : "${(d / 1000).toStringAsFixed(1)} كم");
      }
    });
  }

  Future<void> _upd(String s) async {
    setState(() => _isLoading = true);
    final res = await ApiService.updateDeliveryStatus(
      widget.authResult.token,
      _o['id'].toString(),
      s,
    );
    setState(() => _isLoading = false);
    final d = json.decode(res.body);
    if (d['success'] == true) {
      if (s == 'delivered' || s == 'cancelled') {
        widget.onDeliveryFinished();
      } else {
        setState(() => _o = d['delivery_order']);
        widget.onDataChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _o['order_status'];
    Color stColor = Colors.blue;
    String stText = "جارِ التوجه للمطعم";
    if (s == 'at_store') {
      stColor = Colors.orange;
      stText = "في المطعم";
    } else if (s == 'picked_up') {
      stColor = Colors.purple;
      stText = "جارِ التوجه للزبون";
    }

    final rawPhone = _o['end_customer_phone'] ?? _o['customer_phone'] ?? "";
    final maskedPhone = rawPhone.length > 6
        ? "${rawPhone.substring(0, 4)}****${rawPhone.substring(rawPhone.length - 2)}"
        : "****";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [stColor.withOpacity(0.8), stColor]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: stColor.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.motorcycle, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "المسافة: $_dStr",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    )
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      _o['customer_name'] ?? 'زبون بيتي',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _canShowNumber ? "📞 $rawPhone" : "📞 $maskedPhone",
                          style: TextStyle(
                            color: _canShowNumber ? Colors.red : Colors.grey,
                            fontWeight: _canShowNumber ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "🕒 وقت الطلب: ${_o['date_formatted'] ?? 'اليوم'}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (_o['pickup_code'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            "🔢 رمز الاستلام: ${_o['pickup_code']}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: _canShowNumber
                        ? IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rawPhone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("تم نسخ الرقم: $rawPhone")),
                        );
                      },
                    )
                        : null,
                  ),
                  const Divider(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _initiateVoIP,
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: const Text(
                        "اتصال داخلي مجاني 📞",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_canShowNumber) ...[
                    Text(
                      "ملاحظة: سيتم إظهار الرقم بعد 3 محاولات فاشلة أو بعد 3 دقائق",
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _callSmart,
                    icon: Icon(
                      _canShowNumber ? Icons.phone_disabled : Icons.call,
                      color: _canShowNumber ? Colors.orange : Colors.grey,
                    ),
                    label: Text(
                      _canShowNumber
                          ? "اتصال عادي (المحاولة #$_callAttempts)"
                          : "اتصال عادي (يظهر الرقم بعد 3 محاولات)",
                      style: TextStyle(
                        color: _canShowNumber ? Colors.orange : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _canShowNumber ? Colors.orange : Colors.grey,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: Colors.grey[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _priceRow("سعر التوصيل (لك):", "${_o['delivery_fee']} نقطة", Colors.green.shade700),
                  const Divider(),
                  Text(
                    "📦 التفاصيل: ${_o['items_description']}",
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(),
                  if (_o['notes'] != null && _o['notes'].toString().isNotEmpty) ...[
                    Text(
                      "📝 ملاحظات: ${_o['notes']}",
                      style: const TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                    const Divider(),
                  ],
                  Text(
                    "📍 العنوان: ${_o['destination_address'] ?? 'غير محدد'}",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _map,
                  icon: const Icon(Icons.map, color: Colors.indigo),
                  label: const Text("الاتجاهات", style: TextStyle(color: Colors.indigo)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _upd('cancelled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                    foregroundColor: Colors.red.shade800,
                    elevation: 0,
                  ),
                  child: const Text("إلغاء الطلب"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (s == 'accepted') _mainBtn("وصلت للمطعم", Colors.blue.shade700, 'at_store'),
          if (s == 'at_store') _mainBtn("استلمت الطلب", Colors.orange.shade700, 'picked_up'),
          if (s == 'picked_up') _mainBtn("تم التوصيل", Colors.green.shade700, 'delivered'),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        )
      ],
    );
  }

  Widget _mainBtn(String txt, Color col, String next) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: col,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: _isLoading ? null : () => _upd(next),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
          txt,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
  const HistoryTabV3({super.key, required this.token});

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
                final active = all
                    .where((o) => ['accepted', 'at_store', 'picked_up'].contains(o['status']))
                    .toList();
                final archive = all
                    .where((o) => ['delivered', 'cancelled'].contains(o['status']))
                    .toList();
                return TabBarView(
                  children: [_list(active, false), _list(archive, true)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<dynamic> list, bool isArchive) {
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
            leading: Icon(
              isArchive ? (isDone ? Icons.check_circle : Icons.cancel) : Icons.motorcycle,
              color: isDone ? Colors.green : (status == 'cancelled' ? Colors.red : Colors.blue),
            ),
            title: Text("طلب #${o['id']} - $status"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("تاريخ: ${o['date']}"),
                Text("المصدر: ${o['pickup_location']}"),
                if (isArchive) Text("هاتف: ${_mask(o['customer_phone'])}")
              ],
            ),
            trailing: Text(
              "${o['delivery_fee']} نقطة",
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
    return FutureBuilder<int>(
      future: ApiService.getPoints(token),
      builder: (c, s) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.stars,
              size: 80,
              color: (s.data ?? 0) <= 3 ? Colors.red : Colors.amber,
            ),
            Text(
              "${s.data ?? 0}",
              style: const TextStyle(fontSize: 40),
            ),
            const Text("نقطة"),
            const SizedBox(height: 20),
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
      ),
    );
  }
}

class DriverCallPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("مكالمة مع $customerName"),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              "جارٍ الاتصال بـ $customerName",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "الرقم: $customerPhone",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Text(
              "ملاحظة: هذه مكالمة داخلية مجانية عبر الإنترنت",
              style: const TextStyle(fontSize: 14, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
