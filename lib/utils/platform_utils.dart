import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<bool> isRunningOnSimulator() async {
  if (!Platform.isIOS && !Platform.isAndroid) return false;

  final deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return !iosInfo.isPhysicalDevice;
  } else if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return !androidInfo.isPhysicalDevice;
  }
  return false;
}
