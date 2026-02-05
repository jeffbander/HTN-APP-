"""
Admin Note model with encrypted text field for HIPAA compliance.
"""
from datetime import datetime
from app import db
from app.utils.encryption import encrypt_phi, decrypt_phi


class AdminNote(db.Model):
    """
    Admin notes on patients. The text field is encrypted at rest
    because notes may contain PHI references.
    """
    __tablename__ = 'admin_notes'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    admin_user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    _text_encrypted = db.Column('text', db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationships
    patient = db.relationship('User', foreign_keys=[user_id], backref='admin_notes')
    admin = db.relationship('User', foreign_keys=[admin_user_id])

    @property
    def text(self) -> str:
        return decrypt_phi(self._text_encrypted) if self._text_encrypted else None

    @text.setter
    def text(self, value: str):
        self._text_encrypted = encrypt_phi(value) if value else None

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'admin_user_id': self.admin_user_id,
            'admin_name': self.admin.name if self.admin else 'Admin',
            'text': self.text,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f'<AdminNote {self.id} for user {self.user_id}>'
