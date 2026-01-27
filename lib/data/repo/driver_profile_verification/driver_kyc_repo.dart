import 'dart:io';

import 'package:ovoride_driver/core/utils/method.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/model/authorization/authorization_response_model.dart';
import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/kyc/kyc_response_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class DriverVerificationKycRepo {
  ApiClient apiClient;
  DriverVerificationKycRepo({required this.apiClient});

  Future<DriverKycResponseModel> getDriverVerificationKycData() async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.driverVerificationFormUrl}';
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );

    if (responseModel.statusCode == 200) {
      DriverKycResponseModel model = DriverKycResponseModel.fromJson(
        (responseModel.responseJson),
      );

      if (model.status == 'success') {
        return model;
      } else {
        if (model.remark?.toLowerCase() != 'already_verified' && model.remark?.toLowerCase() != 'under_review') {
          CustomSnackBar.error(
            errorList: model.message ?? [MyStrings.somethingWentWrong],
          );
        }

        return model;
      }
    } else {
      return DriverKycResponseModel();
    }
  }

  List<Map<String, String>> fieldList = [];
  List<ModelDynamicValue> filesList = [];

  Future<AuthorizationResponseModel> submitDriverVerificationKycData(
    List<GlobalFormModel> list,
  ) async {
    apiClient.initToken();
    await modelToMap(list);
    String url = '${UrlContainer.baseUrl}${UrlContainer.driverVerificationFormUrl}';

    Map<String, String> finalMap = {};

    for (var element in fieldList) {
      finalMap.addAll(element);
    }

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

  //
}

class ModelDynamicValue {
  String? key;
  dynamic value;
  ModelDynamicValue(this.key, this.value);
}
