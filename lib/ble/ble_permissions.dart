import 'package:permission_handler/permission_handler.dart';

class BlePermissions {
  static Future<bool> request() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }
}
