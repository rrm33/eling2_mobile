import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/user_service.dart';

class UserFormScreen extends StatefulWidget {
  final dynamic user;
  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = 'cashier';
  int? _selectedShopId;
  List<dynamic> _shops = [];
  bool _isLoading = false;

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _loadShops();
    if (isEdit) {
      _nameController.text = widget.user['name'] ?? '';
      _emailController.text = widget.user['email'] ?? '';
      _role = widget.user['role'] ?? 'cashier';
      _selectedShopId = int.tryParse(widget.user['shop_id']?.toString() ?? '');
    }
  }

  Future<void> _loadShops() async {
    try {
      final shops = await _userService.getShops();
      setState(() => _shops = shops);
    } catch (e) {
      print('Gagal memuat toko: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final data = {
      'name': _nameController.text,
      'email': _emailController.text,
      'role': _role,
      'shop_id': _role == 'cashier' ? _selectedShopId : null,
    };
    if (_passwordController.text.isNotEmpty) {
      data['password'] = _passwordController.text;
    }

    try {
      bool success;
      if (isEdit) {
        success = await _userService.updateUser(widget.user['id'], data);
      } else {
        success = await _userService.createUser(data);
      }

      if (success) {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User berhasil ${isEdit ? 'diperbarui' : 'dibuat'}'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Staff' : 'Tambah Staff', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Nama Lengkap'),
                  TextFormField(
                    controller: _nameController,
                    decoration: _buildInputDecoration('Masukkan nama staff', Icons.person_outline),
                    validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Email'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration('Masukkan email', Icons.email_outlined),
                    validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Password ${isEdit ? '(Kosongkan jika tidak ganti)' : ''}'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _buildInputDecoration('Minimal 8 karakter', Icons.lock_outline),
                    validator: (v) => (!isEdit && v!.isEmpty) ? 'Password wajib diisi' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Peran (Role)'),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: _buildInputDecoration('Pilih role', Icons.admin_panel_settings_outlined),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin (Owner)')),
                      DropdownMenuItem(value: 'cashier', child: Text('Kasir (Toko)')),
                      DropdownMenuItem(value: 'kurir', child: Text('Kurir (Distribusi)')),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                  const SizedBox(height: 20),

                  if (_role == 'cashier') ...[
                    _buildLabel('Cabang / Toko'),
                    DropdownButtonFormField<int>(
                      value: _selectedShopId,
                      decoration: _buildInputDecoration('Pilih cabang', Icons.storefront),
                      items: _shops.map((s) => DropdownMenuItem<int>(
                        value: s['id'],
                        child: Text(s['name'] ?? '-'),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedShopId = v),
                      validator: (v) => (_role == 'cashier' && v == null) ? 'Pilih cabang' : null,
                    ),
                    const SizedBox(height: 30),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text(isEdit ? 'SIMPAN PERUBAHAN' : 'TAMBAH STAFF', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.text)),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppColors.primary, width: 1)),
    );
  }
}
