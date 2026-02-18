import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'googleSheetsUserManager.dart';
import 'sourceManager.dart';

class NoCuffView extends StatelessWidget 
{
  const NoCuffView ({super.key});

  Future<void> sendUserData () async 
  {
    try 
    {
      // Access existing UserInfo from SourceManager singleton
      final userInfo = SourceManager.shared.userInfo;

      // Concatenate user data
      final concatenatedData = userInfo.concatData ();

      // Append user data to Google Sheets using GoogleSheetsUserManager
      await GoogleSheetsUserManager ().appendUserDataToGoogleSheets (concatenatedData);
      dev.log("User data successfully sent to Google Sheets.");
    } catch (e) {
      dev.log("Failed to send user data to Google Sheets: $e");
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    // Trigger data sending when the view is built
    sendUserData ();

    return Scaffold(
      appBar: AppBar(title: const Text("Blood Pressure Cuff Request")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(
            child: Text(
              "Response recorded. We will send you a blood pressure cuff shortly.",
              textAlign: TextAlign.center,
              style: TextStyle (fontSize: 18),
            ),
          ),
          const SizedBox (height: 20),
          ElevatedButton(
            onPressed: () 
            {
              Navigator.pop(context);
            },
            child: const Text("Got It"),
          ),
        ],
      ),
    );
  }
}