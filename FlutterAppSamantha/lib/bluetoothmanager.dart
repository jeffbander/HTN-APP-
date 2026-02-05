import 'dart:async';
import 'dart:io' show Platform;
import 'dart:developer'; // For logging
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
        log('BluetoothManager initialized');

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
        log ('Bluetooth state changed: $state');

        switch (state) 
        {
            case BluetoothAdapterState.on:
                log('Bluetooth is powered on.');
                break;

            case BluetoothAdapterState.off:
                log('Bluetooth is powered off.');
                break;

            case BluetoothAdapterState.unavailable:
                log('Bluetooth is unsupported on this device.');
                break;

            case BluetoothAdapterState.unauthorized:
                log('Bluetooth is unauthorized.');
                break;

            default:
                log('Unknown Bluetooth state: $state');
        }
    }

    Future<void> checkPermissions () async
    {
      try 
      {
          log('Requesting permissions...');
          final Map<Permission, PermissionStatus> statuses = await
          [
              Permission.bluetoothScan,
              Permission.bluetoothConnect,
              Permission.location,
          ].request();

          log('Permissions requested: $statuses');

          statuses.forEach((permission, status)
          {
              log('Permission: $permission, Status: ${status.isGranted}');
          });

          final permissionsGranted = statuses.values.every((status) => status.isGranted);

          if (!permissionsGranted) 
          {
              log('Permissions not granted for scanning', level: 1000);
              return;
          }

          log('Permissions granted.');

      } 
      catch (e) 
      {
          log('Error in startScan: $e', level: 1000);
          rethrow;
      }
    }

    Future<void> startScan () async
    {
      print('🔵 BT: === STARTING BLUETOOTH SCAN ===');
      final completer = Completer<void>();

      try
      {
        // Cancel any existing scan
        await scanSubscription?.cancel();

        // Check Bluetooth adapter state
        final adapterState = await FlutterBluePlus.adapterState.first;
        print('🔵 BT: Bluetooth adapter state: $adapterState');
        if (adapterState != BluetoothAdapterState.on) {
          print('🔵 BT: ERROR - Bluetooth is not ON (state: $adapterState)');
        }

        // Check permissions
        await checkPermissions();
        print('🔵 BT: Permissions checked');

        print('🔵 BT: Starting FlutterBluePlus scan (no service filter, 15s timeout)...');

        // Start scanning — do NOT filter by service UUID because many Omron
        // devices (BP7250 / 5 Series) don't advertise the Blood Pressure
        // Service UUID in their advertisement packets.
        await FlutterBluePlus.startScan(timeout: Duration(seconds: 15));
        print('🔵 BT: Scan started successfully, listening for results...');

        scanSubscription = FlutterBluePlus.scanResults.listen(
          (results) async
          {
            print('🔵 BT: Scan callback: ${results.length} result(s)');
            await handleScanResults(results, completer);
          },
          onDone: () async
          {
            print('🔵 BT: Scan stream onDone fired.');
            if (!completer.isCompleted)
            {
              await finalizeScan(completer);
            }
          },
          onError: (error)
          {
            print('🔵 BT: Scan stream error: $error');
            if (!completer.isCompleted) completer.completeError(error);
          },
        );

        // Wait for the scan results to be handled
        await completer.future;
      }
      catch (e)
      {
        print('🔵 BT: Error in startScan: $e');
        if (!completer.isCompleted) completer.completeError(e);
      }
      finally {
        await FlutterBluePlus.stopScan();
        print('🔵 BT: === SCAN FINISHED ===');
      }
    }

    Future<void> handleScanResults (List<ScanResult> results, Completer<void> completer) async
    {
      for (var result in results)
      {
        final deviceName = result.device.platformName;
        final advName = result.advertisementData.advName;
        final serviceUuids = result.advertisementData.serviceUuids;
        print('🔵 BT: Device found: name="$deviceName" advName="$advName" '
            'id=${result.device.remoteId} rssi=${result.rssi} '
            'services=$serviceUuids');

        // Skip devices with no name — these are unknown random BLE devices
        if (deviceName.isEmpty && advName.isEmpty) {
          print('🔵 BT: Skipping unnamed device: ${result.device.remoteId}');
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
          print('🔵 BT: Skipping non-Omron device: $deviceName');
          continue;
        }

        print('🔵 BT: ✅ MATCHED Omron device: name="$deviceName" advName="$advName" id=${result.device.remoteId}');

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
        log('Finalizing scan...');

        // If no device was found during the scan, send a failure message
        if (theSource == null) {
          log('No device found during scan', level: 1000);
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
        log('Error during finalization: $e', level: 1000);
        if (!completer.isCompleted) completer.completeError(e);
      }
    }


    Future<void> stopScan() async 
    {
        log('Stopping Bluetooth scan...');
        await scanSubscription?.cancel();
    }

    Future<void> pairDevice (BluetoothDevice device) async 
    {
        // connect to the device
        await pairingManager.pairDevice (device);
    }

    Future<void> connectForMeasurement(BluetoothDevice device) async
    {
       log('Clearing previous measurements...');
      clearMeasurements();

      log('Starting connection to device...');
      await measurementManager.connectToDevice(device);
    }

    void dispose() 
    {
        log('Disposing BluetoothManager');
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
            print('🔗 PAIR: Starting pairing for ${device.remoteId}');
            log ('Starting pairing process for ${device.remoteId.toString()}');

            await device.connect(autoConnect: false, timeout: Duration(seconds: 15));
            print('🔗 PAIR: Connected to ${device.remoteId}');
            log('Connected to ${device.remoteId.toString()}');

            // On Android, explicitly request bonding.
            // On iOS, bonding happens automatically when accessing encrypted characteristics.
            if (Platform.isAndroid) {
                log('Android: Requesting BLE bond...');
                try {
                    await device.createBond();
                    log('Bond created for ${device.remoteId.toString()}');
                } catch (e) {
                    log('createBond failed (may already be bonded): $e', level: 900);
                }
            } else {
                print('🔗 PAIR: iOS - bond via characteristic access');
                log('iOS: Bond will be triggered automatically by characteristic access');
            }

            // Discover services to verify BP service exists
            List<BluetoothService> services = await device.discoverServices();
            print('🔗 PAIR: Discovered ${services.length} services');
            log('Discovered ${services.length} services');

            bool foundBpService = false;
            for (BluetoothService service in services)
            {
                log('Service: ${service.uuid}');
                if (service.uuid == BluetoothManager.bloodPressureServiceUUID)
                {
                    foundBpService = true;
                    await handlePairingCharacteristicDiscovery (service);
                }
            }

            if (!foundBpService) {
                print('🔗 PAIR: WARNING - BP service not found!');
                log('WARNING: Blood Pressure Service (0x1810) not found on device. '
                    'Found services: ${services.map((s) => s.uuid).toList()}', level: 900);
            }

            print('🔗 PAIR: SUCCESS for ${device.remoteId}');
            log('Pairing successful for ${device.remoteId.toString()}');
            await messenger.sendMsg (msglib.Msg (deviceType: msglib.DeviceType.Phone,
                                          taskType:   msglib.TaskType.Pair,
                                          status:     msglib.Status.succeeded,
                                          sender:     [msglib.ComponentType.BTManager]));
            await device.disconnect();
        }
        catch (e)
        {
            print('🔗 PAIR: FAILED for ${device.remoteId}: $e');
            log('Pairing failed for ${device.remoteId.toString()}: $e', level: 1000);
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
        log('  Characteristic: ${characteristic.uuid} '
            'props: ${characteristic.properties}');

        // Enable indications for blood pressure measurement characteristic
        // This verifies the device supports BP measurement and that bonding works
        if (characteristic.uuid == BluetoothManager.bloodPressureCharacteristicUUID) {
          log('Enabling indications for blood pressure characteristic');
          try {
            await characteristic.setNotifyValue(true);
            log('Indications enabled — waiting 3 seconds for device to settle...');
            await Future.delayed(const Duration(seconds: 3));
            await characteristic.setNotifyValue(false);
            log('Indications disabled after verification');
          } catch (e) {
            log('Error enabling indications: $e', level: 900);
          }
        }
      }
    }
    
    void dispose() 
    {
        log('Disposing PairingManager');
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
      log ('Starting connection attempts for device: ${device.remoteId.toString()}');

      // Monitor the connection state
      device.connectionState.listen ((state)
      {
          if (prevState != state)
          {
            log ("Connection state changed from: ${prevState.toString()} to ${state.toString()}");
          }
          else
          {
            log ("Connection state unchanged from: ${prevState.toString()}");
          }

          if (prevState != BluetoothConnectionState.disconnected &&
              state == BluetoothConnectionState.disconnected)
          {
              log ('Device ${device.remoteId.toString()} disconnected.');
              sendDisconnectionMsg (device); // Send message on disconnect
          }

          prevState = state;
      });

      // Scan briefly to refresh the BLE cache before attempting connection.
      // Without this, connecting to a device that was off may fail with a
      // stale cache even though the device is now advertising.
      try {
        log('Starting 5-second BLE scan to refresh cache before connect...');
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
        await Future.delayed(const Duration(seconds: 5));
        await FlutterBluePlus.stopScan();
        log('Pre-connect scan complete');
      } catch (e) {
        log('Pre-connect scan error (non-fatal): $e');
      }

      const int maxRetries = 15; // ~30 seconds total (15 attempts * 2 second delay)
      int retryCount = 0;

      while (retryCount < maxRetries)
      {
          try
          {
              if (!device.isConnected)
              {
                  log('Attempting to connect to ${device.remoteId.toString()} (attempt ${retryCount + 1}/$maxRetries)');
                  await device.connect(); // Attempt to connect
                  log('Successfully connected to ${device.remoteId.toString()}');

                  // Perform service discovery once connected
                  List<BluetoothService> services = await device.discoverServices();
                  await handleServiceDiscovery(services);
                  log('Service discovery completed for ${device.remoteId.toString()}');

                  return; // Exit the loop after a successful connection and service discovery
              }
              else
              {
                  log('Device ${device.remoteId.toString()} is already connected. Performing service discovery...');
                  List<BluetoothService> services = await device.discoverServices();
                  await handleServiceDiscovery(services);
                  return; // Exit the loop if already connected
              }
          }
          catch (e)
          {
              retryCount++;
              log('Failed to connect to ${device.remoteId.toString()}: $e', level: 1000);
              if (retryCount < maxRetries) {
                  log('Retrying connection in 2 seconds... (attempt $retryCount/$maxRetries)');
                  await Future.delayed(const Duration(seconds: 2)); // Wait before retrying
              }
          }
      }

      // Max retries exceeded - send failure message
      log('Connection failed after $maxRetries attempts', level: 1000);
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
      log('Sending disconnection message for device: ${device.remoteId.toString()}');
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
              log('Found blood pressure service: ${service.uuid}');
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
          log('Found measurement characteristic: ${characteristic.uuid}');

          // FIXED: Enable notifications FIRST so we're ready to receive data
          await enableNotifications(characteristic);

          // Wait for device to configure notifications
          log('Waiting 2 seconds for device to be ready...');
          await Future.delayed(const Duration(seconds: 2));
          log('2-second delay complete');

          // THEN write command to request measurement
          await requestMeasurement(characteristic);
      }
    }
  }

  Future<void> enableNotifications(BluetoothCharacteristic characteristic) async
  {
    log('Enabling notifications for characteristic: ${characteristic.uuid}');

    try 
    {
      // Now, enable notifications again
      await characteristic.setNotifyValue(true);
      log('Notifications enabled for characteristic: ${characteristic.uuid}');

      // Listen to the characteristic's value changes
      characteristic.lastValueStream.listen(
          (data) => handleCharacteristicData(characteristic, data),
          onError: (error) => log('Error in characteristic value stream: $error', level: 1000),
          onDone: () => log('Characteristic value stream completed.'),
      );
    } catch (e) 
    {
      log('Failed to enable notifications for characteristic ${characteristic.uuid}: $e', level: 1000);

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

          log('Sending measurement request command: $command');
          await characteristic.write(command, withoutResponse: false);
          log('Measurement request sent successfully');
      } catch (e) {
          log('Failed to send measurement request: $e', level: 1000);
      }
  }

  Future<void> handleCharacteristicData (BluetoothCharacteristic characteristic, List<int> data) async
  {
      if (data.isEmpty)
      {
          log('Received empty data from characteristic: ${characteristic.uuid}');
          return;
      }

      log('Received data from ${characteristic.uuid}: $data');

      try
      {
          Map<DateTime, List<int>> parsedData = await parser.parseBloodPressureDataWithTimestamp (data);

          if (parsedData.isNotEmpty)
          {
              syncMeasurements.add (parsedData);
              log('Parsed data added: $parsedData');
          }
      }
      catch (e)
      {
          log('Error parsing data from ${characteristic.uuid}: $e', level: 1000);
      }
  }

  Future<void> sendMeasurements () async
  {
      if (syncMeasurements.isEmpty)
      {
          log('No measurements available to send.');
          return;
      }

      var msg = msglib.Msg (deviceType: msglib.DeviceType.Phone,
                            taskType: msglib.TaskType.Sync,
                            status: msglib.Status.update,
                            sender: [msglib.ComponentType.BTManager],
                            measurement: syncMeasurements,
      );

      await messenger.sendMsg (msg);
      log('Measurements sent successfully. Clearing syncMeasurements.');
      syncMeasurements.clear(); // Fixed: was commented out causing duplicates
  }

  void dispose()
  {
      log('Disposing MeasurementManager.');
  }
}

