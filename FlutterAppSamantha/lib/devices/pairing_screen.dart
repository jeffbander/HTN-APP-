import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../sourceManager.dart';
import '../navigationManager.dart';
import '../msg.dart';
import '../sourceBase.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = true;
  bool _deviceFound = false;
  bool _isPairing = false;
  bool _pairingComplete = false;
  bool _pairingFailed = false;
  String? _deviceName;
  String? _errorMessage;
  bool _instructionsShown = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late SourceManager _sourceManager;
  StreamSubscription<Msg>? _messageSubscription;
  BluetoothDevice? _selectedDevice;
  List<BluetoothDevice> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sourceManager = SourceManager.shared;
    _setupMessageListener();

    // Show instructions modal on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_instructionsShown) {
        _showInstructionsModal();
        _instructionsShown = true;
      }
    });
  }

  void _showInstructionsModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text(
          'Pairing Instructions',
          style: AppTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cuff Image placeholder
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bluetooth,
                        size: 40,
                        color: AppTheme.navyBlue.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'Omron BP Monitor',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              // Instructions
              _buildInstructionItem(1, 'Turn on your BP cuff'),
              const SizedBox(height: AppTheme.spacingSm),
              _buildInstructionItem(2, 'Hold the O/I button until the Bluetooth icon starts blinking'),
              const SizedBox(height: AppTheme.spacingSm),
              _buildInstructionItem(3, 'Wait for "P" to appear on the display'),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startRealScan();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: const Text('Got it!'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppTheme.navyBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: AppTheme.labelMedium.copyWith(color: AppTheme.white),
            ),
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
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _messageSubscription?.cancel();
    _sourceManager.cancelPairing();
    super.dispose();
  }

  void _setupMessageListener() {
    // Listen for device discovery and pairing status messages
    _messageSubscription = _sourceManager.bluetoothMessenger.statusSignalStream.listen((msg) async {
      if (!mounted) return;

      // Handle device discovery
      if (msg.taskType == TaskType.DiscoverSource && msg.source != null) {
        if (msg.source is BluetoothSource) {
          final bluetoothSource = msg.source as BluetoothSource;
          if (bluetoothSource.connectedPeripheral != null) {
            final device = bluetoothSource.connectedPeripheral!;
            // Avoid duplicates
            if (!_discoveredDevices.any((d) => d.remoteId == device.remoteId)) {
              setState(() {
                _discoveredDevices.add(device);
                _isSearching = false;
                _deviceFound = true;
                // Use the first device found
                if (_selectedDevice == null) {
                  _selectedDevice = device;
                  _deviceName = device.platformName.isNotEmpty
                      ? device.platformName
                      : 'Omron BP Monitor';
                }
              });
            }
          }
        }
      }

      // Handle scan completion
      if (msg.taskType == TaskType.Scan) {
        if (msg.status == Status.succeeded || msg.status == Status.finished) {
          setState(() {
            _isSearching = false;
            if (_discoveredDevices.isEmpty) {
              _errorMessage = 'No devices found. Make sure your cuff is in pairing mode.';
            }
          });
        } else if (msg.status == Status.failed) {
          setState(() {
            _isSearching = false;
            _errorMessage = 'Scan failed. Please check Bluetooth permissions.';
          });
        }
      }

      // Handle pairing result
      if (msg.taskType == TaskType.Pair) {
        if (msg.status == Status.succeeded) {
          // Persist device info to SharedPreferences so the app remembers this cuff
          if (_selectedDevice != null) {
            await _sourceManager.registerDeviceInfo(
              _sourceManager.curDeviceModel,
              _selectedDevice!.remoteId.toString(),
            );
          }
          setState(() {
            _isPairing = false;
            _pairingComplete = true;
          });
          _navigateToHome();
        } else if (msg.status == Status.failed) {
          setState(() {
            _isPairing = false;
            _pairingFailed = true;
            _errorMessage = 'Pairing failed. Please try again.';
          });
        }
      }
    });
  }

  Future<void> _startRealScan() async {
    dev.log('PAIRING SCREEN: _startRealScan called');
    setState(() {
      _isSearching = true;
      _deviceFound = false;
      _discoveredDevices.clear();
      _selectedDevice = null;
      _errorMessage = null;
      _pairingFailed = false;
    });

    try {
      dev.log('PAIRING SCREEN: calling startScanning...');
      await _sourceManager.startScanning();

      // Timeout after 15 seconds if no device found
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _isSearching && _discoveredDevices.isEmpty) {
          setState(() {
            _isSearching = false;
            _errorMessage = 'No devices found. Make sure your cuff is in pairing mode (hold Bluetooth button until "P" appears).';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Failed to start scan: $e';
        });
      }
    }
  }

  Future<void> _pairDevice() async {
    dev.log('PAIRING SCREEN: _pairDevice called, device=${_selectedDevice != null ? 'present' : 'null'}');
    if (_selectedDevice == null) return;

    setState(() {
      _isPairing = true;
      _pairingFailed = false;
      _errorMessage = null;
    });

    try {
      // Set up the source object and trigger pairing
      _sourceManager.curSrcObj = BluetoothSource(peripheral: _selectedDevice);
      dev.log('PAIRING SCREEN: calling startPairing...');
      await _sourceManager.startPairing();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPairing = false;
          _pairingFailed = true;
          _errorMessage = 'Pairing failed: $e';
        });
      }
    }
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      // Update stored user status since they've paired a device
      const storage = FlutterSecureStorage();
      await storage.write(key: 'user_status', value: 'active');

      // Update NavigationManager state before navigating
      final navManager = Provider.of<NavigationManager>(context, listen: false);
      navManager.userStatus = 'active';
      navManager.showMeasurementView();
      // Navigate to measurement, clearing the entire stack
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/measurement',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: _pairingComplete ? 'Paired!' : 'Pairing Device',
            showBackButton: !_isPairing && !_pairingComplete,
            onBackPressed: () {
              _sourceManager.cancelPairing();
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  const SizedBox(height: AppTheme.spacingXl),
                  // Status Icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isSearching || _isPairing
                            ? _pulseAnimation.value
                            : 1.0,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _pairingComplete
                                ? AppTheme.accentGreen.withOpacity(0.1)
                                : _pairingFailed
                                    ? AppTheme.error.withOpacity(0.1)
                                    : AppTheme.navyBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _pairingComplete
                                ? Icons.check_circle
                                : _pairingFailed
                                    ? Icons.error
                                    : _deviceFound
                                        ? Icons.bluetooth_connected
                                        : Icons.bluetooth_searching,
                            size: 60,
                            color: _pairingComplete
                                ? AppTheme.accentGreen
                                : _pairingFailed
                                    ? AppTheme.error
                                    : AppTheme.navyBlue,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  // Status Text
                  Text(
                    _pairingComplete
                        ? 'Device Paired Successfully!'
                        : _pairingFailed
                            ? 'Pairing Failed'
                            : _isPairing
                                ? 'Pairing...'
                                : _deviceFound
                                    ? 'Device Found'
                                    : 'Searching for devices...',
                    style: AppTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  if (_isSearching) ...[
                    Text(
                      'Make sure your Omron device is in pairing mode',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    TextButton(
                      onPressed: _showInstructionsModal,
                      child: Text(
                        'Need help? View instructions',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.navyBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppTheme.spacingMd),
                    AppCard(
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: AppTheme.error),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingXl),
                  // Device Card
                  if (_deviceFound && !_pairingComplete)
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingMd),
                            decoration: BoxDecoration(
                              color: AppTheme.navyBlue.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Icon(
                              Icons.bluetooth,
                              color: AppTheme.navyBlue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _deviceName ?? 'Unknown Device',
                                  style: AppTheme.titleLarge,
                                ),
                                const SizedBox(height: AppTheme.spacingXs),
                                Text(
                                  'Ready to pair',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.accentGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isPairing)
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.mediumGray,
                            ),
                          if (_isPairing)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.navyBlue),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_pairingComplete) ...[
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.all(AppTheme.spacingMd),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                child: const Icon(
                                  Icons.bluetooth_connected,
                                  color: AppTheme.accentGreen,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _deviceName ?? 'Omron BP Monitor',
                                      style: AppTheme.titleLarge,
                                    ),
                                    const SizedBox(height: AppTheme.spacingXs),
                                    Text(
                                      'Connected',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.check_circle,
                                color: AppTheme.accentGreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      'Redirecting to home...',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_deviceFound && !_pairingComplete && !_isPairing)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: PrimaryButton(
                  label: 'Pair Device',
                  onPressed: _pairDevice,
                ),
              ),
            ),
          if (_pairingFailed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: PrimaryButton(
                  label: 'Try Again',
                  onPressed: _startRealScan,
                ),
              ),
            ),
          if (_isSearching)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: PrimaryButton(
                  label: 'Cancel',
                  variant: ButtonVariant.outline,
                  onPressed: () {
                    _sourceManager.cancelPairing();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          if (!_isSearching && !_deviceFound && !_pairingComplete && !_pairingFailed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: PrimaryButton(
                  label: 'Scan Again',
                  onPressed: _startRealScan,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
