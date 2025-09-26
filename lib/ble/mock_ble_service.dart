import 'dart:math';

class MockDataGenerator {
  static final Random _random = Random();

  /// Generate fake sync notification data according to protocol specification (18 bytes)
  static List<int> generateSyncNotification() {
    // Generate realistic golf data
    int batteryLevel = _random.nextInt(4); // 0-3 (empty, low, medium, full)
    int maxRecords = 500; // Fixed as per protocol
    int currentRecord = _random.nextInt(maxRecords + 1); // 0-500
    int clubIndex = _random.nextInt(25); // 0-24 (25 club types)

    // Generate realistic swing data
    int clubSpeedRaw = _random.nextInt(1000) + 300; // 30.0-130.0 mph (300-1300 raw)
    int ballSpeedRaw = (clubSpeedRaw * (1.3 + _random.nextDouble() * 0.4)).round(); // Realistic ball speed
    int carryDistanceRaw = _random.nextInt(2500) + 500; // 50-300 yards
    int totalDistanceRaw = carryDistanceRaw + _random.nextInt(300); // Total > carry

    // Ensure values are within protocol limits (0-0x270F = 0-9999)
    clubSpeedRaw = clubSpeedRaw.clamp(0, 0x270F);
    ballSpeedRaw = ballSpeedRaw.clamp(0, 0x270F);
    carryDistanceRaw = carryDistanceRaw.clamp(0, 0x270F);
    totalDistanceRaw = totalDistanceRaw.clamp(0, 0x270F);

    List<int> data = [
      0x47, 0x4C,                                    // Header "GL"
      0x01,                                          // CMD = 1 (sync info)
      batteryLevel,                                  // Battery level (0-3)
      (maxRecords >> 8) & 0xFF, maxRecords & 0xFF,  // Max records (big-endian)
      (currentRecord >> 8) & 0xFF, currentRecord & 0xFF, // Current record (big-endian)
      clubIndex,                                     // Club index (0-24)
      (clubSpeedRaw >> 8) & 0xFF, clubSpeedRaw & 0xFF,   // Club speed (big-endian)
      (ballSpeedRaw >> 8) & 0xFF, ballSpeedRaw & 0xFF,   // Ball speed (big-endian)
      (carryDistanceRaw >> 8) & 0xFF, carryDistanceRaw & 0xFF, // Carry distance (big-endian)
      (totalDistanceRaw >> 8) & 0xFF, totalDistanceRaw & 0xFF, // Total distance (big-endian)
      0x00                                           // Checksum placeholder
    ];

    // Calculate checksum: sum of bytes 3-17 (indexes 2-16)
    int checksum = 0;
    for (int i = 2; i < 17; i++) {
      checksum += data[i];
    }
    data[17] = checksum & 0xFF;

    return data;
  }

  /// Generate fake record upload notification data according to protocol (15 bytes)
  static List<int> generateRecordNotification({int? recordNumber}) {
    recordNumber ??= _random.nextInt(500) + 1; // 1-500
    int clubIndex = _random.nextInt(25); // 0-24

    // Generate realistic swing data
    int clubSpeedRaw = _random.nextInt(1000) + 300; // 30.0-130.0 mph
    int ballSpeedRaw = (clubSpeedRaw * (1.3 + _random.nextDouble() * 0.4)).round();
    int carryDistanceRaw = _random.nextInt(2500) + 500; // 50-300 yards
    int totalDistanceRaw = carryDistanceRaw + _random.nextInt(300);

    // Ensure values are within protocol limits
    clubSpeedRaw = clubSpeedRaw.clamp(0, 0x270F);
    ballSpeedRaw = ballSpeedRaw.clamp(0, 0x270F);
    carryDistanceRaw = carryDistanceRaw.clamp(0, 0x270F);
    totalDistanceRaw = totalDistanceRaw.clamp(0, 0x270F);

    List<int> data = [
      0x47, 0x4C,                                    // Header "GL"
      0x02,                                          // CMD = 2 (record upload)
      (recordNumber >> 8) & 0xFF, recordNumber & 0xFF, // Record number (big-endian)
      clubIndex,                                     // Club index (0-24)
      (clubSpeedRaw >> 8) & 0xFF, clubSpeedRaw & 0xFF,   // Club speed (big-endian)
      (ballSpeedRaw >> 8) & 0xFF, ballSpeedRaw & 0xFF,   // Ball speed (big-endian)
      (carryDistanceRaw >> 8) & 0xFF, carryDistanceRaw & 0xFF, // Carry distance (big-endian)
      (totalDistanceRaw >> 8) & 0xFF, totalDistanceRaw & 0xFF, // Total distance (big-endian)
      0x00                                           // Checksum placeholder
    ];

    // Calculate checksum: sum of bytes 3-14 (indexes 2-13)
    int checksum = 0;
    for (int i = 2; i < 14; i++) {
      checksum += data[i];
    }
    data[14] = checksum & 0xFF;

    return data;
  }

  /// Generate realistic data based on club type
  static List<int> generateRealisticSyncData({int? forClubIndex}) {
    int clubIndex = forClubIndex ?? _random.nextInt(25);

    // Realistic speed ranges based on club type
    Map<int, Map<String, int>> clubRanges = {
      0: {'clubMin': 1000, 'clubMax': 1200, 'carryMin': 2200, 'carryMax': 2800}, // Driver
      1: {'clubMin': 950, 'clubMax': 1150, 'carryMin': 2000, 'carryMax': 2600}, // 2W
      2: {'clubMin': 900, 'clubMax': 1100, 'carryMin': 1800, 'carryMax': 2400}, // 3W
      9: {'clubMin': 800, 'clubMax': 1000, 'carryMin': 1400, 'carryMax': 1800}, // 1i
      17: {'clubMin': 600, 'clubMax': 800, 'carryMin': 1000, 'carryMax': 1300}, // 9i
      18: {'clubMin': 500, 'clubMax': 700, 'carryMin': 800, 'carryMax': 1100}, // PW
      21: {'clubMin': 400, 'clubMax': 600, 'carryMin': 600, 'carryMax': 900}, // SW
    };

    // Use specific ranges if available, otherwise use default
    Map<String, int> ranges = clubRanges[clubIndex] ??
        {'clubMin': 600, 'clubMax': 900, 'carryMin': 1200, 'carryMax': 1800};

    int batteryLevel = _random.nextInt(4);
    int maxRecords = 500;
    int currentRecord = _random.nextInt(maxRecords + 1);

    int clubSpeedRaw = _random.nextInt(ranges['clubMax']! - ranges['clubMin']!) + ranges['clubMin']!;
    int ballSpeedRaw = (clubSpeedRaw * (1.2 + _random.nextDouble() * 0.3)).round();
    int carryDistanceRaw = _random.nextInt(ranges['carryMax']! - ranges['carryMin']!) + ranges['carryMin']!;
    int totalDistanceRaw = carryDistanceRaw + _random.nextInt(200) + 50;

    // Ensure values are within protocol limits
    clubSpeedRaw = clubSpeedRaw.clamp(0, 0x270F);
    ballSpeedRaw = ballSpeedRaw.clamp(0, 0x270F);
    carryDistanceRaw = carryDistanceRaw.clamp(0, 0x270F);
    totalDistanceRaw = totalDistanceRaw.clamp(0, 0x270F);

    List<int> data = [
      0x47, 0x4C,                                    // Header "GL"
      0x01,                                          // CMD = 1 (sync info)
      batteryLevel,                                  // Battery level (0-3)
      (maxRecords >> 8) & 0xFF, maxRecords & 0xFF,  // Max records (big-endian)
      (currentRecord >> 8) & 0xFF, currentRecord & 0xFF, // Current record (big-endian)
      clubIndex,                                     // Club index (0-24)
      (clubSpeedRaw >> 8) & 0xFF, clubSpeedRaw & 0xFF,   // Club speed (big-endian)
      (ballSpeedRaw >> 8) & 0xFF, ballSpeedRaw & 0xFF,   // Ball speed (big-endian)
      (carryDistanceRaw >> 8) & 0xFF, carryDistanceRaw & 0xFF, // Carry distance (big-endian)
      (totalDistanceRaw >> 8) & 0xFF, totalDistanceRaw & 0xFF, // Total distance (big-endian)
      0x00                                           // Checksum placeholder
    ];

    // Calculate checksum: sum of bytes 3-17 (indexes 2-16)
    int checksum = 0;
    for (int i = 2; i < 17; i++) {
      checksum += data[i];
    }
    data[17] = checksum & 0xFF;

    return data;
  }

  /// Generate a sequence of realistic shots for testing
  static List<List<int>> generateShotSequence({int shotCount = 5}) {
    List<List<int>> shots = [];

    for (int i = 0; i < shotCount; i++) {
      // Vary the club occasionally
      int clubIndex = i % 3 == 0 ? _random.nextInt(25) : 0; // Mostly driver shots
      shots.add(generateRealisticSyncData(forClubIndex: clubIndex));
    }

    return shots;
  }

  /// Simple test method without dependencies
  static void testMockData() {
    final mockData = generateSyncNotification();
    print("Generated mock sync data: $mockData");
    print("Data length: ${mockData.length} bytes (should be 18)");

    final recordData = generateRecordNotification();
    print("Generated mock record data: $recordData");
    print("Data length: ${recordData.length} bytes (should be 15)");
  }
}