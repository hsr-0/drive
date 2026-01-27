import 'dart:io';

import 'package:ovoride_driver/core/utils/method.dart' as request;
import 'package:ovoride_driver/core/utils/method.dart' show Method;
import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';

import '../../../core/utils/my_strings.dart';
import '../../../core/utils/url_container.dart';
import '../../../presentation/components/snack_bar/show_custom_snackbar.dart';
import '../../model/authorization/authorization_response_model.dart';
import '../../model/global/response_model/response_model.dart';
import '../../model/withdraw/withdraw_history_response_model.dart' as withdraw_history_model;
import '../../services/api_client.dart';
import '../driver_profile_verification/driver_kyc_repo.dart';

class WithdrawRepo {
  ApiClient apiClient;
  WithdrawRepo({required this.apiClient});

  Future<dynamic> getAllWithdrawMethod() async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.withdrawMethodUrl}';

    ResponseModel responseModel = await apiClient.request(
      url,
      request.Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<dynamic> getWithdrawConfirmScreenData(String trxId) async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.withdrawConfirmScreenUrl}$trxId';

    ResponseModel responseModel = await apiClient.request(
      url,
      request.Method.getMethod,
      null,
      passHeader: true,
    );
    return responseModel;
  }

  Future<dynamic> addWithdrawRequest(
    int methodCode,
    double amount,
    String? authMode,
  ) async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.addWithdrawRequestUrl}';
    Map<String, dynamic> params = {
      'method_code': methodCode.toString(),
      'amount': amount.toString(),
    };

    if (authMode != null && authMode.isNotEmpty && authMode.toLowerCase() != MyStrings.selectOne.toLowerCase()) {
      params['auth_mode'] = authMode.toLowerCase();
    }

    ResponseModel responseModel = await apiClient.request(
      url,
      request.Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  List<Map<String, String>> fieldList = [];
  List<ModelDynamicValue> filesList = [];

  Future<AuthorizationResponseModel> confirmWithdrawRequest(
    String trx,
    List<GlobalFormModel> list,
    String twoFactorCode,
  ) async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.withdrawRequestConfirm}';

    apiClient.initToken();
    await modelToMap(list);

    Map<String, String> finalMap = {};

    for (var element in fieldList) {
      finalMap.addAll(element);
    }

    finalMap.addEntries([
      MapEntry('trx', trx),
      if (twoFactorCode.isNotEmpty) MapEntry('authenticator_code', twoFactorCode),
    ]);

    Map<String, File> attachmentFiles = filesList.isEmpty == true
        ? {}
        : filesList.asMap().map(
              (index, value) => MapEntry(value.key ?? "", value.value),
            );
    ResponseModel responseModel = await apiClient.multipartRequest(
      url,
      Method.postMethod,
      finalMap,
      files: attachmentFiles,
      passHeader: true,
    );
    AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
      (responseModel.responseJson),
    );

    return model;
  }

  Future<dynamic> getAllWithdrawHistory(
    int page, {
    String searchText = "",
  }) async {
    String url = "${UrlContainer.baseUrl}${UrlContainer.withdrawHistoryUrl}?page=$page&search=$searchText";

    ResponseModel responseModel = await apiClient.request(
      url,
      request.Method.getMethod,
      null,
      passHeader: true,
    );

    if (responseModel.statusCode == 200) {
      withdraw_history_model.WithdrawHistoryResponseModel model = withdraw_history_model.WithdrawHistoryResponseModel.fromJson(
        (responseModel.responseJson),
      );

      if (model.status == 'success') {
        return model;
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.somethingWentWrong],
        );
        return withdraw_history_model.WithdrawHistoryResponseModel();
      }
    } else {
      return withdraw_history_model.WithdrawHistoryResponseModel();
    }
  }

  Future<dynamic> modelToMap(List<GlobalFormModel> list) async {
    for (var e in list) {
      if (e.type == 'checkbox') {
        if (e.cbSelected != null && e.cbSelected!.isNotEmpty) {
          for (int i = 0; i < e.cbSelected!.length; i++) {
            fieldList.add({'${e.label}[$i]': e.cbSelected![i]});
          }
        }
      } else if (e.type == 'file') {
        if (e.imageFile != null) {
          filesList.add(ModelDynamicValue(e.label, e.imageFile!));
        }
      } else {
        if (e.selectedValue != null && e.selectedValue.toString().isNotEmpty) {
          fieldList.add({e.label ?? '': e.selectedValue});
        }
      }
    }
  }
}
