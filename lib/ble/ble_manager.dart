import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ble_device.dart';
import 'ble_service.dart';

class BleManager {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  StreamSubscription<List<int>>? _notificationSubscription;

  late QualifiedCharacteristic _writeCharacteristic;
  late QualifiedCharacteristic _notifyCharacteristic;

  DiscoveredDevice? _foundDevice;
  String? deviceName;
  bool _isConnected = false;

  // Auto-sync timer - protocol requires sending every second
  Timer? _syncTimer;
  int _sleepTime = 5; // Default sleep time in minutes
  int _clubIndex = 0; // Default club index

  final Set<String> _discoveredDeviceIds = <String>{};

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final StreamController<dynamic> _notificationController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get notificationStream => _notificationController.stream;

  // Getter to check connection status
  bool get isConnected => _isConnected;

  // Method to check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      final status = await _ble.statusStream.first.timeout(Duration(seconds: 3));
      return status == BleStatus.ready;
    } catch (e) {
      print("** Error checking Bluetooth status: $e");
      return false;
    }
  }

  // Method to get current Bluetooth status
  Future<BleStatus> getBluetoothStatus() async {
    try {
      return await _ble.statusStream.first.timeout(Duration(seconds: 3));
    } catch (e) {
      print("** Error getting Bluetooth status: $e");
      return BleStatus.unknown;
    }
  }

  Future<bool> requestPermissions() async {
    // First check if Bluetooth is enabled
    final bleStatus = await _ble.statusStream.first;
    print("** Current BLE Status: $bleStatus");

    if (bleStatus != BleStatus.ready) {
      print("** Bluetooth is not ready. Status: $bleStatus");
      if (bleStatus == BleStatus.poweredOff) {
        print("** Please enable Bluetooth in device settings");
        return false;
      } else if (bleStatus == BleStatus.unauthorized) {
        print("** Bluetooth permissions not granted");
      }
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    print("** Permission status: $statuses");

    // Check BLE status again after permissions
    final bleStatusAfter = await _ble.statusStream.first.timeout(
      Duration(seconds: 2),
      onTimeout: () => BleStatus.unknown,
    );
    print("** BLE Status after permissions: $bleStatusAfter");

    return allGranted && bleStatusAfter == BleStatus.ready;
  }

  void startDeviceScan(Function(DiscoveredDevice) onDeviceFound) {
    print("** Starting BLE scan for GL-XXXXXX devices...");

    // Check BLE status before scanning
    _ble.statusStream.listen((status) {
      print("** BLE Status: $status");
      if (status == BleStatus.poweredOff) {
        print("** ERROR: Bluetooth is turned off. Please enable Bluetooth.");
        return;
      } else if (status == BleStatus.unauthorized) {
        print("** ERROR: Bluetooth permissions not granted.");
        return;
      }
    });

    _checkBleStatusAndScan(onDeviceFound);
  }

  Future<void> _checkBleStatusAndScan(Function(DiscoveredDevice) onDeviceFound) async {
    try {
      final status = await _ble.statusStream.first.timeout(Duration(seconds: 3));

      if (status != BleStatus.ready) {
        print("** Cannot start scan. BLE Status: $status");
        if (status == BleStatus.poweredOff) {
          throw Exception("Bluetooth is turned off. Please enable Bluetooth in settings.");
        } else if (status == BleStatus.unauthorized) {
          throw Exception("Bluetooth permissions denied. Please grant Bluetooth permissions.");
        } else {
          throw Exception("Bluetooth not available. Status: $status");
        }
        return;
      }

      _performDeviceScan(onDeviceFound);
    } catch (e) {
      print("** BLE Status check error: $e");
    }
  }

  void _performDeviceScan(Function(DiscoveredDevice) onDeviceFound) {
    _scanSub?.cancel();
    _discoveredDeviceIds.clear();

    // First try scanning with the specific service UUID
    _scanSub = _ble.scanForDevices(
      withServices: [BleDevice.serviceUuid],
      scanMode: ScanMode.lowLatency,
      requireLocationServicesEnabled: false,
    ).listen((device) {
      _handleDiscoveredDevice(device, onDeviceFound);
    }, onError: (error) {
      print("** Service-specific scan error: $error");
      _retryGenericScan(onDeviceFound);
    });

    // Add timeout to prevent infinite scanning
    Timer(Duration(seconds: 15), () {
      if (_scanSub != null && !_scanSub!.isPaused) {
        print("** Service scan timeout, trying generic scan");
        _retryGenericScan(onDeviceFound);
      }
    });
  }

  void _handleDiscoveredDevice(DiscoveredDevice device, Function(DiscoveredDevice) onDeviceFound) {
    if (_discoveredDeviceIds.contains(device.id)) {
      return;
    }

    // Filter for GL- prefix devices according to protocol
    // if (!device.name.startsWith("GL-")) {
    //   return;
    // }

    _discoveredDeviceIds.add(device.id);

    print("** Found GL device:");
    print("   Name: '${device.name}'");
    print("   ID: ${device.id}");
    print("   RSSI: ${device.rssi}");
    print("   Connectable: ${device.connectable}");
    print("   Services: ${device.serviceUuids}");
    print("---");

    onDeviceFound(device);
  }

  // Retry with generic scan if service-specific scan fails
  void _retryGenericScan(Function(DiscoveredDevice) onDeviceFound) {
    _scanSub?.cancel();

    _scanSub = _ble.scanForDevices(
      withServices: [], // Scan for all devices
      scanMode: ScanMode.lowLatency,
      requireLocationServicesEnabled: false,
    ).listen((device) {
      _handleDiscoveredDevice(device, onDeviceFound);
    }, onError: (error) {
      print("** Generic scan error: $error");
    });

    // Add timeout for generic scan
    Timer(Duration(seconds: 30), () {
      if (_scanSub != null && !_scanSub!.isPaused) {
        print("** Generic scan timeout reached");
        stopScan();
      }
    });
  }

  // Method to stop scanning
  void stopScan() {
    print("** Stopping scan");
    _scanSub?.cancel();
    _scanSub = null;
  }

  // Connect to device by ID - Simplified and more reliable approach
  void connectToDeviceById(String deviceId, VoidCallback onConnected) {
    print("** Attempting to connect to device: $deviceId");
    _connection?.cancel();

    // Clear any existing state
    _isConnected = false;
    _stopSyncTimer();

    // Use simple connectToDevice method first
    _connectSimple(deviceId, onConnected);
  }

  void _connectSimple(String deviceId, VoidCallback onConnected) {
    print("** Using simple connection method");

    _connection = _ble.connectToDevice(id: deviceId).listen(
          (connectionState) async {
        print("** Connection state: ${connectionState.connectionState}");
        print("** Device ID: ${connectionState.deviceId}");

        if (connectionState.failure != null) {
          print("** Connection failure: ${connectionState.failure}");
        }

        if (connectionState.connectionState == DeviceConnectionState.connected) {
          print("** Successfully connected to device!");

          try {
            await _onConnected(deviceId);
            _isConnected = true;
            WakelockPlus.enable();
            _connectionController.add(true);
            onConnected();
          } catch (e) {
            print("** Error in post-connection setup: $e");
            _handleDisconnection();
          }
        } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
          print("** Device disconnected");
          _handleDisconnection();
        } else if (connectionState.connectionState == DeviceConnectionState.connecting) {
          print("** Device connecting...");
        }
      },
      onError: (error) {
        print("** Connection error: $error");
        _handleDisconnection();

        // Try advanced connection method as fallback
        _connectAdvanced(deviceId, onConnected);
      },
    );

    // Add connection timeout
    Timer(Duration(seconds: 15), () {
      if (_connection != null && !_isConnected) {
        print("** Simple connection timeout, trying advanced method");
        _connection?.cancel();
        _connectAdvanced(deviceId, onConnected);
      }
    });
  }

  void _connectAdvanced(String deviceId, VoidCallback onConnected) {
    print("** Trying advanced connection method");

    Future.delayed(Duration(seconds: 1), () {
      _connection?.cancel();

      _connection = _ble.connectToAdvertisingDevice(
        id: deviceId,
        withServices: [], // Don't filter by services during connection
        prescanDuration: Duration(seconds: 3),
        connectionTimeout: Duration(seconds: 12),
      ).listen(
            (connectionState) async {
          print("** Advanced connection state: ${connectionState.connectionState}");

          if (connectionState.connectionState == DeviceConnectionState.connected) {
            try {
              await _onConnected(deviceId);
              _isConnected = true;
              WakelockPlus.enable();
              _connectionController.add(true);
              onConnected();
            } catch (e) {
              print("** Error in advanced post-connection setup: $e");
              _handleDisconnection();
            }
          } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
            _handleDisconnection();
          }
        },
        onError: (error) {
          print("** Advanced connection error: $error");
          _handleDisconnection();
        },
      );
    });
  }

  void _handleDisconnection() {
    print("** Handling disconnection");
    _isConnected = false;
    _stopSyncTimer();
    WakelockPlus.disable();
    _connectionController.add(false);
    _notificationSubscription?.cancel();
  }

  Future<void> _onConnected(String deviceId) async {
    try {
      print("** Starting service discovery for device: $deviceId");

      // Small delay before service discovery
      await Future.delayed(Duration(milliseconds: 1000));

      final services = await _ble.discoverServices(deviceId);
      print("** Discovered ${services.length} services");

      bool writeCharFound = false;
      bool notifyCharFound = false;

      // Log all discovered services and characteristics
      for (var service in services) {
        print("** Service: ${service.serviceId}");

        if (service.serviceId == BleDevice.serviceUuid) {
          print("** Found target service: ${BleDevice.serviceUuid}");

          for (var char in service.characteristics) {
            print("** Characteristic: ${char.characteristicId}");
            // print("** Properties: ${char.properties}");

            if (char.characteristicId == BleDevice.characteristicWriteUuid) {
              _writeCharacteristic = QualifiedCharacteristic(
                characteristicId: BleDevice.characteristicWriteUuid,
                serviceId: BleDevice.serviceUuid,
                deviceId: deviceId,
              );
              writeCharFound = true;
              print("** Write characteristic configured");
            } else if (char.characteristicId == BleDevice.characteristicNotifyUuid) {
              _notifyCharacteristic = QualifiedCharacteristic(
                characteristicId: BleDevice.characteristicNotifyUuid,
                serviceId: BleDevice.serviceUuid,
                deviceId: deviceId,
              );
              notifyCharFound = true;
              print("** Notify characteristic configured");
            }
          }
        }
      }

      if (!writeCharFound || !notifyCharFound) {
        print("** ERROR: Required characteristics not found");
        print("** Write char found: $writeCharFound, Notify char found: $notifyCharFound");
        throw Exception("Required characteristics not found. Write: $writeCharFound, Notify: $notifyCharFound");
      }

      // Subscribe to notifications
      await _setupNotifications();

      // Start sync timer according to protocol (every 1 second)
      _startSyncTimer();

      print("** Device fully connected and sync timer started");
    } catch (e) {
      print("** Error during service discovery: $e");
      throw e; // Re-throw to handle in calling method
    }
  }

  Future<void> _setupNotifications() async {
    try {
      _notificationSubscription?.cancel();

      _notificationSubscription = _ble.subscribeToCharacteristic(_notifyCharacteristic).listen(
            (data) {
          print("** Received notification: $data");

          // Parse the data to validate it
          final parsedData = BleDataParser.parseNotification(data);
          if (parsedData != null) {
            print("** Parsed data: $parsedData");
            _notificationController.add(data); // Send raw data to HomeScreen for parsing
          } else {
            print("** Failed to parse notification data");
          }
        },
        onError: (e) {
          print("** Notification error: $e");
        },
      );

      print("** Notification subscription successful");
    } catch (e) {
      print("** Failed to setup notifications: $e");
      throw e;
    }
  }

  // Start automatic sync timer according to protocol (every 1 second)
  void _startSyncTimer() {
    _stopSyncTimer();

    print("** Starting sync timer (every 1 second as per protocol)");
    _syncTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isConnected) {
        _sendSyncCommandInternal();
      } else {
        _stopSyncTimer();
      }
    });
  }

  void _stopSyncTimer() {
    if (_syncTimer != null) {
      print("** Stopping sync timer");
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  // Internal method to send sync command (used by timer)
  Future<void> _sendSyncCommandInternal() async {
    if (!_isConnected) {
      print("** Cannot send sync command - not connected");
      return;
    }

    try {
      final cmdBytes = BleDevice.buildSyncCommand(
        sleepTimeMinutes: _sleepTime,
        clubNameIndex: _clubIndex,
      );

      await _ble.writeCharacteristicWithResponse(_writeCharacteristic, value: cmdBytes);
      print("** Auto sync command sent: $cmdBytes");
    } catch (e) {
      print("** Error sending auto sync command: $e");
      // Don't disconnect on sync error, just log it
    }
  }

  // Public method to send sync command manually
  Future<void> sendSyncCommand({int sleepTime = 5, int clubIndex = 0}) async {
    if (!_isConnected) {
      print("** No device connected");
      return;
    }

    // Update internal parameters for future auto-sync
    _sleepTime = sleepTime;
    _clubIndex = clubIndex;

    try {
      final cmdBytes = BleDevice.buildSyncCommand(
        sleepTimeMinutes: sleepTime,
        clubNameIndex: clubIndex,
      );

      await _ble.writeCharacteristicWithResponse(_writeCharacteristic, value: cmdBytes);
      print("** Manual sync command sent: $cmdBytes");
    } catch (e) {
      print("** Error sending manual sync command: $e");
    }
  }

  // Send upload record command
  Future<void> sendUploadRecord(int recordNumber) async {
    if (!_isConnected) {
      print("** No device connected");
      return;
    }

    if (recordNumber < 1 || recordNumber > 500) {
      print("** Invalid record number: $recordNumber (must be 1-500)");
      return;
    }

    try {
      final cmdBytes = BleDevice.buildUploadRecordCommand(recordNumber);
      await _ble.writeCharacteristicWithResponse(_writeCharacteristic, value: cmdBytes);
      print("** Upload record command sent for record #$recordNumber: $cmdBytes");
    } catch (e) {
      print("** Error sending upload record command: $e");
    }
  }

  // Method to clear any stuck connections and reset BLE stack
  Future<void> clearStuckConnections() async {
    print("** Clearing stuck connections");

    _stopSyncTimer();
    _connection?.cancel();
    _notificationSubscription?.cancel();
    _scanSub?.cancel();

    _isConnected = false;
    _foundDevice = null;
    deviceName = null;
    _discoveredDeviceIds.clear();

    _connectionController.add(false);

    // Wait for cleanup
    await Future.delayed(Duration(seconds: 1));

    print("** Connections cleared");
  }

  // Enhanced disconnect method
  void disconnect() async {
    print("** Manual disconnect requested");
    await clearStuckConnections();
  }

  // Method to update sync parameters without sending immediately
  void updateSyncParameters({int? sleepTime, int? clubIndex}) {
    if (sleepTime != null && sleepTime >= 0 && sleepTime <= 255) {
      _sleepTime = sleepTime;
      print("** Updated sleep time to: $_sleepTime minutes");
    }
    if (clubIndex != null && clubIndex >= 0 && clubIndex <= 24) {
      _clubIndex = clubIndex;
      // print("** Updated club index to: $_clubIndex (${clubNames[_clubIndex]})");
    }
  }

  // Get current device info
  String? getCurrentDeviceName() => deviceName;
  DiscoveredDevice? getCurrentDevice() => _foundDevice;
  int getCurrentSleepTime() => _sleepTime;
  int getCurrentClubIndex() => _clubIndex;
  // String getCurrentClubName() => _clubIndex < clubNames.length ? clubNames[_clubIndex] : "Unknown";

  void dispose() {
    print("** Disposing BLE Manager");
    _stopSyncTimer();
    _scanSub?.cancel();
    _connection?.cancel();
    _notificationSubscription?.cancel();
    _connectionController.close();
    _notificationController.close();
    WakelockPlus.disable();
  }
}