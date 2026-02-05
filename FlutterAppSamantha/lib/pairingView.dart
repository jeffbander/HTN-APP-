// import 'package:flutter/material.dart';
// import 'package:hypertensionpreventionprogram/logView.dart';
// import 'package:hypertensionpreventionprogram/msg.dart';

// class PairingView extends StatefulWidget {
//   final DeviceModel curDeviceModel;
//   final BaseMessenger messenger;
//   final LogView logView;

//   const PairingView({super.key, 
//     required this.messenger,
//     required this.logView,
//     required this.curDeviceModel,
//   });

//   @override
//   _PairingViewState createState() => _PairingViewState();
// }

// class _PairingViewState extends State<PairingView> {
//   bool isClicked = false;
//   List<String> statusMessages = [];
//   double imageOpacity = 0.0;
//   double captionOpacity = 0.0;
//   String deviceImageName = "assets/omronStep1.png"; // Default image path
//   String deviceInfoText =
//       "Press button B on the cuff so the phone can find the device.";
//   bool isLogVisible = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("HOME"),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.visibility),
//             onPressed: () {
//               setState(() {
//                 isLogVisible = !isLogVisible;
//               });
//             },
//           )
//         ],
//       ),
//       body: Column(
//         children: [
//           Divider(),
//           _buildStartAction(),
//           Spacer(),
//           _buildDeviceInfoSection(),
//           if (isLogVisible) widget.logView,
//         ],
//       ),
//     );
//   }

//   Widget _buildDeviceInfoSection() {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         children: [
//           AnimatedOpacity(
//             opacity: imageOpacity,
//             duration: Duration(seconds: 1),
//             child: Image.asset(
//               deviceImageName,
//               height: 150,
//               fit: BoxFit.contain,
//             ),
//           ),
//           SizedBox(height: 8),
//           AnimatedOpacity(
//             opacity: captionOpacity,
//             duration: Duration(seconds: 1),
//             child: Text(
//               deviceInfoText,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStartAction() {
//     return Center(
//       child: ElevatedButton(
//         style: ElevatedButton.styleFrom(
//           shape: CircleBorder(), 
//           backgroundColor: isClicked ? Colors.green[300] : Colors.green,
//           padding: EdgeInsets.all(50),
//         ),
//         onPressed: () {
//           setState(() {
//             if (!isClicked) {
//               // Start action
//               statusMessages.clear();
//               updateDeviceInfo(DeviceState.findDeviceID);
//               widget.messenger.sendMessage(Msg(
//                   taskType: TaskType.connect,
//                   status: Status.request,
//                   sender: [Sender.view]));
//               imageOpacity = 1.0;
//               captionOpacity = 1.0;
//             } else {
//               // Cancel action
//               widget.messenger.sendMessage(Msg(
//                   taskType: TaskType.connect,
//                   status: Status.cancel,
//                   sender: [Sender.view]));
//               updateDeviceInfo(DeviceState.cancelled);
//             }
//             isClicked = !isClicked;
//           });
//         },
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               "Blood Pressure",
//               style: TextStyle(fontSize: 14, color: Colors.black54),
//             ),
//             SizedBox(height: 10),
//             Text(
//               isClicked ? "Cancel" : "Pair",
//               style: TextStyle(fontSize: 24, color: Colors.white),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void updateDeviceInfo(DeviceState state) {
//     setState(() {
//       switch (state) {
//         case DeviceState.findDeviceID:
//           deviceImageName = "assets/omronStep1.png";
//           deviceInfoText = "Press button A on the cuff to take a measurement.";
//           break;
//         case DeviceState.readyToMeasure:
//           deviceImageName = "assets/omronStep1.png"; // Replace with actual path
//           deviceInfoText =
//               "Put the cuff on your arm and press button A when you're ready to take a reading.";
//           break;
//         case DeviceState.cancelled:
//           deviceInfoText = "Connection cancelled. Please try again.";
//           break;
//       }
//     });
//   }
// }