"""
Call Attempt model — logs each outreach attempt with encrypted notes (PHI).
"""
from datetime import datetime
from app import db
from app.utils.encryption import encrypt_phi, decrypt_phi


class CallAttempt(db.Model):
    """
    Records a single outreach attempt for a call list item.
    Notes are encrypted at rest because they may contain PHI.
    """
    __tablename__ = 'call_attempts'

    id = db.Column(db.Integer, primary_key=True)
    call_list_item_id = db.Column(db.Integer, db.ForeignKey('call_list_items.id'), nullable=False, index=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)  # the patient
    admin_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)  # who made the call
    outcome = db.Column(db.String(30), nullable=False)
    # completed | left_vm | no_answer | email_sent | requested_callback | refused | sent_materials
    _notes_encrypted = db.Column('notes', db.Text, nullable=True)
    follow_up_needed = db.Column(db.Boolean, default=False)
    follow_up_date = db.Column(db.DateTime, nullable=True)
    materials_sent = db.Column(db.Boolean, default=False)
    materials_desc = db.Column(db.Text, nullable=True)
    referral_made = db.Column(db.Boolean, default=False)
    referral_to = db.Column(db.String(200), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationships
    call_list_item = db.relationship('CallListItem', backref='attempts')
    patient = db.relationship('User', foreign_keys=[user_id])
    admin = db.relationship('User', foreign_keys=[admin_id])

    @property
    def notes(self) -> str:
        return decrypt_phi(self._notes_encrypted) if self._notes_encrypted else None

    @notes.setter
    def notes(self, value: str):
        self._notes_encrypted = encrypt_phi(value) if value else None

    def to_dict(self):
        return {
            'id': self.id,
            'call_list_item_id': self.call_list_item_id,
            'user_id': self.user_id,
            'admin_id': self.admin_id,
            'admin_name': self.admin.name if self.admin else 'Admin',
            'outcome': self.outcome,
            'notes': self.notes,
            'follow_up_needed': self.follow_up_needed,
            'follow_up_date': self.follow_up_date.isoformat() if self.follow_up_date else None,
            'materials_sent': self.materials_sent,
            'materials_desc': self.materials_desc,
            'referral_made': self.referral_made,
            'referral_to': self.referral_to,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f'<CallAttempt {self.id} outcome={self.outcome}>'
