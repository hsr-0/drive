import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/file_download_dialog/download_dialogue.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';

import '../../../../data/controller/vehicle_verification/vehicle_verification_controller.dart';
import '../../../components/image/my_network_image_widget.dart';

class VehicleVerificationPendingSection extends StatefulWidget {
  final bool isPending;
  final String title;

  const VehicleVerificationPendingSection({
    super.key,
    this.isPending = false,
    this.title = MyStrings.kycUnderReviewMsg,
  });

  @override
  State<VehicleVerificationPendingSection> createState() => _VehicleVerificationPendingSectionState();
}

class _VehicleVerificationPendingSectionState extends State<VehicleVerificationPendingSection> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<VehicleVerificationController>(
      builder: (controller) {
        return Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: MyColor.screenBgColor,
          ),
          child: controller.pendingData.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildColumWidget(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            MyStrings.selectedService,
                            style: semiBoldDefault.copyWith(
                              fontSize: Dimensions.fontDefault,
                              color: MyColor.getHeadingTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Text(
                            "${MyStrings.serviceName.tr} : ${controller.selectedService.name?.tr ?? ''}",
                            style: regularDefault.copyWith(
                              color: MyColor.getBodyTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Center(
                            child: MyImageWidget(
                              imageUrl: "${controller.serviceImagePath}/${controller.selectedService.image ?? ''}",
                              height: 100,
                              width: 100,
                              radius: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    buildColumWidget(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            MyStrings.selectedBrand,
                            style: semiBoldDefault.copyWith(
                              fontSize: Dimensions.fontDefault,
                              color: MyColor.getHeadingTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Text(
                            "${MyStrings.brandName.tr} : ${controller.pendingVehicleData?.brand?.name ?? ''}",
                            style: regularDefault.copyWith(
                              color: MyColor.getBodyTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Center(
                            child: MyImageWidget(
                              imageUrl: "${controller.brandImagePath}/${controller.pendingVehicleData?.brand?.image ?? ''}",
                              height: 100,
                              width: 100,
                              radius: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    buildColumWidget(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            MyStrings.vehicleImage,
                            style: semiBoldDefault.copyWith(
                              fontSize: Dimensions.fontDefault,
                              color: MyColor.getHeadingTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Center(
                            child: MyImageWidget(
                              imageUrl: controller.pendingVehicleData?.imageSrc ?? '',
                              height: 100,
                              width: 100,
                              radius: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    buildColumWidget(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            MyStrings.vehicleColor,
                            style: semiBoldDefault.copyWith(
                              fontSize: Dimensions.fontDefault,
                              color: MyColor.getHeadingTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Text(
                            StringConverter.removeQuotationAndSpecialCharacterFromString(
                              controller.pendingVehicleData?.color?.name ?? '',
                            ),
                            style: regularDefault.copyWith(
                              color: MyColor.getBodyTextColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    buildColumWidget(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            MyStrings.vehicleModel,
                            style: semiBoldDefault.copyWith(
                              fontSize: Dimensions.fontDefault,
                              color: MyColor.getHeadingTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Text(
                            StringConverter.removeQuotationAndSpecialCharacterFromString(
                              controller.pendingVehicleData?.model?.name ?? '',
                            ),
                            style: regularDefault.copyWith(
                              color: MyColor.getBodyTextColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    buildColumWidget(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            MyStrings.vehicleYear,
                            style: semiBoldDefault.copyWith(
                              fontSize: Dimensions.fontDefault,
                              color: MyColor.getHeadingTextColor(),
                            ),
                          ),
                          spaceDown(Dimensions.space10),
                          Text(
                            StringConverter.removeQuotationAndSpecialCharacterFromString(
                              controller.pendingVehicleData?.year?.name ?? '',
                            ),
                            style: regularDefault.copyWith(
                              color: MyColor.getBodyTextColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    spaceDown(Dimensions.space15),
                    ListView.separated(
                      separatorBuilder: (context, index) {
                        return spaceDown(Dimensions.space15);
                      },
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.pendingData.length,
                      itemBuilder: (context, index) {
                        return controller.pendingData[index].value != null && controller.pendingData[index].value!.isNotEmpty
                            ? buildColumWidget(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.pendingData[index].name ?? '',
                                      style: semiBoldDefault.copyWith(
                                        fontSize: Dimensions.fontDefault,
                                        color: MyColor.getHeadingTextColor(),
                                      ),
                                    ),
                                    spaceDown(Dimensions.space10),
                                    if (controller.pendingData[index].type == "file") ...[
                                      GestureDetector(
                                        onTap: () {
                                          String url = "${controller.path}/${controller.pendingData[index].value.toString()}";
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
                                    ] else ...[
                                      Text(
                                        StringConverter.removeQuotationAndSpecialCharacterFromString(
                                          controller.pendingData[index].value ?? '',
                                        ),
                                        style: regularDefault.copyWith(
                                          color: MyColor.getBodyTextColor(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : SizedBox.shrink();
                      },
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomSvgPicture(
                      image: widget.isPending ? MyImages.pendingIcon : MyImages.verifiedIcon,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 25),
                    Text(
                      widget.isPending ? widget.title.tr : MyStrings.kycAlreadyVerifiedMsg.tr,
                      style: regularDefault.copyWith(
                        color: MyColor.colorBlack,
                        fontSize: Dimensions.fontExtraLarge,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
        );
      },
    );
  }

  Widget buildColumWidget({required Widget child}) {
    return InnerShadowContainer(
      width: double.infinity,
      backgroundColor: MyColor.textFieldBgColor,
      borderRadius: Dimensions.largeRadius,
      blur: 6,
      offset: Offset(3, 3),
      shadowColor: MyColor.colorBlack.withValues(alpha: 0.04),
      isShadowTopLeft: true,
      isShadowBottomRight: true,
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsetsGeometry.symmetric(
        horizontal: Dimensions.space10,
        vertical: Dimensions.space15,
      ),
      child: child,
    );
  }
}
