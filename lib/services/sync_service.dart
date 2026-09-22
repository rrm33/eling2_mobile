import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sql;
import '../core/api_config.dart';
import 'database_helper.dart';

class SyncService {
  final dbHelper = DatabaseHelper.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, int>> getPendingDetails() async {
    final db = await dbHelper.database;
    Map<String, int> details = {};
    
    final t = await db.rawQuery('SELECT COUNT(*) as total FROM transactions WHERE is_synced != 1');
    details['Transaksi'] = (t.first['total'] as int? ?? 0);
    
    final f = await db.rawQuery('SELECT COUNT(*) as total FROM finances WHERE is_synced != 1');
    details['Keuangan'] = (f.first['total'] as int? ?? 0);
    
    final a = await db.rawQuery('SELECT COUNT(*) as total FROM attendances WHERE is_synced != 1');
    details['Absensi'] = (a.first['total'] as int? ?? 0);
    
    final s = await db.rawQuery('SELECT COUNT(*) as total FROM shifts WHERE is_synced != 1');
    details['Shift'] = (s.first['total'] as int? ?? 0);

    final p = await db.rawQuery('SELECT COUNT(*) as total FROM products WHERE is_synced != 1');
    details['Produk'] = (p.first['total'] as int? ?? 0);
    
    final c = await db.rawQuery('SELECT COUNT(*) as total FROM categories WHERE is_synced != 1');
    details['Kategori'] = (c.first['total'] as int? ?? 0);

    final sh = await db.rawQuery('SELECT COUNT(*) as total FROM shops WHERE is_synced != 1');
    details['Toko'] = (sh.first['total'] as int? ?? 0);
    
    return details;
  }

  Future<int> getPendingCount() async {
    final details = await getPendingDetails();
    return details.values.reduce((a, b) => a + b);
  }

  Future<void> syncAll() async {
    // 1. PUSH (Kirim) - Jalankan beberapa secara paralel untuk efisiensi
    // Kita pisahkan yang ada dependensi: Produk butuh Kategori & Toko
    try {
      await Future.wait([
        syncShops(),
        syncCategories(),
      ]);
      
      // Setelah Toko & Kategori aman, baru Produk & Transaksi dll
      await Future.wait([
        syncProducts(), 
        syncPendingTransactions(),
        syncFinances(),            
        syncAttendances(),         
        syncShifts(),              
        syncStatusUpdates(), 
      ]);

      // 1b. CLEANUP: Tandai data yang sudah punya server_id sebagai sinkron (mencegah data hantu)
      final db = await dbHelper.database;
      await db.execute("UPDATE transactions SET is_synced = 1 WHERE server_id IS NOT NULL AND status = 'active' AND is_synced = 0");
      await db.execute("UPDATE finances SET is_synced = 1 WHERE server_id IS NOT NULL AND status = 'active' AND is_synced = 0");
      await db.execute("UPDATE attendances SET is_synced = 1 WHERE server_id IS NOT NULL AND is_synced = 0");
      await db.execute("UPDATE shifts SET is_synced = 1 WHERE server_id IS NOT NULL AND is_synced = 0");
      
    } catch (e) {
      print("Error during Push Sync: $e");
    }
    
    // 2. PULL (Tarik) - Tetap paralel, tapi dengan timeout yang masuk akal
    try {
      await Future.wait([
        pullShops(),
        pullCategories(),
        pullProducts(),
        pullFinances(),
        pullAttendances(),
        pullTransactions(),
        pullShifts(),
        pullProductComponents(),
      ]).timeout(const Duration(seconds: 30));
    } catch (e) {
      print("Error during Pull Sync: $e");
    }
  }

  Future<void> forceMarkAllAsSynced() async {
    final db = await dbHelper.database;
    final tables = ['transactions', 'finances', 'attendances', 'shifts', 'products', 'categories', 'shops'];
    for (var table in tables) {
      try {
        await db.execute("UPDATE $table SET is_synced = 1 WHERE is_synced != 1");
      } catch (_) {}
    }
  }

  Future<void> pullShifts() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/cashier/reports'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> serverReports = jsonDecode(response.body);
        final db = await dbHelper.database;
        for (var report in serverReports) {
          await db.insert('shifts', {
            'server_id': report['id'],
            'starting_cash': report['starting_cash'],
            'closing_cash': report['closing_cash'],
            'actual_cash': report['actual_cash'],
            'difference': report['difference'],
            'opened_at': report['opened_at'],
            'closed_at': report['closed_at'],
            'note': report['note'],
            'status': 'closed',
            'user_name': report['user']?['name'],
            'shop_name': report['shop']?['name'],
            'is_synced': 1,
          }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
        }
      }
    } catch (_) {}
  }

  // --- -3. TOKO (SHOPS PULL) ---

  Future<void> pullShops() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/shops'), 
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'}
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> dataList = jsonDecode(response.body);
        final db = await dbHelper.database;
        for (var shop in dataList) {
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
            conflictAlgorithm: sql.ConflictAlgorithm.replace,
          );
        }
      }
    } catch (_) {}
  }

  // --- -2. PRODUK & KATEGORI (PRODUCTS & CATEGORIES) ---

  Future<void> pullCategories() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/categories'), 
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'}
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> dataList = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
        final shopId = int.tryParse(userData['shop_id']?.toString() ?? '');

        final db = await dbHelper.database;
        final batch = db.batch();
        for (var item in dataList) {
          batch.insert('categories', {
            'id': item['id'],
            'shop_id': item['shop_id'], // Gunakan shop_id asli dari server
            'name': item['name'],
            'status': (item['status'] == true || item['status'] == 1 || item['status'] == '1') ? 'active' : 'inactive',
            'is_synced': 1,
          }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    } catch (_) {}
  }

  Future<void> pullProducts() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/products'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> dataList = jsonDecode(response.body);
        final db = await dbHelper.database;

        // Ambil ID produk lokal yang belum sinkron agar tidak tertimpa
        final List<Map<String, dynamic>> unsyncedLocal = await db.query(
          'products',
          columns: ['id'],
          where: 'is_synced = 0'
        );
        final Set<int> unsyncedIds = unsyncedLocal
            .map((p) => int.tryParse(p['id']?.toString() ?? '') ?? -1)
            .where((id) => id != -1)
            .toSet();

        final batch = db.batch();
        for (var item in dataList) {
          final pId = int.tryParse(item['id']?.toString() ?? '') ?? -1;
          if (pId != -1 && unsyncedIds.contains(pId)) {
            // Jangan timpa produk lokal yang belum sinkron (bisa jadi sedang diedit/dihapus offline)
            continue;
          }

          String? imageUrl = item['image_url'];
          if (imageUrl != null && !imageUrl.startsWith('http')) {
            if (!imageUrl.startsWith('/storage')) {
              imageUrl = '/storage/$imageUrl';
            }
            imageUrl = '${ApiConfig.baseUrl}$imageUrl';
          }

          batch.insert('products', {
            'id': item['id'],
            'category_id': int.tryParse(item['category_id']?.toString() ?? ''),
            'name': item['name'],
            'description': item['description'],
            'price': item['price'],
            'cost_price': item['cost_price'],
            'stock': int.tryParse(item['stock']?.toString() ?? '0') ?? 0,
            'image_url': imageUrl,
            'status': (item['status'] == true || item['status'] == 1 || item['status'] == '1') ? 'active' : 'inactive',
            'parent_id': item['parent_id'] != null ? int.tryParse(item['parent_id'].toString()) : null,
            'bundle_qty': int.tryParse(item['bundle_qty']?.toString() ?? '1') ?? 1,
            'min_stock': int.tryParse(item['min_stock']?.toString() ?? '10') ?? 10,
            'is_synced': 1,
          }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    } catch (_) {}
  }

  Future<void> pullProductComponents() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/product-components'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> dataList = jsonDecode(response.body);
        final db = await dbHelper.database;
        final batch = db.batch();
        
        // Bersihkan data lama agar selalu fresh dari server
        batch.delete('product_components');
        
        for (var item in dataList) {
          batch.insert('product_components', {
            'parent_id': item['parent_id'],
            'child_id': item['child_id'],
            'quantity': item['quantity'],
            'is_synced': 1,
          });
        }
        await batch.commit(noResult: true);
      }
    } catch (_) {}
  }

  // --- -1. ABSENSI (ATTENDANCES) ---

  Future<void> syncAttendances() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;

    final List<Map<String, dynamic>> unsynced = await db.query('attendances', where: 'is_synced = ?', whereArgs: [0]);
    
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
    final shopId = int.tryParse(userData['shop_id']?.toString() ?? '');

    for (var attend in unsynced) {
      final sId = attend['shop_id'] ?? userData['shop_id'];
      try {
        final String? imagePath = attend['image_path'];
        
        // Cek apakah file foto ada
        bool fileExists = false;
        String base64Image = '';
        
        if (imagePath != null && imagePath.isNotEmpty) {
          final file = File(imagePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            base64Image = base64Encode(bytes);
            fileExists = true;
          }
        }

        if (fileExists) {
          final response = await http.post(
            Uri.parse('${ApiConfig.apiUrl}/attendance'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'type': attend['type'],
              'latitude': attend['latitude'],
              'longitude': attend['longitude'],
              'photo': base64Image,
              'shop_id': sId,
              'created_at': attend['date_time'],
              'note': attend['type'] == 'in' ? 'Masuk (Sync)' : 'Pulang (Sync)',
            }),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final responseData = jsonDecode(response.body);
            await db.update(
              'attendances',
              {'is_synced': 1, 'server_id': responseData['data']['id']},
              where: 'id = ?',
              whereArgs: [attend['id']],
            );
          }
        } else {
          // Jika file foto tidak ada (misal ditarik dari server tapi link foto pecah/file terhapus),
          // kita tandai sukses saja agar tidak nyangkut terus di notifikasi pending.
          await db.update('attendances', {'is_synced': 1}, where: 'id = ?', whereArgs: [attend['id']]);
        }
      } catch (e) {
        print('SYNC ERROR syncAttendances: $e');
      }
    }
  }

  // --- 0. TOKO / CABANG (SHOPS) ---

  Future<void> syncShops() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;

    final List<Map<String, dynamic>> unsynced = await db.query('shops', where: 'is_synced = ?', whereArgs: [0]);
    for (var shop in unsynced) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.apiUrl}/shops/${shop['id']}'),
          headers: {
            ...ApiConfig.headers,
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            '_method': 'PUT',
            'name': shop['name'],
            'is_main': shop['is_main'].toString(),
            'address': shop['address'],
            'phone': shop['phone'],
            'slogan': shop['slogan'],
            'tiktok': shop['tiktok'],
            'instagram': shop['instagram'],
            'facebook': shop['facebook'],
            'web': shop['web'],
            'latitude': shop['latitude'],
            'longitude': shop['longitude'],
            'stock': shop['stock']?.toString(),
            'min_stock': shop['min_stock']?.toString(),
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          await db.update('shops', {'is_synced': 1}, where: 'id = ?', whereArgs: [shop['id']]);
        }
      } catch (_) {}
    }
  }

  // --- 1. KEUANGAN (FINANCES) ---

  Future<void> pullFinances() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(Uri.parse('${ApiConfig.apiUrl}/finance'), headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data']['data'] ?? [];
        
        final prefs = await SharedPreferences.getInstance();
        final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
        final currentShopId = int.tryParse(userData['shop_id']?.toString() ?? '');

        final db = await dbHelper.database;
        final batch = db.batch();

        for (var item in dataList) {
          final Map<String, dynamic> mapData = item as Map<String, dynamic>;
          
          batch.insert('finances', {
            'server_id': mapData['id'],
            'shop_id': mapData['shop_id'] ?? currentShopId,
            'type': mapData['type'],
            'category': mapData['category'],
            'amount': mapData['amount'],
            'description': mapData['note'],
            'date': DateTime.parse(mapData['date'] ?? mapData['created_at']).toLocal().toIso8601String(),
            'status': mapData['status'] ?? 'active',
            'is_synced': 1,
            'user_name': mapData['user']?['name'],
            'shop_name': mapData['shop']?['name'],
          }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      print('SYNC ERROR pullFinances: $e');
    }
  }

  Future<void> syncFinances() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;

    final List<Map<String, dynamic>> unsynced = await db.query('finances', where: 'is_synced = ?', whereArgs: [0]);
    for (var mapData in unsynced) {
      if (mapData['server_id'] != null && mapData['status'] == 'active') {
        // Jika sudah ada server_id dan status active, berarti sudah sinkron tapi flag is_synced tertinggal
        await db.update('finances', {'is_synced': 1}, where: 'id = ?', whereArgs: [mapData['id']]);
        continue;
      }
      if (mapData['server_id'] != null) continue; // Biarkan syncStatusUpdates yang menangani jika status void

      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.apiUrl}/finance'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({
            'type': mapData['type'],
            'category': mapData['category'],
            'amount': mapData['amount'],
            'note': mapData['description'],
            'date': mapData['date'],
            'status': mapData['status'],
            'void_by': mapData['void_by'],
          }),
        ).timeout(const Duration(seconds: 30));
        if (response.statusCode == 201 || response.statusCode == 200) {
          final serverData = jsonDecode(response.body);
          await db.update('finances', {'is_synced': 1, 'server_id': serverData['data']['id']}, where: 'id = ?', whereArgs: [mapData['id']]);
        }
      } catch (_) {}
    }
  }

  // --- 2. TRANSAKSI (TRANSACTIONS) ---

  Future<void> pullTransactions() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(Uri.parse('${ApiConfig.apiUrl}/transactions'), headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] is List ? body['data'] : (body['data']['data'] ?? []);

        final prefs = await SharedPreferences.getInstance();
        final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
        final currentShopId = int.tryParse(userData['shop_id']?.toString() ?? '');

        final db = await dbHelper.database;
        final batch = db.batch();

        for (var item in dataList) {
          final Map<String, dynamic> mapData = item as Map<String, dynamic>;

          batch.insert('transactions', {
            'server_id': mapData['id'],
            'shop_id': mapData['shop_id'] ?? currentShopId,
            'items': jsonEncode(mapData['items'] ?? []),
            'total_price': mapData['total_price'],
            'payment_method': mapData['payment_method'] ?? 'cash',
            'created_at': DateTime.parse(mapData['created_at']).toLocal().toIso8601String(),
            'status': mapData['status'] ?? 'active',
            'is_synced': 1,
            'user_name': mapData['user']?['name'],
            'shop_name': mapData['shop']?['name'],
          }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      print('SYNC ERROR pullTransactions: $e');
    }
  }

  Future<void> syncPendingTransactions() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;
    
    final List<Map<String, dynamic>> unsynced = await db.query('transactions', where: 'is_synced = ?', whereArgs: [0]);
    for (var mapData in unsynced) {
      if (mapData['server_id'] != null && mapData['status'] == 'active') {
        await db.update('transactions', {'is_synced': 1}, where: 'id = ?', whereArgs: [mapData['id']]);
        continue;
      }
      if (mapData['server_id'] != null) continue;

      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.apiUrl}/transactions'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({ 
            'invoice_number': mapData['invoice_number'],
            'items': jsonDecode(mapData['items']), 
            'total_price': mapData['total_price'], 
            'payment_method': mapData['payment_method'], 
            'pay_amount': mapData['cash_received'], 
            'change_amount': mapData['change'],
            'status': mapData['status'],
            'void_by': mapData['void_by'],
            'user_name': mapData['user_name'],
            'shop_name': mapData['shop_name'],
            'created_at': mapData['created_at'], // Ambil waktu asli dari DB lokal
          }),
        ).timeout(const Duration(seconds: 30));
        if (response.statusCode == 201 || response.statusCode == 200) {
          final resp = jsonDecode(response.body);
          await db.update('transactions', {
            'is_synced': 1, 
            'server_id': resp['data']['id'],
            'invoice_number': resp['data']['invoice_number'], // Update dengan nomor resmi dari server
          }, where: 'id = ?', whereArgs: [mapData['id']]);
        }
      } catch (_) {}
    }
  }

  // --- 3. STATUS UPDATES (VOID/CANCEL) ---

  Future<void> syncStatusUpdates() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;

    // 1. Update status Keuangan
    final voidFinances = await db.query('finances', where: 'status = ? AND is_synced = ? AND server_id IS NOT NULL', whereArgs: ['void', 0]);
    for (var f in voidFinances) {
      try {
        final resp = await http.put(
          Uri.parse('${ApiConfig.apiUrl}/finance/${f['server_id']}'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({'status': 'void', 'void_by': f['void_by']}),
        ).timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200) {
          await db.update('finances', {'is_synced': 1}, where: 'id = ?', whereArgs: [f['id']]);
        }
      } catch (_) {}
    }

    // 2. Update status Transaksi
    final voidTransactions = await db.query('transactions', where: 'status = ? AND is_synced = ? AND server_id IS NOT NULL', whereArgs: ['void', 0]);
    for (var t in voidTransactions) {
      try {
        final resp = await http.put(
          Uri.parse('${ApiConfig.apiUrl}/transactions/${t['server_id']}'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({'status': 'void', 'void_by': t['void_by']}),
        ).timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200) {
          await db.update('transactions', {'is_synced': 1}, where: 'id = ?', whereArgs: [t['id']]);
        }
      } catch (_) {}
    }
  }

  Future<void> syncCategories() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;

    final unsynced = await db.query('categories', where: 'is_synced = ?', whereArgs: [0]);
    for (var cat in unsynced) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.apiUrl}/categories'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({'name': cat['name']}),
        ).timeout(const Duration(seconds: 30));
        if (response.statusCode == 201) {
          final serverData = jsonDecode(response.body);
          await db.delete('categories', where: 'id = ?', whereArgs: [cat['id']]);
          await db.insert('categories', {
            'id': serverData['id'],
            'name': cat['name'],
            'is_synced': 1,
            'status': 'active',
          });
        }
      } catch (_) {}
    }
  }

  Future<void> syncProducts() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;

    final unsynced = await db.query('products', where: 'is_synced = ?', whereArgs: [0]);
    for (var p in unsynced) {
      try {
        if (p['status'] == 'deleted') {
          // Jika status didelete secara offline, hapus ke server
          final response = await http.delete(
            Uri.parse('${ApiConfig.apiUrl}/products/${p['id']}'),
            headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          ).timeout(const Duration(seconds: 30));
          
          if (response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404) {
            // Hapus secara permanen dari SQLite lokal
            await db.delete('products', where: 'id = ?', whereArgs: [p['id']]);
          }
        } else {
          // Update Produk (Hanya dukung update data teks offline)
          final response = await http.put(
            Uri.parse('${ApiConfig.apiUrl}/products/${p['id']}'),
            headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
            body: jsonEncode({
              'name': p['name'],
              'category_id': p['category_id'],
              'description': p['description'],
              'price': p['price'],
              'cost_price': p['cost_price'],
              'stock': p['stock'],
              'parent_id': p['parent_id'],
              'bundle_qty': p['bundle_qty'],
              'min_stock': p['min_stock'],
            }),
          ).timeout(const Duration(seconds: 30));
          if (response.statusCode == 200) {
            await db.update('products', {'is_synced': 1}, where: 'id = ?', whereArgs: [p['id']]);
          }
        }
      } catch (e) {
        print('Error sync produk ${p['id']}: $e');
      }
    }
  }

  Future<void> syncShifts() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    if (token == null) return;

    // 1. Sync Buka Kasir (yang belum punya server_id)
    final openShifts = await db.query('shifts', where: 'status = ? AND server_id IS NULL', whereArgs: ['open']);
    for (var s in openShifts) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.apiUrl}/cashier/open'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({'starting_cash': s['starting_cash'], 'created_at': s['opened_at']}),
        ).timeout(const Duration(seconds: 30));
        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          await db.update('shifts', {'server_id': data['data']['id'], 'is_synced': 1}, where: 'id = ?', whereArgs: [s['id']]);
        }
      } catch (_) {}
    }

    // 2. Sync Tutup Kasir (yang sudah closed tapi belum is_synced)
    final closedShifts = await db.query('shifts', where: 'status = ? AND is_synced = ?', whereArgs: ['closed', 0]);
    for (var s in closedShifts) {
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.apiUrl}/cashier/close'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({
            'actual_cash': s['actual_cash'], 
            'note': s['note'],
            'closed_at': s['closed_at']
          }),
        ).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          await db.update('shifts', {'is_synced': 1}, where: 'id = ?', whereArgs: [s['id']]);
        }
      } catch (_) {}
    }
  }
  Future<void> pullAttendances() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/attendance/history'), 
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'}
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        final db = await dbHelper.database;
        
        for (var item in dataList) {
          // Simpan record Masuk
          if (item['in_time'] != null) {
            await db.insert('attendances', {
              'server_id': item['id'],
              'type': 'in',
              'image_path': item['in_photo'],
              'date_time': DateTime.parse(item['created_at']).toLocal().toIso8601String(),
              'is_synced': 1,
              'status': 'active',
            }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
          }
          // Simpan record Pulang
          if (item['out_time'] != null) {
            await db.insert('attendances', {
              'server_id': item['id'],
              'type': 'out',
              'image_path': item['out_photo'],
              'date_time': DateTime.parse(item['updated_at'] ?? item['created_at']).toLocal().toIso8601String(),
              'is_synced': 1,
              'status': 'active',
            }, conflictAlgorithm: sql.ConflictAlgorithm.replace);
          }
        }
      }
    } catch (_) {}
  }
}
