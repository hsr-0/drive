import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';

import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/timeline/custom_time_line.dart';

class RideDestination extends StatelessWidget {
  final RideModel ride;
  const RideDestination({required this.ride, super.key});

  @override
  Widget build(BuildContext context) {
    return CustomTimeLine(
      firstIndicatorColor: MyColor.getPrimaryColor(),
      indicatorPosition: 0.1,
      dashColor: MyColor.getPrimaryColor(),
      firstWidget: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                MyStrings.pickUpLocation.tr,
                style: regularDefault.copyWith(
                  color: MyColor.getBodyTextColor(),
                  fontSize: Dimensions.fontSmall,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            spaceDown(Dimensions.space5),
            Text(
              ride.pickupLocation ?? '',
              style: boldLarge.copyWith(
                color: MyColor.getHeadingTextColor(),
                fontSize: Dimensions.fontNormal,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            spaceDown(Dimensions.space5),
            Divider(color: MyColor.neutral200),
            spaceDown(Dimensions.space5),
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
                style: regularDefault.copyWith(
                  color: MyColor.getBodyTextColor(),
                  fontSize: Dimensions.fontSmall,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: Dimensions.space5 - 1),
            Text(
              ride.destination ?? '',
              style: boldLarge.copyWith(
                color: MyColor.getHeadingTextColor(),
                fontSize: Dimensions.fontNormal,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
