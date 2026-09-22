import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../core/api_config.dart';

class UserService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Ambil Daftar User
  Future<List<dynamic>> getUsers() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/users'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Server mengembalikan error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in getUsers: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Waktu tunggu habis. Server tidak merespon.');
      }
      rethrow;
    }
  }

  // Simpan User Baru
  Future<bool> createUser(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.apiUrl}/users'),
      headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 201;
  }

  // Update User
  Future<bool> updateUser(int id, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('${ApiConfig.apiUrl}/users/$id'),
      headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 200;
  }

  // Hapus User
  Future<bool> deleteUser(int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${ApiConfig.apiUrl}/users/$id'),
      headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  // Ambil Daftar Toko (Untuk pilihan cabang saat tambah user)
  Future<List<dynamic>> getShops() async {
    final token = await _getToken();
    // Kita asumsikan ada endpoint /shops atau kita gunakan data dari toko yang ada
    // Untuk saat ini kita coba panggil dari API atau kembalikan array sementara jika belum ada endpointnya
    final response = await http.get(
      Uri.parse('${ApiConfig.apiUrl}/shops'), // Pastikan nanti kita buat endpoint ini jika belum ada
      headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}
