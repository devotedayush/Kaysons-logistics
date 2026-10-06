import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A device preference. Freight data and the signed-in session are unaffected.
class AppLanguage extends ChangeNotifier {
  AppLanguage._();

  static final AppLanguage instance = AppLanguage._();
  static const _preferenceKey = 'app_language';
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _preferenceKey,
    );
    _locale = saved == 'hi' || saved == 'en' ? Locale(saved!) : null;
    notifyListeners();
  }

  Future<void> select(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'hi') {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    if (_locale?.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      _preferenceKey,
      languageCode,
    );
  }
}
