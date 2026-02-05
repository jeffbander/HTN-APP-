import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: 'Learn',
            subtitle: 'Health Education',
            showBackButton: true,
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
                        color: AppTheme.navyBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 60,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Text(
                      'Coming Soon',
                      style: AppTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      'Educational content about blood pressure, healthy habits, and lifestyle tips will be available here soon.',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.darkGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingXl),
                    // Preview of upcoming content
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upcoming Topics',
                            style: AppTheme.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          _buildUpcomingTopic(
                            Icons.favorite,
                            'Blood Pressure Basics',
                            'Understanding your numbers',
                          ),
                          const Divider(height: AppTheme.spacingMd),
                          _buildUpcomingTopic(
                            Icons.restaurant,
                            'Heart-Healthy Diet',
                            'Foods that help lower BP',
                          ),
                          const Divider(height: AppTheme.spacingMd),
                          _buildUpcomingTopic(
                            Icons.fitness_center,
                            'Exercise & Activity',
                            'Moving for better health',
                          ),
                          const Divider(height: AppTheme.spacingMd),
                          _buildUpcomingTopic(
                            Icons.self_improvement,
                            'Stress Management',
                            'Relaxation techniques',
                          ),
                          const Divider(height: AppTheme.spacingMd),
                          _buildUpcomingTopic(
                            Icons.local_hospital,
                            'Mount Sinai Resources',
                            'Expert care information',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTopic(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: AppTheme.lightGray,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              icon,
              color: AppTheme.mediumGray,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.titleMedium.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline,
            color: AppTheme.mediumGray,
            size: 20,
          ),
        ],
      ),
    );
  }
}
