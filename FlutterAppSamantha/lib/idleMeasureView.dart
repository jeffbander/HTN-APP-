import 'dart:async';
import 'package:flutter/material.dart';
import 'msg.dart';

class IdleMeasureView extends StatefulWidget {
  final BaseMessenger messenger;
  const IdleMeasureView(this.messenger, {super.key});

  @override
  _IdleMeasureViewState createState() => _IdleMeasureViewState();
}

class _IdleMeasureViewState extends State<IdleMeasureView> {
  double firstImageOpacity = 1.0;
  double secondImageOpacity = 0.0;
  bool measurementFound = false;

  @override
  void initState() {
    super.initState();
    print("IdleMeasureView appeared. Displaying first image...");

    // Start second image fade-in after 5 seconds (palm tree animation)
    Future.delayed(const Duration(seconds: 5), () {
      if (!measurementFound && mounted) {
        setState(() {
          firstImageOpacity = 0.0;
          secondImageOpacity = 1.0;
        });
      }
    });
  }

  void onMeasurementFound() {
    setState(() {
      measurementFound = true;
    });
    print("message sent to ui update to new screen");

    widget.messenger.sendMsg(
      Msg(
        taskType: TaskType.Idle,
        status: Status.update,
        sender: [ComponentType.View],
      ),
    );
  }

  void onCancel() {
    // Handle cancel logic - send message to NavigationManager
    print('Cancel button pressed - sending cancel message');

    // Send cancel message - NavigationManager will handle navigation
    // Do NOT navigate locally here - it causes a race condition
    widget.messenger.sendMsg(
      Msg(
        taskType: TaskType.Idle,
        status: Status.cancel,
        sender: [ComponentType.View],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for the second image
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // First image: SafeArea applied only here
          AnimatedOpacity(
            opacity: firstImageOpacity,
            duration: const Duration(seconds: 2),
            child: SafeArea(
              child: Container(
                width: screenWidth,
                height: screenHeight,
                color: Colors.white, // White screen for the first phase
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/UsingCuff.png',  // First image to be shown initially
                      width: 300,
                      height: 300,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.center,
                        child: RichText(
                          textAlign: TextAlign.left,
                          text: TextSpan(
                            style: TextStyle(fontSize: 16, color: Colors.black),
                            children: [
                              TextSpan(text: '\n\n\nPress '),
                              TextSpan(
                                text: 'Start/Stop',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' button on the cuff \n\n\n'),
                              TextSpan(text: '• Sit upright, back supported, feet flat \n'),
                              TextSpan(text: '• Arm at heart level, cuff on bare arm \n'),
                              TextSpan(text: '• Stay still, no talking or movement'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Second image: Full screen with no SafeArea, positioned behind the other elements
          AnimatedOpacity(
            opacity: secondImageOpacity,
            duration: const Duration(seconds: 2),
            child: SizedBox(
              width: screenWidth, // Full screen width
              height: screenHeight, // Full screen height
              child: Image.asset(
                'assets/Beach.gif', // Loading GIF from assets
                width: screenWidth,
                height: screenHeight,
                fit: BoxFit.cover, // Ensure the image covers the full screen
                errorBuilder: (context, error, stackTrace) {
                  return Center(child: Text("Failed to load image."));
                },
              ),
            ),
          ),
          
          // White text on the second image, only appear after second image fades in
          if (secondImageOpacity > 0)
            Positioned(
              top: screenHeight * 0.35,  // Adjust top positioning to center the text
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Measurement in Progress... \n\n\n\n\n\nWait for measurement to complete. The results will appear on the screen.',
                  style: TextStyle(
                    fontSize: 24,  // Set font size as needed
                    fontWeight: FontWeight.bold,  // Bold font
                    color: Colors.white,  // White text color
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 3.0,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ], // Optional: Add shadow to make text stand out on the image
                  ),
                  textAlign: TextAlign.center,  // Center the text horizontally
                ),
              ),
            ),
          
          // Bottom-centered cancel button with rounded edges
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30, // Above safe area
            left: screenWidth * 0.15,
            right: screenWidth * 0.15,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                print("Cancel button pressed");
                onCancel();
              },
              child: Container(
                width: screenWidth * 0.7,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpdateScreen extends StatefulWidget {
  final BaseMessenger messenger;  // Assuming messenger is passed to send messages
  const UpdateScreen(this.messenger, {super.key});

  @override
  _UpdateScreenState createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  @override
  void initState() {
    super.initState();

    // After 5 seconds, send a message and change the screen
    Future.delayed(const Duration(seconds: 5), () {
      // Send message to transition to another screen
      print("Message sent, navigating to the next screen");

      widget.messenger.sendMsg(
        Msg(
          taskType: TaskType.Idle,
          status: Status.finished,
          sender: [ComponentType.View],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: SafeArea(  // This will ensure that content is within safe space
        child: Center(
          child: Text(
            'Sending Blood Pressure\nto Mount Sinai', // Centered black text
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
