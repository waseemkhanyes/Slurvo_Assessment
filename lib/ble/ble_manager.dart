import 'dart:async';
import 'dart:ui';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ble_device.dart';
import 'ble_service.dart';

class BleManager {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connection;

  late QualifiedCharacteristic _writeCharacteristic;
  late QualifiedCharacteristic _notifyCharacteristic;

  DiscoveredDevice? _foundDevice;
  String? deviceName;

  final Set<String> _discoveredDeviceIds = <String>{};

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final StreamController<List<int>> _notificationController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get notificationStream => _notificationController.stream;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    print("** Permission status: $statuses");
    return allGranted;
  }

  void startDeviceScan(Function(DiscoveredDevice) onDeviceFound) {
    print("** Starting BLE scan...");
    _scanSub?.cancel();

    _discoveredDeviceIds.clear();

    // Check BLE status first
    _ble.statusStream.listen((status) {
      print("** BLE Status: $status");
    });

    _scanSub = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
      requireLocationServicesEnabled: false,
    ).listen((device) {
      print("** Found device: ${device.name} (${device.id})");
      print("** Device services: ${device.serviceUuids}");

      if (_discoveredDeviceIds.contains(device.id)) {
        return;
      }

      if (!device.name.startsWith("GL-")) {
        return;
      }

      _discoveredDeviceIds.add(device.id);

      onDeviceFound(device);
    }, onError: (error) {
      print("** Scan error: $error");
      _retryGenericScan(onDeviceFound);
    });

    // Add timeout to prevent infinite scanning
    Timer(Duration(seconds: 30), () {
      if (_scanSub != null && !_scanSub!.isPaused) {
        print("** Scan timeout reached");
        stopScan();
      }
    });
  }

  void _retryGenericScan(Function(DiscoveredDevice) onDeviceFound) {
    print("** Retrying with generic scan...");
    _scanSub?.cancel();

    _scanSub = _ble.scanForDevices(
      withServices: [], // Scan for all devices
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      print("** Found device (generic): ${device.name} (${device.id})");

      if (_discoveredDeviceIds.contains(device.id)) {
        return;
      }

      if (!device.name.startsWith("GL-")) {
        return;
      }

      _discoveredDeviceIds.add(device.id);

      onDeviceFound(device);
    }, onError: (error) {
      print("** Generic scan error: $error");
    });
  }

  void stopScan() {
    print("** Stopping scan");
    _scanSub?.cancel();
    _scanSub = null;
  }

  void startScan({required VoidCallback onDeviceFound}) {
    print("** wk start scan =======");
    _scanSub?.cancel();

    _scanSub = _ble.scanForDevices(
      withServices: [BleDevice.serviceUuid],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name.startsWith("GL-")) {
        print("** wk device: ${device.name}");
        _foundDevice = device;
        deviceName = device.name;
        _scanSub?.cancel();
        _connectToDevice(device, onDeviceFound);
      }
    }, onError: (error) {
      print("Scan error: $error");
    });
  }

  void connectToDeviceById(String deviceId, VoidCallback onConnected) {
    _connection?.cancel();

    _connection = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: Duration(seconds: 5),
    ).listen((connectionState) async {
      print("** Connection state: ${connectionState.connectionState}");
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        await _onConnected(deviceId);
        WakelockPlus.enable();
        _connectionController.add(true);
        onConnected();
      } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        WakelockPlus.disable();
        _connectionController.add(false);
      }
    }, onError: (error) {
      print("Connection error: $error");
      WakelockPlus.disable();
      _connectionController.add(false);
    });
  }

  void _connectToDevice(DiscoveredDevice device, VoidCallback onDeviceFound) {
    _connection?.cancel();

    _connection = _ble.connectToDevice(
      id: device.id,
      connectionTimeout: Duration(seconds: 5),
    ).listen((connectionState) async {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        await _onConnected(device.id);
        WakelockPlus.enable();
        _connectionController.add(true);
        onDeviceFound();
      } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        WakelockPlus.disable();
        _connectionController.add(false);
        startScan(onDeviceFound: onDeviceFound);
      }
    }, onError: (error) {
      print("Connection error: $error");
      WakelockPlus.disable();
      _connectionController.add(false);
      startScan(onDeviceFound: onDeviceFound);
    });
  }

  Future<void> _onConnected(String deviceId) async {
    try {
      final services = await _ble.discoverServices(deviceId);
      print("** Discovered ${services.length} services");

      for (var service in services) {
        print("** Service: ${service.serviceId}");
        if (service.serviceId == BleDevice.serviceUuid) {
          for (var char in service.characteristics) {
            print("** Characteristic: ${char.characteristicId}");
            if (char.characteristicId == BleDevice.characteristicWriteUuid) {
              _writeCharacteristic = QualifiedCharacteristic(
                characteristicId: BleDevice.characteristicWriteUuid,
                serviceId: BleDevice.serviceUuid,
                deviceId: deviceId,
              );
            } else if (char.characteristicId == BleDevice.characteristicNotifyUuid) {
              _notifyCharacteristic = QualifiedCharacteristic(
                characteristicId: BleDevice.characteristicNotifyUuid,
                serviceId: BleDevice.serviceUuid,
                deviceId: deviceId,
              );
            }
          }
        }
      }

      _ble.subscribeToCharacteristic(_notifyCharacteristic).listen((data) {
        _notificationController.add(data);
      }, onError: (e) {
        print("Notification error: $e");
      });
    } catch (e) {
      print("** Error during service discovery: $e");
    }
  }

  Future<void> sendSyncCommand({int sleepTime = 5, int clubIndex = 0}) async {
    if (_foundDevice == null) {
      print("** No device connected");
      return;
    }

    final cmdBytes = BleDevice.buildSyncCommand(sleepTimeMinutes: sleepTime, clubNameIndex: clubIndex);

    try {
      await _ble.writeCharacteristicWithResponse(_writeCharacteristic, value: cmdBytes);
      print("Sync command sent: $cmdBytes");
    } catch (e) {
      print("Error sending sync command: $e");
    }
  }

  Future<void> sendUploadRecord(int recNo) async {
    if (_foundDevice == null) {
      print("** No device connected");
      return;
    }

    final cmdBytes = BleDevice.buildUploadRecordCommand(recNo);

    try {
      await _ble.writeCharacteristicWithResponse(_writeCharacteristic, value: cmdBytes);
      print("Upload record command sent: $cmdBytes");
    } catch (e) {
      print("Error sending upload record command: $e");
    }
  }

  ParsedNotification? parseNotification(List<int> data) {
    return BleDataParser.parseNotification(data);
  }

  void dispose() {
    _scanSub?.cancel();
    _connection?.cancel();
    _connectionController.close();
    _notificationController.close();
  }
}