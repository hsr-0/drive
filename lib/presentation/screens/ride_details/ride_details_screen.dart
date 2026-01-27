import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:ovoride_driver/core/utils/app_status.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_animation.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/data/controller/map/ride_map_controller.dart';
import 'package:ovoride_driver/data/controller/pusher/pusher_ride_controller.dart';
import 'package:ovoride_driver/data/controller/ride/ride_details/ride_details_controller.dart';
import 'package:ovoride_driver/data/controller/ride/ride_meassage/ride_meassage_controller.dart';
import 'package:ovoride_driver/data/repo/meassage/meassage_repo.dart';
import 'package:ovoride_driver/data/repo/ride/ride_repo.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/widgets/ride_details_bottom_sheet_widget.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/widgets/poly_line_map.dart';
import 'package:toastification/toastification.dart';

class RideDetailsScreen extends StatefulWidget {
  final String rideId;

  const RideDetailsScreen({super.key, required this.rideId});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  DraggableScrollableController draggableScrollableController = DraggableScrollableController();

  @override
  void initState() {
    print('🚀 [RideDetails] الشاشة بدأت بالعمل لـ ID: ${widget.rideId}');

    // تهيئة المتحكمات والمستودعات
    Get.put(RideRepo(apiClient: Get.find()));
    final mapController = Get.put(RideMapController());
    Get.put(MessageRepo(apiClient: Get.find()));
    Get.put(RideMessageController(repo: Get.find()));

    final detailsController = Get.put(
      RideDetailsController(repo: Get.find(), mapController: mapController),
    );

    Get.put(
      PusherRideController(
        apiClient: Get.find(),
        rideMessageController: Get.find(),
        rideDetailsController: detailsController,
        rideID: widget.rideId,
      ),
    );

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      print('🔄 [RideDetails] جاري طلب بيانات الرحلة من السيرفر...');
      try {
        await detailsController.getRideDetails(widget.rideId);
        print('✅ [RideDetails] تم استلام البيانات. حالة التحميل: ${detailsController.isLoading}');
      } catch (e) {
        print('❌ [RideDetails] فشل جلب البيانات: $e');
      }

      Get.find<PusherRideController>().ensureConnection();
    });
  }

  @override
  void dispose() {
    print('⚠️ [RideDetails] إغلاق الشاشة وتنظيف الذاكرة');
    if (Get.isRegistered<PusherRideController>()) {
      Get.find<PusherRideController>().dispose();
    }
    super.dispose();
  }

  void _zoomBasedOnExtent(double extent) {
    var controller = Get.find<RideMapController>();
    if (controller.isMapReady) {
      controller.fitPolylineBounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideDetailsController>(
      builder: (controller) {
        print('🎨 [RideDetails] إعادة بناء الواجهة - التحميل: ${controller.isLoading}');

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, dynamic result) async {
              if (didPop) return;
              Get.back();
              toastification.dismissAll();
            },
            child: Scaffold(
              body: Stack(
                children: [
                  // عرض الخريطة أو الأنيميشن
                  controller.isLoading
                      ? SizedBox(
                    height: context.height,
                    width: double.infinity,
                    child: Center(
                      child: LottieBuilder.asset(
                        MyAnimation.rideDetailsLoadingAnimation,
                      ),
                    ),
                  )
                      : SizedBox(
                    height: context.isTablet ? context.height : context.height / 1.3,
                    child: Builder(
                        builder: (context) {
                          print('🗺️ [RideDetails] محاولة عرض ويدجت الخريطة PolyLineMapScreen');
                          return const PolyLineMapScreen();
                        }
                    ),
                  ),

                  // زر الرجوع
                  Positioned(
                    top: 0,
                    left: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.space12),
                        child: IconButton(
                          style: IconButton.styleFrom(backgroundColor: MyColor.colorWhite),
                          color: MyColor.colorBlack,
                          onPressed: () => Get.back(result: true),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              bottomSheet: controller.isLoading
                  ? Container(
                color: MyColor.colorWhite,
                height: context.height / 4,
                child: const Center(child: Text("جاري تحميل الخريطة...")),
              )
                  : AnimatedPadding(
                padding: EdgeInsetsDirectional.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.decelerate,
                child: DraggableScrollableSheet(
                  controller: draggableScrollableController,
                  snap: true,
                  shouldCloseOnMinExtent: true,
                  expand: false,
                  initialChildSize: 0.4,
                  minChildSize: 0.4,
                  maxChildSize: 0.8,
                  snapSizes: const [0.4, 0.5, 0.7, 0.8],
                  builder: (context, scrollController) {
                    return NotificationListener<DraggableScrollableNotification>(
                      onNotification: (notification) {
                        _zoomBasedOnExtent(notification.extent);
                        return true;
                      },
                      child: RideDetailsBottomSheetWidget(
                        scrollController: scrollController,
                        draggableScrollableController: draggableScrollableController,
                      ),
                    );
                  },
                ),
              ),

              floatingActionButton: controller.isLoading
                  ? const SizedBox.shrink()
                  : FloatingActionButton(
                backgroundColor: controller.ride.status == AppStatus.RIDE_RUNNING
                    ? MyColor.primaryColor
                    : MyColor.colorBlack,
                onPressed: () {
                  print('📍 [RideDetails] فتح الخرائط الخارجية');
                  controller.openExternalMap();
                },
                child: Icon(
                  controller.ride.status == AppStatus.RIDE_RUNNING
                      ? CupertinoIcons.location_fill
                      : CupertinoIcons.location,
                  color: MyColor.colorWhite,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
