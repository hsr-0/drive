import 'package:flutter/material.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';

import 'package:ovoride_driver/presentation/components/shimmer/my_shimmer.dart';

class UserShimmer extends StatelessWidget {
  const UserShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;

    return Container(
      width: w,
      decoration: BoxDecoration(
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
        border: Border.all(
          color: MyColor.colorGrey2.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 10, top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MyShimmerWidget(
                  child: Container(
                    height: Dimensions.space50 + 35,
                    width: Dimensions.space50 + 35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MyColor.colorGrey.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: Dimensions.space10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyShimmerWidget(
                      child: Container(
                        height: 13,
                        width: 100,
                        decoration: BoxDecoration(
                          color: MyColor.colorGrey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.space5),
                    MyShimmerWidget(
                      child: Container(
                        height: 6,
                        width: 80,
                        decoration: BoxDecoration(
                          color: MyColor.colorGrey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.space5),
                    MyShimmerWidget(
                      child: Container(
                        height: 6,
                        width: 70,
                        decoration: BoxDecoration(
                          color: MyColor.colorGrey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.space10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
