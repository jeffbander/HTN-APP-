import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';
import 'widgets/primary_button.dart';
import 'flaskRegUsr.dart';
import 'historyView.dart';
import 'msg.dart';
import 'navigationManager.dart';
import 'utils/status_router.dart';
import 'services/sync_service.dart';

class ProfileScreen extends StatefulWidget {
  final BaseMessenger? messenger;

  const ProfileScreen({super.key, this.messenger});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage();
  final _api = FlaskRegUsr();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Read-only fields
  String _name = '';
  String _email = '';
  String _dob = '';
  String _unionName = '';
  String _status = '';
  String _memberSince = '';

  // Editable fields
  String _phone = '';
  String _address = '';
  String _medicalHistory = '';

  // Health data fields (read-only, from registration)
  String _medications = '';
  String? _smokingStatus;
  bool? _hasHighBP;
  bool? _onBPMedication;
  List<String> _chronicConditions = [];

  // Lifestyle questionnaire tracking
  bool _lifestyleIncomplete = false;

  // Controllers for editable fields
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _medicalHistoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
        return;
      }

      final profile = await _api.getProfile(token);
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profile';
        });
        return;
      }

      // Look up union name
      String unionName = '';
      final unionId = profile['union_id'];
      if (unionId != null) {
        final unions = await _api.fetchUnions();
        unionName = unions[unionId] ?? 'Unknown';
      }

      // Format DOB
      String formattedDob = '';
      final dob = profile['dob'];
      if (dob != null && dob is String && dob.isNotEmpty) {
        try {
          final parsed = DateTime.parse(dob);
          formattedDob = DateFormat('MM/dd/yyyy').format(parsed);
        } catch (_) {
          formattedDob = dob;
        }
      }

      // Format member since
      String memberSince = '';
      final createdAt = profile['created_at'];
      if (createdAt != null && createdAt is String) {
        try {
          final parsed = DateTime.parse(createdAt);
          memberSince = DateFormat('MMMM d, yyyy').format(parsed);
        } catch (_) {
          memberSince = createdAt;
        }
      }

      // Determine status from user_status field
      final userStatusRaw = profile['user_status'] as String? ?? 'pending_approval';
      String statusText = StatusRouter.statusLabel(userStatusRaw);

      // Get editable fields
      final phone = profile['phone'] ?? '';
      final address = profile['address'] ?? '';
      final medicalHistory = profile['medical_history'] ?? '';

      // Get health data fields
      final medications = profile['medications'] ?? '';
      final smokingStatus = profile['smoking_status'];
      final hasHighBP = profile['has_high_blood_pressure'];
      final onBPMedication = profile['on_bp_medication'];
      final chronicConditions = profile['chronic_conditions'] != null
          ? List<String>.from(profile['chronic_conditions'])
          : <String>[];

      // Check if lifestyle questionnaire is incomplete
      final lifestyleIncomplete = profile['exercise_days_per_week'] == null
          && profile['stress_level'] == null;

      setState(() {
        _name = profile['name'] ?? '';
        _email = profile['email'] ?? '';
        _dob = formattedDob;
        _unionName = unionName;
        _status = statusText;
        _memberSince = memberSince;
        _phone = phone;
        _address = address;
        _medicalHistory = medicalHistory;
        _phoneController.text = phone;
        _addressController.text = address;
        _medicalHistoryController.text = medicalHistory;
        // Health data
        _medications = medications;
        _smokingStatus = smokingStatus;
        _hasHighBP = hasHighBP;
        _onBPMedication = onBPMedication;
        _chronicConditions = chronicConditions;
        _lifestyleIncomplete = lifestyleIncomplete;
        _isLoading = false;
      });
    } catch (e) {
      dev.log('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profile';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No auth token');
      }

      final result = await _api.updateProfile(
        token,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        medicalHistory: _medicalHistoryController.text.trim(),
      );

      if (!mounted) return;

      if (result['status'] == 200) {
        setState(() {
          _phone = _phoneController.text.trim();
          _address = _addressController.text.trim();
          _medicalHistory = _medicalHistoryController.text.trim();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Failed to update profile');
      }
    } catch (e) {
      dev.log('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool get _hasChanges {
    return _phoneController.text.trim() != _phone ||
        _addressController.text.trim() != _address ||
        _medicalHistoryController.text.trim() != _medicalHistory;
  }

  Future<void> _handleSignOut() async {
    if (_hasChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. Discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (shouldDiscard != true) return;
    }

    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'userId');
    await _storage.delete(key: 'user_status');
    // Clear local measurement cache to prevent cross-account data leakage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('measurements');
    await SyncService.instance.clearQueue();
    // Keep userEmail for autofill on next login
    if (mounted) {
      // Navigate through NavigationManager to preserve the root Consumer route.
      // Using pushNamedAndRemoveUntil('/login') would destroy the root Consumer,
      // breaking subsequent popUntil(isFirst) navigation in login/MFA flows.
      final navManager = Provider.of<NavigationManager>(context, listen: false);
      await navManager.navigate(ViewType.loginView);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _openLifestyleQuestionnaire() {
    Navigator.of(context).pushNamed(
      '/lifestyle',
      arguments: {
        'onComplete': () {
          Navigator.of(context).pop();
        },
      },
    ).then((_) {
      _loadProfile();
    });
  }

  void _showEditDialog(String field, TextEditingController controller, {int maxLines = 1}) {
    final tempController = TextEditingController(text: controller.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text('Edit $field'),
        content: TextField(
          controller: tempController,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: 'Enter $field',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.text = tempController.text;
              Navigator.pop(context);
              setState(() {}); // Trigger rebuild to show save button
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: const Text('Done'),
          ),
        ],
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
            title: 'My Profile',
            subtitle: 'View & edit your information',
            showBackButton: true,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: AppTheme.mediumGray),
                            const SizedBox(height: AppTheme.spacingMd),
                            Text(_errorMessage!,
                                style: AppTheme.bodyLarge
                                    .copyWith(color: AppTheme.mediumGray)),
                            const SizedBox(height: AppTheme.spacingMd),
                            PrimaryButton(
                              label: 'Retry',
                              fullWidth: false,
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = null;
                                });
                                _loadProfile();
                              },
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        child: Column(
                          children: [
                            const SizedBox(height: AppTheme.spacingMd),

                            // Avatar + name card
                            Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.navyBlue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: AppTheme.navyBlue,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Text(_name, style: AppTheme.headlineMedium),
                                const SizedBox(height: AppTheme.spacingXs),
                                Text(_email, style: AppTheme.bodyMedium),
                              ],
                            ),

                            const SizedBox(height: AppTheme.spacingLg),

                            // Personal Information card (Read-only)
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Personal Information',
                                        style: AppTheme.titleMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.lock_outline,
                                        size: 16,
                                        color: AppTheme.mediumGray,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingXs),
                                  Text(
                                    'Contact admin to update these fields',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.mediumGray,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  _buildReadOnlyRow('Name', _name),
                                  const Divider(),
                                  _buildReadOnlyRow('Email', _email),
                                  const Divider(),
                                  _buildReadOnlyRow('Date of Birth', _dob),
                                  if (_unionName.isNotEmpty) ...[
                                    const Divider(),
                                    _buildReadOnlyRow('Union', _unionName),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingMd),

                            // Contact Info card (Editable)
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Contact Info',
                                        style: AppTheme.titleMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: AppTheme.accentGreen,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingXs),
                                  Text(
                                    'Tap to edit',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  _buildEditableRow(
                                    'Phone',
                                    _phoneController.text.isNotEmpty
                                        ? _phoneController.text
                                        : 'Not set',
                                    () => _showEditDialog('Phone', _phoneController),
                                  ),
                                  const Divider(),
                                  _buildEditableRow(
                                    'Address',
                                    _addressController.text.isNotEmpty
                                        ? _addressController.text
                                        : 'Not set',
                                    () => _showEditDialog('Address', _addressController, maxLines: 3),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingMd),

                            // Health Information card (Read-only)
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Health Information',
                                        style: AppTheme.titleMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.lock_outline,
                                        size: 16,
                                        color: AppTheme.mediumGray,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingXs),
                                  Text(
                                    'From registration questionnaire',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.mediumGray,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  _buildReadOnlyRow(
                                    'Medications',
                                    _medications.isNotEmpty ? _medications : 'None',
                                  ),
                                  const Divider(),
                                  _buildReadOnlyRow(
                                    'Smoking Status',
                                    _smokingStatus ?? 'Not specified',
                                  ),
                                  const Divider(),
                                  _buildReadOnlyRow(
                                    'High Blood Pressure',
                                    _hasHighBP == true ? 'Yes' : (_hasHighBP == false ? 'No' : 'Not specified'),
                                  ),
                                  const Divider(),
                                  _buildReadOnlyRow(
                                    'BP Medication',
                                    _onBPMedication == true ? 'Yes' : (_onBPMedication == false ? 'No' : 'Not specified'),
                                  ),
                                  const Divider(),
                                  _buildReadOnlyRow(
                                    'Chronic Conditions',
                                    _chronicConditions.isNotEmpty
                                        ? _chronicConditions.join(', ')
                                        : 'None',
                                  ),
                                ],
                              ),
                            ),

                            // Save button (shown when there are changes)
                            if (_hasChanges) ...[
                              const SizedBox(height: AppTheme.spacingMd),
                              PrimaryButton(
                                label: _isSaving ? 'Saving...' : 'Save Changes',
                                onPressed: _isSaving ? null : _saveProfile,
                              ),
                            ],

                            // Lifestyle questionnaire banner
                            if (_lifestyleIncomplete) ...[
                              const SizedBox(height: AppTheme.spacingMd),
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.assignment_outlined,
                                          color: AppTheme.navyBlue,
                                          size: 24,
                                        ),
                                        const SizedBox(width: AppTheme.spacingSm),
                                        Expanded(
                                          child: Text(
                                            'Complete Your Lifestyle Questionnaire',
                                            style: AppTheme.titleMedium.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.spacingSm),
                                    Text(
                                      'Help us provide personalized health insights by answering a few questions about your lifestyle.',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.darkGray,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.spacingMd),
                                    PrimaryButton(
                                      label: 'Complete Now',
                                      onPressed: _openLifestyleQuestionnaire,
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: AppTheme.spacingMd),

                            // Account Status card
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Status',
                                    style: AppTheme.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingMd),
                                  Row(
                                    children: [
                                      Text('Status',
                                          style: AppTheme.labelLarge
                                              .copyWith(color: AppTheme.navyBlue)),
                                      const Spacer(),
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _status == 'Active'
                                              ? AppTheme.accentGreen
                                              : _status == 'Deactivated'
                                                  ? AppTheme.error
                                                  : AppTheme.warning,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingSm),
                                      Text(
                                        _status.toUpperCase(),
                                        style: AppTheme.labelLarge.copyWith(
                                          color: _status == 'Active'
                                              ? AppTheme.accentGreen
                                              : _status == 'Deactivated'
                                                  ? AppTheme.error
                                                  : AppTheme.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_memberSince.isNotEmpty) ...[
                                    const Divider(),
                                    _buildReadOnlyRow('Member Since', _memberSince),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: AppTheme.spacingLg),

                            // Sign Out button
                            PrimaryButton(
                              label: 'Sign Out',
                              variant: ButtonVariant.outline,
                              onPressed: _handleSignOut,
                            ),

                            const SizedBox(height: AppTheme.spacingLg),
                          ],
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // No specific tab selected for profile
        selectedItemColor: AppTheme.navyBlue,
        unselectedItemColor: AppTheme.mediumGray,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (_hasChanges) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please save or discard your changes first'),
                backgroundColor: AppTheme.warning,
              ),
            );
            return;
          }
          switch (index) {
            case 0: // Home
              Navigator.of(context).pop();
              break;
            case 1: // History
              Navigator.of(context).pop();
              if (widget.messenger != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        HistoryView(messenger: widget.messenger!),
                  ),
                );
              }
              break;
            case 2: // Device
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/device-info');
              break;
            case 3: // Reminders
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/reminders');
              break;
            case 4: // Help
              Navigator.of(context).pop();
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

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTheme.labelLarge.copyWith(color: AppTheme.navyBlue)),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            value.isNotEmpty ? value : '-',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.darkGray),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTheme.labelLarge.copyWith(color: AppTheme.navyBlue)),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    value,
                    style: AppTheme.bodyLarge.copyWith(
                      color: value == 'Not set' ? AppTheme.mediumGray : AppTheme.darkGray,
                      fontStyle: value == 'Not set' ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Icon(
              Icons.chevron_right,
              color: AppTheme.mediumGray,
            ),
          ],
        ),
      ),
    );
  }
}
