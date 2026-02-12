import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';
import 'widgets/primary_button.dart';
import 'services/local_notification_service.dart';

class Reminder {
  final String id;
  TimeOfDay time;
  List<int> daysOfWeek; // 0 = Sunday, 1 = Monday, etc.
  bool isEnabled;
  String? label;

  Reminder({
    required this.id,
    required this.time,
    required this.daysOfWeek,
    this.isEnabled = true,
    this.label,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': time.hour,
        'minute': time.minute,
        'daysOfWeek': daysOfWeek,
        'isEnabled': isEnabled,
        'label': label,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'],
        time: TimeOfDay(hour: json['hour'], minute: json['minute']),
        daysOfWeek: List<int>.from(json['daysOfWeek']),
        isEnabled: json['isEnabled'] ?? true,
        label: json['label'],
      );

  String get timeString {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String get daysString {
    if (daysOfWeek.length == 7) return 'Every day';
    if (daysOfWeek.length == 5 &&
        !daysOfWeek.contains(0) &&
        !daysOfWeek.contains(6)) {
      return 'Weekdays';
    }
    if (daysOfWeek.length == 2 &&
        daysOfWeek.contains(0) &&
        daysOfWeek.contains(6)) {
      return 'Weekends';
    }

    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return daysOfWeek.map((d) => dayNames[d]).join(', ');
  }
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('reminders');

    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        _reminders = decoded.map((r) => Reminder.fromJson(r)).toList();
      } catch (e) {
        _reminders = [];
      }
    }

    // If no reminders exist, add smart suggestions
    if (_reminders.isEmpty) {
      _reminders = [
        Reminder(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          time: const TimeOfDay(hour: 7, minute: 0),
          daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
          label: 'Morning reading',
        ),
        Reminder(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          time: const TimeOfDay(hour: 20, minute: 0),
          daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
          label: 'Evening reading',
        ),
      ];
      await _saveReminders();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reminders',
      jsonEncode(_reminders.map((r) => r.toJson()).toList()),
    );
    // Schedule local notifications
    await _syncNotifications();
  }

  Future<void> _syncNotifications() async {
    final notifService = LocalNotificationService.instance;
    if (!notifService.isInitialized) return;

    // Cancel all existing notifications and re-schedule
    await notifService.cancelAll();

    for (var i = 0; i < _reminders.length; i++) {
      final reminder = _reminders[i];
      if (!reminder.isEnabled) continue;

      await notifService.scheduleDaily(
        id: i + 1,
        hour: reminder.time.hour,
        minute: reminder.time.minute,
        title: 'BP Reading Reminder',
        body: reminder.label ?? 'Time to take your blood pressure reading',
        daysOfWeek: reminder.daysOfWeek,
      );
    }
  }

  void _addReminder() {
    _showReminderDialog(null);
  }

  void _editReminder(Reminder reminder) {
    _showReminderDialog(reminder);
  }

  void _deleteReminder(Reminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _reminders.removeWhere((r) => r.id == reminder.id);
              });
              _saveReminders();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleReminder(Reminder reminder) async {
    if (!reminder.isEnabled) {
      // Enabling a reminder — request permission first
      final granted = await LocalNotificationService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable notifications in your device settings to receive reminders.'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
        return;
      }
    }
    setState(() {
      reminder.isEnabled = !reminder.isEnabled;
    });
    _saveReminders();
  }

  void _showReminderDialog(Reminder? existingReminder) {
    TimeOfDay selectedTime = existingReminder?.time ?? const TimeOfDay(hour: 8, minute: 0);
    List<int> selectedDays = existingReminder?.daysOfWeek.toList() ?? [0, 1, 2, 3, 4, 5, 6];
    final labelController = TextEditingController(text: existingReminder?.label);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Text(
            existingReminder == null ? 'Add Reminder' : 'Edit Reminder',
            style: AppTheme.headlineMedium,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time picker
                Text('Time', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.spacingSm),
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = time;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.lightGray),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Reminder(
                            id: '',
                            time: selectedTime,
                            daysOfWeek: [],
                          ).timeString,
                          style: AppTheme.headlineMedium,
                        ),
                        const Icon(Icons.access_time, color: AppTheme.navyBlue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Days of week selector
                Text('Repeat on', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.spacingSm),
                Wrap(
                  spacing: AppTheme.spacingXs,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .asMap()
                      .entries
                      .map((entry) {
                    final isSelected = selectedDays.contains(entry.key);
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          if (isSelected) {
                            selectedDays.remove(entry.key);
                          } else {
                            selectedDays.add(entry.key);
                            selectedDays.sort();
                          }
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.navyBlue : AppTheme.lightGray,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: isSelected ? AppTheme.white : AppTheme.darkGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Quick select buttons
                Row(
                  children: [
                    _buildQuickSelectButton(
                      'Every day',
                      () {
                        setDialogState(() {
                          selectedDays = [0, 1, 2, 3, 4, 5, 6];
                        });
                      },
                      selectedDays.length == 7,
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    _buildQuickSelectButton(
                      'Weekdays',
                      () {
                        setDialogState(() {
                          selectedDays = [1, 2, 3, 4, 5];
                        });
                      },
                      selectedDays.length == 5 &&
                          !selectedDays.contains(0) &&
                          !selectedDays.contains(6),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Label
                Text('Label (optional)', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Morning reading',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDays.isEmpty
                  ? null
                  : () {
                      if (existingReminder != null) {
                        setState(() {
                          existingReminder.time = selectedTime;
                          existingReminder.daysOfWeek = selectedDays;
                          existingReminder.label = labelController.text.isEmpty
                              ? null
                              : labelController.text;
                        });
                      } else {
                        setState(() {
                          _reminders.add(Reminder(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            time: selectedTime,
                            daysOfWeek: selectedDays,
                            label: labelController.text.isEmpty
                                ? null
                                : labelController.text,
                          ));
                        });
                      }
                      _saveReminders();
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSelectButton(String label, VoidCallback onTap, bool isSelected) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navyBlue.withOpacity(0.1) : AppTheme.lightGray,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: isSelected
              ? Border.all(color: AppTheme.navyBlue)
              : null,
        ),
        child: Text(
          label,
          style: AppTheme.labelMedium.copyWith(
            color: isSelected ? AppTheme.navyBlue : AppTheme.darkGray,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: 'Reminders',
            subtitle: 'Measurement Schedule',
            showBackButton: true,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reminders.isEmpty
                    ? _buildEmptyState()
                    : _buildRemindersList(),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: PrimaryButton(
                label: 'Add Reminder',
                icon: Icons.add,
                onPressed: _addReminder,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No reminders set',
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Add reminders to help you remember to take your blood pressure readings.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Suggestion card
          AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.info,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    'For best results, measure at the same times each day.',
                    style: AppTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Your Reminders',
            style: AppTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          ..._reminders.map((reminder) => _buildReminderCard(reminder)),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _editReminder(reminder),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.timeString,
                      style: AppTheme.headlineMedium.copyWith(
                        color: reminder.isEnabled
                            ? AppTheme.navyBlue
                            : AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      reminder.daysString,
                      style: AppTheme.bodyMedium.copyWith(
                        color: reminder.isEnabled
                            ? AppTheme.darkGray
                            : AppTheme.mediumGray,
                      ),
                    ),
                    if (reminder.label != null) ...[
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        reminder.label!,
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.mediumGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Switch(
                  value: reminder.isEnabled,
                  onChanged: (_) => _toggleReminder(reminder),
                  activeColor: AppTheme.accentGreen,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: () => _deleteReminder(reminder),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
