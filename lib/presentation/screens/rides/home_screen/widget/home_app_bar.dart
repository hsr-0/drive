import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/controller/dashboard/dashboard_controller.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/switch/lite_rolling_switch.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

class HomeScreenAppBar extends StatelessWidget {
  DashBoardController controller;
  HomeScreenAppBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Dimensions.space16,
          vertical: Dimensions.space16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Get.toNamed(RouteHelper.profileScreen);
                        },
                        child: MyImageWidget(
                          imageUrl: '${UrlContainer.domainUrl}/${controller.userImagePath}/${controller.driver.image}',
                          height: 50,
                          width: 50,
                          radius: 50,
                          isProfile: true,
                        ),
                      ),
                      spaceSide(Dimensions.space10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: HeaderText(
                                text: controller.driver.id == '-1' ? controller.repo.apiClient.getUserName().toTitleCase() : controller.driver.getFullName(),
                                style: boldLarge.copyWith(
                                  color: MyColor.getTextColor(),
                                  fontSize: Dimensions.fontLarge,
                                ),
                              ),
                            ),
                            spaceDown(Dimensions.space3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomSvgPicture(
                                  image: MyIcons.currentLocation,
                                  color: MyColor.primaryColor,
                                ),
                                spaceSide(Dimensions.space5),
                                Expanded(
                                  child: Text(
                                    controller.currentAddress,
                                    style: regularDefault.copyWith(
                                      color: MyColor.getBodyTextColor(),
                                      fontSize: Dimensions.fontDefault,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            spaceDown(Dimensions.space2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Dimensions.space30),
                SizedBox(
                  height: Dimensions.space45,
                  child: LiteRollingSwitch(
                    tValue: controller.userOnline,
                    width: Dimensions.space50 + 60,
                    textOn: MyStrings.onLine.tr,
                    textOnColor: MyColor.colorWhite,
                    textOff: MyStrings.offLine.tr,
                    colorOn: MyColor.colorGreen,
                    colorOff: MyColor.colorGrey,
                    iconOn: Icons.network_check,
                    iconOff: Icons.signal_wifi_off,
                    animationDuration: const Duration(milliseconds: 300),
                    onToggle: (newValue) async {
                      try {
                        // Your API call or auth check
                        await controller.changeOnlineStatus(newValue);
                        return true; // Success - allow UI to change
                      } catch (e) {
                        // Auth shutdown or error occurred
                        return false; // Failure - revert UI
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
