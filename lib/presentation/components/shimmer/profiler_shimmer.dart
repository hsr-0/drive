import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/presentation/components/shimmer/my_shimmer.dart';

class ProfilerShimmer extends StatelessWidget {
  const ProfilerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Dimensions.space16,
        vertical: Dimensions.space16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.space10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MyShimmerWidget(
            highlightColor: MyColor.primaryColor.withValues(alpha: 0.9),
            baseColor: MyColor.primaryColor.withValues(alpha: 0.5),
            child: Container(
              height: Dimensions.space50,
              width: Dimensions.space50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MyColor.getPrimaryColor().withValues(alpha: 0.3),
              ),
            ),
          ),
          SizedBox(width: Dimensions.space10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MyShimmerWidget(
                highlightColor: MyColor.primaryColor.withValues(alpha: 0.9),
                baseColor: MyColor.primaryColor.withValues(alpha: 0.5),
                child: Container(
                  height: 5,
                  width: context.width / 3,
                  decoration: BoxDecoration(
                    color: MyColor.colorGrey.withValues(alpha: 0.3),
                  ),
                ),
              ),
              SizedBox(height: Dimensions.space5),
              MyShimmerWidget(
                highlightColor: MyColor.primaryColor.withValues(alpha: 0.9),
                baseColor: MyColor.primaryColor.withValues(alpha: 0.5),
                child: Container(
                  height: 5,
                  width: context.width / 3 - 50,
                  decoration: BoxDecoration(
                    color: MyColor.colorGrey.withValues(alpha: 0.3),
                  ),
                ),
              ),
              SizedBox(height: Dimensions.space5),
              MyShimmerWidget(
                highlightColor: MyColor.primaryColor.withValues(alpha: 0.9),
                baseColor: MyColor.primaryColor.withValues(alpha: 0.5),
                child: Container(
                  height: 5,
                  width: context.width / 4,
                  decoration: BoxDecoration(
                    color: MyColor.colorGrey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
