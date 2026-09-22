import 'package:flutter/material.dart';

class AppColors {
  // Kita jadikan variabel dinamis (tidak const) agar bisa diubah melalui Settings
  static Color primary = const Color(0xFFE64A19); 
  static const Color secondary = Color(0xFFFFA000);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
  static const Color success = Color(0xFF4CAF50);
  static const Color danger = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA000);

  // Fungsi tambahan untuk mengambil warna tema (Opsional)
  static Color getThemePrimary(BuildContext context) => Theme.of(context).primaryColor;
}
