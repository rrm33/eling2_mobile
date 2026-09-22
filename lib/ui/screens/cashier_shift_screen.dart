import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../services/cashier_shift_service.dart';
import '../../services/database_helper.dart';
import '../widgets/custom_button.dart';

class CashierShiftScreen extends StatefulWidget {
  const CashierShiftScreen({super.key});

  @override
  State<CashierShiftScreen> createState() => _CashierShiftScreenState();
}

class _CashierShiftScreenState extends State<CashierShiftScreen> {
  final CashierShiftService _shiftService = CashierShiftService();
  Map<String, dynamic>? _currentShift;
  bool _isLoading = true;
  final TextEditingController _cashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final shift = await _shiftService.getCurrentShift();
      if (!mounted) return;
      setState(() {
        if (shift != null && shift.containsKey('id')) {
          _currentShift = shift;
        } else {
          _currentShift = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> _openShift() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await _shiftService.openShift(0);
      if (!mounted) return;
      if (result['success']) {
        _cashController.clear();
        await _refreshStatus();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Buka Kasir: ${result['message']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _closeShift() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final result = await _shiftService.closeShift(0, "Tutup shift via HP");
      if (!mounted) return;
      if (result['success']) {
        _cashController.clear();
        await _refreshStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kasir Berhasil Ditutup')));
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Tutup Kasir: ${result['message']}'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Shift Kasir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Hapus Cache Shift',
            onPressed: () async {
              final db = await DatabaseHelper.instance.database;
              await db.delete('shifts');
              _refreshStatus();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache shift dikosongkan')));
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshStatus)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: (_currentShift == null)
                  ? _buildOpenShiftForm()
                  : _buildCloseShiftForm(),
            ),
    );
  }

  Widget _buildOpenShiftForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_open_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 20),
        Text('Kasir Belum Dibuka', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        DimsumButton(label: 'BUKA KASIR SEKARANG', onPressed: _openShift),
      ],
    );
  }

  Widget _buildCloseShiftForm() {
    final startTimeStr = _currentShift?['start_time'];
    final startTimeFormatted = startTimeStr != null ? DateFormat('dd MMM, HH:mm').format(DateTime.parse(startTimeStr)) : '-';

    final totalSales = _toDouble(_currentShift?['total_sales']);
    final startingCash = _toDouble(_currentShift?['starting_cash']);
    final totalIncome = _toDouble(_currentShift?['total_income']);
    final totalExpense = _toDouble(_currentShift?['total_expense']);
    final expectedCash = (startingCash + totalSales + totalIncome) - totalExpense;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                _buildInfoRow('Waktu Buka', startTimeFormatted),
                const Divider(),
                _buildInfoRow('Modal Awal', _formatCurrency(startingCash)),
                _buildInfoRow('Penjualan Kasir', _formatCurrency(totalSales)),
                _buildInfoRow('Pemasukan Manual', '+ ${_formatCurrency(totalIncome)}'),
                _buildInfoRow('Pengeluaran Manual', '- ${_formatCurrency(totalExpense)}'),
                const Divider(),
                _buildInfoRow('Ekspektasi Uang di Laci', _formatCurrency(expectedCash), isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 30),
          DimsumButton(label: 'TUTUP KASIR', onPressed: _closeShift),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.grey[700])),
          Text(value, style: GoogleFonts.outfit(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14)),
        ],
      ),
    );
  }
}
