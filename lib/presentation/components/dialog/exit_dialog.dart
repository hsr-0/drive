import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';

void showExitDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true, // dismiss on touch outside
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.defaultRadius),
        ),
        backgroundColor: MyColor.getCardBgColor(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Dimensions.space20,
            horizontal: Dimensions.space20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                MyStrings.exitTitle.tr,
                textAlign: TextAlign.center,
                style: regularLarge.copyWith(
                  color: MyColor.colorBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
              spaceDown(Dimensions.space20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel Button
                  Expanded(
                    child: RoundedButton(
                      isOutlined: true,
                      text: MyStrings.no.tr,
                      press: () {
                        Navigator.pop(context);
                      },
                      bgColor: MyColor.getPrimaryColor().withValues(alpha: 0.1),
                      textColor: MyColor.getPrimaryColor(),
                      textStyle: regularDefault.copyWith(
                        color: MyColor.getPrimaryColor(),
                        fontSize: Dimensions.fontLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  spaceSide(Dimensions.space10),
                  // OK Button
                  Expanded(
                    child: RoundedButton(
                      text: MyStrings.yes.tr,
                      press: () {
                        SystemNavigator.pop();
                      },
                      bgColor: MyColor.colorRed,
                      textColor: MyColor.colorWhite,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
