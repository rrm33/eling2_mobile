import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/api_config.dart';
import 'database_helper.dart';

class ProductService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<int?> _getShopId() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data'); // Gunakan key 'user_data' agar konsisten dengan AuthService
    if (userDataString != null) {
      final user = jsonDecode(userDataString);
      return int.tryParse(user['shop_id'].toString());
    }
    return null;
  }

  Future<List<dynamic>> getCategories({bool sync = false}) async {
    final db = await DatabaseHelper.instance.database;
    final shopId = await _getShopId();
    
    // 1. Ambil Lokal (Filter per Toko ATAU Global)
    final localResults = await db.query(
      'categories', 
      where: shopId == null ? 'shop_id IS NULL' : '(shop_id = ? OR shop_id IS NULL)', 
      whereArgs: shopId == null ? [] : [shopId]
    );
    if (!sync) return localResults;

    // 2. Sync Background
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/categories'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final List<dynamic> serverCats = jsonDecode(response.body);
        
        // Bersihkan data lama toko ini yang sudah sinkron
        if (shopId == null) {
          await db.delete('categories', where: 'shop_id IS NULL AND is_synced = 1');
        } else {
          await db.delete('categories', where: 'shop_id = ? AND is_synced = 1', whereArgs: [shopId]);
        }
        
        final batch = db.batch();
        for (var cat in serverCats) {
          batch.insert('categories', {
            'id': int.tryParse(cat['id']?.toString() ?? ''),
            'shop_id': cat['shop_id'], // Gunakan shop_id dari server
            'name': cat['name'],
            'status': cat['status'] ?? 'active',
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        return serverCats;
      }
    } catch (e) {
      print('Gagal sync kategori: $e');
    }
    return localResults;
  }

  Future<bool> saveCategory(String name) async {
    final db = await DatabaseHelper.instance.database;
    final shopId = await _getShopId();
    
    // Simpan lokal
    final localId = await db.insert('categories', {
      'shop_id': shopId,
      'name': name,
      'is_synced': 0,
      'status': 'active',
    });

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/categories'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode({'name': name}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final serverData = jsonDecode(response.body);
        final realId = serverData['data'] != null ? serverData['data']['id'] : serverData['id'];
        
        await db.delete('categories', where: 'id = ?', whereArgs: [localId]);
        await db.insert('categories', {
          'id': realId,
          'shop_id': shopId,
          'name': name,
          'is_synced': 1,
          'status': 'active',
        });
        return true;
      }
    } catch (e) {
      print('Simpan kategori offline: $e');
    }
    return true; 
  }

  Future<List<dynamic>> getProducts({int? categoryId, String? search, bool sync = false}) async {
    final db = await DatabaseHelper.instance.database;
    
    String where = "status != 'deleted'";
    List<dynamic> args = [];
    
    if (categoryId != null) {
      where += ' AND category_id = ?';
      args.add(categoryId);
    }
    if (search != null && search.isNotEmpty) {
      where += ' AND name LIKE ?';
      args.add('%$search%');
    }
    
    final List<Map<String, dynamic>> rawResults = await db.query('products', where: where, whereArgs: args, orderBy: 'id DESC');
    
    final localResults = rawResults.map((p) {
      final map = Map<String, dynamic>.from(p);
      String? imageUrl = map['image_url'];
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        // Jika tidak dimulai dengan /storage, tambahkan
        if (!imageUrl.startsWith('/storage')) {
          imageUrl = '/storage/$imageUrl';
        }
        imageUrl = '${ApiConfig.baseUrl}$imageUrl';
      }
      map['image_url'] = imageUrl;
      return map;
    }).toList();

    if (!sync) return localResults;

    try {
      final token = await _getToken();
      String url = '${ApiConfig.apiUrl}/products?';
      if (categoryId != null) url += 'category_id=$categoryId&';
      if (search != null) url += 'search=$search&';

      final response = await http.get(
        Uri.parse(url),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> serverProds = jsonDecode(response.body);
        
        // Bersihkan data lama toko ini yang statusnya is_synced = 1 (agar tidak terjadi kebocoran cache)
        if (categoryId != null) {
          await db.delete('products', where: 'category_id = ? AND is_synced = 1', whereArgs: [categoryId]);
        } else if (search == null) {
          await db.delete('products', where: 'is_synced = 1');
        }

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
        for (var p in serverProds) {
          final pId = int.tryParse(p['id']?.toString() ?? '') ?? -1;
          if (pId != -1 && unsyncedIds.contains(pId)) {
            // Jangan timpa produk lokal yang belum sinkron (bisa jadi sedang diedit/dihapus offline)
            continue;
          }

          String? imageUrl = p['image_url'];
          if (imageUrl != null && !imageUrl.startsWith('http')) {
            if (!imageUrl.startsWith('/storage')) {
              imageUrl = '/storage/$imageUrl';
            }
            imageUrl = '${ApiConfig.baseUrl}$imageUrl';
          }

          batch.insert('products', {
            'id': p['id'],
            'category_id': int.tryParse(p['category_id']?.toString() ?? ''),
            'name': p['name'],
            'description': p['description'],
            'price': p['price'],
            'cost_price': p['cost_price'],
            'stock': int.tryParse(p['stock']?.toString() ?? '0') ?? 0,
            'image_url': imageUrl,
            'status': p['status'] ?? 'active',
            'is_synced': 1,
            'parent_id': p['parent_id'] != null ? int.tryParse(p['parent_id'].toString()) : null,
            'bundle_qty': int.tryParse(p['bundle_qty']?.toString() ?? '1') ?? 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        
        // Ambil hasil terbaru dari SQLite lokal setelah digabung
        return getProducts(categoryId: categoryId, search: search, sync: false);
      }
    } catch (e) {
      print('Gagal sync produk: $e');
    }
    return localResults;
  }

  Future<String?> saveProduct(Map<String, String> data, File? image, {int? id}) async {
    final db = await DatabaseHelper.instance.database;
    final shopId = await _getShopId();
    
    // 1. Simpan/Update Lokal Dulu
    int? localId = id;
    if (id != null) {
      await db.update('products', {
        'name': data['name'],
        'category_id': data['category_id'],
        'description': data['description'],
        'price': data['price'],
        'cost_price': data['cost_price'],
        'stock': data['stock'],
        'parent_id': data['parent_id'],
        'bundle_qty': data['bundle_qty'],
        'is_synced': 0,
      }, where: 'id = ?', whereArgs: [id]);
    } else {
      // Simpan produk baru ke lokal dengan ID sementara (is_synced = 0)
      localId = await db.insert('products', {
        'name': data['name'],
        'category_id': data['category_id'],
        'description': data['description'],
        'price': data['price'],
        'cost_price': data['cost_price'],
        'stock': data['stock'],
        'parent_id': data['parent_id'],
        'bundle_qty': data['bundle_qty'],
        'is_synced': 0,
      });
    }

    try {
      final token = await _getToken();
      final uri = Uri.parse(id == null 
          ? '${ApiConfig.apiUrl}/products' 
          : '${ApiConfig.apiUrl}/products/$id?_method=PUT');

      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({...ApiConfig.headers, 'Authorization': 'Bearer $token'});
      
      // Filter field kosong agar tidak menggagalkan validasi server (nullable fields)
      final filteredData = Map<String, String>.from(data)
        ..removeWhere((key, value) => value.isEmpty);
      request.fields.addAll(filteredData);

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }

      // NAIKKAN TIMEOUT JADI 60 DETIK
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      print('PRODUCT SYNC: Status ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final serverData = jsonDecode(response.body);
        // Server mengembalikan {'message': ..., 'data': {...}} untuk create maupun update
        final productData = serverData['data'] ?? serverData;
        final realId = productData['id'] ?? id;
        
        if (realId != null) {
          String? imageUrl = productData['image_url'];
          if (imageUrl != null && !imageUrl.startsWith('http')) {
            if (!imageUrl.startsWith('/storage')) {
              imageUrl = '/storage/$imageUrl';
            }
            imageUrl = '${ApiConfig.baseUrl}$imageUrl';
          }

          // Update semua field lokal dengan data server agar konsisten
          await db.update('products', {
            'id': realId,
            'name': productData['name'] ?? data['name'],
            'category_id': int.tryParse(productData['category_id']?.toString() ?? data['category_id'] ?? ''),
            'description': productData['description'] ?? data['description'],
            'price': productData['price'] ?? data['price'],
            'bundle_qty': int.tryParse(productData['bundle_qty']?.toString() ?? data['bundle_qty'] ?? '0') ?? 0,
            'status': productData['status'] ?? data['status'],
            'is_synced': 1,
            'image_url': imageUrl,
          }, where: 'id = ?', whereArgs: [localId]);
        }
        return null; // null = sukses
      } else {
        // Kembalikan pesan error dari server langsung ke user
        String serverMsg = 'HTTP ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body['message'] != null) {
            serverMsg = body['message'].toString();
          } else if (body['errors'] != null) {
            final errors = body['errors'] as Map;
            serverMsg = errors.values.map((v) => v is List ? v.first : v).join(', ');
          }
        } catch (_) {
          serverMsg = response.body.length > 200 ? response.body.substring(0, 200) : response.body;
        }
        print('Gagal simpan ke server: $serverMsg');
        return serverMsg;
      }
    } on TimeoutException catch (_) {
      print('SYNC TIMEOUT: Data tersimpan lokal, akan sinkron nanti.');
      return null; // null = sukses (tersimpan lokal)
    } catch (e) {
      print('Simpan produk error: $e');
      return e.toString();
    }
  }

  Future<bool> deleteProduct(int id) async {
    final db = await DatabaseHelper.instance.database;
    
    // Set status 'deleted' dan is_synced = 0 dulu di lokal agar langsung menghilang dari UI
    await db.update('products', {'status': 'deleted', 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
    
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiUrl}/products/$id'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404) {
        // Jika sukses di server atau produk sudah tidak ditemukan (sudah terhapus), hapus secara permanen dari database lokal
        await db.delete('products', where: 'id = ?', whereArgs: [id]);
        return true;
      } else {
        print('Gagal hapus produk di server: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Gagal kirim delete ke server (offline), data disimpan lokal: $e');
      // Karena is_synced = 0 dan status = 'deleted', nanti SyncService akan mensinkronkannya saat online
      return true; 
    }
  }

  // --- FITUR PAKET / BUNDLE ---

  // Ambil isi paket
  Future<List<Map<String, dynamic>>> getProductComponents(int parentId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('product_components', where: 'parent_id = ?', whereArgs: [parentId]);
  }

  // Simpan isi paket
  Future<void> saveProductComponents(int parentId, List<Map<String, dynamic>> components) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      // Hapus yang lama
      await txn.delete('product_components', where: 'parent_id = ?', whereArgs: [parentId]);
      // Masukkan yang baru
      for (var comp in components) {
        await txn.insert('product_components', {
          'parent_id': parentId,
          'child_id': comp['child_id'],
          'quantity': comp['quantity'],
          'is_synced': 0,
        });
      }
    });
  }
}
