"""
DeviceToken model for storing FCM push notification tokens.
"""
from datetime import datetime
from app import db


class DeviceToken(db.Model):
    """
    Model for storing Firebase Cloud Messaging device tokens for push notifications.
    """
    __tablename__ = 'device_tokens'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    # FCM token
    token = db.Column(db.String(500), nullable=False, unique=True)

    # Platform: ios, android, web
    platform = db.Column(db.String(20), nullable=True)

    # Device info (optional)
    device_model = db.Column(db.String(100), nullable=True)
    app_version = db.Column(db.String(50), nullable=True)

    # Status
    is_active = db.Column(db.Boolean, default=True, nullable=False)

    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_used_at = db.Column(db.DateTime, nullable=True)

    # Relationships
    user = db.relationship('User', backref='device_tokens')

    def to_dict(self):
        """Convert to dictionary."""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'token': self.token[:20] + '...' if self.token else None,  # Truncate for security
            'platform': self.platform,
            'device_model': self.device_model,
            'app_version': self.app_version,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_used_at': self.last_used_at.isoformat() if self.last_used_at else None,
        }

    def __repr__(self):
        return f'<DeviceToken {self.id} user={self.user_id} platform={self.platform}>'
