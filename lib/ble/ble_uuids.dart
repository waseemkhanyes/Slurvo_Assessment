import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class GlBleUuids {
  static final service = Uuid.parse("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final writeCharacteristic = Uuid.parse("0000fee1-0000-1000-8000-00805f9b34fb");
  static final readCharacteristic  = Uuid.parse("0000fee2-0000-1000-8000-00805f9b34fb");
}
