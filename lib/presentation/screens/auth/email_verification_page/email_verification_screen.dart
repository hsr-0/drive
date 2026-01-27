import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/auth/auth/email_verification_controler.dart';
import 'package:ovoride_driver/data/repo/auth/general_setting_repo.dart';
import 'package:ovoride_driver/data/repo/auth/sms_email_verification_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/default_text.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/components/will_pop_widget.dart';

import '../../../components/otp_field_widget/otp_field_widget.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  @override
  void initState() {
    Get.put(GeneralSettingRepo(apiClient: Get.find()));
    Get.put(SmsEmailVerificationRepo(apiClient: Get.find()));
    final controller = Get.put(EmailVerificationController(repo: Get.find()));

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopWidget(
      nextRoute: RouteHelper.loginScreen,
      child: AnnotatedRegionWidget(
        statusBarColor: MyColor.transparentColor,
        child: Scaffold(
          backgroundColor: MyColor.screenBgColor,
          body: GetBuilder<EmailVerificationController>(
            builder: (controller) => controller.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: MyColor.getPrimaryColor(),
                    ),
                  )
                : SingleChildScrollView(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              Align(
                                alignment: AlignmentDirectional.center,
                                child: Image.asset(
                                  MyImages.emailVerificationImage,
                                  width: Dimensions.space50 * 4,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: Dimensions.space5,
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        Get.offAllNamed(
                                          RouteHelper.loginScreen,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.close,
                                        size: Dimensions.space30,
                                        color: MyColor.getHeadingTextColor(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          spaceDown(Dimensions.space40),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25),
                            child: Column(
                              children: [
                                HeaderText(
                                  text: MyStrings.verifyYourEmail.tr,
                                  textAlign: TextAlign.center,
                                  style: boldExtraLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: Dimensions.fontOverLarge22,
                                  ),
                                ),
                                spaceDown(Dimensions.space8),
                                DefaultText(
                                  text: '${MyStrings.verifyCodeSendToSubText.tr} ${MyUtils.maskEmail(controller.userEmail)}',
                                  textAlign: TextAlign.center,
                                  fontSize: Dimensions.fontLarge,
                                  textColor: MyColor.getBodyTextColor(),
                                ),
                                const SizedBox(height: Dimensions.space40),
                                OTPFieldWidget(
                                  onChanged: (value) {
                                    controller.currentText = value;
                                  },
                                ),
                                spaceDown(Dimensions.space30),
                                RoundedButton(
                                  isLoading: controller.submitLoading,
                                  text: MyStrings.verify.tr,
                                  press: () {
                                    controller.verifyEmail(
                                      controller.currentText,
                                    );
                                  },
                                ),
                                spaceDown(Dimensions.space25),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      MyStrings.didNotReceiveCode.tr,
                                      overflow: TextOverflow.ellipsis,
                                      style: boldLarge.copyWith(
                                        color: MyColor.getBodyTextColor(),
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(width: Dimensions.space5),
                                    TextButton(
                                      onPressed: () {
                                        controller.sendCodeAgain();
                                      },
                                      child: controller.resendLoading
                                          ? const SizedBox(
                                              height: Dimensions.space16,
                                              width: Dimensions.space16,
                                              child: CircularProgressIndicator(
                                                color: MyColor.primaryColor,
                                              ),
                                            )
                                          : Text(
                                              MyStrings.resendCode.tr,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: boldLarge.copyWith(
                                                color: MyColor.getPrimaryColor(),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
