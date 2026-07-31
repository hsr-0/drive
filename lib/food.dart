
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
import 'package:image_picker/image_picker.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';

// =======================================================================
// 🔷 القسم 1: الثوابت (Constants)
// =======================================================================
class AppConstants {
  static const String BEYTEI_URL = 'https://re.beytei.com';
  static const String baseUrl = "https://re.beytei.com/wp-json";
  static const String CONSUMER_KEY = 'ck_d22c789681c4610838f1d39a05dbedcb73a2c810';
  static const String CONSUMER_SECRET = 'cs_78b90e397bbc2a8f5f5092cca36dc86e55c01c07';
  static const Duration API_TIMEOUT = Duration(seconds: 30);
  static const int AD_PRODUCT_ID = 9999;
  static const double AD_COST = 3000.0;
}

// =======================================================================
// 🔷 القسم 2: الموديلات (Models)
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

    String imageUrl = 'https://via.placeholder.com/300';
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
  int quantity; final int categoryId;

  FoodItem({
    required this.id, required this.name, required this.description,
    required this.price, this.salePrice, required this.imageUrl,
    this.quantity = 1, required this.categoryId,
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
      return 'https://via.placeholder.com/150';
    }

    int extractRestaurantId(Map<String, dynamic> json) {
      dynamic categories = json['categories'];
      if (categories is List && categories.isNotEmpty && categories[0] is Map) {
        return categories[0]['id'];
      }
      return 0;
    }

    return FoodItem(
      id: json['id'] ?? 0, name: json['name'] ?? 'غير متوفر',
      description: json['short_description'] is String ? json['short_description'].replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim() : '',
      price: safeParseDouble(json['regular_price']),
      salePrice: (json['sale_price'] != '' && json['sale_price'] != null) ? safeParseDouble(json['sale_price'], -1.0) : null,
      imageUrl: extractImageUrl(json['images']), categoryId: extractRestaurantId(json),
    );
  }
}

class Order {
  final int id; final String status; final DateTime dateCreated; final String total;
  final String customerName; final String address; final String phone;
  final List<LineItem> lineItems; final String? driverName; final String? driverPhone;

  Order({
    required this.id, required this.status, required this.dateCreated, required this.total,
    required this.customerName, required this.address, required this.phone,
    required this.lineItems, this.driverName, this.driverPhone,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'], status: json['status'], dateCreated: DateTime.parse(json['date_created']),
      total: json['total'].toString(),
      customerName: json['customerName'] ?? '${json['billing']?['first_name'] ?? ''} ${json['billing']?['last_name'] ?? ''}'.trim(),
      address: json['address'] ?? json['shipping']?['address_1'] ?? json['billing']?['address_1'] ?? 'N/A',
      phone: json['phone'] ?? json['billing']?['phone'] ?? 'N/A',
      lineItems: (json['line_items'] as List).map((i) => LineItem.fromJson(i)).toList(),
      driverName: json['driver_name'], driverPhone: json['driver_phone'],
    );
  }
}

class LineItem {
  final String name; final int quantity; final String total;
  LineItem({required this.name, required this.quantity, required this.total});
  factory LineItem.fromJson(Map<String, dynamic> json) =>
      LineItem(name: json['name'], quantity: json['quantity'], total: json['total'].toString());
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
// 🔷 القسم 3: الخدمات (Services)
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
      final response = await http.post(
          Uri.parse('$baseUrl/wp-json/jwt-auth/v1/token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'password': password})
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['token'];
      }
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
      if (fcmToken == null) return;
      String platform = Platform.isAndroid ? 'android' : 'ios';
      Map<String, dynamic> bodyData = {'token': fcmToken, 'platform': platform};
      await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/register-device'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode(bodyData),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print("⚠️ [FCM] خطأ في التسجيل: $e");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
  }
}

class ApiService {
  final String _authString = 'Basic ${base64Encode(utf8.encode('${AppConstants.CONSUMER_KEY}:${AppConstants.CONSUMER_SECRET}'))}';
  final CacheService _cacheService = CacheService();

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
    return _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-status'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'mode': mode, 'is_open': isOpen ? 1 : 0}),
      );
      return response.statusCode == 200;
    });
  }

  Future<bool> updateRestaurantAutoTimes(String token, String openTime, String closeTime) async {
    return _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-auto-times'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'open_time': openTime, 'close_time': closeTime}),
      );
      return response.statusCode == 200;
    });
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

  Future<bool> createProduct(String token, String name, String price, String? salePrice, String? description, File? imageFile) async {
    return _executeWithRetry(() async {
      String? imageBase64;
      if (imageFile != null) {
        List<int> imageBytes = await imageFile.readAsBytes();
        imageBase64 = base64Encode(imageBytes);
      }
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/create-product'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({
          'name': name, 'regular_price': price, 'sale_price': salePrice,
          'description': description, 'image_base64': imageBase64,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    });
  }

  Future<bool> updateMyProduct(String token, int productId, String name, String price, String salePrice, File? newImageFile) async {
    return _executeWithRetry(() async {
      String? imageBase64;
      if (newImageFile != null) {
        List<int> imageBytes = await newImageFile.readAsBytes();
        imageBase64 = base64Encode(imageBytes);
      }
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/update-product'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({
          'product_id': productId, 'name': name, 'regular_price': price,
          'sale_price': salePrice, 'image_base64': imageBase64,
        }),
      );
      return response.statusCode == 200;
    });
  }

  Future<List<Order>> getRestaurantOrders({required String status, required String token}) async {
    return _executeWithRetry(() async {
      final uri = Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/restaurant-app/v1/get-orders?status=$status');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        return (json.decode(response.body) as List).map((jsonObj) => Order.fromJson(jsonObj)).toList();
      }
      throw Exception('Failed to load orders: ${response.body}');
    });
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

  Future<bool> notifyDriverOrderReady(int sourceOrderId) async {
    return _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('${AppConstants.BEYTEI_URL}/wp-json/taxi/v3/delivery/notify-ready'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'source_order_id': sourceOrderId.toString(), 'secret_key': 'BEYTEI_SECURE_2025'}),
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

  // ✅ تم إصلاح خطأ تسمية المتغير هنا (تجنب تعارض اسم body)
  Future<bool> createMarketingOrder({required String token, required String title, required String bodyText, required String? imageUrl}) async {
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
          'product_id': AppConstants.AD_PRODUCT_ID,
          'quantity': 1,
          'total_cost': AppConstants.AD_COST,
          'meta_data': metaData,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return true;

      final responseBody = json.decode(response.body);
      throw Exception(responseBody['message'] ?? 'فشل إنشاء طلب الإعلان');
    });
  }
}

// =======================================================================
// 🔷 القسم 4: مزود المصادقة (Auth Provider)
// =======================================================================
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
  }

  Future<bool> login(String username, String password, String role, {String? restaurantLat, String? restaurantLng}) async {
    final authService = AuthService();
    _token = await authService.loginToServer(AppConstants.BEYTEI_URL, username, password);

    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('user_role', role);
      await authService.registerDeviceToken(_token);
      _userRole = role;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout(BuildContext context) async {
    final authService = AuthService();
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
// 🔷 القسم 5: مزودي البيانات (Providers)
// =======================================================================

class RestaurantSettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isRestaurantOpen = true;
  String _operationMode = 'manual';
  String _openTime = '09:00';
  String _closeTime = '22:00';
  bool _isLoading = false;

  bool get isRestaurantOpen => _isRestaurantOpen;
  String get operationMode => _operationMode;
  String get openTime => _openTime;
  String get closeTime => _closeTime;
  bool get isLoading => _isLoading;

  Future<void> fetchSettings(String? token) async {
    if (token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final settings = await _apiService.getRestaurantSettings(token);
      _isRestaurantOpen = settings['is_open'] ?? true;
      _operationMode = settings['operation_mode'] ?? 'manual';
      _openTime = settings['auto_open_time'] ?? '09:00';
      _closeTime = settings['auto_close_time'] ?? '22:00';

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
      print("Error fetching settings: $e");
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
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _isRestaurantOpen = true;
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

  Future<bool> updateProduct(String token, int productId, String name, String price, String salePrice, File? newImage) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await _apiService.updateMyProduct(token, productId, name, price, salePrice, newImage);
      if (success) await fetchProducts(token);
    } catch (e) {
      _errorMessage = "فشل تحديث المنتج: ${e.toString()}";
      success = false;
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> addProduct(String token, String name, String price, String? salePrice, String description, File? image) async {
    _isLoading = true;
    notifyListeners();
    bool success = false;
    try {
      success = await _apiService.createProduct(token, name, price, salePrice, description, image);
      if (success) await fetchProducts(token);
    } catch (e) {
      _errorMessage = "فشل إضافة المنتج: ${e.toString()}";
      success = false;
    }
    _isLoading = false;
    notifyListeners();
    return success;
  }

  void search(String query) {
    if (query.isEmpty) {
      _filteredProducts = _allProducts;
    } else {
      _filteredProducts = _allProducts.where((item) => item.name.toLowerCase().contains(query.toLowerCase())).toList();
    }
    notifyListeners();
  }

  void clearData() {
    _allProducts = [];
    _filteredProducts = [];
    notifyListeners();
  }
}

class DashboardProvider with ChangeNotifier {
  Map<String, List<Order>> _orders = {};
  RestaurantRatingsDashboard? _ratingsDashboard;
  Map<int, String> _pickupCodes = {};
  bool _isLoading = false;
  Timer? _timer;
  Timer? _debounceTimer;

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
    if (token == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final ApiService api = ApiService();
      final activeFromServer = await api.getRestaurantOrders(status: 'active', token: token);
      final completedFromServer = await api.getRestaurantOrders(status: 'completed', token: token);
      List<Order> allOrders = [...activeFromServer, ...completedFromServer];

      final ids = <int>{};
      allOrders.retainWhere((x) => ids.add(x.id));

      List<Order> finalActive = [];
      List<Order> finalCompleted = [];
      final List<String> archiveStatuses = ['completed', 'cancelled', 'refunded', 'failed', 'trash', 'picked_up', 'out-for-delivery', 'delivered'];

      for (var order in allOrders) {
        if (!archiveStatuses.contains(order.status.toLowerCase())) {
          finalActive.add(order);
        } else {
          finalCompleted.add(order);
        }
      }

      finalCompleted.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
      finalActive.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

      _orders['active'] = finalActive;
      _orders['completed'] = finalCompleted;
      final ratings = await api.getDashboardRatings(token);
      _ratingsDashboard = ratings;
    } catch (e) {
      print("Error fetching dashboard: $e");
    } finally {
      _isLoading = false;
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
// 🔷 القسم 6: الشاشات (Screens)
// =======================================================================

class RestaurantLoginScreen extends StatefulWidget {
  const RestaurantLoginScreen({super.key});
  @override
  State<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends State<RestaurantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  bool _isLoading = false;
  String _locationStatus = 'لم يتم تحديد موقع المطعم';
  final ApiService _apiService = ApiService();

  Future<void> _getCurrentLocation() async {
    setState(() => _locationStatus = 'جاري تحديد الموقع...');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationStatus = 'خدمة الموقع معطلة');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationStatus = 'الصلاحية مرفوضة');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _latController.text = position.latitude.toString();
      _lngController.text = position.longitude.toString();
      setState(() => _locationStatus = 'تم التحديد بنجاح');
    } catch (e) {
      setState(() => _locationStatus = 'خطأ في تحديد الموقع');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latController.text.isEmpty || _lngController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد موقع المطعم أولاً.')));
      return;
    }
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
        _usernameController.text, _passwordController.text, 'owner',
        restaurantLat: _latController.text, restaurantLng: _lngController.text
    );

    if (success && mounted) {
      try {
        final token = authProvider.token!;
        await _apiService.updateMyLocation(token, _latController.text, _lngController.text);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RestaurantDashboardScreen()));
      } catch (e) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RestaurantDashboardScreen()));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تسجيل الدخول.')));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دخول مدير المطعم')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store_mall_directory, size: 80, color: Colors.teal),
                  const SizedBox(height: 20),
                  TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'اسم المستخدم'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                  const SizedBox(height: 20),
                  TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: 'كلمة المرور'), obscureText: true, validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                  const SizedBox(height: 40),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.location_on), label: const Text('تحديد موقع المطعم الآن'),
                      onPressed: _getCurrentLocation, style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50))
                  ),
                  const SizedBox(height: 10),
                  Text(_locationStatus, textAlign: TextAlign.center, style: TextStyle(color: _latController.text.isEmpty ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 40),
                  _isLoading ? const CircularProgressIndicator() : ElevatedButton(
                      onPressed: _login, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('تسجيل الدخول')
                  )
                ]
            ),
          ),
        ),
      ),
    );
  }
}

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});
  @override
  State<RestaurantDashboardScreen> createState() => _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        Provider.of<RestaurantSettingsProvider>(context, listen: false).fetchSettings(token).then((_) {
          if (mounted) Provider.of<DashboardProvider>(context, listen: false).startAutoRefresh(token);
        });
      }
    });
  }

  @override
  void dispose() {
    Provider.of<DashboardProvider>(context, listen: false).stopAutoRefresh();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المطعم'),
        actions: [
          IconButton(icon: const Icon(Icons.account_balance_wallet, color: Colors.green), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => auth.logout(context)),
        ],
        bottom: TabBar(
          controller: _tabController, isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'الطلبات'),
            Tab(icon: Icon(Icons.history), text: 'المكتملة'),
            Tab(icon: Icon(Icons.fastfood_outlined), text: 'المنتجات'),
            Tab(icon: Icon(Icons.star_rate), text: 'التقييمات'),
            Tab(icon: Icon(Icons.settings), text: 'الإعدادات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OrdersListScreen(status: 'active'),
          OrdersListScreen(status: 'completed'),
          const ProductManagementTab(),
          const RatingsDashboardScreen(),
          const RestaurantSettingsScreen(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "btn_offer", onPressed: () => _showModernOfferDialog(context),
            icon: const Icon(Icons.campaign_rounded), label: const Text('إرسال عرض'),
            backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showModernOfferDialog(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool isSending = false;
    double currentBalance = 0.0;
    bool isLoadingBalance = true;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          if (isLoadingBalance) {
            final token = Provider.of<AuthProvider>(context, listen: false).token!;
            _apiService.getWalletData(token).then((data) {
              if (mounted) {
                setState(() {
                  currentBalance = double.tryParse(data['wallet_balance'].toString()) ?? 0.0;
                  isLoadingBalance = false;
                });
              }
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  const Text("إرسال إشعار ترويجي", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 30),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: currentBalance >= AppConstants.AD_COST ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("تكلفة الخدمة", style: TextStyle(fontSize: 12)),
                          Text("${NumberFormat('#,###').format(AppConstants.AD_COST)} د.ع", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text("رصيدك الحالي", style: TextStyle(fontSize: 12)),
                          Text("${NumberFormat('#,###').format(currentBalance)} د.ع", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: "عنوان العرض", border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  TextField(controller: bodyController, maxLines: 4, decoration: const InputDecoration(labelText: "تفاصيل العرض", border: OutlineInputBorder())),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: (isSending || currentBalance < AppConstants.AD_COST) ? null : () async {
                        if (titleController.text.isEmpty || bodyController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال العنوان والتفاصيل")));
                          return;
                        }
                        setState(() => isSending = true);
                        try {
                          final token = Provider.of<AuthProvider>(context, listen: false).token!;
                          // ✅ تم تمرير bodyText بدلاً من body لتجنب التعارض
                          await _apiService.createMarketingOrder(token: token, title: titleController.text, bodyText: bodyController.text, imageUrl: null);
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الإرسال بنجاح!"), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: ${e.toString()}"), backgroundColor: Colors.red));
                            setState(() => isSending = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                      child: isSending ? const CircularProgressIndicator(color: Colors.white) : Text("دفع ${NumberFormat('#,###').format(AppConstants.AD_COST)} د.ع وإرسال"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductManagementTab extends StatefulWidget {
  const ProductManagementTab({super.key});
  @override
  State<ProductManagementTab> createState() => _ProductManagementTabState();
}

class _ProductManagementTabState extends State<ProductManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _showOffersOnly = false;

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  void _navigateToEditScreen(FoodItem product) async {
    final productProvider = Provider.of<RestaurantProductsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(product: product, productProvider: productProvider, authProvider: authProvider)));
  }

  void _navigateToAddScreen() async {
    final productProvider = Provider.of<RestaurantProductsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(productProvider: productProvider, authProvider: authProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Consumer<RestaurantProductsProvider>(
      builder: (context, provider, child) {
        List<FoodItem> displayedProducts = provider.products;
        if (_showOffersOnly) displayedProducts = provider.products.where((p) => p.salePrice != null && p.salePrice! > 0).toList();

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(onPressed: _navigateToAddScreen, label: const Text("إضافة وجبة"), icon: const Icon(Icons.fastfood)),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: TextField(
                controller: _searchController, decoration: const InputDecoration(hintText: 'ابحث عن منتج...', prefixIcon: Icon(Icons.search), border: InputBorder.none),
                onChanged: (query) => provider.search(query)
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.fetchProducts(auth.token),
            child: displayedProducts.isEmpty
                ? const Center(child: Text("لا توجد منتجات"))
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 10),
              itemCount: displayedProducts.length,
              itemBuilder: (context, index) {
                final product = displayedProducts[index];
                final bool isOffer = product.salePrice != null && product.salePrice! > 0;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: product.imageUrl, width: 60, height: 60, fit: BoxFit.cover)),
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isOffer ? "سعر العرض: ${product.salePrice} د.ع" : "السعر: ${product.price} د.ع"),
                    trailing: IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _navigateToEditScreen(product)),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class EditProductScreen extends StatefulWidget {
  final FoodItem product;
  final RestaurantProductsProvider productProvider;
  final AuthProvider authProvider;
  const EditProductScreen({super.key, required this.product, required this.productProvider, required this.authProvider});
  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController, _priceController, _salePriceController;
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(0));
    _salePriceController = TextEditingController(text: widget.product.salePrice?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose(); _priceController.dispose(); _salePriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 800, maxHeight: 800);
    if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await widget.productProvider.updateProduct(
        widget.authProvider.token!, widget.product.id, _nameController.text, _priceController.text, _salePriceController.text, _selectedImage
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تعديل: ${widget.product.name}")),
      body: Form(
        key: _formKey,
        child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              GestureDetector(
                  onTap: _pickImage,
                  child: Center(
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, height: 200, fit: BoxFit.cover)
                          : CachedNetworkImage(imageUrl: widget.product.imageUrl, height: 200, fit: BoxFit.cover)
                  )
              ),
              const SizedBox(height: 20),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المنتج'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'السعر العادي'), keyboardType: TextInputType.number),
              TextFormField(controller: _salePriceController, decoration: const InputDecoration(labelText: 'سعر الخصم (اختياري)'), keyboardType: TextInputType.number),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _isLoading ? null : _submit, child: _isLoading ? const CircularProgressIndicator() : const Text('حفظ التعديلات')),
            ]
        ),
      ),
    );
  }
}

class AddProductScreen extends StatefulWidget {
  final RestaurantProductsProvider productProvider;
  final AuthProvider authProvider;
  const AddProductScreen({super.key, required this.productProvider, required this.authProvider});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(), _priceController = TextEditingController(), _salePriceController = TextEditingController(), _descController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose(); _priceController.dispose(); _salePriceController.dispose(); _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null) return;
    setState(() => _isLoading = true);
    final success = await ApiService().createProduct(
        widget.authProvider.token!, _nameController.text, _priceController.text,
        _salePriceController.text.isEmpty ? null : _salePriceController.text, _descController.text, _selectedImage
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.productProvider.fetchProducts(widget.authProvider.token);
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إضافة وجبة جديدة")),
      body: Form(
        key: _formKey,
        child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                      height: 200, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                      child: _selectedImage != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_selectedImage!, fit: BoxFit.cover))
                          : const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey))
                  )
              ),
              const SizedBox(height: 20),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم الوجبة'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
              Row(children: [
                Expanded(child: TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'السعر'), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _salePriceController, decoration: const InputDecoration(labelText: 'سعر الخصم'), keyboardType: TextInputType.number))
              ]),
              TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'الوصف'), maxLines: 3),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _isLoading ? null : _submit, child: _isLoading ? const CircularProgressIndicator() : const Text('حفظ الوجبة')),
            ]
        ),
      ),
    );
  }
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

class RestaurantSettingsScreen extends StatefulWidget {
  const RestaurantSettingsScreen({super.key});
  @override
  State<RestaurantSettingsScreen> createState() => _RestaurantSettingsScreenState();
}

class _RestaurantSettingsScreenState extends State<RestaurantSettingsScreen> {
  Future<void> _updateSettings(RestaurantSettingsProvider provider, {required String mode, required bool isOpen}) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final success = await provider.updateRestaurantStatus(token, mode, isOpen);
    if (success) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحديث بنجاح'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RestaurantSettingsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        bool isAutoMode = provider.operationMode == 'auto';
        bool isManualOpen = provider.isRestaurantOpen;
        return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("نظام التشغيل", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SwitchListTile(title: const Text("تفعيل الجدول التلقائي"), value: isAutoMode, onChanged: (val) => _updateSettings(provider, mode: val ? 'auto' : 'manual', isOpen: isManualOpen)),
                            if (!isAutoMode) SwitchListTile(title: Text(isManualOpen ? 'المطعم: مفتوح' : 'المطعم: مغلق'), value: isManualOpen, onChanged: (val) => _updateSettings(provider, mode: 'manual', isOpen: val)),
                          ]
                      )
                  )
              ),
              const SizedBox(height: 20),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(children: [
                        ListTile(title: const Text('وقت الفتح'), trailing: Text(provider.openTime), leading: const Icon(Icons.wb_sunny_outlined)),
                        ListTile(title: const Text('وقت الإغلاق'), trailing: Text(provider.closeTime), leading: const Icon(Icons.nightlight_round)),
                      ])
                  )
              ),
            ]
        );
      },
    );
  }
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  final ApiService _apiService = ApiService();

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;
    try {
      final data = await _apiService.getWalletData(token);
      if (mounted) setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final walletBalance = _data?['wallet_balance'] ?? 0;
    final totalEarnings = _data?['total_earnings'] ?? 0;
    final liability = _data?['liability'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text("محفظتي والأرباح"), centerTitle: true),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildCard("إجمالي المبيعات", totalEarnings, Colors.green, Icons.store),
            const SizedBox(height: 15),
            _buildCard("رصيدي الحالي", walletBalance, const Color(0xFF1E3C72), Icons.account_balance_wallet),
            if (liability > 0) ...[
              const SizedBox(height: 15),
              _buildCard("مستحقات للمنصة", liability, Colors.red.shade700, Icons.warning_amber_rounded)
            ],
          ])
      ),
    );
  }

  Widget _buildCard(String title, dynamic amount, Color color, IconData icon) {
    final format = NumberFormat('#,###', 'ar_IQ');
    return Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon, color: Colors.white70), const SizedBox(width: 10), Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))]),
              const SizedBox(height: 15),
              Text("${format.format(amount)} د.ع", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ]
        )
    );
  }
}

// =======================================================================
// 🔷 القسم 7: الويدجتات (Widgets)
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
      await ApiService().notifyDriverOrderReady(widget.order.id);
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
    final formattedDate = formatter.format(widget.order.dateCreated.toLocal());
    bool isFinished = ['completed', 'cancelled', 'refunded', 'failed', 'trash', 'picked_up', 'out-for-delivery', 'delivered'].contains(widget.order.status.toLowerCase());
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
                const Divider(height: 25),
                Text("الزبون: ${widget.order.customerName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("العنوان: ${widget.order.address}", style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 15),
                Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.order.lineItems.map((item) => Text("• ${item.quantity} x ${item.name}")).toList()
                    )
                ),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("المطلوب:"),
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
// 🔷 القسم 8: نقطة الدخول (Main)
// =======================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RestaurantManagerApp());
}

class RestaurantManagerApp extends StatelessWidget {
  const RestaurantManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RestaurantSettingsProvider()),
        ChangeNotifierProvider(create: (_) => RestaurantProductsProvider()),
        ChangeNotifierProxyProvider<AuthProvider, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, auth, dashboard) {
            if (auth.isLoggedIn && dashboard != null && auth.token != null) {
              dashboard.fetchDashboardData(auth.token!, silent: true);
            }
            return dashboard!;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Restaurant Manager',
        theme: ThemeData(
            primarySwatch: Colors.teal,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            fontFamily: 'Tajawal', // تأكد من إضافة هذا الخط في pubspec.yaml
            appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white, elevation: 0.5,
                iconTheme: IconThemeData(color: Colors.black),
                titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
            )
        ),
        debugShowCheckedModeBanner: false,
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