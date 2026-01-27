import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/authorization/authorization_response_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/repo/ride/ride_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class RideActionController extends GetxController {
  RideRepo repo;
  RideActionController({required this.repo});

  TextEditingController otpController = TextEditingController();

  bool isPickupLoading = false;
  String selectedRideId = '-1';
  Future<void> startRide(String rideId, {VoidCallback? onSuccess}) async {
    selectedRideId = rideId;
    update();
    try {
      isPickupLoading = true;
      update();
      ResponseModel responseModel = await repo.startRide(
        id: rideId,
        otp: otpController.text,
      );
      if (responseModel.statusCode == 200) {
        AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (model.status == MyStrings.success) {
          CustomSnackBar.success(
            successList: model.message ?? [MyStrings.success],
          );
          onSuccess?.call();
          update();
        } else {
          CustomSnackBar.error(
            errorList: model.message ?? [MyStrings.somethingWentWrong],
          );
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
    } finally {
      isPickupLoading = false;
      // otpController.text = '';
      // selectedRideId = '-1';
      update();
    }
  }
}
