import 'package:ovoride_driver/core/helper/date_converter.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/app_status.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/data/controller/ride/all_ride/all_ride_controller.dart';
import 'package:ovoride_driver/data/model/global/ride/ride_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/data/services/download_service.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:ovoride_driver/presentation/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/card/custom_app_card.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/image/my_network_image_widget.dart';
import 'package:ovoride_driver/presentation/components/text/default_text.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';
import 'package:ovoride_driver/presentation/screens/ride_history/widget/pick_up_from_activity_bottom_sheet.dart';
import '../../../components/divider/custom_spacer.dart';
import '../../../components/timeline/custom_time_line.dart';

class RideInfoCard extends StatefulWidget {
  final String currency;
  final RideModel ride;
  final AllRideController controller;
  const RideInfoCard({
    super.key,
    required this.currency,
    required this.ride,
    required this.controller,
  });

  @override
  State<RideInfoCard> createState() => _RideInfoCardState();
}

class _RideInfoCardState extends State<RideInfoCard> {
  bool isDownLoadLoading = false;

  @override
  Widget build(BuildContext context) {
    return CustomAppCard(
      onPressed: () {
        Get.toNamed(
          RouteHelper.rideDetailsScreen,
          arguments: widget.ride.id.toString(),
        )?.then((value) {
          widget.controller.initialData(
            shouldLoading: false,
            tabID: widget.controller.selectedTab,
          );
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MyImageWidget(
                      imageUrl: widget.controller.userImagePath,
                      height: Dimensions.space45,
                      width: Dimensions.space45,
                      radius: Dimensions.radiusHuge,
                      boxFit: BoxFit.contain,
                      isProfile: true,
                    ),
                    spaceSide(Dimensions.space10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HeaderText(
                            text: widget.ride.user?.getFullName() ?? "",
                            style: boldDefault.copyWith(
                              color: MyColor.getHeadingTextColor(),
                              fontSize: Dimensions.fontTitleLarge,
                            ),
                          ),
                          DefaultText(
                            text: "${widget.ride.duration ?? ""} • ${widget.ride.getDistance()} ${MyUtils.getDistanceLabel(distance: widget.ride.distance, unit: Get.find<ApiClient>().getDistanceUnit())}",
                            textStyle: boldDefault.copyWith(
                              color: MyColor.informationColor,
                            ),
                          ),
                          if (widget.ride.service != null && widget.ride.service!.name != null) ...[
                            Text(
                              widget.ride.service?.name ?? '',
                              textAlign: TextAlign.start,
                              style: regularLarge.copyWith(
                                color: MyColor.getBodyTextColor(),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              spaceSide(Dimensions.space20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Dimensions.space5,
                      vertical: Dimensions.space2,
                    ),
                    decoration: BoxDecoration(
                      color: MyUtils.getRideStatusColor(
                        widget.ride.status ?? '9',
                      ).withValues(alpha: 0.01),
                      borderRadius: BorderRadius.circular(
                        Dimensions.mediumRadius,
                      ),
                      border: Border.all(
                        color: MyUtils.getRideStatusColor(
                          widget.ride.status ?? '9',
                        ),
                      ),
                    ),
                    child: Text(
                      MyUtils.getRideStatus(widget.ride.status ?? '9').tr,
                      style: regularDefault.copyWith(
                        fontSize: Dimensions.fontDefault,
                        color: MyUtils.getRideStatusColor(
                          widget.ride.status ?? '9',
                        ),
                      ),
                    ),
                  ),
                  spaceDown(Dimensions.space3),
                  Text(
                    "${widget.currency}${StringConverter.formatNumber(widget.ride.amount.toString())}",
                    style: boldLarge.copyWith(
                      fontSize: Dimensions.fontLarge,
                      fontWeight: FontWeight.w700,
                      color: MyColor.rideTitle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Dimensions.space20),
          CustomTimeLine(
            indicatorPosition: 0.1,
            dashColor: MyColor.neutral300,
            firstWidget: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      MyStrings.pickUpLocation.tr,
                      style: boldLarge.copyWith(
                        color: MyColor.getHeadingTextColor(),
                        fontSize: Dimensions.fontTitleLarge,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  spaceDown(Dimensions.space5),
                  Text(
                    widget.ride.pickupLocation ?? '',
                    style: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                      fontSize: Dimensions.fontDefault,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.ride.startTime != null) ...[
                    spaceDown(Dimensions.space8),
                    Text(
                      DateConverter.estimatedDate(
                        DateTime.tryParse('${widget.ride.startTime}') ?? DateTime.now(),
                      ),
                      style: regularDefault.copyWith(
                        color: MyColor.bodyMutedTextColor,
                        fontSize: Dimensions.fontSmall,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  spaceDown(Dimensions.space15),
                ],
              ),
            ),
            secondWidget: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      MyStrings.destination.tr,
                      style: boldLarge.copyWith(
                        color: MyColor.getHeadingTextColor(),
                        fontSize: Dimensions.fontTitleLarge,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: Dimensions.space5 - 1),
                  Text(
                    widget.ride.destination ?? '',
                    style: regularDefault.copyWith(
                      color: MyColor.getBodyTextColor(),
                      fontSize: Dimensions.fontDefault,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.ride.endTime != null) ...[
                    spaceDown(Dimensions.space8),
                    Text(
                      DateConverter.estimatedDate(
                        DateTime.tryParse('${widget.ride.endTime}') ?? DateTime.now(),
                      ),
                      style: regularDefault.copyWith(
                        color: MyColor.bodyMutedTextColor,
                        fontSize: Dimensions.fontSmall,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          spaceDown(Dimensions.space15),
          Column(
            children: [
              if (![
                AppStatus.RIDE_CANCELED,
                AppStatus.RIDE_COMPLETED,
                AppStatus.RIDE_ACTIVE,
              ].contains(widget.ride.status))
                CustomAppCard(
                  radius: Dimensions.largeRadius,
                  width: double.infinity,
                  backgroundColor: MyColor.neutral100,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        MyStrings.createdTime.tr,
                        style: boldDefault.copyWith(color: MyColor.colorGrey),
                      ),
                      Text(
                        DateConverter.estimatedDate(
                          DateTime.tryParse('${widget.ride.createdAt}') ?? DateTime.now(),
                        ),
                        style: boldDefault.copyWith(color: MyColor.colorGrey),
                      ),
                    ],
                  ),
                ),
              if (widget.ride.status == AppStatus.RIDE_ACTIVE) ...[
                spaceDown(Dimensions.space15),
                buildMessageAndCallWidget(),
                spaceDown(Dimensions.space15),
                RoundedButton(
                  text: MyStrings.pickupPassenger.tr,
                  press: () {
                    CustomBottomSheet(
                      child: PickUpRiderFromActivityBottomSheet(
                        ride: widget.ride,
                      ),
                    ).customBottomSheet(context);
                  },
                  textColor: MyColor.getRideTitleColor(),
                  textStyle: regularDefault.copyWith(
                    color: MyColor.colorWhite,
                    fontSize: Dimensions.fontLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (widget.ride.status == AppStatus.RIDE_COMPLETED) ...[
                spaceDown(Dimensions.space15),
                RoundedButton(
                  isOutlined: true,
                  text: MyStrings.receipt,
                  isLoading: isDownLoadLoading,
                  press: () async {
                    setState(() {
                      isDownLoadLoading = true;
                    });
                    await DownloadService.downloadPDF(
                      url: "${UrlContainer.rideReceipt}/${widget.ride.id}",
                      fileName: "${Environment.appName}_receipt_${widget.ride.id}.pdf",
                    );
                    setState(() {
                      isDownLoadLoading = false;
                    });
                  },
                  bgColor: MyColor.getPrimaryColor().withValues(alpha: 0.1),
                  textColor: MyColor.getPrimaryColor(),
                  textStyle: regularDefault.copyWith(
                    color: MyColor.getPrimaryColor(),
                    fontSize: Dimensions.fontLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (widget.ride.status == AppStatus.RIDE_CANCELED) ...[
                spaceDown(Dimensions.space15),
                if (widget.ride.cancelReason != null) ...[
                  CustomAppCard(
                    radius: Dimensions.largeRadius,
                    width: double.infinity,
                    backgroundColor: MyColor.redCancelTextColor.withValues(alpha: 0.1),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: widget.ride.canceledUserType == "1" ? (widget.ride.user?.getFullName() ?? '') : MyStrings.byMe.tr,
                            style: boldLarge.copyWith(
                              color: MyColor.redCancelTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.ride.user != null) ...[
                            TextSpan(
                              text: ' : ',
                              style: regularDefault.copyWith(
                                color: MyColor.redCancelTextColor,
                              ),
                            ),
                          ],
                          TextSpan(
                            text: widget.ride.cancelReason ?? '',
                            style: regularDefault.copyWith(
                              color: MyColor.redCancelTextColor,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMessageAndCallWidget() {
    return Row(
      children: [
        Expanded(
          child: CustomAppCard(
            radius: Dimensions.largeRadius,
            backgroundColor: MyColor.getPrimaryColor().withValues(alpha: 0.1),
            onPressed: () {
              Get.toNamed(
                RouteHelper.rideMessageScreen,
                arguments: [
                  widget.ride.id.toString(),
                  widget.ride.user?.getFullName(),
                  widget.ride.status.toString(),
                ],
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MyLocalImageWidget(
                  imagePath: MyIcons.message,
                  width: Dimensions.space25,
                  height: Dimensions.space25,
                  boxFit: BoxFit.contain,
                  imageOverlayColor: MyColor.getPrimaryColor(),
                ),
                spaceSide(Dimensions.space10),
                HeaderText(
                  text: MyStrings.message,
                  style: boldDefault.copyWith(
                    fontSize: Dimensions.fontTitleLarge,
                    color: MyColor.getPrimaryColor(),
                  ),
                ),
              ],
            ),
          ),
        ),
        spaceSide(Dimensions.space10),
        Expanded(
          child: CustomAppCard(
            radius: Dimensions.largeRadius,
            backgroundColor: MyColor.getPrimaryColor().withValues(alpha: 0.1),
            onPressed: () {
              MyUtils.launchPhone('${widget.ride.user?.mobile}');
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MyLocalImageWidget(
                  imagePath: MyIcons.callIcon,
                  width: Dimensions.space25,
                  height: Dimensions.space25,
                  boxFit: BoxFit.contain,
                  imageOverlayColor: MyColor.getPrimaryColor(),
                ),
                spaceSide(Dimensions.space10),
                HeaderText(
                  text: MyStrings.call,
                  style: boldDefault.copyWith(
                    fontSize: Dimensions.fontTitleLarge,
                    color: MyColor.getPrimaryColor(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
