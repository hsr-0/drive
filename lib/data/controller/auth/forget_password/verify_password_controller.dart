import 'package:get/get.dart';
import 'package:ovoride_driver/core/route/route.dart';
import 'package:ovoride_driver/data/model/auth/verification/email_verification_model.dart';
import 'package:ovoride_driver/data/repo/auth/login_repo.dart';
import 'package:ovoride_driver/presentation/components/snack_bar/show_custom_snackbar.dart';

class VerifyPasswordController extends GetxController {
  LoginRepo loginRepo;
  VerifyPasswordController({required this.loginRepo});

  String email = '';
  String password = '';
  bool remember = false;
  bool hasError = false;

  List<String> errors = [];
  String currentText = "";
  String confirmPassword = '';

  bool isResendLoading = false;

  void resendForgetPassCode() async {
    isResendLoading = true;
    update();
    String value = email;
    String type = 'email';
    await loginRepo.forgetPassword(type, value);
    isResendLoading = false;
    update();
  }

  bool verifyLoading = false;

  void verifyForgetPasswordCode(String value) async {
    if (value.isNotEmpty) {
      verifyLoading = true;
      update();

      EmailVerificationModel model = await loginRepo.verifyForgetPassCode(
        value,
      );

      if (model.code == 200) {
        verifyLoading = false;
        Get.offAndToNamed(
          RouteHelper.resetPasswordScreen,
          arguments: [email, value],
        );
      } else {
        verifyLoading = false;
        update();
        // List<String> errorList = [MyStrings.verificationFailed];
        CustomSnackBar.error(errorList: model.message ?? []);
      }
    }
  }

  String getFormatMail() {
    try {
      List<String> tempList = email.split('@');
      int maskLength = tempList[0].length;
      String maskValue = tempList[0][0].padRight(maskLength, '*');
      String value = '$maskValue@${tempList[1]}';
      return value;
    } catch (e) {
      return email;
    }
  }
}
