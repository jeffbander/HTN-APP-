import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/form_field.dart';
import '../models/registration_data.dart';

class Step2Contact extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final RegistrationData data;

  const Step2Contact({
    super.key,
    required this.formKey,
    required this.data,
  });

  @override
  State<Step2Contact> createState() => _Step2ContactState();
}

class _Step2ContactState extends State<Step2Contact> {
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.data.email);
    _phoneController = TextEditingController(text: widget.data.phoneNumber);
    _addressController = TextEditingController(text: widget.data.address);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    // More robust email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$'
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Address is required for cuff shipping';
    }
    // Check for basic address components
    final hasNumber = RegExp(r'\d').hasMatch(value);
    final hasZip = RegExp(r'\d{5}').hasMatch(value);

    if (!hasNumber) {
      return 'Please include a street number';
    }
    if (!hasZip) {
      return 'Please include a 5-digit ZIP code';
    }
    if (value.length < 20) {
      return 'Please enter a complete address (street, city, state, zip)';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Email',
                    required: true,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'example@email.com',
                    validator: _validateEmail,
                    onChanged: (value) {
                      widget.data.email = value;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppTextField(
                    label: 'Phone Number',
                    required: true,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    hint: '(555) 555-5555',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _PhoneNumberFormatter(),
                    ],
                    validator: _validatePhone,
                    onChanged: (value) {
                      widget.data.phoneNumber = value;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Full Address',
                    required: true,
                    controller: _addressController,
                    hint: 'Street, City, State, Zip, Apt # (if applicable)',
                    maxLines: 3,
                    validator: _validateAddress,
                    onChanged: (value) {
                      widget.data.address = value;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'This address will be used for cuff shipping',
                    style: AppTheme.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String formatted = '';
    for (int i = 0; i < digits.length && i < 10; i++) {
      if (i == 0) {
        formatted += '(';
      }
      if (i == 3) {
        formatted += ') ';
      }
      if (i == 6) {
        formatted += '-';
      }
      formatted += digits[i];
    }

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
