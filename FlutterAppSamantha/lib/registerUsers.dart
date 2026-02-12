import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'env.dart';
import 'msg.dart';
import 'services/dev_mode_service.dart';

class RegisterUserView extends StatefulWidget {
  final BaseMessenger? messenger;
  final void Function(Msg msg)? onMsgReceived;

  final String initialFirstLastName;
  final String initialLogin;
  final String initialDOB;
  final String initialUnion;

  const RegisterUserView({
    super.key,
    this.messenger,
    this.onMsgReceived,
    this.initialFirstLastName = "",
    this.initialLogin = "",
    this.initialDOB = "",
    this.initialUnion = "",
  });

  @override
  _RegisterUserViewState createState() => _RegisterUserViewState();
}

class _RegisterUserViewState extends State<RegisterUserView> {
  final TextEditingController firstLastNameController = TextEditingController();
  final TextEditingController loginController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController unionController = TextEditingController();

  bool isDevModeVisible = false;
  final TextEditingController devIpController = TextEditingController();

  int _devTapCounter = 0;
  Timer? _devTapResetTimer;

  bool isRegisterClicked = false;
  bool showAlert = false;
  bool isLoadingUnions = true;

  String? selectedMonth;
  String? selectedDay;
  String? selectedYear;

  List<String> unions = [];
  String? selectedUnion;

  bool get isFormComplete =>
      firstLastNameController.text.isNotEmpty &&
      loginController.text.isNotEmpty &&
      dateOfBirthController.text.isNotEmpty &&
      unionController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();

    log("🔹 RegisterUserView initState: initialUnion=${widget.initialUnion}");

    firstLastNameController.text = widget.initialFirstLastName;
    loginController.text = widget.initialLogin;
    dateOfBirthController.text = widget.initialDOB;

    selectedUnion = widget.initialUnion.isNotEmpty ? widget.initialUnion : null;
    unionController.text = selectedUnion ?? "";

    unions = [];
    isLoadingUnions = true;

    widget.messenger?.statusSignalStream.listen((msg) async
    {
      handleMsgStatus(msg);
    });

    // Fallback timeout: if unions don't load within 10 seconds, use test unions
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && isLoadingUnions && unions.isEmpty) {
        log("⚠️ Union fetch timeout, using fallback unions in view");
        setState(() {
          unions = ["Mount Sinai", "1199SEIU", "Local 32BJ", "Test Union"];
          selectedUnion = unions.first;
          unionController.text = selectedUnion ?? "";
          isLoadingUnions = false;
        });
      }
    });
  }

  @override
  void dispose() {
    firstLastNameController.dispose();
    loginController.dispose();
    dateOfBirthController.dispose();
    unionController.dispose();
    devIpController.dispose();
    super.dispose();
  }

  void _updateDateOfBirthController() {
    if (selectedMonth != null && selectedDay != null && selectedYear != null) {
      dateOfBirthController.text =
          "${selectedMonth!.padLeft(2, '0')}/${selectedDay!.padLeft(2, '0')}/$selectedYear";
    } else {
      dateOfBirthController.clear();
    }
  }

  void _validateAndProceed() {
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(firstLastNameController.text)) {
      setState(() => showAlert = true);
      return;
    }

    if (isFormComplete) {
      setState(() => isRegisterClicked = true);

      widget.messenger?.sendMsg(Msg(
        deviceModel: DeviceModel.iPhone,
        taskType: TaskType.RegisterUserInfo,
        status: Status.update,
        sender: [ComponentType.View],
        strData: [
          firstLastNameController.text,
          loginController.text,
          dateOfBirthController.text,
          unionController.text,
        ],
      ));
    } else {
      setState(() => showAlert = true);
    }
  }

  // This method receives messages from the parent via the callback
  void handleMsgStatus(Msg msg) {
    log("🔹 handleMsgStatus called in view: $msg");

    if (msg.taskType == TaskType.FetchUnionInfo) 
    {
      final List<String>? receivedUnions = msg.strData?.cast<String>();
      log("🔹 Received unions from msg: $receivedUnions");

      if (receivedUnions != null && receivedUnions.isNotEmpty) {
        setState(() 
        {
          unions = receivedUnions;

          // If nothing is selected yet, pick the first union as default
          if (selectedUnion == null && unions.isNotEmpty) {
            selectedUnion = unions.first;
          }

          unionController.text = selectedUnion ?? "";
          isLoadingUnions = false;

          log("Unions are loaded: $isLoadingUnions");
          log("✅ Unions updated in view: $unions");
        });

      } 
      
      else 
      {
        setState(() 
        {
          isLoadingUnions = false;
        });
        log("❌ No unions received");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register User")),
      body: Stack(
        children: [
          _mainRegisterUI(),
          if (isDevModeVisible) _devModeOverlay(),
        ],
      ),
    );
  }

  Widget _mainRegisterUI() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _handleDevModeTap,
                  child: Image.asset('assets/Logotrans.png', height: 100),
                ),
                const SizedBox(height: 20),
                CustomClearableTextField(
                  placeholder: "Name (First Last)",
                  controller: firstLastNameController,
                ),
                const SizedBox(height: 15),
                CustomClearableTextField(
                  placeholder: "Email",
                  controller: loginController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 25),
                const Text("Birthday"),
                const SizedBox(height: 8),
                _buildBirthdayDropdowns(),
                const SizedBox(height: 15),
                isLoadingUnions
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: selectedUnion,
                        decoration: const InputDecoration(labelText: "Union"),
                        items: unions
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedUnion = v;
                            unionController.text = v ?? "";
                            log("🔹 Union selected: $v");
                          });
                        },
                      ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: _validateAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Next"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayDropdowns() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedMonth,
            decoration: const InputDecoration(labelText: "Month"),
            items: List.generate(
              12,
              (i) => DropdownMenuItem(
                value: (i + 1).toString().padLeft(2, '0'),
                child: Text((i + 1).toString().padLeft(2, '0')),
              ),
            ),
            onChanged: (v) {
              setState(() {
                selectedMonth = v!;
                _updateDateOfBirthController();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedDay,
            decoration: const InputDecoration(labelText: "Day"),
            items: List.generate(
              31,
              (i) => DropdownMenuItem(
                value: (i + 1).toString().padLeft(2, '0'),
                child: Text((i + 1).toString().padLeft(2, '0')),
              ),
            ),
            onChanged: (v) {
              setState(() {
                selectedDay = v!;
                _updateDateOfBirthController();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedYear,
            decoration: const InputDecoration(labelText: "Year"),
            items: List.generate(
              100,
              (i) => DropdownMenuItem(
                value: (DateTime.now().year - i).toString(),
                child: Text((DateTime.now().year - i).toString()),
              ),
            ),
            onChanged: (v) {
              setState(() {
                selectedYear = v!;
                _updateDateOfBirthController();
              });
            },
          ),
        ),
      ],
    );
  }

  void _handleDevModeTap() {
    _devTapCounter++;
    log("button tapped ($_devTapCounter/5)");
    _devTapResetTimer?.cancel();

    if (_devTapCounter >= 5 &&
        loginController.text.trim().toLowerCase() == "tester@gmail.com") {
      log("DEV MODE ACTIVATED");
      _devTapCounter = 0;
      _devTapResetTimer?.cancel();
      DevModeService.instance.isDevMode = true;
      setState(() => isDevModeVisible = true);
      return;
    }

    _devTapResetTimer = Timer(const Duration(seconds: 2), () {
      log("⏱ Dev tap counter reset");
      _devTapCounter = 0;
    });
  }

  Widget _devModeOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "DEV MODE ACTIVATED",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: devIpController,
                decoration: const InputDecoration(
                  labelText: "Enter Server IP Address",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                height: 120,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "/// MSG DEBUG OUTPUT WILL APPEAR HERE\n"
                  "/// Incoming messages\n"
                  "/// Outgoing messages\n"
                  "/// Connection status\n",
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final ip = devIpController.text.trim();
                  if (ip.isNotEmpty) {
                    await Environment.setDevIp(ip);
                    log("✅ DEV IP SAVED: $ip");
                    log("✅ API BASE NOW: ${Environment.baseUrl}");
                  }
                  setState(() => isDevModeVisible = false);
                },
                child: const Text("Done"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomClearableTextField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const CustomClearableTextField({
    super.key,
    required this.placeholder,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: placeholder,
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => controller.clear(),
        ),
      ),
    );
  }
}
