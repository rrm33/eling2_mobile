import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_helper.dart';
import '../../core/api_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = 'Memuat...';


  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentVersion = packageInfo.version;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentVersion = 'Tidak diketahui';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pengaturan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih Warna Utama', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Warna ini akan digunakan di tombol, header, dan elemen utama lainnya.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 20),
            
            // Tombol buka palet warna
            GestureDetector(
              onTap: () => _openColorPicker(context, themeProvider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: themeProvider.primaryColor.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.palette, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Pilih Warna dari Palet',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text('Pemeliharaan Data', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Hanya menghapus data di HP, tidak menghapus data di server.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 15),
            
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Hapus Riwayat Lokal', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Bersihkan duplikasi atau data lama di HP', style: TextStyle(fontSize: 12)),
              tileColor: Colors.red.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onTap: () => _confirmClearHistory(context),
            ),
            const SizedBox(height: 30),
            Text('Aplikasi & Sistem', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Periksa pembaruan sistem dan versi aplikasi.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.system_update_alt, color: Colors.blue),
              title: const Text('Periksa Pembaruan', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Versi saat ini: $_currentVersion', style: const TextStyle(fontSize: 12)),
              tileColor: Colors.blue.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              onTap: () => _checkForUpdates(context),
            ),
          ],
        ),
      ),
    );
  }


  void _openColorPicker(BuildContext context, ThemeProvider themeProvider) {
    Color pickerColor = themeProvider.primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Warna Tema', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            displayThumbColor: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              themeProvider.setPrimaryColor(pickerColor);
              Navigator.pop(context);
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  void _checkForUpdates(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('${ApiConfig.apiUrl}/app-version'),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      if (context.mounted) Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version']?.toString() ?? '';
        final downloadUrl = data['download_url']?.toString() ?? '';

        if (latestVersion.isNotEmpty && latestVersion != currentVersion) {
          if (context.mounted) {
            _showUpdateDialog(context, currentVersion, latestVersion, downloadUrl);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aplikasi sudah versi terbaru!'), backgroundColor: Colors.green),
            );
          }
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog just in case
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  void _showUpdateDialog(BuildContext context, String current, String latest, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double progress = 0.0;
        String statusText = 'Pembaruan tersedia! Menunggu konfirmasi...';
        bool isDownloading = false;
        bool hasError = false;

        StreamSubscription? subscription;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Pembaruan Aplikasi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Versi Saat Ini: $current'),
                  Text('Versi Terbaru: $latest', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(statusText, style: TextStyle(color: hasError ? Colors.red : Colors.grey[700], fontSize: 13)),
                  const SizedBox(height: 10),
                  if (isDownloading) ...[
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 5),
                    Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                if (!isDownloading && !hasError) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Nanti Saja'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isDownloading = true;
                        statusText = 'Mengunduh file pembaruan...';
                        progress = 0.0;
                      });

                      try {
                        subscription = OtaUpdate().execute(
                          downloadUrl,
                          destinationFilename: 'eling_dimsum_update.apk',
                        ).listen(
                          (OtaEvent event) {
                            setState(() {
                              switch (event.status) {
                                case OtaStatus.DOWNLOADING:
                                  progress = double.tryParse(event.value ?? '0') ?? 0;
                                  progress = progress / 100;
                                  statusText = 'Mengunduh file pembaruan...';
                                  break;
                                case OtaStatus.INSTALLING:
                                  statusText = 'Membuka installer...';
                                  isDownloading = false;
                                  Navigator.pop(context);
                                  break;
                                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                                  hasError = true;
                                  isDownloading = false;
                                  statusText = 'Izin pemasangan tidak diberikan.';
                                  break;
                                case OtaStatus.DOWNLOAD_ERROR:
                                  hasError = true;
                                  isDownloading = false;
                                  statusText = 'Gagal mengunduh file APK.';
                                  break;
                                default:
                                  hasError = true;
                                  isDownloading = false;
                                  statusText = 'Gagal memperbarui: ${event.status}';
                              }
                            });
                          },
                          onError: (err) {
                            setState(() {
                              hasError = true;
                              isDownloading = false;
                              statusText = 'Terjadi kesalahan: $err';
                            });
                          },
                        );
                      } catch (e) {
                        setState(() {
                          hasError = true;
                          isDownloading = false;
                          statusText = 'Gagal memulai update: $e';
                        });
                      }
                    },
                    child: const Text('Perbarui Sekarang'),
                  ),
                ] else if (hasError) ...[
                  ElevatedButton(
                    onPressed: () {
                      subscription?.cancel();
                      Navigator.pop(context);
                    },
                    child: const Text('Tutup'),
                  ),
                ] else ...[
                  // Sedang mendownload - tampilkan tombol Batal
                  TextButton(
                    onPressed: () {
                      subscription?.cancel();
                      setState(() {
                        isDownloading = false;
                        statusText = 'Download dibatalkan.';
                        hasError = true;
                      });
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Batal Download'),
                  ),
                ]
              ],
            );
          },
        );
      },
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat?'),
        content: const Text('Ini hanya menghapus data riwayat transaksi yang tersimpan di HP. Data di server tetap aman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = await DatabaseHelper.instance.database;
              await db.delete('transactions');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Riwayat lokal berhasil dibersihkan!'), backgroundColor: Colors.green)
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
