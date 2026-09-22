import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_colors.dart';
import '../../services/product_service.dart';
import 'product_form_screen.dart';
import 'courier_dashboard_screen.dart';
import 'category_list_screen.dart';
import 'edit_stock_screen.dart';
import 'package:intl/intl.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService();
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  bool _isLoading = false; // Set false agar instan
  int? _selectedCategoryId;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool forceSync = false}) async {
    // 1. Ambil Lokal (Instan!)
    final localCats = await _productService.getCategories(sync: false);
    final localProds = await _productService.getProducts(
      categoryId: _selectedCategoryId,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      sync: false
    );
    
    if (mounted) {
      setState(() {
        _categories = localCats;
        _products = localProds;
        _isLoading = _products.isEmpty; // Tampilkan loading hanya jika cache kosong
      });
    }

    // 2. Sync Background
    if (_searchQuery.isEmpty || forceSync) {
      try {
        final freshCats = await _productService.getCategories(sync: true);
        final freshProds = await _productService.getProducts(
          categoryId: _selectedCategoryId,
          sync: true
        );
        
        if (mounted) {
          setState(() {
            _categories = freshCats;
            _products = freshProds;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _loadData();
    });
  }

  String _formatCurrency(dynamic value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).user?['role']?.toString().toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Data Produk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined, color: Colors.blue),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourierDashboardScreen())),
              tooltip: 'Distribusi Stok',
            ),
            // Tombol Edit Stok dinonaktifkan sementara (halamannya masih ada)
            // IconButton(
            //   icon: const Icon(Icons.edit_note_outlined, color: Colors.orange),
            //   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditStockScreen())),
            //   tooltip: 'Edit Stok Produk',
            // ),
            IconButton(
              icon: const Icon(Icons.category_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryListScreen())),
              tooltip: 'Kelola Kategori',
            ),
          ],
          IconButton(onPressed: () => _loadData(forceSync: true), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Search Bar dengan Debounce
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari produk dimsum...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          // Product List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty 
                  ? const Center(child: Text('Produk tidak ditemukan.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return _buildProductCard(product);
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
          if (result == true) _loadData(forceSync: true);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildCategoryChip(String label, int? id) {
    bool isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategoryId = id);
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : AppColors.text,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: product['image_url'] != null
                ? CachedNetworkImage(
                    imageUrl: product['image_url'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[100], child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.inventory_2_outlined, color: Colors.grey)),
                  )
                : const Center(child: Icon(Icons.inventory_2_outlined, color: Colors.grey)),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? '-', 
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatCurrency(double.tryParse(product['price'].toString())), 
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 11)
                ),

                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (product['parent_id'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                        child: const Text('VARIAN', style: TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    if (Provider.of<AuthProvider>(context, listen: false).user?['role']?.toString().toLowerCase() == 'admin')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          InkWell(
                            onTap: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)));
                              if (result == true) _loadData(forceSync: true);
                            },
                            child: const Icon(Icons.edit, color: Colors.blue, size: 14),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _confirmDelete(product),
                            child: const Icon(Icons.delete, color: Colors.red, size: 14),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(dynamic product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Produk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Anda yakin ingin menghapus ${product['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _productService.deleteProduct(product['id']);
              if (success) _loadData(forceSync: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
