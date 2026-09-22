import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isCheckingAuth = true;

  AuthProvider() {
    checkAuth();
  }

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isAuthenticated => _user != null;

  Future<void> checkAuth() async {
    _isCheckingAuth = true;
    notifyListeners();
    
    try {
      _user = await _authService.fetchUserProfile();
    } catch (e) {
      debugPrint("Error checking auth: $e");
      _user = await _authService.getUserData(); // Fallback ke lokal jika server down
    } finally {
      _isCheckingAuth = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.login(email, password);
      _user = await _authService.getUserData();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> getToken() async {
    return await _authService.getToken();
  }

  void logout() {
    _authService.logout();
    _user = null;
    notifyListeners();
  }

  /**
   * REFRESH STOK TOKO SECARA REALTIME
   */
  Future<void> refreshShopStock() async {
    if (_user == null) return;
    
    try {
      final freshData = await _authService.fetchUserProfile();
      if (freshData != null && freshData['shop'] != null) {
        _user!['shop'] = freshData['shop'];
        notifyListeners(); // Paksa layar untuk mengganti angka 200 jadi 179
      }
    } catch (e) {
      debugPrint("Gagal refresh stok: $e");
    }
  }

  // Fungsi baru untuk memotong stok secara reaktif di HP
  void reduceStock(int amount) {
    if (_user != null && _user!['shop'] != null) {
      int currentStock = int.tryParse(_user!['shop']['stock']?.toString() ?? '0') ?? 0;
      _user!['shop']['stock'] = currentStock - amount;
      notifyListeners(); // Kabari semua layar untuk update tampilan!
    }
  }
}
