import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/sync_service.dart';
import 'edit_stock_screen.dart';

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key});

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  bool _isAdmin = false;
  final Map<String, TextEditingController> _planControllers = {};

  @override
  void initState() {
    super.initState();
    _isAdmin = Provider.of<AuthProvider>(context, listen: false).user?['role'] == 'admin';
    _fetchStockSummary();
  }

  void _initControllers() {
    final shops = _data?['shops_detail'] as List? ?? [];
    for (var shop in shops) {
      final shopId = shop['id'];
      final planned = shop['planned_stock']?.toString() ?? '0';
      _planControllers['${shopId}_0'] = TextEditingController(text: planned == '0' ? '' : planned);
      
      final products = shop['products'] as List? ?? [];
      for (var product in products) {
        final prodId = product['id'];
        final pPlanned = product['planned_stock']?.toString() ?? '0';
        _planControllers['${shopId}_${prodId}'] = TextEditingController(text: pPlanned == '0' ? '' : pPlanned);
      }
    }
  }

  Future<void> _fetchStockSummary() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/courier/stock-summary'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _data = jsonDecode(response.body);
            _isLoading = false;
          });
          _initControllers();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlan(int shopId) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final bodyStocks = <String, dynamic>{};
      
      final ctrl = _planControllers['${shopId}_0'];
      bodyStocks['0'] = (ctrl != null && ctrl.text.isNotEmpty) ? int.tryParse(ctrl.text) ?? 0 : 0;
      
      // Ambil shop data
      final shops = _data?['shops_detail'] as List? ?? [];
      final shopData = shops.firstWhere((s) => s['id'] == shopId, orElse: () => null);
      if (shopData != null) {
        final products = shopData['products'] as List? ?? [];
        for (var product in products) {
          final pId = product['id'];
          final pCtrl = _planControllers['${shopId}_${pId}'];
          bodyStocks['$pId'] = (pCtrl != null && pCtrl.text.isNotEmpty) ? int.tryParse(pCtrl.text) ?? 0 : 0;
        }
      }

      final Map<String, dynamic> body = {
        'planned_stocks': bodyStocks,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/courier/plan-delivery/$shopId'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rencana disimpan!'), backgroundColor: Colors.green));
        _fetchStockSummary();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${response.statusCode}'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearRequest(int shopId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengajuan'),
        content: const Text('Apakah Anda yakin ingin menghapus semua ajuan stok dari cabang ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/courier/clear-request/$shopId'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan stok berhasil dihapus!'), backgroundColor: Colors.green));
        _fetchStockSummary();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${response.statusCode}'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeDelivery(int shopId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Tandai pengiriman selesai untuk cabang ini? Stok cabang akan diisi ulang otomatis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Selesai', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();

      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/courier/complete-delivery/$shopId'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengiriman selesai!'), backgroundColor: Colors.green));
        
        // Triger sinkronisasi lokal instan agar POS terupdate dengan stok baru
        try {
          await SyncService().syncAll();
        } catch (e) {
          print("Lokal sync failed: $e");
        }

        _fetchStockSummary();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${response.statusCode}'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isAdmin ? 'Distribusi Stok' : 'Penerimaan Stok', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchStockSummary),
          if (!_isAdmin)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Konfirmasi Logout'),
                    content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Logout', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStockSummary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildSummaryCard(
                          'Total Barang Dikirim',
                          _data?['summary']?['total_items_to_prepare']?.toString() ?? '0',
                          Icons.local_shipping,
                          Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text('Status Distribusi Cabang:', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildShopsDetail(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 5),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildShopsDetail() {
    final shops = _data?['shops_detail'] as List? ?? [];
    if (shops.isEmpty) return const Center(child: Text('Tidak ada data cabang.'));

    return Column(
      children: shops.map((shop) {
        final stockVal = int.tryParse(shop['stock']?.toString() ?? '0') ?? 0;
        final plannedVal = int.tryParse(shop['planned_stock']?.toString() ?? '0') ?? 0;
        final minStockVal = int.tryParse(shop['min_stock']?.toString() ?? '100') ?? 100;
        final isLowStock = stockVal < minStockVal;

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isLowStock ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.storefront, color: isLowStock ? Colors.red : Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(shop['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  if (isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                      child: const Text('KRITIS', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  if (_isAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.orange),
                      tooltip: 'Edit Stok Fisik Cabang',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditStockScreen(initialShopId: shop['id']),
                          ),
                        ).then((_) => _fetchStockSummary());
                      },
                    ),
                ],
              ),
              const Divider(height: 30),
              
              // Item Utama
              _buildProductRow(
                title: shop['main_stock_name'] ?? 'Stok Utama',
                stockVal: stockVal,
                plannedVal: plannedVal,
                requestedVal: int.tryParse(shop['requested_stock']?.toString() ?? '0') ?? 0,
                isLowStock: isLowStock,
                controllerKey: '${shop['id']}_0',
                shopId: shop['id'],
              ),

              // Item Non-Varian
              if ((shop['products'] as List? ?? []).isNotEmpty) ...[
                const SizedBox(height: 15),
                const Divider(height: 1),
                const SizedBox(height: 15),
                Text('Produk Non-Varian:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                ...((shop['products'] as List? ?? []).map((prod) {
                  final pStock = int.tryParse(prod['stock']?.toString() ?? '0') ?? 0;
                  final pPlanned = int.tryParse(prod['planned_stock']?.toString() ?? '0') ?? 0;
                  final pRequested = int.tryParse(prod['requested_stock']?.toString() ?? '0') ?? 0;
                  return _buildProductRow(
                    title: prod['name'] ?? 'Unknown',
                    stockVal: pStock,
                    plannedVal: pPlanned,
                    requestedVal: pRequested,
                    isLowStock: false,
                    controllerKey: '${shop['id']}_${prod['id']}',
                    shopId: shop['id'],
                    isSubItem: true,
                  );
                }).toList()),
              ],

              const SizedBox(height: 15),
              if (_isAdmin)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _clearRequest(shop['id']),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Hapus Ajuan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: () => _savePlan(shop['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Simpan Rencana', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                )
              else
                Builder(
                  builder: (context) {
                    final int plannedVal = int.tryParse(shop['planned_stock']?.toString() ?? '0') ?? 0;
                    final products = shop['products'] as List? ?? [];
                    final hasPlannedProducts = products.any((prod) => (int.tryParse(prod['planned_stock']?.toString() ?? '0') ?? 0) > 0);
                    final canReceive = plannedVal > 0 || hasPlannedProducts;

                    if (canReceive) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _completeDelivery(shop['id']),
                          icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                          label: const Text('Terima Barang', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      );
                    } else {
                      return const SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Belum ada kiriman barang untuk diterima.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductRow({
    required String title,
    required int stockVal,
    required int plannedVal,
    required int requestedVal,
    required bool isLowStock,
    required String controllerKey,
    required int shopId,
    bool isSubItem = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSubItem ? 10 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[700], fontSize: isSubItem ? 13 : 12, fontWeight: isSubItem ? FontWeight.w500 : FontWeight.normal)),
                Text('$stockVal butir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: isSubItem ? 15 : 18, color: isLowStock ? Colors.red : Colors.black)),
              ],
            ),
          ),
          if (_isAdmin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (requestedVal > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Text(
                      'Ajuan: $requestedVal',
                      style: GoogleFonts.outfit(color: Colors.orange[800], fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                SizedBox(
                  width: 80,
                  height: 40,
                  child: TextField(
                    controller: _planControllers[controllerKey],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Qty',
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: Colors.blue[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Barang Dikirim', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                Text('$plannedVal', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
              ],
            ),
        ],
      ),
    );
  }
}
