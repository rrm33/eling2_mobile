class ApiConfig {
  static const String baseUrl = 'https://eling2.bisnisumkm.biz.id';
  // static const String baseUrl = 'http://10.0.2.2:8000'; // Untuk Emulator Android
  // static const String baseUrl = 'http://192.168.17.9:8000'; // IP Local Anda
  // static const String baseUrl = 'http://192.168.11.247:8000'; // IP Local Anda
  static const String apiUrl = '$baseUrl/api';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
