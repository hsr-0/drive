import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ovoride_driver/environment.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ovoride_driver/core/helper/shared_preference_helper.dart';
import 'package:ovoride_driver/data/model/language/language_model.dart';

class LocalizationController extends GetxController {
  final SharedPreferences sharedPreferences;

  LocalizationController({required this.sharedPreferences}) {
    loadCurrentLanguage();
  }

  var defaultLanguage = MyLanguageModel(
    languageName: Environment.defaultLanguageName,
    languageCode: Environment.defaultLanguageCode,
    countryCode: Environment.defaultCountryCode,
  ); // Default language

  Locale? _locale;
  bool _isLtr = true;
  final List<MyLanguageModel> _languages = [];

  Locale get locale => _locale ?? Locale(defaultLanguage.languageCode, defaultLanguage.countryCode);
  bool get isLtr => _isLtr;
  List<MyLanguageModel> get languages => _languages;

  void setLanguage(Locale locale, String imageUrl) {
    Get.updateLocale(locale);
    _locale = locale;
    if (_locale?.languageCode == 'ar') {
      _isLtr = false;
    } else {
      _isLtr = true;
    }
    if (_locale != null) {
      saveLanguage(_locale!, imageUrl);
    }
    update();
  }

  void loadCurrentLanguage() async {
    _locale = Locale(
      sharedPreferences.getString(SharedPreferenceHelper.languageCode) ?? defaultLanguage.languageCode,
      sharedPreferences.getString(SharedPreferenceHelper.countryCode) ?? defaultLanguage.countryCode,
    );
    _isLtr = _locale?.languageCode != 'ar';
    update();
  }

  void saveLanguage(Locale locale, String? imageUrl) async {
    sharedPreferences.setString(
      SharedPreferenceHelper.languageCode,
      locale.languageCode,
    );
    sharedPreferences.setString(
      SharedPreferenceHelper.countryCode,
      locale.countryCode ?? '',
    );
    sharedPreferences.setString(
      SharedPreferenceHelper.languageImagePath,
      imageUrl ?? '',
    );
  }

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setSelectIndex(int index) {
    _selectedIndex = index;
    update();
  }
}
