// ignore: file_names

import 'package:flutter/material.dart';
import 'commonWidgets.dart';
import 'package:intl/intl.dart';
import 'msg.dart';
import 'dart:developer'; // For logging
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';
import 'widgets/primary_button.dart';
import 'historyView.dart';

//------------------------------------------------------
// class StartMeasurementView
// View to start the measurement with guided Bluetooth-first flow
//------------------------------------------------------

class StartMeasurementView extends StatefulWidget {
  final BaseMessenger? messenger;
  final List<Map<DateTime, List<int>>> recentMeasurements;

  const StartMeasurementView({
    super.key,
    this.messenger,
    required this.recentMeasurements,
  });

  @override
  _StartMeasurementViewState createState() => _StartMeasurementViewState();
}

//------------------------------------------------------
// class _StartMeasurementViewState
//------------------------------------------------------
class _StartMeasurementViewState extends State<StartMeasurementView> {
  @override
  void initState() {
    super.initState();
    _listenForMessages();
  }

  void _listenForMessages() {
    widget.messenger?.statusSignalStream.listen((msg) {
      if (msg.taskType == TaskType.Measure && msg.status == Status.failed) {
        final errorMsg = msg.strData.isNotEmpty
            ? msg.strData[0]
            : 'Unable to start measurement. Please pair your device first.';
        _showErrorDialog(errorMsg);
      }
    });
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    // Distinguish between "connection failed" (cuff off) vs "no device paired"
    final bool isConnectionFailure = message.toLowerCase().contains('connect') ||
        message.toLowerCase().contains('turn on');
    final String title = isConnectionFailure ? 'Cuff Not Found' : 'No Device Paired';
    final IconData icon = isConnectionFailure ? Icons.bluetooth_searching : Icons.bluetooth_disabled;
    final String subtitle = isConnectionFailure
        ? 'Turn on your cuff and try again.'
        : 'Would you like to pair a device?';
    final String actionLabel = isConnectionFailure ? 'Try Again' : 'Pair Device';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(icon, color: AppTheme.warning),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: TextStyle(color: AppTheme.mediumGray),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (isConnectionFailure) {
                // Retry measurement — send Measure.request again
                _startMeasurement();
              } else {
                // Navigate to pairing flow
                Navigator.of(context).pushNamed('/device-selection');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyBlue,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _startMeasurement() {
    print('🟢 START button pressed in StartMeasurementView!');
    print('🟢 Messenger is: ${widget.messenger}');

    // Send measure request to device - this will trigger navigation to IdleMeasureView
    final msg = Msg(
      taskType: TaskType.Measure,
      status: Status.request,
      sender: [ComponentType.View],
    );

    if (widget.messenger == null) {
      print('⚠️ Messenger is NULL in StartMeasurementView!');
    } else {
      print('🟢 Sending Measure request from StartMeasurementView...');
    }
    widget.messenger?.sendMsg(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: 'Blood Pressure',
            subtitle: 'Take a measurement',
            trailing: IconButton(
              icon: const Icon(Icons.person, color: AppTheme.white),
              onPressed: () {
                Navigator.of(context).pushNamed('/profile');
              },
            ),
          ),
          Expanded(
            child: _buildReadyState(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
              currentIndex: 0,
              selectedItemColor: AppTheme.navyBlue,
              unselectedItemColor: AppTheme.mediumGray,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                switch (index) {
                  case 0: // Home - already here
                    break;
                  case 1: // History
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => HistoryView(messenger: widget.messenger!),
                      ),
                    );
                    break;
                  case 2: // Device
                    Navigator.of(context).pushNamed('/device-info');
                    break;
                  case 3: // Reminders
                    Navigator.of(context).pushNamed('/reminders');
                    break;
                  case 4: // Help
                    Navigator.of(context).pushNamed('/help');
                    break;
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: 'Device'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Reminders'),
                BottomNavigationBarItem(icon: Icon(Icons.help), label: 'Help'),
              ],
            ),
    );
  }

  Widget _buildReadyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingLg),
          // Instruction text
          Text(
            'Ready to take your blood pressure?',
            textAlign: TextAlign.center,
            style: AppTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.spacingXl),
          // Start Button
          StartButton(
            label: 'START',
            subtitle: 'Send to Mt Sinai',
            onPressed: _startMeasurement,
            isActive: true,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          // Quick tips card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppTheme.warning, size: 20),
                    const SizedBox(width: AppTheme.spacingSm),
                    Text(
                      'Quick Tips',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                _buildTipRow('Avoid caffeine for 30 minutes before'),
                _buildTipRow('Don\'t measure right after exercise'),
                _buildTipRow('Empty your bladder before measuring'),
                _buildTipRow('Take readings at the same time daily'),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Manual entry link
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HistoryView(messenger: widget.messenger!),
                ),
              );
            },
            child: Text(
              'Having trouble? Add reading manually from History',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.navyBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          // Recent Measurements Section
          if (widget.recentMeasurements.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Recent Measurements',
                  style: AppTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ...widget.recentMeasurements.take(3).map((measurement) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: _buildMeasurementCard(measurement),
              );
            }),
            if (widget.recentMeasurements.length > 3)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => HistoryView(messenger: widget.messenger!),
                    ),
                  );
                },
                child: Text(
                  'View all ${widget.recentMeasurements.length} readings →',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.navyBlue,
                  ),
                ),
              ),
          ] else ...[
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 48,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      'No recent measurements',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'Press START to take your first reading',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: AppTheme.accentGreen),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(text, style: AppTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(Map<DateTime, List<int>> measurement) {
    final dateTime = measurement.keys.first;
    final values = measurement.values.first;
    final hasValidValues = values.length >= 2;
    final systolic = hasValidValues ? values[0] : 0;
    final diastolic = hasValidValues ? values[1] : 0;
    final heartRate = values.length >= 3 ? values[2] : 0;

    // Determine BP category color
    Color bpColor = AppTheme.accentGreen;
    String bpCategory = 'Normal';
    if (systolic >= 180 || diastolic >= 120) {
      bpColor = AppTheme.error;
      bpCategory = 'Crisis';
    } else if (systolic >= 140 || diastolic >= 90) {
      bpColor = AppTheme.error;
      bpCategory = 'High';
    } else if (systolic >= 130 || diastolic >= 80) {
      bpColor = AppTheme.warning;
      bpCategory = 'Elevated';
    }

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: bpColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateTime(dateTime),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Row(
                  children: [
                    Text(
                      '$systolic/$diastolic',
                      style: AppTheme.headlineMedium.copyWith(
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXs),
                    Text(
                      'mmHg',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: bpColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  bpCategory,
                  style: AppTheme.labelMedium.copyWith(
                    color: bpColor,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$heartRate bpm',
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//------------------------------------------------------
// Helper Functions for Measurement Rows
//------------------------------------------------------
Widget createMeasurementRow(
    Map<DateTime, List<int>> measurement, BuildContext context) {
  final dateTime = measurement.keys.first;
  final values = measurement.values.first;

  final hasValidValues = values.length >= 2;
  final systolic = hasValidValues ? values[0] : "--";
  final diastolic = hasValidValues ? values[1] : "--";
  final heartRate = values.length >= 3 ? values[2] : "--";

  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Row(
      children: [
        const Icon(Icons.favorite, color: Colors.red, size: 12),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Blood Pressure", style: TextStyle(fontSize: 16)),
              Text(formatDateTime(dateTime),
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("$systolic/$diastolic", style: const TextStyle(fontSize: 16)),
            Text("$heartRate", style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    ),
  );
}

List<Widget> buildMeasurementList(
    List<Map<DateTime, List<int>>> measurements, BuildContext context) {
  final Set<DateTime> uniqueDates = {};
  final List<Widget> rows = [];

  for (var measurement in measurements) {
    final dateTime = measurement.keys.first;
    if (uniqueDates.contains(dateTime)) continue;
    uniqueDates.add(dateTime);
    rows.add(createMeasurementRow(measurement, context));
  }

  return rows;
}

//------------------------------------------------------
String formatDateTime(DateTime date) {
  final formatter = DateFormat("MM/dd/yyyy h:mm a");
  return formatter.format(date);
}

//------------------------------------------------------
// class MeasurementView
// Results view after measurement is complete
//------------------------------------------------------

class MeasurementView extends StatefulWidget {
  final BaseMessenger? messenger;
  final Map<DateTime, List<int>>? lastMeasurement;
  final bool isFirstReading;

  const MeasurementView({
    super.key,
    this.messenger,
    this.lastMeasurement,
    this.isFirstReading = false,
  });

  @override
  _MeasurementViewState createState() => _MeasurementViewState();
}

class _MeasurementViewState extends State<MeasurementView> {
  int systolic = 0;
  int diastolic = 0;
  int heartRate = 0;
  DateTime curTimestamp = DateTime.now();
  bool showSyncStatus = true;
  bool syncComplete = false;

  String formattedMessage =
      "Sending measurement back to Mt. Sinai.\nThis may take a moment...";

  @override
  void initState() {
    super.initState();

    Map<DateTime, List<int>>? l = widget.lastMeasurement;
    log("Latest Measurement: $l");
    if (l != null && l.isNotEmpty) {
      curTimestamp = l.keys.first;
      List<int>? values = l[curTimestamp];
      if (values != null && values.length >= 3) {
        systolic = values[0];
        diastolic = values[1];
        heartRate = values[2];
      }
    }

    widget.messenger?.statusSignalStream.listen((msg) async {
      handleMsgStatus(msg);
    });

    // Simulate sync completion after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          syncComplete = true;
        });
      }
    });
  }

  // Determine BP category
  String get bpCategory {
    if (systolic >= 180 || diastolic >= 120) return 'Crisis';
    if (systolic >= 140 || diastolic >= 90) return 'High';
    if (systolic >= 130 || diastolic >= 80) return 'Elevated';
    return 'Normal';
  }

  Color get bpColor {
    if (systolic >= 180 || diastolic >= 120) return AppTheme.error;
    if (systolic >= 140 || diastolic >= 90) return AppTheme.error;
    if (systolic >= 130 || diastolic >= 80) return AppTheme.warning;
    return AppTheme.accentGreen;
  }

  String get bpAdvice {
    if (systolic >= 180 || diastolic >= 120) {
      return 'Your blood pressure is very high. Please contact your healthcare provider immediately.';
    }
    if (systolic >= 140 || diastolic >= 90) {
      return 'Your blood pressure is elevated. Consider lifestyle changes and consult with your healthcare provider.';
    }
    if (systolic >= 130 || diastolic >= 80) {
      return 'Your blood pressure is slightly elevated. Monitor regularly and maintain healthy habits.';
    }
    return 'Great job! Your blood pressure is in the normal range. Keep up the healthy lifestyle!';
  }

  void _handleDone() {
    // Check if this is first reading and should prompt for lifestyle questionnaire
    if (widget.isFirstReading) {
      _showLifestylePrompt();
    } else {
      _finishMeasurement();
    }
  }

  void _showLifestylePrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.assignment, color: AppTheme.navyBlue),
            const SizedBox(width: AppTheme.spacingSm),
            const Text('One More Step'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Great job on your first reading!',
              style: AppTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'To help us provide personalized health insights, please complete a brief lifestyle questionnaire.',
              style: AppTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _finishMeasurement();
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to lifestyle questionnaire
              Navigator.of(context).pushReplacementNamed('/lifestyle');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: const Text('Complete Now'),
          ),
        ],
      ),
    );
  }

  void _finishMeasurement() {
    final msg = Msg(
      taskType: TaskType.Measure,
      status: Status.finished,
      sender: [ComponentType.View],
    );
    widget.messenger?.sendMsg(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Results',
            subtitle: 'Measurement Complete',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  const SizedBox(height: AppTheme.spacingMd),
                  // Timestamp
                  Text(
                    DateFormat("MMMM d, yyyy 'at' h:mm a").format(curTimestamp),
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.mediumGray,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  // Main BP Card
                  AppCard(
                    child: Column(
                      children: [
                        // BP Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMd,
                            vertical: AppTheme.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: bpColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: bpColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingSm),
                              Text(
                                bpCategory.toUpperCase(),
                                style: AppTheme.labelLarge.copyWith(
                                  color: bpColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        // Main BP Reading
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$systolic',
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w300,
                                color: AppTheme.navyBlue,
                                height: 1,
                              ),
                            ),
                            Text(
                              '/',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w300,
                                color: AppTheme.mediumGray,
                                height: 1,
                              ),
                            ),
                            Text(
                              '$diastolic',
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w300,
                                color: AppTheme.navyBlue,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'mmHg',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.mediumGray,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingLg),
                        const Divider(),
                        const SizedBox(height: AppTheme.spacingMd),
                        // Heart Rate
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite,
                              color: AppTheme.error,
                              size: 28,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Text(
                              '$heartRate',
                              style: AppTheme.headlineLarge.copyWith(
                                color: AppTheme.navyBlue,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXs),
                            Text(
                              'bpm',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  // Sync Status Card
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingSm),
                          decoration: BoxDecoration(
                            color: syncComplete
                                ? AppTheme.accentGreen.withOpacity(0.1)
                                : AppTheme.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: syncComplete
                              ? Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 24)
                              : SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.info),
                                  ),
                                ),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                syncComplete
                                    ? 'Received by Mt Sinai'
                                    : 'Syncing with Mt. Sinai',
                                style: AppTheme.titleMedium,
                              ),
                              Text(
                                syncComplete
                                    ? 'team for monitoring'
                                    : 'This may take a moment...',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  // Advice Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              bpCategory == 'Normal'
                                  ? Icons.thumb_up
                                  : Icons.info_outline,
                              color: bpColor,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Text(
                              'What This Means',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          bpAdvice,
                          style: AppTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: PrimaryButton(
                label: 'Done',
                variant: syncComplete ? ButtonVariant.green : ButtonVariant.navy,
                onPressed: _handleDone,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void handleMsgStatus(Msg msg) {
    if (msg.sender.last != ComponentType.NavigationManager) {
      return;
    }

    switch (msg.taskType) {
      case TaskType.Measure:
        if (msg.status == Status.finished &&
            msg.sender.last == ComponentType.NavigationManager) {
          systolic = msg.intData[0];
          diastolic = msg.intData[1];
          heartRate = msg.intData[2];
        }
        break;

      default:
        break;
    }
  }
}
