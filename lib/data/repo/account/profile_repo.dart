import 'dart:io';

import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/utils/method.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/model/authorization/authorization_response_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/profile/profile_response_model.dart';
import 'package:ovoride_driver/data/services/api_client.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

import '../../model/profile/profile_post_model.dart';
import '../../model/profile_complete/profile_complete_post_model.dart';

class ProfileRepo {
  ApiClient apiClient;

  ProfileRepo({required this.apiClient});

  Future<AuthorizationResponseModel> updateProfile(ProfilePostModel m) async {
    try {
      apiClient.initToken();

      String url = '${UrlContainer.baseUrl}${UrlContainer.updateProfileEndPoint}';

      Map<String, String> finalMap = {
        'firstname': m.firstname,
        'lastname': m.lastName,
        'address': m.address ?? '',
        'zip': m.zip ?? '',
        'state': m.state ?? "",
        'city': m.city ?? '',
      };
      printX(finalMap);
      //Attachments file list
      Map<String, File> attachmentFiles = {};
      if (m.image != null) {
        attachmentFiles = {"image": m.image!};
      }

      ResponseModel responseModel = await apiClient.multipartRequest(
        url,
        Method.postMethod,
        finalMap,
        files: attachmentFiles,
        passHeader: true,
      );

      AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
        (responseModel.responseJson),
      );

      if (model.status?.toLowerCase() == MyStrings.success.toLowerCase()) {
        CustomSnackBar.success(
          successList: model.message ?? [MyStrings.success],
        );
        return model;
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail.tr],
        );
        return model;
      }
    } catch (e) {
      return AuthorizationResponseModel(
        status: "error",
        message: [MyStrings.somethingWentWrong],
      );
    }
  }

  Future<ResponseModel> completeProfile(ProfileCompletePostModel model) async {
    dynamic params = model.toMap();
    String url = '${UrlContainer.baseUrl}${UrlContainer.profileCompleteEndPoint}';
    ResponseModel responseModel = await apiClient.request(
      url,
      Method.postMethod,
      params,
      passHeader: true,
    );
    return responseModel;
  }

  Future<dynamic> deleteAccount() async {
    try {
      String url = '${UrlContainer.baseUrl}${UrlContainer.userDeleteEndPoint}';
      ResponseModel response = await apiClient.request(
        url,
        Method.postMethod,
        null,
        passHeader: true,
      );
      return response;
    } catch (e) {
      return ResponseModel(false, MyStrings.somethingWentWrong.tr, 300, '');
    }
  }

  Future<ProfileResponseModel> loadProfileInfo() async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.getProfileEndPoint}';

    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );

    if (responseModel.statusCode == 200) {
      ProfileResponseModel model = ProfileResponseModel.fromJson(
        (responseModel.responseJson),
      );
      if (model.status == 'success') {
        return model;
      } else {
        return ProfileResponseModel();
      }
    } else {
      return ProfileResponseModel();
    }
  }

  Future<dynamic> getCountryList() async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.countryEndPoint}';
    ResponseModel model = await apiClient.request(url, Method.getMethod, null);
    return model;
  }

  Future<dynamic> getZoneList(String page, {String search = ""}) async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.zones}?page=$page&search=$search';
    ResponseModel model = await apiClient.request(url, Method.getMethod, null);
    return model;
  }

  Future<ResponseModel> logout() async {
    String url = '${UrlContainer.baseUrl}${UrlContainer.logoutUrl}';

    ResponseModel responseModel = await apiClient.request(
      url,
      Method.getMethod,
      null,
      passHeader: true,
    );
    await clearSharedPrefData();
    return responseModel;
  }

  Future<void> clearSharedPrefData() async {
    await apiClient.sharedPreferences.setString(
      SharedPreferenceHelper.userNameKey,
      '',
    );
    await apiClient.sharedPreferences.setString(
      SharedPreferenceHelper.userEmailKey,
      '',
    );
    await apiClient.sharedPreferences.setString(
      SharedPreferenceHelper.accessTokenType,
      '',
    );
    await apiClient.sharedPreferences.setString(
      SharedPreferenceHelper.accessTokenKey,
      '',
    );
    await apiClient.sharedPreferences.setBool(
      SharedPreferenceHelper.rememberMeKey,
      false,
    );
    apiClient.setOnlineStatus(false);
    return Future.value();
  }
}
