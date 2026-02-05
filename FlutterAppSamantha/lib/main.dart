import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sourceManager.dart';
import 'navigationManager.dart';
import 'env.dart';
import 'theme/app_theme.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'registration/registration_wizard.dart';
import 'registration/pending_approval_screen.dart';
import 'registration/approved_screen.dart';
import 'registration/steps/step5_lifestyle.dart';
import 'registration/models/registration_data.dart';
import 'devices/device_selection_screen.dart';
import 'devices/cuff_request_pending_screen.dart';
import 'devices/pairing_screen.dart';
import 'login_screen.dart';
import 'mfa_verify_screen.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'helpView.dart';
import 'reminders_screen.dart';
import 'education_screen.dart';
import 'deviceInfoView.dart';
import 'historyView.dart';
import 'msg.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("App running in ${Environment.isDev ? 'DEV' : 'PROD'} mode");
  print("API URL: ${Environment.apiUrl()}");

  // Initialize sync service for offline queue
  await SyncService.instance.initialize();

  // Initialize notification service (stub until Firebase is configured)
  try {
    await NotificationService.instance.initialize();
    print("NotificationService initialized");
  } catch (e) {
    print("NotificationService initialization failed: $e");
  }

  final sourceManager = SourceManager.shared;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NavigationManager(sourceManager),
        ),
        ChangeNotifierProvider.value(
          value: SyncService.instance,
        ),
        ChangeNotifierProvider.value(
          value: NotificationService.instance,
        ),
      ],
      child: MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hypertension Prevention',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Allow text scaling between 80% and 140% for accessibility
        final mediaQuery = MediaQuery.of(context);
        final scale = mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.4);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
      home: Consumer<NavigationManager>(
        builder: (context, navigationManager, _) {
          return navigationManager.currentViewW;
        },
      ),
      routes: {
        '/registration': (context) => const RegistrationWizard(),
        '/pending-approval': (context) => const PendingApprovalScreen(),
        '/approved': (context) => const ApprovedScreen(),
        '/device-selection': (context) => const DeviceSelectionScreen(),
        '/pairing': (context) => const PairingScreen(),
        '/cuff-request-pending': (context) => const CuffRequestPendingScreen(),
        '/profile': (context) => Consumer<NavigationManager>(
          builder: (context, navigationManager, _) {
            return ProfileScreen(messenger: navigationManager.uiMessenger);
          },
        ),
        '/home': (context) => Consumer<NavigationManager>(
          builder: (context, navigationManager, _) {
            return HomeScreen(messenger: navigationManager.uiMessenger);
          },
        ),
        '/help': (context) => const HelpView(),
        '/reminders': (context) => const RemindersScreen(),
        '/education': (context) => const EducationScreen(),
        '/device-info': (context) => const DeviceInfoView(),
      },
      onGenerateRoute: (settings) {
        // Handle routes with arguments
        if (settings.name == '/mfa-verify') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) return null;
          return MaterialPageRoute(
            builder: (context) => MfaVerifyScreen(
              mfaSessionToken: args['mfa_session_token'] as String,
              mfaType: args['mfa_type'] as String? ?? 'email',
              email: args['email'] as String? ?? '',
            ),
          );
        }
        if (settings.name == '/login') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => LoginScreen(
              prefillEmail: args?['email'],
            ),
          );
        }
        if (settings.name == '/lifestyle') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => Step5Lifestyle(
              data: args?['data'] ?? RegistrationData(),
              onComplete: args?['onComplete'] ?? () {
                // Default behavior: go back to measurement view after completing lifestyle questionnaire
                final navManager = Provider.of<NavigationManager>(context, listen: false);
                navManager.showMeasurementView();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          );
        }
        if (settings.name == '/cuff-request-pending-with-address') {
          final address = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => CuffRequestPendingScreen(address: address),
          );
        }
        return null;
      },
    );
  }
}
