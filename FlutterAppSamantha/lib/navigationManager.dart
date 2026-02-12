import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'launchView.dart';
import 'measurementView.dart';
import 'registerDevices.dart';
import 'registerUsers.dart';
import 'syncView.dart';
import 'sourceManager.dart';
import 'idleMeasureView.dart';
import 'msg.dart';
import 'registration/registration_wizard.dart';
import 'devices/device_selection_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'deactivated_screen.dart';
import 'registration/pending_approval_screen.dart';
import 'devices/cuff_request_pending_screen.dart';
import 'flaskRegUsr.dart';
import 'services/biometric_service.dart';
import 'utils/status_router.dart';

enum _AuthResult { authenticated, needsLogin, noToken }

enum ViewType {
  launch,
  registerUser,
  registerUserNew, // New registration wizard
  registerDevice,
  deviceSelection, // New device selection
  startMeasurement,
  deviceInfo,
  measurement,
  pairingView,
  idleMeasurement,
  helpView,
  logView,
  syncView,
  updateScreen,
  loginView,
  profileView,
  startMeasurementSubBP,
}

//------------------------------------------------------
// NavigationManager
//------------------------------------------------------
class NavigationManager extends ChangeNotifier {
  final ValueNotifier<ViewType> currentView = ValueNotifier(ViewType.launch);
  Widget? _currentViewW;

  late final SourceManager sourceManager;
  final List<BaseMessenger> messengers = [];
  final BaseMessenger backendMessenger = BaseMessenger();
  final BaseMessenger uiMessenger = BaseMessenger();

  List<List<dynamic>> supportDeviceInfo = [];
  bool inPairing = false;
  String userStatus = 'active';

  FlaskRegUsr _makeApi() => FlaskRegUsr();

  //------------------------------------------------------
  NavigationManager(this.sourceManager) {
    initSupportedDeviceInfo();

    // Share messenger with sourceManager
    sourceManager.registerUIMessenger(backendMessenger);

    // Listen for messages from sourceManager
    backendMessenger.statusSignalStream.listen((msg) async {
      await handleMsgStatus(msg);
    });

    // Listen for messages from UI
    uiMessenger.statusSignalStream.listen((msg) async {
      await handleMsgStatus(msg);
    });

    _currentViewW = LaunchView(uiMessenger);
  }

  //------------------------------------------------------
  void initSupportedDeviceInfo() {
    for (var deviceModel in DeviceModel.values) {
      switch (deviceModel) {
        case DeviceModel.Omron:
          supportDeviceInfo.add([deviceModel, "BP7000", "assets/omronLogo.png"]);
          break;
        case DeviceModel.Omron3Series:
          supportDeviceInfo.add([deviceModel, "Omron 3 Series", "assets/omronLogo.png"]);
          break;
        case DeviceModel.Omron5Series:
          supportDeviceInfo.add([deviceModel, "Omron 5 Series", "assets/omronLogo.png"]);
          break;
        case DeviceModel.Transtek:
          supportDeviceInfo.add([deviceModel, "TMB-2296-BT", "assets/TranstekLogo.png"]);
          break;
        case DeviceModel.NoCuff:
          supportDeviceInfo.add([deviceModel, "NoDevice", ""]);
          break;
        default:
          break;
      }
    }
  }

  //------------------------------------------------------
  Future<void> startLoggers(int logLevel) async {
    messengers.addAll([uiMessenger, backendMessenger, sourceManager.bluetoothMessenger]);

    for (var messenger in messengers) {
      await messenger.sendMsg('Logging at level $logLevel' as Msg);
    }
  }

  //------------------------------------------------------
  Future<void> delay(int seconds) async {
    await Future.delayed(Duration(seconds: seconds));
  }

  //------------------------------------------------------
  Widget get currentViewW => _currentViewW!;

  //------------------------------------------------------
  /// Show the appropriate screen based on user_status (for non-measurement statuses)
  void _showStatusScreen(String status) {
    switch (status) {
      case 'pending_approval':
      case 'enrollment_only':
        _currentViewW = const PendingApprovalScreen();
        break;
      case 'pending_cuff':
        _currentViewW = const CuffRequestPendingScreen();
        break;
      case 'deactivated':
        _currentViewW = const DeactivatedScreen();
        break;
      default:
        _currentViewW = const LoginScreen();
        break;
    }
    notifyListeners();
  }

  //------------------------------------------------------
  /// Called after device pairing or cuff request to show the measurement view
  void showMeasurementView() {
    currentView.value = ViewType.startMeasurement;
    _currentViewW = StartMeasurementView(
      key: const Key("start_measurement_view_after_pairing"),
      messenger: uiMessenger,
      recentMeasurements: sourceManager.sharedMeasurements,
    );
    notifyListeners();
  }

  //------------------------------------------------------
  /// Check auth state on launch: token existence, expiry, biometric
  Future<_AuthResult> _checkAuthOnLaunch() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    if (token == null) {
      return _AuthResult.noToken;
    }

    // Check if token is expired by decoding JWT payload
    try {
      final parts = token.split('.');
      if (parts.length != 3) return _AuthResult.needsLogin;

      // Decode base64url payload
      String payload = parts[1];
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '='; break;
      }
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64Decode(normalized));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;

      final exp = payloadMap['exp'] as int?;
      if (exp != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (exp < now) {
          return _AuthResult.needsLogin; // Token expired
        }
      }
    } catch (e) {
      log('Token decode error: $e');
      // If we can't decode, try biometric anyway
    }

    // Token exists and not expired — try biometric
    final biometricSuccess = await BiometricService.authenticate();
    if (biometricSuccess) {
      return _AuthResult.authenticated;
    } else {
      return _AuthResult.needsLogin;
    }
  }

  //------------------------------------------------------
  Future<void> navigate(ViewType view) async {
    // Allow re-navigation to idleMeasurement even if it's the current state
    // (user may have pressed back button instead of Cancel, leaving state stale)
    if (view == currentView.value && view != ViewType.idleMeasurement) return;

    currentView.value = view;

    switch (view) {
      case ViewType.launch:
        _currentViewW = LaunchView(uiMessenger);
        break;

      case ViewType.loginView:
        _currentViewW = const LoginScreen();
        break;

      case ViewType.profileView:
        _currentViewW = ProfileScreen(messenger: uiMessenger);
        break;

      case ViewType.idleMeasurement:
        _currentViewW = IdleMeasureView(uiMessenger);
        break;

      case ViewType.updateScreen:
        _currentViewW = UpdateScreen(uiMessenger);
        break;

      case ViewType.registerUser:
        // Use new registration wizard instead of old form
        _currentViewW = const RegistrationWizard();
        print("🔹 NavigationManager: Showing new RegistrationWizard");
        break;

      case ViewType.registerUserNew:
        _currentViewW = const RegistrationWizard();
        break;

      case ViewType.deviceSelection:
        _currentViewW = const DeviceSelectionScreen();
        break;

      case ViewType.registerDevice:
        _currentViewW = RegisterDeviceView(
          key: const Key("register_device_view"),
          messenger: uiMessenger,
          initialDeviceId: sourceManager.curDeviceID,
          supportedSources: supportDeviceInfo,
        );
        break;

      case ViewType.startMeasurement:
        _currentViewW = StartMeasurementView(
          key: const Key("register_start_measurement_view"),
          messenger: uiMessenger,
          recentMeasurements: sourceManager.sharedMeasurements,
        );
        break;

      case ViewType.measurement:
        _currentViewW = MeasurementView(
          messenger: uiMessenger,
          lastMeasurement: sourceManager.latestMeasurement,
        );
        break;

      case ViewType.syncView:
        _currentViewW = SyncView(uiMessenger);
        break;

      default:
        throw Exception('Unhandled ViewType: $view');
    }

    notifyListeners();
  }

  //------------------------------------------------------
  Future<void> measurementUpdated(
    DateTime timestamp,
    List<Map<DateTime, List<int>>> measurement,
    bool isFinalUpdate,
  ) async {
    Status status = isFinalUpdate ? Status.finished : Status.update;

    await uiMessenger.sendMsg(Msg(
      taskType: TaskType.Measure,
      status: status,
      sender: [ComponentType.SourceManager],
      date: timestamp,
      measurement: measurement,
    ));
  }

  //------------------------------------------------------
  Future<void> handleMsgStatus(Msg msg) async {
    if (msg.sender.last == ComponentType.NavigationManager) return;

    switch (msg.taskType) {
      case TaskType.Launch:
        if (msg.status == Status.started && msg.sender.contains(ComponentType.View))
        {
          // Check for existing token and biometric auth
          final authResult = await _checkAuthOnLaunch();
          if (authResult == _AuthResult.authenticated) {
            // Load saved user status and route accordingly
            const storage = FlutterSecureStorage();
            final savedStatus = await storage.read(key: 'user_status');
            userStatus = savedStatus ?? 'active';

            // Fetch fresh status from profile if we have a token
            final token = await storage.read(key: 'auth_token');
            if (token != null) {
              try {
                final api = _makeApi();
                final profile = await api.getProfile(token);
                if (profile != null && profile['user_status'] != null) {
                  userStatus = profile['user_status'];
                  await storage.write(key: 'user_status', value: userStatus);
                }
              } catch (_) {
                // Use cached status if profile fetch fails
              }
            }

            final route = StatusRouter.routeForStatus(userStatus);
            if (route == '/measurement') {
              if (sourceManager.needsDeviceInfo()) {
                await navigate(ViewType.registerDevice);
              } else {
                await navigate(ViewType.startMeasurement);
              }
            } else {
              // Show the status-appropriate screen directly
              _showStatusScreen(userStatus);
            }
          } else if (authResult == _AuthResult.needsLogin) {
            // Has token but biometric failed, or token expired
            await navigate(ViewType.loginView);
          } else {
            // No token at all
            if (sourceManager.needsUserInfo()) {
              await navigate(ViewType.loginView);
            } else if (sourceManager.needsDeviceInfo()) {
              await navigate(ViewType.registerDevice);
            } else {
              await navigate(ViewType.startMeasurement);
            }
          }
        }
        break;

      case TaskType.auth:
        if (msg.status == Status.succeeded) {
          await navigate(ViewType.startMeasurement);
        } else if (msg.status == Status.failed) {
          if (sourceManager.needsUserInfo()) {
            await navigate(ViewType.registerUser);
          } else if (sourceManager.needsDeviceInfo()) {
            await navigate(ViewType.registerDevice);
          }
        }
        break;

      case TaskType.RegisterUserInfo:
        if (msg.status == Status.update && msg.sender.last == ComponentType.View) {
          await sourceManager.registerUserInfo(msg.strData);
          await sourceManager.startTokenLogin();
        } else if (msg.status == Status.request && msg.sender.last == ComponentType.View) {
          await navigate(ViewType.registerUser);
        }
        break;

      case TaskType.RegisterDeviceInfo:
        if (msg.status == Status.update && msg.sender.last == ComponentType.View) {
          await sourceManager.registerDeviceInfo(msg.deviceModel, msg.strData[0]);
          await navigate(ViewType.startMeasurement);
        } else if (msg.status == Status.request && msg.sender.last == ComponentType.View) {
          await navigate(ViewType.registerDevice);
        }
        break;

      case TaskType.ShowStartMeasurementView:
        await navigate(ViewType.startMeasurement);
        break;

      case TaskType.Pair:
        if (msg.status == Status.request) {
          await sourceManager.startPairing();
        } else if (msg.status == Status.cancel) {
          inPairing = false;
          await sourceManager.cancelPairing();
        } else if (msg.status == Status.succeeded) {
          await navigate(ViewType.startMeasurement);
        }
        break;

      case TaskType.DisconnectPeripheralFor:
        if (msg.status == Status.succeeded && inPairing) {
          await navigate(ViewType.startMeasurement);
        }
        break;

      case TaskType.Connect:
        if (msg.status == Status.request) {
          await sourceManager.startScanning();
        } else if (msg.status == Status.cancel) {
          await sourceManager.bluetoothManager.stopScan();
        } else {
          uiMessenger.forwardMsg([ComponentType.NavigationManager], msg);
        }
        break;

      case TaskType.Measure:
        if (msg.status == Status.request && msg.sender.last == ComponentType.View) {
          await sourceManager.startMeasurement();
        } else if (msg.status == Status.finished && msg.sender.last == ComponentType.View) {
          await navigate(ViewType.startMeasurement);
        } else if (msg.status == Status.cancel && msg.sender.last == ComponentType.View) {
          await navigate(ViewType.startMeasurement);
        } else if (msg.status == Status.finished && msg.sender.last == ComponentType.SourceManager) {
          // Skip UpdateScreen - go directly to MeasurementView
          await navigate(ViewType.measurement);
        } else if (msg.status == Status.failed && msg.sender.last == ComponentType.SourceManager) {
          // Navigate back to StartMeasurementView BEFORE forwarding the error
          // so the user isn't stuck on IdleMeasureView
          await navigate(ViewType.startMeasurement);
          await Future.delayed(const Duration(milliseconds: 300));
          uiMessenger.forwardMsg([ComponentType.NavigationManager], msg);
        }
        break;

      case TaskType.Idle:
        if (msg.status == Status.request && msg.sender.last == ComponentType.SourceManager) {
          await navigate(ViewType.idleMeasurement);
        } else if (msg.status == Status.cancel && msg.sender.last == ComponentType.View) {
          // Reset currentView to ensure navigation isn't blocked by stale state
          currentView.value = ViewType.idleMeasurement;
          await navigate(ViewType.startMeasurement);
          await sourceManager.cancelPairing();
        } else if (msg.status == Status.finished && msg.sender.last == ComponentType.View) {
          await navigate(ViewType.measurement);
        } else if (msg.status == Status.update && msg.sender.last == ComponentType.View) {
          await navigate(ViewType.updateScreen);
        }
        break;

      case TaskType.Sync:
        if (msg.status == Status.request && msg.sender.last == ComponentType.View) {
          await sourceManager.startScanning();
        } else if (msg.status == Status.finished && msg.sender.last == ComponentType.View) {
          await navigate(ViewType.startMeasurement);
        }
        break;

      case TaskType.FetchDeviceInfo:
        if (msg.status == Status.request && msg.sender.contains(ComponentType.View)) {
          await sourceManager.fetchDeviceInfo(sourceManager.curDeviceModel);
        }
        break;

      case TaskType.FetchUnionInfo: 
        // log("union info recieved in navmanager");
        log(msg.sender.toString()); 
        if (msg.sender.last == ComponentType.SourceManager)
        {
          log("union info recieved in navmanager "); 
          uiMessenger.forwardMsg([ComponentType.NavigationManager], msg);
        }

      default:
        break;
    }

    if (msg.sender.last != ComponentType.View) {
      await uiMessenger.forwardMsg([ComponentType.NavigationManager], msg);
    }
  }
}
