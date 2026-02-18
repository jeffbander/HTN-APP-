import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'commonWidgets.dart';
import 'LogView.dart';
import 'msg.dart' as msg;
import 'msg.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';


class SyncView extends StatefulWidget
{
  final msg.BaseMessenger? messenger;
  LogView? logView;

  SyncView
  (msg.BaseMessenger uiMessenger, {super.key,
    this.messenger
  });

  @override
  _SyncViewState createState () => _SyncViewState();
}

class _SyncViewState extends State <SyncView>
{
  bool isLogVisible = false; // State to manage log visibility
  bool showAlert = true; // Track alert visibility
  String formattedMessage = '''
Sending measurement back to Mt. Sinai.

This may take a moment...
''';

  @override
  void initState ()
  {
    super.initState ();
    // Send initial message when the view appears
    widget.messenger?.sendMsg
    (
      msg.Msg
      (
        taskType: msg.TaskType.Sync,
        status: msg.Status.request,
        sender: [msg.ComponentType.View],
      ),
    );
  }

  void handleMsgStatus(Msg msg, dynamic Sender)
  {
    // Update messagesSent map
    widget.messenger?.messagesSent[msg.msgId] = msg;

    // Handle messages from the messenger
    if (msg.sender.last != Sender.NavigationManager) return;

    switch (msg.taskType)
    {
      default:
        break;
    }
  }

  @override
  Widget build (BuildContext context)
  {
    return Scaffold
    (
      appBar: null, // Hide the navigation bar
      body: Column
      (
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
        [
          HeaderView
          (
            messenger: widget.messenger,
            title: "SYNC",
            onToggleLogVisibility: ()
            {
              setState(() {
                isLogVisible = !isLogVisible;
              });
            },
            onPressed: ()
            {
              // Provide your logic for the onPressed action here
              dev.log("HeaderView button pressed");
            },
          ),

          const Divider (),
          Padding (
            padding: const EdgeInsets.symmetric (vertical: 20.0),
            child: Image.asset
            (
              "assets/logo.png", // Adjust image path as needed
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
          Padding
          (
            padding: const EdgeInsets.all (8.0),
            child: Text
            (
              "Syncing from cuff",
              style: Theme.of (context).textTheme.titleMedium,
            ),
          ),
          // Offline Queue Status
          _buildOfflineQueueStatus(),
          CustomAlertView
          (
            isVisible: showAlert,
            imageAsset: "assets/logo.png", // Adjust image path as needed
            message: formattedMessage,
            onClose: () {
              // Logic for closing the alert
              dev.log("Alert closed");
              setState(() {
                showAlert = false;
              });
            },
          ),
          if (isLogVisible)
            Container
            (
              height: 300,
              padding: const EdgeInsets.all (8.0),
              decoration: BoxDecoration
              (
                border: Border.all(color: Colors.grey),
              ),
              child: widget.logView,
            ),
          const Spacer (),
        ],
      ),
    );
  }

  Widget _buildOfflineQueueStatus() {
    return Consumer<SyncService>(
      builder: (context, syncService, _) {
        if (syncService.pendingCount == 0 && syncService.failedCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: syncService.isConnected
                ? AppTheme.info.withOpacity(0.1)
                : AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: syncService.isConnected ? AppTheme.info : AppTheme.warning,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    syncService.isConnected
                        ? (syncService.isSyncing ? Icons.sync : Icons.cloud_queue)
                        : Icons.cloud_off,
                    size: 20,
                    color: syncService.isConnected ? AppTheme.info : AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      syncService.isConnected
                          ? (syncService.isSyncing ? 'Syncing...' : 'Offline Queue')
                          : 'Offline Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: syncService.isConnected ? AppTheme.info : AppTheme.warning,
                      ),
                    ),
                  ),
                  if (syncService.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.navyBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${syncService.pendingCount} pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              if (syncService.failedCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${syncService.failedCount} failed readings',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => syncService.retryFailedReadings(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
              if (syncService.lastSyncTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Last sync: ${_formatTime(syncService.lastSyncTime!)}',
                  style: const TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 11,
                  ),
                ),
              ],
              if (!syncService.isConnected) ...[
                const SizedBox(height: 4),
                const Text(
                  'Readings will sync when connection is restored',
                  style: TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
