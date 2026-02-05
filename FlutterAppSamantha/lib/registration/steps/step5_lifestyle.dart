import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/form_field.dart';
import '../../widgets/food_grid.dart';
import '../models/registration_data.dart';
import '../../flaskRegUsr.dart';

class Step5Lifestyle extends StatefulWidget {
  final RegistrationData data;
  final VoidCallback onComplete;

  const Step5Lifestyle({
    super.key,
    required this.data,
    required this.onComplete,
  });

  @override
  State<Step5Lifestyle> createState() => _Step5LifestyleState();
}

class _Step5LifestyleState extends State<Step5Lifestyle> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  final _flaskRegUsr = FlaskRegUsr();
  bool _isLoading = false;

  String _mapFinancialStress(String? value) {
    switch (value) {
      case 'Not at all hard':
        return 'not_at_all';
      case 'Somewhat hard':
        return 'somewhat';
      case 'Very hard':
        return 'very';
      case 'Extremely hard':
        return 'extremely';
      default:
        return '';
    }
  }

  String _mapStressLevel(String? value) {
    switch (value) {
      case 'Never':
        return 'low';
      case 'Rarely':
        return 'moderate';
      case 'Sometimes':
        return 'high';
      case 'Often':
      case 'Always':
        return 'very_high';
      default:
        return '';
    }
  }

  String _mapLoneliness(String? value) {
    switch (value) {
      case 'Never':
        return 'never';
      case 'Rarely':
        return 'rarely';
      case 'Sometimes':
        return 'sometimes';
      case 'Often':
        return 'often';
      case 'Always':
        return 'always';
      default:
        return '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get stored token
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No auth token found');
      }

      // Convert food frequency map to Map<String, String>
      final foodFrequency = widget.data.foodFrequency.map(
        (key, value) => MapEntry(key, value ?? ''),
      );

      // Submit lifestyle data to backend
      final result = await _flaskRegUsr.updateLifestyleData(
        token,
        exerciseDaysPerWeek: widget.data.exerciseDaysPerWeek,
        exerciseMinutesPerSession: widget.data.exerciseMinutesPerSession,
        foodFrequency: foodFrequency,
        financialStress: _mapFinancialStress(widget.data.financialStress),
        stressLevel: _mapStressLevel(widget.data.stressLevel),
        loneliness: _mapLoneliness(widget.data.loneliness),
        sleepQuality: widget.data.sleepQuality,
      );

      if (result['status'] != 200) {
        throw Exception(result['error'] ?? 'Failed to save lifestyle data');
      }

      widget.data.lifestyleCompleted = true;
      widget.data.registrationStatus = RegistrationStatus.completed;

      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting: $e'),
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
            title: 'Complete Registration',
            subtitle: 'Lifestyle & Wellness',
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Column(
                  children: [
                    // Exercise Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXERCISE',
                            style: AppTheme.titleLarge.copyWith(
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            'In the last 30 days, on average, how many days per week did you engage in moderate exercise?',
                            style: AppTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Wrap(
                            spacing: AppTheme.spacingXs,
                            children: RegistrationOptions.exerciseDaysOptions.map((days) {
                              final isSelected = widget.data.exerciseDaysPerWeek == days;
                              return ChoiceChip(
                                label: Text('$days'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    widget.data.exerciseDaysPerWeek = days;
                                  });
                                },
                                selectedColor: AppTheme.navyBlue,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTheme.white : AppTheme.darkGray,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            'On average, how many minutes did you exercise per session?',
                            style: AppTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Wrap(
                            spacing: AppTheme.spacingXs,
                            runSpacing: AppTheme.spacingXs,
                            children: RegistrationOptions.exerciseMinutesOptions.map((mins) {
                              final isSelected = widget.data.exerciseMinutesPerSession == mins;
                              return ChoiceChip(
                                label: Text('$mins'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    widget.data.exerciseMinutesPerSession = mins;
                                  });
                                },
                                selectedColor: AppTheme.navyBlue,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTheme.white : AppTheme.darkGray,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Food Frequency Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WEEKLY FOOD SERVINGS',
                            style: AppTheme.titleLarge.copyWith(
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text(
                            'In a typical week, how many servings of the following foods do you eat?',
                            style: AppTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          FoodFrequencyGrid(
                            foodCategories: RegistrationOptions.foodCategories,
                            frequencyOptions: RegistrationOptions.foodFrequencyOptions,
                            selectedValues: widget.data.foodFrequency,
                            onChanged: (food, frequency) {
                              setState(() {
                                widget.data.foodFrequency[food] = frequency;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Wellbeing Section
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WELLBEING',
                            style: AppTheme.titleLarge.copyWith(
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          AppRadioGroup<String>(
                            label: 'How hard is it for you to pay for the very basics like food, housing, medical care, and heating?',
                            required: true,
                            value: widget.data.financialStress,
                            options: RegistrationOptions.financialStressOptions,
                            optionLabel: (option) => option,
                            onChanged: (value) {
                              setState(() {
                                widget.data.financialStress = value;
                              });
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          AppRadioGroup<String>(
                            label: 'In the past few days, how often have you experienced stress (feelings of tension, restlessness, nervousness, or anxiety)?',
                            required: true,
                            value: widget.data.stressLevel,
                            options: RegistrationOptions.stressLevelOptions,
                            optionLabel: (option) => option,
                            onChanged: (value) {
                              setState(() {
                                widget.data.stressLevel = value;
                              });
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          AppRadioGroup<String>(
                            label: 'How often do you feel lonely or isolated from those around you?',
                            required: true,
                            value: widget.data.loneliness,
                            options: RegistrationOptions.lonelinessOptions,
                            optionLabel: (option) => option,
                            onChanged: (value) {
                              setState(() {
                                widget.data.loneliness = value;
                              });
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          Text(
                            'During the past 7 days, how would you rate your sleep quality overall?',
                            style: AppTheme.labelLarge,
                          ),
                          Text(
                            ' *',
                            style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Row(
                            children: [
                              const Text('1', style: AppTheme.bodyMedium),
                              Expanded(
                                child: Slider(
                                  value: (widget.data.sleepQuality ?? 5).toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  label: widget.data.sleepQuality?.toString() ?? '5',
                                  onChanged: (value) {
                                    setState(() {
                                      widget.data.sleepQuality = value.round();
                                    });
                                  },
                                ),
                              ),
                              const Text('10', style: AppTheme.bodyMedium),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Poor',
                                style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                              ),
                              Text(
                                'Excellent',
                                style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: PrimaryButton(
                label: 'Complete Registration',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
