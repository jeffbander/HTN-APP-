import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/form_field.dart';
import '../models/registration_data.dart';
import '../../flaskRegUsr.dart';

class Step3Work extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final RegistrationData data;

  const Step3Work({
    super.key,
    required this.formKey,
    required this.data,
  });

  @override
  State<Step3Work> createState() => _Step3WorkState();
}

class _Step3WorkState extends State<Step3Work> {
  final _flaskRegUsr = FlaskRegUsr();
  Map<int, String> _backendUnions = {};
  bool _isLoadingUnions = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadUnions();
  }

  Future<void> _loadUnions() async {
    try {
      final unions = await _flaskRegUsr.fetchUnions();
      if (mounted) {
        setState(() {
          if (unions.isNotEmpty) {
            _backendUnions = unions;
          }
          _isLoadingUnions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUnions = false;
          _loadFailed = true;
        });
      }
    }
  }

  List<String> get _unionOptions {
    if (_backendUnions.isNotEmpty) {
      return _backendUnions.values.toList();
    }
    return RegistrationOptions.unions;
  }

  void _onUnionSelected(String? unionName) {
    setState(() {
      widget.data.union = unionName;
      // Find the union ID from backend unions
      if (_backendUnions.isNotEmpty && unionName != null) {
        final entry = _backendUnions.entries.firstWhere(
          (e) => e.value == unionName,
          orElse: () => MapEntry(0, ''),
        );
        widget.data.unionId = entry.key > 0 ? entry.key : null;
      } else {
        // Fallback to index-based ID
        final index = RegistrationOptions.unions.indexOf(unionName ?? '');
        widget.data.unionId = index >= 0 ? index + 1 : null;
      }
      // Clear status and rank when Mount Sinai is selected
      if (unionName == 'Mount Sinai') {
        widget.data.status = null;
        widget.data.rank = null;
      }
    });
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
                  if (_isLoadingUnions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    AppRadioGroup<String>(
                      label: 'Union',
                      required: true,
                      value: widget.data.union,
                      options: _unionOptions,
                      optionLabel: (option) => option,
                      onChanged: _onUnionSelected,
                    ),
                ],
              ),
            ),
            // Only show Status and Rank if union is NOT Mount Sinai
            if (widget.data.union != 'Mount Sinai') ...[
              const SizedBox(height: AppTheme.spacingMd),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppRadioGroup<String>(
                      label: 'Status',
                      required: true,
                      value: widget.data.status,
                      options: RegistrationOptions.statuses,
                      optionLabel: (option) => option,
                      horizontal: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your status';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          widget.data.status = value;
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
                      label: 'Rank',
                      required: true,
                      value: widget.data.rank,
                      items: RegistrationOptions.ranks,
                      itemLabel: (item) => item,
                      hint: 'Select rank...',
                      onChanged: (value) {
                        setState(() {
                          widget.data.rank = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Rank is required';
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
    );
  }
}
