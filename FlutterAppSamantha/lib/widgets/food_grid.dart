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
        ...foodCategories.map((food) => _buildFoodItem(food)),
      ],
    );
  }

  Widget _buildFoodItem(String food) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: frequencyOptions.map((option) {
              final isSelected = selectedValues[food] == option;
              return GestureDetector(
                onTap: () => onChanged(food, option),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
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
                    Text(
                      option,
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 12,
                        color: isSelected ? AppTheme.navyBlue : AppTheme.darkGray,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
