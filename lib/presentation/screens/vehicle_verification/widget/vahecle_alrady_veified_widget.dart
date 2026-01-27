import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/vehicle_verification/vehicle_verification_controller.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/column_widget/card_column.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/file_download_dialog/download_dialogue.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

class VehicleAlreadyVerifiedWidget extends StatefulWidget {
  final bool isPending;

  const VehicleAlreadyVerifiedWidget({super.key, this.isPending = false});

  @override
  State<VehicleAlreadyVerifiedWidget> createState() => _VehicleAlreadyVerifiedWidgetState();
}

class _VehicleAlreadyVerifiedWidgetState extends State<VehicleAlreadyVerifiedWidget> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<VehicleVerificationController>(
      builder: (controller) {
        return Container(
          padding: const EdgeInsets.all(Dimensions.space15),
          decoration: BoxDecoration(
            color: MyColor.getCardBgColor(),
            borderRadius: BorderRadius.circular(Dimensions.space12),
            boxShadow: MyUtils.getCardShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: Dimensions.space10),
              if (controller.pendingData.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (controller.selectedService.id != '-1') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        margin: const EdgeInsets.only(right: 16),
                        width: Dimensions.space50 * 1.8,
                        decoration: BoxDecoration(
                          color: MyColor.colorWhite,
                          borderRadius: BorderRadius.circular(
                            Dimensions.mediumRadius,
                          ),
                          border: Border.all(
                            color: MyColor.primaryColor,
                            width: 1.5,
                          ),
                        ),
                        child: FittedBox(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MyImageWidget(
                                imageUrl: controller.selectedService.imageWithPath ?? '',
                                height: 40,
                                width: 60,
                                radius: 1,
                              ),
                              spaceDown(Dimensions.space5),
                              FittedBox(
                                child: Text(
                                  controller.selectedService.name ?? '',
                                  style: regularDefault.copyWith(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (controller.selectedBrand.id != '-1') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        margin: const EdgeInsets.only(left: 8),
                        width: Dimensions.space50 * 1.8,
                        decoration: BoxDecoration(
                          color: MyColor.colorWhite,
                          borderRadius: BorderRadius.circular(
                            Dimensions.mediumRadius,
                          ),
                          border: Border.all(
                            color: MyColor.primaryColor,
                            width: 1.5,
                          ),
                        ),
                        child: FittedBox(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MyImageWidget(
                                imageUrl: controller.selectedBrand.imageWithPath ?? '',
                                height: 40,
                                width: 60,
                                radius: 1,
                              ),
                              spaceDown(Dimensions.space5),
                              FittedBox(
                                child: Text(
                                  controller.selectedBrand.name ?? '',
                                  style: regularDefault.copyWith(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Dimensions.space20),
                Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.pendingData.length,
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.all(Dimensions.space8),
                          margin: const EdgeInsets.symmetric(
                            vertical: Dimensions.space10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: MyColor.borderColor,
                              width: .5,
                            ),
                            borderRadius: BorderRadius.circular(
                              Dimensions.defaultRadius,
                            ),
                          ),
                          child: controller.pendingData[index].type == "file"
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.pendingData[index].name ?? '',
                                      style: semiBoldDefault.copyWith(
                                        fontSize: Dimensions.fontDefault,
                                      ),
                                    ),
                                    const SizedBox(height: Dimensions.space5),
                                    GestureDetector(
                                      onTap: () {
                                        String url = "${UrlContainer.domainUrl}/${controller.path}/${controller.pendingData[index].value.toString()}";
                                        printX(url);
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return DownloadingDialog(
                                              url: url,
                                              fileName: MyStrings.kycData,
                                            );
                                          },
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.file_download,
                                            size: 17,
                                            color: MyColor.primaryColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            MyStrings.attachment.tr,
                                            style: regularDefault.copyWith(
                                              color: MyColor.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : CardColumn(
                                  header: controller.pendingData[index].name ?? '',
                                  body: StringConverter.removeQuotationAndSpecialCharacterFromString(
                                    controller.pendingData[index].value ?? '',
                                  ),
                                  headerTextStyle: semiBoldDefault.copyWith(
                                    fontSize: Dimensions.fontDefault,
                                  ),
                                  bodyTextStyle: regularDefault.copyWith(),
                                  bodyMaxLine: 3,
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: Dimensions.space20),
                  ],
                ),
                if (controller.selectedRiderRules.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(Dimensions.space5),
                    child: HeaderText(
                      text: MyStrings.selectedRideRules,
                      style: boldMediumLarge.copyWith(),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.selectedRiderRules.length,
                    itemBuilder: (context, index) {
                      return CheckboxListTile(
                        activeColor: MyColor.getPrimaryColor(),
                        title: Text(
                          controller.selectedRiderRules[index].name ?? '',
                          style: regularLarge.copyWith(
                            color: MyColor.getRideSubTitleColor(),
                          ),
                        ),
                        value: true,
                        onChanged: (value) {},
                      );
                    },
                  ),
                ],
                const SizedBox(height: Dimensions.space20),
                RoundedButton(
                  text: MyStrings.backToHome,
                  press: () {
                    Get.back();
                  },
                ),
                const SizedBox(height: Dimensions.space20),
              ] else ...[
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: context.height / 4),
                      SvgPicture.asset(
                        widget.isPending ? MyImages.pendingIcon : MyImages.verifiedIcon,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 25),
                      Text(
                        widget.isPending ? MyStrings.kycUnderReviewMsg.tr : MyStrings.kycAlreadyVerifiedMsg.tr,
                        style: regularDefault.copyWith(
                          color: MyColor.colorBlack,
                          fontSize: Dimensions.fontExtraLarge,
                        ),
                      ),
                      SizedBox(height: context.height / 4),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
