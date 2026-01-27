import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/auth/two_factor_controller.dart';
import 'package:ovoride_driver/data/repo/auth/two_factor_repo.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/otp_field_widget/otp_field_widget.dart';
import 'package:ovoride_driver/presentation/components/text/small_text.dart';
import 'package:ovoride_driver/presentation/components/will_pop_widget.dart';

import '../../../components/image/custom_svg_picture.dart';

class TwoFactorVerificationScreen extends StatefulWidget {
  const TwoFactorVerificationScreen({super.key});

  @override
  State<TwoFactorVerificationScreen> createState() => _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState extends State<TwoFactorVerificationScreen> {
  @override
  void initState() {
    Get.put(TwoFactorRepo(apiClient: Get.find()));
    Get.put(TwoFactorController(repo: Get.find()));
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopWidget(
      nextRoute: RouteHelper.loginScreen,
      child: Scaffold(
        backgroundColor: MyColor.getScreenBgColor(),
        appBar: CustomAppBar(title: MyStrings.twoFactorAuth.tr, fromAuth: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.space15,
            vertical: Dimensions.space20,
          ),
          child: GetBuilder<TwoFactorController>(
            builder: (controller) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: Dimensions.space20),
                  Container(
                    height: 100,
                    width: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MyColor.primaryColor.withValues(alpha: .075),
                      shape: BoxShape.circle,
                    ),
                    child: CustomSvgPicture(
                      image: MyImages.emailVerifyImage,
                      height: 50,
                      width: 50,
                      color: MyColor.getPrimaryColor(),
                    ),
                  ),
                  const SizedBox(height: Dimensions.space50),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * .07,
                    ),
                    child: SmallText(
                      text: MyStrings.twoFactorMsg.tr,
                      maxLine: 3,
                      textAlign: TextAlign.center,
                      textStyle: regularDefault.copyWith(
                        color: MyColor.getLabelTextColor(),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.space50),
                  OTPFieldWidget(
                    onChanged: (value) {
                      setState(() {
                        controller.currentText = value;
                      });
                    },
                  ),
                  const SizedBox(height: Dimensions.space30),
                  RoundedButton(
                    isLoading: controller.submitLoading,
                    press: () {
                      controller.verifyYourSms(controller.currentText);
                    },
                    text: MyStrings.verify.tr,
                  ),
                  const SizedBox(height: Dimensions.space30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
