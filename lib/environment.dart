class Environment {
  // ATTENTION Please update your desired data.
  static const String appName = 'OvoRide Driver';
  static const String version = '1.0.2';

  // Ride and Bids
  static const int bidAcceptSecond = 30; //Bid ACCEPT second
  static const int driverLocationUpdateAfterNmetersOrMovements = 50; //Driver location update after n meters or movements

  //Language
  // Default display name for the app's language (used in UI language selectors)
  static String defaultLanguageName = "English";

  // Default language code (ISO 639-1) used by the app at startup
  static String defaultLanguageCode = "en";

  // Default country code (ISO 3166-1 alpha-2) used for locale-specific formatting
  static const String defaultCountryCode = 'د.ع';



  static const String mapKey = 'pk.eyJ1IjoicmUtYmV5dGVpMzIxIiwiYSI6ImNtaTljbzM4eDBheHAyeHM0Y2Z0NmhzMWMifQ.ugV8uRN8pe9MmqPDcD5XcQ'; // ✅ تأكد من وضع المفتاح هنا
  static const double mapDefaultZoom = 20.0;





  //MAP CONFIG
  static const bool addressPickerFromGoogleMapApi = true; //If true, use Google Map API for formate address picker from lat , long, else use free service reverse geocode

  static const String devToken = "\$2y\$12\$mEVBW3QASB5HMBv8igls3ejh6zw2A0Xb480HWAmYq6BY9xEifyBjG"; //Do not change this token
}
