class UrlContainer {
  static const String domainUrl = 'https://taxi.beytei.com'; //YOUR WEBSITE DOMAIN URL HERE

  static const String baseUrl = '$domainUrl/api/';
  static const String dashBoardEndPoint = 'driver/dashboard';
  static const String depositHistoryUrl = 'driver/deposit/history';
  static const String depositMethodUrl = 'driver/deposit/methods';
  static const String depositInsertUrl = 'driver/deposit/insert';

  static const String registrationEndPoint = 'driver/register';
  static const String loginEndPoint = 'driver/login';
  static const String socialLoginEndPoint = 'driver/social-login';

  static const String socialLogin = 'driver/social-login';
  static const String logoutUrl = 'driver/logout';
  static const String forgetPasswordEndPoint = 'driver/password/email';
  static const String passwordVerifyEndPoint = 'driver/password/verify-code';
  static const String resetPasswordEndPoint = 'driver/password/reset';
  static const String verify2FAUrl = 'driver/verify-g2fa';

  static const String otpVerify = 'driver/otp-verify';
  static const String otpResend = 'driver/otp-resend';

  static const String verifyEmailEndPoint = 'driver/verify-email';
  static const String verifySmsEndPoint = 'driver/verify-mobile';
  static const String resendVerifyCodeEndPoint = 'driver/resend-verify/';
  static const String authorizationCodeEndPoint = 'driver/authorization';

  static const String transactionEndpoint = 'driver/transactions';

  static const String addWithdrawRequestUrl = 'driver/withdraw-request';
  static const String withdrawMethodUrl = 'driver/withdraw-method';
  static const String withdrawRequestConfirm = 'driver/withdraw-request/confirm';
  static const String withdrawHistoryUrl = 'driver/withdraw/history';
  static const String withdrawStoreUrl = 'driver/withdraw/store/';
  static const String withdrawConfirmScreenUrl = 'driver/withdraw/preview/';

  static const String driverVerificationFormUrl = 'driver/driver-verification';
  static const String vehicleVerificationFormUrl = 'driver/vehicle-verification';
  static const String kycSubmitUrl = 'driver/kyc-submit';

  static const String generalSettingEndPoint = 'general-setting';
  static const String privacyPolicyEndPoint = 'policies';

  static const String getProfileEndPoint = 'driver/driver-info';
  static const String updateProfileEndPoint = 'driver/profile-setting';
  static const String profileCompleteEndPoint = 'driver/driver-data-submit';

  static const String changePasswordEndPoint = 'driver/change-password';
  static const String countryEndPoint = 'get-countries';
  static const String deviceTokenEndPoint = 'driver/save-device-token';
  static const String languageUrl = 'language/';
  static const String onlineStatus = 'driver/online-status';
  static const String createBid = 'driver/bid/create';
  static const String zones = 'zones';

  //  ride

  static const String rideList = 'driver/rides/list';
  static const String acceptedRides = 'driver/rides/accepted';
  static const String activeRides = 'driver/rides/active';
  static const String startRides = 'driver/rides/start';
  static const String endRides = 'driver/rides/end';
  static const String reviewRide = 'driver/review';
  static const String driverLocationUpdate = 'driver/location-update';
  static const String cancelBid = 'driver/rides/cancel';
  static const String rideDetails = 'driver/rides/details';
  static const String acceptCashPaymentRides = 'driver/rides/received-cash-payment';

  static const String completedRides = 'driver/rides/completed';
  static const String canceledRides = 'driver/rides/canceled';
  static const String rideMassageList = 'driver/ride/messages';
  static const String sendMessage = 'driver/ride/send/message';
  static const String userDeleteEndPoint = 'driver/delete-account';
  static const String referenceEndPoint = 'driver/reference';
  static const String reviewHistoryEndPoint = 'driver/review';
  static const String reviewByUserHistoryEndPoint = 'driver/get-rider-review';
  static const String faqEndPoint = 'faq';

  static const String rideMessageList = 'driver/ride/messages';

  static const String pusherAuthenticate = 'driver/pusher/auth/';
  static const String paymentHistory = 'driver/payment/history';

  //support ticket
  static const String supportMethodsEndPoint = 'driver/support/method';
  static const String supportListEndPoint = 'driver/ticket';
  static const String storeSupportEndPoint = 'driver/ticket/create';
  static const String supportViewEndPoint = 'driver/ticket/view';
  static const String supportReplyEndPoint = 'driver/ticket/reply';
  static const String supportCloseEndPoint = 'driver/ticket/close';
  static const String supportDownloadEndPoint = 'driver/ticket/download';
  static const String supportImagePath = '$domainUrl/assets/support/';

  static const String twoFactor = "driver/twofactor";
  static const String twoFactorEnable = "driver/twofactor/enable";
  static const String twoFactorDisable = "driver/twofactor/disable";
  static const String rideReceipt = "${baseUrl}driver/rides/receipt";

  // others url
  static const String countryFlagImageLink = 'https://flagpedia.net/data/flags/h60/{countryCode}.webp';
  static const String googleMapLocationSearch = 'https://maps.googleapis.com/maps/api/geocode/json';
}
