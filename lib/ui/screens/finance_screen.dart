import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/finance_service.dart';
import '../../services/sync_service.dart';

class FinanceScreen extends StatefulWidget {
  final String type; // 'income' or 'expense'
  const FinanceScreen({super.key, required this.type});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceService _financeService = FinanceService();
  final SyncService _syncService = SyncService(); // Tambahkan ini
  final _formKey = GlobalKey<FormState>();
  late Future<List<dynamic>> _futureFinances;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    // Inisialisasi awal secara INSTAN agar build tidak error
    _futureFinances = _financeService.getFinances(type: widget.type);
    
    // Jalankan sinkronisasi di latar belakang
    _refresh();
  }

  Future<void> _refresh() async {
    // 1. Sinkronisasi (Mungkin butuh waktu beberapa detik)
    await _syncService.syncAll();
    
    // 2. Setelah sinkron selesai, tarik data terbaru ke tampilan
    if (mounted) {
      setState(() {
        _futureFinances = _financeService.getFinances(type: widget.type);
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.type == 'income' ? Colors.green : Colors.red,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  String _formatCurrency(dynamic value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
    final accentColor = widget.type == 'income' ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Manajemen $title', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.red),
              onPressed: () => setState(() => _dateRange = null),
              tooltip: 'Hapus Filter',
            ),
          IconButton(
            onPressed: () => _selectDateRange(context), 
            icon: Icon(Icons.date_range, color: _dateRange != null ? accentColor : null)
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureFinances,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.outfit()));
          }

          // FILTER DATA BERDASARKAN RENTANG TANGGAL
          List<dynamic> allData = snapshot.data ?? [];
          List<dynamic> filteredData = allData;
          
          if (_dateRange != null) {
            filteredData = allData.where((item) {
              DateTime itemDate = DateTime.parse(item['date'].toString().substring(0, 10));
              return itemDate.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) && 
                     itemDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
            }).toList();
          }

          // HITUNG TOTAL
          double total = 0;
          for (var item in filteredData) {
            if (item['status'] != 'void') {
              total += double.tryParse(item['amount'].toString()) ?? 0;
            }
          }

          return Column(
            children: [
              // HEADER TOTAL
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateRange == null 
                        ? 'Total Keseluruhan' 
                        : 'Rentang: ${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}', 
                      style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 13)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(total), 
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),

              // LIST DATA
              Expanded(
                child: filteredData.isEmpty
                    ? Center(child: Text('Tidak ada data pada rentang ini', style: GoogleFonts.outfit()))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: filteredData.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredData[index];
                          return _buildFinanceCard(item, accentColor);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, title, accentColor),
        backgroundColor: accentColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Tambah $title', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFinanceCard(dynamic item, Color color) {
    final bool isVoid = item['status'] == 'void';
    final Color displayColor = isVoid ? Colors.grey : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: displayColor, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // IKON MINIMALIS
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: displayColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(
              isVoid ? Icons.block : (widget.type == 'income' ? Icons.south_west : Icons.north_east), 
              color: displayColor, 
              size: 14
            ),
          ),
          const SizedBox(width: 12),
          
          // INFO UTAMA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['description'] ?? item['note'] ?? '-', 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    decoration: isVoid ? TextDecoration.lineThrough : null,
                    color: isVoid ? Colors.grey : AppColors.text,
                  )
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['category'] ?? 'Tanpa Kategori'} • ${item['date']}', 
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    _buildSmallInfo(Icons.store, item['shop_name'] ?? 'Pusat', displayColor),
                    _buildSmallInfo(Icons.person, item['user_name'] ?? 'Admin', displayColor),
                  ],
                ),
                if (isVoid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('DIBATALKAN OLEH: ${item['void_by'] ?? '-'}', style: GoogleFonts.outfit(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          
          // HARGA & AKSI
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(double.tryParse(item['amount'].toString())),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14, 
                  color: displayColor,
                  decoration: isVoid ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              if (!isVoid)
                InkWell(
                  onTap: () => _showVoidConfirm(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: Colors.red.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
                    child: Text('Batal', style: GoogleFonts.outfit(fontSize: 9, color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 4),
              Icon(
                item['is_synced'] == 1 ? Icons.check_circle : Icons.cloud_off,
                size: 10,
                color: item['is_synced'] == 1 ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withOpacity(0.6)),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.outfit(fontSize: 9, color: AppColors.text.withOpacity(0.6))),
      ],
    );
  }

  void _showVoidConfirm(dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Batalkan Data?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin membatalkan catatatan ini? Saldo Dashboard akan otomatis diperbarui.', style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('TIDAK', style: GoogleFonts.outfit(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final String userName = auth.user?['name'] ?? 'Unknown';
              
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              final success = await _financeService.voidFinance(item['id'], userName);
              
              if (success && mounted) {
                navigator.pop();
                messenger.showSnackBar(const SnackBar(content: Text('Data berhasil dibatalkan')));
                _refresh();
              }
            }, 
            child: Text('YA, BATALKAN', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, String title, Color color) {
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Input $title', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildFormFiled('Jumlah (Rp)', amountController, Icons.payments, keyboardType: TextInputType.number),
              _buildFormFiled('Kategori (Misal: Listrik, Gaji)', categoryController, Icons.category),
              _buildFormFiled('Keterangan / Catatan', noteController, Icons.note),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final success = await _financeService.storeFinance({
                        'type': widget.type,
                        'amount': amountController.text,
                        'category': categoryController.text,
                        'note': noteController.text,
                      });
                      if (success && mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(content: Text('$title berhasil disimpan'), backgroundColor: Colors.black87),
                        );
                        _refresh();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('SIMPAN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFiled(String label, TextEditingController ctrl, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (v) => v!.isEmpty ? 'Bagian ini wajib diisi' : null,
      ),
    );
  }
}
