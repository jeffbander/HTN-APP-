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
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.data.email);
    _phoneController = TextEditingController(text: widget.data.phoneNumber);
    _streetController = TextEditingController(text: widget.data.streetAddress);
    _cityController = TextEditingController(text: widget.data.city);
    _zipController = TextEditingController(text: widget.data.zipCode);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
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

  String? _validateStreet(String? value) {
    if (value == null || value.isEmpty) {
      return 'Street address is required';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Please include a street number';
    }
    return null;
  }

  String? _validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'City is required';
    }
    return null;
  }

  String? _validateZip(String? value) {
    if (value == null || value.isEmpty) {
      return 'ZIP code is required';
    }
    if (!RegExp(r'^\d{5}$').hasMatch(value)) {
      return 'Please enter a valid 5-digit ZIP code';
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
                    label: 'Street Address',
                    required: true,
                    controller: _streetController,
                    hint: '123 Main St',
                    validator: _validateStreet,
                    onChanged: (value) {
                      widget.data.streetAddress = value;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppTextField(
                    label: 'City',
                    required: true,
                    controller: _cityController,
                    hint: 'New York',
                    validator: _validateCity,
                    onChanged: (value) {
                      widget.data.city = value;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppDropdown<String>(
                          label: 'State',
                          required: true,
                          value: widget.data.state,
                          items: RegistrationOptions.usStates,
                          itemLabel: (s) => s,
                          hint: 'Select...',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'State is required';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              widget.data.state = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: AppTextField(
                          label: 'ZIP Code',
                          required: true,
                          controller: _zipController,
                          hint: '10001',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          validator: _validateZip,
                          onChanged: (value) {
                            widget.data.zipCode = value;
                          },
                        ),
                      ),
                    ],
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
