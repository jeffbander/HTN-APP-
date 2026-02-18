import 'dart:convert';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'dart:developer' as dev; // For logging
import 'package:flutter/services.dart' show rootBundle;
import 'bloodPressureData.dart';

class GoogleSheetsManager 
{
  Future<void> appendDataToGoogleSheets(String concatUserInfo, 
                                     String deviceId,
                                     List<Map<DateTime, List<String>>> bloodPressureData) async 
  {
    const String serviceAccountFilePath = "assets/service-account.json";
    final serviceAccountJson = await rootBundle.loadString(serviceAccountFilePath);
    final credentials = ServiceAccountCredentials.fromJson(json.decode(serviceAccountJson));
    const List<String> scopes = [SheetsApi.spreadsheetsScope];
    final authClient = await clientViaServiceAccount(credentials, scopes);
    final sheetsApi = SheetsApi(authClient);
    const String spreadsheetId = "130HqUBAjr1O6gOn9VrNP7kBTQPz6ACIUins6R2AgvUs";
    const String range = "Sheet1!A1";

    try {
      String scrambledName = scrambleName(concatUserInfo);
      List<List<String>> cookedData = BloodPressureParser.processBloodPressureData(
        bloodPressureData.cast<Map<DateTime, List<int>>>(), scrambledName, deviceId
      );

      List<List<String>> reorderedData = cookedData.map((row) 
      {
        if (row.length >= 3) 
        {
          return [row[1], row[2], row[0], ...row.sublist(3)];
        }
        return row;
      }).toList();

      // Remove duplicates before appending to Google Sheets
      List<List<String>> uniqueData = removeDuplicates(reorderedData);

      final ValueRange valueRange = ValueRange(values: uniqueData);
      await sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: "USER_ENTERED",
      );

      dev.log("Data appended successfully!");
    } catch (e) 
    {
      dev.log("failed to convert data to Google Sheets format");
      dev.log("Error converting data: $e");
    }
  }

  // Function to remove duplicate rows before appending to Google Sheets
  List<List<String>> removeDuplicates(List<List<String>> data) {
    Set<String> seen = {};
    return data.where((row) {
      String key = row.join('|'); // Create a unique key for each row
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      return true;
    }).toList();
  }

  String scrambleName (String data) 
  {
    int key = 126;
    StringBuffer scrambled = StringBuffer();
    for (int codeUnit in data.codeUnits) 
    {
      int scrambledCodeUnit = codeUnit ^ key;
      dev.log("Scrambling codeUnit...");
      if (scrambledCodeUnit >= 0 && scrambledCodeUnit <= 0x10FFFF) 
      {
        scrambled.write(String.fromCharCode(scrambledCodeUnit));
      } 
      else 
      {
        dev.log("Invalid Unicode Scalar encountered");
      }
    }
    return scrambled.toString();
  }
}
