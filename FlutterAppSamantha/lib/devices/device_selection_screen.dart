import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../flaskRegUsr.dart';

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  final _storage = const FlutterSecureStorage();
  final _flaskRegUsr = FlaskRegUsr();
  bool _omronSelected = true;
  bool _isLoading = false;
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAddress() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return;

      final profile = await _flaskRegUsr.getProfile(token);
      if (profile != null && mounted) {
        final address = profile['address'] as String? ?? '';
        if (address.isNotEmpty) {
          setState(() {
            _addressController.text = address;
          });
        }
      }
    } catch (e) {
      // Silently fail - user can still enter address manually
    }
  }

  void _showCuffConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text(
          'Confirm Selection',
          style: AppTheme.headlineMedium,
        ),
        content: Text(
          'Do you have an Omron blood pressure cuff?',
          style: AppTheme.bodyLarge,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Go to pairing instructions
                    Navigator.of(context).pushNamed('/pairing');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.navyBlue,
                    side: const BorderSide(color: AppTheme.navyBlue),
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Text('YES'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Show address dialog to request cuff
                    _showAddressDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Text('NO'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text(
          'Confirm Shipping Address',
          style: AppTheme.headlineMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _addressController.text.isNotEmpty
                  ? "We'll ship your BP cuff to this address:"
                  : 'Please enter your shipping address:',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter full address including street, city, state, and zip code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestCuff(_addressController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCuff(String address) async {
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid address'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No auth token found');
      }

      final result = await _flaskRegUsr.requestCuff(token, address);

      if (result['status'] == 201) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/cuff-request-pending',
            arguments: {'address': address},
          );
        }
      } else if (result['status'] == 409) {
        // Already has a pending request
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'You already have a pending cuff request'),
              backgroundColor: AppTheme.warning,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/cuff-request-pending');
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to submit cuff request');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Select Your Device',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  Text(
                    'Select your BP monitor',
                    style: AppTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  // Omron Card
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _omronSelected = true;
                      });
                    },
                    child: AppCard(
                      selected: _omronSelected,
                      child: Column(
                        children: [
                          // Omron Logo placeholder
                          Container(
                            width: 120,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.lightGray,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Center(
                              child: Text(
                                'OMRON',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            'Omron Blood Pressure Monitor',
                            style: AppTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text(
                            '(All Omron models supported)',
                            style: AppTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (_omronSelected) ...[
                            const SizedBox(height: AppTheme.spacingMd),
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.accentGreen,
                              size: 32,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  // Divider with "OR"
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                        child: Text(
                          'OR',
                          style: AppTheme.labelMedium.copyWith(color: AppTheme.mediumGray),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  // Request Cuff Option
                  GestureDetector(
                    onTap: () => _showAddressDialog(),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingMd),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_shipping,
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
                                  'Request a BP Cuff',
                                  style: AppTheme.titleMedium,
                                ),
                                const SizedBox(height: AppTheme.spacingXs),
                                Text(
                                  'Get a free cuff shipped from Mount Sinai',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: AppTheme.mediumGray,
                            size: 20,
                          ),
                        ],
                      ),
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
                label: 'Next',
                onPressed: _omronSelected
                    ? () {
                        Navigator.of(context).pushNamed('/pairing');
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
