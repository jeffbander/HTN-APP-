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
    static final racpCharacteristicUUID          = Guid("00002A52-0000-1000-8000-00805f9b34fb");

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
    final Set<String> _discoveredDeviceIds = {};

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
      _discoveredDeviceIds.clear();
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
        // Scan for full 15 seconds to discover ALL nearby Omron devices.
        await FlutterBluePlus.startScan(timeout: Duration(seconds: 15));
        dev.log('BT: Scan started successfully, listening for results...');

        scanSubscription = FlutterBluePlus.scanResults.listen(
          (results) async
          {
            dev.log('BT: Scan callback: ${results.length} result(s)');
            await handleScanResults(results);
          },
          onError: (error)
          {
            dev.log('BT: Scan stream error: $error');
            if (!completer.isCompleted) completer.completeError(error);
          },
        );

        // Wait for the full scan duration (15s timeout set above)
        await Future.delayed(const Duration(seconds: 16));
        await finalizeScan(completer);
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

    Future<void> handleScanResults (List<ScanResult> results) async
    {
      for (var result in results)
      {
        final deviceName = result.device.platformName;
        final advName = result.advertisementData.advName;

        // Skip devices with no name
        if (deviceName.isEmpty && advName.isEmpty) {
          continue;
        }

        // Skip already-discovered devices (scanResults is cumulative)
        final deviceId = result.device.remoteId.toString();
        if (_discoveredDeviceIds.contains(deviceId)) {
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
          continue;
        }

        _discoveredDeviceIds.add(deviceId);
        dev.log('BT: MATCHED Omron device: name="$deviceName" advName="$advName" id=$deviceId');

        final peripheral = result.device;
        peripheralName = peripheral.platformName.isNotEmpty
            ? peripheral.platformName
            : peripheral.remoteId.toString();

        theSource = BluetoothSource(peripheral: peripheral);
        theSource?.sourceName = peripheralName;

        // Send discovery message for each Omron device found
        await messenger.sendMsg(msglib.Msg(
          deviceType: msglib.DeviceType.Phone,
          taskType: msglib.TaskType.DiscoverSource,
          status: msglib.Status.succeeded,
          sender: [msglib.ComponentType.BTManager],
          source: theSource,
        ));
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
        await FlutterBluePlus.stopScan();
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

            // Discover services — try twice because iOS may not reveal
            // all services until bonding completes (which is triggered
            // by accessing an encrypted characteristic).
            List<BluetoothService> services = await device.discoverServices();
            dev.log('PAIR: Discovered ${services.length} services');

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

            // If BP service not found on first try, wait for bond
            // to settle and retry service discovery once.
            if (!foundBpService) {
                dev.log('PAIR: BP service not found on first discovery, retrying after delay...');
                await Future.delayed(const Duration(seconds: 3));
                services = await device.discoverServices();
                dev.log('PAIR: Retry discovered ${services.length} services');
                for (BluetoothService service in services)
                {
                    dev.log('Retry Service: ${service.uuid}');
                    if (service.uuid == BluetoothManager.bloodPressureServiceUUID)
                    {
                        foundBpService = true;
                        await handlePairingCharacteristicDiscovery (service);
                    }
                }
            }

            if (!foundBpService) {
                dev.log('PAIR: BP service not found, but proceeding — '
                    'measurement flow will discover services independently. '
                    'Found services: ${services.map((s) => s.uuid).toList()}');
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

  // Silence detection: when no new data arrives for this duration after
  // receiving at least one reading, we treat the transfer as complete.
  // This lets the user see results faster instead of waiting for the
  // cuff to fully disconnect.
  static const Duration _silenceTimeout = Duration(seconds: 4);
  Timer? _silenceTimer;
  bool _transferCompleteSent = false;

  List<Map<DateTime, List<int>>> get measurements => List.unmodifiable(syncMeasurements);

  MeasurementManager({required this.messenger});

  Future<void> connectToDevice (BluetoothDevice device) async
  {
      dev.log('Starting connection attempts for device...');

      // Reset silence detection state for this new connection
      _silenceTimer?.cancel();
      _transferCompleteSent = false;

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
      // 2 seconds is sufficient to refresh the cache without making the user wait.
      try {
        dev.log('Starting 2-second BLE scan to refresh cache before connect...');
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 2));
        await Future.delayed(const Duration(seconds: 2));
        await FlutterBluePlus.stopScan();
        dev.log('Pre-connect scan complete');
      } catch (e) {
        dev.log('Pre-connect scan error (non-fatal): $e');
      }

      // Retry with exponential backoff: 1s, 2s, 4s, 8s delays between attempts.
      // Worst case ~17 seconds total (vs. old approach of ~30 seconds).
      // Most connections succeed on attempt 1 or 2.
      const int maxRetries = 5;
      int retryCount = 0;

      while (retryCount < maxRetries)
      {
          try
          {
              if (!device.isConnected)
              {
                  dev.log('Attempting to connect (attempt ${retryCount + 1}/$maxRetries)');
                  await device.connect(timeout: const Duration(seconds: 10));
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
                  // Exponential backoff: 1s, 2s, 4s, 8s
                  final delaySeconds = 1 << (retryCount - 1); // 2^(retryCount-1)
                  dev.log('Retrying connection in ${delaySeconds}s... (attempt $retryCount/$maxRetries)');
                  await Future.delayed(Duration(seconds: delaySeconds));
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

  // Send a message when the device is disconnected or when silence is detected.
  // Prevents duplicate sends — only the first call (whether from silence detection
  // or actual disconnect) will fire the message.
  Future<void> sendDisconnectionMsg (BluetoothDevice? device) async
  {
      if (_transferCompleteSent && device != null) {
          // Silence detection already triggered the upload — skip the
          // duplicate message from the actual Bluetooth disconnect event.
          dev.log('Disconnect event ignored — transfer already completed via silence detection');
          return;
      }
      _transferCompleteSent = true;
      _silenceTimer?.cancel();

      dev.log('Sending disconnection message (readings: ${syncMeasurements.length})');
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
    BluetoothCharacteristic? bpCharacteristic;
    BluetoothCharacteristic? racpCharacteristic;

    for (BluetoothCharacteristic characteristic in service.characteristics)
    {
      dev.log('  Measurement char: ${characteristic.uuid} props: ${characteristic.properties}');
      if (characteristic.uuid == BluetoothManager.bloodPressureCharacteristicUUID) {
        bpCharacteristic = characteristic;
      }
      if (characteristic.uuid == BluetoothManager.racpCharacteristicUUID) {
        racpCharacteristic = characteristic;
      }
    }

    if (bpCharacteristic != null) {
      dev.log('Found BP measurement characteristic');
      await enableNotifications(bpCharacteristic);
    }

    if (racpCharacteristic != null) {
      dev.log('Found RACP characteristic — enabling indications and requesting stored records');
      await enableNotifications(racpCharacteristic);
      await Future.delayed(const Duration(seconds: 1));
      await requestStoredRecords(racpCharacteristic);
    } else if (bpCharacteristic != null) {
      // Fallback: some devices send data automatically when indications are enabled.
      // No need to wait here — the silence detection timer will handle knowing
      // when the transfer is complete. The app is already listening for data.
      dev.log('No RACP characteristic found — listening for automatic data transfer');
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
          onError: (error) => dev.log('Error in characteristic value stream: $error', level: 1000),
          onDone: () => dev.log('Characteristic value stream completed.'),
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

  Future<void> requestStoredRecords(BluetoothCharacteristic racpCharacteristic) async {
      try {
          // RACP "Report All Stored Records" command
          // Opcode 0x01 = Report stored records, Operator 0x01 = All records
          List<int> command = [0x01, 0x01];

          dev.log('Sending RACP "Report All Stored Records" command: $command');
          await racpCharacteristic.write(command, withoutResponse: false);
          dev.log('RACP command sent successfully — waiting for stored measurements...');
      } catch (e) {
          dev.log('Failed to send RACP command: $e', level: 1000);
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

      // Skip RACP response packets (they start with opcodes 0x05 or 0x06
      // and are status/count responses, not BP measurements)
      if (characteristic.uuid == BluetoothManager.racpCharacteristicUUID) {
          dev.log('RACP response received (not a BP measurement), skipping parse');
          return;
      }

      try
      {
          Map<DateTime, List<int>> parsedData = await parser.parseBloodPressureDataWithTimestamp (data);

          if (parsedData.isNotEmpty)
          {
              syncMeasurements.add (parsedData);
              dev.log('Parsed data added: $parsedData');

              // Start or restart the silence timer. Each time new data arrives,
              // we reset the countdown. When data stops flowing for 4 seconds,
              // we know the cuff is done sending and can show results immediately.
              _restartSilenceTimer();
          }
      }
      catch (e)
      {
          dev.log('Error parsing data from ${characteristic.uuid}: $e', level: 1000);
      }
  }

  /// Restarts the silence detection timer. When no new data arrives for
  /// [_silenceTimeout] after the last reading, we send a disconnection
  /// message so the app shows results without waiting for the cuff to
  /// physically disconnect.
  void _restartSilenceTimer() {
      _silenceTimer?.cancel();
      _silenceTimer = Timer(_silenceTimeout, () {
          if (!_transferCompleteSent && syncMeasurements.isNotEmpty) {
              _transferCompleteSent = true;
              dev.log('Silence detected (${_silenceTimeout.inSeconds}s with no new data) '
                  '— treating transfer as complete with ${syncMeasurements.length} reading(s)');
              sendDisconnectionMsg(null);
          }
      });
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
      _silenceTimer?.cancel();
      dev.log('Disposing MeasurementManager.');
  }
}

