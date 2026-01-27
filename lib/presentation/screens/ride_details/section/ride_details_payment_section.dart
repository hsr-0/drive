import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/ride/ride_details/ride_details_controller.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/packages/simple_ripple_animation.dart';

class RideDetailsPaymentSection extends StatelessWidget {
  const RideDetailsPaymentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideDetailsController>(
      builder: (controller) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: EdgeInsets.only(top: 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    spaceDown(Dimensions.space10),
                    RippleAnimation(
                      repeat: true,
                      color: MyColor.primaryColor,
                      minRadius: 18,
                      child: Container(
                        padding: const EdgeInsets.all(Dimensions.space15),
                        decoration: BoxDecoration(
                          color: MyColor.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    spaceDown(Dimensions.space20),
                    Text(
                      MyStrings.waitForUserPayment.tr,
                      style: boldLarge.copyWith(
                        fontSize: 15,
                        color: MyColor.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
