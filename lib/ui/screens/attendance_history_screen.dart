import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../core/api_config.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  Future<List<dynamic>>? _futureHistory;
  DateTime _selectedDate = DateTime.now();
  String? _userRole;

  @override
  void initState() {
    super.initState();
    // Inisialisasi awal secara sinkron agar tidak error 'late'
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _futureHistory = AuthService().getAttendanceHistory(date: dateStr);
    _refresh();
  }

  void _refresh() async {
    final userData = await AuthService().getUserData();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    setState(() {
      _userRole = userData?['role'];
      _futureHistory = AuthService().getAttendanceHistory(date: dateStr);
    });
  }

  Future<void> _deleteAttendance(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Absensi'),
        content: const Text('Apakah Anda yakin ingin menghapus data absensi ini dari server?'),
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
      final result = await AttendanceService().deleteAttendance(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
        _refresh();
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riwayat Absensi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _selectDate(context),
            icon: Icon(Icons.calendar_month, color: AppColors.primary),
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 16, color: AppColors.text),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refresh,
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
            );
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text('Tidak ada riwayat untuk tanggal ini.', style: GoogleFonts.outfit(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = data[index];
              return _buildAttendanceDailyCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildAttendanceDailyCard(dynamic item) {
    bool isPresent = item['in_time'] != null || item['out_time'] != null;
    // Cek is_synced (bisa berupa bool true/false atau int 1/0 dari SQLite)
    bool isSynced = item['is_synced'] == true || item['is_synced'] == 1 || item['is_synced'] == null;

    return Container(
      decoration: BoxDecoration(
        color: isPresent ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: isPresent ? null : Border.all(color: Colors.grey.shade200),
        boxShadow: isPresent ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tanggal & Toko
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPresent ? AppColors.primary.withOpacity(0.05) : Colors.grey.shade200,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(item['name'] ?? '-', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 5),
                      Icon(
                        isSynced ? Icons.cloud_done : Icons.cloud_off,
                        size: 16,
                        color: isSynced ? Colors.green : Colors.orange,
                      ),
                      if (_userRole?.toLowerCase() == 'admin' && isSynced && item['id'] != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _deleteAttendance(item['id']),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(left: 8),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPresent ? AppColors.success.withOpacity(0.2) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPresent ? (item['is_offline'] == true ? 'LOKAL' : 'HADIR') : 'ALPHA', 
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: isPresent ? AppColors.success : Colors.red),
                  ),
                ),
              ],
            ),
          ),

          // Info Toko
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(item['shop']?['name'] ?? 'Pusat', style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          const Divider(height: 24),

          // Detail Masuk & Pulang
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            child: Opacity(
              opacity: isPresent ? 1.0 : 0.4,
              child: Row(
                children: [
                  Expanded(child: _buildTimeDetail('MASUK', item['in_time'], item['in_photo'], Colors.green)),
                  Container(width: 1, height: 40, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12)),
                  Expanded(child: _buildTimeDetail('PULANG', item['out_time'], item['out_photo'], Colors.red)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDetail(String label, String? time, String? photo, Color color) {
    ImageProvider? imageProvider;
    if (photo != null) {
      if (photo.startsWith('/')) {
        imageProvider = FileImage(File(photo));
      } else {
        imageProvider = NetworkImage('${ApiConfig.baseUrl}/storage/$photo');
      }
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (imageProvider != null) _showFullScreenImage(imageProvider);
          },
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
              image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
            ),
            child: imageProvider == null ? Icon(Icons.camera_alt_outlined, size: 20, color: Colors.grey.shade400) : null,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            Text(time ?? '--:--', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _showFullScreenImage(ImageProvider provider) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image(image: provider))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
