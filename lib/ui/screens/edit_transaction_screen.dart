import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../services/database_helper.dart';
import '../../services/transaction_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class EditTransactionScreen extends StatefulWidget {
  final Map<String, dynamic> transactionData;
  const EditTransactionScreen({super.key, required this.transactionData});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final TransactionService _transactionService = TransactionService();
  final _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<Map<String, dynamic>> _cartItems = []; // Item-item yang sedang diedit
  List<Map<String, dynamic>> _allProducts = []; // Daftar semua produk dari SQLite
  List<Map<String, dynamic>> _originalItems = []; // Item asli sebelum edit (untuk rollback stok)

  bool _isLoading = true;
  bool _isSaving = false;

  // Controller untuk pembayaran
  final TextEditingController _payAmountController = TextEditingController();
  String _paymentMethod = 'tunai';

  // Tanggal transaksi
  DateTime _transactionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _payAmountController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final t = widget.transactionData;

    // Parse tanggal transaksi
    try {
      _transactionDate = DateTime.parse(t['created_at']).toLocal();
    } catch (_) {
      _transactionDate = DateTime.now();
    }

    // Parse item-item yang ada di transaksi
    dynamic rawItems = t['items'];
    List<dynamic> items = [];
    if (rawItems is String) {
      try { items = jsonDecode(rawItems); } catch (_) { items = []; }
    } else if (rawItems is List) {
      items = rawItems;
    }

    // Simpan item asli (sebelum edit) untuk digunakan saat rollback stok
    _originalItems = items.map((item) => Map<String, dynamic>.from(item)).toList();

    // Konversi ke format cart yang bisa diedit
    _cartItems = items.map((item) {
      return {
        'product_id': int.tryParse(item['product_id']?.toString() ?? '') ?? 0,
        'product_name': item['product_name'] ?? item['product']?['name'] ?? '-',
        'price': double.tryParse(item['price']?.toString() ?? '0') ?? 0,
        'quantity': int.tryParse(item['qty']?.toString() ?? item['quantity']?.toString() ?? '1') ?? 1,
      };
    }).toList();

    // Set nominal bayar dan metode pembayaran
    final payAmount = double.tryParse(
      (t['cash_received'] ?? t['pay_amount'] ?? '0').toString()
    ) ?? 0;
    _payAmountController.text = payAmount > 0 ? payAmount.toInt().toString() : '';
    
    String pm = (t['payment_method']?.toString() ?? 'tunai').toLowerCase();
    if (pm == 'cash') pm = 'tunai';
    _paymentMethod = pm;

    // Ambil semua produk dari SQLite
    final db = await DatabaseHelper.instance.database;
    final products = await db.query('products', where: "status = 'active'", orderBy: 'name ASC');
    
    setState(() {
      _allProducts = products.map((p) => Map<String, dynamic>.from(p)).toList();
      _isLoading = false;
    });
  }

  double get _totalPrice {
    double total = 0;
    for (var item in _cartItems) {
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      total += price * qty;
    }
    return total;
  }

  double get _payAmount {
    return double.tryParse(_payAmountController.text) ?? 0;
  }

  double get _changeAmount {
    final change = _payAmount - _totalPrice;
    return change > 0 ? change : 0;
  }

  void _addProduct(Map<String, dynamic> product) {
    setState(() {
      // Cek apakah produk sudah ada di cart
      final existingIndex = _cartItems.indexWhere(
        (item) => item['product_id'] == product['id']
      );

      if (existingIndex != -1) {
        _cartItems[existingIndex]['quantity'] = (_cartItems[existingIndex]['quantity'] as int) + 1;
      } else {
        _cartItems.add({
          'product_id': product['id'],
          'product_name': product['name'],
          'price': double.tryParse(product['price']?.toString() ?? '0') ?? 0,
          'quantity': 1,
        });
      }
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int newQty) {
    setState(() {
      if (newQty <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index]['quantity'] = newQty;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_transactionDate),
      );

      setState(() {
        if (pickedTime != null) {
          _transactionDate = DateTime(picked.year, picked.month, picked.day, pickedTime.hour, pickedTime.minute);
        } else {
          _transactionDate = DateTime(picked.year, picked.month, picked.day, _transactionDate.hour, _transactionDate.minute);
        }
      });
    }
  }

  void _showAddProductDialog() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filteredProducts = _allProducts.where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Tambah Produk', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    // Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari produk...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onChanged: (val) => setSheetState(() => searchQuery = val),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Product list
                    Expanded(
                      child: filteredProducts.isEmpty
                        ? const Center(child: Text('Tidak ada produk ditemukan'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filteredProducts.length,
                            itemBuilder: (ctx, index) {
                              final product = filteredProducts[index];
                              final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
                              final alreadyInCart = _cartItems.any((item) => item['product_id'] == product['id']);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Icon(Icons.fastfood, color: AppColors.primary, size: 20),
                                ),
                                title: Text(product['name'] ?? '-', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                                subtitle: Text(_currencyFormatter.format(price), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                trailing: alreadyInCart 
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : IconButton(
                                      icon: Icon(Icons.add_circle, color: AppColors.primary),
                                      onPressed: () {
                                        _addProduct(product);
                                        Navigator.pop(ctx);
                                      },
                                    ),
                              );
                            },
                          ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveTransaction() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 item produk'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_payAmount < _totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal bayar kurang dari total harga'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final t = widget.transactionData;

    // Tentukan localId, serverId, dan invoiceNumber
    final int localId = int.tryParse(t['id']?.toString() ?? '0') ?? 0;
    final int? serverId = t['server_id'] != null 
        ? int.tryParse(t['server_id'].toString()) 
        : (t['is_synced'] == 1 ? localId : null);
    final String invoiceNumber = t['invoice_number']?.toString() ?? '';

    // Format item untuk disimpan
    final List<Map<String, dynamic>> formattedItems = _cartItems.map((item) {
      return {
        'product_id': item['product_id'],
        'product_name': item['product_name'],
        'price': item['price'],
        'quantity': item['quantity'],
        'qty': item['quantity'],
        'subtotal': (double.tryParse(item['price']?.toString() ?? '0') ?? 0) * (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0),
      };
    }).toList();

    final updatedData = {
      'items': formattedItems,
      'total_price': _totalPrice,
      'pay_amount': _payAmount,
      'change_amount': _changeAmount,
      'payment_method': _paymentMethod,
      'created_at': _transactionDate.toIso8601String(),
      'status': t['status'] ?? 'completed',
    };

    final errorMessage = await _transactionService.updateTransaction(
      invoiceNumber: invoiceNumber,
      serverId: serverId,
      oldItems: _originalItems,
      updatedData: updatedData,
    );

    if (mounted) {
      setState(() => _isSaving = false);

      if (errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil diperbarui'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Return true agar parent bisa refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $errorMessage'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).user?['role']?.toString().toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Transaksi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveTransaction,
              icon: const Icon(Icons.save, size: 18),
              label: Text('Simpan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Invoice
                      _buildInfoCard(),
                      const SizedBox(height: 16),

                      // Tanggal Transaksi
                      _buildDatePicker(isAdmin),
                      const SizedBox(height: 16),

                      // Daftar Item
                      _buildItemsSection(isAdmin),
                      const SizedBox(height: 16),

                      // Nominal Bayar
                      _buildPaymentSection(),
                    ],
                  ),
                ),
              ),
              // Bottom Summary
              _buildBottomSummary(),
            ],
          ),
    );
  }

  Widget _buildInfoCard() {
    final t = widget.transactionData;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Invoice', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t['invoice_number'] ?? '-',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.store, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                t['shop']?['name'] ?? t['shop_name'] ?? '-',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(bool isAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: isAdmin ? _pickDate : null,
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tanggal Transaksi', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(_transactionDate),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (isAdmin) Icon(Icons.edit, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(bool isAdmin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Item Transaksi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
              if (isAdmin)
                TextButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                  label: Text('Tambah', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          if (_cartItems.isEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, color: Colors.grey[300], size: 48),
                  const SizedBox(height: 8),
                  Text('Belum ada item', style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 12),
            ...List.generate(_cartItems.length, (index) {
              final item = _cartItems[index];
              final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
              final qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
              final subtotal = price * qty;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    // Product info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name'] ?? '-',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_currencyFormatter.format(price)} × $qty = ${_currencyFormatter.format(subtotal)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    // Quantity controls
                    if (isAdmin)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQtyButton(
                            icon: Icons.remove,
                            color: Colors.red,
                            onTap: () => _updateQuantity(index, qty - 1),
                          ),
                          Container(
                            width: 36,
                            alignment: Alignment.center,
                            child: Text('$qty', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          _buildQtyButton(
                            icon: Icons.add,
                            color: AppColors.primary,
                            onTap: () => _updateQuantity(index, qty + 1),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _removeProduct(index),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
                            ),
                          ),
                        ],
                      )
                    else
                      Text('$qty x', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pembayaran', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: InputDecoration(
              labelText: 'Metode Pembayaran',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'tunai', child: Text('Tunai', style: TextStyle(fontWeight: FontWeight.bold))),
              DropdownMenuItem(value: 'qris', child: Text('QRIS', style: TextStyle(fontWeight: FontWeight.bold))),
              DropdownMenuItem(value: 'lainnya', child: Text('Lainnya', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            onChanged: (value) {
              setState(() {
                _paymentMethod = value!;
                if (_paymentMethod == 'qris') {
                  _payAmountController.text = _totalPrice.toInt().toString();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          if (_paymentMethod != 'qris') ...[
            TextField(
              controller: _payAmountController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nominal Bayar',
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kembalian:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              Text(
                _currencyFormatter.format(_changeAmount),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(
                    _currencyFormatter.format(_totalPrice),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                  ),
                  Text(
                    '${_cartItems.length} item',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTransaction,
              icon: _isSaving 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
