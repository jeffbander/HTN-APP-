import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FoodFrequencyGrid extends StatelessWidget {
  final List<String> foodCategories;
  final List<String> frequencyOptions;
  final Map<String, String> selectedValues;
  final void Function(String food, String frequency) onChanged;

  const FoodFrequencyGrid({
    super.key,
    required this.foodCategories,
    required this.frequencyOptions,
    required this.selectedValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const Expanded(
              flex: 3,
              child: SizedBox(),
            ),
            ...frequencyOptions.map((option) => Expanded(
              flex: 2,
              child: Text(
                option,
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        const Divider(height: 1),
        // Food rows
        ...foodCategories.map((food) => _buildFoodRow(food)),
      ],
    );
  }

  Widget _buildFoodRow(String food) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  food,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: 12,
                  ),
                ),
              ),
              ...frequencyOptions.map((option) => Expanded(
                flex: 2,
                child: Radio<String>(
                  value: option,
                  groupValue: selectedValues[food],
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(food, value);
                    }
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              )),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
