import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/auth/auth/registration_controller.dart';
import 'package:ovoride_driver/data/repo/auth/general_setting_repo.dart';
import 'package:ovoride_driver/data/repo/auth/signup_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/custom_no_data_found_class.dart';
import 'package:ovoride_driver/presentation/components/will_pop_widget.dart';
import 'package:ovoride_driver/presentation/screens/auth/auth_background.dart';
import 'package:ovoride_driver/presentation/screens/auth/registration/widget/registration_form.dart';

import '../../../components/divider/custom_spacer.dart';
import '../social_auth/social_auth_section.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  @override
  void initState() {
    Get.put(GeneralSettingRepo(apiClient: Get.find()));
    Get.put(RegistrationRepo(apiClient: Get.find()));
    Get.put(
      RegistrationController(
        registrationRepo: Get.find(),
        generalSettingRepo: Get.find(),
      ),
    );

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<RegistrationController>().initData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopWidget(
      nextRoute: RouteHelper.loginScreen,
      child: AnnotatedRegionWidget(
        statusBarColor: Colors.transparent,
        child: GetBuilder<RegistrationController>(
          builder: (controller) => Scaffold(
            backgroundColor: MyColor.colorWhite,
            body: controller.noInternet
                ? NoDataOrInternetScreen(
                    isNoInternet: true,
                    onChanged: () {
                      controller.initData();
                    },
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuthBackgroundWidget(
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
                                      color: MyColor.colorWhite,
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
                                      MyStrings.regScreenTitle.tr,
                                      style: boldExtraLarge.copyWith(
                                        fontSize: 32,
                                        color: MyColor.colorWhite,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    spaceDown(Dimensions.space5),
                                    Text(
                                      MyStrings.regScreenSubTitle.tr,
                                      style: regularDefault.copyWith(
                                        color: MyColor.colorWhite,
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
                                spaceDown(Dimensions.space20),
                                SocialAuthSection(
                                  googleAuthTitle: MyStrings.google,
                                ),
                                spaceDown(Dimensions.space15),
                                const RegistrationForm(),
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
    );
  }
}
