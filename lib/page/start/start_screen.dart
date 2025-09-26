import 'dart:async';
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
  bool _permissionsGranted = false;
  String? _statusMessage;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();

    isRunningOnSimulator().then((simulator) {
      setState(() {
        _isSimulator = simulator;
      });
    });

    // Check permissions on startup
    _checkPermissions();

    // Listen to connection status
    _bleManager.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          if (connected) {
            _statusMessage = "Connected successfully! Device is ready.";
            _connectingDeviceId = null;
          } else {
            if (_connectingDeviceId != null) {
              _statusMessage = "Connection failed. Please try again.";
              _connectingDeviceId = null;
            }
          }
        });
      }
    });
  }

  Future<void> _checkPermissions() async {
    try {
      setState(() {
        _statusMessage = "Checking Bluetooth permissions...";
      });

      final permissionsGranted = await _bleManager.requestPermissions();

      setState(() {
        _permissionsGranted = permissionsGranted;
        if (permissionsGranted) {
          _statusMessage = "Permissions granted. Bluetooth is ready.";
        } else {
          _statusMessage = "Bluetooth permissions required. Please enable Bluetooth and grant location permissions.";
        }
      });

      if (permissionsGranted) {
        // Check Bluetooth status
        final bleStatus = await _bleManager.getBluetoothStatus();
        setState(() {
          switch (bleStatus) {
            case BleStatus.ready:
              _statusMessage = "Bluetooth ready. You can start scanning for GL-XXXXXX devices.";
              break;
            case BleStatus.poweredOff:
              _statusMessage = "Please turn ON Bluetooth in your device settings.";
              break;
            case BleStatus.unauthorized:
              _statusMessage = "Bluetooth permissions denied. Please grant permissions in app settings.";
              break;
            case BleStatus.locationServicesDisabled:
              _statusMessage = "Please enable Location Services for Bluetooth scanning.";
              break;
            default:
              _statusMessage = "Bluetooth status: $bleStatus. Please check your Bluetooth settings.";
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error checking permissions: $e";
        _permissionsGranted = false;
      });
    }
  }

  Future<void> _startScan() async {
    // Double check permissions and Bluetooth status before scanning
    if (!_permissionsGranted) {
      await _checkPermissions();
      if (!_permissionsGranted) {
        _showPermissionDialog();
        return;
      }
    }

    // Check if Bluetooth is enabled
    final bleEnabled = await _bleManager.isBluetoothEnabled();
    if (!bleEnabled) {
      _showBluetoothDialog();
      return;
    }

    setState(() {
      _scanning = true;
      _foundDevices.clear();
      _statusMessage = "Scanning for GL-XXXXXX devices...";
    });

    _bleManager.startDeviceScan((device) {
      setState(() {
        // Check if device already exists to avoid duplicates
        final existingIndex = _foundDevices.indexWhere((d) => d.id == device.id);
        if (existingIndex >= 0) {
          _foundDevices[existingIndex] = device; // Update existing
        } else {
          _foundDevices.add(device); // Add new
        }

        if (_foundDevices.isNotEmpty) {
          _statusMessage = "Found ${_foundDevices.length} GL device(s). Tap to connect.";
        }
      });
    });

    // Stop scanning after 30 seconds
    Timer(Duration(seconds: 30), () {
      if (_scanning && mounted) {
        _stopScan();
      }
    });
  }

  void _stopScan() {
    _bleManager.stopScan();
    setState(() {
      _scanning = false;
      if (_foundDevices.isEmpty) {
        _statusMessage = "No GL-XXXXXX devices found. Make sure your device is powered on and nearby.";
      } else {
        _statusMessage = "Scan stopped. Found ${_foundDevices.length} GL device(s).";
      }
    });
  }

  void _connectToDevice(DiscoveredDevice device) {
    final deviceDisplayName = device.name.isNotEmpty ? device.name : 'GL Device';

    setState(() {
      _statusMessage = "Connecting to $deviceDisplayName...";
      _connectingDeviceId = device.id;
    });

    // Stop scanning first
    if (_scanning) {
      _bleManager.stopScan();
      _scanning = false;
    }

    // Clear any stuck connections first
    _bleManager.clearStuckConnections().then((_) {
      // Add a small delay before connecting
      Future.delayed(Duration(milliseconds: 500), () {
        _bleManager.connectToDeviceById(device.id, () {
          // Connection successful - navigate to home screen
          if (mounted) {
            setState(() {
              _statusMessage = "Connected to $deviceDisplayName! Entering operation mode...";
            });

            // Navigate to home screen after a short delay
            Future.delayed(Duration(milliseconds: 1000), () {
              if (mounted) {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => HomeScreen())
                );
              }
            });
          }
        });
      });
    });

    // Add connection timeout
    Timer(Duration(seconds: 25), () {
      if (mounted && _connectingDeviceId == device.id) {
        setState(() {
          _statusMessage = "Connection timeout. Please ensure the device is powered on and try again.";
          _connectingDeviceId = null;
        });
        _bleManager.clearStuckConnections();
      }
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Permissions Required"),
        content: Text(
            "This app needs Bluetooth and Location permissions to scan for GL devices. "
                "Please grant these permissions in your device settings.\n\n"
                "Required permissions:\n"
                "• Bluetooth\n"
                "• Location (for BLE scanning)"
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermissions(); // Try again
            },
            child: Text("Retry"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Bluetooth Required"),
        content: Text(
            "Please enable Bluetooth in your device settings to scan for GL devices.\n\n"
                "Steps:\n"
                "1. Go to Settings\n"
                "2. Turn ON Bluetooth\n"
                "3. Return to this app and tap Retry"
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermissions(); // Check again
            },
            child: Text("Retry"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _startMockMode() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
  }

  Color _getStatusColor() {
    if (_statusMessage == null) return Colors.grey;

    if (_statusMessage!.contains("ready") ||
        _statusMessage!.contains("Connected") ||
        _statusMessage!.contains("granted")) {
      return Colors.green;
    } else if (_statusMessage!.contains("timeout") ||
        _statusMessage!.contains("failed") ||
        _statusMessage!.contains("Error")) {
      return Colors.red;
    } else if (_statusMessage!.contains("Connecting") ||
        _statusMessage!.contains("Scanning")) {
      return Colors.blue;
    } else if (_statusMessage!.contains("required") ||
        _statusMessage!.contains("Please")) {
      return Colors.orange;
    }

    return Colors.grey;
  }

  @override
  void dispose() {
    _bleManager.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Club Launch Monitor'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status message with dynamic color
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _connectingDeviceId != null ? Icons.bluetooth_searching :
                    (_permissionsGranted ? Icons.bluetooth : Icons.bluetooth_disabled),
                    color: _getStatusColor(),
                    size: 24,
                  ),
                  SizedBox(height: 8),
                  Text(
                    _statusMessage ?? "Initializing...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_connectingDeviceId != null) ...[
                    SizedBox(height: 12),
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Simulator mock mode button
            if (_isSimulator) ...[
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _startMockMode,
                  icon: Icon(Icons.developer_mode),
                  label: Text('Use Mock Data (Simulator Mode)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],

            // Main scan button
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: (_connectingDeviceId != null) ? null : (_scanning ? _stopScan : _startScan),
                icon: Icon(_scanning ? Icons.stop : Icons.search),
                label: Text(
                  _scanning ? 'Stop Scanning' : 'Scan for GL Devices',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _scanning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey[700],
                ),
              ),
            ),

            // Permissions retry button
            if (!_permissionsGranted) ...[
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _checkPermissions,
                  icon: Icon(Icons.refresh),
                  label: Text('Retry Permissions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            // Device list
            Expanded(
              child: _foundDevices.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _scanning ? Icons.search : Icons.bluetooth_disabled,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    SizedBox(height: 16),
                    Text(
                      _scanning
                          ? 'Searching for GL devices...'
                          : 'No GL devices found.\n\nMake sure your club launch monitor is:\n• Powered ON\n• Within range (10-30 feet)\n• Not connected to another device',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _foundDevices.length,
                itemBuilder: (context, index) {
                  final device = _foundDevices[index];
                  final isConnecting = _connectingDeviceId == device.id;

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: Card(
                      color: Colors.grey[900],
                      elevation: 4,
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.golf_course,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          device.name.isNotEmpty ? device.name : 'Unknown',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID: ${device.id}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Signal: ${device.rssi} dBm',
                              style: TextStyle(
                                color: device.rssi > -70 ? Colors.green : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: isConnecting
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        )
                            : Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                        onTap: isConnecting ? null : () => _connectToDevice(device),
                        enabled: !isConnecting,
                      ),
                    ),
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