import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/controller/driver_kyc_controller/driver_kyc_controller.dart';
import 'package:ovoride_driver/presentation/components/card/inner_shadow_container.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/file_download_dialog/download_dialogue.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';

class AlreadyVerifiedWidget extends StatefulWidget {
  final bool isPending;
  final String title;

  const AlreadyVerifiedWidget({
    super.key,
    this.isPending = false,
    this.title = MyStrings.kycUnderReviewMsg,
  });

  @override
  State<AlreadyVerifiedWidget> createState() => _AlreadyVerifiedWidgetState();
}

class _AlreadyVerifiedWidgetState extends State<AlreadyVerifiedWidget> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<DriverKycController>(
      builder: (controller) {
        return Container(
          padding: const EdgeInsets.all(Dimensions.space20),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: MyColor.screenBgColor,
          ),
          child: controller.pendingData.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (context, index) {
                    return spaceDown(Dimensions.space15);
                  },
                  itemCount: controller.pendingData.length,
                  itemBuilder: (context, index) {
                    return controller.pendingData[index].value != null && controller.pendingData[index].value!.isNotEmpty
                        ? InnerShadowContainer(
                            width: double.infinity,
                            backgroundColor: MyColor.textFieldBgColor,
                            borderRadius: Dimensions.largeRadius,
                            blur: 6,
                            offset: Offset(3, 3),
                            shadowColor: MyColor.colorBlack.withValues(
                              alpha: 0.04,
                            ),
                            isShadowTopLeft: true,
                            isShadowBottomRight: true,
                            alignment: AlignmentDirectional.centerStart,
                            padding: EdgeInsetsGeometry.symmetric(
                              horizontal: Dimensions.space10,
                              vertical: Dimensions.space10,
                            ),
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
                                const SizedBox(height: Dimensions.space5),
                                if (controller.pendingData[index].type == "file") ...[
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
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
        );
      },
    );
  }
}
