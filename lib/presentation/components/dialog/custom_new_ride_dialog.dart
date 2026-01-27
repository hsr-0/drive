import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/dashboard/dashboard_controller.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:ovoride_driver/presentation/components/timeline/custom_time_line.dart';
import 'package:toastification/toastification.dart';
import '../../../core/helper/string_format_helper.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/style.dart';
import '../card/bid_dialog_user_info_card.dart';
import '../buttons/rounded_button.dart';
import '../divider/custom_spacer.dart';

class CustomNewRideDialog {
  // Static map to store controllers for each ride
  static final Map<String, TextEditingController> _controllers = {};

  // Get or create controller for a specific ride
  static TextEditingController _getControllerForRide(RideModel ride) {
    printE("Calling ${ride.id}");
    if (!_controllers.containsKey(ride.id)) {
      _controllers[ride.id ?? ""] = TextEditingController(
        text: "${double.tryParse(ride.amount.toString()) ?? 0}",
      );
    }
    return _controllers[ride.id]!;
  }

  // Dispose controller for a specific ride
  static void _disposeController() {
    _controllers.clear();
  }

  static void newRide({
    required RideModel ride,
    required String currency,
    required String currencySym,
    required VoidCallback onBidClick,
    required VoidCallback onCancel,
    required DashBoardController dashboardController,
    VoidCallback? onDispose,
    int duration = 120,
  }) {
    _disposeController();
    // Get or create controller for this ride
    final amountController = _getControllerForRide(ride);
    toastification.showCustom(
      context: Get.context, // optional if you use ToastificationWrapper
      autoCloseDuration: Duration(seconds: duration),

      alignment: Alignment.bottomCenter,

      dismissDirection: DismissDirection.horizontal,
      callbacks: ToastificationCallbacks(
        onDismissed: (toastItem) {
          if (onDispose != null) {
            onDispose();
            printE("Dispose Called");
          }
        },
        onAutoCompleteCompleted: (toastItem) {
          if (onDispose != null) {
            onDispose();
            printE("onAutoCompleteCompleted Called");
          }
        },
      ),
      builder: (BuildContext context, ToastificationItem holder) {
        return buildNewRidePoupDesign(
          ride: ride,
          currency: currency,
          currencySym: currencySym,
          onBidClick: onBidClick,
          dashboardController: dashboardController,
          holder: holder,
          onCancel: onCancel,
          amountController: amountController,
        );
      },
    );
  }

  static Widget buildNewRidePoupDesign({
    required RideModel ride,
    required String currency,
    required String currencySym,
    required VoidCallback onBidClick,
    required VoidCallback onCancel,
    required DashBoardController dashboardController,
    required ToastificationItem holder,
    required TextEditingController amountController,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.space10,
        vertical: Dimensions.space10,
      ),
      child: Material(
        elevation: 50,
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.moreRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: Dimensions.space15,
            horizontal: Dimensions.space20,
          ),
          decoration: BoxDecoration(
            color: MyColor.colorWhite,
            borderRadius: BorderRadius.circular(Dimensions.moreRadius),
            boxShadow: [
              // Top shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                offset: const Offset(0, -20),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              // Bottom shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                offset: const Offset(0, 6),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              _RidePopupTimer(
                duration: Environment.bidAcceptSecond,
                onTimeout: () {
                  toastification.dismissById(holder.id);
                  onCancel();
                  printE("Timer ended → Auto close called");
                },
              ),
              GestureDetector(
                onTap: () {
                  Get.toNamed(
                    RouteHelper.userReviewScreen,
                    arguments: ride.user?.id,
                  );
                },
                child: BidDialogUserCard(
                  fullName: '${ride.user?.getFullName()}',
                  username: '${ride.user?.username}',
                  subtitle: "",
                  rightWidget: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        child: Row(
                          children: [
                            Icon(Icons.group, color: MyColor.primaryColor),
                            SizedBox(width: Dimensions.space2),
                            Text(
                              "${ride.numberOfPassenger}",
                              overflow: TextOverflow.ellipsis,
                              style: boldLarge.copyWith(
                                fontSize: Dimensions.fontExtraLarge,
                                fontWeight: FontWeight.w900,
                                color: MyColor.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "$currencySym${StringConverter.formatNumber(ride.amount ?? '0')}",
                        overflow: TextOverflow.ellipsis,
                        style: boldExtraLarge.copyWith(
                          color: MyColor.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  imgWidget: MyImageWidget(
                    imageUrl: '${dashboardController.userImagePath}/${ride.user?.avatar}',
                    boxFit: BoxFit.cover,
                    height: 40,
                    width: 40,
                    radius: 20,
                    isProfile: true,
                  ),
                  imgHeight: 40,
                  imgWidth: 40,
                ),
              ),
              const SizedBox(height: Dimensions.space10),
              destination(
                pickupLocation: ride.pickupLocation ?? '',
                destination: ride.destination ?? '',
              ),
              const SizedBox(height: Dimensions.space10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Dimensions.space10),
                decoration: BoxDecoration(
                  color: MyColor.bodyTextBgColor,
                  borderRadius: BorderRadius.circular(Dimensions.space5),
                ),
                child: Center(
                  child: Text(
                    MyStrings.recommendedPrice.rKv({
                      "priceKey": "$currencySym${StringConverter.formatNumber(ride.recommendAmount.toString())}",
                      "distanceKey": "${ride.getDistance()} ${MyUtils.getDistanceLabel(distance: ride.distance, unit: Get.find<ApiClient>().getDistanceUnit())}",
                    }).tr,
                    style: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              spaceDown(Dimensions.space10),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: MyColor.primaryColor.withValues(alpha: 0.05),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      Get.find<ApiClient>().getCurrency(isSymbol: true),
                      style: mediumExtraLarge.copyWith(
                        fontSize: 30,
                        color: MyColor.primaryColor,
                      ),
                    ),
                    IntrinsicWidth(
                      child: TextFormField(
                        onChanged: (val) {},
                        expands: false,
                        controller: amountController,
                        scrollPadding: EdgeInsets.zero,
                        inputFormatters: [LengthLimitingTextInputFormatter(8)],
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: Dimensions.space10,
                          ),
                          border: InputBorder.none,
                          hintText: amountController.text.isNotEmpty ? '0' : '0.0',
                          hintStyle: mediumDefault.copyWith(
                            fontSize: 30,
                            color: amountController.text.isNotEmpty ? MyColor.primaryColor : Colors.grey.shade500,
                          ),
                        ),
                        style: mediumDefault.copyWith(
                          fontSize: 30,
                          color: amountController.text.isNotEmpty ? MyColor.primaryColor : Colors.grey.shade500,
                        ),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        selectionHeightStyle: BoxHeightStyle.includeLineSpacingTop,
                        keyboardType: TextInputType.number,
                        cursorColor: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              if (ride.note != null) ...[
                spaceDown(Dimensions.space10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Dimensions.space10),
                  decoration: BoxDecoration(
                    color: MyColor.bodyTextBgColor,
                    borderRadius: BorderRadius.circular(Dimensions.space5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "${MyStrings.riderInstruction.tr}:",
                        style: boldDefault.copyWith(
                          color: MyColor.getBodyTextColor(),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      spaceSide(Dimensions.space7),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: Dimensions.space100,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            ride.note ?? "",
                            style: regularDefault.copyWith(
                              color: MyColor.getBodyTextColor(),
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                spaceDown(Dimensions.space10),
              ] else ...[
                spaceDown(Dimensions.space20),
              ],
              spaceDown(Dimensions.space20),
              Row(
                children: [
                  Expanded(
                    child: RoundedButton(
                      isOutlined: true,
                      text: MyStrings.cancel,
                      press: () {
                        onCancel();
                        toastification.dismissById(holder.id);
                      },
                      bgColor: MyColor.getPrimaryColor().withValues(alpha: 0.1),
                      textColor: MyColor.getPrimaryColor(),
                      textStyle: regularDefault.copyWith(
                        color: MyColor.getPrimaryColor(),
                        fontSize: Dimensions.fontLarge,
                        fontWeight: FontWeight.bold,
                      ),
                      isColorChange: true,
                    ),
                  ),
                  const SizedBox(width: Dimensions.space20),
                  Expanded(
                    child: GetBuilder<DashBoardController>(
                      builder: (controller) => RoundedButton(
                        text: MyStrings.bidNOW.tr,
                        isLoading: dashboardController.isSendBidLoading,
                        press: () async {
                          double enterValue = StringConverter.formatDouble(
                            amountController.text,
                          );
                          double min = StringConverter.formatDouble(
                            ride.minAmount ?? '0.0',
                          );
                          double max = StringConverter.formatDouble(
                            ride.maxAmount ?? '0.0',
                          );

                          if (enterValue >= min && enterValue <= max) {
                            await dashboardController.sendBid(
                              ride.id ?? '-1',
                              amount: enterValue.toString(),
                              onActon: () {
                                onBidClick();
                                toastification.dismissById(holder.id);
                              },
                            );
                          } else {
                            CustomSnackBar.error(
                              errorList: [
                                '${MyStrings.pleaseEnterMinimum.tr} ${controller.currencySym}${StringConverter.formatNumber(ride.minAmount ?? '0')} '
                                    '- ${controller.currencySym}${StringConverter.formatNumber(ride.maxAmount ?? '0')}',
                              ],
                              dismissAll: false,
                            );
                          }
                        },
                        isColorChange: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static CustomTimeLine destination({
    required String pickupLocation,
    required String destination,
  }) {
    return CustomTimeLine(
      indicatorPosition: 0.1,
      dashColor: MyColor.colorYellow,
      firstWidget: Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 10),
        child: Column(
          children: [
            Text(
              pickupLocation.toTitleCase(),
              style: regularSmall.copyWith(
                color: MyColor.getRideSubTitleColor(),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
      secondWidget: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text(
          destination.toTitleCase(),
          style: regularSmall.copyWith(color: MyColor.getRideSubTitleColor()),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _RidePopupTimer extends StatefulWidget {
  final int duration;
  final VoidCallback onTimeout;

  const _RidePopupTimer({required this.duration, required this.onTimeout});

  @override
  State<_RidePopupTimer> createState() => _RidePopupTimerState();
}

class _RidePopupTimerState extends State<_RidePopupTimer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Auto close when timer ends

        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          children: [
            LinearProgressIndicator(
              value: 1 - _controller.value, // countdown style (reverse)
              minHeight: 6,
              color: MyColor.primaryColor,
              backgroundColor: MyColor.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Text(
              '${(widget.duration * (1 - _controller.value)).ceil()}s ${MyStrings.remaining.tr.toLowerCase()}',
              style: regularSmall.copyWith(
                color: MyColor.getBodyTextColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}
