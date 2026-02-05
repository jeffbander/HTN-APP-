import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';

class ApprovedScreen extends StatelessWidget {
  const ApprovedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          const GradientHeader(
            title: "You're Approved!",
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  const SizedBox(height: AppTheme.spacingXl),
                  // Checkmark icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 80,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    'Congratulations!',
                    style: AppTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  AppCard(
                    child: Column(
                      children: [
                        Text(
                          'Your union representative has verified your membership.',
                          style: AppTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          'You can now set up your blood pressure monitor.',
                          style: AppTheme.bodyLarge,
                          textAlign: TextAlign.center,
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
                            color: AppTheme.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingSm),
                              Text(
                                'APPROVED',
                                style: AppTheme.labelLarge.copyWith(
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: PrimaryButton(
                label: 'Continue to Device Setup',
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
