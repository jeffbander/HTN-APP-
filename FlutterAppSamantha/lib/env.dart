import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:developer' as dev;

class Environment {
  /// Uses Flutter's compile-time constant: true in debug builds, false in release.
  static const bool isDev = kDebugMode;

  static String? _runtimeIp;
  static bool _loaded = false;

  /// Load saved IP at app startup
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeIp = prefs.getString("dev_ip");
    _loaded = true;
    dev.log('[Environment] Loaded. Runtime IP: $_runtimeIp');
    dev.log('[Environment] Base URL will be: $baseUrl');
  }

  /// Save IP from Dev Mode
  static Future<void> setDevIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("dev_ip", ip);
    _runtimeIp = ip;
    dev.log('[Environment] Dev IP set to: $ip');
    dev.log('[Environment] Base URL is now: $baseUrl');
  }

  /// Clear any stored runtime IP (useful for resetting to default)
  static Future<void> clearDevIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("dev_ip");
    _runtimeIp = null;
    dev.log('[Environment] Dev IP cleared. Base URL reset to: $baseUrl');
  }

  /// Your BASE URL (now dynamic)
  /// Default: http://127.0.0.1:3002 for local development
  /// Set via setDevIp() for iPhone testing with Mac's IP
  static String get baseUrl {
    String url;
    if (isDev) {
      if (_runtimeIp?.isNotEmpty == true) {
        // Check if runtime IP already includes port
        if (_runtimeIp!.contains(':')) {
          url = "https://$_runtimeIp";
        } else {
          url = "https://$_runtimeIp:3001";
        }
        dev.log('[Environment] Using runtime IP: $_runtimeIp');
      } else {
        url = "https://10.141.18.84:3001"; // Local Flask dev server (Mac IP for phone testing)
        dev.log('[Environment] Using default localhost URL');
      }
    } else {
      url = "https://production.server.com";
      dev.log('[Environment] Using production URL');
    }
    dev.log('[Environment] baseUrl: $url');
    return url;
  }

  // ✅ REMOVED: apiPort no longer needed - Nginx handles routing on 443/80
  // static int get apiPort {
  //   return isDev ? 3001 : 443;
  // }

  /// ✅ Consumer API URL (routed through Nginx)
  static String consumerApiUrl([String path = ""]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return "$baseUrl/consumer${normalizedPath.isNotEmpty ? '/$normalizedPath' : ''}";
  }

  /// ✅ Admin API URL (if needed from mobile app)
  static String adminApiUrl([String path = ""]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return "$baseUrl/admin${normalizedPath.isNotEmpty ? '/$normalizedPath' : ''}";
  }

  /// ✅ Generic API URL (legacy support - defaults to consumer)
  static String apiUrl([String path = ""]) {
    return consumerApiUrl(path);
  }

  /// Remote backend URL
  static String remoteApiUrl([String path = ""]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return "https://34.55.98.226:3001/consumer${normalizedPath.isNotEmpty ? '/$normalizedPath' : ''}";
  }
}