import 'dart:convert';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'dart:developer'; // For logging
import 'package:flutter/services.dart' show rootBundle;

class GoogleSheetsUserManager 
{
  Future<void> appendUserDataToGoogleSheets(String concatUserInfo) async 
  {
    const String serviceAccountFilePath = "assets/userServiceAccount.json";
    final serviceAccountJson = await rootBundle.loadString(serviceAccountFilePath);
    final credentials = ServiceAccountCredentials.fromJson(json.decode(serviceAccountJson));
    const List<String> scopes = [SheetsApi.spreadsheetsScope];
    final authClient = await clientViaServiceAccount(credentials, scopes);
    final sheetsApi = SheetsApi(authClient);
    const String spreadsheetId = "1-V1Im0uOmA9dtCNWV7jIhmxZDYTw_WjnVgMLqWPHkdw";
    const String range = "Sheet1!A1";

    try {
      List<List<String>> userData = [[concatUserInfo]];
      final ValueRange valueRange = ValueRange(values: userData);
      
      await sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: "USER_ENTERED",
      );
      
      log("User data appended successfully!");
    } catch (e) {
      log("Error appending user data to Google Sheets: $e");
    }
  }
}
