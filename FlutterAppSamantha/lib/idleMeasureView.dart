import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'msg.dart';
import 'theme/app_theme.dart';

class IdleMeasureView extends StatefulWidget {
  final BaseMessenger messenger;
  const IdleMeasureView(this.messenger, {super.key});

  @override
  _IdleMeasureViewState createState() => _IdleMeasureViewState();
}

class _IdleMeasureViewState extends State<IdleMeasureView> {
  double instructionOpacity = 1.0;
  double beachOpacity = 0.0;
  bool measurementFound = false;

  @override
  void initState() {
    super.initState();
    dev.log("IdleMeasureView appeared. Displaying instructions...");

    // Fade to beach animation after 5 seconds (proxy for cuff starting)
    Future.delayed(const Duration(seconds: 5), () {
      if (!measurementFound && mounted) {
        setState(() {
          instructionOpacity = 0.0;
          beachOpacity = 1.0;
        });
      }
    });
  }

  void onMeasurementFound() {
    setState(() {
      measurementFound = true;
    });
    dev.log("message sent to ui update to new screen");

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
    dev.log('Cancel button pressed - sending cancel message');

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
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Instruction screen: "Press Start on cuff" + Quick Tips
          AnimatedOpacity(
            opacity: instructionOpacity,
            duration: const Duration(seconds: 2),
            child: SafeArea(
              child: SizedBox(
                width: screenWidth,
                height: screenHeight,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Main instruction
                      Icon(
                        Icons.play_circle_fill,
                        size: 56,
                        color: AppTheme.navyBlue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Press the Start button\non your cuff',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyBlue,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Positioning tips
                      _buildInstructionRow(Icons.event_seat, 'Sit upright, back supported, feet flat'),
                      _buildInstructionRow(Icons.favorite_border, 'Arm at heart level, cuff on bare arm'),
                      _buildInstructionRow(Icons.do_not_touch, 'Stay still, no talking or movement'),
                      const SizedBox(height: 20),
                      Divider(color: AppTheme.lightGray),
                      const SizedBox(height: 20),
                      // Quick Tips section
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: AppTheme.warning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Tips',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTipRow(Icons.no_drinks, 'Avoid caffeine for 30 minutes before'),
                      _buildTipRow(Icons.directions_run, 'Don\'t measure right after exercise'),
                      _buildTipRow(Icons.wc, 'Empty your bladder before measuring'),
                      _buildTipRow(Icons.schedule, 'Take readings at the same time daily'),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Beach animation: full screen
          AnimatedOpacity(
            opacity: beachOpacity,
            duration: const Duration(seconds: 2),
            child: SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: Image.asset(
                'assets/Beach.gif',
                width: screenWidth,
                height: screenHeight,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(child: Text("Failed to load image."));
                },
              ),
            ),
          ),

          // White text on the beach animation
          if (beachOpacity > 0)
            Positioned(
              top: screenHeight * 0.35,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Measurement in Progress... \n\n\n\n\n\nWait for measurement to complete. The results will appear on the screen.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 3.0,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Bottom-centered cancel button
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30,
            left: screenWidth * 0.15,
            right: screenWidth * 0.15,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                dev.log("Cancel button pressed");
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

  Widget _buildInstructionRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.navyBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: AppTheme.accentGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.black87),
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
      dev.log("Message sent, navigating to the next screen");

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
