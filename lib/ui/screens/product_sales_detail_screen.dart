import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/api_config.dart';

class ProductSalesDetailScreen extends StatelessWidget {
  final List<dynamic> productDetails;

  const ProductSalesDetailScreen({super.key, required this.productDetails});

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Detail Produk Terjual', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: productDetails.isEmpty
          ? const Center(child: Text('Tidak ada data penjualan produk.'))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: productDetails.length,
              itemBuilder: (context, index) {
                final item = productDetails[index];
                
                final name = item['name'] ?? '-';
                final qty = int.tryParse(item['total_qty']?.toString() ?? '0') ?? 0;
                final omset = double.tryParse(item['total_omset']?.toString() ?? '0') ?? 0;
                final image = item['image'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    title: Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text('Terjual: $qty porsi', style: GoogleFonts.outfit(color: Colors.blueGrey, fontSize: 13)),
                        Text('Omzet: ${_formatCurrency(omset)}', style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    trailing: image != null && image.toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              '${ApiConfig.baseUrl}/storage/products/$image',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
