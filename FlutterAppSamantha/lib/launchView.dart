import 'dart:async';
import 'package:flutter/material.dart';
import 'msg.dart';
import 'theme/app_theme.dart';

class LaunchView extends StatefulWidget {
  final BaseMessenger messenger;
  const LaunchView(this.messenger, {super.key});

  @override
  _LaunchViewState createState() => _LaunchViewState();
}

class _LaunchViewState extends State<LaunchView> with SingleTickerProviderStateMixin {
  String loadingText = "One step today, a stronger tomorrow.";
  Timer? loadingTimer;
  double logoOpacity = 0.0;
  double logoScale = 0.8;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    print("LaunchView appeared. Starting loading...");

    // Pulse animation for loading indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    startLoadingAnimation();

    // Notify via messenger after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      print("⏱ 5 seconds passed, sending launch message");
      widget.messenger.sendMsg(
        Msg(
          taskType: TaskType.Launch,
          status: Status.started,
          sender: [ComponentType.View],
        ),
      );
    });
  }

  @override
  void dispose() {
    loadingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void startLoadingAnimation() {
    // Start logo fade-in animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          logoOpacity = 1.0;
          logoScale = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.navyGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Logo with animation
              AnimatedOpacity(
                opacity: logoOpacity,
                duration: const Duration(milliseconds: 800),
                child: AnimatedScale(
                  scale: logoScale,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'Hypertension\nPrevention Program',
                textAlign: TextAlign.center,
                style: AppTheme.headlineLarge.copyWith(
                  color: AppTheme.white,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'for First Responders',
                textAlign: TextAlign.center,
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.white.withOpacity(0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(flex: 1),

              // Loading indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _pulseAnimation.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loadingText,
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 1),

              // Version
              Text(
                'v2025.04.18',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.white.withOpacity(0.5),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom logos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Image.asset(
                  'assets/bottom.png',
                  width: screenWidth - 48,
                  height: screenHeight * 0.1,
                  fit: BoxFit.contain,
                  color: AppTheme.white.withOpacity(0.9),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
