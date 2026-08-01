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
import '../../../../data/model/global/response_model/response_model.dart';
import '../../../../data/repo/dashboard/dashboard_repo.dart';
import '../../../../driver_contest_screen.dart';
import 'widget/new_ride_card.dart';

// 🛑 تأكد من تعديل هذا المسار ليتطابق مع مكان حفظك للملف الجديد

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
            body: Stack(
              children: [
                // 1. المحتوى الأساسي للشاشة قابل للتمرير
                RefreshIndicator(
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
                      const SliverToBoxAdapter(
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
                                  const SizedBox(height: 10),
                                  Text(
                                    MyStrings.runningRide.tr,
                                    style: semiBoldLarge.copyWith(
                                      color: MyColor.primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
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
                                  padding: const EdgeInsets.only(
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
                        // مسافة إضافية في الأسفل حتى لا تغطي البطاقة العائمة على آخر طلب
                        SliverToBoxAdapter(child: spaceDown(180)),
                      ],
                    ],
                  ),
                ),

                // 2. بطاقة التحديات والمكافآت (تطفو في الأسفل دائماً)
                Positioned(
                  bottom: 95, // ارتفاع مناسب لتبقى فوق الشريط السفلي (Bottom Navigation)
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      // 🔥 هنا يتم التوجيه إلى الشاشة الجديدة
                      Get.to(() => const ContestDetailsScreen());
                    },
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00B4D8), Color(0xFF0077B6)], // لون بيتي السمائي
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00B4D8).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'التحديات والمكافآت 🏆',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'اضغط للدخول ومتابعة تقدمك',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
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


class ContestDetailsScreen extends StatefulWidget {
  const ContestDetailsScreen({super.key});

  @override
  State<ContestDetailsScreen> createState() => _ContestDetailsScreenState();
}

class _ContestDetailsScreenState extends State<ContestDetailsScreen> {
  bool isLoading = true;
  ContestModel? contestModel;

  @override
  void initState() {
    super.initState();
    _fetchContestDetails();
  }

  // دالة لجلب تفاصيل المسابقة من السيرفر عند فتح الشاشة
  Future<void> _fetchContestDetails() async {
    setState(() => isLoading = true);
    try {
      DashBoardRepo repo = Get.find<DashBoardRepo>();
      ResponseModel response = await repo.getCurrentContest();

      // 🔥 طباعة الاستجابة لمعرفة ماذا يعيد السيرفر بالضبط
      print("🟢 كود حالة السيرفر: ${response.statusCode}");
      print("🟢 استجابة السيرفر: ${response.responseJson}");

      if (response.statusCode == 200) {
        contestModel = ContestModel.fromJson(response.responseJson);
        print("🟢 حالة المسابقة بعد التحويل: ${contestModel?.hasActiveContest}");
      } else {
        print("🔴 السيرفر أرجع خطأ أو البيانات غير موجودة");
        contestModel = ContestModel(hasActiveContest: false);
      }
    } catch (e) {
      // 🔥 طباعة الخطأ البرمجي في حال فشل التحويل أو الاتصال
      print("🔴 خطأ برمجي (Exception): $e");
      contestModel = ContestModel(hasActiveContest: false);
    }
    setState(() => isLoading = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('التحديات والمكافآت الفورية', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A237E)),
          onPressed: () => Get.back(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00B4D8)))
          : RefreshIndicator(
        onRefresh: _fetchContestDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عرض البطاقة التي أرسلت كودها إذا كانت المسابقة نشطة
              if (contestModel != null && contestModel!.hasActiveContest) ...[
                ContestProgressCard(
                  title: contestModel!.title,
                  targetRides: contestModel!.targetRides,
                  completedRides: contestModel!.completedRides,
                  rewardAmount: contestModel!.rewardAmount,
                  progressPercentage: contestModel!.progressPercentage,
                ),
                const SizedBox(height: 20),

                // بطاقة إضافية لشرح التعليمات والقوانين للسائق
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تعليمات المسابقة 📋',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '1. يتم احتساب الرحلات المكتملة تلقائياً فور إنهاء رحلتك مع العميل.\n'
                            '2. عند إتمام العدد المطلوب من الرحلات، ستتم إضافة المكافأة إلى رصيدك ومحفظتك آلياً.\n'
                            '3. تأكد دائماً من تفعيل نظام تحديد الموقع (GPS) واستمرار الاتصال بالإنترنت أثناء الرحلات.',
                        style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // في حال عدم وجود مسابقة نشطة
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد مسابقات نشطة حالياً',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ترقب الإشعارات قريباً لبدء المنافسة وكسب المكافآت النقدية المباشرة!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}