import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../providers/auth_provider.dart';
import '../../core/app_colors.dart';
import '../../core/api_config.dart';
import '../../services/database_helper.dart';
import '../../services/transaction_service.dart';
import '../../services/sync_service.dart';
import '../../services/cashier_shift_service.dart';
import '../../services/finance_service.dart';
import '../../services/chat_service.dart';

import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'user_list_screen.dart';
import 'shop_list_screen.dart';
import 'finance_screen.dart';
import 'product_list_screen.dart';
import 'pos_screen.dart';
import 'settings_screen.dart';
import 'cashier_shift_screen.dart';
import 'shift_report_screen.dart';
import 'transaction_history_screen.dart';
import 'report_screen.dart';
import 'courier_dashboard_screen.dart';
import 'request_stock_screen.dart';
import 'edit_stock_screen.dart';
import 'chat_screen.dart';
import 'admin_chat_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FinanceService _financeService = FinanceService();
  bool _isSyncing = false;
  Map<String, dynamic>? _summary;
  bool _isLoadingSummary = true;
  bool _isOnline = true;
  static int _lastDimsum = 0;
  static int _lastSaus = 0;
  int _unreadCount = 0;
  Timer? _pingTimer;
  Timer? _autoSyncTimer;
  Timer? _chatTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  int _failedPingCount = 0;


  @override
  void initState() {
    super.initState();
    _loadSummary();

    // Dengarkan perubahan koneksi jaringan secara reaktif
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) {
        _failedPingCount = 2; // Paksa status offline jika adapter terputus
        if (_isOnline && mounted) {
          setState(() => _isOnline = false);
          _triggerOfflinePopup();
        }
      } else {
        // Lakukan verifikasi internet aktif
        _checkConnection();
      }
    });

    _pingTimer = Timer.periodic(const Duration(seconds: 60), (_) => _checkConnection());
    // Run automatic background sync periodically (when online) every 5 minutes
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 300), (_) => _autoSync());
    _chatTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadUnreadCount());
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (!mounted || !_isOnline) return;
    try {
      final count = await ChatService().getUnreadCount();
      if (mounted && count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    } catch (e) {
      debugPrint('Error getUnreadCount in dashboard: $e');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pingTimer?.cancel();
    _autoSyncTimer?.cancel();
    _chatTimer?.cancel();
    super.dispose();
  }

  void _triggerOfflinePopup() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.wifi_off_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Koneksi Terputus'),
          ],
        ),
        content: const Text(
          'Anda sedang berada dalam mode offline karena koneksi internet tidak stabil.\n\nJangan khawatir, Anda tetap bisa melakukan transaksi seperti biasa. Data akan otomatis disinkronkan ke server setelah koneksi kembali normal.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _checkConnection() async {
    try {
      // Gunakan DNS lookup ke host server yang sangat ringan, cepat, dan tidak terhambat Cloudflare/Rate-limiting
      final result = await InternetAddress.lookup('bisnisumkm.biz.id').timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _failedPingCount = 0;
        if (!_isOnline && mounted) setState(() => _isOnline = true);
      } else {
        _handlePingFailure();
      }
    } catch (_) {
      _handlePingFailure();
    }
  }

  void _handlePingFailure() {
    _failedPingCount++;
    // Toleransi jitter/gangguan jaringan sesaat: Hanya tampil offline jika gagal 2x berturut-turut
    if (_failedPingCount >= 2) {
      if (_isOnline && mounted) {
        setState(() => _isOnline = false);
        _triggerOfflinePopup();
      }
    }
  }

  Future<double?> _getTodaySalesFromServer(int? shopId) async {
    try {
      final token = await Provider.of<AuthProvider>(context, listen: false).getToken();
      DateTime now = DateTime.now();
      String todayStr = DateFormat('yyyy-MM-dd').format(now);
      String url = '${ApiConfig.apiUrl}/transactions?start_date=$todayStr&end_date=$todayStr';
      if (shopId != null) url += '&shop_id=$shopId';

      final res = await http.get(Uri.parse(url), headers: {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return double.tryParse(data['summary']?['total_sales']?.toString() ?? '0');
      }
    } catch (_) {}
    return null;
  }

  /// Ambil total dimsum & saus dari server, fallback ke lokal jika offline
  Future<void> _loadDimsumSaus(bool isAdmin) async {
    try {
      // Coba ambil dari server dulu
      final serverResult = await TransactionService().getDimsumOutFromServer(isAdmin);
      if (mounted) {
        setState(() {
          _lastDimsum = serverResult['dimsum'] ?? 0;
          _lastSaus   = serverResult['saus']   ?? 0;
        });
      }
    } catch (_) {
      // Fallback ke lokal jika server tidak bisa diakses
      try {
        final localResult = await TransactionService().getShiftMetrics(isAdmin);
        if (mounted) {
          setState(() {
            _lastDimsum = localResult['dimsum'] ?? _lastDimsum;
            _lastSaus   = localResult['saus']   ?? _lastSaus;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadSummary() async {
    // Paksa cek koneksi secara instan setiap kali user me-refresh halaman (pull-to-refresh)
    await _checkConnection();
    
    setState(() {
      _isSyncing = true;
      _isLoadingSummary = true;
    });
    
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final isAdmin = user?['role']?.toString().toLowerCase() == 'admin';
      final int? shopId = isAdmin ? null : (user?['shop_id'] != null ? int.tryParse(user!['shop_id'].toString()) : null);

      // 1. Ambil data lokal dulu agar instan
      final localData = await _financeService.getSummary(shopId, isAdmin: isAdmin);
      if (mounted) {
        setState(() {
          _summary = localData;
          _isLoadingSummary = false;
        });
      }

      // 1b. Coba ambil omzet hari ini dari server agar sama dengan laporan
      try {
        final token = await Provider.of<AuthProvider>(context, listen: false).getToken();
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final serverRes = await http.get(Uri.parse('${ApiConfig.apiUrl}/transactions?start_date=$todayStr&end_date=$todayStr'), headers: headers);
        if (serverRes.statusCode == 200) {
          final sData = jsonDecode(serverRes.body);
          if (sData['summary'] != null) {
            if (sData['summary']['total_sales'] != null) {
              _summary!['today_sales'] = double.tryParse(sData['summary']['total_sales'].toString()) ?? 0;
            }
            if (sData['summary']['total_sales_cash'] != null) {
              _summary!['today_sales_cash'] = double.tryParse(sData['summary']['total_sales_cash'].toString()) ?? 0;
            }
            if (sData['summary']['total_sales_qris'] != null) {
              _summary!['today_sales_qris'] = double.tryParse(sData['summary']['total_sales_qris'].toString()) ?? 0;
            }
            if (sData['summary']['total_sales_lainnya'] != null) {
              _summary!['today_sales_lainnya'] = double.tryParse(sData['summary']['total_sales_lainnya'].toString()) ?? 0;
            }
          }
        }
      } catch (_) {}

      // 2. Ambil data dimsum & saus (server atau lokal)
      _loadDimsumSaus(isAdmin);

      // 3. Jalankan sync di background (automatic)
      SyncService().syncAll().then((_) async {
        final freshData = await _financeService.getSummary(shopId, isAdmin: isAdmin);
        // Refresh juga data dimsum/saus setelah sync selesai
        _loadDimsumSaus(isAdmin);
        if (mounted) {
          setState(() {
            _summary = freshData;
            _isSyncing = false;
          });
        }
        
        // Fetch server sales again after sync to ensure it matches report
        if (_isOnline) {
          final serverSalesAfterSync = await _getTodaySalesFromServer(shopId);
          if (serverSalesAfterSync != null && mounted) {
            setState(() {
              _summary!['today_sales'] = serverSalesAfterSync;
            });
          }
        }
      }).catchError((e) {
        // Gagal sinkronisasi data tidak berarti internet putus, melainkan bisa karena error database/API
        if (mounted) {
          setState(() {
            _isSyncing = false;
          });
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _autoSync() async {
    // Avoid overlapping syncs and only sync when online
    if (!_isOnline || _isSyncing) return;
    try {
      setState(() => _isSyncing = true);
      await SyncService().syncAll();
    } catch (_) {
      // ignore errors; connectivity check will update _isOnline
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _formatCurrency(dynamic value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value ?? 0);
  }

  double _parseNum(dynamic v) => double.tryParse(v.toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final String role = user?['role']?.toString().toLowerCase() ?? 'user';
    final isAdmin = role == 'admin';

    // 1. Masuk: Hanya Pemasukan Manual (Sesuai permintaan Anda)
    final totalMasukManual = _parseNum(_summary?['total_income']);
    
    // 2. Keluar: Hanya Pengeluaran manual
    final totalKeluar = _parseNum(_summary?['total_expense']);
    

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: CustomScrollView(
          slivers: [
            // Header Baru (Melengkung dengan Kartu yang Mengalir Natural)
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // Latar Belakang Melengkung (hanya sebagai background)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 210,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(35),
                          bottomRight: Radius.circular(35),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30, top: -20,
                            child: Opacity(opacity: 0.15, child: Icon(Icons.auto_awesome, size: 180, color: Colors.white)),
                          ),
                          Positioned(
                            left: -20, bottom: -20,
                            child: Opacity(opacity: 0.15, child: Icon(Icons.data_usage, size: 120, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Konten mengalir secara natural
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Teks Sapaan + Ikon
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 5, 20, 15),
                          child: Column(
                            children: [
                              // Baris Atas: Badge Online dan Tombol Aksi
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _isOnline ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_isOnline ? Icons.wifi : Icons.wifi_off, color: Colors.white, size: 10),
                                        const SizedBox(width: 6),
                                        Text(
                                          _isOnline ? 'Online' : 'Offline',
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 22),
                                            onPressed: () {
                                              if (isAdmin) {
                                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminChatListScreen())).then((_) => _loadUnreadCount());
                                              } else {
                                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())).then((_) => _loadUnreadCount());
                                              }
                                            },
                                          ),
                                          if (_unreadCount > 0)
                                            Positioned(
                                              right: -4,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 15),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                                      ),
                                      const SizedBox(width: 15),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                                        onPressed: () async {
                                          final bool? confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Konfirmasi Logout'),
                                              content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Batal'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  child: const Text('Logout', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && mounted) {
                                            Provider.of<AuthProvider>(context, listen: false).logout();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Baris Bawah: Avatar dan Teks Sapaan
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: user?['photo'] ?? 'https://ui-avatars.com/api/?name=${user?['name']}',
                                        placeholder: (context, url) => const Icon(Icons.person, color: Colors.grey),
                                        errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey),
                                        fit: BoxFit.cover,
                                        width: 56,
                                        height: 56,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Selamat Datang', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                                        Text(
                                          (user?['name'] ?? 'KASIR').toString().toUpperCase(),
                                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        if (_isSyncing)
                                          Row(
                                            children: [
                                              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                              const SizedBox(width: 8),
                                              Text('Sinkronisasi Data...', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10)),
                                            ],
                                          )
                                        else
                                          Text(
                                            '${user?['shop']?['name'] ?? 'Pusat'} • ${role.toUpperCase()}',
                                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // KARTU SALDO (mengalir di bawah header)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Omset Hari Ini', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
                                        const SizedBox(height: 2),
                                        _isLoadingSummary
                                          ? const SizedBox(width: 80, height: 2, child: LinearProgressIndicator())
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(_formatCurrency(_parseNum(_summary?['today_sales'])), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                          child: Text('Tunai', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(_formatCurrency(_parseNum(_summary?['today_sales_cash'])), style: GoogleFonts.outfit(fontSize: 10, color: Colors.black87)),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                          decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                          child: Text('QRIS', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(_formatCurrency(_parseNum(_summary?['today_sales_qris'])), style: GoogleFonts.outfit(fontSize: 10, color: Colors.black87)),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                          child: Text('Lainnya', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(_formatCurrency(_parseNum(_summary?['today_sales_lainnya'])), style: GoogleFonts.outfit(fontSize: 10, color: Colors.black87)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        if (!isAdmin)
                                          _buildMiniSummary(Icons.account_balance_wallet_outlined, 'Modal', _parseNum(_summary?['starting_cash']), Colors.blue),
                                        // Pemasukan dan Pengeluaran disembunyikan
                                        // if (!isAdmin) const SizedBox(height: 4),
                                        // _buildMiniSummary(Icons.arrow_downward, 'Masuk', totalMasukManual, Colors.green),
                                        // const SizedBox(height: 4),
                                        // _buildMiniSummary(Icons.arrow_upward, 'Keluar', totalKeluar, Colors.red),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Tombol Pemasukan dan Pengeluaran disembunyikan
                              // const SizedBox(height: 12),
                              // Row(
                              //   children: [
                              //     Expanded(
                              //       child: _buildActionButton(context, 'Pemasukan', Icons.add_circle_outline, Colors.green, () {
                              //         Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(type: 'income')));
                              //       }),
                              //     ),
                              //     const SizedBox(width: 8),
                              //     Expanded(
                              //       child: _buildActionButton(context, 'Pengeluaran', Icons.remove_circle_outline, Colors.red, () {
                              //         Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen(type: 'expense')));
                              //       }),
                              //     ),
                              //   ],
                              // ),
                            ],
                          ),
                        ),
                      ),

                    ],
                  ),
                ],
              ),
            ),



            // Banner Peringatan Offline (Jika Tidak Ada Koneksi)
            if (!_isOnline)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.red.shade700,
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Aplikasi Offline. Transaksi tetap bisa dilakukan & tersimpan aman di HP.',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),


            // Menu Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildListDelegate([
                  // Menu Buka/Tutup Kasir disembunyikan
                  // if (!isAdmin)
                  //   _buildMenuCard(context, 'Buka/Tutup Kasir', Icons.lock_clock_outlined, Colors.blueGrey, () {
                  //     Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierShiftScreen()));
                  //   }),
                  // Menu Laporan Shift disembunyikan
                  // if (isAdmin)
                  //   _buildMenuCard(context, 'Laporan Shift', Icons.assignment_outlined, Colors.indigo, () {
                  //     Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftReportScreen()));
                  //   }),
                  _buildMenuCard(context, 'Absensi', Icons.camera_alt_outlined, AppColors.primary, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen()));
                  }),
                  _buildMenuCard(context, 'Riwayat Presensi', Icons.history, Colors.orange, () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
                  }),
                  if (isAdmin)
                  _buildMenuCard(context, 'Toko', Icons.store_mall_directory_outlined, Colors.indigo, () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopListScreen()));
                  }),
                  if (isAdmin)
                  _buildMenuCard(context, 'Staff', Icons.people_outline, Colors.teal, () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen()));
                  }),

                  _buildMenuCard(context, 'Produk', Icons.inventory_2_outlined, Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
                  }),
                  if (!isAdmin)
                  _buildMenuCard(context, 'Transaksi', Icons.shopping_cart_outlined, AppColors.success, () async {
                    // Cek apakah sudah buka kasir
                    final shift = await CashierShiftService().getCurrentShift();
                    if (shift == null) {
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Kasir Belum Buka', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            content: Text('Silakan lakukan "Buka Kasir" terlebih dahulu sebelum memulai transaksi.', style: GoogleFonts.outfit()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierShiftScreen()));
                                },
                                child: const Text('Buka Kasir Sekarang', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      }
                      return;
                    }
                    
                    if (mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()));
                    }
                  }),
                  
                  _buildMenuCard(context, 'Riwayat Transaksi', Icons.receipt_long_outlined, Colors.teal, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()));
                  }),
                  if (isAdmin)
                  _buildMenuCard(context, 'Laporan', Icons.bar_chart_outlined, Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSummary(IconData icon, String label, dynamic value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey)),
            Text(_formatCurrency(value), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 10, height: 1.1),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String total, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(title, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(total, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text('Total Terjual', style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }
}
