import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../flaskRegUsr.dart';
import '../utils/status_router.dart';

class CuffRequestPendingScreen extends StatefulWidget {
  final String? address;

  const CuffRequestPendingScreen({
    super.key,
    this.address,
  });

  @override
  State<CuffRequestPendingScreen> createState() => _CuffRequestPendingScreenState();
}

class _CuffRequestPendingScreenState extends State<CuffRequestPendingScreen> {
  final _storage = const FlutterSecureStorage();
  final _flaskRegUsr = FlaskRegUsr();
  Timer? _pollTimer;

  String _status = 'pending';
  String? _trackingNumber;
  String? _address;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _address = widget.address;
    _fetchStatus();
    // Poll every 30 seconds for status updates
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return;

      final result = await _flaskRegUsr.getCuffRequestStatus(token);

      if (result['status'] == 200 && mounted) {
        final request = result['request'] as Map<String, dynamic>?;
        setState(() {
          _status = request?['status'] ?? result['request_status'] ?? 'pending';
          _trackingNumber = request?['tracking_number'] ?? result['tracking_number'];
          _address = request?['shipping_address'] ?? result['address'] ?? _address;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String statusText;
    IconData icon;

    switch (_status) {
      case 'approved':
        bgColor = AppTheme.info.withOpacity(0.1);
        textColor = AppTheme.info;
        statusText = 'APPROVED';
        icon = Icons.thumb_up;
        break;
      case 'shipped':
        bgColor = AppTheme.accentGreen.withOpacity(0.1);
        textColor = AppTheme.accentGreen;
        statusText = 'SHIPPED';
        icon = Icons.local_shipping;
        break;
      case 'received':
        bgColor = AppTheme.accentGreen.withOpacity(0.1);
        textColor = AppTheme.accentGreen;
        statusText = 'RECEIVED';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        bgColor = AppTheme.error.withOpacity(0.1);
        textColor = AppTheme.error;
        statusText = 'REJECTED';
        icon = Icons.cancel;
        break;
      default:
        bgColor = AppTheme.warning.withOpacity(0.1);
        textColor = AppTheme.warning;
        statusText = 'PENDING';
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            statusText,
            style: AppTheme.labelLarge.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_status) {
      case 'approved':
        return 'Request Approved';
      case 'shipped':
        return 'Cuff Shipped!';
      case 'received':
        return 'Cuff Received';
      case 'rejected':
        return 'Request Rejected';
      default:
        return 'Request Submitted';
    }
  }

  IconData _getHeaderIcon() {
    switch (_status) {
      case 'approved':
        return Icons.thumb_up;
      case 'shipped':
        return Icons.local_shipping;
      case 'received':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.check_circle;
    }
  }

  Color _getIconColor() {
    switch (_status) {
      case 'approved':
        return AppTheme.info;
      case 'shipped':
      case 'received':
        return AppTheme.accentGreen;
      case 'rejected':
        return AppTheme.error;
      default:
        return AppTheme.accentGreen;
    }
  }

  String _getStatusMessage() {
    switch (_status) {
      case 'approved':
        return 'Your cuff request has been approved. It will be shipped soon.';
      case 'shipped':
        return 'Your blood pressure cuff is on its way!';
      case 'received':
        return 'Great! You can now pair your cuff with the app.';
      case 'rejected':
        return 'Unfortunately, your cuff request was not approved. Please contact support for more information.';
      default:
        return 'Your cuff request has been sent to the Hypertension Prevention Program team.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          GradientHeader(
            title: _getHeaderTitle(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchStatus,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Column(
                        children: [
                          const SizedBox(height: AppTheme.spacingXl),
                          // Status icon
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: _getIconColor().withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getHeaderIcon(),
                              size: 80,
                              color: _getIconColor(),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingLg),
                          Text(
                            _getHeaderTitle(),
                            style: AppTheme.headlineLarge,
                          ),
                          const SizedBox(height: AppTheme.spacingXl),
                          AppCard(
                            child: Column(
                              children: [
                                Text(
                                  _getStatusMessage(),
                                  style: AppTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMd),
                          if (_status != 'rejected' && _status != 'received')
                            AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppTheme.spacingSm),
                                    decoration: BoxDecoration(
                                      color: AppTheme.navyBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active,
                                      color: AppTheme.navyBlue,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingMd),
                                  Expanded(
                                    child: Text(
                                      _status == 'shipped'
                                          ? "You'll receive a notification when your cuff is delivered."
                                          : "You'll receive a push notification when your cuff has been shipped.",
                                      style: AppTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_trackingNumber != null) ...[
                            const SizedBox(height: AppTheme.spacingMd),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tracking Number:',
                                    style: AppTheme.labelLarge,
                                  ),
                                  const SizedBox(height: AppTheme.spacingSm),
                                  SelectableText(
                                    _trackingNumber!,
                                    style: AppTheme.titleLarge.copyWith(
                                      color: AppTheme.navyBlue,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_address != null) ...[
                            const SizedBox(height: AppTheme.spacingMd),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shipping Address:',
                                    style: AppTheme.labelLarge,
                                  ),
                                  const SizedBox(height: AppTheme.spacingSm),
                                  Text(
                                    _address!,
                                    style: AppTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppTheme.spacingMd),
                          AppCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Status: ',
                                  style: AppTheme.bodyLarge,
                                ),
                                _buildStatusBadge(),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Text(
                            'Pull down to refresh status',
                            style: AppTheme.labelMedium.copyWith(
                              color: AppTheme.mediumGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_status == 'delivered' || _status == 'received')
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: PrimaryButton(
                  label: 'Start Taking Readings',
                  variant: ButtonVariant.navy,
                  onPressed: () {
                    // Cuff received — route to measurement (pending_first_reading)
                    Navigator.of(context).pushReplacementNamed(
                      StatusRouter.routeForStatus('pending_first_reading'),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
