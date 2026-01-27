import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/controller/ride/all_ride/all_ride_controller.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/components/shimmer/ride_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:ovoride_driver/presentation/screens/ride_history/widget/ride_info_card.dart';

class AllRideListSection extends StatelessWidget {
  const AllRideListSection({super.key, required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AllRideController>(
      builder: (controller) {
        return RefreshIndicator(
          onRefresh: () async {
            controller.initialData(tabID: controller.selectedTab);
          },
          color: MyColor.primaryColor,
          child: controller.isLoading
              ? ListView.separated(
                  itemCount: 10,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: Dimensions.space10),
                  itemBuilder: (_, __) => const RideShimmer(),
                )
              : controller.isLoading == false && controller.rideList.isEmpty
                  ? NoDataWidget(isRide: true, text: MyStrings.noDataToShow)
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: controller.rideList.length + 1,
                      separatorBuilder: (context, index) {
                        return SizedBox(height: Dimensions.space10);
                      },
                      itemBuilder: (context, index) {
                        if (controller.rideList.length == index) {
                          return controller.hasNext()
                              ? SizedBox(
                                  width: MediaQuery.of(context).size.width,
                                  child: const RideShimmer(),
                                )
                              : const SizedBox();
                        }
                        return RideInfoCard(
                          currency: controller.defaultCurrencySymbol,
                          ride: controller.rideList[index],
                          controller: controller,
                        );
                      },
                    ),
        );
      },
    );
  }
}
