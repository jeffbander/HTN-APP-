import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme/app_theme.dart';
import 'widgets/gradient_header.dart';
import 'widgets/app_card.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  static const String _contactEmail = 'htn.prevention@mountsinai.org';

  Future<void> _sendEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      query: 'subject=Hypertension Prevention Program Help Request',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: 'Help Center',
            subtitle: 'Guides & Support',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // How-To Guides Section
                  Text(
                    'How-To Guides',
                    style: AppTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _HelpSection(
                    title: 'Taking Your First Reading',
                    icon: Icons.favorite,
                    content: '''
1. Sit down in a comfortable chair with your feet flat on the floor.

2. Rest for 5 minutes before taking your measurement.

3. Place your left arm on a flat surface (like a table) with your palm facing up.

4. Position the cuff on your bare upper arm, about 1 inch above your elbow.

5. The tube should run down the center of your inner arm.

6. Make sure the cuff is snug but not too tight (you should be able to fit two fingers underneath).

7. Press the Start button on your cuff.

8. Stay still and don't talk during the measurement.

9. Your reading will appear on the cuff's display and sync to the app.
''',
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _HelpSection(
                    title: 'Pairing Your Device',
                    icon: Icons.bluetooth,
                    content: '''
1. Make sure Bluetooth is enabled on your phone.

2. Turn on your Omron blood pressure monitor.

3. Open the Hypertension Prevention app.

4. Navigate to Device > Pair New Device.

5. Hold the Pair button on your cuff until "P" appears.

6. Release the button - the "P" should blink.

7. When prompted on your phone, tap "Allow" or "Pair".

8. Once connected, you'll see a confirmation message.
''',
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _HelpSection(
                    title: 'Understanding Your Results',
                    icon: Icons.analytics,
                    content: '''
Blood Pressure Categories:

NORMAL: Less than 120/80 mmHg
Your blood pressure is in the healthy range. Keep up the good work!

ELEVATED: 120-129 / Less than 80 mmHg
Your blood pressure is slightly higher than normal. Consider lifestyle changes.

HIGH (Stage 1): 130-139 / 80-89 mmHg
This is high blood pressure. Consult with your healthcare provider.

HIGH (Stage 2): 140+ / 90+ mmHg
This is significantly elevated. Follow up with your doctor promptly.

CRISIS: Higher than 180/120 mmHg
Seek medical attention immediately if you have these readings along with symptoms.

The top number (systolic) measures pressure when your heart beats.
The bottom number (diastolic) measures pressure between beats.
''',
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _HelpSection(
                    title: 'Setting Up Reminders',
                    icon: Icons.notifications,
                    content: '''
1. Tap the Reminders icon in the bottom navigation.

2. Tap "Add Reminder" to create a new reminder.

3. Choose the time you want to be reminded.

4. Select which days of the week to repeat the reminder.

5. Toggle the reminder on/off as needed.

6. Tap Save to confirm your reminder.

Tip: For best results, measure your blood pressure at the same times each day - typically morning and evening.
''',
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  // FAQ Section
                  Text(
                    'Frequently Asked Questions',
                    style: AppTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _FaqItem(
                    question: 'How often should I measure?',
                    answer:
                        'We recommend taking measurements twice daily - once in the morning and once in the evening - at consistent times. This helps establish an accurate picture of your blood pressure patterns.',
                  ),
                  _FaqItem(
                    question: "What's a normal blood pressure reading?",
                    answer:
                        'A normal blood pressure reading is less than 120/80 mmHg. Elevated is 120-129/<80, High Stage 1 is 130-139/80-89, and High Stage 2 is 140+/90+.',
                  ),
                  _FaqItem(
                    question: "My device won't connect",
                    answer:
                        "Make sure Bluetooth is enabled, you're within range of your phone, and your cuff has fresh batteries. Try forgetting the device in your phone's Bluetooth settings and re-pairing. See the troubleshooting section below for detailed steps.",
                  ),
                  _FaqItem(
                    question: 'Is my data secure?',
                    answer:
                        'Yes, your data is fully HIPAA compliant and encrypted. Your readings are only shared with the Mount Sinai Hypertension Prevention Program team for monitoring purposes.',
                  ),
                  _FaqItem(
                    question: 'What if I miss a reading?',
                    answer:
                        "Don't worry! Simply take your next scheduled reading. Consistency is important, but missing occasional readings won't affect your overall monitoring.",
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  // Troubleshooting Section
                  Text(
                    'Troubleshooting',
                    style: AppTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _HelpSection(
                    title: 'Pairing Your Omron EVOLV',
                    icon: Icons.build,
                    initiallyExpanded: false,
                    content: '''
STEP 1: Forget the cuff in Bluetooth settings

iPhone:
- Go to Settings > Bluetooth > My Devices
- Find "BP 7000" and tap the "i" icon
- Tap "Forget This Device"

Android:
- Go to Settings > Bluetooth > Connected Devices
- Tap the gear icon next to your cuff
- Tap "Forget" or "Unpair"


STEP 2: Check app permissions

iPhone:
- Go to Settings > Apps > Hypertension Prevention Program
- Make sure Bluetooth is set to ON

Android:
- Go to Settings > Apps > Hypertension Prevention Program > Permissions
- Allow Location (while using app) & Nearby Devices


STEP 3: Pair in the app

1. Open the app
2. Navigate to Register/Pair Device
3. Select OMRON
4. Tap Pair
5. Hold the Pair button on your cuff until "P" appears
6. Release your finger - it should blink
7. Press "OK" on the pairing instructions page
8. Wait for the pop-up


STEP 4: Approve the connection

iPhone:
- When prompted, tap "Allow"

Android:
- Tap "Pair and Connect" (you may need to tap twice)


STEP 5: Confirm success

- The app should show the Measure page with a green Start button
- Your cuff screen should show "OK"
- Take a test reading to confirm it syncs to the app
''',
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  _TroubleshootingItem(
                    issue: 'Sync problems',
                    steps: [
                      'Check your internet connection',
                      'Force close the app completely',
                      'Reopen the app and try again',
                      'If still not working, try restarting your phone',
                    ],
                  ),
                  _TroubleshootingItem(
                    issue: 'Device not found',
                    steps: [
                      'Make sure your cuff is in pairing mode (hold Pair button until "P" blinks)',
                      'Check that your cuff has fresh batteries',
                      'Move closer to your phone',
                      'Try forgetting and re-adding the device',
                    ],
                  ),
                  _TroubleshootingItem(
                    issue: 'Readings not appearing in app',
                    steps: [
                      'Make sure your cuff is connected via Bluetooth',
                      'Check that you have a stable internet connection',
                      'Try taking another reading',
                      'Force close and reopen the app',
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  // Contact Section
                  AppCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.email,
                          size: 48,
                          color: AppTheme.navyBlue,
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          'Still need help?',
                          style: AppTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        Text(
                          'Contact our support team',
                          style: AppTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        GestureDetector(
                          onTap: () => _sendEmail(context),
                          child: Text(
                            _contactEmail,
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.navyBlue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool initiallyExpanded;

  const _HelpSection({
    required this.title,
    required this.icon,
    required this.content,
    this.initiallyExpanded = false,
  });

  @override
  State<_HelpSection> createState() => _HelpSectionState();
}

class _HelpSectionState extends State<_HelpSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: AppTheme.navyBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    widget.icon,
                    color: AppTheme.navyBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTheme.titleMedium,
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.mediumGray,
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: AppTheme.spacingMd),
            const Divider(),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              widget.content.trim(),
              style: AppTheme.bodyLarge.copyWith(
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: AppCard(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: AppTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.remove : Icons.add,
                    color: AppTheme.navyBlue,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  widget.answer,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.darkGray,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TroubleshootingItem extends StatelessWidget {
  final String issue;
  final List<String> steps;

  const _TroubleshootingItem({
    required this.issue,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  issue,
                  style: AppTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ...steps.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.navyBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.navyBlue,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: AppTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
