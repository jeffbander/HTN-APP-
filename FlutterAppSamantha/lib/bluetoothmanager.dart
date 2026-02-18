import 'dart:async';
import 'dart:io' show Platform;
import 'dart:developer' as dev; // For logging
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'msg.dart' as msglib;
import 'sourceBase.dart';
import 'bloodPressureData.dart';
//-------------------------------------------------------
class BluetoothManager 
{
    // UUIDs
    static final deviceInformationServices       = Guid("0000180A-0000-1000-8000-00805f9b34fb");
    static final mgfName                         = Guid("00002A29-0000-1000-8000-00805f9b34fb");
    static final serialNum                       = Guid("00002A25-0000-1000-8000-00805f9b34fb");

    static final bloodPressureServiceUUID        = Guid("00001810-0000-1000-8000-00805f9b34fb");
    static final bloodPressureCharacteristicUUID = Guid("00002A35-0000-1000-8000-00805f9b34fb");

    static const String Omron_BT_STR             = "BP7000";
    static const String Omron3Series_BT_STR      = "BLESmart_";  // Omron 3 Series (BP7150)
    static const String Omron5Series_BT_STR      = "BLESmart_";  // Omron 5 Series (BP7250)
    static const String Transtek_BT_STR          = "BP7150";

    String curDeviceBluetoothStr                = Omron_BT_STR;
    msglib.DeviceModel curDeviceModel                  = msglib.DeviceModel.Omron;

    final msglib.BaseMessenger messenger;

    late PairingManager pairingManager;
    late MeasurementManager measurementManager;


    StreamSubscription? scanSubscription;

    String peripheralName = "";
    BluetoothSource? theSource;
    BluetoothDevice? connectedPeripheral;


    BluetoothManager (this.messenger) 
    {
        dev.log('BluetoothManager initialized');

        pairingManager  = PairingManager(messenger: messenger);
        measurementManager = MeasurementManager(messenger: messenger);

        FlutterBluePlus.adapterState.listen(
            (BluetoothAdapterState state) 
            {
                onBluetoothStateChanged (state);
            }
        );
    }

    BluetoothSource? createSrcObject (String id)
    {
      DeviceIdentifier devId = DeviceIdentifier (id);

      connectedPeripheral = BluetoothDevice (remoteId: devId);
      theSource = BluetoothSource (peripheral: connectedPeripheral);
      return theSource;
    }

    Future<void> clearMeasurements () async
    {
      measurementManager.syncMeasurements.clear ();
    }

    List<Map<DateTime, List<int>>> getSyncMeasurements() 
    {
        return measurementManager.measurements;
    }

    /// Method to get the last synced measurement
    Map<DateTime, List<int>>? getLastSyncedMeasurement () 
    {
        final measurements = measurementManager.measurements;

        if (measurements.isEmpty) 
        {
            return null; // Return null if no measurements exist
        }

        return measurements.last; // Return the last measurement
    }

    void onBluetoothStateChanged (BluetoothAdapterState state) 
    {
        dev.log('Bluetooth state changed: $state');

        switch (state) 
        {
            case BluetoothAdapterState.on:
                dev.log('Bluetooth is powered on.');
                break;

            case BluetoothAdapterState.off:
                dev.log('Bluetooth is powered off.');
                break;

            case BluetoothAdapterState.unavailable:
                dev.log('Bluetooth is unsupported on this device.');
                break;

            case BluetoothAdapterState.unauthorized:
                dev.log('Bluetooth is unauthorized.');
                break;

            default:
                dev.log('Unknown Bluetooth state: $state');
        }
    }

    Future<void> checkPermissions () async
    {
      try 
      {
          dev.log('Requesting permissions...');
          final Map<Permission, PermissionStatus> statuses = await
          [
              Permission.bluetoothScan,
              Permission.bluetoothConnect,
              Permission.location,
          ].request();

          dev.log('Permissions requested: $statuses');

          statuses.forEach((permission, status)
          {
              dev.log('Permission: $permission, Status: ${status.isGranted}');
          });

          final permissionsGranted = statuses.values.every((status) => status.isGranted);

          if (!permissionsGranted) 
          {
              dev.log('Permissions not granted for scanning', level: 1000);
              return;
          }

          dev.log('Permissions granted.');

      } 
      catch (e) 
      {
          dev.log('Error in startScan: $e', level: 1000);
          rethrow;
      }
    }

    Future<void> startScan () async
    {
      dev.log('BT: === STARTING BLUETOOTH SCAN ===');
      final completer = Completer<void>();

      try
      {
        // Cancel any existing scan
        await scanSubscription?.cancel();

        // Check Bluetooth adapter state
        final adapterState = await FlutterBluePlus.adapterState.first;
        dev.log('BT: Bluetooth adapter state: $adapterState');
        if (adapterState != BluetoothAdapterState.on) {
          dev.log('BT: ERROR - Bluetooth is not ON (state: $adapterState)');
        }

        // Check permissions
        await checkPermissions();
        dev.log('BT: Permissions checked');

        dev.log('BT: Starting FlutterBluePlus scan (no service filter, 15s timeout)...');

        // Start scanning — do NOT filter by service UUID because many Omron
        // devices (BP7250 / 5 Series) don't advertise the Blood Pressure
        // Service UUID in their advertisement packets.
        await FlutterBluePlus.startScan(timeout: Duration(seconds: 15));
        dev.log('BT: Scan started successfully, listening for results...');

        scanSubscription = FlutterBluePlus.scanResults.listen(
          (results) async
          {
            dev.log('BT: Scan callback: ${results.length} result(s)');
            await handleScanResults(results, completer);
          },
          onDone: () async
          {
            dev.log('BT: Scan stream onDone fired.');
            if (!completer.isCompleted)
            {
              await finalizeScan(completer);
            }
          },
          onError: (error)
          {
            dev.log('BT: Scan stream error: $error');
            if (!completer.isCompleted) completer.completeError(error);
          },
        );

        // Wait for the scan results to be handled
        await completer.future;
      }
      catch (e)
      {
        dev.log('BT: Error in startScan: $e');
        if (!completer.isCompleted) completer.completeError(e);
      }
      finally {
        await FlutterBluePlus.stopScan();
        dev.log('BT: === SCAN FINISHED ===');
      }
    }

    Future<void> handleScanResults (List<ScanResult> results, Completer<void> completer) async
    {
      for (var result in results)
      {
        final deviceName = result.device.platformName;
        final advName = result.advertisementData.advName;
        final serviceUuids = result.advertisementData.serviceUuids;
        dev.log('BT: Device found: name="$deviceName" advName="$advName" '
            'rssi=${result.rssi} services=$serviceUuids');

        // Skip devices with no name — these are unknown random BLE devices
        if (deviceName.isEmpty && advName.isEmpty) {
          dev.log('BT: Skipping unnamed device');
          continue;
        }

        // Filter for Omron devices — check both platformName and advName
        final upperName = deviceName.toUpperCase();
        final upperAdvName = advName.toUpperCase();
        final isOmronDevice = upperName.contains('BP7') ||
                              upperAdvName.contains('BP7') ||
                              upperName.contains('BLESMART') ||
                              upperAdvName.contains('BLESMART') ||
                              upperName.contains('OMRON') ||
                              upperAdvName.contains('OMRON') ||
                              upperName.contains('EVOLV') ||
                              upperAdvName.contains('EVOLV') ||
                              upperName.contains('HEM-') ||
                              upperAdvName.contains('HEM-') ||
                              upperName.contains('HEM7') ||
                              upperAdvName.contains('HEM7');

        if (!isOmronDevice) {
          dev.log('BT: Skipping non-Omron device: $deviceName');
          continue;
        }

        dev.log('BT: MATCHED Omron device: name="$deviceName" advName="$advName"');

        final peripheral = result.device;
        // Use platform name if available, otherwise use remote ID
        peripheralName = peripheral.platformName.isNotEmpty
            ? peripheral.platformName
            : peripheral.remoteId.toString();

        theSource = BluetoothSource(peripheral: peripheral);
        theSource?.sourceName = peripheralName;

         // Send the message for the discovered peripheral
        await messenger.sendMsg(msglib.Msg(
          deviceType: msglib.DeviceType.Phone,
          taskType: msglib.TaskType.DiscoverSource,
          status: msglib.Status.succeeded,
          sender: [msglib.ComponentType.BTManager],
          source: theSource,
        ));

        // Complete the completer after sending the message
        if (!completer.isCompleted) completer.complete();
        break;
      }
    }

    // Ensure the completer is completed if handleScanResults doesn't find anything
    Future<void> finalizeScan (Completer<void> completer) async
    {
      try
      {
        dev.log('Finalizing scan...');

        // If no device was found during the scan, send a failure message
        if (theSource == null) {
          dev.log('No device found during scan', level: 1000);
          await messenger.sendMsg(msglib.Msg(
            deviceType: msglib.DeviceType.Phone,
            taskType: msglib.TaskType.Scan,
            status: msglib.Status.failed,
            sender: [msglib.ComponentType.BTManager],
          ));
        }

        if (!completer.isCompleted) completer.complete();

      }
      catch (e)
      {
        dev.log('Error during finalization: $e', level: 1000);
        if (!completer.isCompleted) completer.completeError(e);
      }
    }


    Future<void> stopScan() async 
    {
        dev.log('Stopping Bluetooth scan...');
        await scanSubscription?.cancel();
    }

    Future<void> pairDevice (BluetoothDevice device) async 
    {
        // connect to the device
        await pairingManager.pairDevice (device);
    }

    Future<void> connectForMeasurement(BluetoothDevice device) async
    {
       dev.log('Clearing previous measurements...');
      clearMeasurements();

      dev.log('Starting connection to device...');
      await measurementManager.connectToDevice(device);
    }

    void dispose() 
    {
        dev.log('Disposing BluetoothManager');
        stopScan();
        pairingManager.dispose();
        measurementManager.dispose();
    }
}

class PairingManager 
{
    final msglib.BaseMessenger messenger;

    PairingManager ({required this.messenger});

    Future<void> pairDevice (BluetoothDevice device) async
    {
        try
        {
            dev.log('PAIR: Starting pairing...');
            dev.log('Starting pairing process...');

            await device.connect(autoConnect: false, timeout: Duration(seconds: 15));
            dev.log('PAIR: Connected to device');
            dev.log('Connected to device');

            // On Android, explicitly request bonding.
            // On iOS, bonding happens automatically when accessing encrypted characteristics.
            if (Platform.isAndroid) {
                dev.log('Android: Requesting BLE bond...');
                try {
                    await device.createBond();
                    dev.log('Bond created for device');
                } catch (e) {
                    dev.log('createBond failed (may already be bonded): $e', level: 900);
                }
            } else {
                dev.log('PAIR: iOS - bond via characteristic access');
                dev.log('iOS: Bond will be triggered automatically by characteristic access');
            }

            // Discover services to verify BP service exists
            List<BluetoothService> services = await device.discoverServices();
            dev.log('PAIR: Discovered ${services.length} services');
            dev.log('Discovered ${services.length} services');

            bool foundBpService = false;
            for (BluetoothService service in services)
            {
                dev.log('Service: ${service.uuid}');
                if (service.uuid == BluetoothManager.bloodPressureServiceUUID)
                {
                    foundBpService = true;
                    await handlePairingCharacteristicDiscovery (service);
                }
            }

            if (!foundBpService) {
                dev.log('PAIR: WARNING - BP service not found!');
                dev.log('WARNING: Blood Pressure Service (0x1810) not found on device. '
                    'Found services: ${services.map((s) => s.uuid).toList()}', level: 900);
            }

            dev.log('PAIR: SUCCESS');
            dev.log('Pairing successful');
            await messenger.sendMsg (msglib.Msg (deviceType: msglib.DeviceType.Phone,
                                          taskType:   msglib.TaskType.Pair,
                                          status:     msglib.Status.succeeded,
                                          sender:     [msglib.ComponentType.BTManager]));
            await device.disconnect();
        }
        catch (e)
        {
            dev.log('PAIR: FAILED: $e');
            dev.log('Pairing failed: $e', level: 1000);
            try { await device.disconnect(); } catch (_) {}
            await messenger.sendMsg (msglib.Msg (deviceType: msglib.DeviceType.Phone,
                                          taskType:   msglib.TaskType.Pair,
                                          status:     msglib.Status.failed,
                                          sender:     [msglib.ComponentType.BTManager]));
        }
    }

    Future<void> handlePairingCharacteristicDiscovery(BluetoothService service) async
    {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        dev.log('  Characteristic: ${characteristic.uuid} '
            'props: ${characteristic.properties}');

        // Enable indications for blood pressure measurement characteristic
        // This verifies the device supports BP measurement and that bonding works
        if (characteristic.uuid == BluetoothManager.bloodPressureCharacteristicUUID) {
          dev.log('Enabling indications for blood pressure characteristic');
          try {
            await characteristic.setNotifyValue(true);
            dev.log('Indications enabled — waiting 3 seconds for device to settle...');
            await Future.delayed(const Duration(seconds: 3));
            await characteristic.setNotifyValue(false);
            dev.log('Indications disabled after verification');
          } catch (e) {
            dev.log('Error enabling indications: $e', level: 900);
          }
        }
      }
    }
    
    void dispose() 
    {
        dev.log('Disposing PairingManager');
    }
}

class MeasurementManager
{
  final msglib.BaseMessenger           messenger;
  final BloodPressureParser            parser           = BloodPressureParser();
  final List<Map<DateTime, List<int>>> syncMeasurements = [];
  BluetoothConnectionState             prevState        = BluetoothConnectionState.disconnected;

  List<Map<DateTime, List<int>>> get measurements => List.unmodifiable(syncMeasurements);

  MeasurementManager({required this.messenger});

  Future<void> connectToDevice (BluetoothDevice device) async
  {
      dev.log('Starting connection attempts for device...');

      // Monitor the connection state
      device.connectionState.listen ((state)
      {
          if (prevState != state)
          {
            dev.log("Connection state changed from: ${prevState.toString()} to ${state.toString()}");
          }
          else
          {
            dev.log("Connection state unchanged from: ${prevState.toString()}");
          }

          if (prevState != BluetoothConnectionState.disconnected &&
              state == BluetoothConnectionState.disconnected)
          {
              dev.log('Device disconnected.');
              sendDisconnectionMsg (device); // Send message on disconnect
          }

          prevState = state;
      });

      // Scan briefly to refresh the BLE cache before attempting connection.
      // Without this, connecting to a device that was off may fail with a
      // stale cache even though the device is now advertising.
      try {
        dev.log('Starting 5-second BLE scan to refresh cache before connect...');
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
        await Future.delayed(const Duration(seconds: 5));
        await FlutterBluePlus.stopScan();
        dev.log('Pre-connect scan complete');
      } catch (e) {
        dev.log('Pre-connect scan error (non-fatal): $e');
      }

      const int maxRetries = 15; // ~30 seconds total (15 attempts * 2 second delay)
      int retryCount = 0;

      while (retryCount < maxRetries)
      {
          try
          {
              if (!device.isConnected)
              {
                  dev.log('Attempting to connect (attempt ${retryCount + 1}/$maxRetries)');
                  await device.connect(); // Attempt to connect
                  dev.log('Successfully connected to device');

                  // Perform service discovery once connected
                  List<BluetoothService> services = await device.discoverServices();
                  await handleServiceDiscovery(services);
                  dev.log('Service discovery completed');

                  return; // Exit the loop after a successful connection and service discovery
              }
              else
              {
                  dev.log('Device is already connected. Performing service discovery...');
                  List<BluetoothService> services = await device.discoverServices();
                  await handleServiceDiscovery(services);
                  return; // Exit the loop if already connected
              }
          }
          catch (e)
          {
              retryCount++;
              dev.log('Failed to connect to device: $e', level: 1000);
              if (retryCount < maxRetries) {
                  dev.log('Retrying connection in 2 seconds... (attempt $retryCount/$maxRetries)');
                  await Future.delayed(const Duration(seconds: 2)); // Wait before retrying
              }
          }
      }

      // Max retries exceeded - send failure message
      dev.log('Connection failed after $maxRetries attempts', level: 1000);
      await messenger.sendMsg(msglib.Msg(
          deviceType: msglib.DeviceType.Phone,
          taskType: msglib.TaskType.Measure,
          status: msglib.Status.failed,
          sender: [msglib.ComponentType.BTManager],
          strData: ['Could not connect to your cuff. Please turn on your cuff and try again.'],
      ));
  }

  // Send a message when the device is disconnected
  Future<void> sendDisconnectionMsg (BluetoothDevice device) async
  {
      dev.log('Sending disconnection message for device');
      await messenger.sendMsg (msglib.Msg (deviceType: msglib.DeviceType.Phone,
                                            taskType:  msglib.TaskType.DisconnectPeripheralFor,
                                            status:    msglib.Status.succeeded,
                                            sender:   [msglib.ComponentType.BTManager]));
  }

  Future<void> handleServiceDiscovery (List<BluetoothService> services) async
  {
      for (BluetoothService service in services)
      {
          if (service.uuid == BluetoothManager.bloodPressureServiceUUID)
          {
              dev.log('Found blood pressure service: ${service.uuid}');
              await handleMeasurementCharacteristicDiscovery (service);
          }
      }
  }

  Future<void> handleMeasurementCharacteristicDiscovery(BluetoothService service) async
  {
    for (BluetoothCharacteristic characteristic in service.characteristics)
    {
      if (characteristic.uuid == BluetoothManager.bloodPressureCharacteristicUUID)
      {
          dev.log('Found measurement characteristic: ${characteristic.uuid}');

          // FIXED: Enable notifications FIRST so we're ready to receive data
          await enableNotifications(characteristic);

          // Wait for device to configure notifications
          dev.log('Waiting 2 seconds for device to be ready...');
          await Future.delayed(const Duration(seconds: 2));
          dev.log('2-second delay complete');

          // THEN write command to request measurement
          await requestMeasurement(characteristic);
      }
    }
  }

  Future<void> enableNotifications(BluetoothCharacteristic characteristic) async
  {
    dev.log('Enabling notifications for characteristic: ${characteristic.uuid}');

    try 
    {
      // Now, enable notifications again
      await characteristic.setNotifyValue(true);
      dev.log('Notifications enabled for characteristic: ${characteristic.uuid}');

      // Listen to the characteristic's value changes
      characteristic.lastValueStream.listen(
          (data) => handleCharacteristicData(characteristic, data),
          onError: (error) => log('Error in characteristic value stream: $error', level: 1000),
          onDone: () => log('Characteristic value stream completed.'),
      );
    } catch (e) 
    {
      dev.log('Failed to enable notifications for characteristic ${characteristic.uuid}: $e', level: 1000);

      // Send failure message
      await messenger.sendMsg(
          msglib.Msg(
              deviceType: msglib.DeviceType.Phone,
              taskType: msglib.TaskType.CharacteristicValue,
              status: msglib.Status.failed,
              sender: [msglib.ComponentType.BTManager],
          ),
      );
    }
  }

  Future<void> requestMeasurement(BluetoothCharacteristic characteristic) async {
      try {
          // Command to start measurement (adjust based on device specifications)
          List<int> command = [0x02]; 

          dev.log('Sending measurement request command: $command');
          await characteristic.write(command, withoutResponse: false);
          dev.log('Measurement request sent successfully');
      } catch (e) {
          dev.log('Failed to send measurement request: $e', level: 1000);
      }
  }

  Future<void> handleCharacteristicData (BluetoothCharacteristic characteristic, List<int> data) async
  {
      if (data.isEmpty)
      {
          dev.log('Received empty data from characteristic: ${characteristic.uuid}');
          return;
      }

      dev.log('Received data from ${characteristic.uuid}: $data');

      try
      {
          Map<DateTime, List<int>> parsedData = await parser.parseBloodPressureDataWithTimestamp (data);

          if (parsedData.isNotEmpty)
          {
              syncMeasurements.add (parsedData);
              dev.log('Parsed data added: $parsedData');
          }
      }
      catch (e)
      {
          dev.log('Error parsing data from ${characteristic.uuid}: $e', level: 1000);
      }
  }

  Future<void> sendMeasurements () async
  {
      if (syncMeasurements.isEmpty)
      {
          dev.log('No measurements available to send.');
          return;
      }

      var msg = msglib.Msg (deviceType: msglib.DeviceType.Phone,
                            taskType: msglib.TaskType.Sync,
                            status: msglib.Status.update,
                            sender: [msglib.ComponentType.BTManager],
                            measurement: syncMeasurements,
      );

      await messenger.sendMsg (msg);
      dev.log('Measurements sent successfully. Clearing syncMeasurements.');
      syncMeasurements.clear(); // Fixed: was commented out causing duplicates
  }

  void dispose()
  {
      dev.log('Disposing MeasurementManager.');
  }
}

