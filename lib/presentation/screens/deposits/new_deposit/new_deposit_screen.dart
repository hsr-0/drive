import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/deposits/new_deposit/widget/payment_method_list_bottom_sheet.dart';

import '../../../../core/utils/dimensions.dart';
import '../../../../core/utils/my_color.dart';
import '../../../../core/utils/my_strings.dart';
import '../../../../data/controller/deposit/add_new_deposit_controller.dart';
import '../../../../data/repo/deposit/deposit_repo.dart';
import '../../../components/app-bar/custom_appbar.dart';
import '../../../components/buttons/rounded_button.dart';
import '../../../components/custom_loader/custom_loader.dart';
import 'info_widget.dart';

class NewDepositScreen extends StatefulWidget {
  const NewDepositScreen({super.key});

  @override
  State<NewDepositScreen> createState() => _NewDepositScreenState();
}

class _NewDepositScreenState extends State<NewDepositScreen> {
  @override
  void initState() {
    Get.put(DepositRepo(apiClient: Get.find()));
    final controller = Get.put(
      AddNewDepositController(depositRepo: Get.find()),
    );
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.getDepositMethod();
    });
  }

  @override
  void dispose() {
    Get.find<AddNewDepositController>().clearData();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AddNewDepositController>(
      builder: (controller) => Scaffold(
        backgroundColor: MyColor.getScreenBgColor(),
        appBar: CustomAppBar(
          title: MyStrings.deposit,
          actionsWidget: [
            CustomAppCard(
              width: Dimensions.space40,
              height: Dimensions.space40,
              padding: EdgeInsets.all(Dimensions.space7),
              radius: Dimensions.largeRadius,
              onPressed: () {
                Get.toNamed(RouteHelper.depositsScreen);
              },
              child: MyLocalImageWidget(
                imagePath: MyIcons.recentHistory,
                width: Dimensions.space30,
                height: Dimensions.space30,
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
                child: Form(
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
                                  child: PaymentMethodListBottomSheet(),
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
                                        MyImageWidget(
                                          imageUrl: "${UrlContainer.domainUrl}/${controller.imagePath}/${controller.paymentMethod?.method?.image}",
                                          width: Dimensions.space30,
                                          height: Dimensions.space30,
                                          boxFit: BoxFit.fitWidth,
                                          radius: 4,
                                        ),
                                        const SizedBox(
                                          width: Dimensions.space10,
                                        ),
                                        Text(
                                          (controller.paymentMethod?.method?.name ?? '').tr,
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
                              isShowSuffixIcon: true,
                              isPassword: false,
                              textInputType: TextInputType.number,
                              inputAction: TextInputAction.done,
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
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return MyStrings.fieldErrorMsg.tr;
                                } else {
                                  return null;
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      controller.paymentMethod?.name != MyStrings.selectOne ? const InfoWidget() : const SizedBox(),
                      const SizedBox(height: 35),
                      RoundedButton(
                        isLoading: controller.submitLoading,
                        text: MyStrings.submit,
                        width: double.infinity,
                        press: () {
                          controller.submitDeposit();
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
