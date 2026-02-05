import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as dev;
import 'theme/app_theme.dart';
import 'widgets/form_field.dart';
import 'widgets/primary_button.dart';
import 'flaskRegUsr.dart';
import 'navigationManager.dart';
import 'sourceManager.dart';

class LoginScreen extends StatefulWidget {
  final String? prefillEmail;

  const LoginScreen({super.key, this.prefillEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _api = FlaskRegUsr();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
    } else {
      _loadSavedEmail();
    }
  }

  Future<void> _loadSavedEmail() async {
    final savedEmail = await _storage.read(key: 'userEmail');
    if (savedEmail != null && mounted) {
      setState(() {
        _emailController.text = savedEmail;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final result = await _api.loginUser(email);

      if (!mounted) return;

      switch (result['status']) {
        case 200:
          // Check if MFA is required
          if (result['mfa_required'] == true) {
            if (mounted) {
              Navigator.of(context).pushNamed('/mfa-verify', arguments: {
                'mfa_session_token': result['mfa_session_token'],
                'mfa_type': result['mfa_type'],
                'email': email,
              });
            }
            break;
          }
          // Store token and email
          final token = result['token'] as String;
          final userId = result['userId'];
          await _storage.write(key: 'auth_token', value: token);
          await _storage.write(key: 'userEmail', value: email);
          if (userId != null) {
            await _storage.write(key: 'userId', value: userId.toString());
          }
          // Sync email to SourceManager so flaskUploader uses correct identity
          SourceManager.shared.userInfo.login = email;
          try {
            SourceManager.shared.sharedPrefs.setString('login', email);
          } catch (_) {
            // SharedPreferences may not be initialized yet; will sync on next launch
          }
          // Navigate to measurement view via NavigationManager
          if (mounted) {
            final navManager = Provider.of<NavigationManager>(context, listen: false);
            navManager.showMeasurementView();
            // Pop any Navigator routes to return to root Consumer
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          break;
        case 404:
          setState(() {
            _errorMessage = 'No account found with this email. Please check your email address or register if you\'re a new user.';
          });
          break;
        case 403:
          // Not approved or deactivated — navigate to pending approval
          if (mounted) {
            Navigator.of(context).pushNamed('/pending-approval');
          }
          break;
        case 401:
          setState(() {
            _errorMessage = 'Your session has expired. Please try again.';
          });
          break;
        case 429:
          setState(() {
            _errorMessage = 'Too many login attempts. Please wait a few minutes and try again.';
          });
          break;
        case 500:
          setState(() {
            _errorMessage = 'Server error. Our team has been notified. Please try again later.';
          });
          break;
        case 0:
          setState(() {
            _errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
          });
          break;
        default:
          setState(() {
            _errorMessage = result['error'] ?? 'Login failed. Please try again.';
          });
      }
    } catch (e) {
      dev.log('Login error: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Navy gradient header with logo
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
                      // Logo
                      Image.asset(
                        'assets/Logotrans.png',
                        height: 80,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Icon(
                              Icons.local_hospital,
                              color: AppTheme.white,
                              size: 40,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingLg),
                      Text(
                        'Hypertension',
                        style: AppTheme.headlineLarge.copyWith(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        'Prevention Program\nfor First Responders',
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
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppTheme.spacingMd),
                      Text(
                        'Welcome Back',
                        style: AppTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'Sign in with your email',
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTheme.spacingXl),

                      // Email field with autofill
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Email', style: AppTheme.labelLarge),
                              Text(
                                ' *',
                                style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              hintText: 'your@email.com',
                            ),
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

                      const SizedBox(height: AppTheme.spacingMd),

                      // Sign In button
                      PrimaryButton(
                        label: 'Sign In',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),

                      const SizedBox(height: AppTheme.spacingXl),

                      // Register link
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "Don't have an account?",
                              style: AppTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppTheme.spacingXs),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushNamed('/registration');
                              },
                              child: Text(
                                'Register here',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.navyBlue,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
