import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:fluttertoast/fluttertoast.dart';

// =======================================================================
// 🔷 القسم 1: الثوابت (Constants)
// =======================================================================
class AppConstants {
  static const String BEYTEI_URL = 'https://re.beytei.com';
  static const String baseUrl = "https://re.beytei.com/wp-json";
  static const Duration API_TIMEOUT = Duration(seconds: 30);
}

// Display names are read from the restaurant's authenticated manager-context.
// This fallback is only for old responses missing the localized label.
String beyteiZoneName(int? id, [List<Map<String, dynamic>> areas = const []]) {
  if (id == null || id <= 0) return 'غير محددة';
  for (final area in areas) {
    if (int.tryParse('${area['id']}') == id) {
      final name = (area['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
  }
  const familiar = <int, String>{
    42: 'النعمانية',
    36: 'العزيزية',
    84: 'الكوت',
    85: 'الصويرة',
  };
  return familiar[id] ?? 'منطقة $id';
}
String beyteiZoneDescription(int? id, [List<Map<String, dynamic>> areas = const []]) {
  if (id == null || id <= 0) return 'المنطقة غير محددة';
  return '${beyteiZoneName(id, areas)} — منطقة $id';
}

// =======================================================================
// 🔷 القسم 2: خدمة الصلاحيات (Permission Service) - 🔥 إصلاح رئيسي
// =======================================================================
/// 🔥 هذه الكلاس تحل مشكلة فشل تحديد الموقع بسبب نقص الصلاحيات
class PermissionService {
  static Future<bool> handleLocationPermission(BuildContext context) async {
    // 1. فحص تفعيل خدمات الموقع (GPS)
    bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ خدمات الموقع معطلة. الرجاء تفعيل GPS من الإعدادات.'),
              backgroundColor: Colors.orange,
            )
        );
      }
      return false;
    }

    // 2. فحص الصلاحيات الحالية
    geolocator.LocationPermission permission = await geolocator.Geolocator.checkPermission();

    if (permission == geolocator.LocationPermission.denied) {
      // طلب الصلاحية لأول مرة
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ تم رفض إذن الوصول للموقع.'),
                backgroundColor: Colors.red,
              )
          );
        }
        return false;
      }
    }

    // 3. فحص الرفض الدائم
    if (permission == geolocator.LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من إعدادات التطبيق.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            )
        );
      }
      return false;
    }

    // 4. النجاح!
    return true;
  }
}

// =======================================================================
// 🔷 القسم 3: الموديلات (Models)
// =======================================================================

class Restaurant {
  final int id;
  final String name;
  final String imageUrl;
  bool isDeliverable;
  final double averageRating;
  final int ratingCount;
  bool isOpen;
  String autoOpenTime;
  String autoCloseTime;
  final double latitude;
  final double longitude;

  Restaurant({
    required this.id, required this.name, required this.imageUrl,
    this.isDeliverable = false, this.averageRating = 0.0, this.ratingCount = 0,
    required this.isOpen, required this.autoOpenTime, required this.autoCloseTime,
    required this.latitude, required this.longitude,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    double avgRating = 0.0; int rCount = 0;
    String openTime = '09:00'; String closeTime = '22:00';
    bool finalIsOpenStatus = true; double lat = 0.0; double lng = 0.0;

    if (json['meta_data'] != null && json['meta_data'] is List) {
      final metaData = json['meta_data'] as List;
      var ratingMeta = metaData.firstWhere((m) => m is Map && m['key'] == '_wc_average_rating', orElse: () => null);
      if (ratingMeta != null) avgRating = double.tryParse(ratingMeta['value'].toString()) ?? 0.0;

      var countMeta = metaData.firstWhere((m) => m is Map && m['key'] == '_wc_rating_count', orElse: () => null);
      if (countMeta != null) rCount = int.tryParse(countMeta['value'].toString()) ?? 0;

      var isOpenMeta = metaData.firstWhere((m) => m is Map && m['key'] == '_restaurant_is_open', orElse: () => null);
      if (isOpenMeta != null) finalIsOpenStatus = isOpenMeta['value'].toString() == '1';

      var openMeta = metaData.firstWhere((m) => m is Map && m['key'] == '_restaurant_auto_open_time', orElse: () => null);
      if (openMeta != null) openTime = openMeta['value'].toString();

      var closeMeta = metaData.firstWhere((m) => m is Map && m['key'] == '_restaurant_auto_close_time', orElse: () => null);
      if (closeMeta != null) closeTime = closeMeta['value'].toString();

      var latMeta = metaData.firstWhere((m) => m is Map && m['key'] == 'restaurant_latitude', orElse: () => null);
      if (latMeta != null) lat = double.tryParse(latMeta['value'].toString()) ?? 0.0;

      var lngMeta = metaData.firstWhere((m) => m is Map && m['key'] == 'restaurant_longitude', orElse: () => null);
      if (lngMeta != null) lng = double.tryParse(lngMeta['value'].toString()) ?? 0.0;
    }

    String imageUrl = '';
    if (json['image'] != null) {
      if (json['image'] is Map && json['image']['src'] != null) {
        imageUrl = json['image']['src'].toString();
      } else if (json['image'] is String && json['image'].toString().isNotEmpty) {
        imageUrl = json['image'].toString();
      }
    }

    return Restaurant(
      id: json['id'] ?? 0, name: json['name'] ?? 'اسم غير معروف', imageUrl: imageUrl,
      averageRating: avgRating, ratingCount: rCount, isOpen: finalIsOpenStatus,
      autoOpenTime: openTime, autoCloseTime: closeTime, latitude: lat, longitude: lng,
    );
  }
}

class FoodItem {
  final int id; final String name; final String description;
  final double price; final double? salePrice; final String imageUrl;
  int quantity; final int categoryId; final String status;
  final String availabilityStart;
  final String availabilityEnd;
  bool get isHidden => status != 'publish';

  FoodItem({
    required this.id, required this.name, required this.description,
    required this.price, this.salePrice, required this.imageUrl,
    this.quantity = 1, required this.categoryId, this.status = 'publish',
    this.availabilityStart = '', this.availabilityEnd = '',
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    double safeParseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString().trim()) ?? defaultValue;
    }

    String extractImageUrl(dynamic images) {
      if (images is List && images.isNotEmpty && images[0] is Map && images[0]['src'] != null) {
        return images[0]['src'];
      }
      return '';
    }

    int extractRestaurantId(Map<String, dynamic> json) {
      dynamic categories = json['categories'];
      if (categories is List && categories.isNotEmpty && categories[0] is Map) {
        return int.tryParse(categories[0]['id'].toString()) ?? 0;
      }
      return 0;
    }

    return FoodItem(
      id: json['id'] ?? 0, name: json['name'] ?? 'غير متوفر',
      description: json['short_description'] is String ? json['short_description'].replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim() : '',
      price: safeParseDouble(json['regular_price']),
      salePrice: (json['sale_price'] != '' && json['sale_price'] != null) ? safeParseDouble(json['sale_price'], -1.0) : null,
      imageUrl: extractImageUrl(json['images']), categoryId: extractRestaurantId(json), status: json['status']?.toString() ?? 'publish',
      availabilityStart:(json['availability_start']??'').toString(),
      availabilityEnd:(json['availability_end']??'').toString(),
    );
  }
}

class Order {
  final int id;
  final String status;
  final DateTime dateCreated;
  final DateTime? dateCompleted;
  final bool isPickupOnly;
  final String total;
  final String customerName;
  final String address;
  final String phone;
  final List<LineItem> lineItems;
  final String notes;
  final String? driverName;
  final String? driverPhone;
  // Actual Laravel delivery_orders.id; Woo ID stays in `id` for readiness/actions.
  final int? driverOrderId;

  Order({
    required this.id,
    required this.status,
    required this.dateCreated,
    this.dateCompleted,
    this.isPickupOnly = false,
    required this.total,
    required this.customerName,
    required this.address,
    required this.phone,
    required this.lineItems,
    this.notes = '',
    this.driverName,
    this.driverPhone,
    this.driverOrderId,
  });

  // 🔥 الإضافة الجديدة: لتسهيل حساب الأرباح والمبالغ في الإحصائيات
  double get totalAmount => double.tryParse(total) ?? 0.0;

  factory Order.fromJson(Map<String, dynamic> json) {
    // 1. معالجة الاسم بشكل آمن وتصحيح الخطأ القديم
    final billing = json['billing'] as Map<String, dynamic>?;
    final firstName = billing?['first_name'] ?? '';
    final lastName = billing?['last_name'] ?? '';

    // استخراج الاسم الخام من السيرفر أو من بيانات الـ billing
    final rawCustomerName = json['customerName'] ?? '$firstName $lastName'.trim();

    // ✅ التصحيح الجذري: إذا كان الاسم فارغاً تماماً، نضع كلمة "زبون" كقيمة افتراضية
    final finalCustomerName = rawCustomerName.toString().isEmpty ? 'اسم الزبون غير متاح' : rawCustomerName.toString();

    // 2. معالجة العناصر (Line Items) بشكل آمن لمنع الانهيار إذا كانت null
    List<LineItem> safeLineItems = [];
    if (json['line_items'] is List) {
      safeLineItems = (json['line_items'] as List)
          .where((item) => item is Map<String, dynamic>)
          .map((item) => LineItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 3. بناء الكائن وإرجاعه
    return Order(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'pending',
      // لا تستخدم وقت الجهاز عند غياب تاريخ الطلب، وإلا ستظهر مبيعات وهمية اليوم.
      dateCreated: DateTime.tryParse(json['date_created']?.toString() ?? '')
          ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      dateCompleted: DateTime.tryParse(json['date_completed']?.toString() ?? ''),
      isPickupOnly: json['is_pickup_only'] == true,
      total: json['total']?.toString() ?? 'غير متاح',
      customerName: finalCustomerName, // ✅ استخدام الاسم المعالج نهائياً
      address: json['address'] ?? json['shipping']?['address_1'] ?? billing?['address_1'] ?? 'عنوان غير محدد',
      phone: json['phone'] ?? billing?['phone'] ?? 'لا يوجد رقم',
      lineItems: safeLineItems,
      notes: (json['notes'] ?? '').toString(),
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      driverOrderId: int.tryParse('${json['driver_order_id'] ?? ''}'),
    );
  }

  // 🔥 إضافة دالة toString للمساعدة في تتبع الأخطاء (Debugging) في الـ Console
  @override
  String toString() {
    return 'Order(id: $id, status: $status, total: $total, customerName: $customerName, itemsCount: ${lineItems.length})';
  }
}
class LineItem {
  final String name;
  final int quantity;
  final String total;
  final String note;
  final String optionsSummary;

  LineItem({required this.name, required this.quantity, required this.total, this.note='',this.optionsSummary=''});

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      name: json['name'] ?? 'منتج غير معروف',
      quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity'].toString()) ?? 1,
      total: json['total']?.toString() ?? '0',
      note:json['note']?.toString() ?? '',
      optionsSummary:json['options_summary']?.toString() ?? '',
    );
  }
}

class RestaurantRatingsDashboard {
  final double averageRating; final int totalReviews; final List<Review> recentReviews;
  RestaurantRatingsDashboard({required this.averageRating, required this.totalReviews, required this.recentReviews});
  factory RestaurantRatingsDashboard.fromJson(Map<String, dynamic> json) =>
      RestaurantRatingsDashboard(
        averageRating: (json['average_rating'] as num).toDouble(),
        totalReviews: json['total_reviews'],
        recentReviews: (json['recent_reviews'] as List).map((i) => Review.fromJson(i)).toList(),
      );
}

class Review {
  final String productName; final String author; final int rating; final String content; final DateTime date;
  Review({required this.productName, required this.author, required this.rating, required this.content, required this.date});
  factory Review.fromJson(Map<String, dynamic> json) => Review(
    productName: json['product_name'], author: json['author'], rating: json['rating'],
    content: json['content'], date: DateTime.parse(json['date']),
  );
}

// =======================================================================
// 🔷 القسم 4: الخدمات (Services)
// =======================================================================

class CacheService {
  Future<void> saveData(String key, String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, data);
  }
  Future<String?> getData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}

class AuthService {
  Future<String?> loginToServer(String baseUrl, String username, String password) async {
    try {
      print("🔵 [Auth] محاولة الدخول إلى: $baseUrl");
      final response = await http.post(
          Uri.parse('$baseUrl/wp-json/jwt-auth/v1/token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'password': password})
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ [Auth] نجح الدخول، تم استلام التوكن");
        return data['token'];
      }
      debugPrint('فشل تسجيل الدخول: HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      print("⚠️ [Auth] خطأ اتصال: $e");
      return null;
    }
  }

  Future<void> registerDeviceToken(String? token) async {
    if (token == null) return;
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print("⚠️ [FCM] لم يتم الحصول على FCM Token");
        return;
      }
      String platform = Platform.isAndroid ? 'android' : 'ios';
      Map<String, dynamic> bodyData = {'token': fcmToken, 'platform': platform};
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/register-device'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode(bodyData),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('رفض السيرفر حفظ توكن الإشعارات: ${response.statusCode}');
      print('✅ [FCM] تم تسجيل الجهاز في السيرفر');
    } catch (e) {
      print("⚠️ [FCM] خطأ في التسجيل (يمكن تجاهله): $e");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('restaurant_lat');
    await prefs.remove('restaurant_lng');
  }
}
class ManageSectionsScreen extends StatefulWidget {
  final int restaurantId;
  const ManageSectionsScreen({super.key, required this.restaurantId});
  @override
  State<ManageSectionsScreen> createState() => _ManageSectionsScreenState();
}

class _ManageSectionsScreenState extends State<ManageSectionsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _sections = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final data = await _api.getRestaurantSections(token, widget.restaurantId);
      data.sort((a, b) => (int.tryParse('${a['display_order']}') ?? 999)
          .compareTo(int.tryParse('${b['display_order']}') ?? 999));
      if (mounted) setState(() => _sections = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر جلب الأقسام: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _edit({Map<String, dynamic>? section}) async {
    final name = TextEditingController(text: section?['name']?.toString() ?? '');
    final icon = TextEditingController(text: section?['icon']?.toString() ?? '🍽️');
    final order = TextEditingController(text: (section?['display_order'] ?? _sections.length + 1).toString());
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(section == null ? 'قسم جديد' : 'تعديل القسم'),
      content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم القسم'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null),
        const SizedBox(height: 12),
        TextFormField(controller: icon, decoration: const InputDecoration(labelText: 'أيقونة أو رمز تعبيري')),
        const SizedBox(height: 12),
        TextFormField(controller: order, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ترتيب العرض'),
            validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? 'أدخل رقماً صحيحاً' : null),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('حفظ'))],
    ));
    if (ok != true || !mounted) { name.dispose(); icon.dispose(); order.dispose(); return; }
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    setState(() => _saving = true);
    try {
      final success = section == null
          ? await _api.createSection(token!, name.text.trim(), icon.text.trim(), int.parse(order.text))
          : await _api.updateSection(token!, int.parse('${section['id']}'), name.text.trim(), icon.text.trim(), int.parse(order.text));
      if (!success) throw Exception('رفض السيرفر حفظ القسم');
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ القسم')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      name.dispose(); icon.dispose(); order.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }
  Future<void> _delete(Map<String, dynamic> section) async {
    final count = int.tryParse('${section['count']}') ?? 0;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انقل الوجبات إلى قسم آخر أولاً')));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف القسم'),
      content: Text('هل تريد حذف قسم «${section['name']}»؟ لا يمكن حذف قسم يحتوي على وجبات.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))],
    ));
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      await _api.productAction(token!, 'delete-category', int.parse('${section['id']}'));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة أقسام المطعم'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _edit(), icon: const Icon(Icons.add), label: const Text('إضافة قسم')),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_error!, textAlign: TextAlign.center), TextButton(onPressed: _load, child: const Text('إعادة المحاولة'))]))
        : RefreshIndicator(onRefresh: _load, child: _sections.isEmpty
        ? ListView(children: const [SizedBox(height: 120), Center(child: Text('لا توجد أقسام بعد. اضغط إضافة قسم.'))])
        : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: _sections.length, itemBuilder: (context, i) {
          final section = _sections[i];
          return Card(child: ListTile(
            leading: CircleAvatar(child: Text((section['icon'] ?? '🍽️').toString())),
            title: Text('${section['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('عدد الوجبات: ${section['count'] ?? 0}  ·  الترتيب: ${section['display_order'] ?? '-'}'),
            trailing: PopupMenuButton<String>(enabled: !_saving, onSelected: (val) {
              if (val == 'edit') { _edit(section: section); } else { _delete(section); }
            }, itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ]),
            onTap: _saving ? null : () => _edit(section: section),
          ));
        })),
  );
}


String newMenuId() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';

class ServerOptionsNotReady implements Exception {
  const ServerOptionsNotReady();
  @override
  String toString() => 'السيرفر لا يدعم خيارات الوجبات بعد';
}

class MenuChoice {
  String id;
  String name;
  double extraPrice;
  double? weightKg;
  MenuChoice({required this.id, required this.name, this.extraPrice = 0,this.weightKg});
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'price_delta': extraPrice,
    if(weightKg!=null)'weight_kg':weightKg,
  };
  factory MenuChoice.fromJson(Map<String, dynamic> map) => MenuChoice(
    id: (map['id'] ?? newMenuId()).toString(),
    name: (map['name'] ?? '').toString(),
    extraPrice: double.tryParse((map['price_delta'] ?? 0).toString()) ?? 0,
    weightKg:double.tryParse((map['weight_kg'] ?? '').toString()),
  );
}

class MenuOptionGroup {
  String id;
  String name;
  String kind;
  bool multiSelect;
  bool requiredChoice;
  int maxSelections;
  List<MenuChoice> choices;
  MenuOptionGroup({required this.id, required this.name, this.kind='addon',this.multiSelect = false,
    this.requiredChoice = false, this.maxSelections = 1, required this.choices});
  int get minimum => requiredChoice ? 1 : 0;
  int get maximum => multiSelect ? maxSelections : 1;
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'kind':kind, 'type': multiSelect ? 'multiple' : 'single',
    'required': requiredChoice, 'min_select': minimum, 'max_select': maximum,
    'options': choices.map((c) => c.toJson()).toList(),
  };
  factory MenuOptionGroup.fromJson(Map<String, dynamic> map) {
    final raw = map['options'];
    return MenuOptionGroup(
      id: (map['id'] ?? newMenuId()).toString(),
      name: (map['name'] ?? '').toString(),
      kind:(map['kind']??'addon').toString(),
      multiSelect: (map['type'] ?? 'single') == 'multiple',
      requiredChoice: map['required'] == true || map['required'] == 1,
      maxSelections: int.tryParse((map['max_select'] ?? 1).toString()) ?? 1,
      choices: raw is List
          ? raw.whereType<Map>().map((e) => MenuChoice.fromJson(Map<String, dynamic>.from(e))).toList()
          : <MenuChoice>[],
    );
  }
}

class ProductOptionsLocalDrafts {
  static String _key(int productId) => 'beytei_local_options_draft_v1_$productId';
  static Future<void> save(int productId, List<MenuOptionGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(productId), json.encode(groups.map((e) => e.toJson()).toList()));
  }
  static Future<List<MenuOptionGroup>?> load(int productId) async {
    final prefs = await SharedPreferences.getInstance();
    final contents = prefs.getString(_key(productId));
    if (contents == null) return null;
    try {
      final data = json.decode(contents) as List;
      return data.map((e) => MenuOptionGroup.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return null;
    }
  }
  static Future<void> remove(int productId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(productId));
  }
}

class MenuOptionGroupEditor extends StatefulWidget {
  final MenuOptionGroup? initial;
  const MenuOptionGroupEditor({super.key, this.initial});
  @override
  State<MenuOptionGroupEditor> createState() => _MenuOptionGroupEditorState();
}

class _MenuOptionGroupEditorState extends State<MenuOptionGroupEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late bool _multiple;
  late bool _required;
  late List<MenuChoice> _choices;
  @override
  void initState() {
    super.initState();
    final old = widget.initial;
    _name = TextEditingController(text: old?.name ?? '');
    _limit = TextEditingController(text: (old?.maxSelections ?? 1).toString());
    _multiple = old?.multiSelect ?? false;
    _required = old?.requiredChoice ?? false;
    _choices = old == null ? [] : old.choices.map((e) => MenuChoice(
        id:e.id,name:e.name,extraPrice:e.extraPrice,weightKg:e.weightKg)).toList();
  }
  @override
  void dispose() { _name.dispose(); _limit.dispose(); super.dispose(); }

  Future<void> _choiceDialog({int? index}) async {
    final existing = index == null ? null : _choices[index];
    final name = TextEditingController(text: existing?.name ?? '');
    final fee = TextEditingController(text: (existing?.extraPrice ?? 0).toStringAsFixed(0));
    final kg = TextEditingController(text: existing?.weightKg?.toString() ?? '');
    final isWeight=widget.initial?.kind=='weight';
    final key = GlobalKey<FormState>();
    final choice = await showDialog<MenuChoice>(context: context, builder: (ctx) => AlertDialog(
      title: Text(index == null ? 'إضافة خيار' : 'تعديل الخيار'),
      content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم الخيار (مثال: 500 غرام)'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب الاسم' : null),
        const SizedBox(height: 10),
        if(isWeight) TextFormField(controller:kg,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:const InputDecoration(labelText:'الوزن بالكيلو مثل 0.25'),
            validator:(v){final w=double.tryParse(v??'');return w==null||w<=0?'أدخل وزناً بالكيلو':null;}),
        TextFormField(controller: fee, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'الزيادة على السعر الأساسي (د.ع)'),
            validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n < 0 ? 'أدخل رقماً لا يقل عن صفر' : null; }),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () {
          if (!key.currentState!.validate()) return;
          Navigator.pop(ctx, MenuChoice(id: existing?.id ?? newMenuId(), name: name.text.trim(),
              extraPrice: double.parse(fee.text.trim()),
              weightKg:isWeight?double.tryParse(kg.text.trim()):existing?.weightKg));
        }, child: const Text('حفظ')),
      ],
    ));
    name.dispose(); fee.dispose(); kg.dispose();
    if (choice != null && mounted) setState(() {
      if (index == null) { _choices.add(choice); } else { _choices[index] = choice; }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف خياراً واحداً على الأقل')));
      return;
    }
    final set = _choices.map((e) => e.name.trim().toLowerCase()).toSet();
    if (set.length != _choices.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا تكرر اسم الخيار داخل المجموعة')));
      return;
    }
    final limit = _multiple ? int.tryParse(_limit.text.trim()) ?? 0 : 1;
    if (limit < 1 || limit > _choices.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الحد الأقصى يجب أن يكون من 1 إلى ${_choices.length}')));
      return;
    }
    Navigator.pop(context, MenuOptionGroup(id: widget.initial?.id ?? newMenuId(), name: _name.text.trim(),
        kind:widget.initial?.kind??'addon',
        multiSelect: _multiple, requiredChoice: _required, maxSelections: limit, choices: _choices));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.initial == null ? 'مجموعة خيارات جديدة' : 'تعديل مجموعة الخيارات')),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المجموعة (الأوزان، الصلصات، الإضافات)'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null),
      const SizedBox(height: 10),
      SwitchListTile(title: const Text('السماح باختيار عدة عناصر'), subtitle: const Text('مثلاً أكثر من صلصة في الطلب'),
          value: _multiple, onChanged: (v) => setState(() => _multiple = v)),
      SwitchListTile(title: const Text('اختيار إجباري'), subtitle: const Text('مثل ضرورة اختيار وزن واحد'),
          value: _required, onChanged: (v) => setState(() => _required = v)),
      if (_multiple) TextFormField(controller: _limit, decoration: const InputDecoration(labelText: 'أقصى عدد خيارات يمكن اختياره'),
          keyboardType: TextInputType.number, validator: (v) => int.tryParse(v ?? '') == null ? 'أدخل رقماً صحيحاً' : null),
      const SizedBox(height: 12),
      Row(children: [const Expanded(child: Text('خيارات المجموعة', style: TextStyle(fontWeight: FontWeight.bold))),
        TextButton.icon(onPressed: () => _choiceDialog(), icon: const Icon(Icons.add), label: const Text('إضافة خيار'))]),
      ..._choices.asMap().entries.map((entry) => Card(child: ListTile(
        title: Text(entry.value.name),
        subtitle: Text(entry.value.extraPrice == 0 ? 'بدون تكلفة إضافية' : '+ ${entry.value.extraPrice.toStringAsFixed(0)} د.ع'),
        onTap: () => _choiceDialog(index: entry.key),
        trailing: IconButton(icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _choices.removeAt(entry.key))),
      ))),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('حفظ المجموعة')),
    ])),
  );
}

MenuOptionGroup menuPresetWeights() => MenuOptionGroup(
  id: newMenuId(), name: 'الوزن', kind:'weight', requiredChoice: true,
  // Base product price = one kilogram. Select weight multiplied once.
  // price_delta is only an additional charge on that weight if configured.
  choices: [
    MenuChoice(id: newMenuId(), name: 'ربع كيلو (250 غرام)', extraPrice: 0, weightKg:0.25),
    MenuChoice(id: newMenuId(), name: 'نصف كيلو (500 غرام)', extraPrice: 0, weightKg:0.5),
    MenuChoice(id: newMenuId(), name: 'ثلاثة أرباع كيلو (750 غرام)', extraPrice: 0, weightKg:0.75),
    MenuChoice(id: newMenuId(), name: '1 كيلوغرام', extraPrice: 0, weightKg:1.0),
    MenuChoice(id: newMenuId(), name: 'كيلو ونصف (1.5 كيلوغرام)', extraPrice: 0, weightKg:1.5),
  ],
);
MenuOptionGroup menuPresetSauces() => MenuOptionGroup(
  id: newMenuId(), name: 'الصلصات', multiSelect: true, maxSelections: 3,
  choices: [
    MenuChoice(id: newMenuId(), name: 'عمبة'),
    MenuChoice(id: newMenuId(), name: 'صوص ثوم'),
    MenuChoice(id: newMenuId(), name: 'صوص حار'),
  ],
);
MenuOptionGroup menuPresetOnion() => MenuOptionGroup(
  id: newMenuId(), name: 'تعديل البصل',
  choices: [
    MenuChoice(id: newMenuId(), name: 'بدون بصل'),
    MenuChoice(id: newMenuId(), name: 'بصل إضافي'),
  ],
);

class ApiService {

  Future<T> _executeWithRetry<T>(Future<T> Function() action) async {
    int attempts = 0;
    while (attempts < 3) {
      try {
        return await action().timeout(AppConstants.API_TIMEOUT);
      } catch (e) {
        attempts++;
        String errorString = e.toString();
        if (errorString.contains('403') || errorString.contains('429')) rethrow;
        if (attempts >= 3) rethrow;
        int delaySeconds = pow(2, attempts).toInt();
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
    throw Exception('Failed after multiple retries');
  }

  Future<Map<String, dynamic>> getRestaurantSettings(String token) async {
    return _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/get-settings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load settings');
    });
  }

  Future<bool> updateRestaurantStatusFull(String token, String mode, bool isOpen) async {
    final response = await http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-status'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'mode': mode, 'is_open': isOpen ? 1 : 0}),
    );
    if (response.statusCode != 200) throw Exception(_apiError(response));
    return true;
  }

  Future<bool> updateRestaurantAutoTimes(String token, String openTime, String closeTime) async {
    final response = await http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-auto-times'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'open_time': openTime, 'close_time': closeTime}),
    );
    if (response.statusCode != 200) throw Exception(_apiError(response));
    return true;
  }

  Future<List<FoodItem>> getMyRestaurantProducts(String token) async {
    return _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/my-products'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((jsonObj) => FoodItem.fromJson(jsonObj)).toList();
      }
      throw Exception('Failed to load restaurant products');
    });
  }

  // =======================================================================
  // 🔥 التصحيح هنا: إضافة المعامل السابع (int categoryId)
  // =======================================================================
  Future<bool> createProduct(
      String token,
      String name,
      String price,
      String? salePrice,
      String? description,
      File? imageFile,
      int categoryId // 🔥 المعامل السابع المفقود
      ) async {
    String? imageBase64;
    if (imageFile != null) {
      List<int> imageBytes = await imageFile.readAsBytes();
      imageBase64 = base64Encode(imageBytes);
    }
    final response = await http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/create-product'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'regular_price': price,
        'sale_price': salePrice,
        'description': description,
        'image_base64': imageBase64,
        'category_id': categoryId, // 🔥 إرسال معرف القسم للسيرفر
      }),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_apiError(response));
    }
    return true;
  }

  Future<bool> updateMyProduct(String token, int productId, String name, String price, String salePrice, File? newImageFile, int categoryId) async {
    String? imageBase64;
    if (newImageFile != null) {
      List<int> imageBytes = await newImageFile.readAsBytes();
      imageBase64 = base64Encode(imageBytes);
    }
    final response = await http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-product'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'product_id': productId,
        'name': name,
        'regular_price': price,
        'sale_price': salePrice,
        'image_base64': imageBase64,
        'category_id': categoryId,
      }),
    );
    if (response.statusCode != 200) throw Exception(_apiError(response));
    return true;
  }

  Future<ManagerOrdersPage> getManagerOrdersPage({required String status,
    required String token, int page = 1, int perPage = 20}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/manager-orders-v22')
        .replace(queryParameters: {'status': status, 'page': '$page', 'per_page': '$perPage'});
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) throw Exception(_apiError(response));
    final decoded = json.decode(response.body);
    if (decoded is! Map || decoded['orders'] is! List) throw Exception('صيغة الطلبات غير صحيحة من السيرفر');
    final orders = (decoded['orders'] as List)
        .whereType<Map>().map((e) => Order.fromJson(Map<String, dynamic>.from(e))).toList();
    return ManagerOrdersPage(orders: orders, hasMore: decoded['has_more'] == true);
  }

  Future<List<Order>> getRestaurantOrders({required String status, required String token}) async {
    return (await getManagerOrdersPage(status: status, token: token, perPage: 30)).orders;
  }

  // V31: live AND completed orders read directly from Laravel; same scoped token as finance.
  Future<Map<String, dynamic>> getLaravelManagerOrders(String wpToken, {
    required String status, int page = 1, int perPage = 20,
    String? from, String? to,
  }) async {
    if (status != 'active' && status != 'completed') throw ArgumentError('Unsupported status');
    final uri = Uri.parse('https://de.beytei.com/api/beytei/finance/v1/orders')
        .replace(queryParameters: {
      'status': status, 'page': '$page', 'per_page': '$perPage',
      if (from != null && to != null) 'from': from,
      if (from != null && to != null) 'to': to,
    });
    String scope = await _merchantFinanceScope(wpToken);
    Future<http.Response> get() => http.get(uri, headers: {
      'Authorization': 'Bearer $scope', 'Accept': 'application/json',
    }).timeout(const Duration(seconds: 20));
    var response = await get();
    if (response.statusCode == 401) {
      scope = await _merchantFinanceScope(wpToken, forceRenew: true);
      response = await get();
    }
    debugPrint('[ORDERS] LARAVEL_${status.toUpperCase()}_HTTP=${response.statusCode}');
    if (response.statusCode != 200) throw Exception('تعذر تحميل الطلبات من سيرفر السائقين: ${_apiError(response)}');
    final value = json.decode(response.body);
    if (value is! Map || value['success'] != true || value['orders'] is! List) {
      throw Exception('صيغة طلبات Laravel غير صحيحة');
    }
    return Map<String, dynamic>.from(value);
  }

  // Preserve WooCommerce order IDs for existing "order ready" actions.
  static Order mapDriverOrderToCard(Map<String, dynamic> row) {
    final wpId = int.tryParse('${row['source_order_id'] ?? ''}') ??
        -(int.tryParse('${row['id'] ?? 0}') ?? 0);
    final rawItems = row['line_items'];
    final list = rawItems is List ? rawItems : <dynamic>[];
    return Order.fromJson(<String, dynamic>{
      'id': wpId, 'driver_order_id': row['id'],
      'status': (row['status'] ?? 'pending').toString(),
      'date_created': row['created_at']?.toString(),
      'date_completed': row['delivered_at']?.toString(),
      'total': (row['order_total'] ?? 0).toString(),
      'customerName': (row['customer_name'] ?? '').toString(),
      'phone': (row['customer_phone'] ?? '').toString(),
      'address': (row['destination_address'] ?? '').toString(),
      'line_items': list.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList(),
      'notes': (row['notes'] ?? '').toString(),
      'driver_name': row['driver_assigned'] == true ? 'مندوب معيّن' : null,
      'is_pickup_only': (row['order_items'] ?? '').toString().contains('طلب مندوب مستعجل'),
    });
  }

  Future<bool> testManagerPush(String token) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/manager-test-push-v22'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    ).timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode != 200) throw Exception(_apiError(response));
    final decoded = json.decode(response.body);
    return decoded is Map && decoded['fcm_accepted'] == true;
  }

  Future<RestaurantRatingsDashboard> getDashboardRatings(String token) async {
    // A ratings failure must not keep the whole manager home screen loading.
    final response = await http.get(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/dashboard-ratings'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل التقييمات: ${_apiError(response)}');
    }
    return RestaurantRatingsDashboard.fromJson(json.decode(response.body));
  }

  Future<Map<String, dynamic>> getWalletData(String token) async {
    return _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/wallet'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load wallet');
    });
  }

  Future<bool> updateMyLocation(String token, String lat, String lng) async {
    return _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-my-location'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'lat': lat, 'lng': lng}),
      );
      return response.statusCode == 200;
    });
  }

  Future<bool> notifyDriverOrderReady(int sourceOrderId, String token) async {
    return _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/taxi/v3/delivery/notify-ready'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({'source_order_id': sourceOrderId.toString()}),
      );
      final data = json.decode(response.body);
      if (data['success'] == true) return true;
      throw Exception(data['message'] ?? 'فشل إرسال الإشعار');
    });
  }

  Future<bool> submitReview({required int productId, required double rating, required String review, required String author, required String email}) async {
    final response = await _executeWithRetry(() => http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/submit-review'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'product_id': productId, 'rating': rating, 'review': review, 'author': author, 'email': email}),
    ));
    return response.statusCode == 201;
  }

  Future<Map<String, dynamic>?> getMarketingConfig(String token) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/manager-marketing-config'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode == 404 || response.statusCode == 501) return null;
    if (response.statusCode != 200) throw Exception(_apiError(response));
    return Map<String, dynamic>.from(json.decode(response.body));
  }

  Future<bool> createMarketingOrder({required String token, required String title,
    required String bodyText, required String? imageUrl,
    required int productId, required double cost}) async {
    return _executeWithRetry(() async {
      List<Map<String, dynamic>> metaData = [
        {"key": "_is_ad_request", "value": "true"},
        {"key": "ad_title", "value": title},
        {"key": "ad_content", "value": bodyText},
        if (imageUrl != null && imageUrl.isNotEmpty) {"key": "ad_image", "value": imageUrl},
      ];

      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/create-ad-order'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({
          'product_id': productId,
          'quantity': 1,
          'total_cost': cost,
          'meta_data': metaData,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return true;

      final responseBody = json.decode(response.body);
      throw Exception(responseBody['message'] ?? 'فشل إنشاء طلب الإعلان');
    });
  }

  String _apiError(http.Response response) {
    try{return json.decode(response.body)['message']?.toString() ?? 'HTTP ${response.statusCode}';}
    catch(_){return 'HTTP ${response.statusCode}';}
  }
  Future<Map<String,dynamic>> fetchWeeklySchedule(String token) async {
    final response=await http.get(
        Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/weekly-schedule'),
        headers:{'Authorization':'Bearer $token'}).timeout(AppConstants.API_TIMEOUT);
    if(response.statusCode!=200)throw Exception(_apiError(response));
    return Map<String,dynamic>.from(json.decode(response.body));
  }
  Future<void> saveWeeklySchedule(String token, Map<String,List<Map<String,String>>> days) async {
    final response=await http.post(
        Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/weekly-schedule'),
        headers:{'Authorization':'Bearer $token','Content-Type':'application/json'},
        body:json.encode({'days':days})).timeout(AppConstants.API_TIMEOUT);
    if(response.statusCode!=200)throw Exception(_apiError(response));
  }

  Future<Map<String,dynamic>> getManagerContext(String token) async {
    final r=await http.get(Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/manager-context'),headers:{'Authorization':'Bearer $token'}).timeout(AppConstants.API_TIMEOUT);
    if(r.statusCode!=200) throw Exception(_apiError(r));
    return Map<String,dynamic>.from(json.decode(r.body));
  }
  Future<void> productAction(String token,String operation,int id,{bool hidden=false}) async {
    final route={'hide':'toggle-product-visibility','delete':'delete-product',
      'delete-forever':'delete-product-permanent','delete-category':'delete-subcategory'}[operation];
    if(route==null) throw ArgumentError('Invalid action');
    final r=await http.post(Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/$route'),
        headers:{'Authorization':'Bearer $token','Content-Type':'application/json'},
        body:json.encode(operation=='delete-category'?{'term_id':id}:
        {'product_id':id,'is_hidden':hidden,if(operation=='delete-forever') 'confirm':'DELETE_FOREVER'})).timeout(AppConstants.API_TIMEOUT);
    if(r.statusCode!=200) throw Exception(_apiError(r));
  }
  // V21: pickup-only urgent call. No customer data, destination, or invented fee.
  Future<Map<String, dynamic>> requestUrgentPickup(String token, String requestId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/manager-urgent-pickup'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'request_id': requestId}),
    ).timeout(const Duration(seconds: 35));
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(json.decode(response.body) as Map);
    } catch (_) {
      throw Exception('رد السيرفر غير واضح (HTTP ${response.statusCode}). لا تكرر الطلب قبل التأكد من حالة الطلبات.');
    }
    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 202) {
      if (body['order_id'] != null) return body; // Preserve uncertain saved order ID.
      throw Exception(body['message'] ?? 'فشل استدعاء المندوب: HTTP ${response.statusCode}');
    }
    return body;
  }

  // Explicit, manager-confirmed restaurant location. Never update implicitly at login.
  Future<Map<String, dynamic>> savePickupLocation(String token, double lat, double lng,
      {int? zoneId}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/manager-save-pickup-location'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'lat': lat, 'lng': lng, if (zoneId != null) 'zone_id': zoneId}),
    ).timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode != 200) throw Exception(_apiError(response));
    final decoded = json.decode(response.body);
    if (decoded is! Map || decoded['success'] != true) throw Exception('لم يؤكد السيرفر حفظ الموقع');
    return Map<String, dynamic>.from(decoded);
  }

  // V34: WordPress is the ONLY entry point. It builds WooCommerce orders then
  // invokes the existing auto_dispatch_taxi_request_unified() function.
  // Do NOT call Laravel directly from the restaurant app.
  Future<Map<String, dynamic>> getManagerCourierConfig(String token) async =>
      _courierGet(token, 'manager-courier-v34/config');

  Future<Map<String, dynamic>> getManagerCourierOrders(String token) async =>
      _courierGet(token, 'manager-courier-v34');

  Future<Map<String, dynamic>> getManagerCourierStatus(String token, int id) async =>
      _courierGet(token, 'manager-courier-v34/$id');

  Future<Map<String, dynamic>> _courierGet(String token, String route) async {
    final r = await http.get(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/$route'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));
    final decoded = _courierDecode(r);
    if (r.statusCode != 200) throw Exception(decoded['message'] ?? 'HTTP ${r.statusCode}');
    return decoded;
  }

  Map<String, dynamic> _courierDecode(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    throw Exception('رد غير مفهوم من WordPress (HTTP ${response.statusCode})');
  }

  Future<Map<String, dynamic>> requestManagerCourierV34(
      String token, Map<String, dynamic> payload) async {
    final r = await http.post(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/manager-courier-v34'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json',
        'Accept': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 40));
    final decoded = _courierDecode(r);
    // HTTP 202 can mean a real Woo order was saved but dispatch was unconfirmed.
    // Keep the ID; never retry by creating a new request ID.
    if (decoded['order'] is Map) return decoded;
    if (r.statusCode != 200 && r.statusCode != 201 && r.statusCode != 202) {
      throw Exception(decoded['message'] ?? 'رفض الطلب HTTP ${r.statusCode}');
    }
    return decoded;
  }

  Future<bool> updateProductFull({
    required String token, required int productId, required String name,
    required String price, required String salePrice, required String description,
    File? image, required int categoryId,
    String availabilityStart = '', String availabilityEnd = '',
  }) async {
    final img = image == null ? null : base64Encode(await image.readAsBytes());
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/update-product'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'product_id': productId, 'name': name, 'regular_price': price,
        'sale_price': salePrice, 'description': description,
        'image_base64': img, 'category_id': categoryId,
        'availability_start': availabilityStart,'availability_end':availabilityEnd,
      }),
    ).timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode != 200) throw Exception(_apiError(response));
    return true;
  }

  Future<int> createProductWithId({
    required String token, required String name, required String price,
    String? salePrice, required String description, File? image,
    required int categoryId,
    String availabilityStart = '', String availabilityEnd = '',
  }) async {
    final imageBase64 = image == null ? null : base64Encode(await image.readAsBytes());
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/create-product'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'name': name, 'regular_price': price, 'sale_price': salePrice,
        'description': description, 'image_base64': imageBase64,
        'category_id': categoryId,
        'availability_start':availabilityStart,'availability_end':availabilityEnd,
      }),
    ).timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_apiError(response));
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map) throw Exception('استجابة إنشاء الوجبة غير صالحة');
    final id = int.tryParse((decoded['product_id'] ?? decoded['id'] ?? '').toString());
    if (id == null || id < 1) {
      throw Exception('حُفظت الوجبة، لكن السيرفر لم يُرجع معرّفها. افحص قائمة الوجبات قبل إعادة الإضافة حتى لا تُنشئ وجبة مكررة.');
    }
    return id;
  }

  Future<Map<String, dynamic>?> fetchManagerAnalytics(String token, String period) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/manager-analytics')
        .replace(queryParameters: {'period': period});
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode == 404 || response.statusCode == 501) return null;
    if (response.statusCode != 200) throw Exception(_apiError(response));
    final data = json.decode(response.body);
    if (data is! Map) throw Exception('بيانات الإحصائيات غير صالحة');
    return Map<String, dynamic>.from(data);
  }

  // Merchant-scope token from WordPress after the normal JWT login.
  // Laravel finance reports are requested DIRECTLY from de.beytei.com.
  // The signing secret stays on servers; the app stores only a short-lived token in RAM.
  static String? _financeScopeToken;
  static DateTime? _financeScopeExpiry;
  static String? _financeWpSession;

  Future<String> _merchantFinanceScope(String wpToken, {bool forceRenew = false}) async {
    if (_financeWpSession != wpToken) {
      _financeScopeToken = null;
      _financeScopeExpiry = null;
      _financeWpSession = wpToken;
    }
    final now = DateTime.now().toUtc();
    if (!forceRenew && _financeScopeToken != null && _financeScopeExpiry != null &&
        now.isBefore(_financeScopeExpiry!.subtract(const Duration(seconds: 60)))) {
      return _financeScopeToken!;
    }
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/finance-session-v27'),
      headers: {'Authorization': 'Bearer $wpToken', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));
    debugPrint('[FINANCE] WORDPRESS_SESSION_HTTP=${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('تعذّر التحقق من صلاحية حساب المطعم (WordPress HTTP ${response.statusCode}): ${_apiError(response)}');
    }
    final data = json.decode(response.body);
    if (data is! Map || data['success'] != true || data['token'] is! String ||
        (data['token'] as String).isEmpty) {
      throw Exception('رمز ربط سيرفر السائقين غير صالح');
    }
    final seconds = int.tryParse('${data['expires_at']}') ?? 0;
    final expiry = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    if (!expiry.isAfter(now.add(const Duration(seconds: 60)))) {
      throw Exception('انتهت صلاحية رمز الإحصائيات');
    }
    _financeScopeToken = data['token'] as String;
    _financeScopeExpiry = expiry;
    return _financeScopeToken!;
  }

  /// Six counters and a paginated list directly from Laravel.
  Future<Map<String, dynamic>> getDriverFinanceSnapshot(String token, {
    String? from, String? to, int page = 1,
  }) async {
    final query = <String, String>{'page': '$page', 'per_page': '30'};
    if (from != null && to != null) { query['from'] = from; query['to'] = to; }
    final uri = Uri.parse('https://de.beytei.com/api/beytei/finance/v1/report')
        .replace(queryParameters: query);
    http.Response response;
    String scope = await _merchantFinanceScope(token);
    response = await http.get(uri, headers: {
      'Authorization': 'Bearer $scope', 'Accept': 'application/json',
    }).timeout(const Duration(seconds: 30));
    if (response.statusCode == 401) {
      // Once only: renew an expired bridge token and retry the same report.
      scope = await _merchantFinanceScope(token, forceRenew: true);
      response = await http.get(uri, headers: {
        'Authorization': 'Bearer $scope', 'Accept': 'application/json',
      }).timeout(const Duration(seconds: 30));
    }
    debugPrint('[FINANCE] LARAVEL_REPORT_HTTP=${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('لم تُحمّل إحصائيات سيرفر السائقين (Laravel HTTP ${response.statusCode}): ${_apiError(response)}');
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map || decoded['success'] != true ||
        decoded['source'] != 'laravel.delivery_orders.order_total' ||
        decoded['today'] is! Map || decoded['selected'] is! Map ||
        decoded['lifetime'] is! Map) {
      debugPrint('[FINANCE] INVALID_REPORT_SHAPE');
      throw Exception('استجابة الإحصائيات غير مكتملة؛ تحقق من إصدار Laravel المثبّت');
    }
    debugPrint('[FINANCE] REPORT_PARSED_OK');
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> pauseIncomingOrders(String token, int minutes) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/pause-orders'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({'minutes': minutes}),
    ).timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode == 404) {
      throw Exception('الإيقاف المؤقت بالدقائق يحتاج تحديث السيرفر. يمكنك إغلاق المطعم يدوياً الآن.');
    }
    if (response.statusCode != 200) throw Exception(_apiError(response));
    return Map<String, dynamic>.from(json.decode(response.body));
  }

  Future<Map<String, dynamic>> saveProductOptions(String token, int productId,
      List<MenuOptionGroup> groups) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/manager-product-options'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'product_id': productId,
        'groups': groups.map((g) => g.toJson()).toList(),
      }),
    ).timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode == 404 || response.statusCode == 501) {
      throw const ServerOptionsNotReady();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_apiError(response));
    }
    final data = json.decode(response.body);
    if (data is! Map || data['success'] != true) {
      throw Exception('السيرفر لم يؤكد حفظ خيارات الوجبة');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<MenuOptionGroup>?> fetchProductOptions(String token, int productId) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/restaurant-app/v1/manager-product-options')
        .replace(queryParameters: {'product_id': '$productId'});
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(AppConstants.API_TIMEOUT);
    if (response.statusCode == 404 || response.statusCode == 501) return null;
    if (response.statusCode != 200) throw Exception(_apiError(response));
    final decoded = json.decode(response.body);
    final items = decoded is List ? decoded : decoded is Map ? decoded['groups'] : null;
    if (items is! List) throw Exception('استجابة خيارات الوجبة غير صالحة');
    return items.map((e) => MenuOptionGroup.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Map<String, dynamic>>> getRestaurantSections(String token, int restaurantId) async {
    return _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/restaurant/$restaurantId/subcategories'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      throw Exception('فشل جلب الأقسام');
    });
  }

  Future<bool> createSection(String token, String name, String icon, int displayOrder) async {
    final response = await http.post(
      Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/create-subcategory'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'icon': icon,
        'display_order': displayOrder,
      }),
    );
    if (response.statusCode != 201 && response.statusCode != 200) throw Exception(_apiError(response));
    return true;
  }

  Future<bool> updateSection(String token, int termId, String name, String icon, int displayOrder) async {
    return _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-subcategory'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({
          'term_id': termId,
          'name': name,
          'icon': icon,
          'display_order': displayOrder,
        }),
      );
      if (response.statusCode != 200) throw Exception(_apiError(response));
      return true;
    });
  }
}

// =======================================================================
// 🔷 القسم 5: مزود المصادقة (Auth Provider)
// =======================================================================

// V22: Foreground alerts + Firebase background/system delivery + token renewal.
// Native Android notification sound resource: android/app/src/main/res/raw/woo_sound.mp3
// iOS uses the system default alert sound: no bundled woo.wav is required.
class RestaurantNotificationService {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _refreshSub;
  static bool _initialized = false;
  static bool _permissionAsked = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
        requestAlertPermission: false, requestBadgePermission: false,
        requestSoundPermission: false);
    await _local.initialize(const InitializationSettings(android: android, iOS: ios));
    const channel = AndroidNotificationChannel(
        'high_importance_channel', 'طلبات المطعم',
        description: 'إشعارات طلبات منصة بيتي الجديدة',
        importance: Importance.max, playSound: true,
        sound: RawResourceAndroidNotificationSound('woo_sound'));
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false, badge: true, sound: false);
    FirebaseMessaging.onMessage.listen((message) async {
      if (!['new_order', 'manager_courier_status', 'status_update'].contains(message.data['type'])) return;
      final id = int.tryParse('${message.data['order_id']}') ?? 0;
      try {
        await _local.show(
          id > 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000,
          message.notification?.title ?? message.data['title'] ?? 'تحديث طلب المندوب',
          message.notification?.body ?? message.data['body'] ?? 'تم تحديث حالة الطلب',
          const NotificationDetails(
              android: AndroidNotificationDetails('high_importance_channel', 'طلبات المطعم',
                  channelDescription: 'إشعارات طلبات منصة بيتي الجديدة',
                  importance: Importance.max, priority: Priority.high,
                  sound: RawResourceAndroidNotificationSound('woo_sound')),
              iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true,
                  presentSound: true)),
          payload: '$id',
        );
      } catch (e) {
        debugPrint('تعذر عرض تنبيه الطلب أثناء فتح التطبيق: $e');
      }
    });
    _initialized = true;
  }

  static Future<void> start(String token) async {
    if (!_permissionAsked) {
      _permissionAsked = true;
      try {
        await FirebaseMessaging.instance.requestPermission(
            alert: true, badge: true, sound: true);
      } catch (e) { debugPrint('تعذر طلب إذن الإشعارات: $e'); }
    }
    await AuthService().registerDeviceToken(token);
    await _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((value) async {
      if (value.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final activeToken = prefs.getString('jwt_token');
      if (activeToken != null) await AuthService().registerDeviceToken(activeToken);
    });
  }
  static void stop() { _refreshSub?.cancel(); _refreshSub = null; }
}

@pragma('vm:entry-point')
Future<void> restaurantFirebaseBackground(RemoteMessage message) async {
  await Firebase.initializeApp();
  // FCM notification payload is displayed by Android/iOS in the background.
  // Avoid duplicate local alerts here.
}

class ManagerOrdersPage {
  final List<Order> orders;
  final bool hasMore;
  const ManagerOrdersPage({required this.orders, required this.hasMore});
}

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userRole;
  bool _isLoading = true;

  String? get token => _token;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null;

  AuthProvider() { _checkLoginStatus(); }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _userRole = prefs.getString('user_role');
    _isLoading = false;
    notifyListeners();
    if (_token != null && _userRole == 'owner') {
      RestaurantNotificationService.start(_token!).catchError(
              (e) => debugPrint('فشل تجديد تسجيل الإشعارات: $e'));
    }
  }

  Future<bool> login(String username, String password, String role, {String? restaurantLat, String? restaurantLng}) async {
    final authService = AuthService();
    _token = await authService.loginToServer(AppConstants.BEYTEI_URL, username, password);

    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('user_role', role);

      // حفظ الموقع محلياً
      if (restaurantLat != null && restaurantLng != null) {
        await prefs.setString('restaurant_lat', restaurantLat);
        await prefs.setString('restaurant_lng', restaurantLng);
      }

      // تسجيل FCM Token في الخلفية (لا ننتظر النتيجة)
      RestaurantNotificationService.start(_token!).catchError((e) {
        debugPrint('⚠️ [Auth] فشل تسجيل FCM: $e');
      });

      _userRole = role;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout(BuildContext context) async {
    final authService = AuthService();
    RestaurantNotificationService.stop();
    await authService.logout();
    _token = null;
    _userRole = null;

    if (context.mounted) {
      try {
        Provider.of<RestaurantSettingsProvider>(context, listen: false).clearData();
        Provider.of<RestaurantProductsProvider>(context, listen: false).clearData();
      } catch (e) {
        print("Note: Could not clear providers.");
      }
    }
    notifyListeners();
  }
}

// =======================================================================
// 🔷 القسم 6: مزودي البيانات (Providers)
// =======================================================================

// Always store HH:mm in server; display 12-hour times in manager.
String beyteiManagerTime12(String raw) {
  final match=RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
  if(match==null)return raw;
  final hour=int.tryParse(match.group(1)!)??0;
  if(hour>23)return raw;
  return '${hour%12==0?12:hour%12}:${match.group(2)} ${hour<12?'صباحاً':'مساءً'}';
}

class RestaurantSettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isRestaurantOpen = false;
  bool _loaded = false;
  String? _error;
  String _operationMode = 'manual';
  String _openTime = '09:00';
  String _closeTime = '22:00';
  bool _isLoading = false;

  bool get isRestaurantOpen => _isRestaurantOpen;
  bool get loaded => _loaded;
  String? get error => _error;
  String get operationMode => _operationMode;
  String get openTime => _openTime;
  String get closeTime => _closeTime;
  bool get isLoading => _isLoading;

  Future<void> fetchSettings(String? token) async {
    if (token == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final settings = await _apiService.getRestaurantSettings(token);
      final open = settings['is_open'];
      _isRestaurantOpen = open == true || open == 1 || open == '1';
      _operationMode = settings['operation_mode'] ?? 'manual';
      _openTime = settings['auto_open_time']?.toString() ?? '09:00';
      _closeTime = settings['auto_close_time']?.toString() ?? '22:00';
      _loaded = true;

      if (settings['restaurant_info'] != null) {
        final info = settings['restaurant_info'];
        double? lat = double.tryParse(info['latitude']?.toString() ?? '');
        double? lng = double.tryParse(info['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('restaurant_lat', lat);
          await prefs.setDouble('restaurant_lng', lng);
        }
      }
    } catch (e) {
      _error = 'تعذر تحميل حالة المطعم: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateRestaurantStatus(String? token, String mode, bool isOpen) async {
    if (token == null) return false;
    String oldMode = _operationMode;
    bool oldStatus = _isRestaurantOpen;
    _operationMode = mode;
    _isRestaurantOpen = isOpen;
    notifyListeners();
    try {
      final success = await _apiService.updateRestaurantStatusFull(token, mode, isOpen);
      if (!success) {
        _operationMode = oldMode;
        _isRestaurantOpen = oldStatus;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'فشل تغيير استقبال الطلبات: $e';
      _operationMode = oldMode;
      _isRestaurantOpen = oldStatus;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAutoTimes(String? token, String openTime, String closeTime) async {
    if (token == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _apiService.updateRestaurantAutoTimes(token, openTime, closeTime);
      if (success) {
        _openTime = openTime;
        _closeTime = closeTime;
      }
      return success;
    } catch (e) {
      _error = 'فشل حفظ الجدول: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _isRestaurantOpen = false;
    _loaded = false;
    _error = null;
    _operationMode = 'manual';
    _openTime = '09:00';
    _closeTime = '22:00';
    notifyListeners();
  }
}

class RestaurantProductsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<FoodItem> _allProducts = [];
  List<FoodItem> _filteredProducts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<FoodItem> get products => _filteredProducts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchProducts(String? token) async {
    if (token == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _allProducts = await _apiService.getMyRestaurantProducts(token);
      _filteredProducts = _allProducts;
    } catch (e) {
      _errorMessage = "فشل جلب المنتجات: ${e.toString()}";
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProduct(
      String token,
      int productId,
      String name,
      String price,
      String salePrice,
      File? newImage,
      int categoryId, // 🔥 المعامل السابع: معرف القسم
      ) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      // 🔥 تمرير جميع المعاملات السبعة لدالة الـ API
      success = await _apiService.updateMyProduct(
        token,
        productId,
        name,
        price,
        salePrice,
        newImage,
        categoryId,
      );
      if (success) await fetchProducts(token);
    } catch (e) {
      _errorMessage = "فشل تحديث المنتج: ${e.toString()}";
      success = false;
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> addProduct(
      String token,
      String name,
      String price,
      String? salePrice,
      String description,
      File? image,
      int categoryId, // 🔥 المعامل السابع: معرف القسم
      ) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      // 🔥 تمرير معرف القسم (categoryId) إلى دالة الـ API ليتم حفظه في السيرفر
      success = await _apiService.createProduct(
        token,
        name,
        price,
        salePrice,
        description,
        image,
        categoryId,
      );

      if (success) {
        await fetchProducts(token);
      }
    } catch (e) {
      _errorMessage = "فشل إضافة المنتج: ${e.toString()}";
      success = false;
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  // 🔥 تحديث دالة البحث لتدعم الفلترة حسب القسم أيضاً
  void search(String query, {int? categoryId}) {
    if (query.isEmpty && categoryId == null) {
      _filteredProducts = _allProducts;
    } else {
      _filteredProducts = _allProducts.where((item) {
        // التحقق من مطابقة اسم المنتج للبحث
        bool matchesSearch = query.isEmpty || item.name.toLowerCase().contains(query.toLowerCase());
        // التحقق من مطابقة المنتج للقسم المختار
        bool matchesCategory = categoryId == null || item.categoryId == categoryId;

        // يجب أن يتحقق الشرطان معاً
        return matchesSearch && matchesCategory;
      }).toList();
    }
    notifyListeners();
  }

  void clearData() {
    _allProducts = [];
    _filteredProducts = [];
    notifyListeners();
  }
}
// BEYTEI V34.5 — consistent responsive manager UI, no changes to server APIs.
class BeyteiManagerPalette {
  static const Color blue = Color(0xFF137DB5);
  static const Color dark = Color(0xFF153A53);
  static const Color green = Color(0xFF169967);
  static const Color border = Color(0xFFDAE7EF);
  static const Color hint = Color(0xFF648096);
  static const Color background = Color(0xFFF7FAFC);
}

class BeyteiManagerQuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const BeyteiManagerQuickAction({super.key, required this.title,
    required this.subtitle, required this.icon, required this.accent,
    required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BeyteiManagerPalette.border),
        ),
        child: Row(children: [
          Container(
            width: 37, height: 37,
            decoration: BoxDecoration(color: accent.withOpacity(0.09),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 9),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
                      color: BeyteiManagerPalette.dark)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5,
                      color: BeyteiManagerPalette.hint)),
            ],
          )),
        ]),
      ),
    ),
  );
}

// Status reflects the existing RestaurantSettingsProvider. In auto mode it
// reports "according to schedule", not a fabricated current open/closed value.
class BeyteiManagerReceptionControl extends StatelessWidget {
  const BeyteiManagerReceptionControl({super.key});

  Future<void> _update(BuildContext context,
      RestaurantSettingsProvider settings, bool enabled) async {
    if (!enabled) {
      final confirmed = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إيقاف استقبال الطلبات؟'),
          content: const Text('سيبقى المطعم مغلقاً يدوياً حتى تعيد تشغيل الاستقبال أو تفعّل الجدول.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إيقاف')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final success = await settings.updateRestaurantStatus(token, 'manual', enabled);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'تم تحديث استقبال الطلبات' :
          settings.error ?? 'تعذر تحديث استقبال الطلبات')));
    }
  }

  Future<void> _pause(BuildContext context,
      RestaurantSettingsProvider settings) async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('إيقاف استقبال الطلبات مؤقتاً',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...[15, 30, 60].map((minutes) => ListTile(
            leading: const Icon(Icons.pause_circle_outline,
                color: BeyteiManagerPalette.blue),
            title: Text('$minutes دقيقة'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final token = Provider.of<AuthProvider>(context, listen: false).token;
              try {
                if (token == null) throw Exception('يرجى تسجيل الدخول');
                await ApiService().pauseIncomingOrders(token, minutes);
                await settings.fetchSettings(token);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم الإيقاف لمدة $minutes دقيقة')));
              } catch (error) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$error')));
              }
            },
          )),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Consumer<RestaurantSettingsProvider>(builder: (context, settings, _) {
        final receiving = settings.operationMode == 'auto' || settings.isRestaurantOpen;
        final statusText = !settings.loaded ? 'جاري قراءة الحالة' :
        settings.operationMode == 'auto' ? 'حسب جدول العمل' :
        settings.isRestaurantOpen ? 'يستقبل الطلبات' : 'استقبال متوقف';
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Divider(height: 24, color: BeyteiManagerPalette.border),
          Row(children: [
            const Icon(Icons.storefront_outlined,
                color: BeyteiManagerPalette.blue, size: 21),
            const SizedBox(width: 7),
            const Expanded(child: Text('استقبال طلبات المطعم',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: BeyteiManagerPalette.dark))),
            if (settings.isLoading)
              const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            Switch.adaptive(
              value: receiving,
              onChanged: (!settings.loaded || settings.isLoading)
                  ? null : (value) => _update(context, settings, value),
            ),
          ]),
          Row(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(
                color: receiving ? BeyteiManagerPalette.green : Colors.orange,
                shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(child: Text(statusText,
                style: const TextStyle(fontSize: 12, color: BeyteiManagerPalette.hint))),
            if (!settings.loaded) TextButton(
                onPressed: () => settings.fetchSettings(
                    Provider.of<AuthProvider>(context, listen: false).token),
                child: const Text('تحديث الحالة')),
          ]),
          if (settings.error != null)
            Text(settings.error!, style: const TextStyle(fontSize: 11,
                color: Colors.deepOrange)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: settings.loaded ? () => _pause(context, settings) : null,
              style: OutlinedButton.styleFrom(
                  foregroundColor: BeyteiManagerPalette.blue,
                  side: const BorderSide(color: BeyteiManagerPalette.border),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12)),
              icon: const Icon(Icons.pause_circle_outline, size: 18),
              label: const FittedBox(fit: BoxFit.scaleDown,
                  child: Text('إيقاف مؤقت')),
            )),
            const SizedBox(width: 9),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RestaurantSettingsPage())),
              style: OutlinedButton.styleFrom(
                  foregroundColor: BeyteiManagerPalette.green,
                  side: const BorderSide(color: BeyteiManagerPalette.border),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12)),
              icon: const Icon(Icons.schedule_outlined, size: 18),
              label: const FittedBox(fit: BoxFit.scaleDown,
                  child: Text('أوقات العمل')),
            )),
          ]),
        ]);
      });
}

class UnifiedOrdersScreen extends StatefulWidget {
  const UnifiedOrdersScreen({super.key});

  @override
  State<UnifiedOrdersScreen> createState() => _UnifiedOrdersScreenState();
}

class _UnifiedOrdersScreenState extends State<UnifiedOrdersScreen> {
  Map<String, dynamic>? _today;
  Map<String, dynamic>? _month;
  Map<String, dynamic>? _all;
  DateTimeRange? _customFinancialRange;
  int _unknownDeliveryDates = 0;
  List<Map<String, dynamic>> _recentLaravelOrders = [];
  String? _financialError;
  bool _financialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFinancialSummary());
  }

  int _summaryRequestId = 0;

  Future<void> _loadFinancialSummary() async {
    if (!mounted) return;
    final requestId = ++_summaryRequestId;
    setState(() { _financialLoading = true; _financialError = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final from = _customFinancialRange == null ? null :
      DateFormat('yyyy-MM-dd').format(_customFinancialRange!.start);
      final to = _customFinancialRange == null ? null :
      DateFormat('yyyy-MM-dd').format(_customFinancialRange!.end);
      final result = await ApiService().getDriverFinanceSnapshot(token, from: from, to: to);
      if (!mounted || requestId != _summaryRequestId) return;
      // Display reliable finance counters immediately, without waiting on order details.
      setState(() {
        _today = Map<String, dynamic>.from(result['today'] as Map);
        _month = Map<String, dynamic>.from(result['selected'] as Map);
        _all = Map<String, dynamic>.from(result['lifetime'] as Map);
        _unknownDeliveryDates = int.tryParse('${result['missing_delivery_dates']}') ?? 0;
        _recentLaravelOrders = (result['orders'] is List)
            ? (result['orders'] as List).whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).take(10).toList()
            : <Map<String, dynamic>>[];
        _financialLoading = false;
      });
      // Get full meal details in the background, never hold up the six financial cards.
      unawaited(_loadRecentLaravelDetails(token, requestId, from, to));
    } catch (e) {
      if (mounted && requestId == _summaryRequestId) setState(() {
        _financialError = '$e'; _today = null; _month = null; _all = null;
        _unknownDeliveryDates = 0; _recentLaravelOrders = [];
        _financialLoading = false;
      });
    }
  }

  Future<void> _loadRecentLaravelDetails(String token, int requestId, String? from, String? to) async {
    try {
      final details = await ApiService().getLaravelManagerOrders(token,
          status: 'completed', perPage: 10, from: from, to: to);
      if (!mounted || requestId != _summaryRequestId) return;
      if (details['orders'] is List) {
        setState(() => _recentLaravelOrders = (details['orders'] as List)
            .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      debugPrint('[ORDERS] RECENT_DETAILS_FAILED: $e');
      // Keep the summary orders returned by V27 report as a safe fallback.
    }
  }

  Future<void> _chooseFinancialRange() async {
    final today = DateTime.now();
    final choice = await showDateRangePicker(
      context: context, firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: _customFinancialRange ?? DateTimeRange(
          start: today.subtract(const Duration(days: 29)), end: today),
      helpText: 'اختر فترة المبيعات',
    );
    if (choice == null || !mounted) return;
    setState(() => _customFinancialRange = choice);
    await _loadFinancialSummary();
  }

  String _num(Map<String, dynamic>? data, String key, {bool money = false}) {
    if (data == null || data[key] == null) return '—';
    final n = num.tryParse(data[key].toString());
    if (n == null) return '—';
    return '${NumberFormat('#,##0.##').format(n)}${money ? ' د.ع' : ''}';
  }

  Future<void> _reload() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    await Future.wait([
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData(token),
      _loadFinancialSummary(),
    ]);
  }

  void _viewOrders([String status = 'completed']) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => ManagerOrdersHistoryScreen(initialStatus: status)));
  }

  static const _sky = Color(0xFF169DDB);
  static const _deep = Color(0xFF076D9F);

  Widget _summaryTile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: BeyteiManagerPalette.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: BeyteiManagerPalette.blue, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(label, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5,
                color: BeyteiManagerPalette.hint))),
      ]),
      const Spacer(),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: BeyteiManagerPalette.dark,
              fontSize: 15.5, fontWeight: FontWeight.w800)),
    ]),
  );
  Widget _section(String title, IconData icon, VoidCallback go) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Row(children: [Icon(icon, color: _deep, size: 22), const SizedBox(width: 9),
      Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF17425D)))),
      TextButton(onPressed: go, child: const Text('عرض الكل'))]),
  );

  @override
  Widget build(BuildContext context) {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    return Consumer<DashboardProvider>(builder: (context, dashboard, _) {
      final active = dashboard.orders['active'] ?? <Order>[];
      return RefreshIndicator(
        onRefresh: _reload,
        color: _sky,
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 28), children: [
          // One compact, consistent dashboard card combining sales and reception.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: BeyteiManagerPalette.border, width: 1.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [
                Icon(Icons.storefront_rounded,
                    color: BeyteiManagerPalette.blue, size: 24),
                SizedBox(width: 9),
                Expanded(child: Text('لوحة مدير المطعم',
                    style: TextStyle(color: BeyteiManagerPalette.dark,
                        fontSize: 19, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              const Text('طلباتك ومبيعاتك في مكان واحد',
                  style: TextStyle(color: BeyteiManagerPalette.hint,
                      fontSize: 12)),
              const SizedBox(height: 14),
              const Text('مبيعات اليوم', style: TextStyle(
                  color: BeyteiManagerPalette.hint, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_num(_today, 'net_sales', money: true),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: BeyteiManagerPalette.blue,
                      fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.task_alt_rounded,
                    color: BeyteiManagerPalette.green, size: 17),
                const SizedBox(width: 5),
                Text('${_num(_today, 'completed_orders')} طلبات مكتملة',
                    style: const TextStyle(fontSize: 12,
                        color: BeyteiManagerPalette.dark)),
              ]),
              const BeyteiManagerReceptionControl(),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('إجراءات سريعة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: BeyteiManagerPalette.dark)),
          const SizedBox(height: 9),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 650;
            final columnCount = wide ? 3 : 2;
            const spacing = 9.0;
            final width = (constraints.maxWidth - (columnCount - 1) * spacing) / columnCount;
            final actions = <Widget>[
              BeyteiManagerQuickAction(
                  title: 'الجارية (${active.length})', subtitle: 'متابعة الطلبات',
                  icon: Icons.delivery_dining_rounded,
                  accent: BeyteiManagerPalette.blue,
                  onTap: () => _viewOrders('active')),
              BeyteiManagerQuickAction(
                  title: 'سجل الطلبات', subtitle: 'الطلبات المكتملة',
                  icon: Icons.history_rounded,
                  accent: BeyteiManagerPalette.green,
                  onTap: () => _viewOrders()),
              BeyteiManagerQuickAction(
                  title: 'طلب مندوب', subtitle: 'عادي أو مستعجل',
                  icon: Icons.local_shipping_outlined,
                  accent: BeyteiManagerPalette.blue,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ManagerCourierScreen()))),
              BeyteiManagerQuickAction(
                  title: 'إضافة وجبة', subtitle: 'إضافة منتج جديد',
                  icon: Icons.add_circle_outline,
                  accent: BeyteiManagerPalette.green,
                  onTap: () => RestaurantManagerNavigation.addMeal(context)),
              BeyteiManagerQuickAction(
                  title: 'إدارة الأقسام', subtitle: 'إضافة وتعديل الأقسام',
                  icon: Icons.grid_view_rounded,
                  accent: BeyteiManagerPalette.blue,
                  onTap: () => RestaurantManagerNavigation.categories(context)),
              BeyteiManagerQuickAction(
                  title: 'المبيعات والأرباح', subtitle: 'التقارير المالية',
                  icon: Icons.analytics_outlined,
                  accent: BeyteiManagerPalette.green,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ManagerAnalyticsScreen()))),
            ];
            return Wrap(spacing: spacing, runSpacing: spacing,
                children: actions.map((action) => SizedBox(
                    width: width, child: action)).toList());
          }),
          const SizedBox(height: 5),
          _section('ملخص الأداء', Icons.query_stats_rounded,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerAnalyticsScreen()))),
          OutlinedButton.icon(onPressed: _chooseFinancialRange, icon: const Icon(Icons.date_range_outlined),
              label: Text(_customFinancialRange == null ? 'آخر 30 يوماً • تغيير الفترة' :
              '${DateFormat('yyyy-MM-dd').format(_customFinancialRange!.start)} — ${DateFormat('yyyy-MM-dd').format(_customFinancialRange!.end)}')),
          if (_customFinancialRange != null) TextButton(
              onPressed: () {setState(() => _customFinancialRange = null); _loadFinancialSummary();},
              child: const Text('العودة إلى آخر 30 يوماً')),
          if (_financialLoading) const LinearProgressIndicator(color: _sky),
          if (_financialError != null) Card(child: Padding(padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تعذر تحديث المبيعات: $_financialError', style: const TextStyle(color: Colors.deepOrange)),
                TextButton.icon(onPressed: _loadFinancialSummary,
                    icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))]))),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) => GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth >= 650 ? 3 : 2,
              childAspectRatio: constraints.maxWidth >= 650 ? 2.5 : 1.55,
              mainAxisSpacing: 9, crossAxisSpacing: 9,
              children: [
                _summaryTile('مكتملة اليوم', _num(_today, 'completed_orders'), Icons.today_outlined),
                _summaryTile('مبيعات اليوم', _num(_today, 'net_sales', money: true), Icons.payments_outlined),
                _summaryTile('مكتملة الفترة', _num(_month, 'completed_orders'), Icons.calendar_month_outlined),
                _summaryTile('مبيعات الفترة', _num(_month, 'net_sales', money: true), Icons.trending_up_rounded),
                _summaryTile('مكتملة منذ البداية', _num(_all, 'completed_orders'), Icons.receipt_long_outlined),
                _summaryTile('مبيعات منذ البداية', _num(_all, 'net_sales', money: true), Icons.account_balance_wallet_outlined),
              ])),
          const SizedBox(height: 7),
          const Text('الأسعار المعتمدة من Laravel ولا تشمل أجور التوصيل. يبدأ اليوم المحاسبي الساعة 3 فجراً.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B8091))),
          if (_unknownDeliveryDates > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(
              '$_unknownDeliveryDates طلبات بلا تاريخ تسليم، تظهر ضمن الإجمالي منذ البداية فقط.',
              style: const TextStyle(color: Colors.deepOrange, fontSize: 11))),
          _section('الطلبات الجارية (${active.length})', Icons.local_shipping_outlined,
                  () => _viewOrders('active')),
          if (dashboard.isLoading && active.isEmpty) const LinearProgressIndicator(color: _sky),
          if (dashboard.orderLoadError != null) Card(child: Padding(padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('تعذّر تحميل الطلبات من Laravel: ${dashboard.orderLoadError}',
                    style: const TextStyle(color: Colors.deepOrange)),
                TextButton.icon(onPressed: () => dashboard.fetchDashboardData(token),
                    icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))]))),
          if (active.isEmpty && !dashboard.isLoading && dashboard.orderLoadError == null)
            const Card(child: Padding(padding: EdgeInsets.all(18),
                child: Text('لا توجد طلبات جارية حالياً', textAlign: TextAlign.center))),
          ...active.take(4).map((order) => OrderCard(order: order,
              onStatusChanged: () => dashboard.fetchDashboardData(token),
              pickupCode: dashboard.pickupCodes[order.id])),
          _section('الطلبات المكتملة مؤخراً', Icons.check_circle_outline,
                  () => _viewOrders()),
          if (_financialLoading && _recentLaravelOrders.isEmpty)
            const LinearProgressIndicator(color: _sky),
          if (!_financialLoading && _recentLaravelOrders.isEmpty && _financialError == null)
            const Card(child: Padding(padding: EdgeInsets.all(15),
                child: Text('لا توجد طلبات مكتملة في القائمة حالياً'))),
          ..._recentLaravelOrders.take(5).map((o) => Card(
            child: ListTile(
              onTap: () => showBeyteiCompletedDriverOrder(context, o),
              leading: const CircleAvatar(backgroundColor: Color(0xFFE5F7FD),
                  child: Icon(Icons.check, color: _deep)),
              title: Text('طلب السائقين #${o['id'] ?? 'غير متاح'}'),
              subtitle: Text('تم التسليم • ${o['delivered_at'] ?? '—'}'),
              trailing: Text('${NumberFormat('#,##0').format(beyteiCompleteOrderAmount(o) ?? 0)} د.ع',
                  style: const TextStyle(color: _deep, fontWeight: FontWeight.bold)),
            ),
          )),
        ]),
      );
    });
  }
}

// Read-only details of a completed driver order. V27 may return only the
// financial summary; meal details appear only when Laravel actually sends them.
void showBeyteiCompletedDriverOrder(BuildContext context, Map<String, dynamic> order) {
  String display(dynamic value, [String fallback = 'غير متاح']) {
    final v = value?.toString().trim() ?? '';
    return v.isEmpty || v == 'null' ? fallback : v;
  }
  String money(dynamic value) {
    final n = num.tryParse('${value ?? ''}');
    return n == null ? 'غير متاح' : '${NumberFormat('#,##0').format(n)} د.ع';
  }
  final rawItems = order['line_items'];
  dynamic itemsValue = rawItems;
  if (rawItems is String && rawItems.trim().isNotEmpty) {
    try { itemsValue = json.decode(rawItems); } catch (_) { itemsValue = null; }
  }
  final items = itemsValue is List
      ? itemsValue.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
  final simpleItems = display(order['order_items'], '');
  final note = display(order['notes'], '');

  showModalBottomSheet<void>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (sheetContext) => SafeArea(child: FractionallySizedBox(
      heightFactor: 0.76,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('تفاصيل الطلب #${display(order['id'])}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListTile(title: const Text('الحالة'),
            trailing: Text(restaurantOrderStatusLabel(display(order['status'])))),
        ListTile(title: const Text('تاريخ التسليم'),
            subtitle: Text(display(order['delivered_at']))),
        const Divider(),
        ListTile(title: const Text('سعر الطلب كامل'),
            trailing: Text(money(beyteiCompleteOrderAmount(order)),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
        const Divider(),
        const Text('الوجبات والكميات', style: TextStyle(fontWeight: FontWeight.bold)),
        if (items.isNotEmpty)
          ...items.map((item) => ListTile(
            title: Text(display(item['name'], 'منتج')),
            subtitle: Text([
              'الكمية: ${display(item['quantity'], '1')}',
              if (display(item['options_summary'], '').isNotEmpty)
                display(item['options_summary']),
              if (display(item['note'], '').isNotEmpty)
                'ملاحظة: ${display(item['note'])}',
            ].join(' • ')),
            trailing: Text(money(item['total'])),
          ))
        else if (simpleItems.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(simpleItems))
        else
          const Padding(padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('نسخة API المالي الحالية لا ترسل تفاصيل الوجبات لهذا الطلب؛ تعرض فقط المبلغ ورقم الطلب وتاريخ التسليم.')),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('ملاحظات الطلب: $note'),
        ],
        const SizedBox(height: 20),
      ]),
    )),
  );
}

// Independently paginated list: shows both current and completed orders as cards.
class ManagerOrdersHistoryScreen extends StatefulWidget {
  final String initialStatus;
  const ManagerOrdersHistoryScreen({super.key, this.initialStatus = 'completed'});
  @override
  State<ManagerOrdersHistoryScreen> createState() => _ManagerOrdersHistoryScreenState();
}
class _ManagerOrdersHistoryScreenState extends State<ManagerOrdersHistoryScreen> {
  late String _status;
  List<Order> _items = [];
  List<Map<String, dynamic>> _completedDriverOrders = [];
  int _nextPage = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }
  Future<void> _load({bool reset = false}) async {
    if (_loading || !mounted) return;
    if (!reset && !_hasMore) return;
    final selected = _status;
    setState(() {
      _loading = true; _error = null;
      if (reset) { _nextPage = 1; _items = []; _completedDriverOrders = []; _hasMore = true; }
    });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      if (selected == 'completed') {
        final result = await ApiService().getLaravelManagerOrders(token,
            status: 'completed', page: _nextPage, perPage: 20);
        if (!mounted || _status != selected) return;
        final rows = (result['orders'] is List)
            ? (result['orders'] as List).whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        final existing = _completedDriverOrders.map((e) => '${e['id']}').toSet();
        setState(() {
          _completedDriverOrders.addAll(rows.where((e) => existing.add('${e['id']}')));
          _hasMore = result['has_more'] == true;
          _nextPage++;
        });
      } else {
        final result = await ApiService().getLaravelManagerOrders(token,
            status: 'active', page: _nextPage, perPage: 20);
        final activeOrders = (result['orders'] as List)
            .whereType<Map>()
            .map((e) => ApiService.mapDriverOrderToCard(Map<String, dynamic>.from(e)))
            .toList();
        if (!mounted || _status != selected) return;
        final seen = _items.map((e) => e.id).toSet();
        setState(() {
          _items.addAll(activeOrders.where((e) => seen.add(e.id)));
          _hasMore = result['has_more'] == true;
          _nextPage++;
        });
      }
    } catch (e) {
      if (mounted && _status == selected) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  void _select(String value) {
    if (_status == value || _loading) return;
    setState(() => _status = value);
    _load(reset: true);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مشاهدة طلبات المطعم'),
        actions: [IconButton(onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh), tooltip: 'تحديث')]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(label: const Text('الطلبات الجارية'),
            selected: _status == 'active', onSelected: (_) => _select('active')),
        const SizedBox(width: 10),
        ChoiceChip(label: const Text('الطلبات المكتملة'),
            selected: _status == 'completed', onSelected: (_) => _select('completed')),
      ])),
      Expanded(child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 32), children: [
          if (_loading && _items.isEmpty && _completedDriverOrders.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) Padding(padding: const EdgeInsets.all(12),
              child: Text('تعذر تحميل الطلبات: $_error',
                  style: const TextStyle(color: Colors.deepOrange))),
          if (!_loading && (_status == 'completed' ? _completedDriverOrders.isEmpty : _items.isEmpty)
              && _error == null)
            const Padding(padding: EdgeInsets.all(30),
                child: Center(child: Text('لا توجد طلبات في هذا القسم'))),
          if (_status == 'completed')
            ..._completedDriverOrders.map((o) => Card(child: ListTile(
              onTap: () => showBeyteiCompletedDriverOrder(context, o),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('طلب السائقين #${o['id'] ?? '-'}'),
              subtitle: Text('مكتمل — ${o['delivered_at'] ?? '-'}'),
              trailing: Text('${NumberFormat('#,##0').format(num.tryParse('${o['order_total']}') ?? 0)} د.ع',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )))
          else
            ..._items.map((order) => OrderCard(order: order,
                isCompleted: false,
                onStatusChanged: () => _load(reset: true))),
          if (_loading && (_items.isNotEmpty || _completedDriverOrders.isNotEmpty))
            const Center(child: CircularProgressIndicator()),
          if (!_loading && _hasMore) OutlinedButton.icon(
              onPressed: () => _load(), icon: const Icon(Icons.expand_more),
              label: const Text('تحميل المزيد من الطلبات')),
          if (!_loading && _error != null) TextButton(
              onPressed: () => _load(), child: const Text('إعادة المحاولة')),
        ]),
      )),
    ]),
  );
}

class DashboardProvider with ChangeNotifier {
  Map<String, List<Order>> _orders = {};
  RestaurantRatingsDashboard? _ratingsDashboard;
  Map<int, String> _pickupCodes = {};
  bool _isLoading = false;
  Timer? _timer;
  Timer? _debounceTimer;
  bool _fetching = false;
  bool _ratingsFetching = false;
  String? _orderLoadError;
  String? _ratingsLoadError;

  String? get orderLoadError => _orderLoadError;
  String? get ratingsLoadError => _ratingsLoadError;
  Map<String, List<Order>> get orders => _orders;
  RestaurantRatingsDashboard? get ratingsDashboard => _ratingsDashboard;
  Map<int, String> get pickupCodes => _pickupCodes;
  bool get isLoading => _isLoading;

  void triggerSmartRefresh(String token) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      fetchDashboardData(token, silent: true);
    });
  }

  void startAutoRefresh(String token) {
    _timer?.cancel();
    fetchDashboardData(token, silent: true);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchDashboardData(token, silent: true);
    });
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _debounceTimer?.cancel();
  }

  void setPickupCode(int orderId, String code) {
    _pickupCodes[orderId] = code;
    notifyListeners();
  }

  void _refreshRatingsIndependently(String token) {
    if (_ratingsFetching) return;
    _ratingsFetching = true;
    unawaited(ApiService().getDashboardRatings(token).then<void>((ratings) {
      _ratingsDashboard = ratings;
      _ratingsLoadError = null;
      notifyListeners();
    }).catchError((Object error) {
      _ratingsLoadError = '$error';
      debugPrint('تعذر تحديث تقييمات المطعم: $error');
      notifyListeners();
    }).whenComplete(() {
      _ratingsFetching = false;
    }));
  }

  Future<void> fetchDashboardData(String? token, {bool silent = false}) async {
    if (token == null) return;
    // Ratings are independent from WooCommerce order loading.
    _refreshRatingsIndependently(token);
    if (_fetching) return;
    _fetching = true;

    if (!silent || _orders.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final ApiService api = ApiService();

      // Completed orders and sales come directly from Laravel in UnifiedOrdersScreen.
      // Do not scan WooCommerce completed orders again (very slow for large stores).
      final activePayload = await api.getLaravelManagerOrders(
          token, status: 'active', perPage: 50);
      final activeFromServer = (activePayload['orders'] as List)
          .whereType<Map>()
          .map((e) => ApiService.mapDriverOrderToCard(Map<String, dynamic>.from(e)))
          .toList();
      final completedFromServer = <Order>[]; // completed history is also on Laravel

      List<Order> allOrders = [...activeFromServer, ...completedFromServer];

      // إزالة التكرار بناءً على معرف الطلب
      final ids = <int>{};
      allOrders.retainWhere((x) => ids.add(x.id));

      List<Order> finalActive = [];
      List<Order> finalCompleted = [];
      final List<String> archiveStatuses = ['completed', 'cancelled', 'refunded', 'failed', 'delivered'];

      for (var order in allOrders) {
        if (!archiveStatuses.contains(order.status.toLowerCase())) {
          finalActive.add(order);
        } else {
          finalCompleted.add(order);
        }
      }

      // ترتيب الطلبات من الأحدث للأقدم
      finalCompleted.sort((a, b) => (b.dateCompleted ?? b.dateCreated)
          .compareTo(a.dateCompleted ?? a.dateCreated));
      finalActive.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

      _orders['active'] = finalActive;
      _orders['completed'] = finalCompleted;
      _orderLoadError = null;
      // Update order cards immediately; a slow ratings API must not hide them.
      notifyListeners();

    } catch (e, stackTrace) {
      _orderLoadError = '$e';
      print("🔥🔥🔥 خطأ في جلب بيانات لوحة التحكم: $e");
      print("🔥🔥🔥 تفاصيل الخطأ: $stackTrace");
    } finally {
      _isLoading = false;
      _fetching = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
// =======================================================================
// 🔷 القسم 7: الشاشات (Screens) - 🔥 إصلاح رئيسي لشاشة الدخول
// =======================================================================

class RestaurantLoginScreen extends StatefulWidget {
  const RestaurantLoginScreen({super.key});
  @override
  State<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends State<RestaurantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _username.dispose(); _password.dispose();
    super.dispose();
  }
  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final result = await auth.login(_username.text.trim(), _password.text, 'owner')
          .timeout(const Duration(seconds: 22));
      if (!mounted) return;
      if (!result) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('فشل تسجيل الدخول. تحقق من البيانات أو الصلاحيات.')));
      // AuthWrapper يتابع حالة الدخول ويعرض لوحة المدير دون إنشاء شاشة مكررة.
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تسجيل الدخول: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
          child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(radius: 42, backgroundColor: Color(0xFFE0F4ED),
                child: Icon(Icons.storefront_rounded, size: 46, color: const Color(0xFF168EC7))),
            const SizedBox(height: 18),
            const Text('مدير المطعم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25)),
            const SizedBox(height: 8),
            const Text('إدارة الطلبات والقائمة وساعات العمل بسهولة', textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextFormField(controller: _username, keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'اسم المستخدم أو رقم الهاتف',
                    prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                validator: (v) => (v ?? '').trim().isEmpty ? 'اسم المستخدم مطلوب' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _password, obscureText: !_showPassword,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(labelText: 'كلمة المرور', border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility))),
                validator: (v) => (v ?? '').isEmpty ? 'كلمة المرور مطلوبة' : null),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, height: 50,
                child: FilledButton(onPressed: _isLoading ? null : _login,
                    child: Text(_isLoading ? 'جارٍ تسجيل الدخول...' : 'تسجيل الدخول'))),
            const SizedBox(height: 16),
            const Text('موقع المطعم يُقرأ من السيرفر؛ لا نغيّره تلقائياً بموقع هاتف المدير عند تسجيل الدخول.',
                style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ]))),
    ))),
  );
}


class RestaurantManagerNavigation {
  static Future<void> addMeal(BuildContext context) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final products = Provider.of<RestaurantProductsProvider>(context, listen: false);
      if (auth.token == null) throw Exception('انتهت جلسة المستخدم');
      final api = ApiService();
      final info = await api.getManagerContext(auth.token!);
      final rid = int.tryParse('${info['id']}') ?? 0;
      if (rid <= 0) throw Exception('حسابك غير مرتبط بمطعم');
      final sections = await api.getRestaurantSections(auth.token!, rid);
      if (!context.mounted) return;
      if (sections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف قسماً أولاً من إدارة الأقسام')));
        return;
      }
      final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) =>
          AddProductScreen(authProvider: auth, productProvider: products, sections: sections)));
      if (result == true) await products.fetchProducts(auth.token);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح إضافة وجبة: $e')));
    }
  }

  static Future<void> categories(BuildContext context) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final info = await ApiService().getManagerContext(token);
      final rid = int.tryParse('${info['id']}') ?? 0;
      if (rid < 1) throw Exception('حسابك غير مرتبط بمطعم');
      if (!context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ManageSectionsScreen(restaurantId: rid)));
      if (context.mounted) await Provider.of<RestaurantProductsProvider>(context, listen: false).fetchProducts(token);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class RestaurantQuickPanel extends StatelessWidget {
  const RestaurantQuickPanel({super.key});
  @override
  Widget build(BuildContext context) => Consumer<RestaurantSettingsProvider>(
    builder: (context, settings, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.storefront, color: const Color(0xFF168EC7)), const SizedBox(width: 8),
          const Expanded(child: Text('استقبال طلبات المطعم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          if (settings.isLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        if (settings.error != null) Text(settings.error!, style: const TextStyle(color: Colors.red)),
        if (!settings.loaded) TextButton(onPressed: () {
          final token = Provider.of<AuthProvider>(context, listen: false).token;
          settings.fetchSettings(token);
        }, child: const Text('تحميل حالة المطعم')),
        if (settings.loaded) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(settings.operationMode == 'auto' ? 'الاستقبال حسب الجدول التلقائي'
                : settings.isRestaurantOpen ? 'المطعم مفتوح يدوياً' : 'المطعم مغلق يدوياً'),
            subtitle: Text(settings.operationMode == 'auto'
                ? 'الحالة الفعلية يحددها التوقيت في السيرفر، والزر يحوّل الوضع إلى إيقاف يدوي'
                : 'يمكنك إغلاق المطعم أو فتحه يدوياً'),
            value: settings.operationMode == 'auto' || settings.isRestaurantOpen,
            onChanged: (newValue) async {
              if (!newValue) {
                final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('إيقاف استقبال الطلبات؟'),
                  content: const Text('سيتم إغلاق المطعم يدوياً حتى تعيد فتحه أو تفعّل الجدول التلقائي.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إيقاف'))],
                ));
                if (ok != true || !context.mounted) return;
              }
              final token = Provider.of<AuthProvider>(context, listen: false).token;
              final ok = await settings.updateRestaurantStatus(token, 'manual', newValue);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'تم تحديث حالة المطعم' : settings.error ?? 'تعذر التحديث')));
              }
            },
          ),
        ],
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 7, children: [
          OutlinedButton.icon(onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RestaurantSettingsPage())),
              icon: const Icon(Icons.schedule), label: const Text('أوقات العمل')),
          OutlinedButton.icon(onPressed: () => showModalBottomSheet<void>(context: context,
              showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(
                  padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('إيقاف مؤقت بالدقائق', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Text('يحتاج دعماً من السيرفر ليعود استقبال الطلبات تلقائياً.'),
                ...[15, 30, 60].map((minutes) => ListTile(
                  title: Text('$minutes دقيقة'), leading: const Icon(Icons.pause_circle_outline),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final token = Provider.of<AuthProvider>(context, listen: false).token;
                    try {
                      if (token == null) throw Exception('يرجى تسجيل الدخول');
                      await ApiService().pauseIncomingOrders(token, minutes);
                      await settings.fetchSettings(token);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إيقاف الطلبات لمدة $minutes دقيقة')));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                )),
              ])))), icon: const Icon(Icons.pause_circle), label: const Text('إيقاف مؤقت')),
        ]),
      ],
      ))),
      const SizedBox(height: 14),
      const Text('إجراءات سريعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: () => RestaurantManagerNavigation.addMeal(context),
            icon: const Icon(Icons.add_circle_outline), label: const Text('وجبة جديدة')),
        FilledButton.tonalIcon(onPressed: () => RestaurantManagerNavigation.categories(context),
            icon: const Icon(Icons.category_outlined), label: const Text('إدارة الأقسام')),
        const RestaurantUrgentPickupQuickButton(),
        FilledButton.tonalIcon(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ManagerPickupLocationScreen())),
            icon: const Icon(Icons.my_location_outlined), label: const Text('موقع المطعم')),
        FilledButton.tonalIcon(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ManagerAnalyticsScreen())),
            icon: const Icon(Icons.insights), label: const Text('المبيعات والأرباح')),
      ]),
    ]),
  );
}

class RestaurantSettingsPage extends StatelessWidget {
  const RestaurantSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مواعيد وحالة المطعم')),
    body: const RestaurantSettingsScreen(),
  );
}

class ManagerAnalyticsScreen extends StatefulWidget {
  const ManagerAnalyticsScreen({super.key});
  @override
  State<ManagerAnalyticsScreen> createState() => _ManagerAnalyticsScreenState();
}
class _ManagerAnalyticsScreenState extends State<ManagerAnalyticsScreen> {
  Map<String, dynamic>? _data;
  DateTimeRange? _range;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  final List<Map<String, dynamic>> _orders = [];
  int _page = 1;
  bool _hasMore = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool loadMore = false}) async {
    if (!mounted || (loadMore && (_loadingMore || !_hasMore))) return;
    setState(() {
      if (loadMore) { _loadingMore = true; }
      else { _loading = true; _error = null; }
    });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final from = _range == null ? null : DateFormat('yyyy-MM-dd').format(_range!.start);
      final to = _range == null ? null : DateFormat('yyyy-MM-dd').format(_range!.end);
      final next = loadMore ? _page + 1 : 1;
      final result = await ApiService().getDriverFinanceSnapshot(token,
          from: from, to: to, page: 1);
      // When a custom date is selected, the finance report remains the source
      // for the scoped completed list in that specific accounting date window.
      final detailed = await ApiService().getLaravelManagerOrders(token,
          status: 'completed', page: next, perPage: 30,
          from: from ?? result['from']?.toString(),
          to: to ?? result['to']?.toString());
      if (!mounted) return;
      setState(() {
        _data = result;
        if (!loadMore) _orders.clear();
        if ((detailed?['orders'] ?? result['orders']) is List) {
          for (final raw in ((detailed?['orders'] ?? result['orders']) as List)) {
            if (raw is Map) _orders.add(Map<String, dynamic>.from(raw));
          }
        }
        _page = next;
        _hasMore = (detailed?['has_more'] ?? result['has_more']) == true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final chosen = await showDateRangePicker(
      context: context, firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range ?? DateTimeRange(
          start: now.subtract(const Duration(days: 29)), end: now),
      helpText: 'حدد تاريخ البداية والنهاية',
    );
    if (chosen == null || !mounted) return;
    setState(() => _range = chosen);
    await _load();
  }

  String _money(dynamic value) {
    final amount = num.tryParse('$value') ?? 0;
    return '${NumberFormat('#,##0').format(amount)} د.ع';
  }
  String _count(dynamic value) => NumberFormat('#,##0').format(num.tryParse('$value') ?? 0);
  Widget _tile(String label, dynamic value, {bool money = false}) => Card(
      child: ListTile(title: Text(label), trailing: Text(money ? _money(value) : _count(value),
          style: const TextStyle(fontWeight: FontWeight.bold))));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مبيعات المطعم من سيرفر السائقين'),
        actions: [IconButton(onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
            label: Text(_range == null ? 'آخر 30 يوماً (اختر الفترة)' :
            '${DateFormat('yyyy-MM-dd').format(_range!.start)} إلى ${DateFormat('yyyy-MM-dd').format(_range!.end)}')),
        if (_range != null) TextButton(onPressed: () {
          setState(() => _range = null); _load();
        }, child: const Text('آخر 30 يوماً')),
      ]),
      const Text('بداية اليوم المحاسبي 3:00 فجراً بتوقيت بغداد. مبيعات المطعم المحاسبية لا تشمل أجرة توصيل المندوب.',
          style: TextStyle(fontSize: 12, color: Colors.black54)),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Padding(padding: const EdgeInsets.all(10),
          child: Text('تعذر تحميل الإحصائيات: $_error',
              style: const TextStyle(color: Colors.deepOrange))),
      if (_data != null && !_loading) ...[
        _tile('مكتملة اليوم', (_data!['today'] as Map)['completed_orders']),
        _tile('مبيعات اليوم', (_data!['today'] as Map)['net_sales'], money: true),
        _tile(_range == null ? 'مكتملة آخر 30 يوماً' : 'مكتملة الفترة',
            (_data!['selected'] as Map)['completed_orders']),
        _tile(_range == null ? 'مبيعات آخر 30 يوماً' : 'مبيعات الفترة',
            (_data!['selected'] as Map)['net_sales'], money: true),
        _tile('مكتملة منذ البداية', (_data!['lifetime'] as Map)['completed_orders']),
        _tile('مبيعات منذ البداية', (_data!['lifetime'] as Map)['net_sales'], money: true),
        if ((int.tryParse('${_data!['missing_delivery_dates']}') ?? 0) > 0)
          Padding(padding: const EdgeInsets.all(8), child: Text(
              'بعض الطلبات المكتملة بلا تاريخ تسليم؛ تظهر فقط في إجمالي منذ البداية.',
              style: const TextStyle(color: Colors.deepOrange))),
        const SizedBox(height: 16),
        const Text('الطلبات المكتملة خلال الفترة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ..._orders.map((o) => Card(child: ListTile(
          onTap: () => showBeyteiCompletedDriverOrder(context, o),
          leading: const Icon(Icons.receipt_long),
          title: Text('طلب #${o['id']} — ${_money(beyteiCompleteOrderAmount(o))}'),
          subtitle: Text('الحالة: ${restaurantOrderStatusLabel('${o['status']}')} | التسليم: ${o['delivered_at'] ?? 'غير متاح'}'),
        ))),
        if (_hasMore) TextButton.icon(onPressed: _loadingMore ? null : () => _load(loadMore: true),
            icon: const Icon(Icons.expand_more), label: const Text('عرض المزيد')),
        if (_loadingMore) const Center(child: CircularProgressIndicator()),
      ],
    ]),
  );
}

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  State<RestaurantDashboardScreen> createState() => _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> with SingleTickerProviderStateMixin {
  StreamSubscription<RemoteMessage>? _orderMessageSub;
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  DashboardProvider? _liveDashboard;

  @override
  void initState() {
    super.initState();
    _orderMessageSub=FirebaseMessaging.onMessage.listen((message){
      final type=message.data['type']?.toString() ?? '';
      if(type=='new_order' && mounted){
        final token=Provider.of<AuthProvider>(context,listen:false).token;
        if(token!=null)Provider.of<DashboardProvider>(context,listen:false).triggerSmartRefresh(token);
      }
    });
    // 🔥 تم تقليل عدد التبويبات إلى 4 (حذفنا تبويب المكتملة المنفصل)
    _tabController = TabController(length: 4, vsync: this);

    // 🔥 الحل الجذري: استخدام addPostFrameCallback لضمان جاهزية الـ Context والـ Providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final token = Provider.of<AuthProvider>(context, listen: false).token;

      // 🔍 رسالة تشخيصية: راقب الـ Console للتأكد من أن التوكن ليس فارغاً
      print("🔍 [Dashboard Init] حالة التوكن: ${token != null ? 'موجود ✅' : 'فارغ ❌'}");

      if (token != null) {
        // 1. جلب إعدادات المطعم (الحالة، أوقات العمل، الموقع)
        Provider.of<RestaurantSettingsProvider>(context, listen: false).fetchSettings(token);

        // 🔥 2. الحل السحري: جلب المنتجات صراحةً عند فتح الداشبورد
        Provider.of<RestaurantProductsProvider>(context, listen: false).fetchProducts(token);

        // 3. بدء التحديث التلقائي للطلبات والتقييمات
        _liveDashboard = Provider.of<DashboardProvider>(context, listen: false);
        _liveDashboard!.startAutoRefresh(token);
      } else {
        print("⚠️ [Dashboard Init] تحذير: تم فتح الداشبورد والتوكن فارغ! يرجى إعادة تسجيل الدخول.");
      }
    });
  }

  @override
  void dispose() {
    // إيقاف التحديث التلقائي عند الخروج من الشاشة لتوفير موارد الجهاز والذاكرة
    _liveDashboard?.stopAutoRefresh();
    _orderMessageSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _testNotifications() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final accepted = await _apiService.testManagerPush(token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accepted
          ? 'Firebase قبل إرسال إشعار تجريبي؛ تحقق من ظهوره وصوته على الهاتف.'
          : 'لم يؤكد Firebase قبول الإشعار. راجع تسجيل الجهاز وأذونات الإشعارات.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال إشعار الاختبار: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: const Text('منصة بيتي\nإدارة المطعم',
            maxLines: 2, style: TextStyle(fontSize: 15, height: 1.12,
                fontWeight: FontWeight.bold)),
        actions: [
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.61),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [

                IconButton(tooltip: 'المحفظة', padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 37, height: 43),
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 23, color: Colors.green),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()))),
                IconButton(tooltip: 'موقع المطعم والمنطقة', padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 37, height: 43),
                    icon: const Icon(Icons.location_on_outlined, size: 23, color: Colors.blue),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ManagerPickupLocationScreen()))),
                IconButton(tooltip: 'طلب مندوب', padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 37, height: 43),
                    icon: const Icon(Icons.local_shipping_outlined, size: 23),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ManagerCourierScreen()))),
                IconButton(tooltip: 'اختبار الإشعارات', padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 37, height: 43),
                    icon: const Icon(Icons.notifications_active_outlined, size: 23),
                    onPressed: _testNotifications),
                IconButton(tooltip: 'العروض الترويجية', padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 37, height: 43),
                    icon: const Icon(Icons.campaign_outlined, size: 23),
                    onPressed: () => _showModernOfferDialog(context)),
                IconButton(tooltip: 'تسجيل الخروج', padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 37, height: 43),
                    icon: const Icon(Icons.logout, size: 23, color: Colors.red),
                    onPressed: () => auth.logout(context)),
              ]),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          padding: EdgeInsets.zero,
          labelPadding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: BeyteiManagerPalette.blue,
          labelColor: BeyteiManagerPalette.blue,
          unselectedLabelColor: BeyteiManagerPalette.hint,
          tabs: const [
            Tab(height: 62, child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.dashboard_outlined, size: 21),
              SizedBox(height: 3),
              Text('الطلبات\nوالإحصائيات', textAlign: TextAlign.center,
                  maxLines: 2, style: TextStyle(fontSize: 10.5, height: 1.12)),
            ])),
            Tab(height: 62, child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.fastfood_outlined, size: 21),
              SizedBox(height: 3),
              Text('المنتجات', style: TextStyle(fontSize: 11.5)),
            ])),
            Tab(height: 62, child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.star_outline_rounded, size: 21),
              SizedBox(height: 3),
              Text('التقييمات', style: TextStyle(fontSize: 11.5)),
            ])),
            Tab(height: 62, child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.settings_outlined, size: 21),
              SizedBox(height: 3),
              Text('الإعدادات', style: TextStyle(fontSize: 11.5)),
            ])),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const UnifiedOrdersScreen(), // 🔥 الشاشة الجديدة الموحدة (تحتوي على الإحصائيات + النشطة + المكتملة)
          const ProductManagementTab(),
          const RatingsDashboardScreen(),
          const RestaurantSettingsScreen(),
        ],
      ),
    );
  }

  Future<void> _showModernOfferDialog(BuildContext context) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    Map<String, dynamic>? cfg;
    try {
      cfg = await _apiService.getMarketingConfig(token);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر قراءة تكلفة العرض: $e')));
      return;
    }
    if (!context.mounted) return;
    if (cfg == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('إرسال العروض متوقف حتى يزوّد السيرفر السعر ومعرّف الخدمة. لن نستخدم أسعاراً افتراضية.')));
      return;
    }
    final productId = int.tryParse('${cfg['product_id']}') ?? 0;
    final cost = double.tryParse('${cfg['cost']}') ?? -1;
    if (productId < 1 || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إعدادات الإعلان في السيرفر غير صحيحة')));
      return;
    }
    final title = TextEditingController();
    final body = TextEditingController();
    bool sending = false;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) =>
            SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('إرسال عرض ترويجي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('تكلفة الخدمة المؤكدة من السيرفر: ${NumberFormat('#,##0').format(cost)} د.ع'),
                  const SizedBox(height: 12),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان العرض')),
                  const SizedBox(height: 12),
                  TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'تفاصيل العرض')),
                  const SizedBox(height: 22),
                  SizedBox(width: double.infinity, child: FilledButton(
                      onPressed: sending ? null : () async {
                        if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('العنوان والتفاصيل مطلوبان')));
                          return;
                        }
                        refresh(() => sending = true);
                        try {
                          await _apiService.createMarketingOrder(token: token, title: title.text.trim(),
                              bodyText: body.text.trim(), imageUrl: null, productId: productId, cost: cost);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل طلب العرض')));
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('فشل إرسال العرض: $e')));
                        } finally {
                          if (ctx.mounted) refresh(() => sending = false);
                        }
                      }, child: Text(sending ? 'جاري الإرسال...' : 'تأكيد وإرسال'))),
                ]))))));
    title.dispose(); body.dispose();
  }

}
// Direct one-tap dispatch from restaurant dashboard; no customer information form.
// V34: the quick button opens the validated form; no dispatch without fee.
class RestaurantUrgentPickupQuickButton extends StatelessWidget {
  const RestaurantUrgentPickupQuickButton({super.key});
  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ManagerCourierScreen(initialUrgent: true))),
    icon: const Icon(Icons.flash_on), label: const Text('مندوب مستعجل'),
  );
}

// V34 - complete restaurant courier request and event-driven tracking.
class ManagerCourierScreen extends StatefulWidget {
  final bool initialUrgent;
  const ManagerCourierScreen({super.key, this.initialUrgent = true});
  @override
  State<ManagerCourierScreen> createState() => _ManagerCourierScreenState();
}

class _ManagerCourierScreenState extends State<ManagerCourierScreen>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  StreamSubscription<RemoteMessage>? _messages;
  late bool _urgent;
  int _fee = 1000;
  bool _loading = true, _sending = false;
  Map<String, dynamic>? _context;
  List<Map<String, dynamic>> _orders = [];
  String? _error;
  String? _requestId;
  int? _lastOrder;
  bool _unconfirmed = false;
  static const _deep = Color(0xFF147EBC);
  static const _green = Color(0xFF0DBA85);

  @override
  void initState() {
    super.initState();
    _urgent = widget.initialUrgent;
    WidgetsBinding.instance.addObserver(this);
    _messages = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type']?.toString() ?? '';
      if (type == 'manager_courier_status' || type == 'driver_assigned' ||
          type == 'order_status_update' || type == 'status_update') {
        _refresh(silent: true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(silent: true);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messages?.cancel();
    _phone.dispose();_name.dispose();_address.dispose();
    _notes.dispose();
    super.dispose();
  }

  // Zone IDs/names always come from the existing authenticated
  // manager-context endpoint, never from a globally selectable city list.
  List<Map<String, dynamic>> _serverAreas = [];
  int? _zoneId;
  bool _courierApiAvailable = false;

  String get _zoneText => beyteiZoneDescription(_zoneId, _serverAreas);

  Future<void> _refresh({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      // Three independent GET requests start at once; no sequential network waits.
      final baseFuture = _api.getManagerContext(token);
      final configFuture = _api.getManagerCourierConfig(token)
          .timeout(const Duration(seconds: 12)).then<Map<String,dynamic>?>((v)=>v)
          .catchError((Object e) { debugPrint('Courier config: $e'); return null; });
      final ordersFuture = _api.getManagerCourierOrders(token)
          .timeout(const Duration(seconds: 12)).then<Map<String,dynamic>?>((v)=>v)
          .catchError((Object e) { debugPrint('Courier orders: $e'); return null; });
      final base = await baseFuture;
      final areas = (base['areas'] as List? ?? [])
          .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
      final allowed = areas.map((a) => int.tryParse('${a['id']}'))
          .whereType<int>().where((id)=>id>0).toSet();
      final saved = int.tryParse('${base['pickup_zone_id']}');
      int? selected = saved != null && allowed.contains(saved)
          ? saved : allowed.length == 1 ? allowed.single : null;
      final info = <String,dynamic>{
        'restaurant_id':base['id'], 'restaurant_name':base['name'],
        'pickup_lat':base['latitude'], 'pickup_lng':base['longitude'],
        'zone_id':selected, 'allowed_zones':areas, 'enabled':false,
      };
      if (mounted) setState(() {
        _serverAreas = areas; _zoneId=selected; _context=info;
        _loading=false; // Show region and controls immediately.
      });
      final remote = await configFuture;
      final all = await ordersFuture;
      final supported = remote != null;
      String? notice;
      if (remote != null) {
        final returnedZone = int.tryParse('${remote['zone_id']}');
        if (returnedZone != null && allowed.contains(returnedZone)) selected=returnedZone;
        info.addAll(remote);
        info['zone_id']=selected;
      } else {
        notice='تعذر الوصول إلى خدمة طلب المندوب؛ تأكد من الشبكة أو تفعيل V34.';
      }
      final orders = (all?['orders'] as List? ?? [])
          .whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList();
      if (all == null && supported) notice='تعذر تحديث قائمة الطلبات. اسحب الشاشة لإعادة المحاولة.';
      final prefs = await SharedPreferences.getInstance();
      final rid = int.tryParse('${info['restaurant_id']}') ?? 0;
      final requestKey = 'beytei_v34_active_request_$rid';
      var id = prefs.getString(requestKey);
      if (id == null) {
        id='${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1<<31)}';
        await prefs.setString(requestKey,id);
      }
      if (!mounted) return;
      setState(() {
        _serverAreas=areas; _zoneId=selected;
        _context=info; _courierApiAvailable=supported;
        _orders=orders; _requestId=id; _error=notice;
        _unconfirmed=orders.any((o)=>o['dispatch_confirmed']!=true &&
            !['cancelled','failed'].contains(o['status']));
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _error='تعذر تحميل بيانات المطعم: $e');
    } finally {
      if (mounted) setState(() => _loading=false);
    }
  }

  Future<void> _saveNewRequestKey() async {
    final rid = int.tryParse('${_context?['restaurant_id']}') ?? 0;
    final newId = '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('beytei_v34_active_request_$rid', newId);
    _requestId = newId;
  }

  Future<void> _submit() async {
    if (_sending || _unconfirmed || _context?['enabled'] != true || !_formKey.currentState!.validate()) return;
    // Laravel currently applies a zone-84 driver fee adjustment above 1,500 IQD.
    // Never promise the selected 2,000/3,000 IQD will be sent unchanged.
    if (_zoneId == 84 && _fee > 1500) {
      _toast('في الكوت لا يمكن حالياً طلب أجرة 2000 أو 3000 لأن سيرفر السائقين يغيرها. اختر 1000 إلى حين توحيد التسعير.');
      return;
    }
    if (!_courierApiAvailable) {
      _toast('مسار طلب المندوب بالتوكن غير موجود في WordPress الحالي. لم يتم إرسال أي طلب.');
      return;
    }
    if (_zoneId == null) {
      _toast('منطقة المطعم غير معتمدة؛ اخترها من إعدادات موقع المطعم');return;
    }
    final verifiedZone = int.tryParse('${_context?['zone_id']}');
    if (verifiedZone != _zoneId) {
      _toast('المنطقة المختارة تختلف عن المنطقة المعتمدة في WordPress. لم يتم إرسال الطلب.');
      return;
    }
    if (_context?['pickup_lat'] == null || _context?['pickup_lng'] == null) {
      _toast('حدد موقع المطعم أولاً');return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_urgent ? 'تأكيد مندوب مستعجل' : 'تأكيد طلب المندوب'),
      content: Text('الأجرة: $_fee دينار\nالمطعم: ${_context?['restaurant_name']}\n'
          'سيرسل الطلب إلى سائقي $_zoneText. هل تؤكد؟'),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('تأكيد'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { _sending = true; _lastOrder = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      // Obtain a FRESH FCM token from THIS phone for EVERY courier request.
      // Do not rely on a token saved earlier for a different manager/device.
      String? deviceFcmToken;
      try {
        deviceFcmToken = await FirebaseMessaging.instance.getToken()
            .timeout(const Duration(seconds: 12));
      } catch (e) {
        throw Exception('تعذر الحصول على توكن إشعارات هذا الهاتف: $e');
      }
      if (deviceFcmToken == null || deviceFcmToken.trim().isEmpty) {
        throw Exception('توكن الإشعارات غير متوفر. فعّل إشعارات التطبيق وتأكد من الاتصال بالإنترنت. لم يتم إرسال طلب.');
      }
      final body = <String, dynamic>{
        'request_id': _requestId,
        'fcm_token': deviceFcmToken.trim(),
        'device_platform': Platform.isIOS ? 'ios' : 'android',
        'mode': _urgent ? 'urgent' : 'normal',
        'delivery_fee': _fee,
        // Client sends both numeric zone and its UI label. Backend must
        // independently verify the zone belongs to the logged-in restaurant.
        'zone_id': _zoneId,
        'zone_name': beyteiZoneName(_zoneId, _serverAreas),
        'restaurant_id': _context?['restaurant_id'],
        'restaurant_name': _context?['restaurant_name'],
        if (!_urgent) 'customer_name': _name.text.trim(),
        if (!_urgent) 'customer_phone': _phone.text.trim(),
        if (!_urgent) 'destination_address': _address.text.trim(),
        // Legacy Laravel requires coordinates; restaurant pickup is provisional.
        if (!_urgent) 'destination_lat': _context?['pickup_lat'],
        if (!_urgent) 'destination_lng': _context?['pickup_lng'],
        if (!_urgent) 'notes': '⚠️ موقع الخريطة هو موقع المطعم مؤقتاً وليس موقع الزبون. '
            'اتصل بالزبون للتوجيه حسب العنوان المكتوب. ${_notes.text.trim()}',
      };
      final result = await _api.requestManagerCourierV34(token, body);
      final data = result['order'];
      if (data is Map) {
        final id = int.tryParse('${data['order_id']}');
        if (id != null && mounted) setState(() => _lastOrder = id);
        // Once saved, new requests must use a NEW key. Never retry uncertain
        // dispatch as a new order; manager must inspect the saved order first.
        if (data['dispatch_confirmed'] == true) await _saveNewRequestKey();
      }
      if (!mounted) return;
      _toast('${result['message'] ?? 'تم إنشاء الطلب'}');
      await _refresh(silent: true);
      if (_lastOrder != null && mounted) {
        await Navigator.push(context,MaterialPageRoute(
            builder: (_) => ManagerCourierTrackingScreen(orderId: _lastOrder!)));
        if (mounted) await _refresh(silent: true);
      }
    } catch (e) {
      if (mounted) _toast('تعذر التأكيد: $e. لا تغيّر الطلب أو تكرره حتى تتأكد من القائمة.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text),
        duration: const Duration(seconds: 6)));
  }
  InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label, prefixIcon: Icon(icon,color:_deep),border:const OutlineInputBorder());
  Widget _feeChoice(int value) => ChoiceChip(
    label: Text('${NumberFormat('#,##0').format(value)} د.ع'),
    selected: _fee == value,
    onSelected: _sending ? null : (_) => setState(() => _fee=value),
  );
  Future<void> _openLocation() async {
    await Navigator.push(context,MaterialPageRoute(
        builder: (_) => const ManagerPickupLocationScreen()));
    if (mounted) await _refresh();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title:const Text('طلب مندوب | منصة بيتي'),
        actions: [IconButton(icon:const Icon(Icons.refresh),onPressed:()=>_refresh())]),
    body: RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Card(child:Padding(padding:const EdgeInsets.all(12),
          child:Text(_error!,style:const TextStyle(color:Colors.red)))),
      Card(color:const Color(0xFFEAF7FF),child:Padding(padding:const EdgeInsets.all(14),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${_context?['restaurant_name'] ?? 'المطعم'}',
            style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:_deep)),
        const SizedBox(height:6),
        Text('منطقة إرسال الطلب: $_zoneText',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        if (_serverAreas.length > 1) const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('إذا كان المطعم مسجلاً في أكثر من منطقة، اعتمد منطقة الاستلام '
              'من إعدادات موقع المطعم. لا يمكن إرسال منطقة عشوائية.',
              style: TextStyle(color: Colors.deepOrange)),
        ),
        if (!_courierApiAvailable || _context?['enabled'] != true)
          const Text('الإرسال غير مفعّل: لا يوجد مسار WordPress متوافق أو لم تُفعّل هذه الميزة.',
              style:TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.bold)),
        TextButton.icon(onPressed:_openLocation,icon:const Icon(Icons.place),
            label:const Text('تعديل موقع المطعم')),
      ]))),
      const SizedBox(height:14),
      SegmentedButton<bool>(segments:const [
        ButtonSegment(value:true,label:Text('مندوب مستعجل'),icon:Icon(Icons.flash_on)),
        ButtonSegment(value:false,label:Text('طلب مندوب'),icon:Icon(Icons.local_shipping)),
      ],selected:{_urgent},onSelectionChanged:_sending?null:(s)=>setState(()=>_urgent=s.first)),
      const SizedBox(height:14),
      const Text('أجرة التوصيل',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
      Wrap(spacing:8,children:[_feeChoice(1000),_feeChoice(2000),_feeChoice(3000)]),
      Form(key:_formKey,child:Column(children:[
        if (_urgent) const Card(child:Padding(padding:EdgeInsets.all(12),child:Text(
            'استدعاء للمطعم مباشرة. المندوب يحصل على اسم المطعم وموقعه وملاحظة «زبون مستعجل». '
                'تفاصيل التوصيل تُعطى عند وصوله.'))),
        if (!_urgent) ...[
          const SizedBox(height:10),
          TextFormField(controller:_name,decoration:_input('اسم الزبون (اختياري)',Icons.person)),
          const SizedBox(height:10),
          TextFormField(controller:_phone,keyboardType:TextInputType.phone,
              decoration:_input('رقم هاتف الزبون',Icons.phone),
              validator:(v)=>RegExp(r'^07\d{9}$').hasMatch((v??'').trim())?null:'أدخل رقم عراقي صحيح'),
          const SizedBox(height:10),
          TextFormField(controller:_address,decoration:_input('عنوان الزبون',Icons.location_on),
              validator:(v)=>(v??'').trim().length>=5?null:'عنوان الزبون مطلوب'),
          const SizedBox(height:10),
          const Card(child:Padding(padding:EdgeInsets.all(12), child:Text(
              'لا تحتاج كتابة إحداثيات الزبون. سيظهر عنوانه ورقمه للمندوب. '
                  'إلى حين توفير تحديد موقع الزبون من الخريطة، موقع الوجهة على الخريطة '
                  'سيكون مبدئياً عند المطعم وليس عنوان الزبون؛ على المندوب الاتصال بالزبون للتوجيه.',
              style:TextStyle(color:Colors.deepOrange)))),
          const SizedBox(height:10),
          TextFormField(controller:_notes,maxLines:2,
              decoration:_input('ملاحظات إلى المندوب',Icons.notes)),
        ],
      ])),
      const SizedBox(height:15),
      if (_unconfirmed) const Padding(padding: EdgeInsets.all(8),
          child: Text('يوجد طلب محفوظ لم يتأكد وصوله إلى السائقين. راجع الطلب قبل إنشاء طلب جديد.',
              style: TextStyle(color: Colors.deepOrange))),
      FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_green,
          minimumSize:const Size.fromHeight(52)),
          onPressed:_sending || _unconfirmed || !_courierApiAvailable || _zoneId==null || _context?['enabled']!=true?null:_submit,
          icon:Icon(_urgent?Icons.flash_on:Icons.send),
          label:Text(_sending?'جاري التأكيد...':_urgent?'طلب مندوب مستعجل':'إرسال طلب مندوب')),
      const SizedBox(height:22),
      const Text('طلبات المندوب ومتابعتها',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      if (_orders.isEmpty) const Padding(padding:EdgeInsets.all(12),
          child:Text('لا توجد طلبات جديدة من هذا النوع')),
      // كل طلب يُعرض كبطاقة مستقلة، مع أقواس واضحة وآمنة.
      ..._orders.map((o) {
        final orderId = int.tryParse('${o['order_id']}') ?? 0;
        final isUrgent = o['mode'] == 'urgent';
        return Card(
          child: ListTile(
            leading: Icon(
              isUrgent ? Icons.flash_on : Icons.local_shipping,
              color: _deep,
            ),
            title: Text('طلب السائقين #${o['delivery_order_id'] ?? 'بانتظار الرقم'} — ${restaurantOrderStatusLabel('${o['status'] ?? 'pending'}')}'),
            subtitle: Text('${o['restaurant_name']} • ${o['fee']} د.ع'),
            trailing: const Icon(Icons.chevron_left),
            onTap: orderId <= 0
                ? null
                : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManagerCourierTrackingScreen(
                    orderId: orderId,
                  ),
                ),
              );
            },
          ),
        );
      }),
    ], // ListView.children
    ), // ListView
    ), // RefreshIndicator
  ); // Scaffold
}

class ManagerCourierTrackingScreen extends StatefulWidget {
  final int orderId;
  const ManagerCourierTrackingScreen({super.key,required this.orderId});
  @override
  State<ManagerCourierTrackingScreen> createState()=>_ManagerCourierTrackingScreenState();
}
class _ManagerCourierTrackingScreenState extends State<ManagerCourierTrackingScreen>
    with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _updates;
  Map<String,dynamic>? _order;
  bool _loading=true;
  String? _error;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);
  _updates=FirebaseMessaging.onMessage.listen((msg){
    final id=msg.data['order_id']?.toString()??msg.data['source_order_id']?.toString();
    if(id=='${widget.orderId}') _refresh(silent:true);
  });
  WidgetsBinding.instance.addPostFrameCallback((_)=>_refresh());
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_updates?.cancel();super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed)_refresh(silent:true);
  }
  Future<void> _refresh({bool silent=false}) async {
    if(!mounted)return;
    if(!silent)setState((){_loading=true;_error=null;});
    try {
      final token=Provider.of<AuthProvider>(context,listen:false).token;
      if(token==null)throw Exception('يرجى تسجيل الدخول');
      final r=await ApiService().getManagerCourierStatus(token,widget.orderId);
      if(mounted)setState(()=>_order=Map<String,dynamic>.from(r['order'] as Map));
    } catch(e){if(mounted && !silent)setState(()=>_error='$e');}
    finally{if(mounted && !silent)setState(()=>_loading=false);}
  }
  Future<void> _call() async {
    final phone=(_order?['driver_phone']??'').toString();
    if(phone.isEmpty)return;
    final uri=Uri(scheme:'tel',path:phone);
    if(await canLaunchUrl(uri))await launchUrl(uri);
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text('تتبع طلب السائقين #${_order?['delivery_order_id'] ?? 'بانتظار الرقم'}'),
        actions:[IconButton(onPressed:()=>_refresh(),icon:const Icon(Icons.refresh))]),
    body:_loading?const Center(child:CircularProgressIndicator()):
    RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
      if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
      if(_order!=null)...[
        Card(color:const Color(0xFFE8F7FF),child:Padding(padding:const EdgeInsets.all(18),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('الحالة الحالية',style:TextStyle(color:Color(0xFF526A7C))),
          const SizedBox(height:6),
          Text(restaurantOrderStatusLabel('${_order!['status'] ?? 'pending'}'),style:const TextStyle(fontSize:23,
              fontWeight:FontWeight.bold,color:Color(0xFF0879B1))),
          const SizedBox(height:8),
          Text('المطعم: ${_order!['restaurant_name']}'),
          Text('منطقة المندوبين: ${beyteiZoneDescription(int.tryParse('${_order!['zone_id']}'))}'),
          if(_order!['dispatch_confirmed']!=true) const Text(
              'تم تسجيل الطلب في WordPress، لكن تأكيد وصوله لسيرفر المندوبين غير متوفر.',
              style:TextStyle(color:Colors.deepOrange)),
        ]))),
        Card(child:ListTile(
          leading:const Icon(Icons.delivery_dining,color:Colors.green),
          title:Text((_order!['driver_name']??'').toString().isEmpty
              ?'بانتظار قبول المندوب':'المندوب: ${_order!['driver_name']}'),
          subtitle:Text((_order!['driver_phone']??'').toString().isEmpty
              ?'سيظهر رقم المندوب عندما يرسله السيرفر':'هاتف: ${_order!['driver_phone']}'),
          trailing:(_order!['driver_phone']??'').toString().isEmpty?null:
          IconButton(icon:const Icon(Icons.call),onPressed:_call),
        )),
        const Card(child:Padding(padding:EdgeInsets.all(14),child:Text(
            'التحديثات تصل بإشعارات FCM، ويمكنك السحب للتحديث.\n'
                'تتبع مراحل الاستلام والتسليم يعتمد على تحديث الحالة القادم من سيرفر المندوبين.\n'
                'المحادثة داخل التطبيق تحتاج إلى ربط قناة الدردشة الحالية بهوية مدير المطعم؛ '
                'لا نفتح محادثة بهوية الزبون دون تحقق من صلاحياتها.'))),
      ],
    ])),
  );
}

// Restaurant location is set intentionally, never silently from the manager phone.
class ManagerPickupLocationScreen extends StatefulWidget {
  const ManagerPickupLocationScreen({super.key});
  @override
  State<ManagerPickupLocationScreen> createState() => _ManagerPickupLocationScreenState();
}
class _ManagerPickupLocationScreenState extends State<ManagerPickupLocationScreen> {
  final _api = ApiService();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  List<Map<String, dynamic>> _areas = [];
  int? _zone;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _lat.dispose(); _lng.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final info = await _api.getManagerContext(token);
      if (!mounted) return;
      final areas = (info['areas'] as List? ?? [])
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x)).toList();
      final savedZone = int.tryParse('${info['pickup_zone_id']}');
      setState(() {
        _lat.text = info['latitude'] == null ? '' : info['latitude'].toString();
        _lng.text = info['longitude'] == null ? '' : info['longitude'].toString();
        _areas = areas;
        _zone = areas.any((a) => int.tryParse('${a['id']}') == savedZone)
            ? savedZone : areas.length == 1 ? int.tryParse('${areas.first['id']}') : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _usePhoneLocation() async {
    setState(() { _busy = true; _error = null; });
    try {
      final allowed = await PermissionService.handleLocationPermission(context);
      if (!allowed) return;
      final position = await geolocator.Geolocator.getCurrentPosition(
          desiredAccuracy: geolocator.LocationAccuracy.high,
          timeLimit: const Duration(seconds: 20));
      if (!mounted) return;
      _lat.text = position.latitude.toStringAsFixed(7);
      _lng.text = position.longitude.toStringAsFixed(7);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('أُخذ موقع الهاتف فقط. تأكد أنك داخل المطعم قبل الضغط على حفظ.')));
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحديد موقع الهاتف: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewMap() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) return;
    final link = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(link)) await launchUrl(link, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null || lat.abs() < 0.000001 || lng.abs() < 0.000001 ||
        lat.abs() > 90 || lng.abs() > 180) {
      setState(() => _error = 'إحداثيات المطعم غير صحيحة');
      return;
    }
    if (_zone == null) {
      setState(() => _error = 'اختر منطقة الاستلام من القائمة، ثم اضغط حفظ الموقع');
      return;
    }
    final confirmed = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد موقع المطعم'),
          content: Text('هل الموقع $lat, $lng هو موقع المطعم الفعلي؟ سيتوجه إليه المندوبون.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ الموقع'))],
        ));
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      await _api.savePickupLocation(token, lat, lng, zoneId: _zone);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل حفظ الموقع: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تحديد موقع المطعم')),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(18), children: [
      const Text('حدد موقع الاستلام الحقيقي. يمكنك أخذ موقع الهاتف إذا كنت داخل المطعم، أو كتابة الإحداثيات يدوياً.'),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: _busy ? null : _usePhoneLocation,
          icon: const Icon(Icons.my_location), label: const Text('استخدام موقع الهاتف الآن')),
      const SizedBox(height: 12),
      TextField(controller: _lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'خط العرض Latitude', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'خط الطول Longitude', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _viewMap,
          icon: const Icon(Icons.map_outlined), label: const Text('معاينة الموقع على الخريطة')),
      const SizedBox(height: 12),
      if (_areas.isEmpty)
        const Card(child: ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            title: Text('لا توجد مناطق مرتبطة بهذا المطعم في WordPress'),
            subtitle: Text('يلزم ربط المطعم بمنطقة في إعدادات WordPress أولاً.')))
      else
        DropdownButtonFormField<int>(
          value: _zone,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'منطقة استلام المندوبين (اختر واحفظ مرة واحدة)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city)),
          items: _areas.map((area) {
            final id = int.tryParse('${area['id']}') ?? 0;
            return DropdownMenuItem<int>(
              value: id,
              child: Text(beyteiZoneDescription(id, _areas)),
            );
          }).toList(),
          onChanged: _busy ? null : (id) => setState(() => _zone = id),
        ),
      if (_zone == null && _areas.length > 1)
        const Padding(padding: EdgeInsets.only(top: 8),
            child: Text('اختر المنطقة التي يقع فيها المطعم، ثم اضغط حفظ الموقع. '
                'لن تُختار أول منطقة تلقائياً.',
                style: TextStyle(color: Colors.deepOrange))),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined),
          label: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ الموقع للمندوبين')),
    ]),
  );
}

class ProductManagementTab extends StatefulWidget {
  const ProductManagementTab({super.key});
  @override
  State<ProductManagementTab> createState() => _ProductManagementTabState();
}

class _ProductManagementTabState extends State<ProductManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  String _productFilter = 'all';
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _sections = [];
  int _restaurantId = 0;
  bool _isLoadingSections = true;
  String? _sectionError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// 🔥 دالة جلب معرف المطعم والأقسام التابعة له
  Future<void> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;
    if (mounted) setState(() { _isLoadingSections = true; _sectionError = null; });
    try {
      // 1. جلب معرف المطعم من الإعدادات
      final settings = await _apiService.getManagerContext(authProvider.token!);
      _restaurantId = int.tryParse(settings['id'].toString()) ?? 0;

      // 2. جلب الأقسام إذا تم العثور على معرف المطعم
      if (_restaurantId > 0) {
        final sections = await _apiService.getRestaurantSections(authProvider.token!, _restaurantId);
        if (mounted) {
          setState(() {
            _sections = sections;
            _isLoadingSections = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingSections = false);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingSections = false; _sectionError = 'فشل جلب أقسام المطعم: $e'; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToEditScreen(FoodItem product) async {
    final productProvider = Provider.of<RestaurantProductsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ملاحظة: يجب تحديث EditProductScreen لاستقبال قائمة الأقسام (sections: _sections)
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(
      product: product,
      productProvider: productProvider,
      authProvider: authProvider,
      sections: _sections,
    )));

    if (result == true) {
      _loadInitialData(); // تحديث الأقسام إذا تم التعديل
      productProvider.fetchProducts(authProvider.token);
    }
  }

  Future<void> _navigateToAddScreen() async {
    await RestaurantManagerNavigation.addMeal(context);
    if (mounted) await _loadInitialData();
  }

  Future<void> _openManageSections() async {
    await RestaurantManagerNavigation.categories(context);
    if (mounted) await _loadInitialData();
  }

  /// دالة مساعدة لجلب اسم القسم من معرفه
  String _getSectionName(int categoryId) {
    if (categoryId == 0) return 'بدون قسم';
    final section = _sections.firstWhere((s) => int.tryParse('${s['id']}') == categoryId, orElse: () => {});
    return section.isNotEmpty ? (section['name'] ?? 'بدون قسم') : 'بدون قسم';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Consumer<RestaurantProductsProvider>(
      builder: (context, provider, child) {
        List<FoodItem> displayedProducts = provider.products;
        if (_productFilter == 'offers') {
          displayedProducts = displayedProducts.where((p) => p.salePrice != null && p.salePrice! > 0).toList();
        } else if (_productFilter == 'hidden') {
          displayedProducts = displayedProducts.where((p) => p.isHidden).toList();
        }

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _navigateToAddScreen,
            backgroundColor: BeyteiManagerPalette.blue,
            foregroundColor: Colors.white,
            label: const Text('إضافة وجبة'),
            icon: const Icon(Icons.add_rounded),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 3),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن وجبة أو منتج',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: BeyteiManagerPalette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: BeyteiManagerPalette.border),
                    ),
                  ),
                  onChanged: (query) => provider.search(query),
                )),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'إدارة الأقسام',
                  icon: const Icon(Icons.category_outlined),
                  onPressed: _openManageSections,
                ),
              ]),
            ),

            Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('الكل'), selected: _productFilter == 'all',
                      onSelected: (_) => setState(() => _productFilter = 'all')),
                  ChoiceChip(label: const Text('العروض'), selected: _productFilter == 'offers',
                      onSelected: (_) => setState(() => _productFilter = 'offers')),
                  ChoiceChip(label: const Text('المخفية'), selected: _productFilter == 'hidden',
                      onSelected: (_) => setState(() => _productFilter = 'hidden')),
                ])),
            if (_isLoadingSections) const LinearProgressIndicator(),
            if (_sectionError != null) Padding(padding: const EdgeInsets.all(8), child: TextButton.icon(
                onPressed: _loadInitialData, icon: const Icon(Icons.refresh),
                label: Text(_sectionError!, style: const TextStyle(color: Colors.red)))),
            if (provider.errorMessage != null) Padding(padding: const EdgeInsets.all(8),
                child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red))),
            Expanded(child: RefreshIndicator(
              onRefresh: () async {
                await provider.fetchProducts(auth.token);
                _loadInitialData();
              },
              child: displayedProducts.isEmpty
                  ? const Center(child: Text("لا توجد منتجات"))
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80, top: 10),
                itemCount: displayedProducts.length,
                itemBuilder: (context, index) {
                  final product = displayedProducts[index];
                  final bool isOffer = product.salePrice != null && product.salePrice! > 0;
                  final String sectionName = _getSectionName(product.categoryId);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: product.imageUrl.isEmpty
                          ? Container(width: 60, height: 60, color: Colors.grey.shade100,
                          child: const Icon(Icons.fastfood_outlined))
                          : CachedNetworkImage(imageUrl: product.imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.fastfood_outlined))),
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isOffer ? "سعر العرض: ${product.salePrice} د.ع" : "السعر: ${product.price} د.ع"),
                          if(product.isHidden) const Text('مخفية عن الزبائن',style:TextStyle(color:Colors.red)),
                          const SizedBox(height: 4),
                          // 🔥 عرض اسم القسم كـ Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE6F6FD),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFB4E5F8))
                            ),
                            child: Text(
                              sectionName,
                              style: const TextStyle(fontSize: 11, color: const Color(0xFF168EC7), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected:(action) async {
                          if(action=='edit'){_navigateToEditScreen(product);return;}
                          if(action=='delete' || action=='delete-forever'){
                            final permanent=action=='delete-forever';
                            final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
                                title:Text(permanent?'حذف الوجبة نهائياً':'حذف الوجبة'),
                                content:Text(permanent?'سيتم حذف الوجبة نهائياً ولا يمكن استرجاعها. قد تبقى تفاصيلها في الطلبات القديمة. هل أنت متأكد؟':'سيتم نقل الوجبة إلى سلة المحذوفات'),
                                actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
                                  TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف'))]));
                            if(accepted!=true)return;
                          }
                          try{
                            if (action == 'hide' && product.isHidden) {
                              final draft = await ProductOptionsLocalDrafts.load(product.id);
                              if (draft != null && draft.isNotEmpty) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('لا يمكن إظهار هذه الوجبة: خياراتها محفوظة محلياً ولم تُنشر على السيرفر بعد.')));
                                return;
                              }
                            }
                            await _apiService.productAction(auth.token!,action,product.id,hidden:!product.isHidden);
                            if (action == 'delete'||action == 'delete-forever') await ProductOptionsLocalDrafts.remove(product.id);
                            await provider.fetchProducts(auth.token);
                          }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
                        },
                        itemBuilder:(_)=>[
                          const PopupMenuItem(value:'edit',child:Text('تعديل')),
                          PopupMenuItem(value:'hide',child:Text(product.isHidden?'إظهار للزبائن':'إخفاء مؤقتاً')),
                          const PopupMenuItem(value:'delete',child:Text('نقل للمحذوفات')),
                          const PopupMenuItem(value:'delete-forever',child:Text('حذف نهائي',style:TextStyle(color:Colors.red))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )),
          ]),
        );
      },
    );
  }
}
// شاشتا الإضافة والتعديل تستخدمان نفس محرر الوجبات.
class AddProductScreen extends StatelessWidget {
  final RestaurantProductsProvider productProvider;
  final AuthProvider authProvider;
  final List<Map<String, dynamic>> sections;
  const AddProductScreen({super.key, required this.productProvider,
    required this.authProvider, required this.sections});
  @override
  Widget build(BuildContext context) => ProductEditorScreen(
      productProvider: productProvider, authProvider: authProvider, sections: sections);
}

class EditProductScreen extends StatelessWidget {
  final FoodItem product;
  final RestaurantProductsProvider productProvider;
  final AuthProvider authProvider;
  final List<Map<String, dynamic>> sections;
  const EditProductScreen({super.key, required this.product,
    required this.productProvider, required this.authProvider, required this.sections});
  @override
  Widget build(BuildContext context) => ProductEditorScreen(
      product: product, productProvider: productProvider, authProvider: authProvider, sections: sections);
}

class ProductEditorScreen extends StatefulWidget {
  final FoodItem? product;
  final RestaurantProductsProvider productProvider;
  final AuthProvider authProvider;
  final List<Map<String, dynamic>> sections;
  const ProductEditorScreen({super.key, this.product, required this.productProvider,
    required this.authProvider, required this.sections});
  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _salePrice;
  bool _hoursEnabled = false;
  TimeOfDay _productOpen = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _productClose = const TimeOfDay(hour: 12, minute: 0);
  String _timeCode(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  Future<void> _editProductHour(bool start) async {
    final t=await showTimePicker(context:context,initialTime:start?_productOpen:_productClose,
        builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat:false), child:child!));
    if(t!=null && mounted)setState((){if(start){_productOpen=t;}else{_productClose=t;}});
  }
  int? _category;
  File? _image;
  bool _saving = false;
  bool _fetchingOptions = false;
  bool _localDraft = false;
  int? _createdId;
  bool _creationUncertain = false;
  List<MenuOptionGroup> _groups = [];
  bool get _isEditing => widget.product != null;
  int? get _currentId => widget.product?.id ?? _createdId;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : p.price.toStringAsFixed(0));
    _salePrice = TextEditingController(text: p?.salePrice?.toStringAsFixed(0) ?? '');
    if(p!=null && p.availabilityStart.isNotEmpty && p.availabilityEnd.isNotEmpty){
      _hoursEnabled=true;
      TimeOfDay parseHour(String x, TimeOfDay fallback){
        final parts=x.split(':'); if(parts.length!=2)return fallback;
        final h=int.tryParse(parts[0]);final m=int.tryParse(parts[1]);
        if(h==null||m==null||h<0||h>23||m<0||m>59)return fallback;
        return TimeOfDay(hour:h,minute:m);
      }
      _productOpen=parseHour(p.availabilityStart,_productOpen);
      _productClose=parseHour(p.availabilityEnd,_productClose);
    }
    _category = widget.sections.any((s) => int.tryParse('${s['id']}') == p?.categoryId)
        ? p!.categoryId : null;
    if (p != null) _loadOptions(p.id);
  }
  @override
  void dispose() {
    _name.dispose(); _description.dispose(); _price.dispose(); _salePrice.dispose();
    super.dispose();
  }

  Future<void> _loadOptions(int productId) async {
    setState(() => _fetchingOptions = true);
    try {
      final local = await ProductOptionsLocalDrafts.load(productId);
      // مسودة الجهاز لها الأولوية حتى لا تضيع الإضافات غير المنشورة.
      if (local != null) {
        if (mounted) setState(() { _groups = local; _localDraft = true; });
        return;
      }
      final token = widget.authProvider.token;
      if (token == null) return;
      final remote = await _api.fetchProductOptions(token, productId);
      if (remote != null && mounted) setState(() { _groups = remote; _localDraft = false; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل خيارات المنتج: $e')));
    } finally {
      if (mounted) setState(() => _fetchingOptions = false);
    }
  }
  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 72,
          maxWidth: 1200, maxHeight: 1200);
      if (file != null && mounted) setState(() => _image = File(file.path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر اختيار الصورة: $e')));
    }
  }
  Future<void> _editGroup({int? index}) async {
    final group = await Navigator.push<MenuOptionGroup>(context, MaterialPageRoute(
        builder: (_) => MenuOptionGroupEditor(initial: index == null ? null : _groups[index])));
    if (group == null || !mounted) return;
    setState(() {
      if (index == null) { _groups.add(group); } else { _groups[index] = group; }
      _localDraft = true;
    });
  }
  void _addPreset(String kind) {
    final group = kind == 'weight' ? menuPresetWeights()
        : kind == 'sauces' ? menuPresetSauces() : menuPresetOnion();
    if (_groups.any((g) => g.name == group.name)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('مجموعة «${group.name}» موجودة. اضغط عليها لتعديلها.')));
      return;
    }
    setState(() { _groups.add(group); _localDraft = true; });
  }
  String _groupSubtitle(MenuOptionGroup group) {
    final requirement = group.requiredChoice ? 'إجباري' : 'اختياري';
    final choiceType = group.multiSelect ? 'متعدد حتى ${group.maximum}' : 'اختيار واحد';
    return '$requirement - $choiceType - ${group.choices.length} خيارات';
  }

  String? _validateMoney(String? text, {bool allowEmpty = false}) {
    final raw = (text ?? '').trim();
    if (raw.isEmpty && allowEmpty) return null;
    final number = double.tryParse(raw);
    if (number == null || number <= 0) return 'أدخل سعراً موجباً صحيحاً';
    return null;
  }
  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_creationUncertain && _currentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تحقق من قائمة الوجبات قبل إعادة الإضافة؛ قد يكون السيرفر حفظ الوجبة بالفعل.')));
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر قسماً للوجبة')));
      return;
    }
    final original = double.parse(_price.text.trim());
    final sale = _salePrice.text.trim();
    if (sale.isNotEmpty && double.parse(sale) >= original) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سعر الخصم يجب أن يكون أقل من السعر الأصلي')));
      return;
    }
    if(_hoursEnabled && _timeCode(_productOpen)==_timeCode(_productClose)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('وقت بداية ونهاية توفر الوجبة لا يمكن أن يتساويا')));return;
    }
    // لا تُعرض خيارات غير مدعومة في التطبيق كأنها منشورة للزبائن.
    final token = widget.authProvider.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول مرة أخرى')));
      return;
    }
    setState(() => _saving = true);
    try {
      final productId = _currentId;
      int id;
      if (productId == null) {
        _creationUncertain = true;
        id = await _api.createProductWithId(token: token, name: _name.text.trim(),
            price: _price.text.trim(), salePrice: sale.isEmpty ? null : sale,
            description: _description.text.trim(), image: _image,
            categoryId: _category!,
            availabilityStart:_hoursEnabled?_timeCode(_productOpen):'',
            availabilityEnd:_hoursEnabled?_timeCode(_productClose):'');
        _createdId = id; // يمنع تكرار الوجبة عند إعادة محاولة حفظ الخيارات.
        _creationUncertain = false;
      } else {
        id = productId;
        await _api.updateProductFull(token: token, productId: id,
            name: _name.text.trim(), price: _price.text.trim(),
            salePrice: sale, description: _description.text.trim(),
            image: _image, categoryId: _category!,
            availabilityStart:_hoursEnabled?_timeCode(_productOpen):'',
            availabilityEnd:_hoursEnabled?_timeCode(_productClose):'');
      }

      bool optionsOnline = true;
      if (_groups.isNotEmpty || _localDraft) {
        try {
          await _api.saveProductOptions(token, id, _groups);
          await ProductOptionsLocalDrafts.remove(id);
          _localDraft = false;
        } on ServerOptionsNotReady {
          optionsOnline = false;
          await ProductOptionsLocalDrafts.save(id, _groups);
        } catch (_) {
          optionsOnline = false;
          await ProductOptionsLocalDrafts.save(id, _groups);
        }
      }
      if (_groups.isNotEmpty && !optionsOnline) {
        bool hidden = false;
        try {
          await _api.productAction(token, 'hide', id, hidden: true);
          hidden = true;
        } catch (_) {}
        if (!mounted) return;
        if (!hidden) {
          await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('تنبيه مهم بشأن النشر'),
            content: const Text('تم حفظ بيانات الوجبة الأساسية، لكن السيرفر لم يحفظ خيارات الأوزان والإضافات ولم يؤكد إخفاء الوجبة. قد تظهر للزبون بدون الخيارات. أخفِها من لوحة المنتجات قبل استقبال طلبات جديدة.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('فهمت'))],
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('حُفظت الوجبة مخفية، والخيارات كمسودة محلية إلى حين تحديث السيرفر.')));
        }
      }
      await widget.productProvider.fetchProducts(token);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 7), content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _productImage() => InkWell(onTap: _saving ? null : _pickImage,
      borderRadius: BorderRadius.circular(18), child: Container(
        height: 165, width: double.infinity, decoration: BoxDecoration(
          color: const Color(0xFFEFF5F1), borderRadius: BorderRadius.circular(18)),
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: _image != null
            ? Image.file(_image!, fit: BoxFit.cover)
            : widget.product != null && widget.product!.imageUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.product!.imageUrl, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const Icon(Icons.add_a_photo_outlined, size: 48))
            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo_outlined, size: 45, color: const Color(0xFF168EC7)),
          SizedBox(height: 8), Text('اضغط لإضافة صورة (اختياري)'),
        ])),
      ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_isEditing ? 'تعديل الوجبة' : 'إضافة وجبة')),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      _productImage(), const SizedBox(height: 18),
      const Text('بيانات الوجبة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الوجبة'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'اسم الوجبة مطلوب' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _description, maxLines: 3,
          decoration: const InputDecoration(labelText: 'وصف الوجبة والمكونات')),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(value: _category,
          isExpanded: true, decoration: const InputDecoration(labelText: 'القسم'),
          items: widget.sections.map((section) => DropdownMenuItem<int>(
              value: int.tryParse('${section['id']}'),
              child: Text('${section['icon'] ?? '🍽️'}  ${section['name']}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _saving ? null : (v) => setState(() => _category = v),
          validator: (v) => v == null ? 'اختر القسم' : null),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextFormField(controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'السعر الأساسي (د.ع)'),
            validator: (v) => _validateMoney(v))),
        const SizedBox(width: 10),
        Expanded(child: TextFormField(controller: _salePrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'سعر الخصم'),
            validator: (v) => _validateMoney(v, allowEmpty: true))),
      ]),
      const SizedBox(height: 20),
      SwitchListTile(
          title:const Text('وقت محدد لتوفر الوجبة'),
          subtitle:const Text('مثلاً من 7:00 صباحاً إلى 12:00 ظهراً؛ يتوقف طلبها تلقائياً خارج الوقت'),
          value:_hoursEnabled,onChanged:_saving?null:(v)=>setState(()=>_hoursEnabled=v)),
      if(_hoursEnabled)Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:()=>_editProductHour(true),
            icon:const Icon(Icons.schedule),label:Text('من ${beyteiManagerTime12(_timeCode(_productOpen))}'))),
        const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(onPressed:()=>_editProductHour(false),
            icon:const Icon(Icons.schedule),label:Text('إلى ${beyteiManagerTime12(_timeCode(_productClose))}'))),
      ]),
      const SizedBox(height: 28),
      const Text('الخيارات والأوزان والإضافات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('عند تفعيل مجموعة الأوزان يصبح السعر الأساسي هو سعر الكيلو، وتُحسب الربع والنصف تلقائياً مرة واحدة. أي زيادة تضعها على الخيار تُضاف بعد حساب الوزن. الصلصات تُضاف منفصلة.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 6, children: [
        ActionChip(avatar: const Icon(Icons.scale), label: const Text('أوزان'), onPressed: () => _addPreset('weight')),
        ActionChip(avatar: const Icon(Icons.water_drop_outlined), label: const Text('صلصات'), onPressed: () => _addPreset('sauces')),
        ActionChip(avatar: const Icon(Icons.tune), label: const Text('تعديل البصل'), onPressed: () => _addPreset('onion')),
        ActionChip(avatar: const Icon(Icons.add), label: const Text('مجموعة أخرى'), onPressed: () => _editGroup()),
      ]),
      const SizedBox(height: 12),
      if (_fetchingOptions) const LinearProgressIndicator(),
      ..._groups.asMap().entries.map((entry) => Card(child: ListTile(
        title: Text(entry.value.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_groupSubtitle(entry.value)),
        leading: const Icon(Icons.tune), onTap: () => _editGroup(index: entry.key),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() {
          _groups.removeAt(entry.key); _localDraft = true;
        })),
      ))),
      if (_groups.isNotEmpty) Container(
        padding: const EdgeInsets.all(12), decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), color: Colors.amber.withOpacity(0.13)),
        child: const Text('تنبيه: لن تظهر هذه الخيارات للزبائن حتى يؤكد السيرفر حفظها. '
            'إذا لم يدعم السيرفر الخيارات بعد، تُحفظ مسودة على هذا الجهاز ونحاول إخفاء الوجبة تلقائياً لمنع بيعها بدون الخيارات.'),
      ),
      const SizedBox(height: 28),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_saving ? 'جارٍ الحفظ...' : (_isEditing ? 'حفظ التغييرات' : 'إضافة الوجبة')))),
      const SizedBox(height: 30),
    ])),
  );
}


class OrdersListScreen extends StatefulWidget {
  final String status;
  const OrdersListScreen({super.key, required this.status});
  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.isLoading && (dashboard.orders[widget.status] == null || dashboard.orders[widget.status]!.isEmpty))
          return const Center(child: CircularProgressIndicator());
        final orders = dashboard.orders[widget.status] ?? [];
        final pickupCodes = dashboard.pickupCodes;
        return RefreshIndicator(
          onRefresh: () => dashboard.fetchDashboardData(authProvider.token),
          child: orders.isEmpty
              ? Center(child: Text('لا توجد طلبات'))
              : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final code = pickupCodes[order.id];
              return OrderCard(order: order, onStatusChanged: () => dashboard.fetchDashboardData(authProvider.token), isCompleted: widget.status != 'active', pickupCode: code);
            },
          ),
        );
      },
    );
  }
}

class RatingsDashboardScreen extends StatefulWidget {
  const RatingsDashboardScreen({super.key});
  @override
  State<RatingsDashboardScreen> createState() => _RatingsDashboardScreenState();
}

class _RatingsDashboardScreenState extends State<RatingsDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Consumer<DashboardProvider>(
      builder: (context, dashboard, child) {
        if (dashboard.ratingsDashboard == null && dashboard.ratingsLoadError != null) {
          return Center(child: Padding(padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('تعذّر جلب التقييمات من السيرفر.'),
                const SizedBox(height: 8),
                Text(dashboard.ratingsLoadError!, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                TextButton(onPressed: () => dashboard.fetchDashboardData(authProvider.token),
                    child: const Text('إعادة المحاولة')),
              ])));
        }
        if (dashboard.ratingsDashboard == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = dashboard.ratingsDashboard!;
        return RefreshIndicator(
          onRefresh: () => dashboard.fetchDashboardData(authProvider.token),
          child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(children: [
                          Expanded(child: Column(children: [
                            Text(data.averageRating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 33,
                                    fontWeight: FontWeight.bold,
                                    color: BeyteiManagerPalette.blue)),
                            RatingBarIndicator(
                                rating: data.averageRating,
                                itemBuilder: (context, index) =>
                                const Icon(Icons.star_rounded, color: Colors.amber),
                                itemCount: 5, itemSize: 19),
                          ])),
                          Container(height: 56, width: 1,
                              color: BeyteiManagerPalette.border),
                          Expanded(child: Column(children: [
                            Text(data.totalReviews.toString(),
                                style: const TextStyle(fontSize: 33,
                                    fontWeight: FontWeight.bold,
                                    color: BeyteiManagerPalette.green)),
                            const Text('إجمالي التقييمات', maxLines: 1,
                                style: TextStyle(fontSize: 12)),
                          ])),
                        ])
                    )
                ),
                const SizedBox(height: 24),
                const Text("آخر التقييمات", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ...data.recentReviews.map((review) => ReviewCard(review: review)),
              ]
          ),
        );
      },
    );
  }
}

// BEYTEI V20: per-weekday windows. Saves 24-hour values, displays 12-hour Arabic.
class BeyteiWeeklyHoursScreen extends StatefulWidget {
  final String fallbackStart, fallbackEnd;
  const BeyteiWeeklyHoursScreen({super.key,required this.fallbackStart,required this.fallbackEnd});
  @override State<BeyteiWeeklyHoursScreen> createState()=>_BeyteiWeeklyHoursScreenState();
}
class _BeyteiWeeklyHoursScreenState extends State<BeyteiWeeklyHoursScreen> {
  static const _keys=['sun','mon','tue','wed','thu','fri','sat'];
  static const _names=['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
  Map<String,List<Map<String,String>>> _days={};
  bool _busy=false,_loading=true;
  String? _error;
  @override void initState(){super.initState();_load();}
  String _time(TimeOfDay t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  TimeOfDay _decode(String s){
    final p=s.split(':');
    final h=p.isNotEmpty?int.tryParse(p[0]):null;
    final m=p.length>1?int.tryParse(p[1]):null;
    return TimeOfDay(hour:h!=null&&h>=0&&h<24?h:8,minute:m!=null&&m>=0&&m<60?m:0);
  }
  Future<void> _load() async {
    try{
      final token=Provider.of<AuthProvider>(context,listen:false).token!;
      final r=await ApiService().fetchWeeklySchedule(token);
      final saved=r['days'];
      final days=<String,List<Map<String,String>>>{};
      for(final day in _keys){
        final raw=saved is Map?saved[day]:null;
        days[day]=raw is List?raw.whereType<Map>().map((w)=>{
          'start':(w['start']??'08:00').toString(),
          'end':(w['end']??'13:00').toString()}).toList():[
          {'start':widget.fallbackStart,'end':widget.fallbackEnd}];
      }
      if(mounted)setState((){_days=days;_loading=false;});
    }catch(e){if(mounted)setState((){_error='$e';_loading=false;});}
  }
  Future<void> _pick(String day,int index,String field) async {
    final current=_decode(_days[day]![index][field]!);
    final picked=await showTimePicker(context:context,initialTime:current,
        helpText:'اختر الوقت',
        builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat:false),child:child!));
    if(picked!=null && mounted)setState(()=>_days[day]![index][field]=_time(picked));
  }
  Future<void> _save() async {
    for(final day in _keys){
      for(final span in _days[day]??[]){
        if(span['start']==span['end']){
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('وقت الفتح لا يمكن أن يساوي وقت الإغلاق')));return;
        }
      }
    }
    setState(()=>_busy=true);
    try{
      final token=Provider.of<AuthProvider>(context,listen:false).token!;
      await ApiService().saveWeeklySchedule(token,_days);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ جدول الأسبوع. يعمل عند تفعيل الفتح التلقائي.')));
      Navigator.pop(context,true);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشل الحفظ: $e')));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
      appBar:AppBar(title:const Text('جدول عمل المطعم الأسبوعي')),
      body:_loading?const Center(child:CircularProgressIndicator()):_error!=null
          ?Center(child:Text('تعذر تحميل الجدول: $_error'))
          :ListView(padding:const EdgeInsets.all(12),children:[
        const Text('اختر أيام العمل. لكل يوم يمكنك إضافة فترتين أو ثلاث فترات، وتدعم الأوقات حتى بعد منتصف الليل.',
            style:TextStyle(fontWeight:FontWeight.w500)),
        const SizedBox(height:10),
        for(var i=0;i<_keys.length;i++) Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          SwitchListTile(title:Text(_names[i],style:const TextStyle(fontWeight:FontWeight.bold)),
              subtitle:Text((_days[_keys[i]]??[]).isEmpty?'مغلق طوال اليوم':'${_days[_keys[i]]!.length} فترة'),
              value:(_days[_keys[i]]??[]).isNotEmpty,
              onChanged:_busy?null:(v)=>setState(()=>_days[_keys[i]]=v
                  ?[{'start':'08:00','end':'13:00'}]:[])),
          for(var n=0;n<(_days[_keys[i]]??[]).length;n++)
            Row(children:[
              Expanded(child:TextButton(onPressed:_busy?null:()=>_pick(_keys[i],n,'start'),
                  child:Text('من ${beyteiManagerTime12(_days[_keys[i]]![n]['start']!)}'))),
              Expanded(child:TextButton(onPressed:_busy?null:()=>_pick(_keys[i],n,'end'),
                  child:Text('إلى ${beyteiManagerTime12(_days[_keys[i]]![n]['end']!)}'))),
              IconButton(onPressed:_busy?null:()=>setState(()=>_days[_keys[i]]!.removeAt(n)),
                  icon:const Icon(Icons.remove_circle_outline,color:Colors.red)),
            ]),
          if((_days[_keys[i]]??[]).isNotEmpty&&_days[_keys[i]]!.length<3)
            TextButton.icon(onPressed:_busy?null:()=>setState(()=>_days[_keys[i]]!.add(
                {'start':'16:00','end':'01:00'})),icon:const Icon(Icons.add),label:const Text('إضافة فترة أخرى')),
        ]))),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:_busy?null:_save,icon:const Icon(Icons.save),
            label:Text(_busy?'جارٍ الحفظ...':'حفظ جدول الأسبوع')),
        const SizedBox(height:30),
      ]));
}

class RestaurantSettingsScreen extends StatefulWidget {
  const RestaurantSettingsScreen({super.key});
  @override
  State<RestaurantSettingsScreen> createState() => _RestaurantSettingsScreenState();
}
class _RestaurantSettingsScreenState extends State<RestaurantSettingsScreen> {
  bool _savingHours = false;

  TimeOfDay _parse(String text) {
    final pieces = text.split(':');
    final hour = pieces.isNotEmpty ? int.tryParse(pieces.first) : null;
    final minute = pieces.length > 1 ? int.tryParse(pieces[1]) : null;
    return TimeOfDay(hour: hour != null && hour >= 0 && hour < 24 ? hour : 9,
        minute: minute != null && minute >= 0 && minute < 60 ? minute : 0);
  }
  String _encode(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _setHours(RestaurantSettingsProvider settings) async {
    final open = await showTimePicker(context: context, initialTime: _parse(settings.openTime),
        helpText: 'وقت افتتاح المطعم',
        builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat:false),child:child!));
    if (open == null || !mounted) return;
    final close = await showTimePicker(context: context, initialTime: _parse(settings.closeTime),
        helpText: 'وقت إغلاق المطعم',
        builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat:false),child:child!));
    if (close == null || !mounted) return;
    if (open.hour == close.hour && open.minute == close.minute) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وقت الفتح والإغلاق لا يمكن أن يكونا متساويين')));
      return;
    }
    setState(() => _savingHours = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final ok = await settings.updateAutoTimes(token, _encode(open), _encode(close));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'تم حفظ مواعيد العمل' : settings.error ?? 'لم يحفظ السيرفر المواعيد')));
      if (ok) await settings.fetchSettings(token);
    } finally {
      if (mounted) setState(() => _savingHours = false);
    }
  }
  Future<void> _setStatus(RestaurantSettingsProvider settings, String mode, bool open) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final ok = await settings.updateRestaurantStatus(token, mode, open);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok
        ? 'تم تحديث إعدادات المطعم' : settings.error ?? 'تعذّر التحديث')));
    if (ok) await settings.fetchSettings(token);
  }
  @override
  Widget build(BuildContext context) => Consumer<RestaurantSettingsProvider>(builder: (context, settings, _) {
    if (settings.isLoading && !settings.loaded) return const Center(child: CircularProgressIndicator());
    if (!settings.loaded) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(settings.error ?? 'تعذّر جلب الإعدادات'),
      TextButton(onPressed: () => settings.fetchSettings(
          Provider.of<AuthProvider>(context, listen: false).token), child: const Text('إعادة المحاولة')),
    ]));
    final auto = settings.operationMode == 'auto';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        const ListTile(title: Text('طريقة استقبال الطلبات'),
            subtitle: Text('يدوي: تفتح أو تغلق المطعم بنفسك. تلقائي: حسب جدول المطعم.')),
        SwitchListTile(title: const Text('الفتح والإغلاق تلقائياً'),
            value: auto, onChanged: (v) => _setStatus(settings, v ? 'auto' : 'manual', settings.isRestaurantOpen)),
        if (!auto) SwitchListTile(title: Text(settings.isRestaurantOpen ? 'المطعم مفتوح' : 'المطعم مغلق'),
            value: settings.isRestaurantOpen, onChanged: (v) => _setStatus(settings, 'manual', v)),
      ]))),
      const SizedBox(height: 14),
      Card(child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: const Text('موقع المطعم للمندوبين'),
        subtitle: const Text('تحديد موقع الاستلام والمنطقة بدقة مرة واحدة'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ManagerPickupLocationScreen())),
      )),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        const ListTile(title: Text('أوقات العمل اليومية'), leading: Icon(Icons.access_time)),
        ListTile(title: const Text('وقت الفتح'), trailing: Text(beyteiManagerTime12(settings.openTime))),
        ListTile(title: const Text('وقت الإغلاق'), trailing: Text(beyteiManagerTime12(settings.closeTime))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _savingHours ? null : () => _setHours(settings),
            icon: const Icon(Icons.edit_calendar), label: Text(_savingHours ? 'جارٍ الحفظ...' : 'تعديل أوقات العمل القديمة'))),
        const SizedBox(height:10),
        FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>BeyteiWeeklyHoursScreen(fallbackStart:settings.openTime, fallbackEnd:settings.closeTime))),
            icon:const Icon(Icons.calendar_month),label:const Text('جدول أسبوعي: فترتان أو أكثر لكل يوم')),
      ]))),
      const SizedBox(height: 10),
      const Padding(padding: EdgeInsets.all(10), child: Text(
          'عند الإيقاف اليدوي يبقى المطعم مغلقاً حتى تعيد فتحه. الإيقاف بالدقائق يحتاج مساراً جديداً في السيرفر. الجدول اليومي يدعم المواعيد التي تتجاوز منتصف الليل في الكود الحالي، ويجب اختباره عملياً.')),
    ]);
  });
}


class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;
  final ApiService _api = ApiService();
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final data = await _api.getWalletData(token);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  double? _number(dynamic raw) => raw == null ? null : double.tryParse(raw.toString());
  Widget _tile(String title, double? amount, IconData icon) => Card(
      child: ListTile(leading: Icon(icon, color: const Color(0xFF168EC7)), title: Text(title),
          subtitle: Text(amount == null ? 'غير متاح من السيرفر'
              : '${NumberFormat('#,##0.##').format(amount)} د.ع',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19))));

  @override
  Widget build(BuildContext context) {
    final balance = _number(_data?['wallet_balance']);
    final sales = _number(_data?['total_earnings']);
    final liability = _number(_data?['liability']);
    return Scaffold(appBar: AppBar(title: const Text('المحفظة والحسابات'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(20),
          child: Text('تعذر قراءة بيانات المحفظة: $_error', textAlign: TextAlign.center)))
          : ListView(padding: const EdgeInsets.all(16), children: [
        _tile('إجمالي المبيعات كما يقدمه السيرفر', sales, Icons.storefront),
        _tile('الرصيد الحالي', balance, Icons.account_balance_wallet),
        if (liability != null && liability > 0)
          _tile('مستحقات للمنصة', liability, Icons.warning_amber_outlined),
        const SizedBox(height: 12),
        const Text('الرصيد وإجمالي المبيعات لا يعادلان صافي الربح. '
            'يتطلب صافي الربح خصم العمولات والاسترجاعات والتكاليف وفق بيانات السيرفر.'),
      ]),
    );
  }
}


/// Customer-facing total for completed order details only, NOT restaurant net sales.
/// Laravel's current receiveOrder calculates final_total without delivery_fee.
/// Missing values are not fabricated: return null if no usable amount exists.
num? beyteiCompleteOrderAmount(Map<String, dynamic> order) {
  num? n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');
  final beforeDelivery = n(order['final_total']) ?? n(order['order_total']);
  if (beforeDelivery == null) return null;
  return beforeDelivery + (n(order['delivery_fee']) ?? 0);
}

String restaurantOrderStatusLabel(String value) {
  const names = <String, String>{
    'pending': 'بانتظار الدفع', 'processing': 'قيد التحضير',
    'on-hold': 'معلق', 'completed': 'مكتمل', 'cancelled': 'ملغى',
    'refunded': 'مسترجع', 'failed': 'فشل',
    'picked_up': 'استلمه المندوب', 'out-for-delivery': 'في الطريق',
    'delivered': 'تم التوصيل',
    'accepted': 'قبله المندوب', 'at_store': 'وصل المندوب للمطعم',
    'driver-assigned': 'تم تعيين المندوب', 'out_for_delivery': 'في طريق التوصيل',
  };
  return names[value.toLowerCase()] ?? value;
}

// =======================================================================
// 🔷 القسم 8: الويدجتات (Widgets)
// =======================================================================

class OrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback onStatusChanged;
  final bool isCompleted;
  final String? pickupCode;
  const OrderCard({super.key, required this.order, required this.onStatusChanged, this.isCompleted = false, this.pickupCode});
  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _isNotifyingDriver = false;

  Future<void> _notifyDriverReady() async {
    setState(() => _isNotifyingDriver = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('انتهت جلسة الدخول');
      await ApiService().notifyDriverOrderReady(widget.order.id, token);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إشعار المندوب"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isNotifyingDriver = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd • hh:mm a'); // no uninitialized ar locale
    final orderDate = widget.isCompleted
        ? (widget.order.dateCompleted ?? widget.order.dateCreated)
        : widget.order.dateCreated;
    final formattedDate = orderDate.year >= 2000
        ? formatter.format(orderDate.toLocal()) : 'تاريخ غير متاح';
    bool isFinished = ['completed', 'cancelled', 'refunded', 'failed', 'delivered'].contains(widget.order.status.toLowerCase());
    bool hasDriver = widget.order.driverName != null && widget.order.driverName!.isNotEmpty;

    return Card(
      elevation: 3, margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFF159FD9), borderRadius: BorderRadius.circular(8)),
                          child: Text(widget.order.driverOrderId == null
                              ? "الرقم غير متاح" : "#${widget.order.driverOrderId}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      ),
                      Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]
                ),
                const SizedBox(height: 8),
                Text('حالة الطلب: ${restaurantOrderStatusLabel(widget.order.status)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF168EC7))),
                if (widget.isCompleted && widget.order.dateCompleted != null)
                  Text('تاريخ الإنهاء: $formattedDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 25),
                Text("الزبون: ${widget.order.customerName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("العنوان: ${widget.order.address}", style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 15),
                Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.order.lineItems.map((item) => Padding(
                            padding:const EdgeInsets.symmetric(vertical:4),
                            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                              Text('• ${item.quantity} × ${item.name}',style:const TextStyle(fontWeight:FontWeight.w600)),
                              if(item.optionsSummary.isNotEmpty)Text(item.optionsSummary,
                                  style:const TextStyle(fontSize:12,color:Colors.blueGrey)),
                              if(item.note.isNotEmpty && item.note!=item.optionsSummary)Text('ملاحظة: ${item.note}',
                                  style:const TextStyle(fontSize:12,color:Colors.deepOrange)),
                            ]))).toList()
                    )
                ),
                if (widget.order.notes.trim().isNotEmpty) Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('ملاحظات الطلب: ${widget.order.notes}',
                      style: const TextStyle(color: Color(0xFF8A6018), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("قيمة الوجبات:"),
                      Text("${widget.order.total} د.ع", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))
                    ]
                ),
                if (!isFinished && widget.order.id > 0 && hasDriver && !['picked_up', 'out-for-delivery', 'delivered'].contains(widget.order.status.toLowerCase())) ...[
                  const SizedBox(height: 15),
                  SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton.icon(
                          onPressed: _isNotifyingDriver ? null : _notifyDriverReady,
                          icon: const Icon(Icons.notifications_active),
                          label: Text(_isNotifyingDriver ? "جاري الإرسال..." : "تم تجهيز الطلب - إشعار المندوب")
                      )
                  ),
                ],
                if (widget.pickupCode != null && !isFinished)
                  Container(
                      margin: const EdgeInsets.only(top: 10), width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text("كود التسليم: ${widget.pickupCode}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))
                  ),
              ]
          )
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Review review;
  const ReviewCard({super.key, required this.review});
  @override
  Widget build(BuildContext context) {
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(review.productName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        RatingBarIndicator(rating: review.rating.toDouble(), itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 16.0)
                      ]
                  ),
                  const Divider(),
                  Text(review.content.isEmpty ? "لا يوجد تعليق." : review.content),
                  Align(alignment: Alignment.bottomLeft, child: Text("${review.author} - ${DateFormat('yyyy/MM/dd').format(review.date)}", style: const TextStyle(fontSize: 12, color: Colors.grey))),
                ]
            )
        )
    );
  }
}

// =======================================================================
// 🔷 القسم 9: نقطة الدخول (Main)
// =======================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(restaurantFirebaseBackground);
    await RestaurantNotificationService.initialize();
    print('✅ Firebase والإشعارات مهيأة');
  } catch (e) {
    print("⚠️ Firebase initialization failed: $e");
    // Continue without Firebase if it fails
  }

  runApp(const RestaurantManagerApp());
}

class RestaurantManagerApp extends StatelessWidget {
  const RestaurantManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. مزود المصادقة الأساسي
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        ChangeNotifierProvider(create: (_) => RestaurantSettingsProvider()),
        ChangeNotifierProvider(create: (_) => RestaurantProductsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),

      ],
      child: MaterialApp(
        title: 'منصة بيتي | مدير المطعم',
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: BeyteiManagerPalette.blue, brightness: Brightness.light),
            scaffoldBackgroundColor: BeyteiManagerPalette.background,
            useMaterial3: true,
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: BeyteiManagerPalette.border),
              ),
            ),
            fontFamily: 'Tajawal',
            appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white, elevation: 0.5,
                iconTheme: IconThemeData(color: Colors.black),
                titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
            )
        ),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => Directionality(
            textDirection: ui.TextDirection.rtl, child: child ?? const SizedBox.shrink()),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (auth.isLoggedIn && auth.userRole == 'owner') {
          return const RestaurantDashboardScreen();
        }
        return const RestaurantLoginScreen();
      },
    );
  }
}

