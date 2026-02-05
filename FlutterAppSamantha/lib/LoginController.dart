// // login_controller.dart
// import 'package:flutter_appauth/flutter_appauth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'msg.dart' as msglib;

// /// Handles OAuth login logic using flutter_appauth.
// class LoginController {
//   final FlutterAppAuth _appAuth = FlutterAppAuth();
//   final msglib.BaseMessenger messenger;

//   // --- Configurable OAuth provider ---
//   final String clientId;
//   final String redirectUrl;
//   final List<String> scopes;
//   final String authorizationEndpoint;
//   final String tokenEndpoint;
//   final List<String> promptValues;

//   LoginController(
//     this.messenger, {
//     required this.clientId,
//     required this.redirectUrl,
//     required this.scopes,
//     required this.authorizationEndpoint,
//     required this.tokenEndpoint,
//     required this.promptValues,
//   }) {
//     print('🔹 LoginController initialized with clientId: $clientId');
//     print('RedirectUrl: $redirectUrl');
//     print('Scopes: $scopes');
//     print('AuthorizationEndpoint: $authorizationEndpoint');
//     print('TokenEndpoint: $tokenEndpoint');
//     print('Prompt values: $promptValues');
//   }

//   /// Attempts to log in with OAuth and exchange code for tokens.
//   /// Returns an [AuthorizationTokenResponse] if successful, or `null` if failed.
//   Future<AuthorizationTokenResponse?> login() async {
//     print('🔹 Login started...');
//     print('ClientId: $clientId');
//     print('RedirectUrl: $redirectUrl');
//     print('Scopes: $scopes');

//     try {
//       // Clear cached tokens in shared preferences
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.clear();
//       print('🔹 Cleared SharedPreferences to force account chooser.');

//       print('🔹 Creating AuthorizationTokenRequest...');
//       final authRequest = AuthorizationTokenRequest(
//         clientId,
//         redirectUrl,
//         scopes: scopes,
//         serviceConfiguration: AuthorizationServiceConfiguration(
//           authorizationEndpoint: authorizationEndpoint,
//           tokenEndpoint: tokenEndpoint,
//         ),
//         // Force Google to always show the account chooser
//         promptValues: promptValues,
//       );

//       print('🔹 AuthorizationTokenRequest created:');
//       print('clientId=${authRequest.clientId}');
//       print('redirectUrl=${authRequest.redirectUrl}');
//       print('scopes=${authRequest.scopes}');
//       print('authorizationEndpoint=${authRequest.serviceConfiguration?.authorizationEndpoint}');
//       print('tokenEndpoint=${authRequest.serviceConfiguration?.tokenEndpoint}');
//       print('promptValues=${authRequest.promptValues}');

//       print('🔹 Sending request to authorizeAndExchangeCode...');
//       final result = await _appAuth.authorizeAndExchangeCode(authRequest);

//       if (result != null) {
//         print('✅ Authorization code exchange completed!');
//         print('Access token: ${result.accessToken}');
//         print('ID token: ${result.idToken}');
//         print('Token type: ${result.tokenType}');
//         print('Refresh token: ${result.refreshToken}');
//         print('Expiration: ${result.accessTokenExpirationDateTime}');
//       } else {
//         print('⚠️ No token returned!');
//       }

//       // Notify success via messenger
//       await messenger.sendMsg(
//         msglib.Msg(
//           deviceType: msglib.DeviceType.db,
//           taskType: msglib.TaskType.auth,
//           status: msglib.Status.succeeded,
//           sender: [msglib.ComponentType.Source],
//         ),
//       );

//       return result;
//     } catch (e, stackTrace) {
//       print('❌ Login failed with error: $e');
//       print('Stack trace: $stackTrace');
//       print('⚠️ Please verify your clientId, redirectUri, scopes, and endpoints.');

//       // Notify failure
//       await messenger.sendMsg(
//         msglib.Msg(
//           deviceType: msglib.DeviceType.db,
//           taskType: msglib.TaskType.auth,
//           status: msglib.Status.failed,
//           sender: [msglib.ComponentType.Source],
//         ),
//       );

//       return null;
//     }
//   }
// }
