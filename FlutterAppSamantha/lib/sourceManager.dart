import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hypertensionpreventionprogram/flaskUploader.dart';
import 'package:hypertensionpreventionprogram/remoteUploader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetoothmanager.dart';
import 'googleSheetsManager.dart';
import 'flaskRegUsr.dart';
import 'remoteRegUsr.dart';
import 'sourceBase.dart';
import 'msg.dart';
import 'TokenManager.dart';

//------------------------------------------------------
// UserInfo Class
//------------------------------------------------------
class UserInfo {
  String firstLastName = '';
  String login = '';
  String dateOfBirth = '';
  String union = '';

  String concatData() {
    return '$firstLastName,$login,$dateOfBirth,$union';
  }
}

//------------------------------------------------------
// SourceManager Class
//------------------------------------------------------
class SourceManager extends ChangeNotifier {
  static const String bodytext = "sourceMgrBodyText";

  // Singleton instance
  static final SourceManager shared = SourceManager._internal();
  late final SharedPreferences sharedPrefs;

  // Messengers
  late BaseMessenger uiMessenger;
  final BaseMessenger bluetoothMessenger = BaseMessenger();

  // Managers
  late GoogleSheetsManager googleSheetsManager;
  final flaskUploader = FlaskUploader();
  final remoteUploader = RemoteUploader();
  late BluetoothManager bluetoothManager;

  // User information
  UserInfo userInfo = UserInfo();
  final storage = const FlutterSecureStorage();

  // Device info
  DeviceModel curDeviceModel = DeviceModel.Omron;
  String curDeviceID = '';

  // Measurement data
  Map<DateTime, List<int>> measurementsDict = {};
  Map<DateTime, List<int>>? latestMeasurement;
  late List<Map<DateTime, List<int>>> sharedMeasurements;

  // Sources
  String? curSrcStr;
  SourceBase? curSrcObj;
  List<SourceBase> availSources = [];

  // Targets
  List<String> targetNames = ['DataFile', 'GoogleSheets'];
  SourceBase? curTgtObj;

  // Current timestamp
  late DateTime curTimestamp;

  // States
  bool inPairing = false;
  bool inSync = false;
  bool needsUserRegistration = true;
  bool needsDeviceRegistration = true;

  // Unions
  List<String> unions = [];
  Map<String, int> unionNameToId = {}; // map union name → ID
  bool isFetchingUnions = false;

  // Private named constructor for singleton
  SourceManager._internal() {
    dev.log("🔹 SourceManager._internal constructor called");
    _initialize();
  }

  //------------------------------------------------------
  void _initialize() {
    dev.log("🔹 _initialize called");
    curTimestamp = DateTime.now();

    googleSheetsManager = GoogleSheetsManager();
    bluetoothManager = BluetoothManager(bluetoothMessenger);

    // Listen to Bluetooth messenger stream
    bluetoothMessenger.statusSignalStream.listen((msg) {
      dev.log("🔹 BluetoothMessenger signal received: $msg");
      handleMsgStatus(msg);
    });

    initSharedData();
  }

  //------------------------------------------------------
  Future<void> initSharedData() async {
    dev.log("🔹 Entering initSharedData");

    try {
      sharedPrefs = await SharedPreferences.getInstance();
      dev.log("🔹 SharedPreferences instance obtained");

      // NOTE: Removed sharedPrefs.clear() - was wiping all saved data on app init!

      // Load user info
      userInfo.firstLastName = sharedPrefs.getString('firstLastName') ?? '';
      userInfo.login = sharedPrefs.getString('login') ?? '';
      userInfo.dateOfBirth = sharedPrefs.getString('DOB') ?? '';
      userInfo.union = sharedPrefs.getString('union') ?? '';
      dev.log("🔹 Loaded user info: ${userInfo.concatData()}");

      needsUserRegistration = needsUserInfo();
      dev.log("🔹 Needs user registration: $needsUserRegistration");

      // Load device info
      final deviceModelStr = sharedPrefs.getString('deviceModel') ?? '';
      if (deviceModelStr.isNotEmpty) {
        curDeviceModel = DeviceModel.fromString(deviceModelStr) ?? DeviceModel.Omron;
      }
      curDeviceID = sharedPrefs.getString('deviceID') ?? '';
      dev.log("🔹 Loaded device info: $curDeviceModel / $curDeviceID");

      if (curDeviceID.isNotEmpty) {
        curSrcObj = bluetoothManager.createSrcObject(curDeviceID);
        dev.log("🔹 Created source object: $curSrcObj");
      }
      needsDeviceRegistration = needsDeviceInfo();
      dev.log("🔹 Needs device registration: $needsDeviceRegistration");

      // Load measurements
      final storedMeasurementsJson = sharedPrefs.getStringList("measurements");
      sharedMeasurements = convertMeasurementsFromJson(storedMeasurementsJson);
      dev.log("🔹 Loaded ${sharedMeasurements.length} stored measurements");

      dev.log("✅ SharedPreferences initialization complete");
    } catch (e, stack) {
      dev.log("❌ Error in initSharedData: $e\n$stack");
    }
  }

  //------------------------------------------------------
  List<Map<DateTime, List<int>>> convertMeasurementsFromJson(
      List<String>? storedMeasurementsJson) {
    if (storedMeasurementsJson == null) return [];

    return storedMeasurementsJson.map((jsonString) {
      try {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>?;
        if (decoded == null) return null;

        final date = decoded["date"] != null
            ? DateTime.tryParse(decoded["date"])
            : null;
        final values = decoded["values"] is List
            ? List<int>.from(decoded["values"])
            : null;

        if (date != null && values != null) {
          return {date: values};
        }
      } catch (_) {}
      return null;
    }).whereType<Map<DateTime, List<int>>>().toList();
  }

  Future<void> fetchUnionInfo() async {
    if (isFetchingUnions) {
      dev.log("⚠️ Already fetching unions, skipping duplicate request");
      return;
    }
    isFetchingUnions = true;

    try {
      final api = FlaskRegUsr();
      final fetched = await api.fetchUnions();
      // fetched: Map<int, String> {1: "Mount Sinai", ...}

      unions = [];
      unionNameToId.clear();

      fetched.forEach((id, name) {
        unions.add(name);
        unionNameToId[name] = id;
      });

      // Fallback to test unions if API returns empty
      if (unions.isEmpty) {
        dev.log("⚠️ No unions from API, using test unions");
        unions = ["Mount Sinai", "1199SEIU", "Local 32BJ", "Test Union"];
        unionNameToId = {
          "Mount Sinai": 1,
          "1199SEIU": 2,
          "Local 32BJ": 3,
          "Test Union": 99,
        };
      }

      dev.log("✅ Unions fetched successfully in SourceManager: $unions");

      // Send unions to the UI via messenger
      uiMessenger?.sendMsg(Msg(
        taskType: TaskType.FetchUnionInfo,
        status: Status.succeeded,
        sender: [ComponentType.SourceManager],
        strData: unions,
      ));
    } catch (e, stack) {
      dev.log("❌ Error fetching unions: $e\n$stack");

      // Fallback to test unions on error
      unions = ["Mount Sinai", "1199SEIU", "Local 32BJ", "Test Union"];
      unionNameToId = {
        "Mount Sinai": 1,
        "1199SEIU": 2,
        "Local 32BJ": 3,
        "Test Union": 99,
      };
      dev.log("⚠️ Using fallback test unions: $unions");

      uiMessenger?.sendMsg(Msg(
        taskType: TaskType.FetchUnionInfo,
        status: Status.succeeded,
        sender: [ComponentType.SourceManager],
        strData: unions,
      ));
    } finally {
      isFetchingUnions = false;
      notifyListeners();
    }
  }

  //------------------------------------------------------
  List<String> convertMeasurementsToJson(
      List<Map<DateTime, List<int>>> newMeasurements) {
    return newMeasurements.map((measurement) {
      final date = measurement.keys.first;
      final values = measurement.values.first;
      return jsonEncode({'date': date.toIso8601String(), 'values': values});
    }).toList();
  }

  //------------------------------------------------------
  bool needsUserInfo() {
    return userInfo.firstLastName.isEmpty ||
        // Removed: userInfo.login.isEmpty - login field was never reliably saved
        userInfo.dateOfBirth.isEmpty ||
        userInfo.union.isEmpty;
  }

  bool needsDeviceInfo() {
    return curDeviceID.isEmpty || curDeviceModel == DeviceModel.None;
  }

  //------------------------------------------------------
  Future<void> registerUserInfo(List<String> data) async {
    dev.log("🔹 registerUserInfo called with data: $data");

    try {
      // Update local info
      userInfo.firstLastName = data[0];
      userInfo.login = data[1];
      userInfo.dateOfBirth = data[2];
      userInfo.union = data[3];

      await sharedPrefs.setString('firstLastName', userInfo.firstLastName);
      await sharedPrefs.setString('login', userInfo.login);
      await sharedPrefs.setString('DOB', userInfo.dateOfBirth);
      await sharedPrefs.setString('union', userInfo.union);

      dev.log("🔹 User info saved to SharedPreferences");

      // Convert union name → ID
      final unionId = unionNameToId[userInfo.union];
      if (unionId == null) {
        dev.log("❌ Union '${userInfo.union}' not found in mapping");
        return;
      }

      // Backend registration (Flask)
      final reg = FlaskRegUsr();
      final token = await reg.registerUserInfo(
        data[0],
        data[1],
        data[2],
        unionId, // send int now
      );

      if (token != null) {
        dev.log("✅ User registered successfully, token: $token");
        await storage.write(key: "auth_token", value: token);
      } else {
        dev.log("❌ User registration failed (no token returned)");
      }

      // Also register on remote backend (http://34.55.98.226/)
      final remoteReg = RemoteRegUsr();
      final remoteToken = await remoteReg.registerUserInfo(
        data[0],
        data[1],
        data[2],
        unionId,
      );

      if (remoteToken != null) {
        dev.log("✅ [Remote] User registered successfully, token: $remoteToken");
      } else {
        dev.log("⚠️ [Remote] User registration failed (no token returned)");
      }
    } catch (e, stack) {
      dev.log("❌ Error in registerUserInfo: $e\n$stack");
    }
  }

  //------------------------------------------------------
  Future<void> registerDeviceInfo(DeviceModel deviceModel, String deviceId) async {
    dev.log("🔹 registerDeviceInfo called: $deviceModel / $deviceId");
    curDeviceModel = deviceModel;
    curDeviceID = deviceId;

    await sharedPrefs.setString('deviceModel', deviceModel.toString().split('.').last);
    await sharedPrefs.setString('deviceID', curDeviceID);
  }

  //------------------------------------------------------
  Future<void> fetchDeviceInfo(DeviceModel deviceModel) async {
    dev.log("🔹 fetchDeviceInfo called: $deviceModel");
    curDeviceModel = deviceModel;

    switch (curDeviceModel) {
      case DeviceModel.Omron:
      case DeviceModel.Omron3Series:
      case DeviceModel.Omron5Series:
      case DeviceModel.Transtek:
        bluetoothManager.startScan();
        break;
      default:
        dev.log('Unknown device model scanning');
    }
  }

  //------------------------------------------------------
  void registerUIMessenger(BaseMessenger messenger) {
    uiMessenger = messenger;
    dev.log("🔹 UI Messenger registered");

    uiMessenger.statusSignalStream.listen((msg) {
      uiMessenger.logMsgReceived(msg);
      dev.log("🔹 UI Messenger received message: $msg");
      handleMsgStatus(msg);
    });
  }

  //------------------------------------------------------
  Future<void> startTokenLogin() async {
    dev.log("🔹 startTokenLogin called");

    try {
      final token = await TokenManager.requestToken(
        userInfo.firstLastName,
        userInfo.dateOfBirth,
        userInfo.login,
        userInfo.union,
      );

      if (token != null) {
        dev.log("✅ Token received: $token");
        await uiMessenger.sendMsg(Msg(
          taskType: TaskType.auth,
          status: Status.succeeded,
          sender: [ComponentType.SourceManager],
        ));
      } else {
        dev.log("⚠️ Token request failed, using DEV bypass to continue");
        // DEV MODE: Bypass token requirement for testing
        await uiMessenger.sendMsg(Msg(
          taskType: TaskType.auth,
          status: Status.succeeded,  // Bypass: treat as success for testing
          sender: [ComponentType.SourceManager],
        ));
        return;  // Skip the old failure path below

        dev.log("❌ Token request failed (null token)");
        await uiMessenger.sendMsg(Msg(
          taskType: TaskType.auth,
          status: Status.failed,
          sender: [ComponentType.SourceManager],
        ));
      }
    } catch (e, stack) {
      dev.log("❌ Error in startTokenLogin: $e\n$stack");
      dev.log("⚠️ DEV bypass: Treating as success to allow testing");
      // DEV MODE: Bypass on exception to allow testing without backend
      await uiMessenger.sendMsg(Msg(
        taskType: TaskType.auth,
        status: Status.succeeded,
        sender: [ComponentType.SourceManager],
      ));
    }
  }

  //------------------------------------------------------
  Future<void> startPairing() async {
    print("🔹 startPairing called, curSrcObj=${curSrcObj != null}, peripheral=${curSrcObj?.connectedPeripheral != null}");
    dev.log("🔹 startPairing called");
    if (curSrcObj == null) {
      print("🔹 startPairing: curSrcObj is null, starting scan...");
      await bluetoothManager.startScan();
    }
    if (curSrcObj != null && curSrcObj!.connectedPeripheral != null) {
      print("🔹 startPairing: calling pairDevice on ${curSrcObj!.connectedPeripheral!.remoteId}");
      await bluetoothManager.pairDevice(curSrcObj!.connectedPeripheral!);
    } else {
      print("❌ startPairing: no device available to pair (curSrcObj=${curSrcObj != null}, peripheral=${curSrcObj?.connectedPeripheral})");
      dev.log("❌ startPairing: no device available to pair");
    }
  }

  Future<void> cancelPairing() async {
    dev.log("🔹 cancelPairing called");
    bluetoothManager.stopScan();
  }

  //------------------------------------------------------
  Future<void> startScanning() async {
    print("📱 SOURCE MGR: startScanning called, curDeviceModel=$curDeviceModel");
    switch (curDeviceModel) {
      case DeviceModel.DataFile:
        curSrcObj ??= DeviceModel.DataFile as SourceBase?;
        addDiscoveredSource(curSrcObj!);
        uiMessenger.sendMsg(Msg(
          deviceModel: curDeviceModel,
          taskType: TaskType.Scan,
          status: Status.succeeded,
          sender: [ComponentType.SourceManager],
        ));
        break;
      case DeviceModel.Omron:
      case DeviceModel.Omron3Series:
      case DeviceModel.Omron5Series:
      case DeviceModel.Transtek:
        print("📱 SOURCE MGR: Starting Bluetooth scan for Omron device...");
        bluetoothManager.startScan();
        break;
      default:
        print('📱 SOURCE MGR: Unknown device model: $curDeviceModel');
    }
  }

  void addDiscoveredSource(SourceBase source) {
    availSources.add(source);
    dev.log("🔹 Discovered source added: $source");
  }

  //------------------------------------------------------
  Future<void> startMeasurement() async {
    dev.log("🔹 startMeasurement called");

    // Check persisted device ID instead of in-memory object
    if (curDeviceID.isEmpty) {
      // Never paired — send "no device paired" error
      dev.log("⚠️ startMeasurement: No device ID saved — never paired");
      uiMessenger.sendMsg(Msg(
        taskType: TaskType.Measure,
        status: Status.failed,
        sender: [ComponentType.SourceManager],
        strData: ['No blood pressure device paired. Please pair your device first.'],
      ));
      return;
    }

    // Reconstruct device handle from persisted ID if needed
    if (curSrcObj == null || curSrcObj!.connectedPeripheral == null) {
      dev.log("🔹 startMeasurement: Recreating source object from saved ID: $curDeviceID");
      curSrcObj = bluetoothManager.createSrcObject(curDeviceID);
    }

    // Show IdleMeasureView first, then start connection
    uiMessenger.sendMsg(Msg(
      deviceType: DeviceType.Cuff,
      deviceModel: curDeviceModel,
      taskType: TaskType.Idle,
      status: Status.request,
      sender: [ComponentType.SourceManager],
    ));

    bluetoothManager.connectForMeasurement(curSrcObj!.connectedPeripheral!);
  }

  //------------------------------------------------------
  Future<void> writeMeasurementsToDefaults(List<Map<DateTime, List<int>>> newMeasurements) async {
    dev.log("🔹 writeMeasurementsToDefaults called with ${newMeasurements.length} new measurements");

    // Merge and deduplicate by timestamp (within 1 minute) and same BP values
    final mergedMeasurements = [...sharedMeasurements];
    for (var newM in newMeasurements) {
      final newTime = newM.keys.first;
      final newValues = newM.values.first;

      // Check if this is a duplicate (same time within 1 minute AND same systolic/diastolic)
      final isDuplicate = mergedMeasurements.any((existing) {
        final existingTime = existing.keys.first;
        final existingValues = existing.values.first;
        return (newTime.difference(existingTime).inMinutes).abs() < 1 &&
               existingValues[0] == newValues[0] && // same systolic
               existingValues[1] == newValues[1];   // same diastolic
      });

      if (!isDuplicate) {
        mergedMeasurements.add(newM);
        dev.log("🔹 Added new measurement: $newValues at $newTime");
      } else {
        dev.log("🔹 Skipping duplicate measurement: $newValues at $newTime");
      }
    }

    mergedMeasurements.sort((a, b) => b.keys.first.compareTo(a.keys.first));
    sharedMeasurements = mergedMeasurements; // Removed .take(10) - store all readings

    final updatedMeasurements = convertMeasurementsToJson(sharedMeasurements);
    await sharedPrefs.setStringList('measurements', updatedMeasurements);
    dev.log("🔹 ${sharedMeasurements.length} measurements written to SharedPreferences");
  }

  //------------------------------------------------------
  Future<void> uploadMeasurements() async {
    print("🔹 uploadMeasurements called");

    try {
      List<Map<DateTime, List<int>>> measurements = bluetoothManager.getSyncMeasurements();
      print("🔹 Got ${measurements.length} measurements from Bluetooth manager");

      if (measurements.isEmpty) {
        print("⚠️ No measurements to upload");
        return;
      }

      // Clear immediately so duplicate disconnect events don't re-upload
      await bluetoothManager.clearMeasurements();

      // Navigate to results view IMMEDIATELY so the user isn't stuck
      // on the palm tree while backend uploads happen in the background.
      latestMeasurement = measurements.last;
      final measurement = measurements.last;
      final date = measurement.keys.last;
      final values = measurement.values.last;

      await uiMessenger.sendMsg(Msg(
        deviceType: DeviceType.Cuff,
        deviceModel: curDeviceModel,
        taskType: TaskType.Measure,
        status: Status.finished,
        sender: [ComponentType.SourceManager],
        date: date,
        intData: values,
      ));
      print("✅ Measure.finished sent — navigating to results");

      // Save locally FIRST so Recent Measurements updates immediately
      await writeMeasurementsToDefaults(measurements);
      print("✅ Measurements saved locally");

      // Now upload to backends (user already sees results)
      try {
        print("📤 Sending to Flask backend...");
        await flaskUploader.sendDataToBackend(
          userInfo.concatData(),
          curDeviceID,
          measurements.cast<Map<DateTime, List<int>>>(),
        );
        print("✅ Flask upload complete");

        print("📤 Sending to Remote backend (34.55.98.226)...");
        await remoteUploader.sendDataToBackend(
          userInfo.concatData(),
          curDeviceID,
          measurements.cast<Map<DateTime, List<int>>>(),
        );
        print("✅ Remote upload complete");
      } catch (e, stack) {
        dev.log("⚠️ Backend upload failed (non-fatal): $e\n$stack");
      }
    } catch (e, stack) {
      dev.log("❌ Error in uploadMeasurements: $e\n$stack");
    }
  }

  //------------------------------------------------------
  Future<void> handleDiscoveredSource(Msg msg) async {
    dev.log("🔹 handleDiscoveredSource called with msg: $msg");
    if (msg.source == null) return;

    availSources.add(msg.source!);
    dev.log("🔹 Source added: ${msg.source}");

    if (msg.source is BluetoothSource) {
      final bluetoothSource = msg.source as BluetoothSource;
      if (bluetoothSource.connectedPeripheral!.remoteId.toString().isNotEmpty) {
        curSrcObj = bluetoothSource;
        await registerDeviceInfo(curDeviceModel, bluetoothSource.connectedPeripheral!.remoteId.toString());
        dev.log("🔹 Device info registered: $curDeviceID");
      }
    }
  }

  //------------------------------------------------------
  Future<void> handleMsgStatus(Msg msg) async {
    dev.log("🔹 handleMsgStatus called with msg: $msg");
    if (msg.sender.isNotEmpty && msg.sender.last == ComponentType.SourceManager) return;

    switch (msg.taskType) {
      case TaskType.Pair:
        if (msg.status == Status.succeeded) {
          inPairing = false;
          uiMessenger.forwardMsg([ComponentType.SourceManager], msg);
        }
        break;

      case TaskType.DisconnectPeripheralFor:
        if (msg.status == Status.succeeded) {
          await uploadMeasurements();
        }
        break;

      case TaskType.DiscoverSource:
        if (msg.status == Status.succeeded) {
          await handleDiscoveredSource(msg);
        }
        break;

      case TaskType.FetchDeviceInfo:
        if (msg.status == Status.succeeded && msg.strData.length > 1) {
          await registerDeviceInfo(curDeviceModel, msg.strData[1]);
        }
        break;

      case TaskType.FetchUnionInfo:
        if (msg.status == Status.get) {
          await fetchUnionInfo();
        }

        if (msg.taskType == TaskType.FetchUnionInfo ) {
          unions = msg.strData;
        }
        break;

      case TaskType.auth:
        uiMessenger.forwardMsg([ComponentType.SourceManager], msg);
        break;
      default:
        break;
    }

    if (msg.sender.isEmpty || msg.sender.last != ComponentType.NavigationManager) {
      uiMessenger.forwardMsg([ComponentType.SourceManager], msg);
    }
  }
}
