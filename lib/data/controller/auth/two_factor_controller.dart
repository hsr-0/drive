import 'dart:convert';

import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/authorization/authorization_response_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/repo/auth/two_factor_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

import '../../model/two_factor/two_factor_data_model.dart';
import '../../services/push_notification_service.dart';

class TwoFactorController extends GetxController {
  TwoFactorRepo repo;
  TwoFactorController({required this.repo});

  bool submitLoading = false;
  String currentText = '';

  bool isProfileCompleteEnable = false;

  Future<void> verifyYourSms(String currentText) async {
    if (currentText.isEmpty) {
      CustomSnackBar.error(errorList: [MyStrings.otpFieldEmptyMsg]);
      return;
    }

    submitLoading = true;
    update();

    ResponseModel responseModel = await repo.verify(currentText);

    if (responseModel.statusCode == 200) {
      AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
        (responseModel.responseJson),
      );

      if (model.status == MyStrings.success) {
        CustomSnackBar.success(
          successList: model.message ?? [MyStrings.requestSuccess],
        );
        Get.offAndToNamed(
          isProfileCompleteEnable ? RouteHelper.profileCompleteScreen : RouteHelper.dashboard,
        );
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [responseModel.message]);
    }

    submitLoading = false;
    update();
  }

  bool isLoading = false;
  TwoFactorCodeModel twoFactorCodeModel = TwoFactorCodeModel();
  void get2FaCode() async {
    isLoading = true;
    update();

    ResponseModel responseModel = await repo.get2FaData();

    if (responseModel.statusCode == 200) {
      TwoFactorCodeModel model = twoFactorCodeModelFromJson(
        jsonEncode(responseModel.responseJson),
      );

      if (model.status.toString() == MyStrings.success.toString().toLowerCase()) {
        twoFactorCodeModel = model;
        isLoading = false;
        update();
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [responseModel.message]);
    }
    isLoading = false;
    update();
  }

  void enable2fa(String key, String code) async {
    if (code.isEmpty) {
      CustomSnackBar.error(errorList: [MyStrings.otpFieldEmptyMsg]);
      return;
    }

    submitLoading = true;
    update();

    ResponseModel responseModel = await repo.enable2fa(key, code);

    if (responseModel.statusCode == 200) {
      AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
        (responseModel.responseJson),
      );
      if (model.status.toString() == MyStrings.success.toString().toLowerCase()) {
        Get.back();
        CustomSnackBar.success(
          successList: model.message ?? [MyStrings.requestSuccess],
        );
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [responseModel.message]);
    }
    submitLoading = false;
    update();
  }

  void disable2fa(String code) async {
    if (code.isEmpty) {
      CustomSnackBar.error(errorList: [MyStrings.otpFieldEmptyMsg]);
      return;
    }

    submitLoading = true;
    update();

    ResponseModel responseModel = await repo.disable2fa(code);

    if (responseModel.statusCode == 200) {
      AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
        (responseModel.responseJson),
      );

      if (model.status.toString() == MyStrings.success.toString().toLowerCase()) {
        Get.back();
        CustomSnackBar.success(
          successList: model.message ?? [MyStrings.requestSuccess],
        );
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [responseModel.message]);
    }
    submitLoading = false;
    update();
  }

  void verify2FACode(String currentText) async {
    if (currentText.isEmpty) {
      CustomSnackBar.error(errorList: [MyStrings.otpFieldEmptyMsg]);
      return;
    }

    submitLoading = true;
    update();

    ResponseModel responseModel = await repo.verify(currentText);

    if (responseModel.statusCode == 200) {
      AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
        (responseModel.responseJson),
      );

      if (model.status?.toLowerCase() == MyStrings.success.toLowerCase()) {
        PushNotificationService(apiClient: Get.find()).sendUserToken();
        Get.offAndToNamed(RouteHelper.homeScreen);
        CustomSnackBar.success(
          successList: model.message ?? [MyStrings.requestSuccess],
        );
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [responseModel.message]);
    }

    submitLoading = false;
    update();
  }
}
