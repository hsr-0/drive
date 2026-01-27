import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/text/small_text.dart';
import 'package:toastification/toastification.dart';

class CustomSnackBar {
  static void error({
    required List<String> errorList,
    int duration = 5,
    bool dismissAll = true,
  }) {
    String message = '';
    if (errorList.isEmpty) {
      message = MyStrings.somethingWentWrong.tr;
    } else {
      for (var element in errorList) {
        String tempMessage = element.tr;
        message = message.isEmpty ? tempMessage : "$message\n$tempMessage";
        message = StringConverter.removeQuotationAndSpecialCharacterFromString(
          message,
        );
        if (dismissAll) {
          toastification.dismissAll();
        }

        toastification.show(
          context: Get.context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: Text(
            tempMessage,
            maxLines: 10,
            style: Get.theme.textTheme.bodyMedium?.copyWith(
              color: MyColor.colorWhite,
            ),
          ),
          alignment: Alignment.topCenter,
          foregroundColor: MyColor.colorWhite,
          primaryColor: MyColor.redCancelTextColor,
          showProgressBar: false,
          autoCloseDuration: Duration(seconds: duration),
          borderRadius: BorderRadius.circular(Dimensions.largeRadius),
          applyBlurEffect: false,
        );
      }
    }
  }

  static void success({
    required List<String> successList,
    int duration = 5,
    bool dismissAll = false,
  }) {
    String message = '';
    if (successList.isEmpty) {
      message = MyStrings.somethingWentWrong.tr;
    } else {
      for (var element in successList) {
        String tempMessage = element.tr;
        message = message.isEmpty ? tempMessage : "$message\n$tempMessage";
      }
    }
    message = StringConverter.removeQuotationAndSpecialCharacterFromString(
      message,
    );
    if (dismissAll) {
      toastification.dismissAll();
    }
    toastification.show(
      context: Get.context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text(
        message,
        maxLines: 10,
        style: Get.theme.textTheme.bodyMedium?.copyWith(
          color: MyColor.colorWhite,
        ),
      ),
      alignment: Alignment.topCenter,
      foregroundColor: MyColor.colorWhite,
      primaryColor: MyColor.greenSuccessColor,
      showProgressBar: false,
      autoCloseDuration: Duration(seconds: duration),
      borderRadius: BorderRadius.circular(Dimensions.largeRadius),
      applyBlurEffect: false,
    );
  }

  static void showToast({
    required String message,
    int duration = 2,
    bool dismissAll = false,
  }) {
    toastification.showCustom(
      context: Get.context, // optional if you use ToastificationWrapper
      autoCloseDuration: const Duration(seconds: 2),
      alignment: Alignment.bottomCenter,
      builder: (BuildContext context, ToastificationItem holder) {
        return Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusHuge),
              color: MyColor.greenSuccessColor,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.space10,
              vertical: Dimensions.space8,
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: Dimensions.space10,
              vertical: Dimensions.space10,
            ),
            child: SmallText(
              text: message,
              textStyle: regularDefault.copyWith(color: MyColor.colorWhite),
            ),
          ),
        );
      },
    );
  }
}
