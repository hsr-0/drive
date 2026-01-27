import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/ride/ride_meassage/ride_meassage_controller.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

class UserDetailsWidget extends StatelessWidget {
  final RideModel ride;
  final String imageUrl;
  const UserDetailsWidget({
    super.key,
    required this.ride,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Get.toNamed(
                RouteHelper.userReviewScreen,
                arguments: ride.user?.id,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    MyImageWidget(
                      imageUrl: '${UrlContainer.domainUrl}/$imageUrl/${ride.user?.avatar}',
                      height: 50,
                      width: 50,
                      radius: Dimensions.radiusHuge,
                      boxFit: BoxFit.contain,
                      isProfile: true,
                    ),
                    Positioned(
                      bottom: -10,
                      right: 0,
                      left: 0,
                      child: Container(
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
                          horizontal: Dimensions.space3,
                          vertical: Dimensions.space3,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: MyColor.colorOrange,
                                size: Dimensions.fontExtraLarge,
                              ),
                              spaceSide(Dimensions.space3),
                              Text(
                                ride.user?.avgRating == '0.00' ? MyStrings.nA.tr : (ride.user?.avgRating ?? ''),
                                style: boldDefault.copyWith(
                                  fontSize: Dimensions.fontSmall,
                                  color: MyColor.getHeadingTextColor(),
                                ),
                              ),
                              spaceSide(Dimensions.space5),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                spaceSide(Dimensions.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HeaderText(
                        text: ride.user?.getFullName() ?? ride.user?.username ?? "",
                        style: boldLarge.copyWith(
                          color: MyColor.getTextColor(),
                          fontSize: Dimensions.fontTitleLarge,
                        ),
                      ),
                      spaceDown(Dimensions.space3),
                      Text(
                        "@${ride.user?.username ?? ""}",
                        style: regularDefault.copyWith(
                          fontSize: Dimensions.fontDefault,
                          color: MyColor.informationColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            GetBuilder<RideMessageController>(
              builder: (msgController) {
                return Badge(
                  backgroundColor: MyColor.redCancelTextColor,
                  isLabelVisible: msgController.unreadMsg != 0,
                  label: Text(
                    msgController.unreadMsg.toString(),
                    style: boldDefault.copyWith(color: MyColor.colorWhite),
                  ),
                  child: CustomAppCard(
                    radius: Dimensions.largeRadius,
                    backgroundColor: MyColor.getPrimaryColor().withValues(
                      alpha: 0.1,
                    ),
                    onPressed: () {
                      Get.toNamed(
                        RouteHelper.rideMessageScreen,
                        arguments: [
                          ride.id.toString(),
                          ride.user?.getFullName(),
                          ride.status.toString(),
                        ],
                      );
                    },
                    child: MyLocalImageWidget(
                      imagePath: MyIcons.message,
                      width: Dimensions.space25,
                      height: Dimensions.space25,
                      boxFit: BoxFit.contain,
                      imageOverlayColor: MyColor.getPrimaryColor(),
                    ),
                  ),
                );
              },
            ),
            spaceSide(Dimensions.space10),
            CustomAppCard(
              radius: Dimensions.largeRadius,
              backgroundColor: MyColor.getPrimaryColor().withValues(alpha: 0.1),
              onPressed: () {
                MyUtils.launchPhone('${ride.user?.mobile}');
              },
              child: MyLocalImageWidget(
                imagePath: MyIcons.callIcon,
                width: Dimensions.space25,
                height: Dimensions.space25,
                boxFit: BoxFit.contain,
                imageOverlayColor: MyColor.getPrimaryColor(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
