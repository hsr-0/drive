// =============================================================================
// 🤝 تطبيق المروجين المتكامل - Beytei Promoter App (النسخة النهائية المُصححة)
// 🌐 السيرفر: re.beytei.com
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================================================================
// 🔧 الإعدادات الأساسية
// =============================================================================
const String BASE_URL = 'https://re.beytei.com/wp-json/restaurant-app/v1';

// =============================================================================
// 🎨 الألوان والثيم
// =============================================================================
class AppColors {
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4A42D1);
  static const Color secondary = Color(0xFFFF6584);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color background = Color(0xFFF5F7FA);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);
  static const Color gold = Color(0xFFFFD700);
}

// =============================================================================
// 📦 النماذج (Models)
// =============================================================================
class PromoterDashboard {
  final String code;
  final double walletBalance;
  final int totalOrders;
  final double totalEarnings;
  final int incentiveProgress;
  final int? nextTarget;
  final double? nextReward;
  final List<Incentive> incentives;
  final double minWithdrawal;

  PromoterDashboard({
    required this.code,
    required this.walletBalance,
    required this.totalOrders,
    required this.totalEarnings,
    required this.incentiveProgress,
    this.nextTarget,
    this.nextReward,
    required this.incentives,
    required this.minWithdrawal,
  });

  factory PromoterDashboard.fromJson(Map<String, dynamic> json) {
    print('🔍 [Model] PromoterDashboard.fromJson() called');
    print('🔍 [Model] JSON keys: ${json.keys.toList()}');
    print('🔍 [Model] Full JSON: $json');

    try {
      final dashboard = PromoterDashboard(
        code: json['code']?.toString() ?? '',
        walletBalance: double.tryParse(json['wallet_balance']?.toString() ?? '0') ?? 0.0,
        totalOrders: int.tryParse(json['total_orders']?.toString() ?? '0') ?? 0,
        totalEarnings: double.tryParse(json['total_earnings']?.toString() ?? '0') ?? 0.0,
        incentiveProgress: int.tryParse(json['incentive_progress']?.toString() ?? '0') ?? 0,
        nextTarget: json['next_target'] != null ? int.tryParse(json['next_target'].toString()) : null,
        nextReward: json['next_reward'] != null ? double.tryParse(json['next_reward'].toString()) : null,
        incentives: (json['incentives'] as List?)
            ?.map((i) => Incentive.fromJson(i as Map<String, dynamic>))
            .toList() ?? [],
        minWithdrawal: double.tryParse(json['min_withdrawal']?.toString() ?? '25000') ?? 25000.0,
      );

      print('✅ [Model] Dashboard created successfully');
      print('✅ [Model] Code: ${dashboard.code}');
      print('✅ [Model] Wallet: ${dashboard.walletBalance}');
      print('✅ [Model] Orders: ${dashboard.totalOrders}');

      return dashboard;
    } catch (e, stackTrace) {
      print('❌ [Model] Exception in fromJson: $e');
      print('❌ [Model] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

class Incentive {
  final int target;
  final double reward;
  final String description;

  Incentive({
    required this.target,
    required this.reward,
    required this.description,
  });

  factory Incentive.fromJson(Map<String, dynamic> json) {
    print('🔍 [Model] Incentive.fromJson() called');
    print('🔍 [Model] JSON: $json');

    return Incentive(
      target: int.tryParse(json['target']?.toString() ?? '0') ?? 0,
      reward: double.tryParse(json['reward']?.toString() ?? '0') ?? 0.0,
      description: json['description']?.toString() ?? '',
    );
  }
}

class PromoterOrder {
  final int orderId;
  final String customerName;
  final double total;
  final double commission;
  final String date;

  PromoterOrder({
    required this.orderId,
    required this.customerName,
    required this.total,
    required this.commission,
    required this.date,
  });

  factory PromoterOrder.fromJson(Map<String, dynamic> json) {
    print('🔍 [Model] PromoterOrder.fromJson() called');
    print('🔍 [Model] JSON: $json');

    return PromoterOrder(
      orderId: int.tryParse(json['order_id']?.toString() ?? '0') ?? 0,
      customerName: json['customer_name']?.toString() ?? 'زبون',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      commission: double.tryParse(json['commission']?.toString() ?? '0') ?? 0.0,
      date: json['date']?.toString() ?? '',
    );
  }
}

// =============================================================================
// 🌐 خدمة الـ API
// =============================================================================
class PromoterService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('promoter_token');
  }

  static Future<int?> getPromoterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('promoter_id');
  }

  static Future<String?> getPromoterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('promoter_name');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final result = token != null && token.isNotEmpty;
    print('🔍 [PromoterService] isLoggedIn check: $result');
    return result;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Promoter-Token'] = token;
    }

    print('🔍 [PromoterService] Generated Headers: $headers');
    return headers;
  }

  static Future<void> loadSavedData() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [PromoterService] loadSavedData() called (Live Check)');
    print('═══════════════════════════════════════════════════════');

    try {
      final token = await getToken();
      final id = await getPromoterId();
      final name = await getPromoterName();
      final loggedIn = await isLoggedIn();

      print('🔍 [PromoterService] Live Token: ${token ?? 'NULL'}');
      print('🔍 [PromoterService] Live ID: ${id ?? 'NULL'}');
      print('🔍 [PromoterService] Live Name: ${name ?? 'NULL'}');
      print('🔍 [PromoterService] Live isLoggedIn: $loggedIn');
      print('═══════════════════════════════════════════════════════');
      print('');
    } catch (e, stackTrace) {
      print('❌ [PromoterService] Exception in loadSavedData: $e');
      print('❌ [PromoterService] Stack trace: $stackTrace');
    }
  }

  static Future<void> saveLoginData(
      String token, int promoterId, String name) async {
    print('🔍 [PromoterService] saveLoginData() called');

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('promoter_token', token);
      await prefs.setInt('promoter_id', promoterId);
      await prefs.setString('promoter_name', name);

      print('✅ [PromoterService] Data securely saved to disk');
    } catch (e, stackTrace) {
      print('❌ [PromoterService] Exception in saveLoginData: $e');
    }
  }

  static Future<void> logout() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [PromoterService] logout() called');
    print('═══════════════════════════════════════════════════════');

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('promoter_token');
      await prefs.remove('promoter_id');
      await prefs.remove('promoter_name');

      print('✅ [PromoterService] Login keys successfully removed from disk');
      print('═══════════════════════════════════════════════════════');
      print('');
    } catch (e, stackTrace) {
      print('❌ [PromoterService] Exception in logout: $e');
      print('❌ [PromoterService] Stack trace: $stackTrace');
    }
  }

  static Future<Map<String, dynamic>> login(
      String phone, String password) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [PromoterService] login() called');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [PromoterService] Phone: $phone');
    print('🔍 [PromoterService] Password: ${password.isNotEmpty ? '***' : 'EMPTY'}');

    try {
      final url = '$BASE_URL/promoter-login';
      print('🔍 [PromoterService] URL: $url');

      final body = jsonEncode({'phone': phone, 'password': password});
      print('🔍 [PromoterService] Request body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('🔍 [PromoterService] Response status: ${response.statusCode}');
      print('🔍 [PromoterService] Response body: ${response.body}');

      if (response.body.isEmpty) {
        print('❌ [PromoterService] Empty response body');
        return {'success': false, 'message': 'استجابة فارغة من السيرفر'};
      }

      final data = jsonDecode(response.body);
      print('🔍 [PromoterService] Decoded data: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ [PromoterService] Login successful');

        final token = data['token']?.toString();
        final promoterId = data['promoter_id'];
        final name = data['name']?.toString();

        if (token == null || token.isEmpty) {
          print('❌ [PromoterService] Token is null or empty');
          return {'success': false, 'message': 'التوكن غير موجود في الاستجابة'};
        }

        if (promoterId == null) {
          print('❌ [PromoterService] Promoter ID is null');
          return {'success': false, 'message': 'معرف المروج غير موجود في الاستجابة'};
        }

        final promoterIdInt = int.tryParse(promoterId.toString());
        if (promoterIdInt == null) {
          print('❌ [PromoterService] Promoter ID is not a valid integer');
          return {'success': false, 'message': 'معرف المروج غير صحيح'};
        }

        await saveLoginData(
          token,
          promoterIdInt,
          name ?? 'مروج',
        );

        print('✅ [PromoterService] Login flow completed successfully');
        print('═══════════════════════════════════════════════════════');
        print('');

        return {'success': true, 'message': data['message'] ?? 'تم تسجيل الدخول بنجاح'};
      } else {
        print('❌ [PromoterService] Login failed: ${data['message']}');
        print('═══════════════════════════════════════════════════════');
        print('');
        return {
          'success': false,
          'message': data['message'] ?? 'فشل الدخول (كود: ${response.statusCode})'
        };
      }
    } catch (e, stackTrace) {
      print('❌ [PromoterService] Exception in login: $e');
      print('❌ [PromoterService] Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }

  static Future<PromoterDashboard?> getDashboard() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [PromoterService] getDashboard() called');
    print('═══════════════════════════════════════════════════════');

    final token = await getToken();
    if (token == null || token.isEmpty) {
      print('❌ [PromoterService] Live Token is null or empty, cannot fetch dashboard');
      print('═══════════════════════════════════════════════════════');
      print('');
      return null;
    }

    try {
      final url = '$BASE_URL/promoter-dashboard';
      final headers = await _getHeaders();

      print('🔍 [PromoterService] URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('🔍 [PromoterService] Response status: ${response.statusCode}');

      if (response.body.isEmpty) {
        print('❌ [PromoterService] Empty response body');
        print('═══════════════════════════════════════════════════════');
        print('');
        return null;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          print('✅ [PromoterService] API returned success=true');

          if (data['data'] == null) {
            print('❌ [PromoterService] data field is null');
            print('═══════════════════════════════════════════════════════');
            print('');
            return null;
          }

          final dashboard = PromoterDashboard.fromJson(data['data'] as Map<String, dynamic>);
          print('✅ [PromoterService] Dashboard fetched successfully');
          print('═══════════════════════════════════════════════════════');
          print('');
          return dashboard;
        } else {
          print('❌ [PromoterService] API returned success=false');
          print('❌ [PromoterService] Message: ${data['message']}');
          print('═══════════════════════════════════════════════════════');
          print('');
          return null;
        }
      } else {
        print('❌ [PromoterService] Unexpected status code: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════');
        print('');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ [PromoterService] Exception in getDashboard: $e');
      print('❌ [PromoterService] Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');
      return null;
    }
  }

  static Future<List<PromoterOrder>> getOrders() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [PromoterService] getOrders() called');
    print('═══════════════════════════════════════════════════════');

    final token = await getToken();
    if (token == null || token.isEmpty) {
      print('❌ [PromoterService] Live Token is null or empty, cannot fetch orders');
      print('═══════════════════════════════════════════════════════');
      print('');
      return [];
    }

    try {
      final url = '$BASE_URL/promoter-orders';
      final headers = await _getHeaders();

      print('🔍 [PromoterService] URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('🔍 [PromoterService] Response status: ${response.statusCode}');

      if (response.body.isEmpty) {
        print('❌ [PromoterService] Empty response body');
        print('═══════════════════════════════════════════════════════');
        print('');
        return [];
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          print('✅ [PromoterService] API returned success=true');

          if (data['orders'] == null) {
            print('⚠️ [PromoterService] orders field is null');
            print('═══════════════════════════════════════════════════════');
            print('');
            return [];
          }

          final orders = (data['orders'] as List)
              .map((o) => PromoterOrder.fromJson(o as Map<String, dynamic>))
              .toList();

          print('✅ [PromoterService] Orders fetched: ${orders.length}');
          print('═══════════════════════════════════════════════════════');
          print('');
          return orders;
        } else {
          print('❌ [PromoterService] API returned success=false');
          print('❌ [PromoterService] Message: ${data['message']}');
          print('═══════════════════════════════════════════════════════');
          print('');
          return [];
        }
      } else {
        print('❌ [PromoterService] Unexpected status code: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════');
        print('');
        return [];
      }
    } catch (e, stackTrace) {
      print('❌ [PromoterService] Exception in getOrders: $e');
      print('❌ [PromoterService] Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');
      return [];
    }
  }

  static Future<Map<String, dynamic>> withdraw() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [PromoterService] withdraw() called');
    print('═══════════════════════════════════════════════════════');

    final token = await getToken();
    if (token == null || token.isEmpty) {
      print('❌ [PromoterService] Live Token is null or empty, cannot withdraw');
      print('═══════════════════════════════════════════════════════');
      print('');
      return {'success': false, 'message': 'غير مصرح'};
    }

    try {
      final url = '$BASE_URL/promoter-withdraw';
      final headers = await _getHeaders();

      print('🔍 [PromoterService] URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      print('🔍 [PromoterService] Response status: ${response.statusCode}');

      if (response.body.isEmpty) {
        print('❌ [PromoterService] Empty response body');
        print('═══════════════════════════════════════════════════════');
        print('');
        return {'success': false, 'message': 'استجابة فارغة من السيرفر'};
      }

      final data = jsonDecode(response.body);
      print('🔍 [PromoterService] Decoded withdraw response correctly');
      print('═══════════════════════════════════════════════════════');
      print('');

      return data;
    } catch (e, stackTrace) {
      print('❌ [PromoterService] Exception in withdraw: $e');
      print('❌ [PromoterService] Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');

      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }
}

// =============================================================================
// 🚪 بوابة المروجين (Promoter Gate) - نقطة الدخول من تطبيق السائقين
// =============================================================================
// استدعي هذه الشاشة من تطبيق السائقين هكذا:
// Navigator.push(context, MaterialPageRoute(builder: (_) => const PromoterGateScreen()));

class PromoterGateScreen extends StatefulWidget {
  const PromoterGateScreen({Key? key}) : super(key: key);

  @override
  State<PromoterGateScreen> createState() => _PromoterGateScreenState();
}

class _PromoterGateScreenState extends State<PromoterGateScreen> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [GateScreen] initState() called');
    print('═══════════════════════════════════════════════════════');
    _checkInitialLoginState();
  }

  Future<void> _checkInitialLoginState() async {
    print('🔍 [GateScreen] Checking initial login state...');

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ إجبار التحديث لضمان قراءة أحدث البيانات من القرص
      await prefs.reload();

      final savedToken = prefs.getString('promoter_token');
      final savedId = prefs.getInt('promoter_id');
      final savedName = prefs.getString('promoter_name');

      print('🔍 [GateScreen] Token: ${savedToken != null ? '*** (Found)' : 'NULL (Not Found)'}');
      print('🔍 [GateScreen] ID: ${savedId ?? 'NULL'}');
      print('🔍 [GateScreen] Name: ${savedName ?? 'NULL'}');

      if (savedToken != null && savedToken.isNotEmpty) {
        print('✅ [GateScreen] Token found! Navigating to Dashboard.');
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _isLoading = false;
          });
        }
      } else {
        print('❌ [GateScreen] Token NOT found! Navigating to Login.');
        if (mounted) {
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ [GateScreen] Error checking login state: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }

    print('═══════════════════════════════════════════════════════');
    print('');
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 [GateScreen] build() called');
    print('🔍 [GateScreen] _isLoading: $_isLoading');
    print('🔍 [GateScreen] _isLoggedIn: $_isLoggedIn');

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return _isLoggedIn
        ? const PromoterDashboardScreen()
        : const PromoterLoginScreen();
  }
}

// =============================================================================
// 🔐 شاشة تسجيل الدخول
// =============================================================================
class PromoterLoginScreen extends StatefulWidget {
  const PromoterLoginScreen({Key? key}) : super(key: key);

  @override
  State<PromoterLoginScreen> createState() => _PromoterLoginScreenState();
}

class _PromoterLoginScreenState extends State<PromoterLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [LoginScreen] initState() called');
    print('═══════════════════════════════════════════════════════');
    print('');
  }

  Future<void> _login() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [LoginScreen] _login() called');
    print('═══════════════════════════════════════════════════════');

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    print('🔍 [LoginScreen] Phone: $phone');
    print('🔍 [LoginScreen] Password length: ${password.length}');

    if (phone.isEmpty || password.isEmpty) {
      print('❌ [LoginScreen] Phone or password is empty');
      _showSnackBar('يرجى إدخال رقم الهاتف وكلمة المرور', Colors.red);
      print('═══════════════════════════════════════════════════════');
      print('');
      return;
    }

    setState(() => _isLoading = true);
    print('🔍 [LoginScreen] Loading state set to true');

    final result = await PromoterService.login(phone, password);

    print('🔍 [LoginScreen] Login result: $result');

    setState(() => _isLoading = false);
    print('🔍 [LoginScreen] Loading state set to false');

    if (result['success'] == true) {
      print('✅ [LoginScreen] Login successful, navigating to dashboard');
      _showSnackBar('✅ تم تسجيل الدخول بنجاح', Colors.green);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('🔍 [LoginScreen] Navigating to PromoterDashboardScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PromoterDashboardScreen()),
          );
        } else {
          print('❌ [LoginScreen] Widget not mounted, cannot navigate');
        }
      });
    } else {
      print('❌ [LoginScreen] Login failed: ${result['message']}');
      _showSnackBar('❌ ${result['message']}', Colors.red);
    }

    print('═══════════════════════════════════════════════════════');
    print('');
  }

  void _showSnackBar(String message, Color color) {
    print('🔍 [LoginScreen] _showSnackBar: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 [LoginScreen] build() called');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6C63FF),
              Color(0xFF4A42D1),
              Color(0xFF2E2A8A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.handshake_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'برنامج المروجين',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سجّل دخولك لمتابعة أرباحك وحوافزك',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                          controller: _phoneController,
                          label: 'رقم الهاتف',
                          hint: '07XXXXXXXXX',
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'كلمة المرور / الرمز',
                          hint: '••••••',
                          icon: Icons.lock_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.textLight,
                            ),
                            onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'احصل على بيانات الدخول من الإدارة',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    print('🔍 [LoginScreen] dispose() called');
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// =============================================================================
// 🏠 لوحة التحكم الرئيسية (Dashboard)
// =============================================================================
class PromoterDashboardScreen extends StatefulWidget {
  const PromoterDashboardScreen({Key? key}) : super(key: key);

  @override
  State<PromoterDashboardScreen> createState() =>
      _PromoterDashboardScreenState();
}

class _PromoterDashboardScreenState extends State<PromoterDashboardScreen> {
  PromoterDashboard? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  String _promoterName = 'مروج';

  @override
  void initState() {
    super.initState();
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [DashboardScreen] initState() called');
    print('═══════════════════════════════════════════════════════');

    _loadName();

    print('🔍 [DashboardScreen] Calling _loadDashboard()');
    print('');

    _loadDashboard();
  }

  Future<void> _loadName() async {
    final name = await PromoterService.getPromoterName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() {
        _promoterName = name;
      });
    }
  }

  Future<void> _loadDashboard() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [DashboardScreen] _loadDashboard() called');
    print('═══════════════════════════════════════════════════════');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('🔍 [DashboardScreen] Loading state set to true');
    print('🔍 [DashboardScreen] Calling PromoterService.getDashboard()');

    final data = await PromoterService.getDashboard();

    print('🔍 [DashboardScreen] Dashboard data received: ${data != null ? 'SUCCESS' : 'NULL'}');

    if (data != null) {
      print('✅ [DashboardScreen] Dashboard loaded successfully');
      print('✅ [DashboardScreen] Code: ${data.code}');
      print('✅ [DashboardScreen] Wallet: ${data.walletBalance}');
      print('✅ [DashboardScreen] Orders: ${data.totalOrders}');

      setState(() {
        _dashboard = data;
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      print('❌ [DashboardScreen] Failed to load dashboard');

      setState(() {
        _dashboard = null;
        _isLoading = false;
        _errorMessage = 'فشل تحميل البيانات. تحقق من اتصالك بالإنترنت أو حاول مرة أخرى.';
      });

      _showSnackBar('❌ فشل تحميل البيانات', Colors.red);
    }

    print('═══════════════════════════════════════════════════════');
    print('');
  }

  Future<void> _logout() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 [DashboardScreen] _logout() called');
    print('═══════════════════════════════════════════════════════');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل تريد تسجيل الخروج؟',
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      print('🔍 [DashboardScreen] User confirmed logout');
      await PromoterService.logout();

      if (mounted) {
        print('🔍 [DashboardScreen] Navigating to PromoterLoginScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PromoterLoginScreen()),
        );
      } else {
        print('❌ [DashboardScreen] Widget not mounted, cannot navigate');
      }
    } else {
      print('🔍 [DashboardScreen] User cancelled logout');
    }

    print('═══════════════════════════════════════════════════════');
    print('');
  }

  void _showSnackBar(String message, Color color) {
    print('🔍 [DashboardScreen] _showSnackBar: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 [DashboardScreen] build() called');
    print('🔍 [DashboardScreen] _isLoading: $_isLoading');
    print('🔍 [DashboardScreen] _dashboard: ${_dashboard != null ? 'NOT NULL' : 'NULL'}');
    print('🔍 [DashboardScreen] _errorMessage: ${_errorMessage ?? 'NULL'}');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          'مرحباً $_promoterName 👋',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dashboard == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'فشل تحميل البيانات',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'الرجاء التحقق من الكونسول لمعرفة التفاصيل',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                print('🔍 [DashboardScreen] User pressed logout from error screen');
                _logout();
              },
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadDashboard,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCodeCard(),
              const SizedBox(height: 16),
              _buildStatsGrid(),
              const SizedBox(height: 16),
              _buildIncentivesCard(),
              const SizedBox(height: 16),
              _buildWithdrawButton(),
              const SizedBox(height: 16),
              _buildShareCard(),
              const SizedBox(height: 16),
              _buildOrdersButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'كود الخصم الخاص بك',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dashboard!.code.isEmpty ? 'لم يتم تعيين كود' : _dashboard!.code,
                    style: TextStyle(
                      fontSize: _dashboard!.code.isEmpty ? 16 : 24,
                      fontWeight: FontWeight.bold,
                      color: _dashboard!.code.isEmpty ? Colors.grey : AppColors.primary,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (_dashboard!.code.isNotEmpty) ...[
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _dashboard!.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ تم نسخ الكود',
                              style: TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded,
                        color: AppColors.primary),
                    tooltip: 'نسخ الكود',
                  ),
                  IconButton(
                    onPressed: _shareCode,
                    icon: const Icon(Icons.share_rounded,
                        color: AppColors.primary),
                    tooltip: 'مشاركة الكود',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'شارك هذا الكود مع أصدقائك واحصل على عمولة لكل طلب!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: Icons.shopping_bag_rounded,
          label: 'الطلبات الناجحة',
          value: '${_dashboard!.totalOrders}',
          color: AppColors.success,
          suffix: 'طلب',
        ),
        _buildStatCard(
          icon: Icons.account_balance_wallet_rounded,
          label: 'الرصيد المتاح',
          value: _formatMoney(_dashboard!.walletBalance),
          color: AppColors.warning,
          suffix: 'د.ع',
        ),
        _buildStatCard(
          icon: Icons.emoji_events_rounded,
          label: 'إجمالي الأرباح',
          value: _formatMoney(_dashboard!.totalEarnings),
          color: AppColors.primary,
          suffix: 'د.ع',
        ),
        _buildStatCard(
          icon: Icons.trending_up_rounded,
          label: 'تقدم الحافز',
          value: '${_dashboard!.incentiveProgress}',
          color: AppColors.secondary,
          suffix: _dashboard!.nextTarget != null
              ? '/ ${_dashboard!.nextTarget}'
              : '',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String suffix = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Cairo',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withOpacity(0.7),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncentivesCard() {
    if (_dashboard!.incentives.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            '🎁 لا توجد حوافز مفعّلة حالياً',
            style: TextStyle(
              color: AppColors.textLight,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6584).withOpacity(0.1),
            const Color(0xFFFF6584).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6584).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.celebration_rounded, color: Color(0xFFFF6584), size: 24),
              SizedBox(width: 8),
              Text(
                '🎁 الحوافز والمكافآت',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_dashboard!.nextTarget != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFF6584).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🎯 الحافز القادم',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+${_formatMoney(_dashboard!.nextReward ?? 0)} د.ع',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _dashboard!.nextTarget != null && _dashboard!.nextTarget! > 0
                          ? (_dashboard!.incentiveProgress / _dashboard!.nextTarget!).clamp(0.0, 1.0)
                          : 0.0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFF6584)),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_dashboard!.incentiveProgress} طلب',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        'الهدف: ${_dashboard!.nextTarget} طلب',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          ..._dashboard!.incentives.map((incentive) {
            final isAchieved =
                _dashboard!.incentiveProgress >= incentive.target;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAchieved
                    ? AppColors.success.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAchieved
                      ? AppColors.success.withOpacity(0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAchieved
                          ? AppColors.success
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isAchieved
                          ? Icons.check_circle_rounded
                          : Icons.flag_rounded,
                      color: isAchieved ? Colors.white : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incentive.description.isNotEmpty
                              ? incentive.description
                              : 'إكمال ${incentive.target} طلب',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAchieved
                                ? AppColors.success
                                : AppColors.textDark,
                            fontFamily: 'Cairo',
                            decoration: isAchieved
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'مكافأة: ${_formatMoney(incentive.reward)} د.ع',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAchieved
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    final canWithdraw =
        _dashboard!.walletBalance >= _dashboard!.minWithdrawal;
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: canWithdraw ? _withdraw : null,
        icon: const Icon(Icons.account_balance_wallet_rounded, size: 26),
        label: Text(
          canWithdraw
              ? '💸 سحب الأرباح (${_formatMoney(_dashboard!.walletBalance)} د.ع)'
              : '🔒 الرصيد أقل من ${_formatMoney(_dashboard!.minWithdrawal)} د.ع',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canWithdraw ? AppColors.success : Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canWithdraw ? 4 : 0,
        ),
      ),
    );
  }

  Widget _buildShareCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FACFE).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚀 شارك واربح أكثر!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'كلما شاركت كودك مع أصدقائك، كلما زادت أرباحك! 🎉\n'
                'احصل على عمولة فورية عند كل طلب مكتمل.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Cairo',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareCode,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text(
                    'مشاركة الكود',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4FACFE),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareViaWhatsApp,
                  icon: const Icon(Icons.phone),
                  label: const Text(
                    'واتساب',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PromoterOrdersScreen()),
          );
        },
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text(
          '📋 عرض الطلبات المكتملة (${_dashboard!.totalOrders})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _shareCode() {
    final message = '''
🎁 احصل على خصم مميز مع تطبيق بيتي!

استخدم كود الخصم الخاص بي: ${_dashboard!.code}

📱 حمّل التطبيق الآن من: re.beytei.com
''';
    _share(message);
  }

  void _shareViaWhatsApp() {
    final message = Uri.encodeComponent('''
🎁 احصل على خصم مميز مع تطبيق بيتي!

استخدم كود الخصم: ${_dashboard!.code}

📱 حمّل التطبيق الآن!
''');
    launchUrl(Uri.parse('https://wa.me/?text=$message'));
  }

  void _share(String message) {
    final encoded = Uri.encodeComponent(message);
    launchUrl(Uri.parse('https://api.whatsapp.com/send?text=$encoded'));
  }

  Future<void> _withdraw() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(
              child: Text('تأكيد السحب',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم تحويلك إلى الواتساب لإرسال طلب السحب للإدارة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المبلغ:',
                      style: TextStyle(fontFamily: 'Cairo')),
                  Text(
                    '${_formatMoney(_dashboard!.walletBalance)} د.ع',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
            ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('تأكيد السحب',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await PromoterService.withdraw();
    if (result['success'] == true && result['whatsapp_link'] != null) {
      final link = result['whatsapp_link'] as String;
      if (await canLaunchUrl(Uri.parse(link))) {
        await launchUrl(Uri.parse(link));
      } else {
        _showSnackBar('❌ لا يمكن فتح الواتساب', Colors.red);
      }
    } else {
      _showSnackBar('❌ ${result['message'] ?? 'فشل طلب السحب'}', Colors.red);
    }
  }
}

// =============================================================================
// 📋 شاشة الطلبات
// =============================================================================
class PromoterOrdersScreen extends StatefulWidget {
  const PromoterOrdersScreen({Key? key}) : super(key: key);

  @override
  State<PromoterOrdersScreen> createState() => _PromoterOrdersScreenState();
}

class _PromoterOrdersScreenState extends State<PromoterOrdersScreen> {
  List<PromoterOrder> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await PromoterService.getOrders();
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  String _formatMoney(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'الطلبات المكتملة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'لا توجد طلبات مكتملة بعد',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textLight,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'شارك كودك مع أصدقائك لبدء كسب العمولات!',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            return _buildOrderCard(order);
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(PromoterOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب #${order.orderId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '✅ مكتمل',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppColors.textLight, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.customerName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '${order.total.toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withOpacity(0.1),
                  AppColors.success.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monetization_on_rounded,
                        color: AppColors.success, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'عمولتك:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                Text(
                  '+${order.commission.toStringAsFixed(0)} د.ع',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}