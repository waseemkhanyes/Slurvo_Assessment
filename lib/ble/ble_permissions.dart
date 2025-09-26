import 'package:permission_handler/permission_handler.dart';

class BlePermissions {
  /// Request all necessary permissions for BLE scanning and connection
  static Future<bool> request() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    // Log permission results for debugging
    print("** BLE Permission Results:");
    statuses.forEach((permission, status) {
      print("   ${permission.toString()}: $status");
    });

    return allGranted;
  }

  /// Check current permission status without requesting
  static Future<Map<Permission, PermissionStatus>> checkStatus() async {
    return await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  /// Check if all required permissions are granted
  static Future<bool> areAllGranted() async {
    final statuses = await checkStatus();
    return statuses.values.every((status) => status.isGranted);
  }
}