import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';
import 'database_helper.dart';

class FinanceService {
  final dbHelper = DatabaseHelper.instance;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // DASHBOARD CARD: Hanya hitung yang statusnya 'active' dan sesuai cabang & shift
  Future<Map<String, dynamic>> getSummary(int? shopId, {bool isAdmin = false}) async {
    final db = await dbHelper.database;
    
    // 1. Ambil Modal Awal (Starting Cash) dari Shift Terakhir yang sedang buka
    double startingCash = 0;
    String? startTime;
    if (shopId != null) {
      final List<Map<String, dynamic>> shiftResult = await db.query(
        'shifts',
        columns: ['starting_cash', 'opened_at'],
        where: 'shop_id = ? AND status = ?',
        whereArgs: [shopId, 'open'],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (shiftResult.isNotEmpty) {
        startingCash = double.tryParse(shiftResult.first['starting_cash']?.toString() ?? '0') ?? 0;
        startTime = shiftResult.first['opened_at'];
      }
    }

    // 2. Hitung Pemasukan & Pengeluaran via SQL (Filter by shop_id & shift start time)
    String financeWhere = "WHERE status != 'void'";
    List<dynamic> financeArgs = [];
    
    // Keamanan: Jika bukan admin, WAJIB filter shop_id.
    if (!isAdmin) {
      financeWhere += " AND shop_id = ?";
      financeArgs.add(shopId ?? -1);
    } else if (shopId != null) {
      financeWhere += " AND shop_id = ?";
      financeArgs.add(shopId);
    }

    if (startTime != null) {
      financeWhere += " AND date >= ?";
      financeArgs.add(startTime);
    }

    final List<Map<String, dynamic>> financeResult = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as total_expense
      FROM finances 
      $financeWhere
    ''', financeArgs);

    double income = double.tryParse(financeResult.first['total_income']?.toString() ?? '0') ?? 0;
    double expense = double.tryParse(financeResult.first['total_expense']?.toString() ?? '0') ?? 0;

    // 3. Hitung Jualan (Sales) via SQL (Filter by shop_id & shift start time)
    String salesWhere = "WHERE status != 'void'";
    List<dynamic> salesArgs = [];
    if (!isAdmin) {
      salesWhere += " AND shop_id = ?";
      salesArgs.add(shopId ?? -1);
    } else if (shopId != null) {
      salesWhere += " AND shop_id = ?";
      salesArgs.add(shopId);
    }
    
    if (startTime != null) {
      salesWhere += " AND created_at >= ?";
      salesArgs.add(startTime);
    }

    final List<Map<String, dynamic>> salesResult = await db.rawQuery('''
      SELECT SUM(total_price) as total_sales 
      FROM transactions 
      $salesWhere
    ''', salesArgs);
    
    double totalSales = double.tryParse(salesResult.first['total_sales']?.toString() ?? '0') ?? 0;

    // 4. Hitung Omset Penjualan Hari Ini (Mulai 00:00:00 s.d 23:59:59 hari ini)
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    String todaySalesWhere = "WHERE status != 'void' AND created_at BETWEEN ? AND ?";
    List<dynamic> todaySalesArgs = [todayStart, todayEnd];
    if (!isAdmin) {
      todaySalesWhere += " AND shop_id = ?";
      todaySalesArgs.add(shopId ?? -1);
    } else if (shopId != null) {
      todaySalesWhere += " AND shop_id = ?";
      todaySalesArgs.add(shopId);
    }

    final List<Map<String, dynamic>> todaySalesResult = await db.rawQuery('''
      SELECT 
        SUM(total_price) as today_sales,
        SUM(CASE WHEN LOWER(IFNULL(payment_method, 'cash')) IN ('cash', 'tunai') THEN total_price ELSE 0 END) as today_sales_cash,
        SUM(CASE WHEN LOWER(IFNULL(payment_method, 'cash')) = 'qris' THEN total_price ELSE 0 END) as today_sales_qris,
        SUM(CASE WHEN LOWER(IFNULL(payment_method, 'cash')) NOT IN ('cash', 'tunai', 'qris') THEN total_price ELSE 0 END) as today_sales_lainnya
      FROM transactions 
      $todaySalesWhere
    ''', todaySalesArgs);
    
    double todaySales = double.tryParse(todaySalesResult.first['today_sales']?.toString() ?? '0') ?? 0;
    double todaySalesCash = double.tryParse(todaySalesResult.first['today_sales_cash']?.toString() ?? '0') ?? 0;
    double todaySalesQris = double.tryParse(todaySalesResult.first['today_sales_qris']?.toString() ?? '0') ?? 0;
    double todaySalesLainnya = double.tryParse(todaySalesResult.first['today_sales_lainnya']?.toString() ?? '0') ?? 0;

    return {
      'starting_cash': startingCash,
      'total_income': income,
      'total_expense': expense,
      'total_sales': totalSales,
      'today_sales': todaySales,
      'today_sales_cash': todaySalesCash,
      'today_sales_qris': todaySalesQris,
      'today_sales_lainnya': todaySalesLainnya,
      'balance': (startingCash + income + totalSales) - expense,
      'source': 'local_storage'
    };
  }

  // DAFTAR KEUANGAN: Ambil semua data sesuai cabang
  Future<List<dynamic>> getFinances({required String type}) async {
    final db = await dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final user = jsonDecode(prefs.getString('user_data') ?? '{}');
    final shopId = user['shop_id'] != null ? int.tryParse(user['shop_id'].toString()) : null;
    final isAdmin = user['role']?.toString().toLowerCase() == 'admin';

    String where = 'type = ?';
    List<dynamic> whereArgs = [type];

    if (!isAdmin) {
      // Proteksi: Kasir wajib filter berdasarkan shop_id mereka
      where += ' AND shop_id = ?';
      whereArgs.add(shopId ?? -1); // Jika null, paksa tidak ada data yang cocok
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'finances',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return maps;
  }

  // SIMPAN
  Future<bool> storeFinance(Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    String? userName;
    String? shopName;
    int? shopId;
    
    if (userDataString != null) {
      final user = jsonDecode(userDataString);
      userName = user['name'];
      shopName = user['shop']?['name'];
      shopId = user['shop_id'] != null ? int.tryParse(user['shop_id'].toString()) : null;
    }

    final localId = await db.insert('finances', {
      'type': data['type'],
      'category': data['category'],
      'amount': data['amount'],
      'description': data['note'] ?? data['description'],
      'date': data['date'] ?? DateTime.now().toIso8601String(),
      'is_synced': 0, 
      'status': 'active',
      'user_name': userName,
      'shop_name': shopName,
      'shop_id': shopId,
    });

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/finance'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final serverData = jsonDecode(response.body);
        await db.update('finances', {'is_synced': 1, 'server_id': serverData['data']['id']}, where: 'id = ?', whereArgs: [localId]);
      }
    } catch (_) {}
    return true; 
  }

  // BATALKAN (VOID): Mengubah status menjadi dibatalkan + Catat Pelakunya
  Future<bool> voidFinance(int id, String voidBy) async {
    final db = await dbHelper.database;
    
    // Ubah di HP: Tandai status Void dan siapa pelakunya
    await db.update(
      'finances', 
      {'status': 'void', 'is_synced': 0, 'void_by': voidBy}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
    
    // Coba lapor ke server
    try {
      final record = (await db.query('finances', where: 'id = ?', whereArgs: [id])).first;
      if (record['server_id'] != null) {
        final token = await _getToken();
        await http.put(
          Uri.parse('${ApiConfig.apiUrl}/finance/${record['server_id']}'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
          body: jsonEncode({'status': 'void', 'void_by': voidBy}),
        );
      }
    } catch (_) {}
    
    return true;
  }
}
