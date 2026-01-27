import '../../../core/utils/method.dart';
import '../../../core/utils/url_container.dart';
import '../../model/global/response_model/response_model.dart';
import '../../services/api_client.dart';

class SocialAuthRepo {
  ApiClient apiClient;

  SocialAuthRepo({required this.apiClient});

  Future<ResponseModel> socialLoginUser({
    String accessToken = '',
    String? provider,
  }) async {
    Map<String, String>? map;

    if (provider == 'google') {
      map = {'token': accessToken, 'provider': "google"};
    }

    if (provider == 'linkedin') {
      map = {'token': accessToken, 'provider': "linkedin"};
    }

    if (provider == 'apple') {
      map = {'token': accessToken, 'provider': "apple"};
    }

    String url = '${UrlContainer.baseUrl}${UrlContainer.socialLoginEndPoint}';
    ResponseModel model = await apiClient.request(
      url,
      Method.postMethod,
      map,
      passHeader: false,
    );
    return model;
  }
}
