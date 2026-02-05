import 'package:flutter/material.dart';
import 'dart:async';

import 'msg.dart';

// LogView widget
class LogView extends StatefulWidget {
  final BaseMessenger messenger;

  const LogView({super.key, required this.messenger});

  @override
  _LogViewState createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  String currentLog = '';
  List<String> currentLogs = [];
  bool isExpanded = false;
  bool isLogEnabled = false;

  late StreamSubscription loggingSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to the logging signal from BaseMessenger
    loggingSubscription = widget.messenger.statusSignal.stream.listen((msg) {
      handleLogMsg(msg);
    });
  }

  @override
  void dispose() {
    loggingSubscription.cancel();
    super.dispose();
  }

  // Handle log messages and update the logs list
  void handleLogMsg(dynamic data) {
    final msg = data[2] as Msg;
    print("LogView: handleLogMsg: ${data[0]}: ${data[1]}: ${msg.msgId}");
    final sender = msg.sender.last;
    final newLog = "[${msg.msgId}] [$sender] ${msg.taskType} ${msg.status}";
    setState(() {
      currentLogs.add(newLog);
      // Limit to the last 50 log entries
      if (currentLogs.length > 50) {
        currentLogs.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Viewer"),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
                ),
                const Text(
                  "Log",
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
                const Spacer(),
                // Enable and toggle on the right
                Row(
                  children: [
                    const Text(
                      "Enable",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Switch(
                      value: isLogEnabled,
                      onChanged: (isEnabled) {
                        setState(() {
                          isLogEnabled = isEnabled;
                        });

                        if (isEnabled) 
                        {
                          widget.messenger.sendMsg(
                             Msg(
                              sender: [ComponentType.View],
                              taskType: TaskType.Logger,
                              status: Status.request,
                            ),
                          );
                        } 
                        else 
                        {
                          widget.messenger.sendMsg(
                           Msg(
                              sender: [ComponentType.View],
                              taskType: TaskType.Logger,
                              status: Status.finished,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isExpanded)
            Container(
              height: 250,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ListView.builder(
                itemCount: currentLogs.length,
                itemBuilder: (context, index) {
                  return Container(
                    color: index % 2 == 0 ? Colors.transparent : Colors.green.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                    child: Text(
                      currentLogs[index],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

extension on Stream<Msg> {
  get stream => null;
}

