"""
MFA Secret model for storing TOTP secrets and backup codes.
"""
import json
import secrets
import string
from datetime import datetime, timezone
from app import db
from app.utils.encryption import encrypt_phi, decrypt_phi


class MfaSecret(db.Model):
    """Stores TOTP secrets (encrypted) and backup codes for MFA-enabled users."""
    __tablename__ = 'mfa_secrets'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, unique=True)
    _totp_secret_encrypted = db.Column('totp_secret', db.Text, nullable=False)
    _backup_codes_encrypted = db.Column('backup_codes', db.Text, nullable=True)
    mfa_type = db.Column(db.String(10), nullable=False, default='totp')  # 'totp' or 'email'
    is_active = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_used_at = db.Column(db.DateTime, nullable=True)

    user = db.relationship('User', backref=db.backref('mfa_secret', uselist=False))

    @property
    def totp_secret(self) -> str:
        return decrypt_phi(self._totp_secret_encrypted) if self._totp_secret_encrypted else None

    @totp_secret.setter
    def totp_secret(self, value: str):
        self._totp_secret_encrypted = encrypt_phi(value) if value else None

    @property
    def backup_codes(self) -> list:
        if not self._backup_codes_encrypted:
            return []
        decrypted = decrypt_phi(self._backup_codes_encrypted)
        return json.loads(decrypted) if decrypted else []

    @backup_codes.setter
    def backup_codes(self, value: list):
        self._backup_codes_encrypted = encrypt_phi(json.dumps(value)) if value else None

    def generate_backup_codes(self, count=10):
        """Generate a set of 8-char alphanumeric backup codes."""
        charset = string.ascii_lowercase + string.digits
        codes = [
            ''.join(secrets.choice(charset) for _ in range(8))
            for _ in range(count)
        ]
        self.backup_codes = codes
        return codes

    def use_backup_code(self, code):
        """Verify and consume a backup code. Returns True if valid."""
        codes = self.backup_codes
        code_lower = code.lower().strip()
        if code_lower in codes:
            codes.remove(code_lower)
            self.backup_codes = codes
            self.last_used_at = datetime.now(timezone.utc)
            return True
        return False

    def __repr__(self):
        return f'<MfaSecret user={self.user_id} type={self.mfa_type}>'
