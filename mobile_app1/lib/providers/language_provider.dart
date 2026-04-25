import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  String _currentLang = "en";

  String get currentLang => _currentLang;

  void changeLanguage(String lang) {
    _currentLang = lang;
    notifyListeners(); // 🔥 updates UI everywhere
  }
}
