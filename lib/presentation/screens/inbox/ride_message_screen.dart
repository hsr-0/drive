import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../../../data/controller/ride/ride_meassage/new_driver_chat_controller.dart';
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
    widget.rideID = Get.arguments?[0]?.toString() ?? "-1";
    riderName = Get.arguments?[1] ?? MyStrings.inbox.tr;
    riderStatus = Get.arguments?[2] ?? "-1";

    Get.put(MessageRepo(apiClient: Get.find()));
    Get.put(RideRepo(apiClient: Get.find()));
    Get.put(RideMapController());
    Get.put(RideDetailsController(repo: Get.find(), mapController: Get.find()));
    final controller = Get.put(RideMessageController(repo: Get.find()));

    if (!Get.isRegistered<NewDriverChatController>()) {
      Get.put(NewDriverChatController(rideId: widget.rideID));
    }

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
  Widget build(BuildContext context) {
    getSenderView(CustomClipper clipper, BuildContext context, RideMessage item, String? imagePath, bool isLastMessage) =>
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
                    if (item.image != null && item.image != "null")
                      InkWell(
                        onTap: () => Get.toNamed(RouteHelper.previewImageScreen, arguments: "$imagePath/${item.image}"),
                        child: MyImageWidget(imageUrl: "$imagePath/${item.image}"),
                      ),
                    SizedBox(height: Dimensions.space2),
                    Text('${item.message}', style: regularLarge.copyWith(color: Colors.white)),
                    if (isLastMessage) ...[
                      spaceDown(Dimensions.space2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          DateConverter.getTimeAgo(item.createdAt ?? ""),
                          style: regularDefault.copyWith(color: Colors.white70, fontSize: Dimensions.fontOverSmall),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

    getReceiverView(CustomClipper clipper, BuildContext context, RideMessage item, String? imagePath, bool isLastMessage) =>
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
                    if (item.image != null && item.image != "null")
                      InkWell(
                        onTap: () => Get.toNamed(RouteHelper.previewImageScreen, arguments: "$imagePath/${item.image}"),
                        child: MyImageWidget(imageUrl: "$imagePath/${item.image}"),
                      ),
                    SizedBox(height: Dimensions.space2),
                    Text('${item.message}', style: regularLarge.copyWith(color: MyColor.getTextColor())),
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
              backBtnPress: () => Get.back(),
              actionsWidget: [
                IconButton(
                  onPressed: () {
                    print("🔄 [Driver Chat] Refresh");
                  },
                  icon: Icon(Icons.refresh_outlined, color: MyColor.getPrimaryColor()),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: Get.find<NewDriverChatController>().getMessagesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('حدث خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CustomLoader());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: LottieBuilder.asset(MyAnimation.emptyChat, repeat: false));
                      }

                      var messagesDocs = snapshot.data!.docs;

                      return ListView.builder(
                        controller: controller.scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.space5, vertical: Dimensions.space20),
                        itemCount: messagesDocs.length,
                        reverse: true,
                        itemBuilder: (c, index) {
                          try {
                            var data = messagesDocs[index].data() as Map<String, dynamic>;

                            // 🔥 1. معالجة الوقت بالصيغة الدولية لتجنب الكراش
                            String timeString = DateTime.now().toIso8601String();
                            if (data['createdAt'] != null) {
                              if (data['createdAt'] is Timestamp) {
                                timeString = (data['createdAt'] as Timestamp).toDate().toIso8601String();
                              } else {
                                timeString = data['createdAt'].toString();
                              }
                            }

                            // 🔥 2. إعادة تسمية المفاتيح لكي يقبلها RideMessage.fromJson الخاص بلارافيل
                            Map<String, dynamic> safeData = {
                              'message': data['message']?.toString() ?? '',
                              'user_id': data['userId']?.toString() ?? '0',
                              'driver_id': data['driverId']?.toString() ?? '0',
                              'image': data['image']?.toString() ?? 'null',
                              'created_at': timeString,
                            };

                            RideMessage item = RideMessage.fromJson(safeData);

                            // معالجة بيانات الرسالة السابقة للربط بين الفقاعات (Bubbles)
                            var previousData = index > 0 ? messagesDocs[index - 1].data() as Map<String, dynamic> : null;
                            RideMessage? previous;

                            if (previousData != null) {
                              String prevTimeString = DateTime.now().toIso8601String();
                              if (previousData['createdAt'] != null) {
                                if (previousData['createdAt'] is Timestamp) {
                                  prevTimeString = (previousData['createdAt'] as Timestamp).toDate().toIso8601String();
                                } else {
                                  prevTimeString = previousData['createdAt'].toString();
                                }
                              }
                              Map<String, dynamic> safePrevData = {
                                'message': previousData['message']?.toString() ?? '',
                                'user_id': previousData['userId']?.toString() ?? '0',
                                'driver_id': previousData['driverId']?.toString() ?? '0',
                                'image': previousData['image']?.toString() ?? 'null',
                                'created_at': prevTimeString,
                              };
                              previous = RideMessage.fromJson(safePrevData);
                            }

                            bool isMyMessage = item.driverId != "0" && item.driverId != null;
                            bool previousWasMine = previous?.driverId != "0" && previous?.driverId != null;

                            if (isMyMessage) {
                              return Padding(
                                padding: EdgeInsetsDirectional.only(
                                  end: previousWasMine ? Dimensions.space12 : Dimensions.space6,
                                  bottom: previousWasMine ? 0 : Dimensions.space10,
                                ),
                                child: getSenderView(
                                  previousWasMine ? ChatBubbleClipper5(type: BubbleType.sendBubble, secondRadius: Dimensions.space50) : ChatBubbleClipper3(type: BubbleType.sendBubble),
                                  context, item, controller.imagePath, !previousWasMine,
                                ),
                              );
                            } else {
                              bool previousWasRider = previous?.userId != "0" && previous?.userId != null;
                              return Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: previousWasRider ? Dimensions.space12 : Dimensions.space6,
                                  bottom: previousWasRider ? 0 : Dimensions.space10,
                                ),
                                child: getReceiverView(
                                  previousWasRider ? ChatBubbleClipper5(type: BubbleType.receiverBubble, secondRadius: Dimensions.space50) : ChatBubbleClipper3(type: BubbleType.receiverBubble),
                                  context, item, controller.imagePath, !previousWasRider,
                                ),
                              );
                            }
                          } catch (e) {
                            print("❌ [Driver Chat] Error building message $index: $e");
                            return const SizedBox.shrink(); // إخفاء الرسالة المعطوبة بدلاً من الشاشة البيضاء
                          }
                        },
                      );
                    },
                  ),
                ),
                _buildMessageInputField(controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInputField(RideMessageController oldController) {
    if (riderStatus == AppStatus.RIDE_COMPLETED) {
      return Container(
        color: MyColor.getCardBgColor(),
        padding: EdgeInsets.all(Dimensions.space15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: MyColor.getTextColor()),
            spaceSide(Dimensions.space10),
            HeaderText(text: MyStrings.rideCompleted, style: semiBoldOverLarge.copyWith(color: MyColor.getTextColor())),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(Dimensions.space10),
      padding: const EdgeInsets.all(Dimensions.space5),
      decoration: BoxDecoration(
        color: MyColor.colorWhite,
        borderRadius: BorderRadius.circular(Dimensions.space12),
      ),
      child: GetBuilder<NewDriverChatController>(
          builder: (newChatController) {
            return Row(
              children: [
                spaceSide(Dimensions.space10),
                GestureDetector(
                  onTap: () => oldController.pickFile(),
                  child: oldController.imageFile == null
                      ? Icon(Icons.image, color: MyColor.primaryColor)
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(Dimensions.mediumRadius),
                    child: Image.file(oldController.imageFile!, height: 35, width: 35, fit: BoxFit.cover),
                  ),
                ),
                spaceSide(Dimensions.space10),
                Expanded(
                  child: TextFormField(
                    controller: newChatController.messageController,
                    style: regularSmall.copyWith(color: MyColor.getTextColor()),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: MyStrings.writeYourMessage.tr,
                      border: InputBorder.none,
                    ),
                    onFieldSubmitted: (value) {
                      if (newChatController.messageController.text.isNotEmpty && !newChatController.isSubmitLoading) {
                        newChatController.sendMessage();
                      }
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (newChatController.messageController.text.isNotEmpty && !newChatController.isSubmitLoading) {
                      newChatController.sendMessage();
                    }
                  },
                  child: newChatController.isSubmitLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const MyLocalImageWidget(imagePath: MyIcons.sendArrow, width: Dimensions.space40, height: Dimensions.space40),
                ),
                spaceSide(Dimensions.space10),
              ],
            );
          }
      ),
    );
  }
}