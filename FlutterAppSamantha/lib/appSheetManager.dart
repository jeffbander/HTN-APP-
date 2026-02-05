import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev; // For logging
import 'bloodPressureData.dart';

class AppSheetManager {
  final Set<String> seenRows = {};  // Track seen rows in the current session
  final String appSheetUrl = "https://www.appsheet.com/api/v2/apps/29320fd7-0017-46ab-8427-0c15b574f046/tables/app_data/Action";  // AppSheet API endpoint
  final String apiKey = "V2-r5Tgi-Gw8Pr-icj3D-qmaWg-ALAiV-gfp6P-VoBq7-LX1TD";  // Your AppSheet API Key

  // Function to send data to AppSheet
  Future<void> sendDataToAppSheet(String userInfo,
                                   String deviceId,
                                   List<Map<DateTime, List<String>>> bloodPressureData) async {

    try {
      // Pass the userInfo (scrambledName), deviceId, and bloodPressureData
      List<List<String>> cookedData = BloodPressureParser.processBloodPressureData(
        bloodPressureData.cast<Map<DateTime, List<int>>>(), 
        userInfo,  // Pass the user info as the scrambled name
        deviceId
      );

      dev.log("Original Data: $cookedData"); // Debug log to see the original data

      // Prepare the rows in the required format
      List<Map<String, dynamic>> rows = cookedData.map((row) {
        return {  
          "Timestamp": row[0],  // timestamp
          "Scramble": row[1],  // name and user info 
          "Device ID": row[2],  // Device ID
          "SBP": row[3],        // Systolic BP (SBP)
          "DBP": row[4],        // Diastolic BP (DBP)
          "HR": row[5],         // Heart Rate (HR)
        };
      }).toList();

      // JSON body for the request
      Map<String, dynamic> jsonData = {
        "Action": "Add",
        "Properties": {
          "RunAsUserEmail": "Notifications@ProviderLoop.com"
        },
        "Rows": rows
      };

      // Debugging: Print the full JSON message
      dev.log("Formatted JSON data to send to AppSheet: ${json.encode(jsonData)}");

      // Send data to AppSheet API
      final response = await http.post(
        Uri.parse(appSheetUrl),
        headers: {
          "Content-Type": "application/json",
          "ApplicationAccessKey": apiKey,
        },
        body: json.encode(jsonData),
      );

      if (response.statusCode == 200) {
        dev.log("Data sent successfully to AppSheet!");
      } else {
        dev.log("Failed to send data to AppSheet. Status code: ${response.statusCode}");
        dev.log("Response body: ${response.body}");
      }
    } catch (e) {
      dev.log("Error sending data to AppSheet: $e");
    }
  }
}
