import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:screenshot/screenshot.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_colors.dart';
import '../../services/printer_service.dart';
import 'package:intl/intl.dart';

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _buildDashedDivider() => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: CustomPaint(
    size: const Size(double.infinity, 1.5),
    painter: _DashedLinePainter(),
  ),
);

class ReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> transactionData;
  final bool isNewTransaction;
  const ReceiptScreen({super.key, required this.transactionData, this.isNewTransaction = false});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final PrinterService _printerService = PrinterService();
  bool _isPrinting = false;
  double _receiptFontSize = 14.0;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    // Auto-print dimatikan sesuai permintaan user. 
    // User harus memencet tombol secara manual untuk ngeprint.
  }

  // ===================================================
  // DIALOG PILIH PRINTER BLUETOOTH
  // ===================================================
  Future<void> _showPrinterDialog({bool autoPrint = false}) async {
    // Minta izin Bluetooth terlebih dahulu
    final hasPermission = await _printerService.requestBluetoothPermissions();
    if (!mounted) return;

    if (!hasPermission) {
      // Tampilkan dialog untuk mengarahkan ke Settings jika izin ditolak
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Izin Bluetooth Diperlukan'),
          content: const Text(
            'Aplikasi membutuhkan izin "Perangkat di Dekat Anda" (Nearby Devices) untuk menemukan printer Bluetooth.\n\n'
            'Ketuk OK untuk membuka Pengaturan, lalu aktifkan izin tersebut untuk aplikasi ini.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          ],
        ),
      );
      return;
    }

    final devices = await _printerService.getPairedDevices();
    final lastPrinter = await _printerService.getLastPrinter();

    if (!mounted) return;

    // Jika ada printer tersimpan sebelumnya dan auto print, langsung sambungkan
    if (autoPrint && lastPrinter != null && devices.isNotEmpty) {
      final saved = devices.where((d) => d.macAdress == lastPrinter['macAdress']).toList();
      if (saved.isNotEmpty) {
        _connectAndPrint(saved.first);
        return;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PrinterPickerSheet(
        devices: devices,
        lastMac: lastPrinter?['macAdress'],
        onSelect: (device) {
          Navigator.pop(ctx);
          _connectAndPrint(device);
        },
        onSkip: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _connectAndPrint(BluetoothInfo device) async {
    if (!mounted) return;
    setState(() => _isPrinting = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Menyambungkan ke ${device.name}...'), duration: const Duration(seconds: 3)),
      );

      final ok = await _printerService.connect(device);
      if (!ok) throw Exception('Gagal tersambung ke printer ${device.name}');

      // Ambil screenshot dari widget struk yang tampil di layar
      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 50),
        pixelRatio: 2.0,
      );
      if (imageBytes == null) throw Exception('Gagal mengambil gambar struk');

      // Cetak gambar ke printer — hasilnya identik dengan tampilan layar
      await _printerService.printImageViaBluetooth(imageBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Struk berhasil dicetak di ${device.name}!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal cetak: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _shareReceipt() async {
    try {
      final directory = await getTemporaryDirectory();
      final String fileName = 'Struk_${widget.transactionData['invoice_number']}.png';
      await _screenshotController.captureAndSave(directory.path, fileName: fileName);
      final File imageFile = File('${directory.path}/$fileName');
      await Share.shareXFiles([XFile(imageFile.path)], text: 'Struk Transaksi Dimsum');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final transaction = widget.transactionData;
    // Ambil data cabang dari transaksi terlebih dahulu, fallback ke data user yang login
    // Ini memastikan admin yang melihat nota cabang lain tetap tampil info cabang yang benar
    final dynamic txShop = transaction['shop'];
    final Map<String, dynamic> shop = txShop is Map<String, dynamic>
        ? txShop
        : (txShop != null ? Map<String, dynamic>.from(txShop as Map) : (user?['shop'] as Map<String, dynamic>? ?? {}));
    // Jika shop dari transaksi kosong, coba fallback ke shop_name dari transaksi
    final String shopName = shop['name']?.toString().isNotEmpty == true
        ? shop['name'].toString()
        : (transaction['shop_name']?.toString() ?? 'KEDAI DIMSUM');
    // Nama kasir: cari dari berbagai field yang mungkin ada di data transaksi,
    // lalu fallback ke data user yang sedang login.
    final String cashierName = transaction['user_name']?.toString().isNotEmpty == true
        ? transaction['user_name'].toString()
        : (transaction['user']?['name']?.toString().isNotEmpty == true
            ? transaction['user']['name'].toString()
            : (user?['name']?.toString() ?? '-'));
    final dynamic rawItems = transaction['items'];
    final List<dynamic> items = rawItems is String ? jsonDecode(rawItems) : (rawItems ?? []);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.blue), onPressed: _shareReceipt),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // TAMPILAN STRUK VISUAL
            Screenshot(
              controller: _screenshotController,
              child: Container(
                width: 384, // Lebar aman untuk SEMUA printer (58mm & 80mm)
                padding: const EdgeInsets.only(left: 0, right: 0, top: 12, bottom: 4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  children: [
                    Text(shopName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: _receiptFontSize + 8, color: Colors.black), textAlign: TextAlign.center),
                    Text(shop['address'] ?? '-', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                    if (shop['slogan'] != null && shop['slogan'].toString().trim().isNotEmpty)
                      Text('"${shop['slogan']}"', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                    if (transaction['status'] == 'void') ...[
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(color: Colors.red[50], border: Border.all(color: Colors.red, width: 1.5), borderRadius: BorderRadius.circular(4)),
                        child: const Center(child: Text('BATAL / VOID', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2))),
                      ),
                    ],
                    const SizedBox(height: 2),
                    _buildDashedDivider(),
                    Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(), // Lebar menyesuaikan teks terpanjang (Tanggal)
                        1: IntrinsicColumnWidth(), // Lebar titik dua
                        2: FlexColumnWidth(),      // Sisanya untuk value
                      },
                      children: [
                        _buildTableRow('Nota', transaction['invoice_number'] ?? '-'),
                        _buildTableRow('Tanggal', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
                        _buildTableRow('Kasir', cashierName),
                        _buildTableRow('Metode', (transaction['payment_method']?.toString() ?? 'Tunai').toUpperCase()),
                      ],
                    ),
                    _buildDashedDivider(),
                    ...items.map((item) {
                      String name = item['product_name'] ?? item['product']?['name'] ?? '-';
                      int qty = int.tryParse(item['qty']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0;
                      double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                      double subtotal = double.tryParse(item['subtotal']?.toString() ?? '0') ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Text('$qty x ${currencyFormatter.format(price)}', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black))),
                                const SizedBox(width: 8),
                                Text(currencyFormatter.format(subtotal), style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.right),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    _buildDashedDivider(),
                    _buildTotalRow('TOTAL', currencyFormatter.format(double.tryParse(transaction['total_price']?.toString() ?? '0') ?? 0), isBold: true),
                    _buildTotalRow('BAYAR', currencyFormatter.format(double.tryParse((transaction['cash_received'] ?? transaction['pay_amount'] ?? '0').toString()) ?? 0)),
                    _buildTotalRow('KEMBALI', currencyFormatter.format(double.tryParse((transaction['change'] ?? transaction['change_amount'] ?? '0').toString()) ?? 0)),
                    const SizedBox(height: 4),
                    Text('TERIMA KASIH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: _receiptFontSize, color: Colors.black)),
                    Text(
                      transaction['status'] == 'void' ? '--- VOID / BATAL ---' : '--- LUNAS ---',
                      style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: transaction['status'] == 'void' ? Colors.red : Colors.black),
                    ),
                    if ((shop['phone'] != null && shop['phone'].toString().trim().isNotEmpty) ||
                        (shop['instagram'] != null && shop['instagram'].toString().trim().isNotEmpty) ||
                        (shop['tiktok'] != null && shop['tiktok'].toString().trim().isNotEmpty) ||
                        (shop['facebook'] != null && shop['facebook'].toString().trim().isNotEmpty)) ...[
                      _buildDashedDivider(),
                      if (shop['phone'] != null && shop['phone'].toString().trim().isNotEmpty)
                        Text('WhatsApp: ${shop['phone']}', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                      if (shop['instagram'] != null && shop['instagram'].toString().trim().isNotEmpty)
                        Text('Instagram: @${shop['instagram'].toString().replaceAll('@', '')}', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                      if (shop['tiktok'] != null && shop['tiktok'].toString().trim().isNotEmpty)
                        Text('TikTok: @${shop['tiktok'].toString().replaceAll('@', '')}', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                      if (shop['facebook'] != null && shop['facebook'].toString().trim().isNotEmpty)
                        Text('Facebook: ${shop['facebook']}', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // TOMBOL PILIH PRINTER BLUETOOTH
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : () => _showPrinterDialog(),
                icon: _isPrinting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isPrinting ? 'Mencetak...' : 'Cetak via Bluetooth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showSettings = !_showSettings;
                  });
                },
                icon: const Icon(Icons.settings),
                label: const Text('Pengaturan'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Colors.blueGrey),
                  foregroundColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (_showSettings) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ukuran Font Struk: ${_receiptFontSize.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: _receiptFontSize,
                      min: 10.0,
                      max: 24.0,
                      divisions: 14,
                      label: _receiptFontSize.round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          _receiptFontSize = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Kembali', style: TextStyle(color: AppColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Text(label, style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Text(' : ', style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Text(value, style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.left),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: TextStyle(fontSize: _receiptFontSize, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// ===================================================
// WIDGET: Sheet Pilih Printer Bluetooth
// ===================================================
class _PrinterPickerSheet extends StatelessWidget {
  final List<BluetoothInfo> devices;
  final String? lastMac;
  final Function(BluetoothInfo) onSelect;
  final VoidCallback onSkip;

  const _PrinterPickerSheet({
    required this.devices,
    required this.onSelect,
    required this.onSkip,
    this.lastMac,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Pilih Printer Bluetooth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: onSkip, child: const Text('Lewati')),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pastikan printer sudah dinyalakan dan di-pair di pengaturan Bluetooth HP Anda.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Tidak ada printer yang terpasang.', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  const Text(
                    'Buka Pengaturan → Bluetooth → Pasangkan printer terlebih dahulu, lalu kembali ke sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            )
          else
            ...devices.map((device) {
              final isLast = device.macAdress == lastMac;
              return ListTile(
                leading: Icon(Icons.print, color: isLast ? Colors.blue : Colors.grey[600]),
                title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(device.macAdress),
                trailing: isLast
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)),
                        child: const Text('Terakhir', style: TextStyle(fontSize: 10, color: Colors.blue)),
                      )
                    : null,
                onTap: () => onSelect(device),
              );
            }),
        ],
      ),
    );
  }
}
