import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/auth/social_auth_controller.dart';
import 'package:ovoride_driver/data/repo/auth/social_auth_repo.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/screens/auth/login/widgets/login_or_bar.dart';

class SocialAuthSection extends StatefulWidget {
  final String googleAuthTitle;
  const SocialAuthSection({super.key, this.googleAuthTitle = MyStrings.google});

  @override
  State<SocialAuthSection> createState() => _SocialAuthSectionState();
}

class _SocialAuthSectionState extends State<SocialAuthSection> {
  @override
  void initState() {
    Get.put(SocialAuthRepo(apiClient: Get.find()));
    Get.put(SocialAuthController(authRepo: Get.find()));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SocialAuthController>(
      builder: (controller) {
        return Column(
          children: [
            Row(
              children: [
                if (controller.authRepo.apiClient.isGoogleLoginEnabled() == true) ...[
                  Expanded(
                    child: RoundedButton(
                      text: "",
                      isOutlined: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          controller.isGoogleSignInLoading
                              ? SizedBox(
                                  height: 15,
                                  width: 15,
                                  child: CircularProgressIndicator(
                                    color: MyColor.primaryColor,
                                  ),
                                )
                              : MyLocalImageWidget(
                                  imagePath: MyImages.google,
                                  height: 25,
                                  width: 25,
                                  boxFit: BoxFit.contain,
                                ),
                          SizedBox(width: Dimensions.space10),
                          Text(
                            (widget.googleAuthTitle).tr,
                            style: regularDefault.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      press: () {
                        if (!controller.isGoogleSignInLoading) {
                          controller.signInWithGoogle();
                        }
                      },
                    ),
                  ),
                ],
                // Add spacing if both buttons are visible
                if (controller.authRepo.apiClient.isGoogleLoginEnabled() == true && controller.authRepo.apiClient.isAppleLoginEnabled() == true && Platform.isIOS) ...[
                  spaceSide(Dimensions.space10),
                ],
                if (controller.authRepo.apiClient.isAppleLoginEnabled() == true && Platform.isIOS) ...[
                  Expanded(
                    child: RoundedButton(
                      text: "",
                      isOutlined: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          controller.isAppleSignInLoading
                              ? SizedBox(
                                  height: 15,
                                  width: 15,
                                  child: CircularProgressIndicator(
                                    color: MyColor.primaryColor,
                                  ),
                                )
                              : MyLocalImageWidget(
                                  imagePath: MyImages.apple,
                                  height: 25,
                                  width: 25,
                                  boxFit: BoxFit.contain,
                                ),
                          SizedBox(width: Dimensions.space10),
                          Text(
                            MyStrings.apple.tr,
                            style: regularDefault.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      press: () {
                        if (!controller.isAppleSignInLoading) {
                          controller.signInWithApple();
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (controller.authRepo.apiClient.isGoogleLoginEnabled() == true || controller.authRepo.apiClient.isAppleLoginEnabled() == true) ...[
              spaceDown(Dimensions.space20),
              const LoginOrBar(stock: 0.8),
            ],
          ],
        );
      },
    );
  }
}
