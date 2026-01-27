import 'package:ovoride_driver/core/utils/method.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';

class ReviewRepo {
  ApiClient apiClient;
  ReviewRepo({required this.apiClient});

  Future<ResponseModel> getReviews() async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.reviewHistoryEndPoint}";
    final response = await apiClient.request(
      url,
      Method.getMethod,
      {},
      passHeader: true,
    );
    return response;
  }

  Future<ResponseModel> getReviewByUserId(String userId) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.reviewByUserHistoryEndPoint}/$userId";
    final response = await apiClient.request(
      url,
      Method.getMethod,
      {},
      passHeader: true,
    );
    return response;
  }
}
