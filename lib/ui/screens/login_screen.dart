import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_colors.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60),
              Text(
                'Selamat Datang di\nEling Dimsum',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Masuk untuk mulai mengelola transaksi Anda',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
              ),
              SizedBox(height: 40),
              
              // Form Login
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              SizedBox(height: 24),

              // Tombol Login Utama
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: authProvider.isLoading 
                    ? null 
                    : () async {
                        try {
                          await authProvider.login(
                            _emailController.text, 
                            _passwordController.text
                          );
                          // Routing ditangani otomatis oleh main.dart via AuthProvider
                        } catch (e) {
                          _showErrorModal(e.toString());
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: authProvider.isLoading 
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'MASUK',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showErrorModal(String rawError) {
    String message = 'Terjadi kesalahan pada sistem. Silakan coba beberapa saat lagi.';
    final errLower = rawError.toLowerCase();
    
    if (errLower.contains('kredensial') || errLower.contains('salah') || errLower.contains('password') || errLower.contains('email') || errLower.contains('401') || errLower.contains('invalid')) {
      message = 'Email atau kata sandi yang Anda masukkan tidak sesuai. Silakan periksa kembali.';
    } else if (errLower.contains('connection refused') || errLower.contains('network') || errLower.contains('timeout') || errLower.contains('socket') || errLower.contains('host')) {
      message = 'Tidak dapat terhubung ke server.\nPastikan perangkat Anda terhubung ke internet dan coba lagi.';
    } else if (errLower.contains('404')) {
      message = 'Sistem sedang dalam perbaikan atau layanan tidak ditemukan.';
    } else if (errLower.contains('500') || errLower.contains('server')) {
      message = 'Terjadi gangguan pada server pusat. Mohon tunggu beberapa saat lagi.';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
              const SizedBox(height: 16),
              Text(
                'Gagal Masuk',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('TUTUP', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
