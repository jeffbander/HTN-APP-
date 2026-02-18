"""
Push notification utilities using Firebase Cloud Messaging (FCM).
"""
import os
import logging

logger = logging.getLogger(__name__)

# Firebase Admin SDK instance (lazy initialized)
_firebase_app = None


def _get_firebase_app():
    """Get or initialize Firebase Admin SDK app."""
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    try:
        import firebase_admin
        from firebase_admin import credentials

        # Check if already initialized
        try:
            _firebase_app = firebase_admin.get_app()
            return _firebase_app
        except ValueError:
            pass

        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized successfully")
        else:
            logger.warning(
                "Firebase credentials not found. Push notifications will be disabled. "
                "Set FIREBASE_CREDENTIALS_PATH environment variable."
            )
            return None

        return _firebase_app

    except ImportError:
        logger.warning("firebase-admin package not installed. Push notifications disabled.")
        return None
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        return None


def send_notification(user_id, title, body, data=None):
    """Send a push notification to all active devices for a user.

    Args:
        user_id: The user ID to send notification to
        title: Notification title
        body: Notification body text
        data: Optional dict of custom data to include

    Returns:
        dict with 'success_count' and 'failure_count'
    """
    from app.models.device_token import DeviceToken

    app = _get_firebase_app()
    if not app:
        logger.warning(f"Cannot send notification to user {user_id}: Firebase not configured")
        return {'success_count': 0, 'failure_count': 0, 'error': 'Firebase not configured'}

    try:
        from firebase_admin import messaging
    except ImportError:
        return {'success_count': 0, 'failure_count': 0, 'error': 'firebase-admin not installed'}

    # Get active tokens for user
    tokens = DeviceToken.query.filter_by(user_id=user_id, is_active=True).all()

    if not tokens:
        logger.info(f"No active device tokens for user {user_id}")
        return {'success_count': 0, 'failure_count': 0, 'error': 'No device tokens'}

    success_count = 0
    failure_count = 0

    for device_token in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=device_token.token,
            )

            response = messaging.send(message)
            logger.info(f"Sent notification to user {user_id}, response: {response}")
            success_count += 1

            # Update last used timestamp
            from datetime import datetime, timezone
            device_token.last_used_at = datetime.now(timezone.utc)

        except messaging.UnregisteredError:
            # Token is no longer valid, mark as inactive
            logger.warning(f"Token {device_token.id} is unregistered, marking inactive")
            device_token.is_active = False
            failure_count += 1

        except Exception as e:
            logger.error(f"Failed to send notification to token {device_token.id}: {e}")
            failure_count += 1

    # Commit token updates
    from app import db
    db.session.commit()

    return {'success_count': success_count, 'failure_count': failure_count}


def notify_account_approved(user_id):
    """Send notification when user's account is approved."""
    return send_notification(
        user_id=user_id,
        title="Account Approved!",
        body="Your account has been approved. You can now log in and start tracking your blood pressure.",
        data={'type': 'account_approved'}
    )


def notify_cuff_shipped(user_id, tracking_number):
    """Send notification when user's cuff has been shipped."""
    return send_notification(
        user_id=user_id,
        title="Your Cuff Has Shipped!",
        body=f"Your blood pressure cuff is on its way! Tracking: {tracking_number}",
        data={'type': 'cuff_shipped', 'tracking_number': tracking_number}
    )


def notify_cuff_approved(user_id):
    """Send notification when user's cuff request is approved."""
    return send_notification(
        user_id=user_id,
        title="Cuff Request Approved",
        body="Your blood pressure cuff request has been approved and will ship soon.",
        data={'type': 'cuff_approved'}
    )


def notify_reading_reminder(user_id):
    """Send a reminder to take blood pressure reading."""
    return send_notification(
        user_id=user_id,
        title="Time to Check Your BP",
        body="Don't forget to take your blood pressure reading today!",
        data={'type': 'reading_reminder'}
    )


def notify_high_bp_alert(user_id, systolic, diastolic):
    """Send alert for high blood pressure reading."""
    return send_notification(
        user_id=user_id,
        title="High Blood Pressure Alert",
        body=f"Your recent reading of {systolic}/{diastolic} is elevated. Please consult your healthcare provider.",
        data={'type': 'high_bp_alert', 'systolic': str(systolic), 'diastolic': str(diastolic)}
    )
