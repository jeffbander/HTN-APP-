import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';
import 'widgets/primary_button.dart';
import 'msg.dart';

class DeviceInfoView extends StatefulWidget {
  final BaseMessenger? messenger;
  final bool isConnected;
  final String? deviceName;
  final String? deviceModel;

  const DeviceInfoView({
    super.key,
    this.messenger,
    this.isConnected = false,
    this.deviceName,
    this.deviceModel,
  });

  @override
  State<DeviceInfoView> createState() => _DeviceInfoViewState();
}

class _DeviceInfoViewState extends State<DeviceInfoView> {
  String _deviceName = 'Omron EVOLV';
  String _deviceModel = 'Omron EVOLV';
  bool _isConnected = false;
  DateTime? _lastSyncTime;
  int _totalReadings = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;
    if (widget.deviceName != null) _deviceName = widget.deviceName!;
    if (widget.deviceModel != null) _deviceModel = widget.deviceModel!;
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved device info
    final savedName = prefs.getString('device_name');
    final savedModel = prefs.getString('device_model');
    final lastSyncStr = prefs.getString('last_sync_time');
    final readings = prefs.getStringList('measurements')?.length ?? 0;

    if (mounted) {
      setState(() {
        if (savedName != null) _deviceName = savedName;
        if (savedModel != null) _deviceModel = savedModel;
        if (lastSyncStr != null) {
          try {
            _lastSyncTime = DateTime.parse(lastSyncStr);
          } catch (_) {}
        }
        _totalReadings = readings;
        // Check if we have a saved connected state
        _isConnected = prefs.getBool('device_connected') ?? widget.isConnected;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
    });

    // Simulate sync - in real app this would trigger Bluetooth sync
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString('last_sync_time', now.toIso8601String());

    if (mounted) {
      setState(() {
        _lastSyncTime = now;
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync complete'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _disconnectDevice() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device'),
        content: const Text(
            'Are you sure you want to disconnect your blood pressure monitor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('device_connected', false);
              if (mounted) {
                setState(() {
                  _isConnected = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device disconnected'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _repairDevice() {
    Navigator.of(context).pushReplacementNamed('/pairing');
  }

  String _formatLastSync() {
    if (_lastSyncTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(_lastSyncTime!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: 'Device Info',
            subtitle: 'Blood Pressure Monitor',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  // Device status card
                  AppCard(
                    child: Column(
                      children: [
                        // Device icon/image
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? AppTheme.accentGreen.withOpacity(0.1)
                                : AppTheme.lightGray,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            size: 50,
                            color: _isConnected ? AppTheme.accentGreen : AppTheme.mediumGray,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          _deviceName,
                          style: AppTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppTheme.spacingXs),
                        Text(
                          _deviceModel,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.mediumGray,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        // Connection status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMd,
                            vertical: AppTheme.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? AppTheme.accentGreen.withOpacity(0.1)
                                : AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isConnected ? AppTheme.accentGreen : AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingSm),
                              Text(
                                _isConnected ? 'Connected' : 'Disconnected',
                                style: AppTheme.labelLarge.copyWith(
                                  color: _isConnected ? AppTheme.accentGreen : AppTheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  // Device info card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Information',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        _buildInfoRow('Device Name', _deviceName),
                        const Divider(),
                        _buildInfoRow('Model', _deviceModel),
                        const Divider(),
                        _buildInfoRow('Last Sync', _formatLastSync()),
                        const Divider(),
                        _buildInfoRow('Total Readings', '$_totalReadings'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  // Actions card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actions',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        // Sync Now button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isConnected && !_isSyncing ? _syncNow : null,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navyBlue,
                              side: const BorderSide(color: AppTheme.navyBlue),
                              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        // Re-pair button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _repairDevice,
                            icon: const Icon(Icons.bluetooth),
                            label: const Text('Re-pair Device'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navyBlue,
                              side: const BorderSide(color: AppTheme.navyBlue),
                              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        // Disconnect button
                        if (_isConnected)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _disconnectDevice,
                              icon: const Icon(Icons.link_off),
                              label: const Text('Disconnect Device'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  // Troubleshooting tips
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.warning,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Text(
                              'Troubleshooting Tips',
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        _buildTip('Make sure Bluetooth is enabled on your phone'),
                        _buildTip('Keep your phone within 3 feet of the cuff'),
                        _buildTip('Ensure your cuff has fresh batteries'),
                        _buildTip('Try turning the cuff off and on again'),
                        _buildTip('If issues persist, forget the device in Bluetooth settings and re-pair'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.mediumGray,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
