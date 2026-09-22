import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../services/shop_service.dart';

class ShopFormScreen extends StatefulWidget {
  final dynamic shop;
  const ShopFormScreen({super.key, this.shop});

  @override
  State<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends State<ShopFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ShopService _shopService = ShopService();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _sloganController;
  late TextEditingController _tiktokController;
  late TextEditingController _igController;
  late TextEditingController _fbController;
  late TextEditingController _webController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;

  bool _isMain = false;
  bool _isLoading = false;
  bool _isGettingLocation = false;
  File? _logoFile;
  dynamic _mainShop;
  final Map<String, bool> _syncedFields = {};

  bool get isEdit => widget.shop != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop?['name'] ?? '');
    _addressController = TextEditingController(text: widget.shop?['address'] ?? '');
    _phoneController = TextEditingController(text: widget.shop?['phone'] ?? '');
    _sloganController = TextEditingController(text: widget.shop?['slogan'] ?? '');
    _tiktokController = TextEditingController(text: widget.shop?['tiktok'] ?? '');
    _igController = TextEditingController(text: widget.shop?['instagram'] ?? '');
    _fbController = TextEditingController(text: widget.shop?['facebook'] ?? '');
    _webController = TextEditingController(text: widget.shop?['web'] ?? '');
    _latController = TextEditingController(text: widget.shop?['latitude'] ?? '');
    _lngController = TextEditingController(text: widget.shop?['longitude'] ?? '');
    _stockController = TextEditingController(text: widget.shop?['stock']?.toString() ?? '0');
    _minStockController = TextEditingController(text: widget.shop?['min_stock']?.toString() ?? '100');
    _isMain = widget.shop?['is_main'] == true;
    _loadMainShop();
  }

  Future<void> _loadMainShop() async {
    try {
      final shops = await _shopService.getShops();
      if (shops.isNotEmpty) {
        setState(() {
          final mainShops = shops.where((s) => s['is_main'] == true || s['is_main'] == 1).toList();
          _mainShop = mainShops.isNotEmpty ? mainShops.first : null;
          
          if (_mainShop != null && isEdit && widget.shop['id'] != _mainShop['id']) {
            if (_phoneController.text == _mainShop['phone'] && _phoneController.text.isNotEmpty) _syncedFields['phone'] = true;
            if (_sloganController.text == _mainShop['slogan'] && _sloganController.text.isNotEmpty) _syncedFields['slogan'] = true;
            if (_igController.text == _mainShop['instagram'] && _igController.text.isNotEmpty) _syncedFields['instagram'] = true;
            if (_tiktokController.text == _mainShop['tiktok'] && _tiktokController.text.isNotEmpty) _syncedFields['tiktok'] = true;
            if (_fbController.text == _mainShop['facebook'] && _fbController.text.isNotEmpty) _syncedFields['facebook'] = true;
            if (_webController.text == _mainShop['web'] && _webController.text.isNotEmpty) _syncedFields['web'] = true;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _logoFile = File(image.path));
    }
  }

  Future<void> _getCurrentLocation() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ambil Lokasi GPS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Aplikasi akan mengambil koordinat lokasi Anda saat ini melalui GPS. Lanjutkan?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: GoogleFonts.outfit(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Ya, Ambil Lokasi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isGettingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi berhasil diambil')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil lokasi: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final data = {
      'name': _nameController.text,
      'is_main': _isMain ? '1' : '0',
      'address': _addressController.text,
      'phone': _phoneController.text,
      'slogan': _sloganController.text,
      'tiktok': _tiktokController.text,
      'instagram': _igController.text,
      'facebook': _fbController.text,
      'web': _webController.text,
      'latitude': _latController.text,
      'longitude': _lngController.text,
      'stock': _stockController.text,
      'min_stock': _minStockController.text,
    };

    try {
      bool success = isEdit 
          ? await _shopService.updateShop(widget.shop['id'], data, logo: _logoFile)
          : await _shopService.createShop(data, logo: _logoFile);
      if (success) Navigator.pop(context, true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Cabang' : 'Tambah Cabang', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, foregroundColor: AppColors.text, elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // UI Logo Picker
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _logoFile != null 
                              ? FileImage(_logoFile!) 
                              : (widget.shop?['logo_url'] != null ? NetworkImage(widget.shop['logo_url']) : null) as ImageProvider?,
                            child: _logoFile == null && widget.shop?['logo_url'] == null 
                              ? Icon(Icons.store, size: 50, color: Colors.grey.shade400) 
                              : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: Text('Logo Cabang', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey))),
                    const SizedBox(height: 24),

                    // Switch Toko Pusat
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.amber),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Tandai sebagai Toko Pusat', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
                          Switch(
                            value: _isMain,
                            activeColor: Colors.amber,
                            onChanged: (v) => setState(() => _isMain = v),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('INFORMASI UTAMA'),
                    _buildField('Nama Toko / Cabang', _nameController, Icons.storefront),
                    _buildField('Alamat Lengkap', _addressController, Icons.location_on_outlined, maxLines: 2),
                    _buildField('No. Telepon', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone, mainKey: 'phone'),
                    _buildField('Stok Saat Ini (Butir)', _stockController, Icons.inventory_2_outlined, keyboardType: TextInputType.number),
                    _buildField('Minimal Stok (Peringatan Butir)', _minStockController, Icons.warning_amber_outlined, keyboardType: TextInputType.number),
                    _buildField('Slogan / Pesan Cabang', _sloganController, Icons.message_outlined, mainKey: 'slogan'),
                    
                    const SizedBox(height: 20),
                    _buildSectionHeader('SOSIAL MEDIA'),
                    _buildField('Instagram', _igController, Icons.camera_alt_outlined, mainKey: 'instagram'),
                    _buildField('TikTok', _tiktokController, Icons.video_collection_outlined, mainKey: 'tiktok'),
                    _buildField('Facebook', _fbController, Icons.facebook_outlined, mainKey: 'facebook'),
                    _buildField('Website Resmi', _webController, Icons.language, mainKey: 'web'),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('LOKASI GPS'),
                        TextButton.icon(
                          onPressed: _isGettingLocation ? null : _getCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 16),
                          label: Text(_isGettingLocation ? 'Menunggu...' : 'Ambil Titik Lokasi', style: GoogleFonts.outfit(fontSize: 12)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildField('Latitude', _latController, Icons.map_outlined)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField('Longitude', _lngController, Icons.map_outlined)),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: Text('SIMPAN DATA CABANG', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2, fontSize: 13)),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? mainKey}) {
    bool canSync = _mainShop != null && mainKey != null && (widget.shop == null || widget.shop['id'] != _mainShop['id']);
    bool isSynced = _syncedFields[mainKey] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
            if (canSync)
              Row(
                children: [
                  Text('Samakan pusat', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                  Checkbox(
                    value: isSynced,
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      setState(() {
                        _syncedFields[mainKey] = v!;
                        if (v) ctrl.text = _mainShop[mainKey]?.toString() ?? '';
                      });
                    },
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 1),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          readOnly: isSynced,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(fontSize: 14, color: isSynced ? Colors.grey : AppColors.text),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: isSynced ? Colors.grey : AppColors.primary, size: 20),
            filled: true, fillColor: isSynced ? Colors.grey.shade100 : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            hintText: 'Isi $label',
          ),
          validator: (v) => (label.contains('Nama') || label.contains('Alamat')) && v!.isEmpty ? 'Wajib diisi' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
