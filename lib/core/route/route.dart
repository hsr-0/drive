import 'package:get/get.dart';
import 'package:ovoride_driver/data/model/deposit/deposit_insert_response_model.dart';
import 'package:ovoride_driver/data/model/global/user/global_driver_model.dart';
import 'package:ovoride_driver/data/services/push_notification_service.dart';
import 'package:ovoride_driver/presentation/screens/Profile/profile_screen.dart';
import 'package:ovoride_driver/presentation/screens/account/change-password/change_password_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/email_verification_page/email_verification_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/forget_password/forget_password/forget_password.dart';
import 'package:ovoride_driver/presentation/screens/auth/forget_password/reset_password/reset_password_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/forget_password/verify_forget_password/verify_forget_password_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/login/login_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/profile_complete/profile_complete_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/registration/registration_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/sms_verification_page/sms_verification_screen.dart';
import 'package:ovoride_driver/presentation/screens/auth/two_factor_screen/two_factor_verification_screen.dart';
import 'package:ovoride_driver/presentation/screens/edit_profile/edit_profile_screen.dart';
import 'package:ovoride_driver/presentation/screens/faq/faq_screen.dart';
import 'package:ovoride_driver/presentation/screens/image_preview/preview_image_screen.dart';
import 'package:ovoride_driver/presentation/screens/language/language_screen.dart';
import 'package:ovoride_driver/presentation/screens/my_wallet/my_wallet_screen.dart';
import 'package:ovoride_driver/presentation/screens/onbaord/onboard_intro_screen.dart';
import 'package:ovoride_driver/presentation/screens/payment_history/payment_history_screen.dart';
import 'package:ovoride_driver/presentation/screens/privacy_policy/privacy_policy_screen.dart';
import 'package:ovoride_driver/presentation/screens/review/my_review_history_screen.dart';
import 'package:ovoride_driver/presentation/screens/review/user_review_history_screen.dart';
import 'package:ovoride_driver/presentation/screens/ride_details/ride_details_screen.dart';
import 'package:ovoride_driver/presentation/screens/ride_history/ride_activity_screen.dart';
import 'package:ovoride_driver/presentation/screens/splash/splash_screen.dart';
import 'package:ovoride_driver/presentation/screens/support_ticket/new_ticket_screen/add_new_ticket_screen.dart';
import 'package:ovoride_driver/presentation/screens/support_ticket/support_ticket_screen.dart';
import 'package:ovoride_driver/presentation/screens/support_ticket/ticket_details/ticket_details_screen.dart';
import 'package:ovoride_driver/presentation/screens/transaction/transactions_screen.dart';
import 'package:ovoride_driver/presentation/screens/vehicle_verification/vehicle_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/deposits/deposit_webview/my_webview_screen.dart';
import '../../presentation/screens/deposits/deposits_screen.dart';
import '../../presentation/screens/deposits/new_deposit/new_deposit_screen.dart';
import '../../presentation/screens/driver_profile_verification/driver_profile_verification_screen.dart';
import '../../presentation/screens/inbox/ride_message_screen.dart';
import '../../presentation/screens/maintenance/maintanance_screen.dart';
import '../../presentation/screens/profile_and_settings/profile_and_settings_screen.dart';
import '../../presentation/screens/two_factor_screen/two_factor_setup_screen.dart';
import '../../presentation/screens/withdraw/add_withdraw_screen/add_withdraw_method_screen.dart';
import '../../presentation/screens/withdraw/confirm_withdraw_screen/withdraw_confirm_screen.dart';
import '../../presentation/screens/withdraw/withdraw_history/withdraw_screen.dart';
import '../helper/shared_preference_helper.dart';

class RouteHelper {
  static const String splashScreen = "/splash_screen";

  static const String onboardScreen = "/onboard_screen";

  static const String loginScreen = "/login_screen";

  static const String phoneNumberLoginScreen = "/phone_number_login_screen";

  static const String forgotPasswordScreen = "/forgot_password_screen";

  static const String changePasswordScreen = "/change_password_screen";

  static const String registrationScreen = "/registration_screen";

  static const String myWalletScreen = "/my_wallet_screen";

  static const String allRideScreen = "/all_ride_screen";

  static const String addMoneyHistoryScreen = "/add_money_history_screen";

  static const String profileCompleteScreen = "/profile_complete_screen";

  static const String emailVerificationScreen = "/verify_email_screen";

  static const String smsVerificationScreen = "/verify_sms_screen";

  static const String verifyPassCodeScreen = "/verify_pass_code_screen";

  static const String twoFactorScreen = "/two-factor-screen";

  static const String twoFactorSetupScreen = "/two-factor-setup-screen";

  static const String resetPasswordScreen = "/reset_pass_screen";

  static const String transactionHistoryScreen = "/transaction_history_screen";

  static const String notificationScreen = "/notification_screen";

  static const String profileScreen = "/profile_screen";

  static const String profileAndSettingsScreen = "/profile_and_settings_screen";

  static const String editProfileScreen = "/edit_profile_screen";

  static const String privacyScreen = "/privacy-screen";

  static const String withdrawScreen = "/withdraw-screen";

  static const String newWithdrawScreen = "/new-withdraw-method";

  static const String withdrawConfirmScreenScreen = "/withdraw-preview-screen";

  static const String depositsScreen = "/deposits";

  static const String depositsDetailsScreen = "/deposits_details";

  static const String newDepositScreenScreen = "/deposits_money";

  static const String depositWebViewScreen = '/deposit_webView';

  static const String dashboard = "/dashboard_screen";

  static const String homeScreen = '/home_Screen';

  static const String rideActivityScreen = '/ride_activity_screen';

  static const String rideDetailsScreen = '/ride_details_Screen';

  static const String referralAFriendsScreen = '/referral_a_friends_screen';

  static const String rideMessageList = '/inbox_screen';

  static const String rideMessageScreen = '/inbox_message_screen';

  static const String languageScreen = '/language_screen';

  static const String vehicleVerificationScreen = '/vehicle_verification_screen';

  static const String driverProfileVerificationScreen = '/driver_verification_screen';

  static const String paymentHistoryScreen = '/payment_history_screen';

  static const String faqScreen = "/faq-screen";

  static const String maintenanceScreen = '/maintenance_screen';

  static const String myReviewScreen = '/driver_review_screen';

  static const String userReviewScreen = '/user_review_screen';

  //support ticket
  static const String supportTicketScreen = '/support_ticket_screen';
  static const String createSupportTicketScreen = '/create_support_ticket_screen';
  static const String supportTicketDetailsScreen = '/support_ticket_details_screen';
  static const String previewImageScreen = "/preview-image-screen";

  List<GetPage> routes = [
    GetPage(name: splashScreen, page: () => const SplashScreen()),
    GetPage(name: onboardScreen, page: () => const OnBoardIntroScreen()),
    GetPage(name: loginScreen, page: () => const LoginScreen()),
    GetPage(
      name: forgotPasswordScreen,
      page: () => const ForgetPasswordScreen(),
    ),
    GetPage(
      name: changePasswordScreen,
      page: () => const ChangePasswordScreen(),
    ),
    GetPage(name: registrationScreen, page: () => const RegistrationScreen()),
    GetPage(
      name: profileCompleteScreen,
      page: () => const ProfileCompleteScreen(),
    ),

    GetPage(
      name: dashboard,
      page: () => const DashBoardScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: rideActivityScreen,
      page: () => RideActivityScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: myWalletScreen,
      page: () => const MyWalletScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(name: withdrawScreen, page: () => const WithdrawScreen()),
    GetPage(name: newWithdrawScreen, page: () => const AddWithdrawMethod()),
    GetPage(
      name: withdrawConfirmScreenScreen,
      page: () => const WithdrawConfirmScreen(),
    ),
    GetPage(name: profileScreen, page: () => const ProfileScreen()),
    GetPage(name: editProfileScreen, page: () => const EditProfileScreen()),
    GetPage(
      name: profileAndSettingsScreen,
      page: () => const ProfileAndSettingsScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: rideMessageScreen,
      page: () => RideMessageScreen(rideID: '-1'),
    ),
    GetPage(
      name: rideDetailsScreen,
      page: () => RideDetailsScreen(rideId: Get.arguments),
    ),

    GetPage(name: myReviewScreen, page: () => MyReviewHistoryScreen()),
    GetPage(name: userReviewScreen, page: () => UserReviewHistory()),

    GetPage(name: languageScreen, page: () => const LanguageScreen()),
    GetPage(
      name: transactionHistoryScreen,
      page: () => const TransactionsScreen(),
    ),
    GetPage(
      name: emailVerificationScreen,
      page: () => EmailVerificationScreen(),
    ),
    GetPage(
      name: smsVerificationScreen,
      page: () => const SmsVerificationScreen(),
    ),
    GetPage(
      name: verifyPassCodeScreen,
      page: () => const VerifyForgetPassScreen(),
    ),
    GetPage(name: resetPasswordScreen, page: () => const ResetPasswordScreen()),
    GetPage(name: twoFactorScreen, page: () => TwoFactorVerificationScreen()),
    GetPage(
      name: twoFactorSetupScreen,
      page: () => const TwoFactorSetupScreen(),
    ),
    GetPage(name: privacyScreen, page: () => const PrivacyPolicyScreen()),
    GetPage(
      name: vehicleVerificationScreen,
      page: () => const VehicleVerificationScreen(),
    ),
    GetPage(
      name: driverProfileVerificationScreen,
      page: () => const DriverProfileVerificationScreen(),
    ),

    GetPage(
      name: depositWebViewScreen,
      page: () => MyWebViewScreen(
        depositInsertData: Get.arguments as DepositInsertData,
      ),
    ),
    GetPage(name: depositsScreen, page: () => const DepositsScreen()),
    GetPage(name: newDepositScreenScreen, page: () => const NewDepositScreen()),
    GetPage(
      name: paymentHistoryScreen,
      page: () => const PaymentHistoryScreen(),
    ),

    //support ticket
    //support
    GetPage(
      name: createSupportTicketScreen,
      page: () => const AddNewTicketScreen(),
    ),

    GetPage(name: supportTicketScreen, page: () => const SupportTicketScreen()),

    GetPage(
      name: supportTicketDetailsScreen,
      page: () => const TicketDetailsScreen(),
    ),

    GetPage(
      name: previewImageScreen,
      page: () => PreviewImageScreen(url: Get.arguments),
    ),
    GetPage(name: faqScreen, page: () => const FaqScreen()),
    GetPage(name: maintenanceScreen, page: () => MaintenanceScreen()),
  ];

  static Future<void> checkUserStatusAndGoToNextStep(
    GlobalDriverInfoModel? user, {
    bool isRemember = false,
    String accessToken = "",
    String tokenType = "",
  }) async {
    bool needEmailVerification = user?.ev == "1" ? false : true;
    bool needSmsVerification = user?.sv == '1' ? false : true;
    bool isTwoFactorEnable = user?.tv == '1' ? false : true;

    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

    if (isRemember) {
      await sharedPreferences.setBool(
        SharedPreferenceHelper.rememberMeKey,
        true,
      );
    } else {
      await sharedPreferences.setBool(
        SharedPreferenceHelper.rememberMeKey,
        false,
      );
    }

    await sharedPreferences.setString(
      SharedPreferenceHelper.userIdKey,
      user?.id.toString() ?? '-1',
    );
    await sharedPreferences.setString(
      SharedPreferenceHelper.userEmailKey,
      user?.email ?? '',
    );
    await sharedPreferences.setString(
      SharedPreferenceHelper.userPhoneNumberKey,
      user?.mobile ?? '',
    );
    await sharedPreferences.setString(
      SharedPreferenceHelper.userNameKey,
      user?.username ?? '',
    );

    if (accessToken.isNotEmpty) {
      await sharedPreferences.setString(
        SharedPreferenceHelper.accessTokenKey,
        accessToken,
      );
      await sharedPreferences.setString(
        SharedPreferenceHelper.accessTokenType,
        tokenType,
      );
    }

    bool isProfileCompleteEnable = user?.profileComplete == '0' ? true : false;

    if (isProfileCompleteEnable) {
      Get.offAndToNamed(RouteHelper.profileCompleteScreen);
    } else if (needEmailVerification) {
      Get.offAndToNamed(RouteHelper.emailVerificationScreen);
    } else if (needSmsVerification) {
      Get.offAndToNamed(RouteHelper.smsVerificationScreen);
    } else if (isTwoFactorEnable) {
      Get.offAndToNamed(RouteHelper.twoFactorScreen);
    } else {
      PushNotificationService(apiClient: Get.find()).sendUserToken();
      Get.offAndToNamed(RouteHelper.dashboard);
    }
  }
}
