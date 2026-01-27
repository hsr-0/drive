import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_animation.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';

class NoDataWidget extends StatelessWidget {
  final double margin;
  final String text;
  final bool isRide;
  const NoDataWidget({
    super.key,
    this.margin = 4,
    this.isRide = false,
    this.text = MyStrings.noDataToShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height / margin,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isRide ? Image.asset(MyImages.emptyRide, height: 120, width: 120) : Lottie.asset(MyAnimation.notFound, height: 150, width: 150),
            const SizedBox(height: Dimensions.space15),
            Text(
              text.toCapitalized().tr,
              style: regularLarge.copyWith(color: MyColor.getBodyTextColor()),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
