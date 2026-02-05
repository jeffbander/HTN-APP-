import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ButtonVariant { green, navy, outline }

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool fullWidth;
  final ButtonVariant variant;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.fullWidth = true,
    this.variant = ButtonVariant.green,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (variant) {
      ButtonVariant.green => AppTheme.accentGreen,
      ButtonVariant.navy => AppTheme.navyBlue,
      ButtonVariant.outline => Colors.transparent,
    };

    final foregroundColor = switch (variant) {
      ButtonVariant.green => AppTheme.white,
      ButtonVariant.navy => AppTheme.white,
      ButtonVariant.outline => AppTheme.navyBlue,
    };

    final borderSide = variant == ButtonVariant.outline
        ? const BorderSide(color: AppTheme.navyBlue, width: 2)
        : BorderSide.none;

    Widget buttonChild = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppTheme.spacingSm),
              ],
              Text(label),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: borderSide,
          ),
        ),
        child: buttonChild,
      ),
    );
  }
}

class StartButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? subtitle;
  final String label;
  final bool isActive;

  const StartButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.subtitle,
    this.label = 'START',
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use green gradient when active, faded green when inactive/cancel
    final gradient = isActive
        ? AppTheme.greenGradient
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accentGreen.withOpacity(0.6),
              AppTheme.accentGreenDark.withOpacity(0.6),
            ],
          );

    final shadow = isActive ? AppTheme.greenGlow : <BoxShadow>[];

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: shadow,
        ),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: AppTheme.buttonTextLarge.copyWith(
                        fontSize: 28,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.spacingXs),
                      Text(
                        subtitle!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
