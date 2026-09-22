import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/app_colors.dart';
import '../../core/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  File? _image;
  Position? _currentPosition;
  bool _isLoading = false;
  String _type = 'in';

  final ImagePicker _picker = ImagePicker();

  Future<void> _getImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25, // Kurangi kualitas ke 25% (masih jelas untuk absen)
        maxWidth: 800,    // Batasi lebar maksimal 800px
        maxHeight: 800,   // Batasi tinggi maksimal 800px
        preferredCameraDevice: CameraDevice.front,
      );

      setState(() {
        if (pickedFile != null) {
          _image = File(pickedFile.path);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin kamera ditolak. Silakan aktifkan izin kamera di pengaturan HP Anda.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS tidak aktif.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Izin lokasi ditolak.');
    }

    setState(() => _isLoading = true);
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10), // Limit waktu agar tidak loading selamanya
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan lokasi: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAttendance({bool forceUpdate = false}) async {
    if (_image == null || _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto dan Lokasi wajib ada!')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final result = await _attendanceService.submitAttendance(
        type: _type,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        photoPath: _image!.path,
        forceUpdate: forceUpdate,
      );

      if (!mounted) return;

      // Jika server mendeteksi sudah ada absen, munculkan dialog
      if (result['status'] == 'exists') {
        setState(() => _isLoading = false);
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Konfirmasi Absen', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Text(result['message'] ?? 'Anda sudah absen hari ini. Ingin memperbarui data?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Tidak')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), 
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text('Ya, Update', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          _submitAttendance(forceUpdate: true);
        }
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']), 
          backgroundColor: result['success'] ? AppColors.success : AppColors.warning
        )
      );
      
      if (result['success']) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Absensi Karyawan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Pilih Tipe
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'in', label: Text('Masuk'), icon: Icon(Icons.login)),
                ButtonSegment(value: 'out', label: Text('Pulang'), icon: Icon(Icons.logout)),
              ],
              selected: {_type},
              onSelectionChanged: (newSelection) => setState(() => _type = newSelection.first),
            ),
            SizedBox(height: 30),

            // Preview Foto
            GestureDetector(
              onTap: _getImage,
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_enhance_outlined, size: 50, color: AppColors.textLight),
                          SizedBox(height: 10),
                          Text('Ambil Foto Selfie', style: GoogleFonts.outfit(color: AppColors.textLight)),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
              ),
            ),
            SizedBox(height: 20),

            // Info Lokasi
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lokasi Saat Ini:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        Text(
                          _currentPosition == null 
                            ? 'Mencari lokasi...' 
                            : '${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
                          style: GoogleFonts.outfit(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _isLoading ? CircularProgressIndicator(strokeWidth: 2) : IconButton(icon: Icon(Icons.refresh), onPressed: _determinePosition)
                ],
              ),
            ),
            SizedBox(height: 40),

            // Tombol Kirim
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('KIRIM ABSENSI', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
