import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool required;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffixIcon,
    this.required = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool required;
  final String? hint;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.required = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        DropdownButtonFormField<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint ?? 'Select...',
          ),
          isExpanded: true,
        ),
      ],
    );
  }
}

class AppRadioGroup<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) optionLabel;
  final void Function(T?) onChanged;
  final bool required;
  final bool horizontal;
  final String? Function(T?)? validator;

  const AppRadioGroup({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.required = false,
    this.horizontal = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<T> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: AppTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (required)
                  Text(
                    ' *',
                    style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            if (horizontal)
              Wrap(
                spacing: AppTheme.spacingMd,
                children: options.map((option) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<T>(
                        value: option,
                        groupValue: value,
                        onChanged: (val) {
                          state.didChange(val);
                          onChanged(val);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(
                        optionLabel(option),
                        style: AppTheme.bodyLarge,
                      ),
                    ],
                  );
                }).toList(),
              )
            else
              Column(
                children: options.map((option) {
                  return RadioListTile<T>(
                    value: option,
                    groupValue: value,
                    onChanged: (val) {
                      state.didChange(val);
                      onChanged(val);
                    },
                    title: Text(
                      optionLabel(option),
                      style: AppTheme.bodyLarge,
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }).toList(),
              ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: AppTheme.error, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AppCheckboxGroup extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selectedValues;
  final void Function(String, bool) onChanged;
  final bool required;

  const AppCheckboxGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        ...options.map((option) {
          return CheckboxListTile(
            value: selectedValues.contains(option),
            onChanged: (value) => onChanged(option, value ?? false),
            title: Text(
              option,
              style: AppTheme.bodyLarge,
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
  }
}

class DateDropdowns extends StatelessWidget {
  final String label;
  final int? selectedMonth;
  final int? selectedDay;
  final int? selectedYear;
  final void Function(int?) onMonthChanged;
  final void Function(int?) onDayChanged;
  final void Function(int?) onYearChanged;
  final bool required;

  const DateDropdowns({
    super.key,
    required this.label,
    required this.selectedMonth,
    required this.selectedDay,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onDayChanged,
    required this.onYearChanged,
    this.required = false,
  });

  static const List<String> months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (i) => currentYear - i);
    final days = List.generate(31, (i) => i + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (required)
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
              flex: 3,
              child: DropdownButtonFormField<int>(
                value: selectedMonth,
                isExpanded: true,
                items: List.generate(12, (i) {
                  return DropdownMenuItem<int>(
                    value: i + 1,
                    child: Text(months[i], overflow: TextOverflow.ellipsis),
                  );
                }),
                onChanged: onMonthChanged,
                decoration: const InputDecoration(
                  hintText: 'Month',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingXs),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: selectedDay,
                isExpanded: true,
                items: days.map((day) {
                  return DropdownMenuItem<int>(
                    value: day,
                    child: Text(day.toString()),
                  );
                }).toList(),
                onChanged: onDayChanged,
                decoration: const InputDecoration(
                  hintText: 'Day',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingXs),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: selectedYear,
                isExpanded: true,
                items: years.map((year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                onChanged: onYearChanged,
                decoration: const InputDecoration(
                  hintText: 'Year',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
