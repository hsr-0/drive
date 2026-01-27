import 'dart:io';

import 'package:ovoride_driver/core/utils/method.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/model/authorization/authorization_response_model.dart';
import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/global/ride/app_service_model.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_rulse_model.dart';
import 'package:ovoride_driver/data/model/vehicle_verification/vehicle_verification_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class VehicleVerificationRepo {
  ApiClient apiClient;
  VehicleVerificationRepo({required this.apiClient});

  Future<VehicleKycResponseModel> getVahicleVerificationKycData() async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.vehicleVerificationFormUrl}';
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );

    if (responseModel.statusCode == 200) {
      VehicleKycResponseModel model = VehicleKycResponseModel.fromJson(
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
      return VehicleKycResponseModel();
    }
  }

  List<Map<String, String>> fieldList = [];
  List<ModelDynamicValue> filesList = [];

  Future<AuthorizationResponseModel> submitVehicleVerificationKycData({
    required List<GlobalFormModel> formList,
    required List<RiderRule> rideRuleList,
    required Brand brand,
    required AppService service,
    required String vehicleNumber,
    required String vmodel,
    required String color,
    required String year,
    required File image,
  }) async {
    apiClient.initToken();
    await modelToMap(formList);

    String url = '${UrlContainer.baseUrl}${UrlContainer.vehicleVerificationFormUrl}';

    Map<String, String> finalMap = {
      'service_id': service.id!,
      'brand_id': brand.id!,
      'model': vmodel,
      'color': color,
      'year': year,
      'vehicle_number': vehicleNumber,
    };

    for (int i = 0; i < rideRuleList.length; i++) {
      String id = rideRuleList[i].id.toString();
      finalMap['rules[$i]'] = id;
    }

    for (var element in fieldList) {
      finalMap.addAll(element);
    }

    Map<String, File> attachmentFiles = filesList.isEmpty == true
        ? {}
        : filesList.asMap().map(
              (index, value) => MapEntry(value.key ?? "", value.value),
            );

    attachmentFiles.addAll({"image": image});
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
