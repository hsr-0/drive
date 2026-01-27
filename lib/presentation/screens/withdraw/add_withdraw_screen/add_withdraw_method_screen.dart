import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/withdraw/add_withdraw_screen/widget/withdraw_method_list_bottom_sheet.dart';

import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/my_strings.dart';
import '../../../../data/controller/withdraw/add_new_withdraw_controller.dart';
import '../../../../data/repo/withdraw/withdraw_repo.dart';
import '../../../components/app-bar/custom_appbar.dart';
import '../../../components/custom_loader/custom_loader.dart';
import '../../../components/text-form-field/custom_drop_down_button_with_text_field2.dart';
import 'info_widget.dart';

class AddWithdrawMethod extends StatefulWidget {
  const AddWithdrawMethod({super.key});

  @override
  State<AddWithdrawMethod> createState() => _AddWithdrawMethodState();
}

class _AddWithdrawMethodState extends State<AddWithdrawMethod> {
  @override
  void initState() {
    Get.put(WithdrawRepo(apiClient: Get.find()));
    final controller = Get.put(AddNewWithdrawController(repo: Get.find()));

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadDepositMethod();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AddNewWithdrawController>(
      builder: (controller) {
        return Scaffold(
          backgroundColor: MyColor.getScreenBgColor(),
          appBar: CustomAppBar(
            title: MyStrings.withdraw.tr,
            actionsWidget: [
              CustomAppCard(
                width: Dimensions.space40,
                height: Dimensions.space40,
                padding: EdgeInsets.all(Dimensions.space5),
                radius: Dimensions.largeRadius,
                onPressed: () {
                  Get.toNamed(RouteHelper.withdrawScreen);
                },
                child: MyLocalImageWidget(
                  imagePath: MyIcons.recentHistory,
                  width: Dimensions.space35,
                  height: Dimensions.space35,
                  imageOverlayColor: MyColor.getPrimaryColor(),
                  boxFit: BoxFit.contain,
                ),
              ),
              spaceSide(Dimensions.space10),
            ],
          ),
          body: controller.isLoading
              ? const CustomLoader()
              : SingleChildScrollView(
                  padding: Dimensions.screenPaddingHV,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomAppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HeaderText(
                              text: MyStrings.paymentMethod,
                              style: regularDefault.copyWith(
                                color: MyColor.getTextColor(),
                                fontSize: Dimensions.fontNormal,
                              ),
                            ),
                            spaceDown(Dimensions.space5),
                            InkWell(
                              onTap: () {
                                CustomBottomSheet(
                                  child: WithdrawMethodListBottomSheet(),
                                ).customBottomSheet(context);
                              },
                              child: InnerShadowContainer(
                                width: double.infinity,
                                backgroundColor: MyColor.neutral50,
                                borderRadius: Dimensions.largeRadius,
                                blur: 6,
                                offset: Offset(3, 3),
                                shadowColor: MyColor.colorBlack.withValues(
                                  alpha: 0.04,
                                ),
                                isShadowTopLeft: true,
                                isShadowBottomRight: true,
                                padding: EdgeInsetsGeometry.symmetric(
                                  vertical: Dimensions.space16,
                                  horizontal: Dimensions.space16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        controller.withdrawMethod?.id == -1
                                            ? Image.asset(
                                                MyImages.amount,
                                                width: Dimensions.space35,
                                                height: Dimensions.space35,
                                                fit: BoxFit.fitWidth,
                                                color: MyColor.primaryColor,
                                              )
                                            : MyImageWidget(
                                                imageUrl: "${UrlContainer.domainUrl}/${controller.imagePath}/${controller.withdrawMethod?.image}",
                                                width: Dimensions.space30,
                                                height: Dimensions.space30,
                                                boxFit: BoxFit.fitWidth,
                                                radius: 4,
                                              ),
                                        const SizedBox(
                                          width: Dimensions.space10,
                                        ),
                                        Text(
                                          (controller.withdrawMethod?.name ?? '').tr,
                                          style: regularDefault,
                                        ),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: MyColor.iconColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: Dimensions.space15),
                            CustomTextField(
                              labelText: MyStrings.amount.tr,
                              labelWidget: Column(
                                children: [
                                  HeaderText(
                                    text: MyStrings.amount,
                                    style: regularDefault.copyWith(
                                      color: MyColor.getTextColor(),
                                      fontSize: Dimensions.fontNormal,
                                    ),
                                  ),
                                  spaceDown(Dimensions.space5),
                                ],
                              ),
                              hintText: MyStrings.enterAmount.tr,
                              inputAction: TextInputAction.done,
                              textInputType: TextInputType.number,
                              isShowSuffixIcon: true,
                              suffixWidget: Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: Dimensions.space12,
                                  end: Dimensions.space8,
                                ),
                                child: Center(
                                  child: Text(
                                    controller.currency,
                                    style: boldDefault.copyWith(
                                      color: MyColor.getPrimaryColor(),
                                      fontSize: Dimensions.fontLarge,
                                    ),
                                  ),
                                ),
                              ),
                              controller: controller.amountController,
                              onChanged: (value) {
                                if (value.toString().isEmpty) {
                                  controller.changeInfoWidgetValue(0);
                                } else {
                                  double amount = double.tryParse(value.toString()) ?? 0;
                                  controller.changeInfoWidgetValue(amount);
                                }
                                return;
                              },
                            ),
                            Visibility(
                              visible: controller.authorizationList.length > 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: Dimensions.space15),
                                  CustomDropDownTextField2(
                                    labelText: MyStrings.authorizationMethod.tr,
                                    selectedValue: controller.selectedAuthorizationMode,
                                    onChanged: (value) {
                                      controller.changeAuthorizationMode(value);
                                    },
                                    items: controller.authorizationList.map((
                                      String value,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          (value.toString()).tr,
                                          style: regularDefault.copyWith(
                                            color: MyColor.getTextColor(),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      controller.mainAmount > 0 ? const InfoWidget() : const SizedBox.shrink(),
                      const SizedBox(height: Dimensions.space30),
                      RoundedButton(
                        isLoading: controller.submitLoading,
                        text: MyStrings.submit.tr,
                        press: () {
                          controller.submitWithdrawRequest();
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
