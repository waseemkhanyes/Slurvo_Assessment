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

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final StreamController<List<int>> _notificationController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get notificationStream => _notificationController.stream;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    return allGranted;
  }

  void startScan({required VoidCallback onDeviceFound}) {
    _scanSub?.cancel();

    _scanSub = _ble.scanForDevices(
      withServices: [BleDevice.serviceUuid],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name.startsWith("GL-")) {
        _foundDevice = device;
        deviceName = device.name;
        _scanSub?.cancel();
        _connectToDevice(device, onDeviceFound);
      }
    }, onError: (error) {
      print("Scan error: $error");
    });
  }

  // Expose a method to start scanning, with a callback when device found
  void startDeviceScan(Function(DiscoveredDevice) onDeviceFound) {
    _scanSub?.cancel();
    _scanSub = _ble.scanForDevices(
      withServices: [BleDevice.serviceUuid],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name.startsWith("GL-")) {
        onDeviceFound(device);
        _scanSub?.cancel();
      }
    }, onError: (error) {
      print("Scan error: $error");
    });
  }

// Expose a public method to connect to a device by ID
  void connectToDeviceById(String deviceId, VoidCallback onConnected) {
    _connection?.cancel();

    _connection = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: Duration(seconds: 5),
    ).listen((connectionState) async {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        await _onConnected(deviceId);
        WakelockPlus.enable();
        _connectionController.add(true);
        onConnected();
      } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        WakelockPlus.disable();
        _connectionController.add(false);
        // Optionally restart scanning or notify user
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
    final services = await _ble.discoverServices(deviceId);
    for (var service in services) {
      if (service.serviceId == BleDevice.serviceUuid) {
        for (var char in service.characteristics) {
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
  }

  Future<void> sendSyncCommand({int sleepTime = 5, int clubIndex = 0}) async {
    if (_foundDevice == null) return;

    final cmdBytes = BleDevice.buildSyncCommand(sleepTimeMinutes: sleepTime, clubNameIndex: clubIndex);

    try {
      await _ble.writeCharacteristicWithResponse(_writeCharacteristic, value: cmdBytes);
      print("Sync command sent: $cmdBytes");
    } catch (e) {
      print("Error sending sync command: $e");
    }
  }

  Future<void> sendUploadRecord(int recNo) async {
    if (_foundDevice == null) return;

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

  void _startScan({required Function(DiscoveredDevice device) onDeviceFound}) {
    _scanSub?.cancel();
    _scanSub = _ble.scanForDevices(
      withServices: [BleDevice.serviceUuid],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name.startsWith("GL-")) {
        onDeviceFound(device);
        _scanSub?.cancel();
      }
    }, onError: (error) {
      print("Scan error: $error");
    });
  }

  void dispose() {
    _scanSub?.cancel();
    _connection?.cancel();
    _connectionController.close();
    _notificationController.close();
  }
}
