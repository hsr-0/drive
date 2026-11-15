import 'package:ovoride_driver/core/helper/date_converter.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';

import '../../../../components/divider/custom_spacer.dart';
import '../../../../components/dotted_border/dotted_border.dart';
import '../../../../components/timeline/custom_time_line.dart';

class NewRideCardWidget extends StatelessWidget {
  bool isActive;
  String currency;
  String driverImagePath;
  RideModel ride;
  VoidCallback press;
  bool isShowMapButton;
  NewRideCardWidget({
    super.key,
    required this.isActive,
    required this.press,
    required this.currency,
    required this.ride,
    required this.driverImagePath,
    this.isShowMapButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: CustomAppCard(
        backgroundColor: MyColor.getCardBgColor(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      MyImageWidget(
                        imageUrl: driverImagePath,
                        height: 45,
                        width: 45,
                        radius: 22,
                        isProfile: true,
                      ),
                      const SizedBox(width: Dimensions.space10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ride.user?.firstname} ${ride.user?.lastname}'.toTitleCase(),
                              overflow: TextOverflow.ellipsis,
                              style: boldMediumLarge,
                            ),
                            spaceDown(Dimensions.space5),
                            FittedBox(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${ride.duration}, ${ride.getDistance()} ${MyUtils.getDistanceLabel(distance: ride.distance, unit: Get.find<ApiClient>().getDistanceUnit())}",
                                    style: boldDefault.copyWith(
                                      color: MyColor.primaryColor,
                                      fontSize: Dimensions.fontDefault,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: Dimensions.space8),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                spaceSide(Dimensions.space10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      child: Row(
                        children: [
                          Icon(Icons.group, color: MyColor.primaryColor),
                          SizedBox(width: Dimensions.space2),
                          Text(
                            "${ride.numberOfPassenger}",
                            overflow: TextOverflow.ellipsis,
                            style: boldLarge.copyWith(
                              fontSize: Dimensions.fontExtraLarge,
                              fontWeight: FontWeight.w900,
                              color: MyColor.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FittedBox(
                      child: Text(
                        "$currency${StringConverter.formatNumber(ride.amount.toString())}",
                        overflow: TextOverflow.ellipsis,
                        style: boldLarge.copyWith(
                          fontSize: Dimensions.fontExtraLarge,
                          fontWeight: FontWeight.w900,
                          color: MyColor.rideTitle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Dimensions.space20),
            CustomTimeLine(
              indicatorPosition: 0.1,
              dashColor: MyColor.neutral300,
              firstWidget: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        MyStrings.pickUpLocation.tr,
                        style: boldLarge.copyWith(
                          color: MyColor.getHeadingTextColor(),
                          fontSize: Dimensions.fontTitleLarge,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    spaceDown(Dimensions.space5),
                    Text(
                      ride.pickupLocation ?? '',
                      style: regularDefault.copyWith(
                        color: MyColor.getBodyTextColor(),
                        fontSize: Dimensions.fontDefault,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ride.startTime != null) ...[
                      spaceDown(Dimensions.space8),
                      Text(
                        DateConverter.estimatedDate(
                          DateTime.tryParse('${ride.startTime}') ?? DateTime.now(),
                        ),
                        style: regularDefault.copyWith(
                          color: MyColor.bodyMutedTextColor,
                          fontSize: Dimensions.fontSmall,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    spaceDown(Dimensions.space15),
                  ],
                ),
              ),
              secondWidget: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        MyStrings.destination.tr,
                        style: boldLarge.copyWith(
                          color: MyColor.getHeadingTextColor(),
                          fontSize: Dimensions.fontTitleLarge,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: Dimensions.space5 - 1),
                    Text(
                      ride.destination ?? '',
                      style: regularDefault.copyWith(
                        color: MyColor.getBodyTextColor(),
                        fontSize: Dimensions.fontDefault,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ride.endTime != null) ...[
                      spaceDown(Dimensions.space8),
                      Text(
                        DateConverter.estimatedDate(
                          DateTime.tryParse('${ride.endTime}') ?? DateTime.now(),
                        ),
                        style: regularDefault.copyWith(
                          color: MyColor.bodyMutedTextColor,
                          fontSize: Dimensions.fontSmall,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            spaceDown(Dimensions.space10),
            const DottedLine(),
            spaceDown(Dimensions.space15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Dimensions.space10),
              decoration: BoxDecoration(
                color: MyColor.bodyTextBgColor,
                borderRadius: BorderRadius.circular(Dimensions.space5),
              ),
              child: Text(
                MyStrings.recommendedPrice.rKv({
                  "priceKey": "$currency${StringConverter.formatNumber(ride.recommendAmount.toString())}",
                  "distanceKey": "${ride.getDistance()} ${MyUtils.getDistanceLabel(distance: ride.distance, unit: Get.find<ApiClient>().getDistanceUnit())}",
                }).tr,
                style: regularDefault.copyWith(
                  color: MyColor.getBodyTextColor(),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Dimensions.space10),
          ],
        ),
      ),
    );
  }
}
