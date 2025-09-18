import '../models/club_names.dart';

class ParsedNotification {
  final int batteryLevel;
  final String clubName;
  final double clubSpeed;
  final double ballSpeed;
  final double carryDistance;
  final double totalDistance;

  ParsedNotification({
    required this.batteryLevel,
    required this.clubName,
    required this.clubSpeed,
    required this.ballSpeed,
    required this.carryDistance,
    required this.totalDistance,
  });
}

class BleDataParser {
  static ParsedNotification? parseNotification(List<int> data) {
    if (data.length < 18) {
      print("Notification too short, ignoring");
      return null;
    }

    if (data[0] != 0x47 || data[1] != 0x4C) {
      print("Invalid header");
      return null;
    }

    int cmd = data[2];
    if (cmd == 1) {
      int batteryCap = data[3];
      int maxRecord = (data[4] << 8) | data[5];
      int currentRecord = (data[6] << 8) | data[7];
      int clubIdx = data[8];
      int clubSpRaw = (data[9] << 8) | data[10];
      int ballSpRaw = (data[11] << 8) | data[12];
      int carryRaw = (data[13] << 8) | data[14];
      int totalRaw = (data[15] << 8) | data[16];

      double clubSpeedVal = clubSpRaw / 10.0;
      double ballSpeedVal = ballSpRaw / 10.0;
      double carryDistVal = carryRaw / 10.0;
      double totalDistVal = totalRaw / 10.0;

      return ParsedNotification(
        batteryLevel: batteryCap,
        clubName: (clubIdx < clubNames.length) ? clubNames[clubIdx] : "Unknown",
        clubSpeed: clubSpeedVal,
        ballSpeed: ballSpeedVal,
        carryDistance: carryDistVal,
        totalDistance: totalDistVal,
      );
    } else if (cmd == 2) {
      print("Received upload record response");
      return null; // Extend if needed
    } else {
      print("Unknown CMD in notification: $cmd");
      return null;
    }
  }
}
