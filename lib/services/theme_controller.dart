import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light; // default: white

  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString('theme');
      mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.light);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString('theme', m.name);
    } catch (_) {}
  }
}
