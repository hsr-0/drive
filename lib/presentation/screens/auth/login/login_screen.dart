import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/dimensions.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/controller/auth/login_controller.dart';
import 'package:ovoride_driver/data/repo/auth/login_repo.dart';
import 'package:ovoride_driver/presentation/components/annotated_region/annotated_region_widget.dart';
import 'package:ovoride_driver/presentation/components/buttons/rounded_button.dart';
import 'package:ovoride_driver/presentation/components/text-form-field/custom_text_field.dart';
import 'package:ovoride_driver/presentation/components/text/default_text.dart';
import 'package:ovoride_driver/presentation/components/will_pop_widget.dart';
import 'package:ovoride_driver/presentation/screens/auth/auth_background.dart';
import '../../../../core/utils/my_icons.dart';
import '../../../../core/utils/my_images.dart';
import '../../../components/divider/custom_spacer.dart';
import '../../../components/image/custom_svg_picture.dart';
import '../social_auth/social_auth_section.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    Get.put(LoginRepo(apiClient: Get.find()));
    Get.put(LoginController(loginRepo: Get.find()));

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationDisclosure();
    });
  }

  // --- دالة فتح الواتساب ---
  Future<void> _openWhatsAppSupport() async {
    String phone = Get.find<LoginController>().emailController.text.trim();
    String supportNumber = "+96478554076931";
    String message = phone.isNotEmpty
        ? "مرحباً، أنا كابتن في منصة بيتي ونسيت كلمة المرور لحسابي. رقم هاتفي المسجل هو: $phone"
        : "مرحباً، أنا كابتن في منصة بيتي ونسيت كلمة المرور لحسابي.";

    String encodedMessage = Uri.encodeComponent(message);
    Uri whatsappUrl = Uri.parse("https://wa.me/$supportNumber?text=$encodedMessage");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar("تنبيه", "تطبيق واتساب غير مثبت على جهازك", backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  // --- دالة فتح شرح اليوتيوب ---
  Future<void> _openYouTubeTutorial() async {
    // ضع رابط فيديو اليوتيوب الخاص بك هنا بمجرد رفعه
    final Uri youtubeUrl = Uri.parse('https://www.youtube.com/channel/UCilI5RfhwMpRi7r_ioY2GXw');

    if (await canLaunchUrl(youtubeUrl)) {
      await launchUrl(youtubeUrl, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar("تنبيه", "لا يمكن فتح الرابط", backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  // --- نافذة الصلاحية ---
  Future<void> _checkLocationDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasAccepted = prefs.getBool('location_accepted') ?? false;

    if (!hasAccepted) {
      _showCustomDisclosureDialog(prefs);
    }
  }

  void _showCustomDisclosureDialog(SharedPreferences prefs) {
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

                LocationPermission permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  await Geolocator.requestPermission();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopWidget(
      nextRoute: '',
      child: AnnotatedRegionWidget(
        statusBarColor: Colors.transparent,
        child: Scaffold(
          backgroundColor: MyColor.colorWhite,
          body: GetBuilder<LoginController>(
            builder: (controller) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthBackgroundWidget(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: Dimensions.space20, vertical: Dimensions.space10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          spaceDown(Dimensions.space15),
                          Image.asset(
                            MyImages.appLogoWhite,
                            color: MyColor.colorWhite,
                            width: MediaQuery.of(context).size.width / 2.5,
                          ),
                          spaceDown(Dimensions.space15),
                          Text(
                            MyStrings.loginScreenTitle.tr,
                            style: boldExtraLarge.copyWith(
                              fontSize: 32,
                              color: MyColor.colorWhite,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          spaceDown(Dimensions.space5),
                          Text(
                            MyStrings.loginScreenSubTitle.tr,
                            style: regularDefault.copyWith(
                              color: MyColor.colorWhite,
                              fontSize: Dimensions.fontLarge,
                            ),
                          ),
                          spaceDown(Dimensions.space40),
                        ],
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(0, -Dimensions.space20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: MyColor.colorWhite,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(Dimensions.radius25),
                          topRight: Radius.circular(Dimensions.radius25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MyColor.colorBlack.withValues(alpha: 0.05),
                            offset: const Offset(0, -30),
                            blurRadius: 15,
                            spreadRadius: -3,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(horizontal: Dimensions.space15, vertical: Dimensions.space15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          spaceDown(Dimensions.space15),
                          SocialAuthSection(),
                          Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  controller: controller.emailController,
                                  hintText: "رقم الهاتف",
                                  onChanged: (value) {},
                                  focusNode: controller.emailFocusNode,
                                  nextFocus: controller.passwordFocusNode,
                                  textInputType: TextInputType.phone,
                                  inputAction: TextInputAction.next,
                                  prefixIcon: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      start: Dimensions.space12,
                                      end: Dimensions.space8,
                                    ),
                                    child: Icon(
                                      Icons.phone_android,
                                      color: MyColor.primaryColor,
                                      size: Dimensions.space25,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "يرجى إدخال رقم الهاتف";
                                    } else if (value.length < 10) {
                                      return "رقم الهاتف غير صحيح";
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space20),
                                CustomTextField(
                                  hintText: MyStrings.password.tr,
                                  controller: controller.passwordController,
                                  focusNode: controller.passwordFocusNode,
                                  onChanged: (value) {},
                                  isShowSuffixIcon: true,
                                  isPassword: true,
                                  textInputType: TextInputType.text,
                                  inputAction: TextInputAction.done,
                                  prefixIcon: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      start: Dimensions.space12,
                                      end: Dimensions.space8,
                                    ),
                                    child: CustomSvgPicture(
                                      image: MyIcons.password,
                                      color: MyColor.primaryColor,
                                      height: Dimensions.space30,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return MyStrings.fieldErrorMsg.tr;
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [

                                    // --- تم استبدال مربع الصح بزر اليوتيوب هنا ---
                                    InkWell(
                                      onTap: () {
                                        _openYouTubeTutorial(); // فتح فيديو اليوتيوب
                                      },
                                      child: DefaultText(
                                        text: "شرح طريقة التسجيل 🎥",
                                        textColor: MyColor.primaryColor,
                                        textStyle: boldDefault.copyWith(
                                          fontSize: Dimensions.fontLarge,
                                          decoration: TextDecoration.underline, // خط تحت النص
                                        ),
                                      ),
                                    ),
                                    // ---------------------------------------------

                                    InkWell(
                                      onTap: () {
                                        _openWhatsAppSupport();
                                      },
                                      child: DefaultText(
                                        text: "نسيت الباسورد؟",
                                        textColor: MyColor.redCancelTextColor,
                                        textStyle: boldDefault.copyWith(
                                          fontSize: Dimensions.fontLarge,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                spaceDown(Dimensions.space25),
                                RoundedButton(
                                  isLoading: controller.isSubmitLoading,
                                  text: MyStrings.logIn.tr,
                                  press: () {
                                    if (formKey.currentState!.validate()) {
                                      controller.loginUser();
                                    }
                                  },
                                ),
                                spaceDown(Dimensions.space30),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      MyStrings.doNotHaveAccount.tr,
                                      overflow: TextOverflow.ellipsis,
                                      style: boldLarge.copyWith(
                                        color: MyColor.getBodyTextColor(),
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(width: Dimensions.space5),
                                    TextButton(
                                      onPressed: () {
                                        Get.offAndToNamed(
                                          RouteHelper.registrationScreen,
                                        );
                                      },
                                      child: Text(
                                        MyStrings.register.tr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: boldLarge.copyWith(
                                          color: MyColor.getPrimaryColor(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}