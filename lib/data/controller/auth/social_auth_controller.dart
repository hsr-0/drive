import 'package:google_sign_in/google_sign_in.dart';
import 'package:get/get.dart';
import '../../../core/helper/string_format_helper.dart';
import '../../../core/route/route.dart';
import '../../../core/utils/my_strings.dart';
import '../../../presentation/components/snack_bar/show_custom_snackbar.dart';
import '../../model/auth/login/login_response_model.dart';
import '../../model/global/response_model/response_model.dart';
import '../../repo/auth/social_auth_repo.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialAuthController extends GetxController {
  SocialAuthRepo authRepo;
  SocialAuthController({required this.authRepo});

  final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  bool isGoogleSignInLoading = false;

  Future<void> signInWithGoogle() async {
    try {
      isGoogleSignInLoading = true;
      update();
      const List<String> scopes = <String>['email', 'profile'];
      googleSignIn.signOut();
      await googleSignIn.initialize();
      var googleUser = await googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        isGoogleSignInLoading = false;
        update();
        return;
      }
      final GoogleSignInClientAuthorization? authorization = await googleUser.authorizationClient.authorizationForScopes(scopes);
      printX(authorization?.accessToken);

      await socialLoginUser(
        provider: 'google',
        accessToken: authorization?.accessToken ?? '',
      );
    } catch (e) {
      printX(e.toString());
      // CustomSnackBar.error(errorList: [e.toString()]);
    }

    isGoogleSignInLoading = false;
    update();
  }

  bool isAppleSignInLoading = false;
  Future signInWithApple() async {
    isAppleSignInLoading = true;
    update();
    try {
      final AuthorizationCredentialAppleID credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      printX(credential.email);
      printX(credential.givenName);
      printX(credential.familyName);
      printX(credential.authorizationCode);
      printX(credential.identityToken);
      socialLoginUser(
        provider: 'apple',
        accessToken: credential.identityToken ?? '',
      );
    } catch (e) {
      printX(e.toString());
      // CustomSnackBar.error(errorList: [e.toString()]);
    } finally {
      isAppleSignInLoading = false;
      update();
    }
  }

  Future socialLoginUser({String accessToken = '', String? provider}) async {
    try {
      ResponseModel responseModel = await authRepo.socialLoginUser(
        accessToken: accessToken,
        provider: provider,
      );
      if (responseModel.statusCode == 200) {
        LoginResponseModel loginModel = LoginResponseModel.fromJson(
          (responseModel.responseJson),
        );
        if (loginModel.status.toString().toLowerCase() == MyStrings.success.toLowerCase()) {
          await RouteHelper.checkUserStatusAndGoToNextStep(
            loginModel.data?.user,
            accessToken: loginModel.data?.accessToken ?? "",
            tokenType: loginModel.data?.tokenType ?? '',
            isRemember: true,
          );
        } else {
          CustomSnackBar.error(
            errorList: loginModel.message ?? [MyStrings.loginFailedTryAgain.tr],
          );
        }
      } else {
        CustomSnackBar.error(errorList: [responseModel.message]);
      }
    } catch (e) {
      printX(e.toString());
    }
  }
}
