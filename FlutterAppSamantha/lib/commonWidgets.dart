import 'package:flutter/material.dart';
import 'msg.dart';
import 'theme/app_theme.dart';

class HeaderView extends StatelessWidget {
  final BaseMessenger? messenger;
  final String? title;
  final VoidCallback? onToggleLogVisibility;

  const HeaderView({
    super.key,
    this.messenger,
    this.title,
    this.onToggleLogVisibility,
    required Null Function() onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.darkGray,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: AppTheme.accentGreen),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            onSelected: (value) {
              switch (value) {
                case 'RegisterUser':
                  Msg msg = Msg(
                      taskType: TaskType.RegisterUserInfo,
                      status: Status.request,
                      sender: [ComponentType.View]);
                  messenger?.sendMsg(msg);
                  break;
                case 'RegisterDevice':
                  Msg msg = Msg(
                      taskType: TaskType.RegisterDeviceInfo,
                      status: Status.request,
                      sender: [ComponentType.View]);
                  messenger?.sendMsg(msg);
                  break;
                case 'StartMeasurement':
                  Msg msg = Msg(
                      taskType: TaskType.ShowStartMeasurementView,
                      status: Status.request,
                      sender: [ComponentType.View]);
                  messenger?.sendMsg(msg);
                  break;
                default:
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'RegisterUser',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: AppTheme.navyBlue, size: 20),
                    const SizedBox(width: AppTheme.spacingSm),
                    Text('Register User', style: AppTheme.bodyMedium),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'RegisterDevice',
                child: Row(
                  children: [
                    Icon(Icons.bluetooth, color: AppTheme.navyBlue, size: 20),
                    const SizedBox(width: AppTheme.spacingSm),
                    Text('Register/Pair Device', style: AppTheme.bodyMedium),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'StartMeasurement',
                child: Row(
                  children: [
                    Icon(Icons.favorite_outline, color: AppTheme.navyBlue, size: 20),
                    const SizedBox(width: AppTheme.spacingSm),
                    Text('Start Measurement', style: AppTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomAlertView extends StatelessWidget {
  final bool isVisible;
  final String imageAsset;
  final String message;
  final VoidCallback onClose;

  const CustomAlertView({
    super.key,
    required this.isVisible,
    required this.imageAsset,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Center(
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.navyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Image.asset(
                  imageAsset,
                  width: 150,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTheme.bodyLarge,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navyBlue,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: AppTheme.labelLarge.copyWith(color: AppTheme.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomTextFieldStyle extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const CustomTextFieldStyle({
    super.key,
    required this.hintText,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTheme.bodyLarge.copyWith(color: AppTheme.mediumGray),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingMd,
        ),
        filled: true,
        fillColor: AppTheme.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.navyBlue, width: 2),
        ),
      ),
    );
  }
}

class CustomClearableTextField extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;

  const CustomClearableTextField({
    super.key,
    required this.placeholder,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: AppTheme.bodyLarge.copyWith(color: AppTheme.mediumGray),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingMd,
        ),
        filled: true,
        fillColor: AppTheme.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.navyBlue, width: 2),
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.mediumGray),
                onPressed: () {
                  controller.clear();
                },
              )
            : null,
      ),
    );
  }
}
