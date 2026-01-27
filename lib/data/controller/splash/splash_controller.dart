import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/messages.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/controller/localization/localization_controller.dart';
import 'package:ovoride_driver/data/model/general_setting/general_setting_response_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/repo/auth/general_setting_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

import '../../model/authorization/authorization_response_model.dart';

class SplashController extends GetxController {
  GeneralSettingRepo repo;
  LocalizationController localizationController;
  SplashController({required this.repo, required this.localizationController});

  bool isLoading = true;
  Future<void> gotoNextPage() async {
    await loadLanguage();
    bool isRemember = repo.apiClient.sharedPreferences.getBool(
          SharedPreferenceHelper.rememberMeKey,
        ) ??
        false;
    noInternet = false;
    update();

    initSharedData();

    getGSData(isRemember);
  }

  bool noInternet = false;
  void getGSData(bool isRemember) async {
    ResponseModel response = await repo.getGeneralSetting();
    bool isOnboardAlreadyDisplayed = repo.apiClient.sharedPreferences.getBool(
          SharedPreferenceHelper.onBoardKey,
        ) ??
        false;

    if (response.statusCode == 200) {
      GeneralSettingResponseModel model = GeneralSettingResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.status?.toLowerCase() == MyStrings.success) {
        repo.apiClient.storeGeneralSetting(model);
        repo.apiClient.storePushSetting(
          model.data?.generalSetting?.pushConfig ?? PusherConfig(),
        );
        repo.apiClient.storeNotificationAudio(
          "${UrlContainer.domainUrl}/${model.data?.notificationAudioPath}/${model.data?.generalSetting?.notificationAudio ?? ""}",
        );
      } else {
        if (model.remark == "maintenance_mode") {
          Future.delayed(const Duration(seconds: 1), () {
            Get.offAndToNamed(RouteHelper.maintenanceScreen);
          });
          return;
        } else {
          List<String> message = [MyStrings.somethingWentWrong];
          CustomSnackBar.error(errorList: model.message ?? message);
        }
      }
    } else {
      if (response.statusCode == 503) {
        noInternet = true;
        update();
      }
      CustomSnackBar.error(errorList: [response.message]);
    }

    isLoading = false;
    update();
    if (isOnboardAlreadyDisplayed == false) {
      Future.delayed(const Duration(seconds: 1), () {
        Get.offAndToNamed(RouteHelper.onboardScreen);
      });
    } else if (isRemember) {
      Future.delayed(const Duration(seconds: 1), () {
        Get.offAndToNamed(RouteHelper.dashboard);
      });
    } else {
      Future.delayed(const Duration(seconds: 1), () {
        Get.offAndToNamed(RouteHelper.loginScreen);
      });
    }
  }

  Future<bool> initSharedData() {
    if (!repo.apiClient.sharedPreferences.containsKey(
      SharedPreferenceHelper.countryCode,
    )) {
      return repo.apiClient.sharedPreferences.setString(
        SharedPreferenceHelper.countryCode,
        localizationController.defaultLanguage.countryCode,
      );
    }
    if (!repo.apiClient.sharedPreferences.containsKey(
      SharedPreferenceHelper.languageCode,
    )) {
      return repo.apiClient.sharedPreferences.setString(
        SharedPreferenceHelper.languageCode,
        localizationController.defaultLanguage.languageCode,
      );
    }
    return Future.value(true);
  }

  Future<void> loadLanguage() async {
    localizationController.loadCurrentLanguage();
    String languageCode = localizationController.locale.languageCode;
    ResponseModel response = await repo.getLanguage(languageCode);

    if (response.statusCode == 200) {
      AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.remark == "maintenance_mode") {
        Future.delayed(const Duration(seconds: 1), () {
          Get.offAndToNamed(RouteHelper.maintenanceScreen);
        });
        return;
      }
      try {
        Map<String, Map<String, String>> language = {};
        var resJson = (response.responseJson);
        saveLanguageList(jsonEncode(response.responseJson));
        var value = resJson['data']['file'].toString() == '[]' ? {} : resJson['data']['file'];
        Map<String, String> json = {};
        printX(value);
        value.forEach((key, value) {
          json[key] = value.toString();
        });
        language['${localizationController.locale.languageCode}_${localizationController.locale.countryCode}'] = json;
        Get.addTranslations(Messages(languages: language).keys);
      } catch (e) {
        if (kDebugMode) {
          CustomSnackBar.error(errorList: [e.toString()]);
        }
      }
    } else {
      CustomSnackBar.error(errorList: [response.message]);
    }
  }

  void saveLanguageList(String languageJson) async {
    await repo.apiClient.sharedPreferences.setString(
      SharedPreferenceHelper.languageListKey,
      languageJson,
    );
    return;
  }
}
