import 'package:http/http.dart' as http;
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/utils/method.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/environment.dart';

class DashBoardRepo {
  ApiClient apiClient;
  DashBoardRepo({required this.apiClient});

  Future<ResponseModel> getDashboardData({String page = '1'}) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.dashBoardEndPoint}?page=$page";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> onlineStatus({
    required String lat,
    required String long,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.onlineStatus}";

    Map<String, String> params = {'lat': lat, 'long': long};

    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  // ===========================================================================
  // 🚀 النظام المزدوج النظيف: حفظ MySQL (قديم) + بث Reverb (جديد ومنعزل)
  // ===========================================================================
  Future<ResponseModel> updateLiveLocation({
    required String lat,
    required String long,
    required String rideId, // ⚠️ إضافة ضرورية: معرف الرحلة الحالية للبث
  }) async {

    // ---------------------------------------------------------
    // 1️⃣ النظام القديم (محافظة عليه 100%): الحفظ في MySQL
    // ---------------------------------------------------------
    // نحتفظ بنفس أسماء المتغيرات (current_lat, current_lot) لضمان عمل لوحة التحكم ومكافحة الاحتيال كما هي
    String url = "${UrlContainer.baseUrl}${UrlContainer.driverLocationUpdate}";
    Map<String, String> params = {
      'current_lat': lat,
      'current_lot': long
    };

    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );

    // ---------------------------------------------------------
    // 2️⃣ النظام الجديد (منعزل): البث اللحظي للزبون عبر Reverb
    // ---------------------------------------------------------
    // نستخدم http.post عادي بدون await (Fire and Forget) حتى لا يبطئ التطبيق
    try {
      final String broadcastUrl = "${UrlContainer.baseUrl}/api/driver/broadcast-location";
      final String token = apiClient.sharedPreferences.getString(SharedPreferenceHelper.accessTokenKey) ?? '';

      // نتأكد من وجود التوكن ومعرف الرحلة قبل الإرسال
      if (token.isNotEmpty && rideId.isNotEmpty) {
        http.post(
          Uri.parse(broadcastUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'ride_id': rideId,       // معرف الرحلة (مطلوب للسيرفر الجديد)
            'latitude': lat,         // أسماء نظيفة وصحيحة للسيرفر الجديد
            'longitude': long,
          },
        ).catchError((e) {
          // في حال فشل البث، لا نوقف التطبيق، فقط نسجل الخطأ في الـ Console
          print("⚠️ [BROADCAST WARNING] فشل في البث اللحظي (لن يؤثر على حفظ MySQL): $e");
        });
      }
    } catch (e) {
      print("❌ [BROADCAST ERROR] استثناء في كود البث: $e");
    }

    // نرجع نتيجة طلب MySQL الأصلي كما كان يتوقع التطبيق
    return responseModel;
  }
  // ===========================================================================

  Future<ResponseModel> createBid({
    required String amount,
    required String id,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.createBid}/$id";
    Map<String, String> params = {'bid_amount': amount};
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  Future<String?> getActualAddress(double lat, double lng) async {
    const apiKey = Environment.mapKey;
    final url = '${UrlContainer.googleMapLocationSearch}?latlng=$lat,$lng&key=$apiKey';

    final response = await apiClient.request(url, Method.getMethod, null);

    if (response.statusCode == 200) {
      final data = response.responseJson;

      if (data['results'] != null && data['results'].isNotEmpty) {
        for (var result in data['results']) {
          final types = result['types'];
          if (types != null && (types.contains('street_address') || types.contains('premise') || types.contains('subpremise') || types.contains('route') || types.contains('locality'))) {
            return result['formatted_address'];
          }
        }
        return data['results'][0]['formatted_address'];
      }

      if (data['plus_code'] != null && data['plus_code']['compound_code'] != null) {
        return data['plus_code']['compound_code'];
      }
    }

    return null;
  }
  // ===========================================================================
  // 🏆 جلب بيانات المسابقة الحالية للسائق
  // ===========================================================================
  Future<ResponseModel> getCurrentContest() async {
    // استخدمنا الرابط الذي جهزناه في لارافيل
    String url = "${UrlContainer.baseUrl}/api/driver/current-contest";

    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }
}
