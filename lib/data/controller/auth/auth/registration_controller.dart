import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/core/helper/string_format_helper.dart';
import 'package:ovoride_driver/data/model/zone/zone_list_response_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/auth/sign_up_model/registration_response_model.dart';
import 'package:ovoride_driver/data/model/auth/sign_up_model/sign_up_model.dart';
import 'package:ovoride_driver/data/model/general_setting/general_setting_response_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/model/error_model.dart';
import 'package:ovoride_driver/data/repo/auth/general_setting_repo.dart';
import 'package:ovoride_driver/data/repo/auth/signup_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class RegistrationController extends GetxController {
  RegistrationRepo registrationRepo;
  GeneralSettingRepo generalSettingRepo;

  RegistrationController({
    required this.registrationRepo,
    required this.generalSettingRepo,
  });

  bool isLoading = true;
  bool agreeTC = false;
  bool isReferralEnable = false;

  GeneralSettingResponseModel generalSettingMainModel = GeneralSettingResponseModel();

  bool checkPasswordStrength = false;
  bool needAgree = true;

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();
  final FocusNode firstNameFocusNode = FocusNode();
  final FocusNode lastNameFocusNode = FocusNode();
  final FocusNode referNameFocusNode = FocusNode();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController cPasswordController = TextEditingController();
  final TextEditingController fNameController = TextEditingController();
  final TextEditingController lNameController = TextEditingController();
  final TextEditingController referNameController = TextEditingController();

  String? email;
  String? password;
  String? confirmPassword;
  String? countryName;
  String? countryCode;
  String? mobileCode;
  String? userName;
  String? phoneNo;
  String? firstName;
  String? lastName;
  ZoneData selectedZone = ZoneData(id: "-1");

  RegExp regex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
  bool submitLoading = false;

  Future<void> signUpUser() async {
    if (needAgree && !agreeTC) {
      CustomSnackBar.error(errorList: [MyStrings.agreePolicyMessage]);
      return;
    }

    submitLoading = true;
    update();

    try {
      SignUpModel model = getUserData();
      ResponseModel responseModel = await registrationRepo.registerUser(model);
      printX(responseModel.statusCode);
      if (responseModel.statusCode == 200) {
        RegistrationResponseModel model = RegistrationResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (model.status?.toLowerCase() == MyStrings.success.toLowerCase()) {
          CustomSnackBar.success(
            successList: model.message ?? [MyStrings.success.tr],
          );
          checkAndGotoNextStep(model);
        } else {
          CustomSnackBar.error(
            errorList: model.message ?? [MyStrings.somethingWentWrong.tr],
          );
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e);
    }

    submitLoading = false;
    update();
  }

  void updateAgreeTC() {
    agreeTC = !agreeTC;
    update();
  }

  void closeAllController() {
    isLoading = false;
    emailController.text = '';
    passwordController.text = '';
    cPasswordController.text = '';
    fNameController.text = '';
    lNameController.text = '';
  }

  void clearAllData() {
    closeAllController();
  }

  List<ErrorModel> passwordValidationRules = [
    ErrorModel(text: MyStrings.hasUpperLetter.tr, hasError: true),
    ErrorModel(text: MyStrings.hasLowerLetter.tr, hasError: true),
    ErrorModel(text: MyStrings.hasDigit.tr, hasError: true),
    ErrorModel(text: MyStrings.hasSpecialChar.tr, hasError: true),
    ErrorModel(text: MyStrings.minSixChar.tr, hasError: true),
  ];

  String? validatePassword(String value) {
    if (value.isEmpty) {
      return MyStrings.enterYourPassword_.tr;
    } else {
      if (checkPasswordStrength) {
        if (!regex.hasMatch(value)) {
          return MyStrings.invalidPassMsg.tr;
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
  }

  void checkAndGotoNextStep(RegistrationResponseModel responseModel) async {
    SharedPreferences preferences = registrationRepo.apiClient.sharedPreferences;

    await preferences.setString(
      SharedPreferenceHelper.userIdKey,
      responseModel.data?.user?.id.toString() ?? '-1',
    );
    await preferences.setString(
      SharedPreferenceHelper.accessTokenKey,
      responseModel.data?.accessToken ?? '',
    );
    await preferences.setString(
      SharedPreferenceHelper.accessTokenType,
      responseModel.data?.tokenType ?? '',
    );
    await preferences.setString(
      SharedPreferenceHelper.userEmailKey,
      responseModel.data?.user?.email ?? '',
    );
    await preferences.setString(
      SharedPreferenceHelper.userNameKey,
      responseModel.data?.user?.username ?? '',
    );
    await preferences.setString(
      SharedPreferenceHelper.userPhoneNumberKey,
      responseModel.data?.user?.mobile ?? '',
    );

    Get.offAndToNamed(RouteHelper.profileCompleteScreen);
  }

  bool isCountryLoading = true;
  void initData() async {
    isLoading = true;
    update();

    ResponseModel response = await generalSettingRepo.getGeneralSetting();
    if (response.statusCode == 200) {
      GeneralSettingResponseModel model = GeneralSettingResponseModel.fromJson(
        (response.responseJson),
      );
      if (model.status?.toLowerCase() == 'success') {
        generalSettingMainModel = model;
        registrationRepo.apiClient.storeGeneralSetting(model);
      } else {
        List<String> message = [MyStrings.somethingWentWrong.tr];
        CustomSnackBar.error(errorList: model.message ?? message);
        return;
      }
    } else {
      if (response.statusCode == 503) {
        noInternet = true;
        update();
      }
      CustomSnackBar.error(errorList: [response.message]);
      return;
    }

    needAgree = generalSettingMainModel.data?.generalSetting?.agree.toString() == '0' ? false : true;
    checkPasswordStrength = generalSettingMainModel.data?.generalSetting?.securePassword.toString() == '0' ? false : true;

    isLoading = false;
    update();
  }

  bool noInternet = false;
  void changeInternet(bool hasInternet) {
    noInternet = false;
    initData();
    update();
  }

  void updateValidationList(String value) {
    passwordValidationRules[0].hasError = value.contains(RegExp(r'[A-Z]')) ? false : true;
    passwordValidationRules[1].hasError = value.contains(RegExp(r'[a-z]')) ? false : true;
    passwordValidationRules[2].hasError = value.contains(RegExp(r'[0-9]')) ? false : true;
    passwordValidationRules[3].hasError = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')) ? false : true;
    passwordValidationRules[4].hasError = value.length >= 6 ? false : true;

    update();
  }

  bool hasPasswordFocus = false;
  void changePasswordFocus(bool hasFocus) {
    hasPasswordFocus = hasFocus;
    update();
  }

  SignUpModel getUserData() {
    SignUpModel model = SignUpModel(
      firstName: fNameController.text.toString(),
      lastName: lNameController.text.toString(),
      email: emailController.text.toString(),
      password: passwordController.text.toString(),
      agree: agreeTC ? true : false,
    );

    return model;
  }
}
