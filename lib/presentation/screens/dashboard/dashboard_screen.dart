import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; // تأكد من وجود هذه المكتبة في pubspec.yaml
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_icons.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/controller/dashboard/dashboard_controller.dart';
import 'package:ovoride_driver/data/controller/pusher/global_pusher_controller.dart';
import 'package:ovoride_driver/data/controller/ride/ride_action/ride_action_controller.dart';
import 'package:ovoride_driver/data/controller/ride/all_ride/all_ride_controller.dart';
import 'package:ovoride_driver/data/repo/dashboard/dashboard_repo.dart';
import 'package:ovoride_driver/data/repo/ride/ride_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/image/custom_svg_picture.dart';
import 'package:ovoride_driver/presentation/screens/ride_history/ride_activity_screen.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/presentation/components/will_pop_widget.dart';
import 'package:ovoride_driver/presentation/screens/profile_and_settings/profile_and_settings_screen.dart';
import 'package:ovoride_driver/presentation/screens/rides/home_screen/home_screen.dart';
import '../../packages/flutter_floating_bottom_navigation_bar/floating_bottom_navigation_bar.dart';

class DashBoardScreen extends StatefulWidget {
  const DashBoardScreen({super.key});

  @override
  State<DashBoardScreen> createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<DashBoardScreen> {
  int selectedIndex = 0;
  late List<Widget> _widgets;

  @override
  void initState() {
    Get.put(RideRepo(apiClient: Get.find()));
    Get.put(DashBoardRepo(apiClient: Get.find()));
    Get.put(DashBoardController(repo: Get.find()));
    var globalPusherController = Get.put(
      GlobalPusherController(
        apiClient: Get.find(),
        dashBoardController: Get.find(),
      ),
    );
    Get.put(RideActionController(repo: Get.find()));
    Get.put(AllRideController(repo: Get.find()));

    _widgets = <Widget>[
      HomeScreen(),
      RideActivityScreen(
        onBackPress: () {
          changeScreen(0);
        },
      ),
      const ProfileAndSettingsScreen(),
    ];

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      globalPusherController.ensureConnection();
      // تشغيل فحص الإفصاح البارز
      _checkLocationDisclosure();
    });
  }

  Future<void> _checkLocationDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasAccepted = prefs.getBool('location_accepted') ?? false;

    if (!hasAccepted) {
      _showLocationDialog(prefs);
    }
  }

  void _showLocationDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 10),
              Text("Location Permission"),
            ],
          ),
          content: const Text(
            "Beytei Services collects location data to enable 'Real-time Trip Tracking' and 'Driver Availability' features, even when the app is closed or not in use. "
                "This data is used to allow customers to track their rides and to calculate trip distances accurately.\n\n"
                "To continue working as a driver, please select 'Allow all the time' in the next step.",
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text("Exit", style: TextStyle(color: Colors.red)),
              onPressed: () => exit(0),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColor.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Accept & Continue", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                await prefs.setBool('location_accepted', true);
                Navigator.of(context).pop();

                // --- طلب الإذن مباشرة من النظام لحل مشكلة الخطأ ---
                LocationPermission permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }

                if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
                  // إذا تم القبول، نقوم بتحديث البيانات في الكنترولر (اختياري حسب السكربت)
                  Get.find<DashBoardController>().update();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void changeScreen(int val) {
    setState(() {
      selectedIndex = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopWidget(
      child: AnnotatedRegionWidget(
        systemNavigationBarColor: MyColor.colorWhite,
        statusBarColor: MyColor.transparentColor,
        child: GetBuilder<DashBoardController>(
          builder: (controller) => Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                IndexedStack(index: selectedIndex, children: _widgets),
                if (Platform.isIOS && selectedIndex == 0)
                  Positioned(
                    top: 60,
                    left: 20,
                    child: GestureDetector(
                      onTap: () {
                        Get.offAllNamed(RouteHelper.sectionsScreen);
                      },
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: FloatingNavbar(
              inLine: true,
              fontSize: Dimensions.fontMedium,
              backgroundColor: MyColor.colorWhite,
              unselectedItemColor: MyColor.bodyMutedTextColor,
              selectedItemColor: MyColor.primaryColor,
              borderRadius: Dimensions.space50,
              itemBorderRadius: Dimensions.space50,
              selectedBackgroundColor: MyColor.primaryColor.withValues(
                alpha: 0.09,
              ),
              onTap: (int val) {
                changeScreen(val);
                if (Get.isRegistered<AllRideController>()) {
                  Get.find<AllRideController>().changeTab(0);
                }
              },
              margin: const EdgeInsetsDirectional.only(
                start: Dimensions.space20,
                end: Dimensions.space20,
                bottom: Dimensions.space15,
              ),
              currentIndex: selectedIndex,
              items: [
                FloatingNavbarItem(
                  icon: Icons.home,
                  title: MyStrings.home.tr,
                  customWidget: CustomSvgPicture(
                    image: selectedIndex == 0 ? MyIcons.homeActive : MyIcons.home,
                    color: selectedIndex == 0 ? MyColor.primaryColor : MyColor.bodyMutedTextColor,
                  ),
                ),
                FloatingNavbarItem(
                  icon: Icons.location_city,
                  title: MyStrings.activity.tr,
                  customWidget: CustomSvgPicture(
                    image: selectedIndex == 1 ? MyIcons.activityActive : MyIcons.activity,
                    color: selectedIndex == 1 ? MyColor.primaryColor : MyColor.bodyMutedTextColor,
                  ),
                ),
                FloatingNavbarItem(
                  icon: Icons.list,
                  title: MyStrings.menu.tr,
                  customWidget: CustomSvgPicture(
                    image: selectedIndex == 2 ? MyIcons.menuActive : MyIcons.menu,
                    color: selectedIndex == 2 ? MyColor.primaryColor : MyColor.bodyMutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}