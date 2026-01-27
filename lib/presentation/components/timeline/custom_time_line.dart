import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_icons.dart';
import '../image/custom_svg_picture.dart';

class CustomTimeLine extends StatelessWidget {
  final Widget firstWidget;
  final Widget secondWidget;
  final bool? needScrolling;
  final double? indicatorPosition;
  final Color? dashColor;
  final Color? firstIndicatorColor;
  final Color? secondIndicatorColor;

  const CustomTimeLine({
    super.key,
    required this.firstWidget,
    required this.secondWidget,
    this.needScrolling = false,
    this.dashColor = MyColor.primaryColor,
    this.indicatorPosition = 0.40,
    this.firstIndicatorColor,
    this.secondIndicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Timeline.tileBuilder(
      shrinkWrap: true,
      theme: TimelineThemeData(
        nodePosition: 0,
        indicatorTheme: const IndicatorThemeData(
          size: 15.0,
          color: MyColor.colorBlack,
        ),
        indicatorPosition: indicatorPosition,
        nodeItemOverlap: false,
      ),
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      builder: TimelineTileBuilder.connected(
        contentsBuilder: (context, index) => index == 0 ? firstWidget : secondWidget,
        connectorBuilder: (_, index, __) {
          return DashedLineConnector(
            color: dashColor ?? MyColor.colorBlack,
            thickness: 2,
          );
        },
        indicatorBuilder: (_, index) {
          final indicatorColor = index == 0 ? (firstIndicatorColor ?? MyColor.colorYellow) : (secondIndicatorColor ?? MyColor.highPriorityPurpleColor);
          final icon = index == 0 ? MyIcons.currentLocation : MyIcons.location;

          return CustomSvgPicture(
            image: icon,
            color: indicatorColor,
            height: Dimensions.space20,
            width: Dimensions.space20,
          );
        },
        itemCount: 2,
      ),
    );
  }
}
