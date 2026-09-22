import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';
import '../../services/shop_service.dart';
import '../../services/transaction_service.dart';
import '../widgets/custom_button.dart';
import 'receipt_screen.dart';
import 'edit_transaction_screen.dart';
import 'product_sales_detail_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final ShopService _shopService = ShopService();
  final TransactionService _transactionService = TransactionService();
  List<dynamic> _transactions = [];
  List<dynamic> _shops = [];
  Map<String, dynamic> _summary = {'total_sales': 0, 'total_transactions': 0};
  
  bool _isLoading = true;
  int? _selectedShopId;
  String _dateFilter = 'Hari Ini';
  DateTimeRange? _customDateRange;
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedMonthYear;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchShops(),
      _fetchTransactions(),
    ]);
  }

  Future<void> _fetchShops() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?['role']?.toString().toLowerCase() != 'admin') return;

    try {
      final shops = await _shopService.getShops();
      if (mounted) {
        setState(() => _shops = shops);
      }
    } catch (e) {
      debugPrint('Error fetch shops: $e');
    }
  }

  Future<void> _fetchTransactions() async {
    final db = await DatabaseHelper.instance.database;
    
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_dateFilter == 'Hari Ini') {
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_dateFilter == 'Custom' && _customDateRange != null) {
      start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
      end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
    } else if (_dateFilter == '7 Hari Terakhir') {
      start = now.subtract(const Duration(days: 7));
    } else if (_dateFilter == 'Per Bulan') {
      int y = _selectedMonthYear ?? now.year;
      int m = _selectedMonth ?? now.month;
      start = DateTime(y, m, 1, 0, 0, 0);
      end = DateTime(y, m + 1, 1).subtract(const Duration(seconds: 1));
    } else if (_dateFilter == 'Per Tahun') {
      int y = _selectedYear ?? now.year;
      start = DateTime(y, 1, 1, 0, 0, 0);
      end = DateTime(y, 12, 31, 23, 59, 59);
    }

    final String startStr = start.toIso8601String();
    final String endStr = end.toIso8601String();

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final int? userShopId = user?['shop_id'] != null ? int.tryParse(user!['shop_id'].toString()) : null;
    final bool isAdmin = user?['role']?.toString().toLowerCase() == 'admin';

    String localWhere = 'created_at BETWEEN ? AND ?';
    List<dynamic> localArgs = [startStr, endStr];

    if (!isAdmin && userShopId != null) {
      localWhere += ' AND shop_id = ?';
      localArgs.add(userShopId);
    }

    final List<Map<String, dynamic>> localData = await db.query(
      'transactions', 
      where: localWhere,
      whereArgs: localArgs,
      orderBy: 'id DESC'
    );

    double localTotal = 0;
    double localTotalCash = 0;
    double localTotalQris = 0;
    double localTotalLainnya = 0;
    int localCount = 0;
    int totalDimsum = 0;
    int totalSaus = 0;
    for (var item in localData) {
      if (item['status'] != 'void') {
        double price = double.parse(item['total_price'].toString());
        localTotal += price;
        
        String paymentMethod = (item['payment_method']?.toString() ?? 'cash').toLowerCase();
        if (['tunai', 'cash'].contains(paymentMethod)) {
            localTotalCash += price;
        } else if (['qris'].contains(paymentMethod)) {
            localTotalQris += price;
        } else {
            localTotalLainnya += price;
        }

        localCount++;
        
        List items = [];
        try { items = jsonDecode(item['items'].toString()); } catch(_) {}
        for (var i in items) {
           final name = (i['product_name'] ?? i['name'] ?? i['product']?['name'] ?? '').toString().toLowerCase();
           final bundleQty = int.tryParse(i['bundle_qty']?.toString() ?? i['product']?['bundle_qty']?.toString() ?? '0') ?? 0;
           final qty = int.tryParse(i['quantity']?.toString() ?? i['qty']?.toString() ?? '0') ?? 0;
           
           if (bundleQty > 0) {
              totalDimsum += (bundleQty * qty);
           }
           if (name.contains('saus bangkok') || name.contains('sauce bangkok')) {
              totalSaus += qty;
           }
        }
      }
    }

    if (mounted) {
      setState(() {
        _transactions = localData.map((e) {
          final item = Map<String, dynamic>.from(e);
          item['invoice_number'] = item['invoice_number'] ?? (item['server_id'] != null ? '${item['server_id']}' : 'LOKAL-${item['id']}');
          item['shop'] = {'name': item['shop_name'] ?? 'Cabang'};
          if (item['items'] != null && item['items'] is String) {
            try { item['items'] = jsonDecode(item['items']); } catch (_) { item['items'] = []; }
          }
          return item;
        }).toList();
        
        _summary = {
           'total_sales': localTotal, 
           'total_transactions': localCount, 
           'total_grains': totalDimsum, 
           'total_saus': totalSaus,
           'total_sales_cash': localTotalCash,
           'total_sales_qris': localTotalQris,
           'total_sales_lainnya': localTotalLainnya,
        };
        _isLoading = false;
      });
    }

    // 2. AMBIL DARI SERVER DI BACKGROUND
    try {
      final prefs = await SharedPreferences.getInstance();
      String url = '${ApiConfig.apiUrl}/transactions?start_date=${DateFormat('yyyy-MM-dd').format(start)}&end_date=${DateFormat('yyyy-MM-dd').format(end)}';
      if (_selectedShopId != null) url += '&shop_id=$_selectedShopId';

      final response = await http.get(
        Uri.parse(url),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        final List<dynamic> serverData = res['data'];
        
        // 1. Identifikasi transaksi lokal yang is_synced = 1 tetapi sudah tidak ada di server (telah dihapus)
        final serverInvoices = serverData.map((s) => s['invoice_number']?.toString()).toSet();
        final serverIds = serverData.map((s) => int.tryParse(s['id']?.toString() ?? '')).toSet();
        
        final List<int> deletedLocalIds = [];
        for (var ld in localData) {
          if (ld['is_synced'] == 1) {
            final int? localId = int.tryParse(ld['id']?.toString() ?? '');
            final int? localServerId = int.tryParse(ld['server_id']?.toString() ?? '');
            final String? localInvoice = ld['invoice_number']?.toString();
            
            bool existsOnServer = false;
            if (localServerId != null && serverIds.contains(localServerId)) {
              existsOnServer = true;
            }
            if (localInvoice != null && serverInvoices.contains(localInvoice)) {
              existsOnServer = true;
            }
            
            if (!existsOnServer && localId != null) {
              deletedLocalIds.add(localId);
            }
          }
        }

        // 2. Hapus secara sinkron dari SQLite lokal menggunakan ID lokal (Primary Key) sebelum update state
        if (deletedLocalIds.isNotEmpty) {
          for (var localId in deletedLocalIds) {
            await db.delete('transactions', where: 'id = ?', whereArgs: [localId]);
          }
          print('SQLITE CLEANUP: Berhasil menghapus ${deletedLocalIds.length} transaksi sampah berdasarkan ID lokal.');
        }
        
        if (mounted) {
          setState(() {
            // MERGE & DE-DUPLICATE AGGRESIF: 
            // Kita buang data lokal jika sudah ada data server yang "mirip" (Invoice sama ATAU Total + Waktu sama)
            final unsyncedLocal = localData.where((ld) {
              if (ld['is_synced'] == 1) return false;

              // Jangan tampilkan jika ID lokal ini ada di daftar yang didelete
              if (deletedLocalIds.contains(ld['id'])) return false;

              bool isAlreadyOnServer = serverData.any((s) {
                if (s['invoice_number'] == ld['invoice_number']) return true;
                
                final ldTime = ld['created_at'].toString().substring(0, 16);
                final sTime = s['created_at'].toString().substring(0, 16);
                return s['total_price'].toString() == ld['total_price'].toString() && ldTime == sTime;
              });

              return !isAlreadyOnServer;
            }).map((e) {
              final item = Map<String, dynamic>.from(e);
              item['shop'] = {'name': item['shop_name'] ?? 'Cabang'};
              if (item['items'] is String) {
                try { item['items'] = jsonDecode(item['items']); } catch (_) { item['items'] = []; }
              }
              return item;
            }).toList();

            _transactions = [...unsyncedLocal, ...serverData.map((t) {
              final item = Map<String, dynamic>.from(t);
              item['is_synced'] = 1;
              return item;
            })];
            
            _summary = res['summary'];
          });
        }
      }
    } catch (e) {
      debugPrint('Background sync failed: $e');
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AuthProvider>(context).user?['role']?.toString().toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Riwayat Transaksi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildFilters(isAdmin),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                ? const Center(child: Text('Tidak ada data transaksi'))
                : RefreshIndicator(
                    onRefresh: _fetchTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) => _buildTransactionItem(_transactions[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    String subtitle;
    final bulanList = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    if (_dateFilter == 'Per Tahun') {
      subtitle = _selectedYear != null ? '$_selectedYear' : '${DateTime.now().year}';
    } else if (_dateFilter == 'Per Bulan') {
      final now = DateTime.now();
      subtitle = '${bulanList[(_selectedMonth ?? now.month) - 1]} ${_selectedMonthYear ?? now.year}';
    } else if (_dateFilter == 'Hari Ini') {
      subtitle = DateFormat('dd MMM yyyy').format(DateTime.now());
    } else if (_dateFilter == 'Custom' && _customDateRange != null) {
      if (_customDateRange!.start == _customDateRange!.end) {
        subtitle = DateFormat('dd MMM yyyy').format(_customDateRange!.start);
      } else {
        subtitle = '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange!.end)}';
      }
    } else if (_dateFilter == '7 Hari Terakhir') {
      final from = DateTime.now().subtract(const Duration(days: 7));
      subtitle = '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(DateTime.now())}';
    } else {
      subtitle = _dateFilter;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Omzet ($subtitle)', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 5),
                    Text(_formatCurrency(double.parse(_summary['total_sales'].toString())), style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildPaymentBadge('Tunai', double.tryParse(_summary['total_sales_cash']?.toString() ?? '0') ?? 0, Colors.green),
                        _buildPaymentBadge('QRIS', double.tryParse(_summary['total_sales_qris']?.toString() ?? '0') ?? 0, Colors.purple),
                        _buildPaymentBadge('Lain', double.tryParse(_summary['total_sales_lainnya']?.toString() ?? '0') ?? 0, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Produk Terjual: ${_summary['total_products'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductSalesDetailScreen(
                            productDetails: _summary['product_details'] ?? [],
                          ),
                        ),
                      );
                    },
                    child: const Text('Lihat detail >', style: TextStyle(color: Colors.yellow, fontSize: 12, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallSummary('Jml Transaksi', _summary['total_transactions'].toString()),
              _buildSmallSummary('Dimsum Terjual', '${_summary['total_grains'] ?? 0} biji', alignCenter: true),
              _buildSmallSummary('Saus Terjual', '${_summary['total_saus'] ?? 0} pcs', isRight: true),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSmallSummary(String label, String value, {bool isRight = false, bool alignCenter = false}) {
    CrossAxisAlignment align = CrossAxisAlignment.start;
    if (isRight) align = CrossAxisAlignment.end;
    if (alignCenter) align = CrossAxisAlignment.center;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildPaymentBadge(String label, double amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
          child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 4),
        Text(_formatCurrency(amount), style: GoogleFonts.outfit(fontSize: 11, color: Colors.white)),
      ],
    );
  }

  Widget _buildFilters(bool isAdmin) {
    return Column(
      children: [
        if (isAdmin)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: DropdownButtonFormField<int>(
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              hintText: 'Semua Cabang',
            ),
            value: _selectedShopId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua Cabang')),
              ..._shops.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name']))),
            ],
            onChanged: (val) {
              setState(() => _selectedShopId = val);
              _fetchTransactions();
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(10),
          child: Row(
            children: ['Hari Ini', 'Custom', '7 Hari Terakhir', 'Per Bulan', 'Per Tahun'].map((filter) {
              // Buat label yang menampilkan pilihan filter
              String chipLabel = filter;
              if (filter == 'Custom' && _dateFilter == filter && _customDateRange != null) {
                if (_customDateRange!.start == _customDateRange!.end) {
                  chipLabel = DateFormat('d MMM yyyy').format(_customDateRange!.start);
                } else {
                  chipLabel = '${DateFormat('d MMM').format(_customDateRange!.start)} - ${DateFormat('d MMM yyyy').format(_customDateRange!.end)}';
                }
              } else if (filter == 'Per Bulan' && _dateFilter == filter && _selectedMonth != null) {
                final bulanList = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                chipLabel = '${bulanList[_selectedMonth! - 1]} ${_selectedMonthYear ?? DateTime.now().year}';
              } else if (filter == 'Per Tahun' && _dateFilter == filter && _selectedYear != null) {
                chipLabel = '$_selectedYear';
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(chipLabel, style: TextStyle(fontSize: 12, color: _dateFilter == filter ? Colors.white : Colors.black)),
                  selected: _dateFilter == filter,
                  selectedColor: AppColors.primary,
                  onSelected: (selected) async {
                    if (filter == 'Per Tahun') {
                      int currentYear = DateTime.now().year;
                      int? pickedYear = await showDialog<int>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Pilih Tahun'),
                          content: SizedBox(
                            width: 300,
                            height: 300,
                            child: ListView.builder(
                              itemCount: 10,
                              itemBuilder: (ctx, i) {
                                int year = currentYear - i;
                                return ListTile(
                                  title: Text(year.toString(), style: TextStyle(fontWeight: year == (_selectedYear ?? currentYear) ? FontWeight.bold : FontWeight.normal)),
                                  trailing: year == (_selectedYear ?? currentYear) ? const Icon(Icons.check, color: Colors.green) : null,
                                  onTap: () => Navigator.pop(ctx, year),
                                );
                              }
                            ),
                          ),
                        )
                      );
                      if (pickedYear != null) {
                        setState(() { _dateFilter = filter; _selectedYear = pickedYear; });
                        _fetchTransactions();
                      }
                    } else if (filter == 'Per Bulan') {
                      final now = DateTime.now();
                      final bulanList = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
                      final result = await showDialog<Map<String, int>>(
                        context: context,
                        builder: (ctx) {
                          int dialogYear = _selectedMonthYear ?? now.year;
                          return StatefulBuilder(
                            builder: (ctx, setDialogState) => AlertDialog(
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setDialogState(() => dialogYear--)),
                                  Text('$dialogYear', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setDialogState(() => dialogYear++)),
                                ],
                              ),
                              content: SizedBox(
                                width: 300,
                                height: 200,
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.2),
                                  itemCount: 12,
                                  itemBuilder: (ctx, i) {
                                    final isSelected = (i + 1) == (_selectedMonth ?? now.month) && dialogYear == (_selectedMonthYear ?? now.year);
                                    return GestureDetector(
                                      onTap: () => Navigator.pop(ctx, {'month': i + 1, 'year': dialogYear}),
                                      child: Container(
                                        margin: const EdgeInsets.all(4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(bulanList[i].substring(0, 3), style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        }
                      );
                      if (result != null) {
                        setState(() { _dateFilter = filter; _selectedMonth = result['month']; _selectedMonthYear = result['year']; });
                        _fetchTransactions();
                      }
                    } else if (filter == 'Custom') {
                      final picked = await showDateRangePicker(
                        context: context,
                        initialDateRange: _customDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now()
                      );
                      if (picked != null) {
                        setState(() { _dateFilter = filter; _customDateRange = picked; });
                        _fetchTransactions();
                      }
                    } else {
                      setState(() => _dateFilter = filter);
                      _fetchTransactions();
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteTransaction(dynamic t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Transaksi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Anda yakin ingin menghapus transaksi ${t['invoice_number']}?\nTindakan ini akan mengembalikan stok barang ke cabang terkait.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              
              final invoiceNumber = t['invoice_number']?.toString() ?? '';
              final serverId = t['server_id'] != null 
                  ? int.tryParse(t['server_id'].toString()) 
                  : (t['is_synced'] == 1 ? int.tryParse(t['id']?.toString() ?? '') : null);
              final items = t['items'] is List ? t['items'] : [];

              final errorMessage = await _transactionService.deleteTransaction(
                invoiceNumber: invoiceNumber,
                serverId: serverId,
                items: items,
              );

              if (errorMessage == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaksi berhasil dihapus dan stok dikembalikan')),
                  );
                }
                _fetchTransactions();
              } else {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus transaksi: $errorMessage')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }



  void _navigateToEditTransaction(dynamic t) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTransactionScreen(transactionData: Map<String, dynamic>.from(t))),
    );

    if (result == true) {
      _fetchTransactions(); // Refresh data setelah berhasil edit
    }
  }

  Widget _buildTransactionItem(dynamic t) {
    String dateStr = '-';
    try { dateStr = DateFormat('dd MMM, HH:mm').format(DateTime.parse(t['created_at']).toLocal()); } catch (_) {}
    
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).user?['role']?.toString().toLowerCase() == 'admin';
    final isVoid = t['status'] == 'void';
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10, left: 15, right: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(transactionData: t))),
        title: Text(
          t['shop']?['name'] ?? 'Cabang', 
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, 
            fontSize: 14,
            decoration: isVoid ? TextDecoration.lineThrough : null,
            color: isVoid ? Colors.grey : AppColors.primary,
          )
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    t['invoice_number'] ?? '-', 
                    style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Metode: ${(t['payment_method']?.toString() ?? 'Tunai').toUpperCase()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: t['payment_method']?.toString().toLowerCase() == 'qris' ? Colors.purple : (t['payment_method']?.toString().toLowerCase() == 'lainnya' ? Colors.orange : Colors.green),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(double.parse(t['total_price'].toString())), 
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, 
                    color: isVoid ? Colors.grey : Colors.black,
                    decoration: isVoid ? TextDecoration.lineThrough : null,
                  )
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isVoid 
                          ? 'Void' 
                          : (t['is_synced'] == 1 ? 'Sinkron' : 'Lokal'),
                      style: GoogleFonts.outfit(
                        fontSize: 10, 
                        color: isVoid 
                            ? Colors.red 
                            : (t['is_synced'] == 1 ? Colors.green : Colors.orange), 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isVoid 
                          ? Icons.cancel 
                          : (t['is_synced'] == 1 ? Icons.check_circle : Icons.cloud_off), 
                      size: 12, 
                      color: isVoid 
                          ? Colors.red 
                          : (t['is_synced'] == 1 ? Colors.green : Colors.orange)
                    ),
                  ],
                ),
              ],
            ),
            if (isAdmin || !isVoid) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDeleteTransaction(t);
                  } else if (value == 'edit') {
                    _navigateToEditTransaction(t);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (!isVoid)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Transaksi'),
                        ],
                      ),
                    ),
                  if (isAdmin)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever_outlined, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Hapus Permanen'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
