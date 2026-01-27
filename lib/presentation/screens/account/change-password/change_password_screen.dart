import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/account/change_password_controller.dart';
import 'package:ovoride_driver/data/repo/account/change_password_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/app-bar/custom_appbar.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/account/change-password/widget/change_password_form.dart';

import '../../../../core/utils/dimensions.dart';
import '../../../components/card/app_body_card.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  @override
  void initState() {
    Get.put(ChangePasswordRepo(apiClient: Get.find()));
    Get.put(ChangePasswordController(changePasswordRepo: Get.find()));
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<ChangePasswordController>().clearData();
    });
  }

  @override
  void dispose() {
    Get.find<ChangePasswordController>().clearData();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegionWidget(
      child: Scaffold(
        backgroundColor: MyColor.secondaryScreenBgColor,
        appBar: CustomAppBar(
          title: MyStrings.changePassword.tr,
          isShowBackBtn: true,
        ),
        body: GetBuilder<ChangePasswordController>(
          builder: (controller) {
            return SingleChildScrollView(
              padding: Dimensions.screenPaddingHV,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: Dimensions.space15,
                    ),
                    child: AppBodyWidgetCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              MyStrings.changePassword.tr,
                              style: boldDefault.copyWith(
                                color: MyColor.getHeadingTextColor(),
                                fontSize: Dimensions.fontOverLarge22,
                              ),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              MyStrings.createPasswordSubText.tr,
                              textAlign: TextAlign.center,
                              style: regularDefault.copyWith(
                                color: MyColor.getBodyTextColor(),
                              ),
                            ),
                          ),
                          spaceDown(Dimensions.space30),
                          const ChangePasswordForm(),
                        ],
                      ),
                    ),
                  ),
                  spaceDown(Dimensions.space30),
                  InkWell(
                    onTap: () {
                      Get.toNamed(RouteHelper.forgotPasswordScreen);
                    },
                    child: HeaderText(
                      text: MyStrings.forgotPassword.tr,
                      style: mediumMediumLarge.copyWith(
                        color: MyColor.redCancelTextColor,
                        fontSize: Dimensions.fontExtraLarge,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
