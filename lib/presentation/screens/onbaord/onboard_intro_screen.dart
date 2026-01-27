import 'package:flutter_animate/flutter_animate.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/presentation/components/divider/custom_spacer.dart';
import 'package:ovoride_driver/presentation/components/image/my_local_image_widget.dart';
import '../../../core/utils/dimensions.dart';
import '../../../core/utils/my_color.dart';
import '../../../core/utils/my_images.dart';
import '../../../core/utils/my_strings.dart';
import '../../../core/utils/style.dart';
import '../../../data/services/api_client.dart';
import '../../components/buttons/rounded_button.dart';

class OnBoardIntroScreen extends StatefulWidget {
  const OnBoardIntroScreen({super.key});

  @override
  State<OnBoardIntroScreen> createState() => _OnBoardIntroScreenState();
}

class _OnBoardIntroScreenState extends State<OnBoardIntroScreen> {
  late PageController _pageController;
  int currentPageID = 0;

  final GlobalKey _bottomContainerKey = GlobalKey();
  double _bottomContainerHeight = 0;

  static const List<Map<String, String>> onboardText = [
    {"title": MyStrings.onboardTitle1, "body": MyStrings.onboardDescription1},
    {"title": MyStrings.onboardTitle2, "body": MyStrings.onboardDescription2},
    {"title": MyStrings.onboardTitle3, "body": MyStrings.onboardDescription3},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // Delay to measure bottom container height after first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureContainer());
  }

  void _measureContainer() {
    final context = _bottomContainerKey.currentContext;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox;
      if (mounted) {
        setState(() {
          _bottomContainerHeight = box.size.height;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Delay to measure bottom container height after first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureContainer());
    return AnnotatedRegionWidget(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: MyColor.colorWhite,
      child: Scaffold(
        backgroundColor: MyColor.getScreenBgColor(),
        body: Stack(
          children: [
            /// 🖼️ Background images
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (int index) {
                      setState(() {
                        currentPageID = index;
                      });
                    },
                    itemCount: MyImages.onboardImages.length,
                    itemBuilder: (context, index) {
                      return TweenAnimationBuilder(
                        key: ValueKey(index),
                        curve: Curves.fastOutSlowIn,
                        tween: Tween<double>(begin: 1.0, end: 0.0),
                        duration: const Duration(milliseconds: 700),
                        builder: (context, value, child) {
                          return Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.01)
                              ..rotateX(value * -0.06),
                            child: MyLocalImageWidget(
                              imagePath: MyImages.onboardImages[index],
                              width: double.infinity,
                              boxFit: BoxFit.cover,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                /// 🟢 Space exactly matching the actual bottom widget height
                spaceDown(_bottomContainerHeight > 50 ? (_bottomContainerHeight - 50) : _bottomContainerHeight),
              ],
            ),

            /// ⚪ Overlapping bottom white container
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                key: _bottomContainerKey,
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  color: MyColor.colorWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(Dimensions.radius25),
                    topRight: Radius.circular(Dimensions.radius25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MyColor.colorBlack.withValues(alpha: 0.05),
                      offset: const Offset(0, -3),
                      blurRadius: 15,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: Dimensions.space15,
                  vertical: Dimensions.space15,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: Dimensions.space20),
                    Text(
                      onboardText[currentPageID]['title'] ?? "",
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: boldExtraLarge.copyWith(
                        fontSize: Dimensions.fontOverLarge21,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate(effects: [FadeEffect(duration: 500.ms)]),
                    const SizedBox(height: Dimensions.space10),
                    Text(
                      onboardText[currentPageID]['body'] ?? "",
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: regularDefault.copyWith(
                        fontSize: Dimensions.fontLarge,
                        color: MyColor.getBodyTextColor(),
                      ),
                    ).animate(effects: [FadeEffect(duration: 500.ms)]),
                    const SizedBox(height: Dimensions.space20),

                    /// 🔵 Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        MyImages.onboardImages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: currentPageID == i ? 30 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: currentPageID == i ? MyColor.primaryColor : MyColor.colorGrey2,
                            borderRadius: currentPageID == i
                                ? const BorderRadius.horizontal(
                                    left: Radius.circular(Dimensions.space5),
                                    right: Radius.circular(Dimensions.space5),
                                  )
                                : BorderRadius.circular(Dimensions.space10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimensions.space20),

                    /// 🔘 Buttons
                    if (currentPageID == MyImages.onboardImages.length - 1) ...[
                      RoundedButton(
                        text: MyStrings.logIn.tr,
                        press: () {
                          Get.find<ApiClient>().sharedPreferences.setBool(
                                SharedPreferenceHelper.onBoardKey,
                                true,
                              );
                          Get.offAllNamed(RouteHelper.loginScreen);
                        },
                      ),
                      SizedBox(height: Dimensions.space20),
                      RoundedButton(
                        text: MyStrings.register.tr,
                        isOutlined: true,
                        textStyle: boldDefault.copyWith(
                          color: MyColor.primaryColor,
                        ),
                        press: () {
                          Get.find<ApiClient>().sharedPreferences.setBool(
                                SharedPreferenceHelper.onBoardKey,
                                true,
                              );
                          Get.offAllNamed(RouteHelper.registrationScreen);
                        },
                      ),
                      const SizedBox(height: Dimensions.space20),
                    ] else ...[
                      RoundedButton(
                        text: MyStrings.next.tr,
                        press: () {
                          if (currentPageID < MyImages.onboardImages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.ease,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: Dimensions.space20),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
