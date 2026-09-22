import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/api_config.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';

class RawMaterialPerShopScreen extends StatefulWidget {
  final String? startDate;
  final String? endDate;
  final String? shopId; // if non-null, will filter to single shop

  const RawMaterialPerShopScreen({Key? key, this.startDate, this.endDate, this.shopId}) : super(key: key);

  @override
  State<RawMaterialPerShopScreen> createState() => _RawMaterialPerShopScreenState();
}

class _RawMaterialPerShopScreenState extends State<RawMaterialPerShopScreen> {
  bool _isLoading = true;
  Map<String, int> _usageByShop = {};
  String _dateFilter = 'Hari Ini';
  final List<String> _filterOptions = ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini', 'Custom', 'Semua Waktu'];
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = 'Custom';
      });
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();

      // determine date range based on filter
      DateTime now = DateTime.now();
      String? startDate;
      String? endDate;
      if (_dateFilter == 'Hari Ini') {
        startDate = DateFormat('yyyy-MM-dd').format(now);
        endDate = startDate;
      } else if (_dateFilter == '7 Hari Terakhir') {
        startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
        endDate = DateFormat('yyyy-MM-dd').format(now);
      } else if (_dateFilter == 'Bulan Ini') {
        startDate = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
        endDate = DateFormat('yyyy-MM-dd').format(now);
      } else if (_dateFilter == 'Custom' && _customDateRange != null) {
        startDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.start);
        endDate = DateFormat('yyyy-MM-dd').format(_customDateRange!.end);
      }

      String url = '${ApiConfig.apiUrl}/transactions?';
      if (startDate != null) url += 'start_date=$startDate&';
      if (endDate != null) url += 'end_date=$endDate&';
      if (widget.shopId != null) url += 'shop_id=${widget.shopId}&';

      final res = await http.get(Uri.parse(url), headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List<dynamic> list = body is Map && body.containsKey('data') ? body['data'] : (body as List);

        final Map<String, int> agg = {};
        for (var t in list) {
          final shopName = t['shop']?['name'] ?? 'Pusat/Unknown';
          if (t['items'] == null) continue;
          int shopTotal = agg[shopName] ?? 0;
          for (var item in t['items']) {
            final qty = int.tryParse(item['qty']?.toString() ?? '0') ?? 0;
            final bQty = int.tryParse(item['product']?['bundle_qty']?.toString() ?? '1') ?? 1;
            shopTotal += qty * bQty;
          }
          agg[shopName] = shopTotal;
        }

        setState(() {
          _usageByShop = agg;
        });
      }
    } catch (e) {
      debugPrint('Error loading raw material usage: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNumber(int v) => NumberFormat.decimalPattern('id_ID').format(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pemakaian Bahan Baku per Cabang', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      backgroundColor: AppColors.background,
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
                    onTap: () async {
                      if (filter == 'Custom') {
                        await _selectCustomDateRange();
                      } else {
                        setState(() => _dateFilter = filter);
                        await _loadData();
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
                        filter == 'Custom' && _customDateRange != null && isSelected
                          ? '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}'
                          : filter,
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
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: _usageByShop.isEmpty
                    ? Center(child: Text('Tidak ada data', style: GoogleFonts.outfit(color: Colors.grey)))
                    : ListView(
                        children: _usageByShop.entries.map((e) {
                          return Card(
                            child: ListTile(
                              title: Text(e.key, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              trailing: Text('${_formatNumber(e.value)} butir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          );
                        }).toList(),
                      ),
                ),
          ),
        ],
      ),
    );
  }
}
