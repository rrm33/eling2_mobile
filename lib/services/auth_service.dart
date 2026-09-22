import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';
import 'database_helper.dart';

class AuthService {

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/login'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data['access_token'], data['user']);
        return true;
      } else {
        throw Exception('Email atau password salah.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    // Normalisasi tipe data agar shop_id dan id SELALU berupa int
    final normalizedUser = Map<String, dynamic>.from(user);
    if (normalizedUser['shop_id'] != null) {
      normalizedUser['shop_id'] = int.tryParse(normalizedUser['shop_id'].toString());
    }
    if (normalizedUser['id'] != null) {
      normalizedUser['id'] = int.tryParse(normalizedUser['id'].toString());
    }
    // Normalisasi URL Foto jika relatif
    if (normalizedUser['photo'] != null && !normalizedUser['photo'].toString().startsWith('http')) {
      String photo = normalizedUser['photo'].toString();
      if (!photo.startsWith('/storage/') && !photo.startsWith('storage/')) {
        photo = '/storage/' + (photo.startsWith('/') ? photo.substring(1) : photo);
      } else if (photo.startsWith('storage/')) {
        photo = '/' + photo;
      }
      normalizedUser['photo'] = '${ApiConfig.baseUrl}$photo';
    }
    await prefs.setString('auth_token', token);
    await prefs.setString('user_data', jsonEncode(normalizedUser));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userData = prefs.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  /**
   * TARIK PROFIL TERBARU DARI SERVER
   * Digunakan untuk update stok secara real-time
   */
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/me'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['data'];
        await _saveSession(token, user); // Update Cache Lokal
        return user;
      }
    } catch (e) {
      print('Gagal fetch profile: $e');
    }
    return await getUserData(); // Fallback ke data lokal jika gagal
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<dynamic>> getAttendanceHistory({String? date}) async {
    List<dynamic> serverData = [];
    List<dynamic> localUnsynced = [];
    final db = await DatabaseHelper.instance.database;

    // 1. Ambil data lokal yang belum sinkron (selalu tampilkan ini)
    try {
      String whereClause = "is_synced = 0";
      List<dynamic> whereArgs = [];
      if (date != null) {
        whereClause += " AND date_time LIKE ?";
        whereArgs.add('$date%');
      }
      final List<Map<String, dynamic>> localLogs = await db.query(
        'attendances', 
        where: whereClause, 
        whereArgs: whereArgs,
        orderBy: 'date_time DESC'
      );
      localUnsynced = localLogs.map((log) {
        bool isIn = log['type'] == 'in';
        return {
          'id': log['id'],
          'name': 'Menunggu Sinkron...',
          'shop': {'name': 'Lokal (HP)'},
          'in_time': isIn ? DateTime.parse(log['date_time']).toLocal().toString().substring(11, 16) : null,
          'in_photo': isIn ? log['photo_path'] : null,
          'out_time': !isIn ? DateTime.parse(log['date_time']).toLocal().toString().substring(11, 16) : null,
          'out_photo': !isIn ? log['photo_path'] : null,
          'is_offline': true,
          'is_synced': false,
          'date_time': log['date_time'],
        };
      }).toList();
    } catch (e) {
      print('Gagal ambil data lokal: $e');
    }

    // 2. Ambil data dari Server
    try {
      final token = await getToken();
      final url = date != null 
          ? '${ApiConfig.apiUrl}/attendance/history?date=$date'
          : '${ApiConfig.apiUrl}/attendance/history';
          
      final response = await http.get(
        Uri.parse(url),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        serverData = data['data'] as List<dynamic>;
      }
    } catch (e) {
      print("Offline/Server Error: $e");
    }

    // Jika online, gabungkan Lokal Unsynced di paling atas
    if (serverData.isNotEmpty) {
      return [...localUnsynced, ...serverData];
    }

    // Jika offline total (serverData kosong), ambil semua dari lokal (termasuk yang sudah sinkron sebagai cache)
    if (localUnsynced.isEmpty && serverData.isEmpty) {
      final List<Map<String, dynamic>> allLocal = await db.query(
        'attendances', 
        where: date != null ? "date_time LIKE ?" : null,
        whereArgs: date != null ? ['$date%'] : null,
        orderBy: 'date_time DESC'
      );
      return allLocal.map((log) {
        bool isIn = log['type'] == 'in';
        return {
          'id': log['id'],
          'name': log['is_synced'] == 1 ? 'Data Cache' : 'Lokal',
          'shop': {'name': log['is_synced'] == 1 ? 'Sinkron' : 'Lokal (HP)'},
          'in_time': isIn ? DateTime.parse(log['date_time']).toLocal().toString().substring(11, 16) : null,
          'in_photo': isIn ? log['photo_path'] : null,
          'out_time': !isIn ? DateTime.parse(log['date_time']).toLocal().toString().substring(11, 16) : null,
          'out_photo': !isIn ? log['photo_path'] : null,
          'is_offline': true,
          'is_synced': log['is_synced'] == 1,
        };
      }).toList();
    }

    return localUnsynced;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
