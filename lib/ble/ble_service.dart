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
  static const List<String> clubNames = [
    "Driver", "2W", "3W", "4W", "5W", "6W", "7W", "8W", "9W",
    "1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i",
    "PW", "GW", "AW", "SW", "LW", "PT1", "PT2"
  ];

  static Map<String, dynamic>? parseNotification(List<int> data) {
    if (data.length < 3) {
      print("** Data too short: ${data.length} bytes");
      return null;
    }

    // Check header "GL" (0x47, 0x4C)
    if (data[0] != 0x47 || data[1] != 0x4C) {
      print("** Invalid header: [${data[0]}, ${data[1]}]");
      return null;
    }

    int cmd = data[2];
    print("** Parsing command: $cmd, length: ${data.length}");

    if (cmd == 1 && data.length == 18) {
      // Sync notification (18 bytes)
      return _parseSyncNotification(data);
    } else if (cmd == 2 && data.length == 15) {
      // Record notification (15 bytes)
      return _parseRecordNotification(data);
    } else {
      print("** Unknown command or invalid length: cmd=$cmd, length=${data.length}");
      return null;
    }
  }

  static Map<String, dynamic> _parseSyncNotification(List<int> data) {
    try {
      int batteryLevel = data[3];
      int maxRecords = (data[4] << 8) | data[5];
      int currentRecord = (data[6] << 8) | data[7];
      int clubIndex = data[8];

      // Parse big-endian 16-bit values
      int clubSpeedRaw = (data[9] << 8) | data[10];
      int ballSpeedRaw = (data[11] << 8) | data[12];
      int carryDistanceRaw = (data[13] << 8) | data[14];
      int totalDistanceRaw = (data[15] << 8) | data[16];

      // Convert to actual values (divide by 10)
      double clubSpeed = clubSpeedRaw / 10.0;
      double ballSpeed = ballSpeedRaw / 10.0;
      double carryDistance = carryDistanceRaw / 10.0;
      double totalDistance = totalDistanceRaw / 10.0;

      String clubName = clubIndex < clubNames.length ? clubNames[clubIndex] : "Unknown";
      String batteryText = _getBatteryText(batteryLevel);

      print("** Parsed sync data: Club=$clubName, ClubSpeed=${clubSpeed}mph, BallSpeed=${ballSpeed}mph");
      print("** Distances: Carry=${carryDistance}yds, Total=${totalDistance}yds, Battery=$batteryText");

      return {
        'type': 'sync',
        'batteryLevel': batteryLevel,
        'batteryText': batteryText,
        'maxRecords': maxRecords,
        'currentRecord': currentRecord,
        'clubIndex': clubIndex,
        'clubName': clubName,
        'clubSpeed': clubSpeed,
        'ballSpeed': ballSpeed,
        'carryDistance': carryDistance,
        'totalDistance': totalDistance,
        'rawData': data,
      };
    } catch (e) {
      print("** Error parsing sync notification: $e");
      return {};
    }
  }

  static Map<String, dynamic> _parseRecordNotification(List<int> data) {
    try {
      int recordNumber = (data[3] << 8) | data[4];
      int clubIndex = data[5];

      // Parse big-endian 16-bit values
      int clubSpeedRaw = (data[6] << 8) | data[7];
      int ballSpeedRaw = (data[8] << 8) | data[9];
      int carryDistanceRaw = (data[10] << 8) | data[11];
      int totalDistanceRaw = (data[12] << 8) | data[13];

      // Convert to actual values (divide by 10)
      double clubSpeed = clubSpeedRaw / 10.0;
      double ballSpeed = ballSpeedRaw / 10.0;
      double carryDistance = carryDistanceRaw / 10.0;
      double totalDistance = totalDistanceRaw / 10.0;

      String clubName = clubIndex < clubNames.length ? clubNames[clubIndex] : "Unknown";

      print("** Parsed record #$recordNumber: Club=$clubName, ClubSpeed=${clubSpeed}mph, BallSpeed=${ballSpeed}mph");

      return {
        'type': 'record',
        'recordNumber': recordNumber,
        'clubIndex': clubIndex,
        'clubName': clubName,
        'clubSpeed': clubSpeed,
        'ballSpeed': ballSpeed,
        'carryDistance': carryDistance,
        'totalDistance': totalDistance,
        'rawData': data,
      };
    } catch (e) {
      print("** Error parsing record notification: $e");
      return {};
    }
  }

  static String _getBatteryText(int level) {
    switch (level) {
      case 0: return "Empty";
      case 1: return "Low";
      case 2: return "Medium";
      case 3: return "Full";
      default: return "Unknown";
    }
  }

  static int _getBatteryPercentage(int level) {
    switch (level) {
      case 0: return 0;
      case 1: return 25;
      case 2: return 60;
      case 3: return 100;
      default: return 0;
    }
  }

  // Helper method for testing
  static void testParser() {
    print("** Testing BLE Data Parser");

    // Test sync data
    List<int> testSyncData = [
      0x47, 0x4C, 0x01, 0x02, 0x01, 0xF4, 0x00, 0x64, 0x00,
      0x03, 0x84, 0x04, 0xB0, 0x05, 0xDC, 0x07, 0x08, 0x00
    ];

    var parsed = parseNotification(testSyncData);
    if (parsed != null) {
      print("** Test sync parsing successful");
    } else {
      print("** Test sync parsing failed");
    }
  }
}
