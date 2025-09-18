import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleDevice {
  static final Uuid serviceUuid = Uuid.parse("0000FFE0-0000-1000-8000-00805F9B34FB");
  static final Uuid characteristicWriteUuid = Uuid.parse("0000FEE1-0000-1000-8000-00805F9B34FB");
  static final Uuid characteristicNotifyUuid = Uuid.parse("0000FEE2-0000-1000-8000-00805F9B34FB");

  static List<int> buildSyncCommand({
    required int sleepTimeMinutes,
    required int clubNameIndex,
  }) {
    int byte1 = 0x47;
    int byte2 = 0x4C;
    int cmd = 1;
    int sleepTime = sleepTimeMinutes & 0xFF;
    int club = clubNameIndex & 0xFF;
    int checksum = (cmd + sleepTime + club) & 0xFF;
    return [byte1, byte2, cmd, sleepTime, club, checksum];
  }

  static List<int> buildUploadRecordCommand(int recordNumber) {
    int byte1 = 0x47;
    int byte2 = 0x4C;
    int cmd = 2;
    int recNoHigh = (recordNumber >> 8) & 0xFF;
    int recNoLow = recordNumber & 0xFF;
    int checksum = (cmd + recNoHigh + recNoLow) & 0xFF;
    return [byte1, byte2, cmd, recNoHigh, recNoLow, checksum];
  }
}
