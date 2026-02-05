"""
Revoked token model for JWT token revocation / logout support.
"""
from datetime import datetime
from app import db


class RevokedToken(db.Model):
    """Tracks revoked JWT tokens to support logout."""
    __tablename__ = 'revoked_tokens'

    id = db.Column(db.Integer, primary_key=True)
    jti = db.Column(db.String(64), unique=True, nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    revoked_at = db.Column(db.DateTime, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)

    @staticmethod
    def is_token_revoked(jti):
        """Check if a token has been revoked."""
        return db.session.query(
            db.exists().where(RevokedToken.jti == jti)
        ).scalar()

    @staticmethod
    def cleanup_expired():
        """Delete revoked token entries that have already expired."""
        count = RevokedToken.query.filter(
            RevokedToken.expires_at < datetime.utcnow()
        ).delete()
        db.session.commit()
        return count

    def __repr__(self):
        return f'<RevokedToken {self.jti}>'
