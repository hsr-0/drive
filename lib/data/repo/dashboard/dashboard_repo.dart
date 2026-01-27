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

  Future<ResponseModel> updateLiveLocation({
    required String lat,
    required String long,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.driverLocationUpdate}";

    Map<String, String> params = {'current_lat': lat, 'current_lot': long};

    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

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

      // Prefer a meaningful formatted_address
      if (data['results'] != null && data['results'].isNotEmpty) {
        for (var result in data['results']) {
          final types = result['types'];
          if (types != null && (types.contains('street_address') || types.contains('premise') || types.contains('subpremise') || types.contains('route') || types.contains('locality'))) {
            return result['formatted_address'];
          }
        }

        // Fallback to first result's address if no specific types found
        return data['results'][0]['formatted_address'];
      }

      // Final fallback: Plus Code
      if (data['plus_code'] != null && data['plus_code']['compound_code'] != null) {
        return data['plus_code']['compound_code'];
      }
    }

    return null; // or return 'Unknown Location';
  }
}
