import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/auth/forget_password/forget_password_controller.dart';
import 'package:ovoride_driver/data/repo/auth/login_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/screens/auth/auth_background.dart';

import '../../../../../core/utils/my_icons.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    Get.put(LoginRepo(apiClient: Get.find()));
    Get.put(ForgetPasswordController(loginRepo: Get.find()));

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegionWidget(
      statusBarColor: Colors.transparent,
      child: Scaffold(
        backgroundColor: MyColor.colorWhite,
        body: GetBuilder<ForgetPasswordController>(
          builder: (auth) => SingleChildScrollView(
            child: Column(
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
                              MyStrings.forgotPassword.tr,
                              style: boldExtraLarge.copyWith(
                                fontSize: 32,
                                color: MyColor.getHeadingTextColor(),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            spaceDown(Dimensions.space5),
                            Text(
                              MyStrings.forgetPasswordSubText.tr,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              spaceDown(Dimensions.space40),
                              CustomTextField(
                                // labelText: MyStrings.usernameOrEmail.tr,
                                hintText: MyStrings.usernameOrEmailHint.tr,
                                textInputType: TextInputType.emailAddress,
                                inputAction: TextInputAction.done,
                                controller: auth.emailOrUsernameController,
                                prefixIcon: Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: Dimensions.space12,
                                    end: Dimensions.space8,
                                  ),
                                  child: CustomSvgPicture(
                                    image: MyIcons.user,
                                    color: MyColor.primaryColor,
                                    height: Dimensions.space30,
                                  ),
                                ),
                                onSuffixTap: () {},
                                onChanged: (value) {
                                  return;
                                },
                                validator: (value) {
                                  if (auth.emailOrUsernameController.text.isEmpty) {
                                    return MyStrings.enterEmailOrUserName.tr;
                                  } else {
                                    return null;
                                  }
                                },
                              ),
                              const SizedBox(height: Dimensions.space25),
                              RoundedButton(
                                isLoading: auth.submitLoading,
                                press: () {
                                  if (_formKey.currentState!.validate()) {
                                    auth.submitForgetPassCode();
                                  }
                                },
                                text: MyStrings.submit.tr,
                              ),
                              const SizedBox(height: Dimensions.space40),
                            ],
                          ),
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
    );
  }
}
