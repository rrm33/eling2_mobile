import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/api_config.dart';
import 'database_helper.dart';

class CashierShiftService {
  final dbHelper = DatabaseHelper.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>?> getCurrentShift() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    
    // 1. Cek apakah ada shift lokal yang masih buka tapi belum sinkron
    final List<Map<String, dynamic>> unsyncedOpen = await db.query('shifts', where: "status = 'open' AND is_synced = 0", limit: 1);

    // 2. Coba fetch dari server (Hanya jika tidak ada shift lokal yang unsynced)
    if (unsyncedOpen.isEmpty) {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.apiUrl}/cashier/current'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data != null && data is Map && data.containsKey('id')) {
            await db.insert('shifts', {
              'server_id': data['id'],
              'starting_cash': data['starting_cash'],
              'opened_at': data['start_time'] ?? data['created_at'],
              'status': 'open',
              'is_synced': 1,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            return data as Map<String, dynamic>;
          } else {
            // Self-healing: Jika server mengatakan tidak ada shift yang buka, 
            // maka shift di HP yang berstatus open (dan sudah is_synced=1) harus ditutup otomatis
            // agar sinkron dengan kenyataan di server.
            await db.update('shifts', {'status': 'closed'}, where: "status = 'open' AND is_synced = 1");
            return null;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback Lokal (Hitung total sales, income, expense dari SQLite)
    final List<Map<String, dynamic>> openShifts = await db.query('shifts', where: "status = 'open'", limit: 1);
    if (openShifts.isNotEmpty) {
      final shift = openShifts.first;
      final startTime = shift['opened_at'] as String;

      // Hitung Jualan
      final sales = await db.query('transactions', where: "status != 'void' AND created_at >= ?", whereArgs: [startTime]);
      double totalSales = 0;
      for (var s in sales) {
        totalSales += double.tryParse(s['total_price'].toString()) ?? 0;
      }

      // Hitung Finance
      final finances = await db.query('finances', where: "status != 'void' AND date >= ?", whereArgs: [startTime]);
      double totalIncome = 0;
      double totalExpense = 0;
      for (var f in finances) {
        double amt = double.tryParse(f['amount'].toString()) ?? 0;
        if (f['type'] == 'income') {
          totalIncome += amt;
        } else {
          totalExpense += amt;
        }
      }

      return {
        'id': shift['server_id'],
        'starting_cash': shift['starting_cash'],
        'start_time': startTime,
        'total_sales': totalSales,
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'offline': true,
      };
    }
    return null;
  }

  Future<Map<String, dynamic>> openShift(double startingCash) async {
    final db = await dbHelper.database;
    final token = await _getToken();
    
    final prefs = await SharedPreferences.getInstance();
    final user = jsonDecode(prefs.getString('user_data') ?? '{}');

    // 1. Simpan Lokal
    final localId = await db.insert('shifts', {
      'starting_cash': startingCash,
      'opened_at': DateTime.now().toIso8601String(),
      'status': 'open',
      'user_name': user['name'],
      'shop_name': user['shop']?['name'],
      'is_synced': 0,
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/cashier/open'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode({'starting_cash': startingCash}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await db.update('shifts', {
          'server_id': data['data']['id'],
          'is_synced': 1,
        }, where: 'id = ?', whereArgs: [localId]);
        return {'success': true, 'message': data['message']};
      }
    } catch (e) {
      print('Buka kasir offline: $e');
    }
    
    return {'success': true, 'message': 'Kasir dibuka secara offline.'};
  }

  Future<Map<String, dynamic>> closeShift(double actualCash, String? note) async {
    final db = await dbHelper.database;
    final token = await _getToken();

    // 1. Update Lokal
    await db.update('shifts', {
      'actual_cash': actualCash,
      'note': note,
      'closed_at': DateTime.now().toIso8601String(),
      'status': 'closed',
      'is_synced': 0,
    }, where: "status = 'open'");

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/cashier/close'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode({'actual_cash': actualCash, 'note': note}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await db.update('shifts', {'is_synced': 1}, where: "status = 'closed' AND is_synced = 0");
        return {'success': true, 'message': data['message']};
      }
    } catch (e) {
      print('Tutup kasir offline: $e');
    }
    
    return {'success': true, 'message': 'Kasir ditutup secara offline.'};
  }

  Future<List<dynamic>> getShiftReports() async {
    final db = await dbHelper.database;
    final token = await _getToken();
    List<dynamic> serverReports = [];
    List<dynamic> localUnsynced = [];

    // 1. Ambil data lokal yang belum sinkron
    try {
      final List<Map<String, dynamic>> localData = await db.query('shifts', where: 'is_synced = 0 AND status = ?', whereArgs: ['closed']);
      
      for (var s in localData) {
        final startTime = s['opened_at'];
        final endTime = s['closed_at'] ?? DateTime.now().toIso8601String();
        
        // Hitung Jualan lokal
        final sales = await db.query('transactions', where: "status != 'void' AND created_at >= ? AND created_at <= ?", whereArgs: [startTime, endTime]);
        double totalSales = 0;
        for (var tx in sales) {
          totalSales += double.tryParse(tx['total_price'].toString()) ?? 0;
        }

        // Hitung Finance lokal
        final finances = await db.query('finances', where: "status != 'void' AND date >= ? AND date <= ?", whereArgs: [startTime, endTime]);
        double totalIncome = 0;
        double totalExpense = 0;
        for (var f in finances) {
          double amt = double.tryParse(f['amount'].toString()) ?? 0;
          if (f['type'] == 'income') {
            totalIncome += amt;
          } else {
            totalExpense += amt;
          }
        }

        // Kalkulasi difference manual
        double startingCash = double.tryParse(s['starting_cash'].toString()) ?? 0;
        double actualCash = double.tryParse(s['actual_cash'].toString()) ?? 0;
        double expected = (startingCash + totalSales + totalIncome) - totalExpense;
        double difference = actualCash - expected;

        localUnsynced.add({
          ...s,
          'total_sales': totalSales,
          'total_income': totalIncome,
          'total_expense': totalExpense,
          'difference': difference,
          'is_offline': true
        });
      }
    } catch (_) {}

    // 2. Ambil data dari Server
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/cashier'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> reportsList = body is Map && body.containsKey('data') ? body['data'] : (body as List);
        
        serverReports = reportsList;
        for (var report in serverReports) {
          await db.insert('shifts', {
            'server_id': report['id'],
            'starting_cash': report['starting_cash'],
            'closing_cash': report['expected_balance'],
            'actual_cash': report['actual_cash'],
            'difference': report['difference'],
            'opened_at': report['start_time'] ?? report['created_at'],
            'closed_at': report['end_time'] ?? report['updated_at'],
            'note': report['note'],
            'status': report['status'] ?? 'closed',
            'user_name': report['user']?['name'],
            'shop_name': report['shop']?['name'],
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (_) {}

    if (serverReports.isNotEmpty) {
      return [...localUnsynced, ...serverReports];
    }
    
    // Jika offline penuh, ambil semua dari SQLite (baik yang synced maupun unsynced)
    final List<Map<String, dynamic>> allLocal = await db.query('shifts', orderBy: 'id DESC');
    
    // Untuk yang unsynced, kita harus ganti dengan data yang sudah di-calculate di atas
    List<dynamic> combinedOffline = [];
    for (var l in allLocal) {
      if (l['is_synced'] == 0 && l['status'] == 'closed') {
        final calculated = localUnsynced.firstWhere((element) => element['id'] == l['id'], orElse: () => l);
        combinedOffline.add(calculated);
      } else {
        combinedOffline.add(l);
      }
    }

    return combinedOffline;
  }

  // Hapus Laporan Shift (Khusus Admin)
  Future<Map<String, dynamic>> deleteShift(int id) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiUrl}/cashier/$id'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      final responseData = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ?? 'Gagal menghapus laporan'
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
