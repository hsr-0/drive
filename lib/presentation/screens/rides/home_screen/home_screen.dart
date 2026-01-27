import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/dashboard/dashboard_controller.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/no_data.dart';
import 'package:ovoride_driver/presentation/components/shimmer/ride_shimmer.dart';
import 'package:ovoride_driver/presentation/screens/dashboard/dashboard_background.dart';
import 'package:ovoride_driver/presentation/screens/dashboard/widgets/driver_kyc_warning_section.dart';
import 'package:ovoride_driver/presentation/screens/dashboard/widgets/vahicle_kyc_warning_section.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ovoride_driver/presentation/screens/rides/home_screen/widget/home_app_bar.dart';
import 'package:ovoride_driver/presentation/screens/rides/home_screen/widget/offer_bid_bottom_sheet.dart';
import '../../../../core/helper/string_format_helper.dart';
import 'widget/new_ride_card.dart';

class HomeScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState>? dashBoardScaffoldKey;
  const HomeScreen({super.key, this.dashBoardScaffoldKey});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double appBarSize = 90.0;

  ScrollController scrollController = ScrollController();
  void scrollListener() {
    if (scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      if (Get.find<DashBoardController>().hasNext()) {
        Get.find<DashBoardController>().loadData();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Get.find<DashBoardController>().initialData(shouldLoad: true);

      scrollController.addListener(scrollListener);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashBoardController>(
      builder: (controller) {
        return DashboardBackground(
          child: Scaffold(
            extendBody: true,
            backgroundColor: MyColor.transparentColor,
            extendBodyBehindAppBar: false,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(appBarSize),
              child: HomeScreenAppBar(controller: controller),
            ),
            body: RefreshIndicator(
              edgeOffset: 80,
              backgroundColor: MyColor.colorWhite,
              color: MyColor.primaryColor,
              triggerMode: RefreshIndicatorTriggerMode.onEdge,
              onRefresh: () async {
                controller.initialData(shouldLoad: true);
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                controller: scrollController,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(height: 10),
                        DriverKYCWarningSection(),
                        SizedBox(height: 2),
                        VehicleKYCWarningSection(),
                      ],
                    ),
                  ),
                  //Running Rides
                  if (controller.isLoading == false) ...[
                    if (controller.runningRide != null) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: Dimensions.space10,
                          ),
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 10),
                              Text(
                                MyStrings.runningRide.tr,
                                style: semiBoldLarge.copyWith(
                                  color: MyColor.primaryColor,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 10),
                              NewRideCardWidget(
                                isActive: true,
                                ride: controller.runningRide!,
                                currency: controller.currencySym,
                                driverImagePath: '${controller.userImagePath}/${controller.runningRide?.user?.avatar}',
                                press: () {
                                  final ride = controller.runningRide!;
                                  Get.toNamed(
                                    RouteHelper.rideDetailsScreen,
                                    arguments: ride.id,
                                  );
                                },
                              )
                                  .animate(
                                    onPlay: (controller) => controller.repeat(),
                                  )
                                  .shakeX(
                                    duration: 1000.ms,
                                    delay: 4000.ms,
                                    curve: Curves.easeInOut,
                                    hz: 4,
                                  ),
                              spaceDown(Dimensions.space10),
                              if (controller.rideList.isNotEmpty) ...[
                                Text(
                                  MyStrings.newRide.tr,
                                  style: regularDefault.copyWith(
                                    color: MyColor.colorBlack,
                                    fontSize: 18,
                                  ),
                                ),
                                spaceDown(Dimensions.space10),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],

                  //All Requested Rides List
                  if (controller.isLoading) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.space16,
                        ),
                        child: Column(
                          children: List.generate(
                            10,
                            (index) => Padding(
                              padding: EdgeInsets.only(
                                bottom: Dimensions.space10,
                              ),
                              child: const RideShimmer(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else if (controller.isLoading == false && controller.rideList.isEmpty) ...[
                    SliverToBoxAdapter(
                      child: NoDataWidget(
                        text: MyStrings.noRideFoundInYourArea.tr,
                        isRide: true,
                        margin: controller.runningRide?.id != "-1" ? 4 : 8,
                      ),
                    ),
                  ] else ...[
                    SliverList.separated(
                      itemCount: controller.rideList.length + 1,
                      itemBuilder: (context, index) {
                        if (controller.rideList.length == index) {
                          return controller.hasNext()
                              ? SizedBox(
                                  width: MediaQuery.of(context).size.width,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Dimensions.space16,
                                    ),
                                    child: const RideShimmer(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.space16,
                          ),
                          child: NewRideCardWidget(
                            isActive: true,
                            ride: controller.rideList[index],
                            currency: controller.currencySym,
                            driverImagePath: '${controller.userImagePath}/${controller.rideList[index].user?.avatar}',
                            press: () {
                              final ride = controller.rideList[index];
                              printE(ride.amount);
                              controller.updateMainAmount(
                                StringConverter.formatDouble(
                                  ride.amount.toString(),
                                ),
                              );
                              CustomBottomSheet(
                                child: OfferBidBottomSheet(ride: ride),
                              ).customBottomSheet(context);
                            },
                          ),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return spaceDown(Dimensions.space10);
                      },
                    ),
                    SliverToBoxAdapter(child: spaceDown(Dimensions.space100)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
