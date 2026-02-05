import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/form_field.dart';
import '../models/registration_data.dart';

class Step4Health extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final RegistrationData data;

  const Step4Health({
    super.key,
    required this.formKey,
    required this.data,
  });

  @override
  State<Step4Health> createState() => _Step4HealthState();
}

class _Step4HealthState extends State<Step4Health> {
  late TextEditingController _weightController;
  late TextEditingController _otherConditionsController;
  late TextEditingController _medicationsController;
  late TextEditingController _initialsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.data.weight?.toString() ?? '',
    );
    _otherConditionsController = TextEditingController(
      text: widget.data.otherConditions ?? '',
    );
    _medicationsController = TextEditingController(
      text: widget.data.medications ?? '',
    );
    _initialsController = TextEditingController(
      text: widget.data.initials ?? '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _otherConditionsController.dispose();
    _medicationsController.dispose();
    _initialsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            // Height and Weight
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Height',
                        style: AppTheme.labelLarge,
                      ),
                      Text(
                        ' *',
                        style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: widget.data.heightFeet,
                          items: List.generate(5, (i) => i + 4).map((ft) {
                            return DropdownMenuItem<int>(
                              value: ft,
                              child: Text('$ft ft'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              widget.data.heightFeet = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Feet',
                          ),
                          validator: (value) {
                            if (value == null) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: widget.data.heightInches,
                          items: List.generate(12, (i) => i).map((inch) {
                            return DropdownMenuItem<int>(
                              value: inch,
                              child: Text('$inch in'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              widget.data.heightInches = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Inches',
                          ),
                          validator: (value) {
                            if (value == null) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppTextField(
                    label: 'Weight (lbs)',
                    required: true,
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hint: 'Enter weight in pounds',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Weight is required';
                      }
                      final weight = int.tryParse(value);
                      if (weight == null || weight < 50 || weight > 700) {
                        return 'Please enter a valid weight';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      widget.data.weight = int.tryParse(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Chronic Conditions
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCheckboxGroup(
                    label: 'Chronic Conditions',
                    required: true,
                    options: RegistrationOptions.chronicConditionOptions,
                    selectedValues: widget.data.chronicConditions,
                    onChanged: (option, selected) {
                      setState(() {
                        if (selected) {
                          if (option == 'No chronic conditions') {
                            widget.data.chronicConditions.clear();
                          } else {
                            widget.data.chronicConditions.remove('No chronic conditions');
                          }
                          widget.data.chronicConditions.add(option);
                        } else {
                          widget.data.chronicConditions.remove(option);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  AppTextField(
                    label: 'Other conditions (if applicable)',
                    controller: _otherConditionsController,
                    hint: 'List any other relevant conditions',
                    onChanged: (value) {
                      widget.data.otherConditions = value;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Blood Pressure & Medications
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppRadioGroup<bool>(
                    label: 'Do you currently have high blood pressure?',
                    required: true,
                    value: widget.data.hasHighBloodPressure,
                    options: const [true, false],
                    optionLabel: (option) => option ? 'Yes' : 'No',
                    horizontal: true,
                    onChanged: (value) {
                      setState(() {
                        widget.data.hasHighBloodPressure = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppTextField(
                    label: 'Current Medications',
                    controller: _medicationsController,
                    hint: 'List any medications you are currently taking',
                    maxLines: 2,
                    onChanged: (value) {
                      widget.data.medications = value;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppRadioGroup<String>(
                    label: 'Smoking Status',
                    required: true,
                    value: widget.data.smokingStatus,
                    options: RegistrationOptions.smokingStatuses,
                    optionLabel: (option) => option,
                    onChanged: (value) {
                      setState(() {
                        widget.data.smokingStatus = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // BP Medication
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppRadioGroup<bool>(
                    label: 'Do you currently take medication for hypertension?',
                    required: true,
                    value: widget.data.onBPMedication,
                    options: const [true, false],
                    optionLabel: (option) => option ? 'Yes' : 'No',
                    horizontal: true,
                    onChanged: (value) {
                      setState(() {
                        widget.data.onBPMedication = value;
                        if (value == false) {
                          widget.data.missedDoses = null;
                        }
                      });
                    },
                  ),
                  if (widget.data.onBPMedication == true) ...[
                    const SizedBox(height: AppTheme.spacingMd),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: AppTheme.offWhite,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'In the past 2 weeks, how many days have you missed doses of your blood pressure medication?',
                            style: AppTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          DropdownButtonFormField<int>(
                            value: widget.data.missedDoses,
                            items: List.generate(15, (i) => i).map((days) {
                              return DropdownMenuItem<int>(
                                value: days,
                                child: Text('$days days'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                widget.data.missedDoses = value;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Select number of days',
                            ),
                            validator: (value) {
                              if (widget.data.onBPMedication == true && value == null) {
                                return 'Please select number of missed doses';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Consent Section
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONSENT',
                    style: AppTheme.titleLarge.copyWith(
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.offWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      'By providing my initials and checking the box below, I agree to participate in the Hypertension Prevention Program. I understand that my health information will be shared with Mount Sinai healthcare providers to help monitor and manage my blood pressure.',
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppTextField(
                    label: 'Your Initials',
                    required: true,
                    controller: _initialsController,
                    hint: 'e.g., JD',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                      LengthLimitingTextInputFormatter(4),
                      _UpperCaseFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Initials are required';
                      }
                      if (value.length < 2) {
                        return 'Please enter at least 2 initials';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      widget.data.initials = value.toUpperCase();
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  FormField<bool>(
                    initialValue: widget.data.consentAgreed,
                    validator: (value) {
                      if (value != true) {
                        return 'You must agree to participate';
                      }
                      return null;
                    },
                    builder: (field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: widget.data.consentAgreed,
                            onChanged: (value) {
                              setState(() {
                                widget.data.consentAgreed = value ?? false;
                                field.didChange(value);
                              });
                            },
                            title: Text(
                              'I agree to participate in the Hypertension Prevention Program',
                              style: AppTheme.bodyLarge,
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (field.hasError)
                            Padding(
                              padding: const EdgeInsets.only(left: AppTheme.spacingMd),
                              child: Text(
                                field.errorText!,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.error,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
