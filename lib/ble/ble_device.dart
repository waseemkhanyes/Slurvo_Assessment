import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleDevice {
  // Corrected UUIDs according to protocol documentation
  static final Uuid serviceUuid = Uuid.parse("0000FFE0-0000-1000-8000-00805F9B34FB");
  static final Uuid characteristicWriteUuid = Uuid.parse("0000FEE1-0000-1000-8000-00805F9B34FB");
  static final Uuid characteristicNotifyUuid = Uuid.parse("0000FEE2-0000-1000-8000-00805F9B34FB");

  // Build sync command according to protocol (6 bytes)
  static List<int> buildSyncCommand({
    required int sleepTimeMinutes,
    required int clubNameIndex,
  }) {
    int byte1 = 0x47; // 'G'
    int byte2 = 0x4C; // 'L'
    int cmd = 1; // Sync command
    int sleepTime = sleepTimeMinutes & 0xFF; // 0-255 minutes
    int club = clubNameIndex & 0xFF; // 0-24 club index

    // Checksum: sum of bytes 3-5 (CMD + SLEEP TIME + CLUB NAME)
    int checksum = (cmd + sleepTime + club) & 0xFF;

    return [byte1, byte2, cmd, sleepTime, club, checksum];
  }

  // Build upload record command according to protocol (6 bytes)
  static List<int> buildUploadRecordCommand(int recordNumber) {
    int byte1 = 0x47; // 'G'
    int byte2 = 0x4C; // 'L'
    int cmd = 2; // Upload record command
    int recNoHigh = (recordNumber >> 8) & 0xFF; // High byte of record number
    int recNoLow = recordNumber & 0xFF; // Low byte of record number

    // Checksum: sum of bytes 3-5 (CMD + REC NO HIGH + REC NO LOW)
    int checksum = (cmd + recNoHigh + recNoLow) & 0xFF;

    return [byte1, byte2, cmd, recNoHigh, recNoLow, checksum];
  }
}