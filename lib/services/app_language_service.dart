import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageService {
  static final ValueNotifier<String> language = ValueNotifier<String>('lv');

  static Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    language.value = prefs.getString('app_language') ?? 'lv';
  }

  static Future<void> setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', value);
    language.value = value;
  }

  static bool get isLv => language.value == 'lv';
  static bool get isEn => language.value == 'en';
  static String tr({
    required String lv,
    required String en,
  }) {
    return isLv ? lv : en;
  }
}