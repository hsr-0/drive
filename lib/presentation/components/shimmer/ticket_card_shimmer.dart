import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/shimmer/my_shimmer.dart';

class TicketCardShimmer extends StatelessWidget {
  const TicketCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyShimmerWidget(
                    child: Container(
                      width: context.width / 3,
                      height: 8,
                      decoration: BoxDecoration(
                        color: MyColor.colorGrey2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.space5),
                  MyShimmerWidget(
                    child: Container(
                      width: context.width / 4,
                      height: 6,
                      decoration: BoxDecoration(
                        color: MyColor.colorGrey2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              MyShimmerWidget(
                child: Container(
                  width: context.width / 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: MyColor.colorGrey2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.space30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MyShimmerWidget(
                child: Container(
                  width: context.width / 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: MyColor.colorGrey2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              MyShimmerWidget(
                child: Container(
                  width: context.width / 5,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MyColor.colorGrey2,
                    borderRadius: BorderRadius.circular(2),
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
