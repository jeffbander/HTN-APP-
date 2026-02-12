/// Maps user_status values to routes and enforces navigation guards.
class StatusRouter {
  StatusRouter._();

  /// Returns the route name the user should be on given their status.
  static String routeForStatus(String userStatus) {
    switch (userStatus) {
      case 'pending_approval':
        return '/pending-approval';
      case 'pending_registration':
        return '/registration';
      case 'pending_cuff':
        return '/device-selection';
      case 'pending_first_reading':
        return '/measurement';
      case 'active':
        return '/measurement';
      case 'deactivated':
        return '/deactivated';
      case 'enrollment_only':
        return '/pending-approval';
      default:
        return '/pending-approval';
    }
  }

  /// Whitelist of routes allowed for each status.
  static Set<String> allowedRoutesForStatus(String userStatus) {
    switch (userStatus) {
      case 'pending_approval':
        return {'/pending-approval', '/login', '/logout'};
      case 'pending_registration':
        return {'/registration', '/login', '/logout'};
      case 'pending_cuff':
        return {'/device-selection', '/cuff-request-pending', '/pairing', '/login', '/logout'};
      case 'pending_first_reading':
        return {'/measurement', '/login', '/logout'};
      case 'active':
        // Full access
        return {
          '/measurement', '/profile', '/home', '/help',
          '/reminders', '/education', '/device-info', '/device-selection',
          '/pairing', '/cuff-request-pending', '/history',
          '/lifestyle', '/login', '/logout',
        };
      case 'deactivated':
        return {'/deactivated', '/login', '/logout'};
      case 'enrollment_only':
        return {'/pending-approval', '/login', '/logout'};
      default:
        return {'/pending-approval', '/login', '/logout'};
    }
  }

  /// Returns true if the user's status allows navigating to the target route.
  static bool canNavigateTo(String userStatus, String targetRoute) {
    return allowedRoutesForStatus(userStatus).contains(targetRoute);
  }

  /// Returns true if bottom navigation bar should be shown for this status.
  static bool showBottomNav(String userStatus) {
    return userStatus == 'active' || userStatus == 'pending_first_reading';
  }

  /// Human-readable label for a user_status value.
  static String statusLabel(String userStatus) {
    switch (userStatus) {
      case 'pending_approval':
        return 'Pending Approval';
      case 'pending_registration':
        return 'Pending Registration';
      case 'pending_cuff':
        return 'Awaiting Cuff';
      case 'pending_first_reading':
        return 'Awaiting First Reading';
      case 'active':
        return 'Active';
      case 'deactivated':
        return 'Deactivated';
      case 'enrollment_only':
        return 'Enrollment Only';
      default:
        return userStatus;
    }
  }
}
