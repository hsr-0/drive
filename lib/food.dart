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
  final String? driverName;
  final String? driverPhone;

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
    this.driverName,
    this.driverPhone,
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
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
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
    return _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/dashboard-ratings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return RestaurantRatingsDashboard.fromJson(json.decode(response.body));
      throw Exception('Failed to load dashboard ratings');
    });
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

  Future<Map<String,dynamic>> requestManualDriver(String token, Map<String,dynamic> payload) async {
    final r=await http.post(Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/manager-request-driver'),
        headers:{'Authorization':'Bearer $token','Content-Type':'application/json'},body:json.encode(payload)).timeout(const Duration(seconds:45));
    if(r.statusCode!=200) throw Exception(_apiError(r));
    return Map<String,dynamic>.from(json.decode(r.body));
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
      if (message.data['type'] != 'new_order') return;
      final id = int.tryParse('${message.data['order_id']}') ?? 0;
      try {
        await _local.show(
          id > 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000,
          message.notification?.title ?? message.data['title'] ?? 'طلب جديد',
          message.notification?.body ?? message.data['body'] ?? 'وصل طلب جديد إلى المطعم',
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
class UnifiedOrdersScreen extends StatefulWidget {
  const UnifiedOrdersScreen({super.key});

  @override
  State<UnifiedOrdersScreen> createState() => _UnifiedOrdersScreenState();
}

class _UnifiedOrdersScreenState extends State<UnifiedOrdersScreen> {
  Map<String, dynamic>? _today;
  Map<String, dynamic>? _month;
  Map<String, dynamic>? _all;
  String? _financialError;
  bool _financialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFinancialSummary());
  }

  Future<void> _loadFinancialSummary() async {
    if (!mounted) return;
    setState(() { _financialLoading = true; _financialError = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final results = await Future.wait([
        ApiService().fetchManagerAnalytics(token, 'today'),
        ApiService().fetchManagerAnalytics(token, 'month'),
        ApiService().fetchManagerAnalytics(token, 'all'),
      ]);
      if (!mounted) return;
      if (results.any((x) => x == null || x['complete'] != true)) {
        throw Exception('سيرفر الإحصائيات غير محدّث أو التقرير غير مكتمل');
      }
      setState(() { _today = results[0]; _month = results[1]; _all = results[2]; });
    } catch (e) {
      if (mounted) setState(() { _financialError = '$e'; _today = null; _month = null; _all = null; });
    } finally {
      if (mounted) setState(() => _financialLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    return Consumer<DashboardProvider>(builder: (context, dashboard, _) {
      final active = dashboard.orders['active'] ?? [];
      final finished = dashboard.orders['completed'] ?? [];
      if (dashboard.isLoading && dashboard.orders.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const RestaurantQuickPanel(),
          if (dashboard.orderLoadError != null) Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('تعذر تحديث قائمة الطلبات من السيرفر: ${dashboard.orderLoadError}. آخر بيانات محفوظة ما زالت معروضة.',
                  style: const TextStyle(color: Colors.deepOrange)))),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('📊 ملخص المبيعات الفعلي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal))),
            TextButton.icon(onPressed: () => _viewOrders(),
                icon: const Icon(Icons.receipt_long), label: const Text('مشاهدة الطلبات')),
          ]),
          const Text('الأرقام من السيرفر بحسب تاريخ اكتمال الطلب، دون أجور التوصيل. صافي المبيعات بعد الاسترجاع.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          if (_financialLoading) const LinearProgressIndicator(),
          if (_financialError != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('تعذر تحميل الملخص الدقيق: $_financialError',
                  style: const TextStyle(color: Colors.deepOrange))),
          const SizedBox(height: 12),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, childAspectRatio: 1.4,
              crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
                _stat('مكتملة اليوم', _num(_today, 'completed_orders'), Icons.today, Colors.blue),
                _stat('صافي مبيعات اليوم', _num(_today, 'net_sales', money: true), Icons.attach_money, Colors.green),
                _stat('مكتملة الشهر', _num(_month, 'completed_orders'), Icons.calendar_month, Colors.orange),
                _stat('صافي مبيعات الشهر', _num(_month, 'net_sales', money: true), Icons.trending_up, Colors.purple),
                _stat('جميع المكتملة', _num(_all, 'completed_orders'), Icons.receipt_long, Colors.blueGrey),
                _stat('جميع المبيعات الصافية', _num(_all, 'net_sales', money: true), Icons.account_balance_wallet, Colors.teal),
              ]),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _financialLoading ? null : _loadFinancialSummary,
              icon: const Icon(Icons.refresh), label: const Text('تحديث ملخص المبيعات')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('🔔 الطلبات الجارية (${active.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            TextButton(onPressed: () => _viewOrders('active'), child: const Text('عرض الكل')),
          ]),
          if (active.isEmpty) const Padding(padding: EdgeInsets.all(16),
              child: Text('لا توجد طلبات جارية حالياً')),
          ...active.take(8).map((order) => OrderCard(order: order,
              onStatusChanged: () => dashboard.fetchDashboardData(token),
              pickupCode: dashboard.pickupCodes[order.id])),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('✅ الطلبات المنتهية مؤخراً',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            TextButton(onPressed: () => _viewOrders(), child: const Text('مشاهدة جميع الطلبات')),
          ]),
          if (finished.isEmpty) const Padding(padding: EdgeInsets.all(16),
              child: Text('لم تُرجع قاعدة البيانات طلبات منتهية حديثاً')),
          ...finished.take(10).map((order) => OrderCard(order: order,
              isCompleted: true,
              onStatusChanged: () => dashboard.fetchDashboardData(token))),
        ]),
      );
    });
  }

  Widget _stat(String title, String value, IconData icon, Color color) => Card(
    child: Padding(padding: const EdgeInsets.all(10), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 5),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12), maxLines: 2))]),
      const SizedBox(height: 7),
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    ])),
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
      if (reset) { _nextPage = 1; _items = []; _hasMore = true; }
    });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final result = await ApiService().getManagerOrdersPage(
          status: selected, token: token, page: _nextPage, perPage: 20);
      if (!mounted || _status != selected) return;
      final seen = _items.map((e) => e.id).toSet();
      setState(() {
        _items.addAll(result.orders.where((e) => seen.add(e.id)));
        _hasMore = result.hasMore;
        _nextPage++;
      });
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
        ChoiceChip(label: const Text('المكتملة والمنتهية'),
            selected: _status == 'completed', onSelected: (_) => _select('completed')),
      ])),
      Expanded(child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 32), children: [
          if (_loading && _items.isEmpty) const Center(child: CircularProgressIndicator()),
          if (_error != null) Padding(padding: const EdgeInsets.all(12),
              child: Text('تعذر تحميل الطلبات: $_error',
                  style: const TextStyle(color: Colors.deepOrange))),
          if (!_loading && _items.isEmpty && _error == null)
            const Padding(padding: EdgeInsets.all(30),
                child: Center(child: Text('لا توجد طلبات في هذا القسم'))),
          ..._items.map((order) => OrderCard(order: order,
              isCompleted: _status == 'completed',
              onStatusChanged: () => _load(reset: true))),
          if (_loading && _items.isNotEmpty) const Center(child: CircularProgressIndicator()),
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
  String? _orderLoadError;

  String? get orderLoadError => _orderLoadError;
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

  Future<void> fetchDashboardData(String? token, {bool silent = false}) async {
    if (token == null || _fetching) return;
    _fetching = true;

    if (!silent || _orders.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final ApiService api = ApiService();

      // 🔥 جلب الطلبات النشطة والمكتملة بشكل منفصل لضمان الدقة
      final activeFromServer = await api.getRestaurantOrders(status: 'active', token: token);
      final completedFromServer = await api.getRestaurantOrders(status: 'completed', token: token);

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

      try {
        _ratingsDashboard = await api.getDashboardRatings(token);
      } catch (e) {
        debugPrint('تعذر تحديث التقييمات: $e');
      }

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
                child: Icon(Icons.storefront_rounded, size: 46, color: Colors.teal)),
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
          const Icon(Icons.storefront, color: Colors.teal), const SizedBox(width: 8),
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
  String _period = 'today';
  bool _loading = false;
  Map<String, dynamic>? _data;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; _data = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final result = await ApiService().fetchManagerAnalytics(token, _period);
      if (mounted) setState(() => _data = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  String _value(String key, {bool money = false}) {
    if (_data == null || _data![key] == null) return '—';
    final value = _data![key];
    final n = double.tryParse(value.toString());
    return n == null ? value.toString() :
    '${NumberFormat('#,##0.##').format(n)}${money ? ' د.ع' : ''}';
  }
  Widget _stat(String label, String value, IconData icon) => Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(icon, color: Colors.teal), const SizedBox(width: 10),
        Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ])));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إحصائيات المبيعات والأرباح'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 8, children: {
        'today': 'اليوم', 'week': 'الأسبوع', 'month': 'الشهر', 'all': 'الكل'
      }.entries.map((e) => ChoiceChip(label: Text(e.value), selected: _period == e.key,
          onSelected: (_) { setState(() => _period = e.key); _load(); })).toList()),
      const SizedBox(height: 16),
      if (_loading) const Center(child: CircularProgressIndicator()),
      if (!_loading && _data == null) Card(child: Padding(padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: Colors.orange),
            const SizedBox(height: 12),
            Text(_error == null
                ? 'السيرفر الحالي لا يوفر إحصائيات مالية مؤكدة للفترة المختارة بعد.'
                : 'تعذّر جلب الإحصائيات: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('لا يتم اختراع رقم صافي الربح؛ يحتاج حسابه إلى الخصومات والعمولات والمبالغ المستردة.'),
          ]))),
      if (!_loading && _data != null) ...[
        _stat('عدد الطلبات المكتملة', _value('completed_orders'), Icons.receipt_long),
        _stat('إجمالي المبيعات', _value('gross_sales', money: true), Icons.attach_money),
        _stat('الخصومات والاسترجاعات', _value('refunds', money: true), Icons.money_off),
        _stat('عمولة المنصة', _value('platform_commission', money: true), Icons.account_balance),
        _stat('صافي الربح', _value('net_profit', money: true), Icons.trending_up),
        const SizedBox(height: 8),
        const Text('المبالغ مستخرجة من السيرفر فقط. أي قيمة غير متوفرة تظهر —.'),
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
        title: const Text('لوحة تحكم المطعم', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.green),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            tooltip: 'المحفظة والأرباح',
          ),
          IconButton(icon: const Icon(Icons.location_on_outlined, color: Colors.blue),
              tooltip: 'تحديد موقع المطعم وإرساله للسيرفر',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerPickupLocationScreen()))),
          IconButton(icon: const Icon(Icons.delivery_dining), tooltip: 'طلب مندوب مستعجل',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerCourierScreen()))),
          IconButton(icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'اختبار إشعار الطلبات', onPressed: _testNotifications),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => auth.logout(context),
            tooltip: 'تسجيل الخروج',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'الطلبات والإحصائيات'), // تم دمجه
            Tab(icon: Icon(Icons.fastfood_outlined), text: 'المنتجات'),
            Tab(icon: Icon(Icons.star_rate), text: 'التقييمات'),
            Tab(icon: Icon(Icons.settings), text: 'الإعدادات'),
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
      // 🔥 ترتيب الأزرار العائمة: إضافة وجبة فوق إرسال عرض
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. زر إضافة وجبة (في الأعلى)
          FloatingActionButton.extended(
            heroTag: "btn_add_meal",
            onPressed: () => RestaurantManagerNavigation.addMeal(context),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('إضافة وجبة'),
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          // 2. زر إرسال عرض (في الأسفل)
          FloatingActionButton.extended(
            heroTag: "btn_offer",
            onPressed: () => _showModernOfferDialog(context),
            icon: const Icon(Icons.campaign_rounded),
            label: const Text('إرسال عرض'),
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
          ),
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
class RestaurantUrgentPickupQuickButton extends StatefulWidget {
  const RestaurantUrgentPickupQuickButton({super.key});
  @override
  State<RestaurantUrgentPickupQuickButton> createState() => _RestaurantUrgentPickupQuickButtonState();
}
class _RestaurantUrgentPickupQuickButtonState extends State<RestaurantUrgentPickupQuickButton> {
  bool _busy = false;
  int? _submittedOrder;
  late final String _requestId =
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';

  Future<void> _call() async {
    if (_busy || _submittedOrder != null) return;
    setState(() => _busy = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final contextData = await ApiService().getManagerContext(token);
      final lat = double.tryParse('${contextData['latitude']}');
      final lng = double.tryParse('${contextData['longitude']}');
      if (!mounted) return;
      if (lat == null || lng == null || lat.abs() < 0.000001 || lng.abs() < 0.000001) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('حدد موقع المطعم أولاً، ثم أعد الضغط على طلب المندوب')));
        await Navigator.push<void>(context,
            MaterialPageRoute(builder: (_) => const ManagerPickupLocationScreen()));
        return;
      }
      final result = await ApiService().requestUrgentPickup(token, _requestId);
      if (!mounted) return;
      final orderId = int.tryParse('${result['order_id']}');
      if (orderId != null) setState(() => _submittedOrder = orderId);
      final success = result['success'] == true && result['dispatch_confirmed'] == true;
      final message = success
          ? 'تم تسجيل استدعاء المندوب المستعجل، رقم الطلب #$orderId'
          : (result['message'] ?? 'الاستدعاء غير مؤكد. افحص الطلبات قبل تكراره.').toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: success ? Colors.green.shade700 : Colors.orange.shade800,
          content: Text(message), duration: const Duration(seconds: 6)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذّر تأكيد الطلب: $e. تأكد من الطلبات قبل إعادة المحاولة.'),
          duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: (_busy || _submittedOrder != null) ? null : _call,
    icon: Icon(_busy ? Icons.hourglass_top : Icons.delivery_dining),
    label: Text(_busy ? 'جارٍ الطلب...' : _submittedOrder != null
        ? 'استدعاء #$_submittedOrder' : 'طلب مندوب مستعجل'),
  );
}

// V21: The manager calls a courier to the restaurant with ONE tap.
// Customer details are handed over after the courier arrives; none are fabricated.
class ManagerCourierScreen extends StatefulWidget {
  const ManagerCourierScreen({super.key});
  @override
  State<ManagerCourierScreen> createState() => _ManagerCourierScreenState();
}

class _ManagerCourierScreenState extends State<ManagerCourierScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _restaurantName = '';
  double? _lat;
  double? _lng;
  int? _orderId;
  String? _notice;
  late final String _requestId;

  @override
  void initState() {
    super.initState();
    _requestId = '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 31)}';
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final info = await _api.getManagerContext(token);
      if (!mounted) return;
      setState(() {
        _restaurantName = (info['name'] ?? '').toString();
        _lat = double.tryParse('${info['latitude']}');
        _lng = double.tryParse('${info['longitude']}');
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasLocation => _lat != null && _lng != null &&
      _lat!.abs() > 0.000001 && _lng!.abs() > 0.000001 &&
      _lat!.abs() <= 90 && _lng!.abs() <= 180;

  Future<void> _request() async {
    if (_busy || _orderId != null || !_hasLocation) return;
    setState(() { _busy = true; _error = null; });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      final data = await _api.requestUrgentPickup(token, _requestId);
      if (!mounted) return;
      final id = int.tryParse('${data['order_id']}');
      final succeeded = data['success'] == true && data['dispatch_confirmed'] == true;
      setState(() {
        _orderId = id; // Do not duplicate a saved order even if dispatch is uncertain.
        _notice = succeeded
            ? 'تم إرسال استدعاء مندوب مستعجل. رقم الطلب: #$id'
            : (data['message'] ?? 'تم تسجيل الطلب، لكن وصوله للمندوب لم يتأكد. راجع الطلب رقم #$id ولا تعِد الإرسال.').toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تأكيد الطلب: $e. إذا انقطع الاتصال بعد الضغط، افحص الطلبات قبل إعادة المحاولة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLocation() async {
    await Navigator.push<void>(context,
        MaterialPageRoute(builder: (_) => const ManagerPickupLocationScreen()));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('طلب مندوب مستعجل')),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 18),
      const Center(child: Icon(Icons.delivery_dining, color: Colors.deepOrange, size: 72)),
      const SizedBox(height: 14),
      const Text('استدعاء مندوب للمطعم', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('ضغطة واحدة فقط. يصل المندوب إلى موقع المطعم المحفوظ، وتعطيه تفاصيل الزبون والعنوان يدوياً عندما يحضر.',
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Card(child: ListTile(
        leading: Icon(_hasLocation ? Icons.location_on : Icons.location_off,
            color: _hasLocation ? Colors.green : Colors.red),
        title: Text(_restaurantName.isNotEmpty ? _restaurantName : 'المطعم'),
        subtitle: Text(_hasLocation
            ? 'موقع الاستلام محفوظ (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})'
            : 'يجب تحديد موقع المطعم قبل طلب مندوب'),
        trailing: IconButton(onPressed: _openLocation,
            icon: const Icon(Icons.edit_location_alt_outlined), tooltip: 'تحديد موقع المطعم'),
        onTap: _openLocation,
      )),
      const SizedBox(height: 12),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.red))),
      if (_notice != null) Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Text(_notice!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
      SizedBox(height: 54, child: FilledButton.icon(
        onPressed: (_busy || _orderId != null || !_hasLocation) ? null : _request,
        icon: const Icon(Icons.campaign_outlined),
        label: Text(_busy ? 'جارٍ استدعاء المندوب...' : _orderId != null ? 'تم تسجيل الاستدعاء' : 'طلب مندوب مستعجل'),
      )),
      const SizedBox(height: 14),
      const Text('استدعاء استلام فقط: لا يُدخل رقم زبون أو تفاصيل أو أجرة توصيل، ولا تُنشأ فاتورة تحصيل بقيمة افتراضية. التوزيع يتم وفق آلية السائقين الحالية.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
    ]),
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
      setState(() => _error = 'حدد منطقة المندوبين الخاصة بموقع المطعم');
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
      DropdownButtonFormField<int>(value: _zone,
          decoration: const InputDecoration(labelText: 'منطقة المندوبين / الاستلام', border: OutlineInputBorder()),
          items: _areas.map((a) => DropdownMenuItem<int>(
              value: int.tryParse('${a['id']}'), child: Text('${a['name']}'))).toList(),
          onChanged: _busy ? null : (v) => setState(() => _zone = v)),
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
              label: const Text("إضافة وجبة"),
              icon: const Icon(Icons.fastfood)
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: TextField(
                controller: _searchController,
                decoration: const InputDecoration(hintText: 'ابحث عن منتج...', prefixIcon: Icon(Icons.search), border: InputBorder.none),
                onChanged: (query) => provider.search(query)
            ),
            actions: [
              // 🔥 أيقونة إدارة الأقسام
              IconButton(
                icon: const Icon(Icons.category_outlined, color: Colors.teal),
                tooltip: 'إدارة الأقسام',
                onPressed: _openManageSections,
              ),
            ],
          ),
          body: Column(children: [
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
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.teal.shade200)
                            ),
                            child: Text(
                              sectionName,
                              style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600),
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
          Icon(Icons.add_a_photo_outlined, size: 45, color: Colors.teal),
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
        if (dashboard.isLoading && dashboard.ratingsDashboard == null) return const Center(child: CircularProgressIndicator());
        if (dashboard.ratingsDashboard == null) return const Center(child: Text("لا توجد بيانات تقييم."));
        final data = dashboard.ratingsDashboard!;
        return RefreshIndicator(
          onRefresh: () => dashboard.fetchDashboardData(authProvider.token),
          child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(children: [
                                Text(data.averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.amber)),
                                RatingBarIndicator(rating: data.averageRating, itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber), itemCount: 5, itemSize: 25.0)
                              ]),
                              Column(children: [
                                Text(data.totalReviews.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                                const Text("إجمالي التقييمات")
                              ]),
                            ]
                        )
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
      child: ListTile(leading: Icon(icon, color: Colors.teal), title: Text(title),
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

String restaurantOrderStatusLabel(String value) {
  const names = <String, String>{
    'pending': 'بانتظار الدفع', 'processing': 'قيد التحضير',
    'on-hold': 'معلق', 'completed': 'مكتمل', 'cancelled': 'ملغى',
    'refunded': 'مسترجع', 'failed': 'فشل',
    'picked_up': 'استلمه المندوب', 'out-for-delivery': 'في الطريق',
    'delivered': 'تم التوصيل',
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
    final formatter = DateFormat('yyyy-MM-dd – hh:mm a', 'ar');
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
                          decoration: BoxDecoration(color: Colors.teal.shade600, borderRadius: BorderRadius.circular(8)),
                          child: Text("#${widget.order.id}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      ),
                      Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]
                ),
                const SizedBox(height: 8),
                Text('حالة الطلب: ${restaurantOrderStatusLabel(widget.order.status)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal)),
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
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("قيمة الوجبات:"),
                      Text("${widget.order.total} د.ع", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))
                    ]
                ),
                if (!isFinished && hasDriver && !['picked_up', 'out-for-delivery', 'delivered'].contains(widget.order.status.toLowerCase())) ...[
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
        title: 'Restaurant Manager',
        theme: ThemeData(
            primarySwatch: Colors.teal,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
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

