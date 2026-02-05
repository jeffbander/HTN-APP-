"""
MFA Session model for pending MFA verification during login.
"""
import secrets
from datetime import datetime, timedelta
from app import db


class MfaSession(db.Model):
    """Short-lived sessions for pending MFA verification."""
    __tablename__ = 'mfa_sessions'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    session_token = db.Column(db.String(64), unique=True, nullable=False, index=True)
    otp_code = db.Column(db.String(6), nullable=True)  # 6-digit code for email MFA
    mfa_type = db.Column(db.String(10), nullable=False, default='email')  # 'totp' or 'email'
    attempts = db.Column(db.Integer, default=0)
    expires_at = db.Column(db.DateTime, nullable=False)
    verified_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='mfa_sessions')

    @classmethod
    def create_for_user(cls, user_id, mfa_type='email'):
        """Invalidate old sessions and create a new MFA session with 10-min expiry."""
        # Expire existing unverified sessions for this user
        cls.query.filter_by(user_id=user_id, verified_at=None).update(
            {'expires_at': datetime.utcnow()}
        )

        session_token = secrets.token_hex(32)
        otp_code = str(secrets.randbelow(1000000)).zfill(6) if mfa_type == 'email' else None

        session = cls(
            user_id=user_id,
            session_token=session_token,
            otp_code=otp_code,
            mfa_type=mfa_type,
            expires_at=datetime.utcnow() + timedelta(minutes=10),
        )
        db.session.add(session)
        db.session.commit()
        return session

    @property
    def is_expired(self):
        return datetime.utcnow() > self.expires_at

    @property
    def is_verified(self):
        return self.verified_at is not None

    @property
    def too_many_attempts(self):
        return self.attempts >= 5

    def __repr__(self):
        return f'<MfaSession user={self.user_id} type={self.mfa_type}>'
