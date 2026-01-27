import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/auth/forget_password/reset_password_controller.dart';
import 'package:ovoride_driver/data/repo/auth/login_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/components/will_pop_widget.dart';
import 'package:ovoride_driver/presentation/screens/auth/auth_background.dart';
import 'package:ovoride_driver/presentation/screens/auth/registration/widget/validation_widget.dart';
import '../../../../../core/utils/my_icons.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    Get.put(LoginRepo(apiClient: Get.find()));
    final controller = Get.put(ResetPasswordController(loginRepo: Get.find()));

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.email = Get.arguments[0];
      controller.code = Get.arguments[1];
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
        child: Scaffold(
          backgroundColor: MyColor.colorWhite,
          body: GetBuilder<ResetPasswordController>(
            builder: (controller) => SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthBackgroundWidget(
                      colors: [MyColor.colorWhite.withValues(alpha: 0.9), MyColor.colorWhite.withValues(alpha: 0.8)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: Dimensions.space5,
                              ),
                              child: IconButton(
                                onPressed: () {
                                  Get.offAllNamed(RouteHelper.loginScreen);
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: Dimensions.space30,
                                  color: MyColor.getHeadingTextColor(),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Dimensions.space20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  MyStrings.resetPassword.tr,
                                  style: boldExtraLarge.copyWith(
                                    fontSize: 32,
                                    color: MyColor.getHeadingTextColor(),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                spaceDown(Dimensions.space5),
                                Text(
                                  MyStrings.resetPassContent.tr,
                                  style: regularDefault.copyWith(
                                    color: MyColor.getBodyTextColor(),
                                    fontSize: Dimensions.fontLarge,
                                  ),
                                ),
                                spaceDown(Dimensions.space40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -Dimensions.space20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: MyColor.colorWhite,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(Dimensions.radius25),
                            topRight: Radius.circular(Dimensions.radius25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MyColor.colorBlack.withValues(alpha: 0.05), // soft top shadow
                              offset: const Offset(0, -30), // ⬆️ Shadow goes up
                              blurRadius: 15,
                              spreadRadius: -3,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(horizontal: Dimensions.space20, vertical: Dimensions.space20),
                        child: Column(
                          children: [
                            const SizedBox(height: Dimensions.space15),
                            Focus(
                              onFocusChange: (hasFocus) {
                                controller.changePasswordFocus(hasFocus);
                              },
                              child: CustomTextField(
                                focusNode: controller.passwordFocusNode,
                                nextFocus: controller.confirmPasswordFocusNode,
                                labelText: MyStrings.password.tr,
                                hintText: MyStrings.password,
                                isShowSuffixIcon: true,
                                isPassword: true,
                                textInputType: TextInputType.text,
                                controller: controller.passController,
                                prefixIcon: Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: Dimensions.space12,
                                    end: Dimensions.space8,
                                  ),
                                  child: CustomSvgPicture(
                                    image: MyIcons.password,
                                    color: MyColor.primaryColor,
                                    height: Dimensions.space30,
                                  ),
                                ),
                                validator: (value) {
                                  return controller.validatePassword(value);
                                },
                                onChanged: (value) {
                                  if (controller.checkPasswordStrength) {
                                    controller.updateValidationList(value);
                                  }
                                  return;
                                },
                              ),
                            ),
                            Visibility(
                              visible: controller.hasPasswordFocus && controller.checkPasswordStrength,
                              child: ValidationWidget(
                                list: controller.passwordValidationRules,
                                fromReset: true,
                              ),
                            ),
                            const SizedBox(height: Dimensions.space15),
                            CustomTextField(
                              inputAction: TextInputAction.done,
                              isPassword: true,
                              labelText: MyStrings.confirmPassword.tr,
                              hintText: MyStrings.confirmYourPassword.tr,
                              isShowSuffixIcon: true,
                              controller: controller.confirmPassController,
                              prefixIcon: Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: Dimensions.space12,
                                  end: Dimensions.space8,
                                ),
                                child: CustomSvgPicture(
                                  image: MyIcons.password,
                                  color: MyColor.primaryColor,
                                  height: Dimensions.space30,
                                ),
                              ),
                              onChanged: (value) {
                                return;
                              },
                              validator: (value) {
                                if (controller.passController.text.toLowerCase() != controller.confirmPassController.text.toLowerCase()) {
                                  return MyStrings.kMatchPassError.tr;
                                } else {
                                  return null;
                                }
                              },
                            ),
                            const SizedBox(height: Dimensions.space35),
                            RoundedButton(
                              text: MyStrings.submit.tr,
                              isLoading: controller.submitLoading,
                              press: () {
                                if (formKey.currentState!.validate()) {
                                  controller.resetPassword();
                                }
                              },
                            ),
                          ],
                        ),
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
