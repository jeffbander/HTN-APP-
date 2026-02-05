// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'sourceBase.dart';

enum ComponentType 
{
  SourceManager,
  NavigationManager,
  BTManager,
  Source,
  View,
  CentralManager,
  None;

  @override
  String toString () 
  {
    switch (this) 
    {
      case ComponentType.SourceManager:
        return 'SourceManager';
      case ComponentType.NavigationManager:
        return 'NavigationManager';
      case ComponentType.BTManager:
        return 'BluetoothManager';
      case ComponentType.Source:
        return 'Source';
      case ComponentType.View:
        return 'View';
      case ComponentType.CentralManager:
        return 'CentralManager';
      case ComponentType.None:
        return 'None';
    }
  }

  static ComponentType? fromString (String value) 
  {
    return ComponentType.values.firstWhere
    (
      (type) => type.toString().toLowerCase() == value.toLowerCase()
    );
  }
}

enum DeviceType 
{
  Phone,
  Cuff,
  db, 
  None;

  @override
  String toString () 
  {
    switch (this) 
    {
      case DeviceType.Phone:
        return 'Phone';
      case DeviceType.db:
        return 'db';
      case DeviceType.Cuff:
        return 'Cuff';
      case DeviceType.None:
        return 'None';
    }
  }

  static DeviceType? fromString(String value) 
  {
    return DeviceType.values.firstWhere
    (
      (type) => type.toString().toLowerCase() == value.toLowerCase()
    );
  }
}

enum DeviceModel
{
  iPhone,
  Android,
  Omron,
  Omron3Series,
  Omron5Series,
  Transtek,
  NoCuff,
  DataFile,
  None;

  @override
  String toString()
  {
    switch (this)
    {
      case DeviceModel.iPhone:
        return 'iPhone';
      case DeviceModel.Android:
        return 'Android';
      case DeviceModel.Omron:
        return 'Omron';
      case DeviceModel.Omron3Series:
        return 'Omron3Series';
      case DeviceModel.Omron5Series:
        return 'Omron5Series';
      case DeviceModel.Transtek:
        return 'Transtek';
      case DeviceModel.NoCuff:
        return 'NoCuff';
      case DeviceModel.DataFile:
        return 'DataFile';
      case DeviceModel.None:
        return 'None';
    }
  }

  static DeviceModel? fromString(String value) 
  {
    return DeviceModel.values.firstWhere(
      (type) => type.toString().toLowerCase() == value.toLowerCase(),
    );
  }
}

enum TaskType 
{
  Launch,
  RegisterUserInfo,
  RegisterDeviceInfo,
  Power,
  Scan,
  ScanTimer,
  Connect,
  DiscoverSource, // peripherals
  DiscoverServices,
  DiscoverCharacteristics,
  CharacteristicValue,
  FetchDeviceInfo,
  Measure,
  Upload,
  SourceChangeRequest,
  ShowSettings,
  UpdateValue,
  DiscoverCharacteristicsFor,
  DiscoverServiceFor,
  DisconnectPeripheralFor,
  FailToConnectFor,
  DidConnectFor,
  Logger,
  ShowStartMeasurementView,
  ShowLogView,
  Sync,
  Pair,
  ShowHelp,
  None, 
  startMeasurement, 
  measurement,
  FetchUnionInfo,
  auth, 
  Idle;

 @override
 String toString() 
 {
  switch (this)
    {
      case TaskType.Launch:
        return "Launch";
      case TaskType.RegisterUserInfo:
        return "RegisterUserInfo";
      case TaskType.RegisterDeviceInfo:
        return "RegisterDeviceInfo";
      case TaskType.Power:
        return "Power";
      case TaskType.Scan:
        return "Scan";
      case TaskType.ScanTimer:
        return "ScanTimer";
      case TaskType.Connect:
        return "Connect";
      case TaskType.DiscoverSource:
        return "DiscoverSource";
      case TaskType.DiscoverServices:
        return "DiscoverServices";
      case TaskType.DiscoverCharacteristics:
        return "DiscoverCharacteristics";
      case TaskType.CharacteristicValue:
        return "CharacteristicValue";
      case TaskType.FetchDeviceInfo:
        return "FetchDeviceInfo";
      case TaskType.Measure:
        return "Measure";
      case TaskType.Upload:
        return "Upload";
      case TaskType.SourceChangeRequest:
        return "SourceChangeRequest";
      case TaskType.ShowSettings:
        return "ShowSettings";
      case TaskType.UpdateValue:
        return "UpdateValue";
      case TaskType.DiscoverCharacteristicsFor:
        return "DiscoverCharacteristicsFor";
      case TaskType.DiscoverServiceFor:
        return "DiscoverServiceFor";
      case TaskType.DisconnectPeripheralFor:
        return "DisconnectPeripheralFor";
      case TaskType.FailToConnectFor:
        return "FailToConnectFor";
      case TaskType.DidConnectFor:
        return "DidConnectFor";
      case TaskType.Logger:
        return "Logger";
      case TaskType.ShowStartMeasurementView:
        return "ShowStartMeasurementView";
      case TaskType.ShowLogView:
        return "ShowLogView";
      case TaskType.Sync:
        return "Sync";
      case TaskType.Pair:
        return "Pair";
      case TaskType.ShowHelp:
        return "ShowHelp";
      case TaskType.None:
        return "None";
      case TaskType.startMeasurement:
        return "startMeasurement";
      case TaskType.measurement:
        return "measurement";
      case TaskType.Idle:
        return "idle";
      case TaskType.FetchUnionInfo:
        return "fetchUnionInfo"; 
      case TaskType.auth:
        return "auth";
    }
  }

  static TaskType? fromString(String string) 
  {
    for (TaskType type in TaskType.values) 
    {
      if (type.toString().toLowerCase() == string.toLowerCase()) 
      {
        return type;
      }
    }
    return null;
  }
}


enum Status 
{
  connected,
  disconnected,
  inProgress,
  running,
  waiting,
  poweredOn,
  poweredOff,
  notStarted,
  started,
  finished,
  succeeded,
  failed,
  request,
  update,
  cancel,
  get, 
  oldMeasurement,
  None;

  @override
  String toString () 
  {
    switch (this)
    {
      case Status.connected:
        return "connected";
      case Status.disconnected:
        return "disconnected";
      case Status.inProgress:
        return "inProgress";
      case Status.running:
        return "running";
      case Status.waiting:
        return "waiting";
      case Status.poweredOn:
        return "poweredOn";
      case Status.poweredOff:
        return "poweredOff";
      case Status.notStarted:
        return "notStarted";
      case Status.started:
        return "started";
      case Status.finished:
        return "finished";
      case Status.succeeded:
        return "succeeded";
      case Status.failed:
        return "failed";
      case Status.request:
        return "request";
      case Status.update:
        return "update";
      case Status.cancel:
        return "cancel";
      case Status.oldMeasurement:
        return "oldMeasurement";
      case Status.get:
        return "get"; 
      case Status.None:
        return "None";
    }
  }

  static Status? fromString(String string) 
  {
    for (Status type in Status.values) 
    {
      if (type.toString().toLowerCase() == string.toLowerCase()) 
      {
        return type;
      }
    }
    return null;
  }
}

enum SourceProtocolType 
{
  dataFile,
  bluetooth;

  @override
  String toString () 
  {
    switch (this) 
    {
      case SourceProtocolType.dataFile:
        return 'DataFile';
      case SourceProtocolType.bluetooth:
        return 'Bluetooth';
    }
  }

  static SourceProtocolType? fromString(String string) 
  {
    for (SourceProtocolType type in SourceProtocolType.values) 
    {
      if (type.toString().toLowerCase() == string.toLowerCase()) 
      {
        return type;
      }
    }
    return null;
  }
}

class Msg 
{
          // Public members
  late double                     msgId;
  DeviceType                      deviceType;
  DeviceModel                     deviceModel;
  TaskType                        taskType;
  Status                          status;
  List<ComponentType>             sender;

          // Types of data that can be sent
  DateTime                        date;
  List<String>                    strData;
  List<int>                       intData;

  SourceBase?                     source;
  List<Map<DateTime, List<int>>>  measurement;
  List<int>?                      uiMeasurement;

  static double                   idCounter = 0.0;

          // Custom initializer
  Msg ({
        this.deviceType  = DeviceType.None,
        this.deviceModel = DeviceModel.None,
        this.taskType    = TaskType.None,
        this.status      = Status.None,
        List<ComponentType>? sender,
        DateTime? date,
        List<String>? strData,
        List<int>? intData,
        this.source,
        Map<DateTime, List<int>>? lastMeasurement,
        List<Map<DateTime, List<int>>>? measurement,
        this.uiMeasurement,
       }) : sender      = sender ?? <ComponentType>[],
            date        = date ?? DateTime.now(),
            strData     = strData ?? <String>[],
            intData     = intData ?? <int>[],
            measurement = measurement ?? <Map<DateTime, List<int>>>[] 
  {
      // Automatically assign and increment msgId
    msgId      = idCounter;
    idCounter += 1;
  }

  Msg copy() 
  {
    // Create a new Msg instance with the same properties
    return Msg (deviceType:  deviceType,
                deviceModel: deviceModel,
                taskType:    taskType,
                status:      status,
                sender:      List<ComponentType>.from(sender),
                date:        date,
                strData:     List<String>.from(strData),
                intData:     List<int>.from(intData),
                source:      source,
                measurement: measurement.map((map) 
          {
            return map.map ((key, value) => MapEntry (key, List<int>.from (value)));
          }).toList(),
          uiMeasurement: uiMeasurement != null ? List<int>.from (uiMeasurement!) : null);
  }

} // end class Msg

class BaseMessenger 
{
      // Subject properties are encapsulated within the base class
  final StreamController<Msg> statusSignal = StreamController<Msg>.broadcast ();

  // final StreamController<(
  //   DeviceType,
  //   DeviceModel,
  //   TaskType,
  //   Status,
  //   List<ComponentType>,
  //   DateTime,
  //   List<String>,
  //   List<int>
  // )> statusTupleSignal = StreamController<(
  //   DeviceType,
  //   DeviceModel,
  //   TaskType,
  //   Status,
  //   List<ComponentType>,
  //   DateTime,
  //   List<String>,
  //   List<int>
  // )>.broadcast();

  Stream<Msg> get statusSignalStream => statusSignal.stream;

  Map<double, Msg> messagesSent = {};
  Map<double, Msg> messagesReceive = {};

  bool blockMsgs = false;
  List<Msg> keepOutMsgStorage = [];

      // Implement default messaging methods
  Future<void> sendMsg(Msg msg) async
  {
    messagesSent[msg.msgId] = msg;
    statusSignal.add(msg);
  }

  // void 
  // sendoMsgTuples
  // (
  //   {
  //     required DeviceType deviceType, // Mark as required if it must be provided
  //     required DeviceModel deviceModel, // Mark as required if it must be provided
  //     TaskType taskType = TaskType.None,
  //     Status status = Status.None,
  //     List<ComponentType> sender = const [],
  //     DateTime? dateData, // Make it nullable
  //     List<String> strData = const [],
  //     List<int> intData = const [],
  //   }
  // ) 
  // {
  //   dateData ??= DateTime.now(); // Assign default value if not provided
  //   statusTupleSignal.add((deviceType, deviceModel, taskType, status, sender, dateData, strData, intData));
  // }

  // (String, String, String, String, String, String, String, String) 
  // toTupleStrings(Msg msg) 
  // {
  //   final dateString = msg.date.toIso8601String();
  //   return (
  //     msg.deviceType.toString(),
  //     msg.deviceModel.toString(),
  //     msg.taskType.toString(),
  //     msg.status.toString(),
  //     dateString,
  //     msg.sender.map((e) => e.toString()).join(', '),
  //     msg.strData.join(', '),
  //     msg.intData.map((e) => e.toString()).join(', '),
  //   );
  // }

  // (DeviceType?, DeviceModel?, TaskType?, Status?, List<ComponentType>, DateTime, List<String>, List<int>) 
  // toTuple(Msg msg) 
  // {
  //   return (msg.deviceType,
  //     msg.deviceModel,
  //     msg.taskType,
  //     msg.status,
  //     msg.sender,
  //     msg.date,
  //     msg.strData,
  //     msg.intData,
  //   );
  // }

  void dump(Msg msg) 
  {
    /*
    print("DeviceType: ${msg.deviceType}");
    print("DeviceModel: ${msg.deviceModel}");
    print("TaskType: ${msg.taskType}");
    print("Status: ${msg.status}");
    print("Sender: ${msg.sender}");
    print("Date: ${msg.date}");
    print("Str Data: ${msg.strData}");
    print("Int Data: ${msg.intData}");
    */
  }

  Future<void> registerMessenger (BaseMessenger messenger) async
  {
    messenger.statusSignal.stream.listen ((msg) => handleMsgStatus (msg));
    // messenger.statusTupleSignal.stream.listen ((tuple) 
    // {
    //   handleMsgStatusTuple (
    //     deviceType: tuple.$1,
    //     deviceModel: tuple.$2,
    //     taskType: tuple.$3,
    //     status: tuple.$4,
    //     componentType: tuple.$5,
    //     date: tuple.$6,
    //     strData: tuple.$7,
    //     intData: tuple.$8,
    //   );
    // });
  }

  Future<void> handleMsgStatus (Msg msg) async
  {
    messagesReceive[msg.msgId] = msg;
  }

  void handleMsgStatusTuple({
    required DeviceType deviceType,
    required DeviceModel deviceModel,
    required TaskType taskType,
    required Status status,
    required List<ComponentType> componentType,
    required DateTime date,
    required List<String> strData,
    required List<int> intData,
  }) 
  {
    // Default handling logic (can be overridden)
  }

  Future<void> forwardMsg (List<ComponentType> newSender, Msg msg) async
  {
    final newMsg = msg.copy();
    if (newSender.isNotEmpty) 
    {
      newMsg.sender.add (newSender.first);
    }

    newMsg.msgId += 0.1;
    sendMsg (newMsg);
  }

  void logMsgSent (Msg msg) 
  {
    messagesSent[msg.msgId] = msg;
   // print("[${msg.msgId}] [${msg.sender.last}] [${msg.taskType}]");
  }

  void logMsgReceived (Msg msg) 
  {
    messagesReceive[msg.msgId] = msg;
  }
} // end BaseMessenger Class

