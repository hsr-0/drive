import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/account/profile_controller.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/shimmer/profiler_shimmer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

class ProfileAndSettingsScreenAppBar extends StatelessWidget {
  ProfileController controller;
  ProfileAndSettingsScreenAppBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: controller.isLoading
          ? ProfilerShimmer()
          : Container(
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
                        child: GestureDetector(
                          onTap: () => Get.toNamed(RouteHelper.profileScreen),
                          child: Row(
                            children: [
                              MyImageWidget(
                                imageUrl: controller.imageUrl,
                                height: Dimensions.space50,
                                width: Dimensions.space50,
                                radius: 50,
                                isProfile: true,
                              ),
                              spaceSide(Dimensions.space10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: HeaderText(
                                        text: controller.driver.getFullName(),
                                        style: boldLarge.copyWith(
                                          color: MyColor.getTextColor(),
                                          fontSize: Dimensions.fontLarge,
                                        ),
                                      ),
                                    ),
                                    spaceDown(Dimensions.space3),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          MyIcons.telePhone,
                                          colorFilter: ColorFilter.mode(
                                            MyColor.getPrimaryColor(),
                                            BlendMode.srcIn,
                                          ),
                                          height: Dimensions.fontLarge,
                                          width: Dimensions.fontLarge,
                                          fit: BoxFit.contain,
                                        ),
                                        spaceSide(Dimensions.space5),
                                        Text(
                                          "+${controller.driver.dialCode ?? ""}${controller.driver.mobile ?? ""}",
                                          style: regularDefault.copyWith(
                                            fontSize: Dimensions.fontLarge,
                                            color: MyColor.getBodyTextColor(),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                      ),
                      SizedBox(width: Dimensions.space30),
                      Container(
                        decoration: BoxDecoration(
                          color: MyColor.colorWhite,
                          borderRadius: BorderRadius.circular(
                            Dimensions.space20,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MyColor.colorBlack.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: Offset(0, 0),
                            ),
                            BoxShadow(
                              color: MyColor.colorBlack.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.space12,
                          vertical: Dimensions.space7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: MyColor.colorOrange,
                              size: Dimensions.space30,
                            ),
                            spaceSide(Dimensions.space5),
                            Text(
                              controller.driver.avgRating == '0.00' ? MyStrings.nA.tr : (controller.driver.avgRating ?? ''),
                              style: boldDefault.copyWith(
                                fontSize: Dimensions.fontLarge,
                                color: MyColor.getHeadingTextColor(),
                              ),
                            ),
                            spaceSide(Dimensions.space5),
                          ],
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
