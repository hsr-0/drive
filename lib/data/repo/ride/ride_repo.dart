import 'package:geolocator/geolocator.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/method.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';

class RideRepo {
  ApiClient apiClient;
  RideRepo({required this.apiClient});

  Future<ResponseModel> getRideDetails(String id) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.rideDetails}/$id";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> getRideList({
    required String rideType,
    required String status,
    String page = '1',
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.rideList}?ride_type=$rideType&status=$status&page=$page";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> getNewRide({required bool isICity}) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.rideList}?ride_type=${isICity ? '2' : '1'}&status=new";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> acceptedRide({required bool isICity}) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.rideList}?ride_type=${isICity ? '2' : '1'}&status=accept";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> activeRide({required bool isICity}) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.rideList}?ride_type=${isICity ? '2' : '1'}&status=2";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> runningRide({required bool isICity}) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.rideList}?ride_type=${isICity ? '2' : '1'}&status=3";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> getAllRideList(
    String page, {
    required bool isICity,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.rideList}?ride_type=${isICity ? '2' : '1'}&status=all&page=$page";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> startRide({
    required String id,
    required String otp,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.startRides}/$id";
    Map<String, String> params = {'otp': otp};
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> endRide({required String id}) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.endRides}/$id";
    Position position = await MyUtils.getCurrentLocationPosition();
    Map<String, String> params = {
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
    };
    printX(params);
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> acceptCashPayment({required String id}) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.acceptCashPaymentRides}/$id";

    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> completedRide() async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.completedRides}";
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> createBid({
    required String rideId,
    required String amount,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.createBid}/$rideId";
    Map<String, String> params = {'rideId': rideId, 'bid_amount': amount};
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> reviewRide({
    required String id,
    required String review,
    required String rating,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.reviewRide}/$id";
    Map<String, String> params = {'review': review, 'rating': rating};
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  Future<ResponseModel> cancelRide({
    required String id,
    required String reason,
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.cancelBid}/$id";
    Map<String, String> params = {'cancel_reason': reason};
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }
}
