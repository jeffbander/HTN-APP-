"""
Email verification model for 6-digit code-based email verification.
"""
import secrets
from datetime import datetime, timedelta
from app import db


class EmailVerification(db.Model):
    """Stores email verification codes for users."""
    __tablename__ = 'email_verifications'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    code = db.Column(db.String(6), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    used_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    @staticmethod
    def generate_code():
        """Generate a 6-digit numeric verification code."""
        return str(secrets.randbelow(1000000)).zfill(6)

    @classmethod
    def create_for_user(cls, user_id):
        """Expire unused codes for this user, then create a new one (15-min expiry)."""
        # Mark all existing unused codes as expired
        cls.query.filter_by(user_id=user_id, used_at=None).update(
            {'expires_at': datetime.utcnow()}
        )

        code = cls.generate_code()
        verification = cls(
            user_id=user_id,
            code=code,
            expires_at=datetime.utcnow() + timedelta(minutes=15)
        )
        db.session.add(verification)
        db.session.commit()
        return verification

    def __repr__(self):
        return f'<EmailVerification user={self.user_id}>'
