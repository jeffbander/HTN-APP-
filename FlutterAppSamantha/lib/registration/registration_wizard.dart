import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/step_indicator.dart';
import '../widgets/primary_button.dart';
import '../flaskRegUsr.dart';
import 'models/registration_data.dart';
import 'steps/step1_personal.dart';
import 'steps/step2_contact.dart';
import 'steps/step3_work.dart';
import 'steps/step4_health.dart';

class RegistrationWizard extends StatefulWidget {
  const RegistrationWizard({super.key});

  @override
  State<RegistrationWizard> createState() => _RegistrationWizardState();
}

class _RegistrationWizardState extends State<RegistrationWizard> {
  final PageController _pageController = PageController();
  final RegistrationData _registrationData = RegistrationData();
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;

  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Personal Information';
      case 1:
        return 'Contact Information';
      case 2:
        return 'Work Information';
      case 3:
        return 'Health Information';
      default:
        return 'Registration';
    }
  }

  void _nextStep() {
    // Validate current step - MUST return true to proceed
    if (_formKeys[_currentStep].currentState?.validate() != true) {
      // Show error message when validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Block progression
    }

    // Save form data
    _formKeys[_currentStep].currentState?.save();

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Save registration data locally to SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Save complete registration data as JSON
      await prefs.setString('registration_data', jsonEncode(_registrationData.toJson()));

      // Also save key fields individually for easy access
      await prefs.setString('firstName', _registrationData.firstName ?? '');
      await prefs.setString('lastName', _registrationData.lastName ?? '');
      await prefs.setString('email', _registrationData.email ?? '');
      await prefs.setString('phoneNumber', _registrationData.phoneNumber ?? '');
      await prefs.setString('address', _registrationData.address ?? '');
      await prefs.setString('union', _registrationData.union ?? '');
      await prefs.setString('firstLastName',
          '${_registrationData.firstName ?? ''} ${_registrationData.lastName ?? ''}'.trim());
      await prefs.setString('DOB', _registrationData.dateOfBirth?.toIso8601String() ?? '');
      await prefs.setString('login', _registrationData.email ?? ''); // Save email as login field

      print('Registration data saved to SharedPreferences');

      // Submit to backend API
      final flaskReg = FlaskRegUsr();
      final fullName =
          '${_registrationData.firstName ?? ''} ${_registrationData.lastName ?? ''}'.trim();
      final email = _registrationData.email ?? '';
      final dob = _registrationData.dateOfBirth != null
          ? '${_registrationData.dateOfBirth!.month.toString().padLeft(2, '0')}/${_registrationData.dateOfBirth!.day.toString().padLeft(2, '0')}/${_registrationData.dateOfBirth!.year}'
          : '';
      // Use the stored union ID from backend, or fallback to index-based mapping
      final unionId = _registrationData.unionId ??
          (RegistrationOptions.unions.indexOf(_registrationData.union ?? '') + 1);

      final result = await flaskReg.registerUserInfoWithResult(
        fullName,
        email,
        dob,
        unionId > 0 ? unionId : 1,
        gender: _registrationData.gender,
        race: _registrationData.race,
        ethnicity: _registrationData.ethnicity,
        phone: _registrationData.phoneNumber,
        address: _registrationData.address,
        workStatus: _registrationData.status,
        rank: _registrationData.rank,
        heightFeet: _registrationData.heightFeet,
        heightInches: _registrationData.heightInches,
        weight: _registrationData.weight,
        chronicConditions: _registrationData.chronicConditions.isNotEmpty
            ? _registrationData.chronicConditions
            : null,
        hasHighBloodPressure: _registrationData.hasHighBloodPressure,
        medications: _registrationData.medications,
        smokingStatus: _registrationData.smokingStatus,
        onBPMedication: _registrationData.onBPMedication,
        missedDoses: _registrationData.missedDoses,
      );

      if (!mounted) return;

      if (result.isSuccess && result.data != null && result.data['token'] != null) {
        // Store token securely
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'auth_token', value: result.data['token']);
        print('Auth token stored in secure storage');

        _registrationData.registrationStatus = RegistrationStatus.pendingApproval;
        Navigator.of(context).pushReplacementNamed('/pending-approval');
      } else {
        // Show error dialog with option to retry
        _showRegistrationErrorDialog(result);
      }
    } catch (e) {
      if (mounted) {
        _showRegistrationErrorDialog(
          ApiResult(statusCode: 0, error: e.toString(), errorType: 'unknown'),
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

  void _showRegistrationErrorDialog(ApiResult result) {
    String title = 'Registration Failed';
    String message = result.displayError;

    // Customize message based on error type
    if (result.statusCode == 409) {
      title = 'Account Already Exists';
      message = 'An account with this email address already exists. Please try logging in instead.';
    } else if (result.statusCode == 0) {
      title = 'Connection Error';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              result.statusCode == 409 ? Icons.person_outline : Icons.error_outline,
              color: AppTheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTheme.titleLarge)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppTheme.bodyLarge),
            if (result.statusCode == 0) ...[
              const SizedBox(height: 16),
              Text(
                'Please check your internet connection and try again.',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
              ),
            ],
          ],
        ),
        actions: [
          if (result.statusCode == 409)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed(
                  '/login',
                  arguments: {'email': _registrationData.email},
                );
              },
              child: const Text('Go to Login'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _submitRegistration(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: _stepTitle,
            subtitle: 'Step ${_currentStep + 1} of $_totalSteps',
            showBackButton: _currentStep > 0,
            onBackPressed: _previousStep,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacingMd,
              horizontal: AppTheme.spacingLg,
            ),
            child: StepIndicator(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Step1Personal(
                  formKey: _formKeys[0],
                  data: _registrationData,
                ),
                Step2Contact(
                  formKey: _formKeys[1],
                  data: _registrationData,
                ),
                Step3Work(
                  formKey: _formKeys[2],
                  data: _registrationData,
                ),
                Step4Health(
                  formKey: _formKeys[3],
                  data: _registrationData,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: PrimaryButton(
                        label: 'Back',
                        variant: ButtonVariant.outline,
                        onPressed: _previousStep,
                      ),
                    ),
                  if (_currentStep > 0)
                    const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    flex: _currentStep > 0 ? 2 : 1,
                    child: PrimaryButton(
                      label: _currentStep == _totalSteps - 1 ? 'Submit' : 'Next',
                      onPressed: _nextStep,
                      isLoading: _isLoading,
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
}
