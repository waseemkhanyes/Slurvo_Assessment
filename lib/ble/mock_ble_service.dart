import 'dart:typed_data';
import 'dart:math';
import '../models/club_names.dart';

class MockDataGenerator {
  static List<int> generateFakeData() {
    final random = Random();

    // Use a Random object for more robust random numbers
    int batteryLevel = random.nextInt(4); // 0-3
    int currentRecordNumber = random.nextInt(100); // 0-99
    int clubIndex = random.nextInt(clubNames.length);
    int clubSpeed = random.nextInt(601) + 100; // 10.0 to 70.0 (100-700)
    int ballSpeed = random.nextInt(901) + 100; // 10.0 to 100.0 (100-1000)
    int carryDistance = random.nextInt(1001) + 100; // 10.0 to 110.0 (100-1100)
    int totalDistance = random.nextInt(1001) + 100; // 10.0 to 110.0 (100-1100)

    List<int> fakeData = [
      0x47, 0x4C,           // Header "GL"
      0x01,                 // CMD = 1 (sync info)
      batteryLevel,         // Battery level (0-3)
      0x01, 0xF4,           // Max record = 500 (this is a fixed value, often for a specific device)
      0x00, currentRecordNumber,   // Current record number
      clubIndex,            // Club index
      (clubSpeed >> 8) & 0xFF, clubSpeed & 0xFF, // Club speed
      (ballSpeed >> 8) & 0xFF, ballSpeed & 0xFF, // Ball speed
      (carryDistance >> 8) & 0xFF, carryDistance & 0xFF, // Carry distance
      (totalDistance >> 8) & 0xFF, totalDistance & 0xFF, // Total distance
      0x00                  // Checksum placeholder
    ];

    // Calculate checksum (sum bytes 3 to 17 inclusive)
    // The range for the checksum calculation should be from the CMD byte to the byte before the checksum placeholder.
    // In this case, that's from index 2 to 16.
    int checksum = fakeData.sublist(2, 16).fold(0, (a, b) => a + b) & 0xFF;
    fakeData[16] = checksum;

    return fakeData;
  }
}





// import 'dart:typed_data';
// import '../models/club_names.dart';
//
// class MockDataGenerator {
//   static List<int> generateFakeData() {
//     final random = DateTime.now().second;
//
//     List<int> fakeData = [
//       0x47, 0x4C,           // Header "GL"
//       0x01,                 // CMD = 1 (sync info)
//       random % 4,           // Battery level (0-3)
//       0x01, 0xF4,           // Max record = 500
//       0x00, random % 100,   // Current record number
//       random % clubNames.length, // Club index
//       0x01, 0xF4,           // Club speed = 500 -> 50.0
//       0x02, 0xBC,           // Ball speed = 700 -> 70.0
//       0x03, 0xE8,           // Carry distance = 1000 -> 100.0
//       0x04, 0x38,           // Total distance = 1080 -> 108.0
//       0x00                  // Checksum placeholder
//     ];
//
//     // Calculate checksum (sum bytes 3 to 16 inclusive)
//     int checksum = fakeData.sublist(3, 17).fold(0, (a, b) => a + b) & 0xFF;
//     fakeData[17] = checksum;
//
//     return fakeData;
//   }
// }
