import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:slurvo/ble/ble_manager.dart';
import 'package:slurvo/ble/mock_ble_service.dart';
import 'package:slurvo/page/home/widget/anaylysis_card_view.dart';
import 'package:slurvo/page/home/widget/customize_option_view.dart';
import 'package:slurvo/page/start/start_screen.dart';
import 'package:slurvo/utils/platform_utils.dart';

class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final BleManager _bleManager = BleManager();
  Timer? _syncTimer;

  bool _connected = false;
  String batteryLevel = "";
  String clubName = "";
  double clubSpeed = 0.0;
  double ballSpeed = 0.0;
  double carryDistance = 0.0;
  double totalDistance = 0.0;

  @override
  void initState() {
    super.initState();

    isRunningOnSimulator().then((simulator) async {
      if (simulator) {
        print("Running on simulator — using mock BLE data");
        _startMockMode();
      } else {
        bool permissionGranted = await _bleManager.requestPermissions();
        if (permissionGranted) {
          _bleManager.startScan(onDeviceFound: _onDeviceFound);
        } else {
          print("Bluetooth permissions not granted.");
        }
      }
    });

    _bleManager.connectionStream.listen((connected) {
      setState(() {
        _connected = connected;
      });
    });

    _bleManager.notificationStream.listen((data) {
      _handleNotification(data);
    });
  }

  void _onDeviceFound() {
    setState(() {
      _connected = true;
    });

    _startSyncTimer();
  }

  void _startMockMode() {
    setState(() {
      _connected = true;
    });

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(seconds: 1), (_) {
      final data = MockDataGenerator.generateFakeData();
      _handleNotification(data);
    });
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _bleManager.sendSyncCommand();
    });
  }

  void _handleNotification(List<int> data) {
    final parsed = _bleManager.parseNotification(data);
    if (parsed != null) {
      setState(() {
        batteryLevel = parsed.batteryLevel.toString();
        clubName = parsed.clubName;
        clubSpeed = parsed.clubSpeed;
        ballSpeed = parsed.ballSpeed;
        carryDistance = parsed.carryDistance;
        totalDistance = parsed.totalDistance;
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _bleManager.dispose();
    super.dispose();
  }


  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xff111111),
        leading: const Icon(Icons.person),
        title: const Text("SLURVO", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.settings))],
      ),
      body: Column(
        children: [

          Divider(height: 0.5, color: Colors.white,),

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
                        Navigator.pop(context);  // goes back to the previous screen
                      },
                    ),

                    SizedBox(width: 10),
                    Text("Shot Analysis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
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
                    AnalysisCardView(title: "Battery", value: "$batteryLevel%", unit: ""),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        child: const Text("Delete Shot"),
                      ),
                    ),
                    const SizedBox(width: 10), // Add a little space between the buttons
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

class AnaylysisCardView {
}