import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:ovoride_driver/core/helper/date_converter.dart';
import 'package:ovoride_driver/core/utils/app_status.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/map/ride_map_controller.dart';
import 'package:ovoride_driver/data/controller/pusher/pusher_ride_controller.dart';
import 'package:ovoride_driver/data/controller/ride/ride_details/ride_details_controller.dart';
import 'package:ovoride_driver/data/controller/ride/ride_meassage/ride_meassage_controller.dart';
import 'package:ovoride_driver/data/model/global/app/ride_meassage_model.dart';
import 'package:ovoride_driver/data/repo/meassage/meassage_repo.dart';
import 'package:ovoride_driver/data/repo/ride/ride_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/custom_loader/custom_loader.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import 'package:ovoride_driver/presentation/components/text/header_text.dart';

import '../../../core/route/route.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_animation.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_strings.dart';
import '../../components/app-bar/custom_appbar.dart';
import '../../components/image/my_network_image_widget.dart';
import '../../packages/flutter_chat_bubble/chat_bubble.dart';

class RideMessageScreen extends StatefulWidget {
  String rideID;
  RideMessageScreen({super.key, required this.rideID});

  @override
  State<RideMessageScreen> createState() => _RideMessageScreenState();
}

class _RideMessageScreenState extends State<RideMessageScreen> {
  String riderName = "";
  String riderStatus = "";
  @override
  void initState() {
    widget.rideID = Get.arguments?[0] ?? -1;
    riderName = Get.arguments?[1] ?? MyStrings.inbox.tr;
    riderStatus = Get.arguments?[2] ?? "-1";
    Get.put(MessageRepo(apiClient: Get.find()));
    Get.put(RideRepo(apiClient: Get.find()));
    Get.put(RideMapController());
    Get.put(RideDetailsController(repo: Get.find(), mapController: Get.find()));
    final controller = Get.put(RideMessageController(repo: Get.find()));
    Get.put(
      PusherRideController(
        apiClient: Get.find(),
        rideMessageController: Get.find(),
        rideDetailsController: Get.find(),
        rideID: widget.rideID,
      ),
    );
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((time) {
      controller.initialData(widget.rideID);
      controller.updateCount(0);
    });
  }

  @override
  void dispose() {
    super.dispose();
    // Get.find<RideMessageController>().updateCount(0);
  }

  @override
  Widget build(BuildContext context) {
    getSenderView(
      CustomClipper clipper,
      BuildContext context,
      RideMessage item,
      imagePath,
      bool isLastMessage,
    ) =>
        AnimatedContainer(
          duration: const Duration(microseconds: 500),
          curve: Curves.easeIn,
          child: ChatBubble(
            clipper: clipper,
            alignment: Alignment.topRight,
            margin: const EdgeInsets.only(top: Dimensions.space3),
            backGroundColor: MyColor.primaryColor,
            shadowColor: MyColor.primaryColor.withValues(alpha: 0.01),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
                minWidth: MediaQuery.of(context).size.width * 0.2,
              ),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    item.image != "null"
                        ? InkWell(
                            splashFactory: NoSplash.splashFactory,
                            onTap: () {
                              Get.toNamed(
                                RouteHelper.previewImageScreen,
                                arguments: "$imagePath/${item.image}",
                              );
                            },
                            child: MyImageWidget(
                              imageUrl: "$imagePath/${item.image}",
                            ),
                          )
                        : SizedBox.shrink(),
                    SizedBox(height: Dimensions.space2),
                    Text(
                      '${item.message}',
                      textAlign: TextAlign.start,
                      style: regularLarge.copyWith(color: Colors.white),
                    ),
                    if (isLastMessage) ...[
                      spaceDown(Dimensions.space2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          DateConverter.getTimeAgo(item.createdAt ?? ""),
                          style: regularDefault.copyWith(
                            color: Colors.white70,
                            fontSize: Dimensions.fontOverSmall,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

    getReceiverView(
      CustomClipper clipper,
      BuildContext context,
      RideMessage item,
      String imagePath,
      bool isLastMessage,
    ) =>
        AnimatedContainer(
          duration: const Duration(microseconds: 500),
          curve: Curves.easeIn,
          child: ChatBubble(
            clipper: clipper,
            backGroundColor: MyColor.colorGrey.withValues(alpha: 0.09),
            shadowColor: MyColor.colorGrey.withValues(alpha: 0.01),
            margin: const EdgeInsets.only(top: Dimensions.space3),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
                minWidth: MediaQuery.of(context).size.width * 0.2,
              ),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    item.image != "null"
                        ? InkWell(
                            splashFactory: NoSplash.splashFactory,
                            onTap: () {
                              Get.toNamed(
                                RouteHelper.previewImageScreen,
                                arguments: "$imagePath/${item.image}",
                              );
                            },
                            child: MyImageWidget(
                              imageUrl: "$imagePath/${item.image}",
                            ),
                          )
                        : SizedBox.shrink(),
                    SizedBox(height: Dimensions.space2),
                    Text(
                      '${item.message}',
                      style: regularLarge.copyWith(color: MyColor.getTextColor()),
                    ),
                    if (isLastMessage) ...[
                      spaceDown(Dimensions.space2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          DateConverter.getTimeAgo(item.createdAt ?? ""),
                          style: regularDefault.copyWith(
                            color: MyColor.getTextColor().withValues(alpha: 0.7),
                            fontSize: Dimensions.fontOverSmall,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

    return GetBuilder<RideMessageController>(
      builder: (controller) {
        return AnnotatedRegionWidget(
          child: Scaffold(
            extendBody: true,
            resizeToAvoidBottomInset: true,
            backgroundColor: MyColor.screenBgColor,
            appBar: CustomAppBar(
              title: riderName,
              backBtnPress: () {
                Get.back();
              },
              actionsWidget: [
                IconButton(
                  onPressed: () {
                    controller.getRideMessage(
                      controller.rideId,
                      shouldLoading: true,
                    );
                  },
                  icon: Icon(
                    Icons.refresh_outlined,
                    color: MyColor.getPrimaryColor(),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                controller.isLoading
                    ? Expanded(child: const CustomLoader())
                    : controller.massageList.isEmpty
                        ? Expanded(
                            child: SizedBox(
                              height: context.height,
                              child: LottieBuilder.asset(
                                MyAnimation.emptyChat,
                                repeat: false,
                              ),
                            ),
                          )
                        : Expanded(
                            child: ListView.builder(
                              controller: controller.scrollController,
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: Dimensions.space5,
                                vertical: Dimensions.space20,
                              ),
                              itemCount: controller.massageList.length,
                              reverse: true,
                              itemBuilder: (c, index) {
                                var previous = index > 0 ? controller.massageList[index - 1] : null;
                                var item = controller.massageList[index];

                                // Check if this message is from ME (driver)
                                bool isMyMessage = item.driverId == controller.driverId && item.driverId != "0";

                                // Check if PREVIOUS message was also from ME (driver)
                                bool previousWasMine = previous?.driverId == controller.driverId && previous?.driverId != "0";

                                // Check if PREVIOUS message was from RIDER
                                bool previousWasRider = previous?.userId != null && previous?.userId != "0";

                                if (isMyMessage) {
                                  // MY MESSAGE (Driver) - Sender View
                                  if (previousWasMine) {
                                    // Previous message was also mine - continuation bubble
                                    return Padding(
                                      padding: EdgeInsetsDirectional.only(
                                        end: Dimensions.space12,
                                      ),
                                      child: getSenderView(
                                        ChatBubbleClipper5(
                                          type: BubbleType.sendBubble,
                                          secondRadius: Dimensions.space50,
                                        ),
                                        context,
                                        item,
                                        controller.imagePath,
                                        false,
                                      ),
                                    );
                                  } else {
                                    // First message in sequence - full bubble
                                    return Padding(
                                      padding: EdgeInsetsDirectional.only(
                                        end: Dimensions.space6,
                                        bottom: Dimensions.space10, // More space when switching sender
                                      ),
                                      child: getSenderView(
                                        ChatBubbleClipper3(
                                          type: BubbleType.sendBubble,
                                        ),
                                        context,
                                        item,
                                        controller.imagePath,
                                        true,
                                      ),
                                    );
                                  }
                                } else {
                                  // RIDER MESSAGE - Receiver View
                                  bool currentIsRider = item.userId != null && item.userId != "0";

                                  if (currentIsRider && previousWasRider && previous?.userId == item.userId) {
                                    // Previous message was also from same rider - continuation bubble
                                    return Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        start: Dimensions.space12,
                                      ),
                                      child: getReceiverView(
                                        ChatBubbleClipper5(
                                          type: BubbleType.receiverBubble,
                                          secondRadius: Dimensions.space50,
                                        ),
                                        context,
                                        item,
                                        controller.imagePath,
                                        false,
                                      ),
                                    );
                                  } else {
                                    // First message from rider in sequence - full bubble
                                    return Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        start: Dimensions.space6,
                                        bottom: Dimensions.space10,
                                      ),
                                      child: getReceiverView(
                                        ChatBubbleClipper3(
                                          type: BubbleType.receiverBubble,
                                        ),
                                        context,
                                        item,
                                        controller.imagePath,
                                        true,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                controller.isLoading
                    ? SizedBox.shrink()
                    : riderStatus == AppStatus.RIDE_COMPLETED
                        ? Container(
                            color: MyColor.getCardBgColor(),
                            padding: EdgeInsets.all(Dimensions.space15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: MyColor.getTextColor(),
                                ),
                                spaceSide(Dimensions.space10),
                                HeaderText(
                                  text: MyStrings.rideCompleted,
                                  style: semiBoldOverLarge.copyWith(
                                    color: MyColor.getTextColor(),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: Dimensions.space10,
                              vertical: Dimensions.space10,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.space5,
                              vertical: Dimensions.space5,
                            ),
                            decoration: BoxDecoration(
                              color: MyColor.colorWhite,
                              borderRadius: BorderRadius.circular(
                                Dimensions.space12,
                              ),
                            ),
                            child: Row(
                              children: [
                                spaceSide(Dimensions.space10),
                                controller.imageFile == null
                                    ? GestureDetector(
                                        onTap: () => controller.pickFile(),
                                        child: Icon(
                                          Icons.image,
                                          color: MyColor.primaryColor,
                                        ),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.mediumRadius,
                                        ),
                                        child: Image.file(
                                          controller.imageFile!,
                                          height: 35,
                                          width: 35,
                                        ),
                                      ),
                                spaceSide(Dimensions.space10),
                                Expanded(
                                  child: TextFormField(
                                    controller: controller.massageController,
                                    cursorColor: MyColor.getPrimaryColor(),
                                    style: regularSmall.copyWith(
                                      color: MyColor.getTextColor(),
                                    ),
                                    readOnly: false,
                                    maxLines: null,
                                    textAlignVertical: TextAlignVertical.top,
                                    decoration: InputDecoration(
                                      hintText: MyStrings.writeYourMessage.tr,
                                      hintStyle: mediumDefault.copyWith(
                                        color: MyColor.bodyTextColor.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      enabledBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                    ),
                                    onFieldSubmitted: (value) {
                                      if (controller.massageController.text.isNotEmpty && controller.isSubmitLoading == false) {
                                        controller.sendMessage();
                                      }
                                    },
                                  ),
                                ),
                                spaceSide(Dimensions.space10),
                                InkWell(
                                  onTap: () {
                                    if (controller.massageController.text.isNotEmpty && controller.isSubmitLoading == false) {
                                      controller.sendMessage();
                                    }
                                  },
                                  child: controller.isSubmitLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: MyColor.primaryColor,
                                          ),
                                        )
                                      : const MyLocalImageWidget(
                                          imagePath: MyIcons.sendArrow,
                                          width: Dimensions.space40,
                                          height: Dimensions.space40,
                                        ),
                                ),
                                spaceSide(Dimensions.space10),
                              ],
                            ),
                          ),
              ],
            ),
          ),
        );
      },
    );
  }
}
