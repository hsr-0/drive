import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';

import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/core/utils/my_strings.dart';
import 'package:ovoride_driver/data/model/auth/login/login_response_model.dart';
import 'package:ovoride_driver/data/model/global/response_model/response_model.dart';
import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';
import 'package:ovoride_driver/data/repo/auth/login_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class LoginController extends GetxController {
  LoginRepo loginRepo;
  LoginController({required this.loginRepo});

  final FocusNode mobileNumberFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  TextEditingController mobileNumberController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  String? email;
  String? password;

  List<String> errors = [];
  bool remember = true;

  void forgetPassword() {
    Get.toNamed(RouteHelper.forgotPasswordScreen);
  }

  bool isSubmitLoading = false;

  void loginUser() async {
    isSubmitLoading = true;
    update();

    String phone = emailController.text.trim();
    String fakeEmail = "$phone@driver.beytei.com";

    ResponseModel model = await loginRepo.loginUser(
      fakeEmail,
      passwordController.text.toString(),
    );

    if (model.statusCode == 200) {
      LoginResponseModel loginModel = LoginResponseModel.fromJson(
        (model.responseJson),
      );
      if (loginModel.status.toString().toLowerCase() == MyStrings.success.toLowerCase()) {
        String accessToken = loginModel.data?.accessToken ?? "";
        String tokenType = loginModel.data?.tokenType ?? "";
        GlobalDriverInfoModel? user = loginModel.data?.user;

        // --- بداية التعديل: إجبار التطبيق على حفظ التوكن والبيانات محلياً وتذكر الدخول ---
        try {
          SharedPreferences preferences = loginRepo.apiClient.sharedPreferences;
          await preferences.setString(SharedPreferenceHelper.userIdKey, user?.id.toString() ?? '-1');
          await preferences.setString(SharedPreferenceHelper.accessTokenKey, accessToken);
          await preferences.setString(SharedPreferenceHelper.accessTokenType, tokenType);
          await preferences.setString(SharedPreferenceHelper.userEmailKey, user?.email ?? '');
          await preferences.setString(SharedPreferenceHelper.userNameKey, user?.username ?? '');
          await preferences.setString(SharedPreferenceHelper.userPhoneNumberKey, user?.mobile ?? '');

          // السطر السحري لمنع تسجيل الخروج عند إغلاق التطبيق
          await preferences.setBool(SharedPreferenceHelper.rememberMeKey, true);

        } catch (e) {
          print("خطأ في حفظ البيانات: $e");
        }
        // --- نهاية التعديل ---

        await RouteHelper.checkUserStatusAndGoToNextStep(
          user,
          accessToken: accessToken,
          tokenType: tokenType,
          isRemember: true,
        );

      } else {
        CustomSnackBar.error(
          errorList: loginModel.message ?? [MyStrings.loginFailedTryAgain],
        );
      }
    } else {
      CustomSnackBar.error(errorList: [model.message]);
    }

    isSubmitLoading = false;
    update();
  }

  void changeRememberMe() {
    remember = !remember;
    update();
  }

  void clearTextField() {
    passwordController.text = '';
    emailController.text = '';
  }
}