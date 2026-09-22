import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_colors.dart';
import '../../services/sync_service.dart';

class EditStockScreen extends StatefulWidget {
  final int? initialShopId;
  const EditStockScreen({super.key, this.initialShopId});

  @override
  State<EditStockScreen> createState() => _EditStockScreenState();
}

class _EditStockScreenState extends State<EditStockScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  int? _selectedShopId;
  final Map<String, TextEditingController> _stockControllers = {};

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.initialShopId;
    _fetchStockSummary();
  }

  @override
  void dispose() {
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initControllers() {
    _stockControllers.clear();
    final shops = _data?['shops_detail'] as List? ?? [];
    if (shops.isNotEmpty) {
      // Jika belum ada cabang yang dipilih, pilih yang pertama
      _selectedShopId ??= shops.first['id'];
      
      final shop = shops.firstWhere((s) => s['id'] == _selectedShopId, orElse: () => shops.first);
      _selectedShopId = shop['id'];

      final stock = shop['stock']?.toString() ?? '0';
      _stockControllers['0'] = TextEditingController(text: stock);
      
      final products = shop['products'] as List? ?? [];
      for (var product in products) {
        final prodId = product['id'];
        final pStock = product['stock']?.toString() ?? '0';
        _stockControllers['$prodId'] = TextEditingController(text: pStock);
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

  Future<void> _submitStocks() async {
    if (_selectedShopId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final bodyStocks = <String, dynamic>{};
      
      // Ambil stock utama
      final ctrl = _stockControllers['0'];
      bodyStocks['0'] = (ctrl != null && ctrl.text.isNotEmpty) ? int.tryParse(ctrl.text) ?? 0 : 0;
      
      // Ambil stock produk non-varian
      final shops = _data?['shops_detail'] as List? ?? [];
      final shopData = shops.firstWhere((s) => s['id'] == _selectedShopId, orElse: () => null);
      if (shopData != null) {
        final products = shopData['products'] as List? ?? [];
        for (var product in products) {
          final pId = product['id'];
          final pCtrl = _stockControllers['$pId'];
          bodyStocks['$pId'] = (pCtrl != null && pCtrl.text.isNotEmpty) ? int.tryParse(pCtrl.text) ?? 0 : 0;
        }
      }

      final Map<String, dynamic> body = {
        'stocks': bodyStocks,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/shops/update-branch-stocks/$_selectedShopId'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stok cabang berhasil diperbarui!'), backgroundColor: Colors.green),
          );
        }
        
        // Trigger sinkronisasi lokal instan agar POS terupdate dengan stok baru
        try {
          await SyncService().syncAll();
        } catch (e) {
          print("Lokal sync failed: $e");
        }

        _fetchStockSummary();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan: ${response.statusCode}'), backgroundColor: Colors.red),
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

  void _adjustStockValue(String key, int amount) {
    final ctrl = _stockControllers[key];
    if (ctrl != null) {
      final current = int.tryParse(ctrl.text) ?? 0;
      final newVal = current + amount;
      if (newVal >= 0) {
        setState(() {
          ctrl.text = newVal.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = _data?['shops_detail'] as List? ?? [];
    final shop = _selectedShopId != null 
        ? shops.firstWhere((s) => s['id'] == _selectedShopId, orElse: () => shops.isNotEmpty ? shops.first : null)
        : (shops.isNotEmpty ? shops.first : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Stok Cabang', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchStockSummary),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : shops.isEmpty
              ? const Center(child: Text('Tidak ada data cabang.'))
              : RefreshIndicator(
                  onRefresh: _fetchStockSummary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dropdown Pilihan Cabang
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedShopId,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue),
                              style: GoogleFonts.outfit(
                                color: AppColors.text,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              items: shops.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s['id'],
                                  child: Text(s['name'] ?? 'Cabang'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedShopId = val;
                                    _initControllers();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form input stok
                        if (shop != null)
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
                                    const Icon(Icons.inventory_2_outlined, color: Colors.blue),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Data Stok - ${shop['name']}',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 30),
                                
                                // Item Utama Dimsum
                                _buildStockRow(
                                  title: shop['main_stock_name'] ?? 'Stok Utama',
                                  controllerKey: '0',
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
                                  const SizedBox(height: 15),
                                  ...((shop['products'] as List? ?? []).map((prod) {
                                    return _buildStockRow(
                                      title: prod['name'] ?? 'Unknown',
                                      controllerKey: prod['id']?.toString() ?? '0',
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
                            onPressed: _submitStocks,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Simpan Perubahan Stok',
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

  Widget _buildStockRow({
    required String title,
    required String controllerKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tombol Minus
              GestureDetector(
                onTap: () => _adjustStockValue(controllerKey, -10),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('-10', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _adjustStockValue(controllerKey, -1),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.remove, color: Colors.blue, size: 16),
                  ),
                ),
              ),
              
              // Input Field
              Container(
                width: 70,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _stockControllers[controllerKey],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                  ),
                ),
              ),
              
              // Tombol Plus
              GestureDetector(
                onTap: () => _adjustStockValue(controllerKey, 1),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.add, color: Colors.blue, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _adjustStockValue(controllerKey, 10),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('+10', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
