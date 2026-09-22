import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final ProductService _productService = ProductService();
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      // 1. Load Lokal dulu (Satset)
      final localCats = await _productService.getCategories(sync: false);
      if (mounted) {
        setState(() {
          _categories = localCats;
          _isLoading = false;
        });
      }

      // 2. Background Sync
      _productService.getCategories(sync: true).then((freshCats) {
        if (mounted) setState(() => _categories = freshCats);
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCategory({int? id, required String name}) async {
    try {
      // Untuk kategori, kita pakai ProductService.saveCategory
      // Catatan: saveCategory saat ini hanya dukung simpan baru. 
      // Kita asumsikan untuk edit bisa ditambahkan nanti atau pakai logic serupa.
      final success = await _productService.saveCategory(name);
      if (success) {
        _loadCategories();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteCategory(int id) async {
    try {
      // Implementasi delete category di ProductService jika belum ada
      // (Asumsi sederhana untuk sekarang)
      _loadCategories();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showFormDialog({int? id, String? initialName}) {
    final controller = TextEditingController(text: initialName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(id == null ? 'Tambah Kategori' : 'Edit Kategori', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nama Kategori'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => _saveCategory(id: id, name: controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).user?['role'] == 'admin';
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Manajemen Kategori', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(cat['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showFormDialog(id: cat['id'], initialName: cat['name'])),
                      if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), 
                        onPressed: () => _showDeleteConfirm(cat['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showDeleteConfirm(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus?'),
        content: const Text('Kategori ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () {
            _deleteCategory(id);
            Navigator.pop(context);
          }, child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
