import 'dart:convert';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';


class PrinterService {
  static const _prefKey = 'saved_printer_address';

  // ===========================================================
  // REQUEST IZIN BLUETOOTH (Android 12+)
  // ===========================================================
  Future<bool> requestBluetoothPermissions() async {
    // Android 12+ membutuhkan BLUETOOTH_CONNECT & BLUETOOTH_SCAN
    final connectStatus = await Permission.bluetoothConnect.request();
    final scanStatus = await Permission.bluetoothScan.request();
    return connectStatus.isGranted && scanStatus.isGranted;
  }

  // ===========================================================
  // GET LIST PRINTER BLUETOOTH (PAIRED DEVICES)
  // ===========================================================
  Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      // Pastikan izin sudah diberikan sebelum scan
      final hasPermission = await requestBluetoothPermissions();
      if (!hasPermission) return [];

      final enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  // ===========================================================
  // SIMPAN & BACA PILIHAN PRINTER TERAKHIR
  // ===========================================================
  Future<void> saveLastPrinter(BluetoothInfo device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode({
      'name': device.name,
      'macAdress': device.macAdress,
    }));
  }

  Future<Map<String, String>?> getLastPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == null) return null;
    final map = jsonDecode(saved);
    return {'name': map['name'] ?? '', 'macAdress': map['macAdress'] ?? ''};
  }

  // ===========================================================
  // SAMBUNGKAN KE PRINTER
  // ===========================================================
  Future<bool> connect(BluetoothInfo device) async {
    try {
      final connected = await PrintBluetoothThermal.connectionStatus;
      if (connected) await PrintBluetoothThermal.disconnect;

      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      if (ok) await saveLastPrinter(device);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  // ===========================================================
  // PRINT STRUK (ESC/POS)
  // ===========================================================
  Future<void> printReceipt(Map<String, dynamic> transactionData, String cashierName) async {
    final connected = await isConnected();
    if (!connected) throw Exception('Printer belum terhubung');

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    String fmt(double v) {
      return 'Rp ${v.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    }

    final shopName = transactionData['shop_name'] ?? 'Eling Dimsum';
    final invoiceNumber = transactionData['invoice_number'] ?? '-';
    final items = transactionData['items'];
    final List<dynamic> itemList = items is String ? jsonDecode(items) : (items ?? []);
    final total = double.tryParse(transactionData['total_price']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse((transactionData['cash_received'] ?? transactionData['pay_amount'] ?? '0').toString()) ?? 0;
    final change = double.tryParse((transactionData['change'] ?? transactionData['change_amount'] ?? '0').toString()) ?? 0;
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    // Header
    bytes += generator.text(shopName, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Kasir', width: 5),
      PosColumn(text: ': $cashierName', width: 7),
    ]);
    bytes += generator.row([
      PosColumn(text: 'No', width: 5),
      PosColumn(text: ': $invoiceNumber', width: 7),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Waktu', width: 5),
      PosColumn(text: ': $dateStr', width: 7),
    ]);
    bytes += generator.hr();

    // Items
    for (var item in itemList) {
      final name = item['product_name'] ?? item['product']?['name'] ?? '-';
      final qty = int.tryParse(item['qty']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0;
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final subtotal = double.tryParse(item['subtotal']?.toString() ?? '0') ?? (price * qty);
      
      bytes += generator.text(name, styles: const PosStyles(bold: false));
      bytes += generator.row([
        PosColumn(text: '$qty x ${fmt(price)}', width: 7),
        PosColumn(text: fmt(subtotal), width: 5, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 7, styles: const PosStyles(bold: true)),
      PosColumn(text: fmt(total), width: 5, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Bayar', width: 7),
      PosColumn(text: fmt(paid), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Kembali', width: 7),
      PosColumn(text: fmt(change), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();
    bytes += generator.text('Terima Kasih!', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Selamat Makan :)', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // ===========================================================
  // PRINT GAMBAR LANGSUNG KE PRINTER BLUETOOTH (agar sama dengan tampilan layar)
  // ===========================================================
  Future<void> printImageViaBluetooth(Uint8List imageBytes) async {
    final connected = await isConnected();
    if (!connected) throw Exception('Printer belum terhubung');

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Konversi Uint8List gambar ke format ESC/POS raster image
    final originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) throw Exception('Gagal decode gambar struk');

    // Resize ke lebar standar printer 80mm (576 dots) atau 58mm (384 dots)
    // Kita gunakan 384 agar muat di 58mm dan 80mm
    final image = img.copyResize(originalImage, width: 384);

    bytes += generator.imageRaster(image, align: PosAlign.center);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

}
