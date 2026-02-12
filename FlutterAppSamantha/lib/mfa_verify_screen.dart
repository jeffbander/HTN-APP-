import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as dev;
import 'theme/app_theme.dart';
import 'widgets/primary_button.dart';
import 'flaskRegUsr.dart';
import 'navigationManager.dart';
import 'sourceManager.dart';
import 'utils/status_router.dart';

class MfaVerifyScreen extends StatefulWidget {
  final String mfaSessionToken;
  final String mfaType;
  final String email;

  const MfaVerifyScreen({
    super.key,
    required this.mfaSessionToken,
    required this.mfaType,
    required this.email,
  });

  @override
  State<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends State<MfaVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _api = FlaskRegUsr();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final code = _codeController.text.trim();
      final result = await _api.verifyMfa(widget.mfaSessionToken, code);

      if (!mounted) return;

      if (result['status'] == 200) {
        final token = result['token'] as String;
        final userId = result['userId'];
        final userStatus = result['user_status'] as String? ?? 'active';
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'userEmail', value: widget.email);
        await _storage.write(key: 'user_status', value: userStatus);
        if (userId != null) {
          await _storage.write(key: 'userId', value: userId.toString());
        }
        // Sync email to SourceManager so flaskUploader uses correct identity
        SourceManager.shared.userInfo.login = widget.email;
        try {
          SourceManager.shared.sharedPrefs.setString('login', widget.email);
        } catch (_) {
          // SharedPreferences may not be initialized yet; will sync on next launch
        }
        // Route based on user_status
        if (mounted) {
          final targetRoute = StatusRouter.routeForStatus(userStatus);
          if (targetRoute == '/measurement') {
            final navManager = Provider.of<NavigationManager>(context, listen: false);
            navManager.userStatus = userStatus;
            navManager.showMeasurementView();
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (r) => false);
          }
        }
      } else if (result['status'] == 429) {
        setState(() {
          _errorMessage = 'Too many failed attempts. Please log in again.';
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Invalid code. Please try again.';
        });
      }
    } catch (e) {
      dev.log('MFA verify error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error. Please check your network.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _api.resendMfaCode(widget.mfaSessionToken);

      if (!mounted) return;

      if (result['status'] == 200) {
        setState(() {
          _successMessage = 'A new code has been sent to your email.';
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to resend code.';
        });
      }
    } catch (e) {
      dev.log('MFA resend error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error. Please check your network.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Navy gradient header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.navyGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radiusXl),
                  bottomRight: Radius.circular(AppTheme.radiusXl),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingXl,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: AppTheme.spacingMd),
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: AppTheme.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      Text(
                        'Verify Identity',
                        style: AppTheme.headlineLarge.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        widget.mfaType == 'totp'
                            ? 'Enter the code from\nyour authenticator app'
                            : 'Enter the 6-digit code\nsent to your email',
                        textAlign: TextAlign.center,
                        style: AppTheme.titleLarge.copyWith(
                          color: AppTheme.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],
                  ),
                ),
              ),
            ),

            // Form content
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      'Verification Code',
                      style: AppTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      widget.mfaType == 'totp'
                          ? 'Enter the code from your authenticator app'
                          : 'We sent a verification code to ${widget.email}',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingXl),

                    // Code input
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Code', style: AppTheme.labelLarge),
                            Text(
                              ' *',
                              style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          maxLength: widget.mfaType == 'totp' ? 8 : 6,
                          onFieldSubmitted: (_) => _handleVerify(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Verification code is required';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: '000000',
                            counterText: '',
                          ),
                          style: const TextStyle(
                            letterSpacing: 8,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                            const SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                    ],

                    // Success message
                    if (_successMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                            const SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: AppTheme.bodyMedium.copyWith(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                    ],

                    const SizedBox(height: AppTheme.spacingMd),

                    // Verify button
                    PrimaryButton(
                      label: 'Verify',
                      isLoading: _isLoading,
                      onPressed: _handleVerify,
                    ),

                    const SizedBox(height: AppTheme.spacingLg),

                    // Resend button (email MFA only)
                    if (widget.mfaType == 'email')
                      Center(
                        child: GestureDetector(
                          onTap: _isResending ? null : _handleResend,
                          child: Text(
                            _isResending ? 'Sending...' : 'Resend code',
                            style: AppTheme.bodyMedium.copyWith(
                              color: _isResending ? AppTheme.mediumGray : AppTheme.navyBlue,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),

                    if (widget.mfaType == 'totp')
                      Center(
                        child: Text(
                          'You can also use a backup code',
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
                        ),
                      ),

                    const SizedBox(height: AppTheme.spacingMd),

                    // Back to login
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          'Back to login',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.navyBlue,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
