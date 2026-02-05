import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted || isCurrent
                    ? AppTheme.navyBlue
                    : AppTheme.lightGray,
                border: isCurrent
                    ? Border.all(color: AppTheme.navyBlue, width: 2)
                    : null,
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      size: 8,
                      color: AppTheme.white,
                    )
                  : null,
            ),
            if (index < totalSteps - 1)
              Container(
                width: 40,
                height: 2,
                color: isCompleted ? AppTheme.navyBlue : AppTheme.lightGray,
              ),
          ],
        );
      }),
    );
  }
}
