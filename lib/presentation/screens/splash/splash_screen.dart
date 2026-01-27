import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_images.dart';
import 'package:ovoride_driver/core/utils/util.dart';
import 'package:ovoride_driver/data/controller/localization/localization_controller.dart';
import 'package:ovoride_driver/data/controller/splash/splash_controller.dart';
import 'package:ovoride_driver/data/repo/auth/general_setting_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/custom_no_data_found_class.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    MyUtils.splashScreen();

    Get.put(GeneralSettingRepo(apiClient: Get.find()));
    Get.put(LocalizationController(sharedPreferences: Get.find()));
    final controller = Get.put(
      SplashController(repo: Get.find(), localizationController: Get.find()),
    );

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.gotoNextPage();
    });
  }

  @override
  void dispose() {
    MyUtils.allScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      builder: (controller) => AnnotatedRegionWidget(
        bottom: false,
        statusBarColor: MyColor.transparentColor,
        systemNavigationBarColor: MyColor.primaryColor,
        child: Scaffold(
          body: controller.noInternet
              ? NoDataOrInternetScreen(
                  isNoInternet: true,
                  onChanged: () {
                    controller.gotoNextPage();
                  },
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        MyImages.backgroundImage,
                        height: double.infinity,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.85,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [
                                MyColor.primaryColor, // Left-side purple
                                MyColor.primaryColor.withValues(
                                  alpha: 0.8,
                                ), // Right-side lighter purple
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(
                        MyImages.logoWhite,
                        height: double.infinity,
                        width: MediaQuery.of(context).size.height * 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
