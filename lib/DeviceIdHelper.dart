import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdHelper {
  // Fungsi untuk mendapatkan ID unik HP ini
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    // Cek apakah sudah ada ID tersimpan
    String? deviceId = prefs.getString('device_uuid');

    // Jika belum ada (pengguna baru install), buat ID baru
    if (deviceId == null) {
      deviceId = const Uuid().v4(); // Generate random UUID
      await prefs.setString('device_uuid', deviceId);
    }

    return deviceId;
  }
}