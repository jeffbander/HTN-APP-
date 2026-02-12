import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';
import 'widgets/primary_button.dart';

class DeactivatedScreen extends StatelessWidget {
  const DeactivatedScreen({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'userId');
    await storage.delete(key: 'user_status');
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Account Deactivated',
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block,
                        size: 60,
                        color: AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      'Account Deactivated',
                      style: AppTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    AppCard(
                      child: Text(
                        'Your account has been deactivated. Please contact your care team for assistance.',
                        style: AppTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
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
                label: 'Sign Out',
                variant: ButtonVariant.outline,
                onPressed: () => _handleSignOut(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
