import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RequestStockScreen extends StatefulWidget {
  const RequestStockScreen({super.key});

  @override
  State<RequestStockScreen> createState() => _RequestStockScreenState();
}

class _RequestStockScreenState extends State<RequestStockScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  final Map<String, TextEditingController> _requestControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchStockSummary();
  }

  @override
  void dispose() {
    for (var controller in _requestControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initControllers() {
    final shops = _data?['shops_detail'] as List? ?? [];
    if (shops.isNotEmpty) {
      final shop = shops.first;
      final requested = shop['requested_stock']?.toString() ?? '0';
      _requestControllers['0'] = TextEditingController(text: requested == '0' ? '' : requested);
      
      final products = shop['products'] as List? ?? [];
      for (var product in products) {
        final prodId = product['id'];
        final pRequested = product['requested_stock']?.toString() ?? '0';
        _requestControllers['$prodId'] = TextEditingController(text: pRequested == '0' ? '' : pRequested);
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
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat data: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final bodyStocks = <String, dynamic>{};
      
      final ctrl = _requestControllers['0'];
      bodyStocks['0'] = (ctrl != null && ctrl.text.isNotEmpty) ? int.tryParse(ctrl.text) ?? 0 : 0;
      
      final shops = _data?['shops_detail'] as List? ?? [];
      if (shops.isNotEmpty) {
        final shopData = shops.first;
        final products = shopData['products'] as List? ?? [];
        for (var product in products) {
          final pId = product['id'];
          final pCtrl = _requestControllers['$pId'];
          bodyStocks['$pId'] = (pCtrl != null && pCtrl.text.isNotEmpty) ? int.tryParse(pCtrl.text) ?? 0 : 0;
        }
      }

      final Map<String, dynamic> body = {
        'requested_stocks': bodyStocks,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/courier/request-stock'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengajuan stok berhasil dikirim!'), backgroundColor: Colors.green),
          );
        }
        _fetchStockSummary();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: ${response.statusCode}'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = _data?['shops_detail'] as List? ?? [];
    final hasData = shops.isNotEmpty;
    final shop = hasData ? shops.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Ajukan Stok', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchStockSummary),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
              ? const Center(child: Text('Gagal memuat data cabang.'))
              : RefreshIndicator(
                  onRefresh: _fetchStockSummary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront, color: Colors.blue),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      shop!['name'] ?? 'Cabang Anda',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 30),
                              
                              // Item Utama Dimsum
                              _buildProductRow(
                                title: shop['main_stock_name'] ?? 'Stok Utama',
                                stockVal: int.tryParse(shop['stock']?.toString() ?? '0') ?? 0,
                                minStockVal: int.tryParse(shop['min_stock']?.toString() ?? '100') ?? 100,
                                controllerKey: '0',
                                isDimsum: true,
                              ),
                              
                              // Item Non-Varian
                              if ((shop['products'] as List? ?? []).isNotEmpty) ...[
                                const SizedBox(height: 20),
                                const Divider(height: 1),
                                const SizedBox(height: 15),
                                Text(
                                  'Produk Non-Varian:',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800]),
                                ),
                                const SizedBox(height: 10),
                                ...((shop['products'] as List? ?? []).map((prod) {
                                  final pStock = int.tryParse(prod['stock']?.toString() ?? '0') ?? 0;
                                  return _buildProductRow(
                                    title: prod['name'] ?? 'Unknown',
                                    stockVal: pStock,
                                    minStockVal: 0,
                                    controllerKey: prod['id']?.toString() ?? '0',
                                    isSubItem: true,
                                  );
                                }).toList()),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _submitRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Kirim Pengajuan Stok',
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProductRow({
    required String title,
    required int stockVal,
    required int minStockVal,
    required String controllerKey,
    bool isDimsum = false,
    bool isSubItem = false,
  }) {
    final isLow = isDimsum && stockVal < minStockVal;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isSubItem ? 15 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: isSubItem ? 14 : 13,
                    fontWeight: isSubItem ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                Text(
                  '$stockVal butir',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: isSubItem ? 16 : 18,
                    color: isLow ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            height: 45,
            child: TextField(
              controller: _requestControllers[controllerKey],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Qty',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.orange[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.orange.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.orange.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
