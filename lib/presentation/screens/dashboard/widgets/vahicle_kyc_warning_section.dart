import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/dashboard/dashboard_controller.dart';

import '../../../../core/utils/my_images.dart';

class VehicleKYCWarningSection extends StatelessWidget {
  const VehicleKYCWarningSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashBoardController>(
      builder: (controller) {
        return Visibility(
          visible: !controller.isVehicleVerified && !controller.isLoading,
          child: InkWell(
            splashColor: MyColor.primaryColor.withValues(alpha: 0.2),
            onTap: () {
              Get.toNamed(RouteHelper.vehicleVerificationScreen)?.then((value) {
                controller.loadData();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Card(
                color: MyColor.colorWhite,
                elevation: 1,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(
                    left: Dimensions.space15,
                    right: Dimensions.space15,
                    top: 0,
                    bottom: Dimensions.space1,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.defaultRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  controller.isVehicleVerificationPending ? MyStrings.yourVehicleVerificationUnderReview.tr : MyStrings.pleaseVerifyYourVehicle.tr,
                                  style: semiBoldDefault.copyWith(
                                    color: controller.isVehicleVerificationPending ? MyColor.pendingColor : MyColor.redCancelTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Dimensions.space5),
                            Text(
                              controller.isVehicleVerificationPending ? MyStrings.waitUntilAdminApprovedYourVerificationRequest.tr : MyStrings.verifyVehicleAndStartRide.tr,
                              style: regularDefault.copyWith(
                                fontSize: Dimensions.fontExtraSmall,
                                color: MyColor.colorBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SvgPicture.asset(
                        MyImages.verification,
                        width: 23,
                        height: 23,
                        colorFilter: ColorFilter.mode(
                          controller.isVehicleVerificationPending ? MyColor.pendingColor : MyColor.redCancelTextColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
