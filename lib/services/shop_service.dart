import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/api_config.dart';
import 'database_helper.dart';

class ShopService {
  final dbHelper = DatabaseHelper.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<dynamic>> getShops() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/shops'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> serverShops = jsonDecode(response.body);
        
        // Cache to SQLite
        for (var shop in serverShops) {
          await db.insert(
            'shops',
            {
              'id': shop['id'],
              'name': shop['name'],
              'is_main': (shop['is_main'] == true || shop['is_main'] == 1) ? 1 : 0,
              'address': shop['address'],
              'phone': shop['phone'],
              'slogan': shop['slogan'],
              'tiktok': shop['tiktok'],
              'instagram': shop['instagram'],
              'facebook': shop['facebook'],
              'web': shop['web'],
              'latitude': shop['latitude'],
              'longitude': shop['longitude'],
              'logo_url': shop['logo_url'],
              'stock': int.tryParse(shop['stock']?.toString() ?? '0') ?? 0,
              'min_stock': int.tryParse(shop['min_stock']?.toString() ?? '100') ?? 100,
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return serverShops;
      }
    } catch (e) {
      print("Offline mode: Fetching shops from local DB");
    }

    // Fallback to local
    final List<Map<String, dynamic>> localShops = await db.query('shops');
    return localShops.map((s) => {
      ...s,
      'is_main': s['is_main'] == 1,
    }).toList();
  }

  Future<bool> createShop(Map<String, dynamic> data, {File? logo}) async {
    final token = await _getToken();
    var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.apiUrl}/shops'));
    
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    // Tambahkan data teks
    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Tambahkan file logo jika ada
    if (logo != null) {
      request.files.add(await http.MultipartFile.fromPath('logo', logo.path));
    }

    try {
      final response = await request.send().timeout(const Duration(seconds: 30));
      return response.statusCode == 201;
    } catch (e) {
      return false; // Create shop might need server ID first, so we don't fully support offline CREATE here without more logic
    }
  }

  Future<bool> updateShop(int id, Map<String, dynamic> data, {File? logo}) async {
    final db = await dbHelper.database;
    final token = await _getToken();
    
    // 1. Simpan ke Lokal Terlebih Dahulu (Offline Support)
    await db.update(
      'shops',
      {
        'name': data['name'],
        'is_main': data['is_main'] == '1' ? 1 : 0,
        'address': data['address'],
        'phone': data['phone'],
        'slogan': data['slogan'],
        'tiktok': data['tiktok'],
        'instagram': data['instagram'],
        'facebook': data['facebook'],
        'web': data['web'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'stock': int.tryParse(data['stock']?.toString() ?? '0') ?? 0,
        'min_stock': int.tryParse(data['min_stock']?.toString() ?? '100') ?? 100,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // 2. Coba kirim ke server
    try {
      // Gunakan POST dengan _method PUT agar support upload file di Laravel
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.apiUrl}/shops/$id'));
      
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['_method'] = 'PUT';

      // Tambahkan data teks
      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Tambahkan file logo jika ada
      if (logo != null) {
        request.files.add(await http.MultipartFile.fromPath('logo', logo.path));
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        await db.update('shops', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
        return true;
      }
    } catch (e) {
      print("Offline mode: Saved update locally.");
    }
    
    return true; // Anggap sukses (tersimpan lokal)
  }

  Future<bool> deleteShop(int id) async {
    final db = await dbHelper.database;
    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiUrl}/shops/$id'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Jika sukses di server, hapus juga dari lokal agar langsung hilang dari layar
        try {
          await db.delete('shops', where: 'id = ?', whereArgs: [id]);
        } catch (_) {}
        return true;
      } else {
        // Server menolak -> simpan status deleted lokal untuk sinkronisasi nanti
        try {
          await db.update('shops', {'status': 'deleted', 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
        } catch (_) {}
        return true; // dianggap sukses lokal (queued)
      }
    } catch (e) {
      // Offline / error: jadikan deleted lokal supaya saat online akan dicoba hapus di server
      try {
        await db.update('shops', {'status': 'deleted', 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
      return true; // dianggap berhasil lokal
    }
  }
}
