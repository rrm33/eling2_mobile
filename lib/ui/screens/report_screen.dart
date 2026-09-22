import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/app_colors.dart';
import '../../core/api_config.dart';
import '../../providers/auth_provider.dart';
import 'raw_material_per_shop_screen.dart';
import 'sales_chart_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _dateFilter = 'Hari Ini';
  final List<String> _filterOptions = ['Hari Ini', 'Custom', '7 Hari Terakhir', 'Per Bulan', 'Per Tahun', 'Semua Waktu'];
  DateTimeRange? _customDateRange;
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedMonthYear;

  bool _isLoading = true;

  // Laporan Data
  double _totalSales = 0;
  int _totalTransactions = 0;
  double _totalIncome = 0;
  double _totalExpense = 0;
  int _totalRawMaterial = 0;
  int _totalSaus = 0;
  double _totalCash = 0;
  double _totalQris = 0;
  double _totalLainnya = 0;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _topShops = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();
      final user = auth.user;
      final isAdmin = user?['role']?.toString().toLowerCase() == 'admin';
      final String? shopId = isAdmin ? null : user?['shop_id']?.toString();

      DateTime now = DateTime.now();
      String? startDate;
      String? endDate;

      if (_dateFilter == 'Hari Ini') {
        startDate = DateFormat('yyyy-MM-dd').format(now);
        endDate = startDate;
      } else if (_dateFilter == 'Custom' && _customDateRange != null) {
        startDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
        endDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
      } else if (_dateFilter == '7 Hari Terakhir') {
        startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
        endDate = DateFormat('yyyy-MM-dd').format(now);
      } else if (_dateFilter == 'Per Bulan') {
        int y = _selectedMonthYear ?? now.year;
        int m = _selectedMonth ?? now.month;
        startDate = '$y-${m.toString().padLeft(2,'0')}-01';
        final lastDay = DateTime(y, m + 1, 1).subtract(const Duration(days: 1)).day;
        endDate = '$y-${m.toString().padLeft(2,'0')}-$lastDay';
      } else if (_dateFilter == 'Per Tahun') {
        int y = _selectedYear ?? now.year;
        startDate = '$y-01-01';
        endDate = '$y-12-31';
      }

      // 1. Fetch Transactions & Summary
      String transUrl = '${ApiConfig.apiUrl}/transactions?';
      if (startDate != null) transUrl += 'start_date=$startDate&';
      if (endDate != null) transUrl += 'end_date=$endDate&';
      if (shopId != null) transUrl += 'shop_id=$shopId&';

      final transRes = await http.get(Uri.parse(transUrl), headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      });

      // 2. Fetch Finance Summary
      String financeUrl = '${ApiConfig.apiUrl}/finance/summary?';
      if (startDate != null) financeUrl += 'start_date=$startDate&';
      if (endDate != null) financeUrl += 'end_date=$endDate&';
      if (shopId != null) financeUrl += 'shop_id=$shopId&';

      final financeRes = await http.get(Uri.parse(financeUrl), headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      });

      if (transRes.statusCode == 200 && financeRes.statusCode == 200) {
        final transData = jsonDecode(transRes.body);
        final financeData = jsonDecode(financeRes.body);

        // Process Summary
        final summary = transData['summary'];
        _totalSales = double.tryParse(summary['total_sales'].toString()) ?? 0;
        _totalTransactions = int.tryParse(summary['total_transactions'].toString()) ?? 0;
        _totalRawMaterial = int.tryParse(summary['total_grains']?.toString() ?? '0') ?? 0;
        _totalSaus = int.tryParse(summary['total_saus']?.toString() ?? '0') ?? 0;
        _totalCash = double.tryParse(summary['total_sales_cash']?.toString() ?? '0') ?? 0;
        _totalQris = double.tryParse(summary['total_sales_qris']?.toString() ?? '0') ?? 0;
        _totalLainnya = double.tryParse(summary['total_sales_lainnya']?.toString() ?? '0') ?? 0;

        _totalIncome = double.tryParse(financeData['total_income'].toString()) ?? 0;
        _totalExpense = double.tryParse(financeData['total_expense'].toString()) ?? 0;

        // Gunakan product_details dari server (sudah diagregasi dengan benar)
        final List<dynamic> productDetails = summary['product_details'] ?? [];
        _topProducts = productDetails.map((p) => {
          'name': (p['name'] ?? 'Unknown').toString(),
          'qty': int.tryParse(p['total_qty']?.toString() ?? '0') ?? 0,
          'omset': double.tryParse(p['total_omset']?.toString() ?? '0') ?? 0,
          'bQty': 1, // bundle_qty tidak tersedia dari server langsung, tampil qty saja
        }).toList();

        // Gunakan shop_stats dari server (akurat, sama logikanya dengan total_grains/total_saus)
        final List<dynamic> shopStats = transData['shop_stats'] ?? [];
        _topShops = shopStats.map((s) => {
          'name': s['shop_name'] ?? 'Unknown',
          'sales': double.tryParse(s['total_sales']?.toString() ?? '0') ?? 0.0,
          'dimsum': int.tryParse(s['total_dimsum']?.toString() ?? '0') ?? 0,
          'saus': int.tryParse(s['total_saus']?.toString() ?? '0') ?? 0,
        }).toList();

      }
    } catch (e) {
      debugPrint("Error loading API report: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateRange ?? DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() { _customDateRange = picked; _dateFilter = 'Custom'; });
      _loadReportData();
    }
  }

  Future<void> _selectMonthFilter() async {
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
      setState(() { _dateFilter = 'Per Bulan'; _selectedMonth = result['month']; _selectedMonthYear = result['year']; });
      _loadReportData();
    }
  }

  Future<void> _selectYearFilter() async {
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
      setState(() { _selectedYear = pickedYear; _dateFilter = 'Per Tahun'; });
      _loadReportData();
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Laporan Penjualan (Online)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadReportData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            height: 50,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = filter == _dateFilter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                  child: InkWell(
                  onTap: () {
                      if (filter == 'Per Tahun') {
                        _selectYearFilter();
                      } else if (filter == 'Per Bulan') {
                        _selectMonthFilter();
                      } else if (filter == 'Custom') {
                        _selectCustomDateRange();
                      } else {
                        setState(() => _dateFilter = filter);
                        _loadReportData();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        () {
                          if (filter == 'Per Tahun' && isSelected && _selectedYear != null) return '$_selectedYear';
                          if (filter == 'Per Bulan' && isSelected && _selectedMonth != null) {
                            final bulanList = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
                            return '${bulanList[_selectedMonth! - 1]} ${_selectedMonthYear ?? DateTime.now().year}';
                          }
                          if (filter == 'Custom' && isSelected && _customDateRange != null) {
                            if (_customDateRange!.start == _customDateRange!.end) {
                              return DateFormat('d MMM yyyy').format(_customDateRange!.start);
                            }
                            return '${DateFormat('d MMM').format(_customDateRange!.start)} - ${DateFormat('d MMM yyyy').format(_customDateRange!.end)}';
                          }
                          return filter;
                        }(),
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadReportData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Text(
                          'Terakhir diperbarui: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      // _buildRawMaterialCard(),
                      // const SizedBox(height: 20),
                      // _buildFinanceCard(),
                      // const SizedBox(height: 16),
                      _buildTopShopsCard(),
                      const SizedBox(height: 16),
                      _buildProductBreakdownCard(),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    // Hitung subtitle berdasarkan filter aktif
    String subtitle;
    final bulanList = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final now = DateTime.now();
    if (_dateFilter == 'Per Tahun') {
      subtitle = _selectedYear != null ? '$_selectedYear' : '${now.year}';
    } else if (_dateFilter == 'Per Bulan') {
      subtitle = '${bulanList[(_selectedMonth ?? now.month) - 1]} ${_selectedMonthYear ?? now.year}';
    } else if (_dateFilter == 'Custom' && _customDateRange != null) {
      if (_customDateRange!.start == _customDateRange!.end) {
        subtitle = DateFormat('dd MMM yyyy').format(_customDateRange!.start);
      } else {
        subtitle = '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange!.end)}';
      }
    } else if (_dateFilter == '7 Hari Terakhir') {
      final from = now.subtract(const Duration(days: 7));
      subtitle = '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM').format(now)}';
    } else {
      subtitle = _dateFilter;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Omzet ($subtitle)', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
              InkWell(
                onTap: () {
                  final user = Provider.of<AuthProvider>(context, listen: false).user;
                  final String? shopId = user?['role']?.toString().toLowerCase() == 'admin' ? null : user?['shop_id']?.toString();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SalesChartScreen(initialShopId: shopId)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text('Lihat Grafik', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.insights, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(_formatCurrency(_totalSales), style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildPaymentBadge('Tunai', _totalCash, Colors.green),
              _buildPaymentBadge('QRIS', _totalQris, Colors.purple),
              _buildPaymentBadge('Lain', _totalLainnya, Colors.orange),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallSummary('Jml Transaksi', _totalTransactions.toString()),
              _buildSmallSummary('Dimsum Terjual', '$_totalRawMaterial biji', alignCenter: true),
              _buildSmallSummary('Saus Terjual', '$_totalSaus pcs', isRight: true),
            ],
          )
        ],
      ),
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

  Widget _buildSmallSummary(String label, String value, {bool isRight = false, bool alignCenter = false}) {
    CrossAxisAlignment align = CrossAxisAlignment.start;
    if (isRight) align = CrossAxisAlignment.end;
    if (alignCenter) align = CrossAxisAlignment.center;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRawMaterialCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Text('Pemakaian Bahan Baku', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)),
                ],
              ),
              // Small button to open per-shop raw material usage
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RawMaterialPerShopScreen()),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
                tooltip: 'Lihat per Cabang',
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Dimsum Terjual', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$_totalRawMaterial Butir', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                  Text('Dari $_totalTransactions Transaksi', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Saus Bangkok', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$_totalSaus pcs', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arus Kas Manual', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildFinanceStat(Icons.arrow_downward, 'Pemasukan', _totalIncome, Colors.green)),
              Container(width: 1, height: 40, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 15)),
              Expanded(child: _buildFinanceStat(Icons.arrow_upward, 'Pengeluaran', _totalExpense, Colors.red)),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Laba Bersih Estimasi', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
              Text(
                _formatCurrency((_totalSales + _totalIncome) - _totalExpense),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFinanceStat(IconData icon, String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
              Text(_formatCurrency(amount), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopShopsCard() {
    if (_topShops.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text('Peringkat Cabang Terlaris', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 15),
          ..._topShops.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> shop = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: idx == 0 ? Colors.orange.withOpacity(0.2) : (idx == 1 ? Colors.grey.withOpacity(0.2) : (idx == 2 ? Colors.brown.withOpacity(0.2) : Colors.transparent)),
                      shape: BoxShape.circle,
                    ),
                    child: Text('${idx + 1}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: idx == 0 ? Colors.orange : (idx == 1 ? Colors.grey.shade700 : (idx == 2 ? Colors.brown : Colors.grey)))),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop['name'] ?? 'Unknown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${shop['dimsum']} dimsum', style: GoogleFonts.outfit(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text('${shop['saus']} saus', style: GoogleFonts.outfit(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(_formatCurrency(shop['sales']), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProductBreakdownCard() {
    if (_topProducts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text('Detail Produk Terjual', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 15),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: IntrinsicColumnWidth(),
              2: IntrinsicColumnWidth(),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                children: [
                  _buildTableHeader('Produk'),
                  _buildTableHeader('Terjual'),
                  _buildTableHeader('Omzet'),
                ],
              ),
              ..._topProducts.map((p) {
                final qty = p['qty'] ?? 0;
                final omset = p['omset'] ?? 0.0;
                return TableRow(
                  children: [
                    _buildTableCell(p['name'].toString()),
                    _buildTableCell('$qty pcs'),
                    _buildTableCell(_formatCurrency(omset.toDouble()), isBold: true),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildTableCell(String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        value, 
        textAlign: value.length < 5 ? TextAlign.center : TextAlign.start,
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }
}
