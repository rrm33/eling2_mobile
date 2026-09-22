import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

class ThemeProvider with ChangeNotifier {
  Color _primaryColor = const Color(0xFFE64A19); // Warna default (Deep Orange)

  Color get primaryColor => _primaryColor;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('primary_color');
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
      AppColors.primary = _primaryColor;
      notifyListeners();
    }
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    AppColors.primary = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_color', color.value);
    notifyListeners();
  }
}
