import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/otp_field_widget/otp_field_widget.dart';

import '../../../../../../core/utils/dimensions.dart';
import '../../../../../../core/utils/my_color.dart';
import '../../../../../../core/utils/my_strings.dart';
import '../../../../../../core/utils/style.dart';
import '../../../../../data/controller/auth/two_factor_controller.dart';
import '../../../components/buttons/rounded_button.dart';
import '../../../components/text/small_text.dart';

class TwoFactorDisableSection extends StatelessWidget {
  const TwoFactorDisableSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TwoFactorController>(
      builder: (twoFactorController) {
        return Column(
          children: [
            CustomAppCard(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(
                vertical: Dimensions.space15,
                horizontal: Dimensions.space15,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MyStrings.disable2Fa.tr,
                    style: boldExtraLarge.copyWith(color: MyColor.colorBlack),
                  ),
                  spaceDown(Dimensions.space5),
                  SmallText(
                    text: MyStrings.twoFactorMsg.tr,
                    maxLine: 3,
                    textAlign: TextAlign.start,
                    textStyle: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                    ),
                  ),
                  spaceDown(Dimensions.space30),
                  OTPFieldWidget(
                    onChanged: (value) {
                      twoFactorController.currentText = value;
                      twoFactorController.update();
                    },
                  ),
                  spaceDown(Dimensions.space30),
                  RoundedButton(
                    isLoading: twoFactorController.submitLoading,
                    press: () {
                      twoFactorController.disable2fa(
                        twoFactorController.currentText,
                      );
                    },
                    text: MyStrings.submit.tr,
                  ),
                  spaceDown(Dimensions.space30),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
