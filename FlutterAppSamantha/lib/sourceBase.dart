import 'dart:async';
import 'SourceManager.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';


enum SourceProtocolType 
{
  dataFile,
  // Add other protocols if needed
}

class SourceBase 
{
  String?            sourceName;
  SourceProtocolType sourceProtocol;
  SourceManager?     sourceManager;

  final              _measurementController = StreamController<Tuple3<DateTime, List<int>, bool>>.broadcast();

  Stream<Tuple3<DateTime, List<int>, bool>> get measurementPublisher => _measurementController.stream;

  SourceBase()
      : sourceName = "DataFile",
        sourceProtocol = SourceProtocolType.dataFile;

  get connectedPeripheral => null;

  //-------------------------------------------------------------------------
  void connect() 
  {
    // Intentionally left blank for override in subclass
  }

  //-------------------------------------------------------------------------
  void startScanning() 
  {
    // Intentionally left blank for override in subclass
  }

  //-------------------------------------------------------------------------
  void startMeasurement() 
  {
    // Intentionally left blank for override in subclass
  }

  //-------------------------------------------------------------------------
  void stopMeasurement() 
  {
    // Intentionally left blank for override in subclass
  }
}

// Utility class for Tuple3
class Tuple3<T1, T2, T3> 
{
  final T1 item1;
  final T2 item2;
  final T3 item3;

  Tuple3 (this.item1, this.item2, this.item3);
}


class BluetoothSource extends SourceBase 
{
  bool                  isConnecting         = false;
  final FlutterBluePlus flutterBlue          = FlutterBluePlus(); // Direct constructor usage
  @override
  BluetoothDevice?      connectedPeripheral; // Strong reference to the peripheral

  // Constructor
  BluetoothSource ({BluetoothDevice? peripheral}) : super() 
  {
    connectedPeripheral = peripheral; // Initialize with the provided peripheral or null
  }
}