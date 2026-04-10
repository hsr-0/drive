import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
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
  bool remember = true; // تم تعديل القيمة الافتراضية إلى true كإجراء إضافي للتأكيد

  void forgetPassword() {
    Get.toNamed(RouteHelper.forgotPasswordScreen);
  }

  bool isSubmitLoading = false;

  void loginUser() async {
    isSubmitLoading = true;
    update();

    ResponseModel model = await loginRepo.loginUser(
      emailController.text.toString(),
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

        // التعديل الرئيسي: تمرير true بشكل ثابت دائماً لتفعيل ميزة التذكر
        await RouteHelper.checkUserStatusAndGoToNextStep(
          user,
          accessToken: accessToken,
          tokenType: tokenType,
          isRemember: true,
        );

        // تم إزالة الكود الذي كان يغير حالة remember بعد تسجيل الدخول لأنه لم يعد ضرورياً

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

    if (remember) {
      remember = false;
    }
    update();
  }
}