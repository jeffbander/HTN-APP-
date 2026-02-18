import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'flaskRegUsr.dart';
import 'msg.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';
import 'widgets/primary_button.dart';

enum HistoryViewMode { graph, table }

class HistoryView extends StatefulWidget {
  final BaseMessenger messenger;

  const HistoryView({super.key, required this.messenger});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  HistoryViewMode _viewMode = HistoryViewMode.graph;
  List<Map<DateTime, List<int>>> _measurements = [];
  bool _isLoading = true;
  int _selectedDays = 7; // Date range selector: 7, 30, or all

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getStringList('measurements') ?? [];

    // If local cache is empty, fetch from backend for the current user
    if (stored.isEmpty) {
      stored = await _fetchFromBackend(prefs) ?? [];
    }

    final List<Map<DateTime, List<int>>> loaded = [];

    for (final jsonStr in stored) {
      try {
        final map = jsonDecode(jsonStr);
        final date = DateTime.parse(map['date']);
        final values = List<int>.from(map['values']);
        loaded.add({date: values});
      } catch (e) {
        dev.log('Error parsing measurement: $e');
      }
    }

    // Sort by date descending (most recent first)
    loaded.sort((a, b) => b.keys.first.compareTo(a.keys.first));

    if (mounted) {
      setState(() {
        _measurements = loaded;
        _isLoading = false;
      });
    }
  }

  /// Fetch readings from the backend API and cache them locally.
  Future<List<String>?> _fetchFromBackend(SharedPreferences prefs) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token == null) return null;

      final api = FlaskRegUsr();
      final readings = await api.getReadings(token);
      if (readings == null || readings.isEmpty) return null;

      // Convert backend format to local cache format
      final localEntries = <String>[];
      for (final r in readings) {
        final entry = jsonEncode({
          'date': r['reading_date'],
          'values': [
            r['systolic'],
            r['diastolic'],
            r['heart_rate'] ?? 0,
          ],
        });
        localEntries.add(entry);
      }

      // Persist to local cache
      await prefs.setStringList('measurements', localEntries);
      dev.log('Fetched ${localEntries.length} readings from backend into local cache');
      return localEntries;
    } catch (e, stack) {
      dev.log('Error fetching readings from backend: $e\n$stack');
      return null;
    }
  }

  List<Map<DateTime, List<int>>> get _filteredMeasurements {
    if (_selectedDays == 0) return _measurements; // All readings

    final cutoff = DateTime.now().subtract(Duration(days: _selectedDays));
    return _measurements.where((m) => m.keys.first.isAfter(cutoff)).toList();
  }

  void _showAddManualReadingDialog() {
    final systolicController = TextEditingController();
    final diastolicController = TextEditingController();
    final hrController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Text('Add Manual Reading', style: AppTheme.headlineMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use this for readings taken on another device or if Bluetooth sync failed.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Date/Time selector
                Text('Date & Time', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.spacingSm),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
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
                          DateFormat('MMM d, yyyy h:mm a').format(selectedDate),
                          style: AppTheme.bodyLarge,
                        ),
                        const Icon(Icons.calendar_today, color: AppTheme.navyBlue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Systolic
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Systolic (top)', style: AppTheme.labelLarge),
                          const SizedBox(height: AppTheme.spacingSm),
                          TextField(
                            controller: systolicController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'e.g., 120',
                              suffixText: 'mmHg',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Diastolic (bottom)', style: AppTheme.labelLarge),
                          const SizedBox(height: AppTheme.spacingSm),
                          TextField(
                            controller: diastolicController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'e.g., 80',
                              suffixText: 'mmHg',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Heart rate
                Text('Heart Rate (optional)', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: hrController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g., 72',
                    suffixText: 'bpm',
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
              onPressed: () async {
                final systolic = int.tryParse(systolicController.text);
                final diastolic = int.tryParse(diastolicController.text);
                final hr = int.tryParse(hrController.text) ?? 0;

                if (systolic == null || diastolic == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid blood pressure values'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                  return;
                }

                if (systolic < 60 || systolic > 250 || diastolic < 40 || diastolic > 150) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Blood pressure values seem unusual. Please verify.'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );
                  return;
                }

                // Save the manual reading
                final prefs = await SharedPreferences.getInstance();
                final stored = prefs.getStringList('measurements') ?? [];

                final newReading = jsonEncode({
                  'date': selectedDate.toIso8601String(),
                  'values': [systolic, diastolic, hr],
                  'manual': true,
                });

                stored.add(newReading);
                await prefs.setStringList('measurements', stored);

                Navigator.pop(context);
                _loadMeasurements();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reading added successfully'),
                    backgroundColor: AppTheme.accentGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
              child: const Text('Save'),
            ),
          ],
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
            title: 'History',
            subtitle: '${_filteredMeasurements.length} readings',
            showBackButton: true,
          ),
          // View toggle and date range
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              children: [
                // View toggle
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.lightGray,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        _buildToggleButton('Graph', HistoryViewMode.graph),
                        _buildToggleButton('Table', HistoryViewMode.table),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                // Date range selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.lightGray),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedDays,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 days')),
                      DropdownMenuItem(value: 30, child: Text('30 days')),
                      DropdownMenuItem(value: 0, child: Text('All')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDays = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMeasurements.isEmpty
                    ? _buildEmptyState()
                    : _viewMode == HistoryViewMode.graph
                        ? _buildGraphView()
                        : _buildTableView(),
          ),
          // Add Manual Reading button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: PrimaryButton(
                label: 'Add Manual Reading',
                icon: Icons.add,
                variant: ButtonVariant.outline,
                onPressed: _showAddManualReadingDialog,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: AppTheme.navyBlue,
        unselectedItemColor: AppTheme.mediumGray,
        onTap: (index) {
          switch (index) {
            case 0: // Home
              Navigator.of(context).pop();
              break;
            case 1: // History - already here
              break;
            case 2: // Device
              Navigator.of(context).pushNamed('/pairing');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: 'Device'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, HistoryViewMode mode) {
    final isSelected = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.navyBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.labelLarge.copyWith(
              color: isSelected ? AppTheme.white : AppTheme.darkGray,
            ),
          ),
        ),
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
              Icons.history,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No readings yet',
              style: AppTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Take your first blood pressure reading to see it here.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphView() {
    final measurements = _filteredMeasurements.reversed.toList(); // Oldest first for graph

    if (measurements.isEmpty) return _buildEmptyState();

    // Build spots for systolic and diastolic
    final systolicSpots = <FlSpot>[];
    final diastolicSpots = <FlSpot>[];

    for (int i = 0; i < measurements.length; i++) {
      final values = measurements[i].values.first;
      systolicSpots.add(FlSpot(i.toDouble(), values[0].toDouble()));
      diastolicSpots.add(FlSpot(i.toDouble(), values[1].toDouble()));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blood Pressure Trend',
                  style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                        getDrawingHorizontalLine: (value) {
                          // Highlight normal BP threshold
                          if (value == 120 || value == 80) {
                            return FlLine(
                              color: AppTheme.accentGreen.withOpacity(0.5),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          }
                          return FlLine(
                            color: AppTheme.lightGray,
                            strokeWidth: 0.5,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: (measurements.length / 5).ceilToDouble().clamp(1, 10),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < measurements.length) {
                                final date = measurements[index].keys.first;
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    DateFormat('M/d').format(date),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 20,
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 40,
                      maxY: 200,
                      lineBarsData: [
                        // Systolic line (red)
                        LineChartBarData(
                          spots: systolicSpots,
                          isCurved: true,
                          color: AppTheme.error,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: measurements.length < 15,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: AppTheme.error,
                                strokeWidth: 1,
                                strokeColor: AppTheme.white,
                              );
                            },
                          ),
                        ),
                        // Diastolic line (blue)
                        LineChartBarData(
                          spots: diastolicSpots,
                          isCurved: true,
                          color: AppTheme.navyBlue,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: measurements.length < 15,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: AppTheme.navyBlue,
                                strokeWidth: 1,
                                strokeColor: AppTheme.white,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Systolic', AppTheme.error),
                    const SizedBox(width: AppTheme.spacingLg),
                    _buildLegendItem('Diastolic', AppTheme.navyBlue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Text(label, style: AppTheme.bodyMedium),
      ],
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: AppCard(
        child: Column(
          children: [
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.lightGray),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('Date', style: AppTheme.labelLarge),
                  ),
                  Expanded(
                    child: Text('BP', style: AppTheme.labelLarge, textAlign: TextAlign.center),
                  ),
                  Expanded(
                    child: Text('HR', style: AppTheme.labelLarge, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            // Table rows
            ..._filteredMeasurements.map((measurement) {
              final date = measurement.keys.first;
              final values = measurement.values.first;
              final systolic = values[0];
              final diastolic = values[1];
              final hr = values.length > 2 ? values[2] : 0;

              // Determine BP category color
              Color bpColor = AppTheme.accentGreen;
              if (systolic >= 180 || diastolic >= 120) {
                bpColor = AppTheme.error;
              } else if (systolic >= 140 || diastolic >= 90) {
                bpColor = AppTheme.error;
              } else if (systolic >= 130 || diastolic >= 80) {
                bpColor = AppTheme.warning;
              }

              return Container(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.lightGray.withOpacity(0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(date),
                            style: AppTheme.bodyMedium,
                          ),
                          Text(
                            DateFormat('h:mm a').format(date),
                            style: AppTheme.labelMedium.copyWith(color: AppTheme.mediumGray),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSm,
                          vertical: AppTheme.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: bpColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          '$systolic/$diastolic',
                          style: AppTheme.bodyLarge.copyWith(
                            color: bpColor,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        hr > 0 ? '$hr' : '-',
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
