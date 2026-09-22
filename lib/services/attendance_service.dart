import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';
import 'database_helper.dart';

class AttendanceService {
  final dbHelper = DatabaseHelper.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Simpan Absen ke Lokal + Server secara bersamaan jika online
  Future<Map<String, dynamic>> submitAttendance({
    required String type,
    required double latitude,
    required double longitude,
    required String photoPath,
    bool forceUpdate = false,
  }) async {
    final db = await dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
    final shopId = userData['shop_id'];
    final userId = userData['id'];
    
    // 1. CEK APAKAH SUDAH ADA DATA LOKAL UNTUK HARI INI & TIPE INI
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final List<Map<String, dynamic>> existing = await db.query(
      'attendances',
      where: 'user_id = ? AND type = ? AND date_time LIKE ?',
      whereArgs: [userId, type, '$today%'],
    );

    int localId;
    final localTime = DateTime.now().toIso8601String();
    
    if (existing.isNotEmpty) {
      // Jika sudah ada, update data yang sudah ada di lokal
      localId = existing.first['id'];
      await db.update(
        'attendances',
        {
          'latitude': latitude,
          'longitude': longitude,
          'image_path': photoPath,
          'date_time': localTime,
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
    } else {
      // Jika belum ada, baru insert data baru
      localId = await db.insert('attendances', {
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'image_path': photoPath,
        'date_time': localTime,
        'shop_id': shopId,
        'user_id': userId,
        'is_synced': 0,
      });
    }

    // 2. LANGSUNG KIRIM KE SERVER (Jika Online)
    try {
      final token = await _getToken();
      
      // Menggunakan MultipartRequest agar lebih stabil saat mengirim foto besar
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${ApiConfig.apiUrl}/attendance')
      );
      
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Tambahkan data teks
      request.fields['type'] = type;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['shop_id'] = shopId.toString();
      request.fields['created_at'] = localTime;
      request.fields['note'] = type == 'in' ? 'Masuk' : 'Pulang';
      request.fields['force_update'] = forceUpdate.toString();

      // Tambahkan File Foto secara langsung (Tanpa Base64)
      request.files.add(await http.MultipartFile.fromPath('photo', photoPath));

      // Kirim dan tunggu respon
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Cek jika server mengirimkan status 'exists' (sudah absen)
        if (responseData['status'] == 'exists') {
          return {
            'success': false, 
            'status': 'exists', 
            'message': responseData['message']
          };
        }

        // Pastikan ada data dan id sebelum update lokal
        if (responseData['data'] != null && responseData['data']['id'] != null) {
          final serverId = responseData['data']['id'];
          
          // Hapus record lama yang punya server_id yang sama (agar tidak bentrok UNIQUE constraint)
          await db.delete(
            'attendances',
            where: 'server_id = ? AND id != ?',
            whereArgs: [serverId, localId],
          );

          await db.update(
            'attendances',
            {'is_synced': 1, 'server_id': serverId},
            where: 'id = ?',
            whereArgs: [localId],
          );
        }
        
        return {'success': true, 'message': responseData['message'] ?? 'Absen Berhasil & Tersinkron'};
      } else {
        // SERVER MENOLAK
        try {
          final responseData = jsonDecode(response.body);
          return {'success': false, 'message': responseData['message'] ?? 'Ditolak Server (${response.statusCode})'};
        } catch (_) {
          return {'success': false, 'message': 'Server Error (${response.statusCode}): ${response.body.length > 50 ? response.body.substring(0, 50) : response.body}'};
        }
      }
    } on SocketException catch (_) {
      return {'success': true, 'message': 'Offline: Absen hanya disimpan di HP.'};
    } on TimeoutException catch (_) {
      return {'success': true, 'message': 'Koneksi Lemah: Tersimpan di HP.'};
    } catch (e) {
      print('DEBUG Attendance Error: $e');
      return {'success': false, 'message': 'Kesalahan Lokal: $e'};
    }
  }

  // Ambil history absensi (bisa dari lokal/server)
  Future<List<dynamic>> getAttendanceHistory() async {
    final db = await dbHelper.database;
    return await db.query('attendances', orderBy: 'id DESC');
  }

  // Hapus Absensi (Khusus Admin)
  Future<Map<String, dynamic>> deleteAttendance(int id) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiUrl}/attendance/$id'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      final responseData = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ?? 'Gagal menghapus data'
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
