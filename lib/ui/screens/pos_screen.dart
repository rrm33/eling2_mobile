import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/cart_provider.dart';
import '../../core/app_colors.dart';
import '../../services/product_service.dart';
import '../../services/transaction_service.dart';
import '../../providers/auth_provider.dart';
import 'receipt_screen.dart';
import '../../services/sync_service.dart';

import 'package:http/http.dart' as http;
import '../../core/api_config.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductService _productService = ProductService();
  List<dynamic> _products = [];
  // Some screens keep categories for future use; silence unused-field analyzer for now
  // ignore: unused_field
  List<dynamic> _categories = [];
  bool _isLoading = false; 
  int? _selectedCategoryId;
  String _searchQuery = '';
  // Track per-product add-in-progress state so UI buttons can be disabled while addItem runs
  final Map<String, bool> _adding = {};

  Future<void> _receiveStock() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final planned = int.tryParse(auth.user?['shop']?['total_planned_stock']?.toString() ?? '0') ?? 0;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terima Kiriman Stok'),
        content: Text('Apakah Anda yakin ingin menerima kiriman $planned unit barang? Stok akan langsung ditambahkan ke sistem.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Terima', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = await auth.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.apiUrl}/shops/receive-stock'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
          await SyncService().syncAll(); // Sinkronkan data lokal ke HP agar stok produk non-varian terupdate
          await auth.checkAuth(); // Refresh profile to update stock UI
          _loadData(); // Muat ulang data SQLite lokal ke grid
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menerima stok.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    // Listen to cart changes to force UI rebuild so all product cards reflect realtime remaining stock
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    // Remove cart listener
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      cart.removeListener(_onCartChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadData() async {
    // 1. Ambil Lokal dulu (Instan!)
    final localProds = await _productService.getProducts(categoryId: _selectedCategoryId, sync: false);
    final localCats = await _productService.getCategories(sync: false);

    if (mounted) {
      setState(() {
        _products = localProds;
        _categories = localCats;
        _isLoading = _products.isEmpty; // Tampilkan loading hanya jika cache kosong
      });
    }

    // 2. Sync Background (Diam-diam cek ke server)
    try {
      // Refresh data User/Toko untuk mendapatkan stok terbaru dari DB Server
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuth();

      final freshCats = await _productService.getCategories(sync: true);
      final freshProds = await _productService.getProducts(categoryId: _selectedCategoryId, sync: true, search: _searchQuery);
      
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

  /// Reload data HANYA dari SQLite lokal (tanpa sync ke server)
  /// Digunakan setelah transaksi agar stok yang sudah dipotong di SQLite tidak tertimpa oleh data server.
  Future<void> _loadLocalOnly() async {
    final localProds = await _productService.getProducts(categoryId: _selectedCategoryId, sync: false, search: _searchQuery);
    if (mounted) {
      setState(() {
        _products = localProds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Kasir Dimsum', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) {
                _searchQuery = v;
                _loadData();
              },
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          // Indikator Stok Global Dihapus sesuai permintaan
          
          // Product Grid
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    // Wrap each card with Consumer so it rebuilds when cart changes
                    return Consumer<CartProvider>(
                      builder: (context, cartProvider, _) => _buildProductCard(p, cartProvider),
                    );
                  },
                 ),
          ),

          if (cart.totalItems > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${cart.totalItems} Item', style: const TextStyle(fontSize: 12)),
                      Text(
                        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(cart.totalAmount),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _showCartSheet(context, cart),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('LIHAT KERANJANG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildProductCard(dynamic p, CartProvider cart) {
    // Get global shop stock
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final int shopStock = int.tryParse(auth.user?['shop']?['stock']?.toString() ?? '0') ?? 0;
    // Determine if product is a dimsum variant (has bundle_qty > 0)
    final int bundleQty = int.tryParse(p['bundle_qty']?.toString() ?? '0') ?? 0;
    final bool isDimsum = bundleQty > 0;

    // Use CartProvider helper for realtime remaining stock (single source of truth)
    final int remainingStock = cart.getRemainingStock(p, shopStock);
    final bool canAdd = cart.canAddProduct(p, shopStock);

    final String pid = p['id']?.toString() ?? '';
    final bool isAdding = _adding[pid] == true;

    return GestureDetector(
      onTap: canAdd
          && !isAdding
          ? () async {
              // mark as adding to prevent double taps
              setState(() => _adding[pid] = true);
              try {
                bool success = await cart.addItem(p, shopStock);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stok tidak mencukupi!'), duration: Duration(seconds: 1)),
                  );
                }
              } finally {
                if (mounted) setState(() => _adding[pid] = false);
              }
            }
           : null,
       child: Container(
         decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(12),
         ),
         child: Stack(
           children: [
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Expanded(
                   child: ClipRRect(
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                     child: p['image_url'] != null
                         ? CachedNetworkImage(
                             imageUrl: p['image_url'],
                             width: double.infinity,
                             fit: BoxFit.cover,
                             placeholder: (context, url) => Container(
                               color: Colors.grey[100],
                               child: const Center(child: Icon(Icons.image, color: Colors.grey, size: 20)),
                             ),
                             errorWidget: (context, url, error) => const Icon(Icons.image_not_supported),
                           )
                         : const Center(child: Icon(Icons.fastfood, color: Colors.grey)),
                   ),
                 ),
                 Padding(
                   padding: const EdgeInsets.all(8),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(p['name'], style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
                       // Format price to remove trailing .0 and show localized currency
                       Text(
                         NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(
                           double.tryParse(p['price']?.toString() ?? '0') ?? 0,
                         ),
                         style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                       ),

                     ],
                   ),
                 ),
               ],
             ),
             // Show in-progress overlay when adding
             if (isAdding)
               Positioned.fill(
                 child: Container(
                   decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                   child: const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                 ),
               ),

           ],
         ),
       ),
     );
   }
// Legacy duplicate product card code removed




  void _showCartSheet(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CartContent(
        cart: cart, 
        products: _products, 
        isSheet: true,
        onSuccess: _loadLocalOnly,
      ),
    );
  }
}

class _CartContent extends StatefulWidget {
  final CartProvider cart;
  final List<dynamic> products;
  final bool isSheet;
  final VoidCallback? onSuccess;

  const _CartContent({
    required this.cart, 
    required this.products, 
    this.isSheet = false,
    this.onSuccess,
  });

  @override
  State<_CartContent> createState() => _CartContentState();
}

class _CartContentState extends State<_CartContent> {
  late TextEditingController _payController;
  double _change = 0;
  bool _isProcessing = false;
  final TransactionService _transactionService = TransactionService();
  String _paymentMethod = 'qris';

  // Track add-in-progress state for items inside the cart sheet
  final Map<int, bool> _addingInSheet = {};

  @override
  void initState() {
    super.initState();
    _payController = TextEditingController(text: widget.cart.totalAmount.toInt().toString());
    _calculateChange();
    _payController.addListener(_calculateChange);
  }

  void _calculateChange() {
    if (!mounted) return;
    final pay = double.tryParse(_payController.text) ?? 0;
    setState(() {
      _change = pay - widget.cart.totalAmount;
    });
  }

  void _updatePayAmount() {
    setState(() {
      _payController.text = widget.cart.totalAmount.toInt().toString();
    });
  }

  Future<void> _processTransaction() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);

    try {
      final pay = double.tryParse(_payController.text) ?? 0;
      final res = await _transactionService.storeTransaction({
         'items': widget.cart.items.values.map((e) => {
           'product_id': e.productId, 
           'name': e.name, 
           'price': e.price, 
           'quantity': e.quantity, 
           'bundle_qty': e.bundleQty,
           'subtotal': e.subtotal
         }).toList(),
         'total_price': widget.cart.totalAmount,
         'pay_amount': pay,
         'change_amount': _paymentMethod == 'qris' ? 0.0 : _change,
         'payment_method': _paymentMethod,
       });

      if (res != null && mounted) {
        // If server returned an error map, do not clear cart or show receipt.
        if (res['error'] != null) {
          final String msg = res['error']?.toString() ?? 'Transaksi gagal di server';
          // Refresh local stock/UI because TransactionService already rolled back local DB when rejecting
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.checkAuth();
          if (widget.onSuccess != null) widget.onSuccess!();

          // Show modal bottom sheet with error details and allow retry
          final result = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            builder: (ctx) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Transaksi Gagal', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('TUTUP'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            onPressed: () => Navigator.pop(ctx, 'retry'),
                            child: const Text('COBA LAGI', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );

          // After modal closes: if user chose retry, allow a new attempt
          if (result == 'retry') {
            if (mounted) setState(() => _isProcessing = false);
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) await _processTransaction();
            return;
          }

          // otherwise just return
          return;
        }

        // Success (or offline save) -> proceed to finalize: deduct dimsum from auth, clear cart and show receipt
        int dimsumDeduction = 0;
        for (var item in widget.cart.items.values) {
          final found = widget.products.where((prod) => prod['id'] == item.productId).toList();
          final p = found.isNotEmpty ? found.first : null;
          if (p != null) {
            int bQty = int.tryParse(p['bundle_qty']?.toString() ?? '0') ?? 0;
            if (bQty > 0) {
              dimsumDeduction += (item.quantity * bQty);
            }
          }
        }

        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (dimsumDeduction > 0) {
          auth.reduceStock(dimsumDeduction);
        }
        await auth.checkAuth();

        widget.cart.clear();
        if (widget.isSheet) Navigator.pop(context);
        if (widget.onSuccess != null) widget.onSuccess!();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReceiptScreen(transactionData: res, isNewTransaction: true)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _payController.dispose();
    super.dispose();
  }

  void _confirmTransaction() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Transaksi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Apakah pesanan dan uang pembayaran pelanggan sudah sesuai?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Periksa Lagi', style: TextStyle(color: Colors.black54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.pop(ctx);
              _processTransaction();
            },
            child: const Text('Ya, Selesaikan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double value, {bool isBold = false, Color? color}) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(formatter.format(value), style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: color ?? (isBold ? AppColors.primary : Colors.black),
          fontSize: isBold ? 16 : 14,
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: widget.isSheet ? MediaQuery.of(context).viewInsets.bottom : 20,
        left: 20, right: 20, top: 20
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Keranjang Belanja', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...widget.cart.items.values.map((item) {
               final foundProducts = widget.products.where((p) => p['id'] == item.productId).toList();
               final product = foundProducts.isNotEmpty ? foundProducts.first : null;
               final auth = Provider.of<AuthProvider>(context, listen: false);
               final int shopStock = int.tryParse(auth.user?['shop']?['stock']?.toString() ?? '0') ?? 0;

               final bool addingInSheet = _addingInSheet[item.productId] == true;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Rp ${item.price.toInt()} x ${item.quantity}', style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 24),
                      onPressed: () {
                        // Hapus 1 unit dari cart
                        widget.cart.removeOneItem(item.productId);
                        _updatePayAmount();
                        _calculateChange();
                      },
                    ),
                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    // Add button: show spinner while adding
                    IconButton(
                      icon: addingInSheet
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_circle_outline, color: Colors.green, size: 24),
                      onPressed: addingInSheet
                          ? null
                          : () async {
                              if (product == null) return;
                              final bool can = widget.cart.canAddProduct(product, shopStock);
                              if (!can) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak mencukupi!'), duration: Duration(seconds: 1)));
                                return;
                              }
                              setState(() => _addingInSheet[item.productId] = true);
                              try {
                                bool success = await widget.cart.addItem(product, shopStock);
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak mencukupi!'), duration: Duration(seconds: 1)));
                                } else {
                                  _updatePayAmount();
                                  _calculateChange();
                                }
                              } finally {
                                if (mounted) setState(() => _addingInSheet[item.productId] = false);
                              }
                            },
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(),
            _buildPriceRow('Total Belanja', widget.cart.totalAmount, isBold: true),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _paymentMethod == 'cash' ? 'tunai' : _paymentMethod,
              decoration: InputDecoration(
                labelText: 'Metode Pembayaran',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: const [
                DropdownMenuItem(value: 'tunai', child: Text('Tunai', style: TextStyle(fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'qris', child: Text('QRIS', style: TextStyle(fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: 'lainnya', child: Text('Lainnya', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              onChanged: (value) {
                setState(() {
                  _paymentMethod = value!;
                  // Isi otomatis nilai pembayaran sesuai total
                  _payController.text = widget.cart.totalAmount.toInt().toString();
                });
                _calculateChange();
              },
            ),
            const SizedBox(height: 15),
            if (_paymentMethod == 'tunai' || _paymentMethod == 'lainnya' || _paymentMethod == 'cash') ...[
              TextField(
                controller: _payController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Uang Pembayaran',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (_) => _calculateChange(),
              ),
              const SizedBox(height: 10),
              _buildPriceRow('Kembalian', _change, color: _change < 0 ? Colors.red : Colors.green),
            ] else if (_paymentMethod == 'qris') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: Colors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pilih metode QRIS. Pastikan pelanggan membayar lunas sejumlah Total Belanja sebelum menyelesaikan transaksi.',
                        style: GoogleFonts.outfit(color: Colors.purple, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isProcessing || _change < 0 || widget.cart.totalItems == 0) ? null : _confirmTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SELESAIKAN TRANSAKSI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
