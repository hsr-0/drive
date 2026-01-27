import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/app_status.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/ride/ride_details/ride_details_controller.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/data/services/download_service.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/column_widget/card_column.dart';
import 'package:ovoride_driver/presentation/components/dialog/app_dialog.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/section/ride_details_payment_section.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/section/ride_details_review_section.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/widgets/pick_up_rider_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/widgets/ride_cancel_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/widgets/ride_destination_widget.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/widgets/user_details_widget.dart';

class RideDetailsBottomSheetWidget extends StatelessWidget {
  final ScrollController scrollController;

  final DraggableScrollableController draggableScrollableController;
  const RideDetailsBottomSheetWidget({
    super.key,
    required this.scrollController,
    required this.draggableScrollableController,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideDetailsController>(
      builder: (controller) {
        final ride = controller.ride;
        final currency = controller.currency;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: MyColor.colorWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(Dimensions.moreRadius),
                  topRight: Radius.circular(Dimensions.moreRadius),
                ),
              ),
              padding: EdgeInsets.only(
                top: Dimensions.space10,
                left: Dimensions.space16,
                right: Dimensions.space16,
              ),
              child: ListView(
                clipBehavior: Clip.none,
                controller: scrollController,
                children: [
                  if (ride.status != AppStatus.RIDE_COMPLETED && ride.status != AppStatus.RIDE_CANCELED && ride.status != AppStatus.RIDE_PAYMENT_REQUESTED) ...[
                    spaceDown(Dimensions.space10),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 5,
                        width: 50,
                        decoration: BoxDecoration(
                          color: MyColor.neutral300,
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    spaceDown(Dimensions.space10),
                  ],
                  if (ride.status == AppStatus.RIDE_PAYMENT_REQUESTED || (ride.status == AppStatus.RIDE_COMPLETED) || (ride.status == AppStatus.RIDE_CANCELED)) ...[
                    spaceDown(Dimensions.space70),
                  ],

                  if (ride.user != null) ...[
                    UserDetailsWidget(
                      ride: ride,
                      imageUrl: controller.userImageUrl,
                    ),
                    spaceDown(Dimensions.space25),
                  ],
                  buildRideCounterWidget(ride, currency),

                  spaceDown(Dimensions.space20),

                  RideDestination(ride: controller.ride),

                  //OLD CODE
                  const SizedBox(height: Dimensions.space20),
                  if (controller.ride.status == AppStatus.RIDE_COMPLETED) ...[
                    if (controller.ride.userReview == null) ...[
                      RoundedButton(
                        text: MyStrings.review,
                        isOutlined: false,
                        press: () {
                          CustomBottomSheet(
                            child: RideDetailsReviewSection(),
                          ).customBottomSheet(context);
                        },
                        textColor: MyColor.colorWhite,
                      ),
                    ] else ...[
                      const SizedBox(height: Dimensions.space20),
                      Builder(
                        builder: (context) {
                          bool isDownLoadLoading = false;
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return RoundedButton(
                                isOutlined: true,
                                text: MyStrings.receipt,
                                isLoading: isDownLoadLoading,
                                press: () async {
                                  setState(() {
                                    isDownLoadLoading = true;
                                  });
                                  await DownloadService.downloadPDF(
                                    url: "${UrlContainer.rideReceipt}/${ride.id}",
                                    fileName: "${Environment.appName}_receipt_${ride.id}.pdf",
                                  );
                                  setState(() {
                                    isDownLoadLoading = false;
                                  });
                                },
                                bgColor: MyColor.getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                textColor: MyColor.getPrimaryColor(),
                                textStyle: regularDefault.copyWith(
                                  color: MyColor.getPrimaryColor(),
                                  fontSize: Dimensions.fontLarge,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      SizedBox(height: Dimensions.space15),
                    ],
                  ],
                  if (controller.ride.status == AppStatus.RIDE_ACTIVE) ...[
                    RoundedButton(
                      text: MyStrings.pickupPassenger.tr,
                      press: () {
                        CustomBottomSheet(
                          child: PickUpRiderBottomSheet(ride: ride),
                        ).customBottomSheet(context);
                      },
                      isLoading: controller.isStartBtnLoading,
                    ),
                    spaceDown(Dimensions.space20),
                    RoundedButton(
                      text: MyStrings.cancelRide.tr,
                      press: () {
                        CustomBottomSheet(
                          child: RideCancelBottomSheet(ride: controller.ride),
                        ).customBottomSheet(context);
                      },
                      bgColor: MyColor.redCancelTextColor,
                    ),
                    spaceDown(Dimensions.space20),
                  ],
                  if (controller.ride.status == AppStatus.RIDE_RUNNING) ...[
                    RoundedButton(
                      text: MyStrings.endRide,
                      press: () {
                        AppDialog().showRideDetailsDialog(
                          context,
                          title: MyStrings.pleaseConfirm,
                          description: MyStrings.youWantToEndTheRide,
                          onTap: () async {
                            await controller.endRide(ride.id ?? '-1');
                          },
                        );
                      },
                      isLoading: controller.isEndBtnLoading,
                    ),
                  ],
                  if (controller.ride.status == AppStatus.RIDE_PAYMENT_REQUESTED) ...[
                    RideDetailsPaymentSection(),
                    const SizedBox(height: Dimensions.space25),
                  ],
                ],
              ),
            ),

            //show arriving message
            if (ride.status == AppStatus.RIDE_PAYMENT_REQUESTED || (ride.status == AppStatus.RIDE_COMPLETED) || (ride.status == AppStatus.RIDE_CANCELED)) ...[
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Dimensions.space20,
                      vertical: Dimensions.space15,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: (ride.status == AppStatus.RIDE_CANCELED) ? MyColor.redCancelTextColor.withValues(alpha: 0.2) : MyColor.getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(Dimensions.moreRadius),
                        topRight: Radius.circular(Dimensions.moreRadius),
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: HeaderText(
                          text: (ride.status == AppStatus.RIDE_COMPLETED)
                              ? MyStrings.rideCompleted
                              : (ride.status == AppStatus.RIDE_CANCELED)
                                  ? MyStrings.rideCanceled.tr
                                  : MyStrings.arriveAtMsg.tr,
                          style: boldExtraLarge.copyWith(
                            color: (ride.status == AppStatus.RIDE_CANCELED) ? MyColor.redCancelTextColor : MyColor.getPrimaryColor(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Container buildRideCounterWidget(RideModel ride, String currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.space15,
        vertical: Dimensions.space15,
      ),
      decoration: BoxDecoration(
        color: MyColor.neutral50,
        borderRadius: BorderRadius.circular(Dimensions.largeRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: rideCardDetails(
                title: '${ride.getDistance()} ${MyUtils.getDistanceLabel(distance: ride.distance, unit: Get.find<ApiClient>().getDistanceUnit())}',
                description: MyStrings.distance,
              ),
            ),
          ),
          Container(
            color: MyColor.neutral200,
            height: Dimensions.space50,
            margin: const EdgeInsets.symmetric(horizontal: Dimensions.space10),
            width: 1,
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: rideCardDetails(
                title: '${ride.duration}',
                description: MyStrings.estimatedTime,
              ),
            ),
          ),
          Container(
            color: MyColor.neutral200,
            height: Dimensions.space50,
            margin: const EdgeInsets.symmetric(horizontal: Dimensions.space10),
            width: 1,
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: rideCardDetails(
                title: '${StringConverter.formatNumber(ride.amount.toString())} $currency',
                description: MyStrings.rideFare,
              ),
            ),
          ),
        ],
      ),
    );
  }

  CardColumn rideCardDetails({
    required String title,
    required String description,
  }) {
    return CardColumn(
      header: title.tr,
      body: description.tr,
      headerTextStyle: boldMediumLarge.copyWith(
        color: MyColor.getPrimaryColor(),
      ),
      bodyTextStyle: regularDefault.copyWith(color: MyColor.getBodyTextColor()),
      alignmentCenter: true,
    );
  }
}
