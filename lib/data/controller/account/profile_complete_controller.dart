import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/country_model/country_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/profile/profile_response_model.dart';
import 'package:ovoride_driver/data/model/zone/zone_list_response_model.dart';
import 'package:ovoride_driver/data/repo/account/profile_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

import '../../model/profile_complete/profile_complete_post_model.dart';
import '../../model/profile_complete/profile_complete_response_model.dart';

class ProfileCompleteController extends GetxController {
  ProfileRepo profileRepo;
  ProfileCompleteController({required this.profileRepo});

  ProfileResponseModel model = ProfileResponseModel();

  TextEditingController userNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController mobileNoController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController zipCodeController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController referController = TextEditingController();
  TextEditingController countryController = TextEditingController();

  FocusNode emailFocusNode = FocusNode();
  FocusNode mobileNoFocusNode = FocusNode();
  FocusNode zoneFocusNode = FocusNode();
  FocusNode addressFocusNode = FocusNode();
  FocusNode stateFocusNode = FocusNode();
  FocusNode zipCodeFocusNode = FocusNode();
  FocusNode cityFocusNode = FocusNode();
  FocusNode countryFocusNode = FocusNode();
  final FocusNode mobileFocusNode = FocusNode();
  FocusNode userNameFocusNode = FocusNode();

  Future<void> initialData() async {
    // await getZoneData();
    countryList = profileRepo.apiClient.getOperatingCountries();
    update();
    if (countryList.isNotEmpty) {
      selectCountryData(countryList.first);
    }
    isLoading = false;
    update();
    printX(countryList.first.toJson());
  }

  TextEditingController searchController = TextEditingController();

  ProfileResponseModel profileResponseModel = ProfileResponseModel();

  String imageUrl = '';

  File? imageFile;
  String emailData = '';
  String countryData = '';
  String countryCodeData = '';
  String phoneCodeData = '';
  String phoneData = '';
  String loginType = '';

  String? countryName;
  String? countryCode;
  String? dialCode;
  ZoneData selectedZone = ZoneData(id: "-1");

  Future<void> loadProfileInfo() async {
    isLoading = true;
    update();
    try {
      profileResponseModel = await profileRepo.loadProfileInfo();
      if (profileResponseModel.data != null && profileResponseModel.status?.toLowerCase() == MyStrings.success.toLowerCase()) {
        emailData = profileResponseModel.data?.driver?.email ?? '';
        countryData = profileResponseModel.data?.driver?.countryName ?? '';
        countryCodeData = profileResponseModel.data?.driver?.countryCode ?? '';
        phoneData = profileResponseModel.data?.driver?.mobile ?? '';
      } else {
        isLoading = false;
        update();
      }
    } catch (e) {
      isLoading = false;
      update();
    }
    isLoading = false;
    update();
  }

  TextEditingController searchCountryController = TextEditingController();
  bool countryLoading = true;
  List<Countries> countryList = [];
  List<Countries> filteredCountries = [];

  bool isLoading = true;
  bool submitLoading = false;

  Future<void> updateProfile() async {
    if (mobileNoController.text.isEmpty) {
      CustomSnackBar.error(errorList: [MyStrings.enterYourPhoneNumber.tr]);
      return;
    }
    if (selectedZone.id == '-1') {
      CustomSnackBar.error(errorList: [MyStrings.selectYourZone]);
      return;
    }
    String username = userNameController.text;
    String mobileNumber = mobileNoController.text;
    String address = addressController.text.toString();
    String city = cityController.text.toString();
    String zip = zipCodeController.text.toString();
    String state = stateController.text.toString();
    String zoneId = selectedZone.id ?? '';
    submitLoading = true;
    update();

    ProfileCompletePostModel model = ProfileCompletePostModel(
      username: username,
      countryName: selectedCountryData.country ?? '',
      countryCode: selectedCountryData.countryCode ?? '',
      mobileNumber: mobileNumber,
      mobileCode: selectedCountryData.dialCode ?? '',
      address: address,
      state: state,
      zip: zip,
      city: city,
      image: null,
      zone: zoneId,
    );

    ResponseModel responseModel = await profileRepo.completeProfile(model);

    if (responseModel.statusCode == 200) {
      ProfileCompleteResponseModel model = ProfileCompleteResponseModel.fromJson((responseModel.responseJson));
      if (model.status?.toLowerCase() == MyStrings.success.toLowerCase()) {
        RouteHelper.checkUserStatusAndGoToNextStep(model.data?.user);
      } else {
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.requestFail],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [responseModel.message]);
    }

    submitLoading = false;
    update();
  }

  Countries selectedCountryData = Countries();
  void selectCountryData(Countries value) {
    selectedCountryData = value;
    update();
  }

  bool zoneLoading = false;
  int page = 0;
  List<ZoneData> zoneList = [];
  TextEditingController searchZoneController = TextEditingController();

  Future<void> initZoneData({bool shouldLoad = false}) async {
    zoneLoading = shouldLoad;
    page = 0;
    if (shouldLoad) {
      searchZoneController.clear();
    }
    update();
    await getZoneData(shouldLoad: shouldLoad);
  }

  Future<dynamic> getZoneData({bool shouldLoad = false}) async {
    try {
      page = page + 1;
      if (page == 1) {
        zoneLoading = shouldLoad;
        update();
      }
      ResponseModel mainResponse = await profileRepo.getZoneList(page.toString(), search: searchZoneController.text);

      if (mainResponse.statusCode == 200) {
        ZoneListResponseModel model = ZoneListResponseModel.fromJson((mainResponse.responseJson));

        if (model.status == MyStrings.success) {
          nextPageUrl = model.data?.zones?.nextPageUrl;
          List<ZoneData>? tempList = model.data?.zones?.data;
          if (page == 1) {
            zoneList.clear();
          }
          if (tempList != null && tempList.isNotEmpty) {
            zoneList.addAll(tempList);
          }
          zoneLoading = false;
          update();
        }
      } else {
        CustomSnackBar.error(errorList: [mainResponse.message]);
        zoneLoading = false;
        update();
      }
    } catch (e) {
      printE(e);
    } finally {
      zoneLoading = false;
      update();
    }
  }

  bool hasNext() {
    return nextPageUrl != null && nextPageUrl!.isNotEmpty && nextPageUrl != 'null' ? true : false;
  }

  String? nextPageUrl;

  void selectZone(ZoneData zone) {
    selectedZone = zone;
    update();
  }
}
