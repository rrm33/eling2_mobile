import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_config.dart';
import '../../core/app_colors.dart';
import '../../services/cashier_shift_service.dart';
import '../../services/database_helper.dart';

class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  final CashierShiftService _shiftService = CashierShiftService();
  List<dynamic> _shifts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
      
      final data = await _shiftService.getShiftReports();
      setState(() {
        _userRole = userData['role'];
        _shifts = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Gagal memuat data laporan shift.";
      });
    }
  }

  Future<void> _deleteShift(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Laporan Shift'),
        content: const Text('Apakah Anda yakin ingin menghapus laporan shift ini dari server?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _shiftService.deleteShift(id);
      if (mounted) {
        if (result['success']) {
          // Hapus juga dari lokal agar langsung hilang dari layar
          final db = await DatabaseHelper.instance.database;
          await db.delete('shifts', where: 'server_id = ?', whereArgs: [id]);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
        _fetchShifts();
      }
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'Rp 0';
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(double.parse(value.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Laporan Shift Cabang', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchShifts, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 16, color: AppColors.text),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _fetchShifts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('COBA LAGI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _shifts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text('Tidak ada laporan shift saat ini.', style: GoogleFonts.outfit(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _shifts.length,
            itemBuilder: (context, index) {
              final s = _shifts[index];
              final diff = double.tryParse(s['difference']?.toString() ?? '0') ?? 0;
              final shopName = s['shop']?['name'] ?? s['shop_name'] ?? 'Cabang';
              final userName = s['user']?['name'] ?? s['user_name'] ?? 'Kasir';
              final startTime = s['start_time'] ?? s['opened_at'];
              final endTime = s['end_time'] ?? s['closed_at'];
              
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shopName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Kasir: $userName', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_userRole?.toLowerCase() == 'admin' && 
                                    (s['is_synced'] == 1 || s['is_synced'] == true || s['id'] != null))
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                    onPressed: () => _deleteShift(s['id']),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(right: 8),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: s['status'] == 'open' ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    (s['status'] ?? 'CLOSED').toUpperCase(),
                                    style: TextStyle(
                                      color: s['status'] == 'open' ? Colors.green : Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  s['is_synced'] == 1 ? Icons.cloud_done : Icons.cloud_off,
                                  size: 14,
                                  color: s['is_synced'] == 1 ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  s['is_synced'] == 1 ? 'Sinkron' : 'Lokal',
                                  style: TextStyle(fontSize: 9, color: s['is_synced'] == 1 ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 25),
                    Row(
                      children: [
                        _buildStat('Modal', _formatCurrency(s['starting_cash'])),
                        _buildStat('Penjualan', _formatCurrency(s['total_sales'] ?? 0)),
                        _buildStat('Pengeluaran', _formatCurrency(s['total_expense'] ?? 0), isExpense: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Selisih Uang Fisik:', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                        Text(
                          _formatCurrency(diff),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold, 
                            color: diff == 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Buka: ${startTime != null ? DateFormat('dd/MM HH:mm').format(DateTime.parse(startTime).toLocal()) : '-'} ${endTime != null ? ' - Tutup: ${DateFormat('HH:mm').format(DateTime.parse(endTime).toLocal())}' : ''}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildStat(String label, String value, {bool isExpense = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(
            value, 
            style: GoogleFonts.outfit(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: isExpense ? Colors.red : Colors.black,
            )
          ),
        ],
      ),
    );
  }
}
