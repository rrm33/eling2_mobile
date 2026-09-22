import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../services/product_service.dart';
import 'dart:convert';

class ProductFormScreen extends StatefulWidget {
  final dynamic product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _bundleQtyController;
  late TextEditingController _stockController;

  bool _isDimSum = true;
  File? _imageFile;
  bool _isLoading = false;
  bool _status = true;
  int? _defaultCategoryId;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?['name'] ?? '');
    _descController = TextEditingController(text: widget.product?['description'] ?? '');
    _priceController = TextEditingController(text: widget.product?['price']?.toString() ?? '');
    _bundleQtyController = TextEditingController(text: widget.product?['bundle_qty']?.toString() ?? '1');
    _stockController = TextEditingController(text: widget.product?['stock']?.toString() ?? '0');
    
    final bundleQtyVal = int.tryParse(widget.product?['bundle_qty']?.toString() ?? '0') ?? 0;
    _isDimSum = bundleQtyVal > 0;

    if (widget.product != null) {
      final s = widget.product!['status'];
      _status = s == 1 || s == '1' || s == true;
    } else {
      _status = true;
    }

    _loadDefaultCategory();
  }

  Future<void> _loadDefaultCategory() async {
    try {
      final cats = await _productService.getCategories(sync: false);
      if (cats.isNotEmpty) {
        // Saat edit: gunakan category_id dari produk. Saat tambah baru: pakai kategori pertama
        if (isEdit && widget.product!['category_id'] != null) {
          setState(() => _defaultCategoryId = int.tryParse(widget.product!['category_id'].toString()));
        } else {
          setState(() => _defaultCategoryId = int.tryParse(cats.first['id'].toString()));
        }
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _showToast(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    final data = {
      'category_id': _defaultCategoryId?.toString() ?? '1',
      'name': _nameController.text,
      'description': _descController.text,
      'price': _priceController.text,
      'cost_price': '0',
      'status': _status ? '1' : '0',
      'parent_id': '', // dikosongkan, di-handle di service
      'min_stock': '10',
      'stock': _isDimSum ? '0' : _stockController.text,
      'bundle_qty': _isDimSum ? _bundleQtyController.text : '0',
    };

    try {
      final errorMsg = await _productService.saveProduct(data, _imageFile, id: widget.product?['id']);
      if (errorMsg == null && mounted) {
        _showToast('Produk berhasil disimpan', isError: false);
        Navigator.pop(context, true);
      } else if (mounted) {
        _showToast(errorMsg ?? 'Gagal simpan ke server.');
      }
    } catch (e) {
      _showToast('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildField('Nama Produk', _nameController, Icons.fastfood_outlined),
                    _buildField('Harga Jual (Porsi)', _priceController, Icons.payments_outlined, keyboardType: TextInputType.number),
                    SwitchListTile(
                      title: Text('Varian Dimsum', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      value: _isDimSum,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _isDimSum = v),
                    ),
                    const SizedBox(height: 12),
                    _isDimSum
                        ? _buildField('Jumlah Isi (Berapa butir per porsi)', _bundleQtyController, Icons.numbers, keyboardType: TextInputType.number)
                        : _buildField('Stok Barang', _stockController, Icons.inventory, keyboardType: TextInputType.number),
                    _buildField('Deskripsi (Opsional)', _descController, Icons.description_outlined, maxLines: 2, isRequired: false),
                    
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Produk Aktif / Tersedia', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      value: _status,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('SIMPAN PRODUK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            validator: (v) => isRequired && (v == null || v.isEmpty) ? 'Wajib diisi' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
        child: _imageFile != null
            ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_imageFile!, fit: BoxFit.cover))
            : isEdit && widget.product['image_url'] != null
                ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(widget.product['image_url'], fit: BoxFit.cover))
                : const Center(child: Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey)),
      ),
    );
  }
}
