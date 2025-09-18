import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:slurvo/ble/ble_manager.dart';
import 'package:slurvo/page/home/home_screen.dart';
import 'package:slurvo/utils/platform_utils.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final BleManager _bleManager = BleManager();

  List<DiscoveredDevice> _foundDevices = [];
  bool _scanning = false;
  bool _isSimulator = false;

  @override
  void initState() {
    super.initState();

    isRunningOnSimulator().then((simulator) {
      setState(() {
        _isSimulator = simulator;
      });
    });
  }

  void _startScan() {
    setState(() {
      _scanning = true;
      _foundDevices.clear();
    });

    _bleManager.startDeviceScan((device) {
      setState(() {
        _foundDevices.add(device);
        _scanning = false;
      });
    });
  }

  void _connectToDevice(DiscoveredDevice device) {
    _bleManager.connectToDeviceById(device.id, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    });
  }

  void _startMockMode() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Start Screen'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isSimulator)
              ElevatedButton(
                onPressed: _startMockMode,
                child: const Text('Use Mock Data (Simulator)'),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _scanning ? null : _startScan,
              child: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _foundDevices.length,
                itemBuilder: (context, index) {
                  final device = _foundDevices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.id),
                    onTap: () => _connectToDevice(device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
