import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/app_status.dart';
import 'package:ovoride_driver/core/utils/my_color.dart';
import 'package:ovoride_driver/core/utils/style.dart';
import 'package:ovoride_driver/data/model/global/formdata/global_kyc_form_data.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'my_strings.dart';

class MyUtils {
  static Future<void> vibrate() async {
    final hasVibrator = await Vibration.hasVibrator();

    if (Platform.isAndroid) {
      // ✅ Android: use full vibration
      if (hasVibrator) {
        await Vibration.vibrate(duration: 800);
      }
    } else if (Platform.isIOS) {
      // ✅ iOS: use haptic feedback instead
      HapticFeedback.heavyImpact();
    } else {
      // ✅ Fallback for web or other platforms
      if (hasVibrator) {
        await Vibration.vibrate(duration: 500);
      }
    }
  }

  static void splashScreen() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: MyColor.getPrimaryColor(),
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: MyColor.getPrimaryColor(),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  static void allScreen() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: MyColor.getPrimaryColor(),
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: MyColor.colorWhite,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  static dynamic getShadow() {
    return [
      BoxShadow(
        blurRadius: 15.0,
        offset: const Offset(0, 25),
        color: Colors.grey.shade500.withValues(alpha: 0.6),
        spreadRadius: -35.0,
      ),
    ];
  }

  static void copy({required String text}) {
    Clipboard.setData(ClipboardData(text: text)).then((value) {
      CustomSnackBar.showToast(message: MyStrings.copiedToClipBoard.tr);
    });
  }

  static Future<void> precacheImagesFromPathList(
    BuildContext context,
    List<String> paths,
  ) async {
    for (final path in paths) {
      late ImageProvider imageProvider;

      if (path.startsWith('http') || path.startsWith('https')) {
        imageProvider = NetworkImage(path);
      } else {
        imageProvider = AssetImage(path);
      }

      try {
        await precacheImage(imageProvider, context);
        printX('✅ Precached: $path');
      } catch (e) {
        printX('❌ Error precaching $path: $e');
      }
    }
  }

  static String getRideStatus(String status) {
    if (status == '0') {
      return MyStrings.pending;
    } else if (status == '1') {
      return MyStrings.completed;
    } else if (status == '2') {
      return MyStrings.active;
    } else if (status == '3') {
      return MyStrings.running;
    } else if (status == '4') {
      return MyStrings.waitingForPayment;
    } else {
      return MyStrings.canceled;
    }
  }

  static Color getRideStatusColor(String status) {
    if (status == AppStatus.RIDE_PENDING) {
      return MyColor.pendingColor;
    } else if (status == AppStatus.RIDE_COMPLETED) {
      return MyColor.greenSuccessColor;
    } else if (status == AppStatus.RIDE_ACTIVE) {
      return MyColor.highPriorityPurpleColor;
    } else if (status == AppStatus.RIDE_RUNNING) {
      return MyColor.highPriorityPurpleColor;
    } else if (status == AppStatus.RIDE_PAYMENT_REQUESTED) {
      return Colors.lightBlueAccent;
    } else {
      return MyColor.redCancelTextColor;
    }
  }

  static String paymentStatus(String status) {
    if (status == AppStatus.PAYMENT_TYPE_CASH) {
      return MyStrings.cashPayment;
    } else {
      return MyStrings.onlinePayment;
    }
  }

  static dynamic getBottomSheetShadow() {
    return [
      BoxShadow(
        color: Colors.grey.shade400.withValues(alpha: 0.08),
        spreadRadius: 3,
        blurRadius: 4,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static String getDistanceLabel({String? distance, String unit = '1'}) {
    try {
      if (unit == AppStatus.DISTANCE_UNIT_KM) {
        return MyStrings.km.tr;
      }

      if (distance == null || distance.isEmpty) {
        return MyStrings.mile.tr; // always plural when no distance
      }

      final value = double.tryParse(distance) ?? 0;
      final rounded = value.round();

      return rounded == 1 ? MyStrings.mile.tr : MyStrings.miles.tr;
    } catch (e) {
      return '';
    }
  }

  static dynamic getShadow2({double blurRadius = 8}) {
    return [
      BoxShadow(
        color: MyColor.getShadowColor().withValues(alpha: 0.3),
        blurRadius: blurRadius,
        spreadRadius: 3,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: MyColor.getShadowColor().withValues(alpha: 0.3),
        spreadRadius: 1,
        blurRadius: blurRadius,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static dynamic getCardShadow() {
    return [
      BoxShadow(
        color: Colors.grey.shade400.withValues(alpha: 0.05),
        spreadRadius: 2,
        blurRadius: 2,
        offset: const Offset(0, 3),
      ),
    ];
  }

  //Location Permission improver

  static Future<bool> checkAppLocationPermission({Function? onsuccess}) async {
    // Check if location services are enabled on the device
    if (!await Geolocator.isLocationServiceEnabled()) {
      // If not enabled, open settings and show an error message
      await Geolocator.openLocationSettings();
      CustomSnackBar.error(errorList: [MyStrings.locationServiceDisableMsg]);
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    printX("Current permission status: $permission");

    // If permission is denied (first time) - request permission with system dialog
    if (permission == LocationPermission.denied) {
      try {
        // Show the system permission dialog
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 30),
        );
        printX("After request permission: $permission");
        if (onsuccess != null) {
          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            onsuccess.call();
          }
          printD("OOOOOO::::SUCCESS222");
        }
        // If user denies in the system dialog, show a custom message
        if (permission == LocationPermission.denied) {
          CustomSnackBar.error(errorList: [MyStrings.locationPermissionDenied]);
          return false;
        }
      } catch (e) {
        printX("Error requesting permission: $e");
        permission = LocationPermission.denied;
        return false;
      }
    }

    // Handle permanent denial or other cases requiring app settings
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.unableToDetermine) {
      if (Get.context != null) {
        await showCupertinoDialog(
          context: Get.context!,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(
              MyStrings.locationPermissionNeedTitle.tr,
              style: regularLarge.copyWith(
                color: MyColor.getTextColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              MyStrings.locationPermissionNeedMSG.tr,
              style: regularSmall.copyWith(
                color: MyColor.getTextColor(),
                fontWeight: FontWeight.normal,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  MyStrings.cancel.tr,
                  style: regularLarge.copyWith(),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Geolocator.openAppSettings();
                },
                child: Text(
                  MyStrings.openSettings.tr,
                  style: regularLarge.copyWith(
                    color: MyColor.redCancelTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return false;
    }

    // If we reach here, we have permission
    return true;
  }

  static Future<void> launchPhone(String url) async {
    await launchUrl(Uri.parse("tel:$url"));
  }

  static dynamic getCardTopShadow() {
    return [
      BoxShadow(
        color: Colors.grey.shade400.withValues(alpha: 0.05),
        offset: const Offset(0, 0),
        blurRadius: 20,
        spreadRadius: 0,
      ),
    ];
  }

  static dynamic getBottomNavShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 0),
      ),
    ];
  }

  static String getOperationTitle(String value) {
    String number = value;
    RegExp regExp = RegExp(r'^(\d+)(\w+)$');
    Match? match = regExp.firstMatch(number);
    if (match != null) {
      String? num = match.group(1) ?? '';
      String? unit = match.group(2) ?? '';
      String title = '${MyStrings.last.tr} $num ${unit.capitalizeFirst}';
      return title.tr;
    } else {
      return value.tr;
    }
  }

  static String maskSensitiveInformation(String input) {
    try {
      if (input.isEmpty) {
        return '';
      }

      final int maskLength = input.length ~/ 2;

      final String mask = '*' * maskLength;

      final String maskedInput = maskLength > 4 ? input.replaceRange(5, maskLength, mask) : input.replaceRange(0, maskLength, mask);

      return maskedInput;
    } catch (e) {
      return input;
    }
  }

  void stopLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  static List<GlobalFormModel> dynamicFormSelectValueFormatter(
    List<GlobalFormModel>? dynamicFormList,
  ) {
    List<GlobalFormModel> mainFormList = [];

    if (dynamicFormList != null && dynamicFormList.isNotEmpty) {
      mainFormList.clear();

      for (var element in dynamicFormList) {
        if (element.type == 'select') {
          bool? isEmpty = element.options?.isEmpty;
          bool empty = isEmpty ?? true;
          if (element.options != null && empty != true) {
            if (!element.options!.contains(MyStrings.selectOne)) {
              element.options?.insert(0, MyStrings.selectOne);
            }

            element.selectedValue = element.options?.first;
            mainFormList.add(element);
          }
        } else {
          mainFormList.add(element);
        }
      }
    }
    return mainFormList;
  }

  static bool isImage(String path) {
    if (path.contains('.jpg')) {
      return true;
    }
    if (path.contains('.png')) {
      return true;
    }
    if (path.contains('.jpeg')) {
      return true;
    }
    return false;
  }

  static bool isXlsx(String path) {
    if (path.contains('.xlsx')) {
      return true;
    }
    if (path.contains('.xls')) {
      return true;
    }
    if (path.contains('.xlx')) {
      return true;
    }
    return false;
  }

  static bool isDoc(String path) {
    if (path.contains('.doc')) {
      return true;
    }
    if (path.contains('.docs')) {
      return true;
    }
    return false;
  }

  static String maskEmail(String email) {
    try {
      if (email.isEmpty) {
        return '';
      }

      List<String> parts = email.split('@');
      String maskedPart = maskString(parts[0]);

      if (parts.length > 2) {
        return "$maskedPart@${parts[1]}";
      } else {
        return "$maskedPart@${parts[1]}";
      }
    } catch (e) {
      return email;
    }
  }

  static String maskString(String str) {
    if (str.length <= 2) {
      return str.substring(0, 1) + "*" * (str.length - 1);
    } else {
      return str.substring(0, 1) + "*" * (str.length - 2) + str.substring(str.length - 1);
    }
  }

  static Future<Position> getCurrentLocationPosition() async {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
    return position;
  }
}
