"""
DashboardMfaSession model for pending MFA verification during dashboard login.
"""
import secrets
from datetime import datetime, timedelta, timezone
from app import db


class DashboardMfaSession(db.Model):
    """Short-lived sessions for pending MFA verification on the admin dashboard."""
    __tablename__ = 'dashboard_mfa_sessions'

    id = db.Column(db.Integer, primary_key=True)
    dashboard_user_id = db.Column(
        db.Integer, db.ForeignKey('dashboard_users.id'), nullable=False
    )
    session_token = db.Column(db.String(64), unique=True, nullable=False, index=True)
    otp_code = db.Column(db.String(6), nullable=True)
    mfa_type = db.Column(db.String(10), nullable=False, default='totp')
    attempts = db.Column(db.Integer, default=0)
    expires_at = db.Column(db.DateTime, nullable=False)
    verified_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    dashboard_user = db.relationship('DashboardUser', backref='mfa_sessions')

    @classmethod
    def create_for_user(cls, dashboard_user_id, mfa_type='totp'):
        """Invalidate old sessions and create a new MFA session with 10-min expiry."""
        cls.query.filter_by(dashboard_user_id=dashboard_user_id, verified_at=None).update(
            {'expires_at': datetime.now(timezone.utc)}
        )

        session_token = secrets.token_hex(32)
        otp_code = str(secrets.randbelow(1000000)).zfill(6) if mfa_type == 'email' else None

        session = cls(
            dashboard_user_id=dashboard_user_id,
            session_token=session_token,
            otp_code=otp_code,
            mfa_type=mfa_type,
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        )
        db.session.add(session)
        db.session.commit()
        return session

    @property
    def is_expired(self):
        now = datetime.now(timezone.utc)
        expires = self.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        return now > expires

    @property
    def is_verified(self):
        return self.verified_at is not None

    @property
    def too_many_attempts(self):
        return self.attempts >= 5

    def __repr__(self):
        return f'<DashboardMfaSession user={self.dashboard_user_id} type={self.mfa_type}>'
