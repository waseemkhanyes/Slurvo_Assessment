import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:slurvo/ble/ble_manager.dart';
import 'package:slurvo/ble/ble_service.dart';
import 'package:slurvo/ble/mock_ble_service.dart';
import 'package:slurvo/page/home/widget/anaylysis_card_view.dart';
import 'package:slurvo/page/home/widget/customize_option_view.dart';
import 'package:slurvo/page/start/start_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isMockMode;

  const HomeScreen({super.key, required this.isMockMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleManager _bleManager = BleManager();
  Timer? _syncTimer;

  bool _connected = false;
  String batteryLevel = "0";
  String clubName = "Driver";
  double clubSpeed = 0.0;
  double ballSpeed = 0.0;
  double carryDistance = 0.0;
  double totalDistance = 0.0;

  @override
  void initState() {
    super.initState();

    // Check if already connected from StartScreen or using mock mode
    if (widget.isMockMode) {
      print("Starting in mock mode");
      _startMockMode();
    } else if (_bleManager.isConnected) {
      setState(() {
        _connected = true;
      });
      _startRealDataSync();
    } else {
      // Check permissions for real device
      _bleManager.requestPermissions().then((permissionGranted) {
        if (!permissionGranted) {
          print("Bluetooth permissions not granted.");
        }
      });
    }

    _bleManager.connectionStream.listen((connected) {
      setState(() {
        _connected = connected;
      });
      if (connected && !widget.isMockMode) {
        _startRealDataSync();
      }
    });

    _bleManager.notificationStream.listen((data) {
      _handleNotification(data);
    });
  }

  void _startMockMode() {
    setState(() {
      _connected = true;
    });

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) {
        // Generate mock data and handle it
        final mockData = MockDataGenerator.generateSyncNotification();
        print("Generated mock data: $mockData");
        _handleNotification(mockData);
      }
    });

    print("Mock mode started - generating data every 2 seconds");
  }

  void _startRealDataSync() {
    print("Real BLE data sync active");
    // Real data sync is handled by BleManager's internal timer
  }

  void _handleNotification(List<int> data) {
    print("Received notification data: $data");

    final parsed = BleDataParser.parseNotification(data);
    if (parsed != null) {
      setState(() {
        if (parsed.containsKey('batteryLevel')) {
          int batteryLevelInt = parsed['batteryLevel'];
          // Convert battery level to percentage
          switch (batteryLevelInt) {
            case 0: batteryLevel = "0"; break;
            case 1: batteryLevel = "25"; break;
            case 2: batteryLevel = "60"; break;
            case 3: batteryLevel = "100"; break;
            default: batteryLevel = "0"; break;
          }
        }

        clubName = parsed['clubName'] ?? "Unknown";
        clubSpeed = (parsed['clubSpeed'] ?? 0.0).toDouble();
        ballSpeed = (parsed['ballSpeed'] ?? 0.0).toDouble();
        carryDistance = (parsed['carryDistance'] ?? 0.0).toDouble();
        totalDistance = (parsed['totalDistance'] ?? 0.0).toDouble();
      });

      print("UI updated - Club: $clubName, Club Speed: ${clubSpeed}mph, Ball Speed: ${ballSpeed}mph");
    } else {
      print("Failed to parse notification data: $data");
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    if (widget.isMockMode) {
      // Only dispose if we created it in mock mode
      _bleManager.dispose();
    }
    super.dispose();
  }

  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xff111111),
        leading: const Icon(Icons.person),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("SLURVO", style: TextStyle(fontWeight: FontWeight.bold)),
            if (widget.isMockMode) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "DEMO",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: _connected ? Colors.green : Colors.red,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Divider(height: 0.5, color: Colors.white),

          // Connection status
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _connected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  _connected ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: _connected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  _connected
                      ? (widget.isMockMode ? "Mock Data Active" : "Device Connected")
                      : "Device Disconnected",
                  style: TextStyle(
                    color: _connected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    SizedBox(width: 10),
                    Text("Shot Analysis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 15),

                // Current club display
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.golf_course, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Text(
                        "Current Club: $clubName",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),
                CustomizeOptionView(),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    AnalysisCardView(title: "Ball Speed", value: ballSpeed.toStringAsFixed(1), unit: "MPH"),
                    AnalysisCardView(title: "Club Speed", value: clubSpeed.toStringAsFixed(1), unit: "MPH"),
                    AnalysisCardView(title: "Carry Distance", value: carryDistance.toStringAsFixed(1), unit: "YDS"),
                    AnalysisCardView(title: "Total Distance", value: totalDistance.toStringAsFixed(1), unit: "YDS"),
                    AnalysisCardView(title: "Battery", value: "${batteryLevel}%", unit: ""),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Clear shot data
                          setState(() {
                            clubSpeed = 0.0;
                            ballSpeed = 0.0;
                            carryDistance = 0.0;
                            totalDistance = 0.0;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        child: const Text("Clear Shot"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text("Dispersion"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Text("Session View", style: TextStyle(fontSize: 18)),
                ),

                // Debug info for mock mode
                if (widget.isMockMode) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Debug Info (Mock Mode)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Mock data updating every 2 seconds",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home Page"),
          BottomNavigationBarItem(icon: Icon(Icons.golf_course), label: "Shot Analysis"),
          BottomNavigationBarItem(icon: Icon(Icons.videogame_asset), label: "Practice Games"),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: "Shot Library"),
        ],
      ),
    );
  }
}