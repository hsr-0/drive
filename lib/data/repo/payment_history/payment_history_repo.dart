import '../../../core/utils/method.dart';
import '../../../core/utils/url_container.dart';
import '../../model/global/response_model/response_model.dart';
import '../../services/api_client.dart';

class PaymentHistoryRepo {
  ApiClient apiClient;
  PaymentHistoryRepo({required this.apiClient});

  Future<ResponseModel> getPaymentHistory(String page) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.paymentHistory}?page=$page";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }
}
