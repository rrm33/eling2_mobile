import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';
import 'database_helper.dart';
import 'cashier_shift_service.dart';

class TransactionService {
  final dbHelper = DatabaseHelper.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, int>> getShiftMetrics(bool isAdmin) async {
    final db = await dbHelper.database;
    final now = DateTime.now();
    
    String startTime;
    if (isAdmin) {
      // Untuk Admin: seluruh hari ini dari jam 00:00
      startTime = DateTime(now.year, now.month, now.day).toIso8601String();
    } else {
      // Untuk Kasir: sejak shift dibuka
      final shift = await CashierShiftService().getCurrentShift();
      if (shift == null) return {'dimsum': 0, 'saus': 0};
      startTime = shift['start_time'];
    }
    
    final List<Map<String, dynamic>> txs = await db.query(
      'transactions',
      where: 'status != ? AND created_at >= ?',
      whereArgs: ['void', startTime]
    );
    
    int totalDimsum = 0;
    int totalSaus = 0;
    
    for (var tx in txs) {
      final items = jsonDecode(tx['items'] as String? ?? '[]');
      for (var item in items) {
        final name = (item['product_name'] ?? item['name'] ?? '').toString().toLowerCase();
        final bundleQty = int.tryParse(item['bundle_qty']?.toString() ?? '0') ?? 0;
        final qty = int.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '0') ?? 0;
        
        if (bundleQty > 0) {
           totalDimsum += (bundleQty * qty);
        }
        if (name.contains('saus bangkok') || name.contains('sauce bangkok')) {
           totalSaus += qty;
        }
      }
    }
    return {'dimsum': totalDimsum, 'saus': totalSaus};
  }

  /// Memanggil API Server yang sama dengan Halaman Laporan untuk mendapatkan total_grains
  Future<Map<String, int>> getDimsumOutFromServer(bool isAdmin) async {
    try {
      final token = await _getToken();
      if (token == null) return {'dimsum': 0, 'saus': 0};

      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      final user = userDataString != null ? jsonDecode(userDataString) : null;
      final String? shopId = isAdmin ? null : user?['shop_id']?.toString();

      DateTime now = DateTime.now();
      String startDate = DateFormat('yyyy-MM-dd').format(now);
      String endDate = startDate;

      String url = '${ApiConfig.apiUrl}/transactions?start_date=$startDate&end_date=$endDate&';
      if (shopId != null) url += 'shop_id=$shopId&';

      final response = await http.get(Uri.parse(url), headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['summary'];
        int totalGrains = int.tryParse(summary['total_grains']?.toString() ?? '0') ?? 0;
        int totalSaus = int.tryParse(summary['total_saus']?.toString() ?? '0') ?? 0;
        
        return {'dimsum': totalGrains, 'saus': totalSaus};
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Lempar error agar fallback lokal di UI bisa dijalankan
      throw Exception('Failed to get dimsum from server: $e');
    }
  }

  Future<Map<String, dynamic>?> storeTransaction(Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data'); // Gunakan key 'user_data' agar konsisten
    String? userName;
    String? shopName;
    int? shopId;
    
    if (userDataString != null) {
      final user = jsonDecode(userDataString);
      userName = user['name'];
      shopName = user['shop']?['name'];
      shopId = int.tryParse(user['shop_id']?.toString() ?? '');
    }

    // GENERATE INVOICE NUMBER (Format Standar: YYYYMMDD/SHOP_ID/HHMMSS)
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePrefix = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final invoiceNumber = "$datePrefix/${shopId ?? 0}/$timePrefix";

    // 1. Simpan ke HP Dulu
    final localId = await db.insert('transactions', {
      'items': jsonEncode(data['items']),
      'invoice_number': invoiceNumber,
      'total_price': data['total_price'],
      'payment_method': data['payment_method'],
      'cash_received': data['pay_amount'], 
      'change': data['change_amount'],
      'created_at': now.toIso8601String(),
      'is_synced': 0,
      'status': data['status'] ?? 'completed',
      'user_name': userName,
      'shop_name': shopName,
      'shop_id': shopId,
    });

    print('SQLITE DEBUG: Berhasil simpan lokal dengan ID: $localId');

    // 2. Potong Stok Lokal (Cek apakah barang ini paket atau bukan)
    final List<dynamic> items = data['items'];
    for (var item in items) {
      // Ambil data produk untuk cek parent_id & bundle_qty
      final List<Map<String, dynamic>> productData = await db.query(
        'products', 
        where: 'id = ?', 
        whereArgs: [item['product_id']]
      );

      if (productData.isNotEmpty) {
        final p = productData.first;
        final int? parentId = p['parent_id'] != null ? int.tryParse(p['parent_id'].toString()) : null;
        final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '1') ?? 1;

        if (parentId != null && parentId != 0) {
          // Jika Produk Paket: Potong stok Produk Asal
          int totalDeduct = bundleQty * (item['quantity'] as int);
          await db.execute(
            'UPDATE products SET stock = stock - ?, is_synced = 0 WHERE id = ?',
            [totalDeduct, parentId]
          );
        } else {
          // Jika Produk Biasa: Potong stok produk itu sendiri
          await db.execute(
            'UPDATE products SET stock = stock - ?, is_synced = 0 WHERE id = ?',
            [item['quantity'], item['product_id']]
          );
        }
      }
    }

    // 3. Ambil data dari lokal untuk dikirim ke server
    final savedLocal = (await db.query('transactions', where: 'id = ?', whereArgs: [localId])).first;

    print('SYNC DEBUG: Mencoba kirim ke server: $invoiceNumber');

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/transactions'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'invoice_number': savedLocal['invoice_number'],
          'items': savedLocal['items'] is String ? jsonDecode(savedLocal['items'] as String) : savedLocal['items'],
          'total_price': savedLocal['total_price'],
          'pay_amount': savedLocal['cash_received'],
          'change_amount': savedLocal['change'],
          'payment_method': savedLocal['payment_method'],
          'status': savedLocal['status'],
          'created_at': savedLocal['created_at'],
          'shop_id': savedLocal['shop_id'], // Tambahkan ini agar server tahu tokonya!
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
          final resp = jsonDecode(response.body);
          final serverData = resp['data'];

          print('SYNC SUCCESS: Server returned ID: ${serverData['id']}');

          // Update local transaction as synced
          await db.rawUpdate(
            'UPDATE transactions SET is_synced = 1, server_id = ?, invoice_number = ? WHERE id = ?',
            [serverData['id'], serverData['invoice_number'], localId]
          );

          print('SQLITE UPDATE SUCCESS for localId: $localId');

          // Pastikan user_name & shop_name ada untuk struk
          serverData['user_name'] = serverData['user_name'] ?? userName;
          serverData['shop_name'] = serverData['shop_name'] ?? shopName;

          return serverData;
        } else if (response.statusCode == 422) {
          // Stock insufficient or validation error
          final errorMsg = jsonDecode(response.body)['message'] ?? 'Validation error';
          print('SYNC FAILED: $errorMsg');

          // Rollback local stock changes
          for (var item in items) {
            final List<Map<String, dynamic>> productData = await db.query(
              'products',
              where: 'id = ?',
              whereArgs: [item['product_id']]
            );
            if (productData.isNotEmpty) {
              final p = productData.first;
              final int? parentId = p['parent_id'] != null ? int.tryParse(p['parent_id'].toString()) : null;
              final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '1') ?? 1;
              if (parentId != null && parentId != 0) {
                int totalRestore = bundleQty * (item['quantity'] as int);
                await db.execute(
                  'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
                  [totalRestore, parentId]
                );
              } else {
                await db.execute(
                  'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
                  [item['quantity'], item['product_id']]
                );
              }
            }
          }
          // Delete the local transaction record
          await db.delete('transactions', where: 'id = ?', whereArgs: [localId]);
          return {'error': errorMsg};
        } else {
          // Error 5xx (500, 502, 503, 504) atau server bermasalah:
          // Anggap sebagai MODE OFFLINE! Jangan hapus transaksi lokal & jangan rollback stok lokal.
          // Transaksi tetap tersimpan di SQLite (is_synced = 0) agar kasir bisa cetak struk & jualan lancar.
          print('SERVER ERROR ${response.statusCode}: Tersimpan lokal di HP (is_synced = 0) untuk di-sync nanti saat server online.');
        }
     } catch (e) {
       print('Gagal kirim ke server, data aman di HP: $e');
     }

     // Jika offline, kembalikan data "palsu" tapi dengan invoice yang sudah digenerate
     return {
       ...data,
       'id': localId,
       'offline': true,
       'invoice_number': invoiceNumber,
       'created_at': now.toIso8601String(),
       'message': 'Berhasil (Disimpan di HP)',
       'user_name': userName,
       'shop_name': shopName,
     };
   }

  Future<String?> deleteTransaction({
    required String invoiceNumber,
    int? serverId,
    required List<dynamic> items,
  }) async {
    final db = await dbHelper.database;

    // 1. Coba hapus di server jika ada serverId
    if (serverId != null) {
      try {
        final token = await _getToken();
        final response = await http.delete(
          Uri.parse('${ApiConfig.apiUrl}/transactions/$serverId'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 404) {
          print('Gagal hapus transaksi di server: ${response.statusCode} - ${response.body}');
          return 'Server error (${response.statusCode}): ${response.body}';
        }
      } catch (e) {
        print('Error hapus transaksi di server (offline): $e');
        // Jika offline, transaksi yang sudah sinkron tidak boleh dihapus agar data keuangan aman
        return 'Koneksi error: $e';
      }
    }

    // 2. Kembalikan stok lokal di HP
    for (var item in items) {
      final int productId = int.tryParse(item['product_id']?.toString() ?? '') ?? 0;
      final int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

      if (productId != 0 && qty > 0) {
        // Ambil data produk untuk cek parent_id & bundle_qty
        final List<Map<String, dynamic>> productData = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId]
        );

        if (productData.isNotEmpty) {
          final p = productData.first;
          final int? parentId = p['parent_id'] != null ? int.tryParse(p['parent_id'].toString()) : null;
          final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '1') ?? 1;

          if (parentId != null && parentId != 0) {
            int totalRestore = bundleQty * qty;
            await db.execute(
              'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
              [totalRestore, parentId]
            );
          } else {
            await db.execute(
              'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
              [qty, productId]
            );
          }
        }
      }
    }

    // 3. Hapus baris transaksi secara permanen di SQLite lokal berdasarkan invoice_number
    await db.delete('transactions', where: 'invoice_number = ?', whereArgs: [invoiceNumber]);
    return null;
  }

  Future<String?> voidTransaction({
    required String invoiceNumber,
    int? serverId,
    required List<dynamic> items,
  }) async {
    final db = await dbHelper.database;

    // 1. Coba void di server jika ada serverId
    if (serverId != null) {
      try {
        final token = await _getToken();
        final response = await http.post(
          Uri.parse('${ApiConfig.apiUrl}/transactions/$serverId/void'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 404) {
          print('Gagal void transaksi di server: ${response.statusCode} - ${response.body}');
          return 'Server error (${response.statusCode}): ${response.body}';
        }
      } catch (e) {
        print('Error void transaksi di server (offline): $e');
        return 'Koneksi error: $e';
      }
    }

    // 2. Kembalikan stok lokal di HP
    for (var item in items) {
      final int productId = int.tryParse(item['product_id']?.toString() ?? '') ?? 0;
      final int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

      if (productId != 0 && qty > 0) {
        final List<Map<String, dynamic>> productData = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId]
        );

        if (productData.isNotEmpty) {
          final p = productData.first;
          final int? parentId = p['parent_id'] != null ? int.tryParse(p['parent_id'].toString()) : null;
          final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '1') ?? 1;

          if (parentId != null && parentId != 0) {
            int totalRestore = bundleQty * qty;
            await db.execute(
              'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
              [totalRestore, parentId]
            );
          } else {
            await db.execute(
              'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
              [qty, productId]
            );
          }
        }
      }
    }

    // 3. Update status transaksi menjadi 'void' di SQLite lokal berdasarkan invoice_number
    await db.update(
      'transactions',
      {'status': 'void', 'is_synced': 1},
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber]
    );
    return null;
  }

  Future<String?> updateTransaction({
    required String invoiceNumber,
    required int? serverId,
    required List<dynamic> oldItems,
    required Map<String, dynamic> updatedData,
  }) async {
    final db = await dbHelper.database;

    // 1. Kembalikan stok lama di SQLite lokal
    for (var item in oldItems) {
      final int productId = int.tryParse(item['product_id']?.toString() ?? '') ?? 0;
      final int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

      if (productId != 0 && qty > 0) {
        final List<Map<String, dynamic>> productData = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId]
        );

        if (productData.isNotEmpty) {
          final p = productData.first;
          final int? parentId = p['parent_id'] != null ? int.tryParse(p['parent_id'].toString()) : null;
          final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '1') ?? 1;

          if (parentId != null && parentId != 0) {
            int totalRestore = bundleQty * qty;
            await db.execute(
              'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
              [totalRestore, parentId]
            );
          } else {
            await db.execute(
              'UPDATE products SET stock = stock + ?, is_synced = 0 WHERE id = ?',
              [qty, productId]
            );
          }
        }
      }
    }

    // 2. Potong stok baru di SQLite lokal
    final List<dynamic> newItems = updatedData['items'];
    for (var item in newItems) {
      final int productId = int.tryParse(item['product_id']?.toString() ?? '') ?? 0;
      final int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

      if (productId != 0 && qty > 0) {
        final List<Map<String, dynamic>> productData = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId]
        );

        if (productData.isNotEmpty) {
          final p = productData.first;
          final int? parentId = p['parent_id'] != null ? int.tryParse(p['parent_id'].toString()) : null;
          final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '1') ?? 1;

          if (parentId != null && parentId != 0) {
            int totalDeduct = bundleQty * qty;
            await db.execute(
              'UPDATE products SET stock = stock - ?, is_synced = 0 WHERE id = ?',
              [totalDeduct, parentId]
            );
          } else {
            await db.execute(
              'UPDATE products SET stock = stock - ?, is_synced = 0 WHERE id = ?',
              [qty, productId]
            );
          }
        }
      }
    }

    // 3. Update data transaksi di SQLite lokal
    await db.update(
      'transactions',
      {
        'items': jsonEncode(newItems),
        'total_price': updatedData['total_price'],
        'cash_received': updatedData['pay_amount'],
        'change': updatedData['change_amount'],
        'payment_method': updatedData['payment_method'],
        'created_at': updatedData['created_at'],
        'status': updatedData['status'] ?? 'completed',
        'is_synced': 0, // Tandai belum tersinkron
      },
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber]
    );

    // 4. Update data transaksi di Server jika terkoneksi (serverId tidak null)
    if (serverId != null) {
      try {
        final token = await _getToken();
        final response = await http.put(
          Uri.parse('${ApiConfig.apiUrl}/transactions/$serverId'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({
            'items': newItems,
            'total_price': updatedData['total_price'],
            'pay_amount': updatedData['pay_amount'],
            'change_amount': updatedData['change_amount'],
            'payment_method': updatedData['payment_method'],
            'created_at': updatedData['created_at'],
            'status': updatedData['status'],
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 204) {
          // Tandai sudah sinkron
          await db.update(
            'transactions',
            {'is_synced': 1},
            where: 'invoice_number = ?',
            whereArgs: [invoiceNumber]
          );
        } else {
          // Kembalikan pesan error server
          String errorMsg = 'Server error ${response.statusCode}';
          try {
            final body = jsonDecode(response.body);
            if (body is Map && body['message'] != null) errorMsg = body['message'];
          } catch (_) {}
          return errorMsg;
        }
      } catch (e) {
        print('Gagal update transaksi ke server (offline/error): $e');
        return 'Gagal update ke server. Pastikan koneksi internet stabil.';
      }
    }
    return null;
  }
}
