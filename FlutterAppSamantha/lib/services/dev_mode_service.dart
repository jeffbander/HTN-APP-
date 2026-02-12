import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service to track dev mode state.
/// Activated via 5-tap + tester@gmail.com mechanism in registerUsers.dart.
class DevModeService {
  DevModeService._();
  static final DevModeService instance = DevModeService._();

  static const String _key = 'dev_mode_enabled';
  bool _isDevMode = false;

  bool get isDevMode => _isDevMode;

  set isDevMode(bool value) {
    _isDevMode = value;
    _persist(value);
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDevMode = prefs.getBool(_key) ?? false;
  }

  Future<void> _persist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
