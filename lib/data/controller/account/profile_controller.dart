import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/core/utils/url_container.dart';
import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';
import 'package:ovoride_driver/data/model/profile/profile_response_model.dart';
import 'package:ovoride_driver/data/repo/account/profile_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

import '../../model/authorization/authorization_response_model.dart';
import '../../model/global/response_model/response_model.dart';
import '../../model/profile/profile_post_model.dart';

class ProfileController extends GetxController {
  ProfileRepo profileRepo;
  ProfileResponseModel model = ProfileResponseModel();

  ProfileController({required this.profileRepo});

  String imageUrl = '';

  bool isLoading = true;
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController mobileNoController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController zipCodeController = TextEditingController();
  TextEditingController cityController = TextEditingController();

  FocusNode firstNameFocusNode = FocusNode();
  FocusNode lastNameFocusNode = FocusNode();
  FocusNode emailFocusNode = FocusNode();
  FocusNode mobileNoFocusNode = FocusNode();
  FocusNode addressFocusNode = FocusNode();
  FocusNode stateFocusNode = FocusNode();
  FocusNode zipCodeFocusNode = FocusNode();
  FocusNode cityFocusNode = FocusNode();
  FocusNode countryFocusNode = FocusNode();

  File? imageFile;

  GlobalDriverInfoModel driver = GlobalDriverInfoModel();
  bool user2faIsOne = false;

  Future<void> loadProfileInfo({bool shouldLoad = true}) async {
    isLoading = shouldLoad;
    model = await profileRepo.loadProfileInfo();
    if (model.data != null && model.status?.toLowerCase() == MyStrings.success.toLowerCase()) {
      loadData(model);
    } else {
      isLoading = false;
      update();
    }
  }

  bool isSubmitLoading = false;
  Future<void> updateProfile() async {
    isSubmitLoading = true;
    update();

    String firstName = firstNameController.text;
    String lastName = lastNameController.text.toString();
    String address = addressController.text.toString();
    String city = cityController.text.toString();
    String zip = zipCodeController.text.toString();
    String state = stateController.text.toString();

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      ProfilePostModel model = ProfilePostModel(
        address: address,
        state: state,
        zip: zip,
        city: city,
        image: imageFile,
        firstname: firstName,
        lastName: lastName,
      );

      AuthorizationResponseModel b = await profileRepo.updateProfile(model);

      if (b.status == 'success') {
        await loadProfileInfo(shouldLoad: false);
      }
    } else {
      if (firstName.isEmpty) {
        CustomSnackBar.error(errorList: [MyStrings.kFirstNameNullError.tr]);
      }
      if (lastName.isEmpty) {
        CustomSnackBar.error(errorList: [MyStrings.kLastNameNullError.tr]);
      }
    }

    isSubmitLoading = false;
    update();
  }

  void loadData(ProfileResponseModel? model) {
    driver = model?.data?.driver ?? GlobalDriverInfoModel();
    profileRepo.apiClient.sharedPreferences.setString(
      SharedPreferenceHelper.userProfileKey,
      model?.data?.driver?.imageWithPath ?? '',
    );
    firstNameController.text = model?.data?.driver?.firstname ?? '';
    lastNameController.text = model?.data?.driver?.lastname ?? '';
    emailController.text = model?.data?.driver?.email ?? '';
    mobileNoController.text = model?.data?.driver?.mobile ?? '';
    addressController.text = model?.data?.driver?.address ?? '';
    stateController.text = model?.data?.driver?.state ?? '';
    zipCodeController.text = model?.data?.driver?.zip ?? '';
    cityController.text = model?.data?.driver?.city ?? '';
    imageUrl = "${UrlContainer.domainUrl}/${model?.data?.driverImagePath}/${model?.data?.driver?.image}";
    user2faIsOne = model?.data?.driver?.ts == "1" ? true : false;
    isLoading = false;
    update();
  }

  void openGallery(BuildContext context) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    imageFile = File(pickedFile!.path);
    update();
  }

  final InAppReview inAppReview = InAppReview.instance;

  bool logoutLoading = false;
  Future<void> logout() async {
    logoutLoading = true;
    update();

    await profileRepo.logout();
    CustomSnackBar.success(successList: [MyStrings.logoutSuccessMsg]);

    logoutLoading = false;
    update();
    Get.offAllNamed(RouteHelper.loginScreen);
  }

  //delete account

  bool noInternet = false;
  bool isDeleteBtnLoading = false;

  Future<void> deleteAccount() async {
    isDeleteBtnLoading = true;
    update();

    ResponseModel response = await profileRepo.deleteAccount();

    if (response.statusCode == 200) {
      AuthorizationResponseModel model = AuthorizationResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.status?.toLowerCase() == MyStrings.success.toLowerCase()) {
        profileRepo.apiClient.sharedPreferences.setBool(
          SharedPreferenceHelper.rememberMeKey,
          false,
        );
        profileRepo.apiClient.sharedPreferences.setString(
          SharedPreferenceHelper.accessTokenKey,
          "",
        );

        Get.offAllNamed(RouteHelper.loginScreen);
        CustomSnackBar.error(
          errorList: model.message ?? [MyStrings.accountDeletedSuccessfully],
        );
      } else {
        List<String> message = [MyStrings.somethingWentWrong];
        CustomSnackBar.error(errorList: model.message ?? message);
      }
    } else {
      if (response.statusCode == 503) {
        noInternet = true;
        update();
      }
      CustomSnackBar.error(errorList: [response.message]);
    }

    isDeleteBtnLoading = false;
    update();
  }
}
