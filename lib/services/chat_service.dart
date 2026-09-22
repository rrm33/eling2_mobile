import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class ChatService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<dynamic>> getConversations() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/chat/conversations'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error getConversations: $e');
    }
    return [];
  }

  Future<List<dynamic>> getMessages({int? shopId}) async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      String url = '${ApiConfig.apiUrl}/chat/messages';
      if (shopId != null) {
        url += '/$shopId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error getMessages: $e');
    }
    return [];
  }

  Future<bool> sendMessage(String message, {int? shopId}) async {
    final token = await _getToken();
    if (token == null) return false;

    try {
      final Map<String, dynamic> body = {'message': message};
      if (shopId != null) {
        body['shop_id'] = shopId; // Kirim sebagai int, bukan String
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/chat/messages'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('CHAT SEND: status=${response.statusCode} body=${response.body}');
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sendMessage: $e');
      return false;
    }
  }

  Future<void> markAsRead({int? shopId}) async {
    final token = await _getToken();
    if (token == null) return;

    try {
      String url = '${ApiConfig.apiUrl}/chat/read';
      if (shopId != null) {
        url += '/$shopId';
      }

      await http.post(
        Uri.parse(url),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Error markAsRead: $e');
    }
  }

  Future<int> getUnreadCount() async {
    final token = await _getToken();
    if (token == null) return 0;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/chat/unread-count'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error getUnreadCount: $e');
    }
    return 0;
  }
}
