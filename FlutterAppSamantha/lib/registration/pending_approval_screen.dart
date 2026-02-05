import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../flaskRegUsr.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  static const String _contactEmail = 'htn.prevention@mountsinai.org';

  final _storage = const FlutterSecureStorage();
  final _api = FlaskRegUsr();
  Timer? _pollTimer;
  bool _isApproved = false;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    // Check status immediately
    _checkApprovalStatus();
    // Poll every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkApprovalStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkApprovalStatus() async {
    if (_isCheckingStatus) return;
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return;

      final profile = await _api.getProfile(token);
      if (profile != null && profile['is_approved'] == true && mounted) {
        setState(() {
          _isApproved = true;
        });
        _pollTimer?.cancel();
        // Navigate to approved screen after short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/device-selection');
        }
      }
    } catch (e) {
      // Silent failure - will retry on next poll
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      query: 'subject=Registration Help Request',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact us at $_contactEmail'),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                // Copy email to clipboard would go here
              },
            ),
          ),
        );
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
            title: 'Registration Submitted',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _checkApprovalStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  children: [
                    const SizedBox(height: AppTheme.spacingXl),
                    // Hourglass icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _isApproved
                            ? AppTheme.accentGreen.withOpacity(0.1)
                            : AppTheme.warning.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isApproved ? Icons.check_circle : Icons.hourglass_top,
                        size: 60,
                        color: _isApproved ? AppTheme.accentGreen : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      _isApproved ? 'Approved!' : 'Pending Approval',
                      style: AppTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingXl),
                    AppCard(
                      child: Column(
                        children: [
                          Text(
                            _isApproved
                                ? 'Your registration has been approved!'
                                : 'Your registration has been submitted for review.',
                            style: AppTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            _isApproved
                                ? 'Redirecting you to setup your device...'
                                : 'A union representative will verify your membership.',
                            style: AppTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spacingSm),
                            decoration: BoxDecoration(
                              color: AppTheme.navyBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: const Icon(
                              Icons.notifications_active,
                              color: AppTheme.navyBlue,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Text(
                              "You'll receive a push notification when your registration is approved.",
                              style: AppTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    AppCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Status: ',
                            style: AppTheme.bodyLarge,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMd,
                              vertical: AppTheme.spacingSm,
                            ),
                            decoration: BoxDecoration(
                              color: _isApproved
                                  ? AppTheme.accentGreen.withOpacity(0.1)
                                  : AppTheme.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isCheckingStatus)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _isApproved ? AppTheme.accentGreen : AppTheme.warning,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _isApproved ? AppTheme.accentGreen : AppTheme.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(width: AppTheme.spacingSm),
                                Text(
                                  _isApproved ? 'APPROVED' : 'PENDING REVIEW',
                                  style: AppTheme.labelLarge.copyWith(
                                    color: _isApproved ? AppTheme.accentGreen : AppTheme.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    // Contact support card
                    AppCard(
                      child: Column(
                        children: [
                          Text(
                            'Need help?',
                            style: AppTheme.titleMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text(
                            'Contact our support team:',
                            style: AppTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          GestureDetector(
                            onTap: _sendEmail,
                            child: Text(
                              _contactEmail,
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.navyBlue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'Pull down to refresh status',
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Testing button to skip approval
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: PrimaryButton(
                label: 'Continue (Skip for Testing)',
                variant: ButtonVariant.navy,
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/device-selection');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
