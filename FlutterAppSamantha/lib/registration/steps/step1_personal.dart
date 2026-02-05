import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/form_field.dart';
import '../models/registration_data.dart';

class Step1Personal extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final RegistrationData data;

  const Step1Personal({
    super.key,
    required this.formKey,
    required this.data,
  });

  @override
  State<Step1Personal> createState() => _Step1PersonalState();
}

class _Step1PersonalState extends State<Step1Personal> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.data.firstName);
    _lastNameController = TextEditingController(text: widget.data.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'First Name',
                    required: true,
                    controller: _firstNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      widget.data.firstName = value;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppTextField(
                    label: 'Last Name',
                    required: true,
                    controller: _lastNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      widget.data.lastName = value;
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
                  DateDropdowns(
                    label: 'Date of Birth',
                    required: true,
                    selectedMonth: widget.data.birthMonth,
                    selectedDay: widget.data.birthDay,
                    selectedYear: widget.data.birthYear,
                    onMonthChanged: (value) {
                      setState(() {
                        widget.data.birthMonth = value;
                      });
                    },
                    onDayChanged: (value) {
                      setState(() {
                        widget.data.birthDay = value;
                      });
                    },
                    onYearChanged: (value) {
                      setState(() {
                        widget.data.birthYear = value;
                      });
                    },
                  ),
                  // Hidden FormField to validate age on form submission
                  FormField<bool>(
                    initialValue: true,
                    validator: (_) {
                      if (widget.data.birthMonth == null ||
                          widget.data.birthDay == null ||
                          widget.data.birthYear == null) {
                        return 'Date of birth is required';
                      }
                      if (widget.data.age != null && widget.data.age! < 18) {
                        return 'You must be at least 18 years old';
                      }
                      return null;
                    },
                    builder: (state) {
                      if (state.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                          child: Text(
                            state.errorText!,
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.error),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
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
                  AppRadioGroup<String>(
                    label: 'Gender',
                    required: true,
                    value: widget.data.gender,
                    options: RegistrationOptions.genders,
                    optionLabel: (option) => option,
                    onChanged: (value) {
                      setState(() {
                        widget.data.gender = value;
                      });
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
                  AppDropdown<String>(
                    label: 'Race',
                    required: true,
                    value: widget.data.race,
                    items: RegistrationOptions.races,
                    itemLabel: (item) => item,
                    hint: 'Select race...',
                    onChanged: (value) {
                      setState(() {
                        widget.data.race = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Race is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  AppRadioGroup<String>(
                    label: 'Ethnicity',
                    required: true,
                    value: widget.data.ethnicity,
                    options: RegistrationOptions.ethnicities,
                    optionLabel: (option) => option,
                    onChanged: (value) {
                      setState(() {
                        widget.data.ethnicity = value;
                      });
                    },
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
