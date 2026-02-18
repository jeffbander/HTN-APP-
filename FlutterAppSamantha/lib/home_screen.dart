import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';
import 'widgets/primary_button.dart';
import 'msg.dart';
import 'historyView.dart';
import 'helpView.dart';
import 'reminders_screen.dart';

class HomeScreen extends StatefulWidget {
  final BaseMessenger? messenger;

  const HomeScreen({super.key, this.messenger});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  List<Map<DateTime, List<int>>> _measurements = [];
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMeasurements();
    _listenForMessages();
  }

  void _listenForMessages() {
    widget.messenger?.statusSignalStream.listen((msg) {
      if (msg.taskType == TaskType.Measure && msg.status == Status.failed) {
        // Show error dialog
        final errorMsg = msg.strData.isNotEmpty
            ? msg.strData[0]
            : 'Unable to start measurement. Please pair your device first.';
        _showNoPairedDeviceDialog(errorMsg);
      }
    });
  }

  void _showNoPairedDeviceDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: AppTheme.warning),
            const SizedBox(width: 8),
            const Text('No Device Paired'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              'Would you like to pair a device or add a reading manually?',
              style: TextStyle(color: AppTheme.mediumGray),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HistoryView(messenger: widget.messenger!),
                ),
              );
            },
            child: const Text('Add Manually'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/device-selection');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyBlue,
            ),
            child: const Text('Pair Device'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('firstName') ?? '';
    if (mounted) {
      setState(() {
        _userName = firstName.isNotEmpty ? firstName : 'there';
      });
    }
  }

  Future<void> _loadMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('measurements') ?? [];

    final List<Map<DateTime, List<int>>> loaded = [];
    for (final jsonStr in stored) {
      try {
        final map = jsonDecode(jsonStr);
        final date = DateTime.parse(map['date']);
        final values = List<int>.from(map['values']);
        loaded.add({date: values});
      } catch (e) {
        // Skip invalid entries
      }
    }

    // Sort by date descending (most recent first)
    loaded.sort((a, b) => b.keys.first.compareTo(a.keys.first));

    if (mounted) {
      setState(() {
        _measurements = loaded;
      });
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Map<String, dynamic> get _stats {
    if (_measurements.isEmpty) {
      return {
        'avgSystolic': 0,
        'avgDiastolic': 0,
        'avgHr': 0,
        'highSystolic': 0,
        'lowSystolic': 0,
        'lastReading': null,
        'totalReadings': 0,
      };
    }

    // Get readings from last 7 days
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentMeasurements = _measurements.where((m) {
      return m.keys.first.isAfter(sevenDaysAgo);
    }).toList();

    if (recentMeasurements.isEmpty) {
      final last = _measurements.first;
      return {
        'avgSystolic': last.values.first[0],
        'avgDiastolic': last.values.first[1],
        'avgHr': last.values.first.length > 2 ? last.values.first[2] : 0,
        'highSystolic': last.values.first[0],
        'lowSystolic': last.values.first[0],
        'lastReading': last.keys.first,
        'totalReadings': _measurements.length,
      };
    }

    int totalSystolic = 0;
    int totalDiastolic = 0;
    int totalHr = 0;
    int highSystolic = 0;
    int lowSystolic = 999;

    for (final m in recentMeasurements) {
      final values = m.values.first;
      totalSystolic += values[0];
      totalDiastolic += values[1];
      if (values.length > 2) totalHr += values[2];
      if (values[0] > highSystolic) highSystolic = values[0];
      if (values[0] < lowSystolic) lowSystolic = values[0];
    }

    final count = recentMeasurements.length;
    return {
      'avgSystolic': (totalSystolic / count).round(),
      'avgDiastolic': (totalDiastolic / count).round(),
      'avgHr': (totalHr / count).round(),
      'highSystolic': highSystolic,
      'lowSystolic': lowSystolic,
      'lastReading': _measurements.first.keys.first,
      'totalReadings': _measurements.length,
    };
  }

  void _startMeasurement() {
    dev.log('START button pressed in HomeScreen');
    dev.log('Messenger is: ${widget.messenger}');

    // Show snackbar for immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting measurement...'),
        duration: Duration(seconds: 2),
      ),
    );

    if (widget.messenger == null) {
      dev.log('Messenger is NULL - cannot send message');
      _showNoPairedDeviceDialog('Messenger not available. Please restart the app.');
      return;
    }

    final msg = Msg(
      taskType: TaskType.Measure,
      status: Status.request,
      sender: [ComponentType.View],
    );
    dev.log('Sending Measure request message...');
    widget.messenger?.sendMsg(msg);
    dev.log('Message sent!');
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedNavIndex = index;
    });

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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const RemindersScreen(),
          ),
        );
        break;
      case 4: // Help
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const HelpView(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: '$_greeting, $_userName!',
            subtitle: 'Blood Pressure Monitor',
            showBackButton: false,
            trailing: IconButton(
              icon: const Icon(Icons.person, color: AppTheme.white),
              onPressed: () {
                Navigator.of(context).pushNamed('/profile');
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  // Stats Card
                  if (_measurements.isNotEmpty)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '7-Day Summary',
                                style: AppTheme.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${stats['totalReadings']} readings',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.mediumGray,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Average',
                                  '${stats['avgSystolic']}/${stats['avgDiastolic']}',
                                  'mmHg',
                                  AppTheme.navyBlue,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: AppTheme.lightGray,
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'High',
                                  '${stats['highSystolic']}',
                                  'sys',
                                  AppTheme.error,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: AppTheme.lightGray,
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Low',
                                  '${stats['lowSystolic']}',
                                  'sys',
                                  AppTheme.accentGreen,
                                ),
                              ),
                            ],
                          ),
                          if (stats['lastReading'] != null) ...[
                            const Divider(height: AppTheme.spacingLg),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: AppTheme.mediumGray),
                                const SizedBox(width: AppTheme.spacingXs),
                                Text(
                                  'Last reading: ${_formatDateTime(stats['lastReading'])}',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_measurements.isEmpty) ...[
                    AppCard(
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 48,
                            color: AppTheme.mediumGray,
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            'No readings yet',
                            style: AppTheme.titleMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text(
                            'Take your first blood pressure reading to see your stats here.',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.mediumGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingXl),
                  // START Button
                  GestureDetector(
                    onTap: _startMeasurement,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.greenGradient,
                        boxShadow: AppTheme.greenGlow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'START',
                            style: AppTheme.buttonTextLarge.copyWith(
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXs),
                          Text(
                            'Take Reading',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    'Tap to start your blood pressure measurement',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.mediumGray,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAction(
                          Icons.history,
                          'History',
                          () => _onNavTap(1),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: _buildQuickAction(
                          Icons.help_outline,
                          'Help',
                          () => _onNavTap(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedNavIndex,
        selectedItemColor: AppTheme.navyBlue,
        unselectedItemColor: AppTheme.mediumGray,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Device',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Help',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.labelMedium.copyWith(
            color: AppTheme.mediumGray,
          ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          value,
          style: AppTheme.headlineMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          unit,
          style: AppTheme.labelMedium.copyWith(
            color: AppTheme.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Column(
          children: [
            Icon(icon, color: AppTheme.navyBlue, size: 32),
            const SizedBox(height: AppTheme.spacingSm),
            Text(label, style: AppTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }
}
