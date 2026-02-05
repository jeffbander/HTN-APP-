import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'commonWidgets.dart';
import 'msg.dart';
import 'noCuffView.dart';

class DeviceGrid extends StatelessWidget {
  final List<List<dynamic>>? supportedSources;
  final ValueNotifier<int?> selectedIndex;
  final VoidCallback onRegisterPressed;

  const DeviceGrid({
    super.key,
    this.supportedSources,
    required this.selectedIndex,
    required this.onRegisterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20.0,
                mainAxisSpacing: 20.0,
              ),
              itemCount: supportedSources?.length ?? 0,
              itemBuilder: (context, index) {
                List<dynamic> source = supportedSources?[index] ?? [];
                return sourceView(context, source, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget sourceView(BuildContext context, List<dynamic> source, int index) {
    return ValueListenableBuilder<int?> (
      valueListenable: selectedIndex,
      builder: (context, selected, _) {
        bool isSelected = selected == index;

        return GestureDetector(
          onTap: () {
            selectedIndex.value = index;
          },
          child: Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  source.isNotEmpty ? source[0].toString() : "Unknown Device",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RegisterDeviceView extends StatefulWidget {
  final BaseMessenger? messenger;
  final List<List<dynamic>>? supportedSources;
  final String? initialDeviceId;

  const RegisterDeviceView({
    super.key,
    this.messenger,
    this.supportedSources,
    this.initialDeviceId,
  });

  @override
  _RegisterDeviceViewState createState() => _RegisterDeviceViewState();
}

class _RegisterDeviceViewState extends State<RegisterDeviceView> {
  bool isRegisterClicked = false;
  bool isLogVisible = false;
  String deviceID = "";
  late ValueNotifier<int?> selectedIndex;
  StreamSubscription? _messengerSubscription;

  @override
  void initState() {
    super.initState();
    selectedIndex = ValueNotifier<int?>(null);
    deviceID = widget.initialDeviceId ?? "";

    // Listen for pairing results
    _messengerSubscription = widget.messenger?.statusSignalStream.listen((msg) {
      _handlePairingResult(msg);
    });
  }

  @override
  void dispose() {
    _messengerSubscription?.cancel();
    super.dispose();
  }

  void _handlePairingResult(Msg msg) {
    if (msg.taskType == TaskType.Pair) {
      if (msg.status == Status.succeeded) {
        log("✅ Pairing succeeded!");
        setState(() {
          isRegisterClicked = false;
        });
        // Navigation will be handled by NavigationManager
      } else if (msg.status == Status.failed) {
        log("❌ Pairing failed");
        setState(() {
          isRegisterClicked = false;
        });
        _showPairingErrorDialog();
      }
    } else if (msg.taskType == TaskType.Scan && msg.status == Status.failed) {
      log("❌ Scan failed - no device found");
      setState(() {
        isRegisterClicked = false;
      });
      _showScanErrorDialog();
    }
  }

  void _showPairingErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Pairing Failed"),
          content: const Text(
            "Could not pair with the blood pressure cuff.\n\n"
            "Please ensure:\n"
            "• The cuff is in pairing mode (Bluetooth icon blinking)\n"
            "• Phone Bluetooth is enabled\n"
            "• You're close to the device\n\n"
            "Try again?"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showOmronPairingPopup();
              },
              child: const Text("Retry"),
            ),
          ],
        );
      },
    );
  }

  void _showScanErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Device Not Found"),
          content: const Text(
            "No blood pressure cuff was detected.\n\n"
            "Please ensure:\n"
            "• The cuff is powered on\n"
            "• The cuff is in pairing mode (press Bluetooth button)\n"
            "• Phone Bluetooth is enabled\n"
            "• You're within range of the device"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  HeaderView(
                    messenger: widget.messenger,
                    title: 'REGISTER CUFF',
                    onToggleLogVisibility: () {
                      setState(() {
                        isLogVisible = !isLogVisible;
                      });
                    },
                    onPressed: () {},
                  ),
                  const Divider(),
                  Image.asset("assets/Logotrans.png", height: 100),
                  const SizedBox(height: 10),
                  const Text("Pick Your Blood Pressure Cuff"),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: DeviceGrid(
                        supportedSources: widget.supportedSources,
                        selectedIndex: selectedIndex,
                        onRegisterPressed: handleRegisterButtonPress,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(text: deviceID),
                    decoration: const InputDecoration(labelText: "Device ID"),
                    enabled: false,
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<int?>(
                    valueListenable: selectedIndex,
                    builder: (context, selected, _) {
                      String buttonText = "Make Selection Above";
                      if (selected != null && widget.supportedSources != null) {
                        List<dynamic> selectedSource = widget.supportedSources![selected];
                        if (selectedSource.isNotEmpty &&
                            (selectedSource.first == DeviceModel.Omron ||
                             selectedSource.first == DeviceModel.Omron3Series ||
                             selectedSource.first == DeviceModel.Omron5Series ||
                             selectedSource.first == DeviceModel.Transtek)) {
                          buttonText = "Pair";
                        } else {
                          buttonText = "Send Information";
                        }
                      }

                      return ElevatedButton(
                        onPressed: isRegisterClicked ? null : handleRegisterButtonPress,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Text(buttonText),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay during pairing
          if (isRegisterClicked)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      "Searching for device...\nPlease wait",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void handleRegisterButtonPress() {
    if (selectedIndex.value == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("No Selection"),
            content: const Text("Please select a blood pressure cuff before proceeding."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    } else {
      List<dynamic> selectedSource = widget.supportedSources?[selectedIndex.value!] ?? [];
      if (selectedSource.isNotEmpty &&
          (selectedSource.first == DeviceModel.Omron ||
           selectedSource.first == DeviceModel.Omron3Series ||
           selectedSource.first == DeviceModel.Omron5Series ||
           selectedSource.first == DeviceModel.Transtek)) {
        showOmronPairingPopup();
      } else {
        showNoCuffConfirmation();
      }
    }
  }

  void showOmronPairingPopup() 
  {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Pairing Instructions"),
          content: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "To pair the cuff, press the ",
                  style: TextStyle(color: Colors.black),
                ),
                WidgetSpan(
                  child: Image.asset(
                    'assets/PairingButton.png', // Replace with your image asset
                    width: 40,  // Adjust size as needed
                    height: 40, // Adjust size as needed
                    fit: BoxFit.contain,
                  ),
                ),
                TextSpan(
                  text: " button on the cuff.\n\nFollow the pop-ups on your phone screen, pressing pair when propmpted. \n\nNote: Ensure phone's Bluetooth is on. This may take a moment.",
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                sendPairingRequest();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }


  void sendPairingRequest () 
  {
    setState(()
    {
      isRegisterClicked = true; 
    }); 

    widget.messenger?.sendMsg (Msg (deviceModel: widget.supportedSources? [selectedIndex.value!] [0] as DeviceModel,
                                    taskType: TaskType.Pair,
                                    status: Status.request,
                                    sender: [ComponentType.View])); 
  }

  void showNoCuffConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Selection"),
          content: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black),
              children: <TextSpan>[
                const TextSpan(text: "Do you have an "),
                TextSpan(
                  text: "Omron ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: "Blood Pressure Cuff?"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Yes"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const NoCuffView()),
                );
              },
              child: const Text("No"),
            ),
          ],
        );
      },
    );
  }
}
