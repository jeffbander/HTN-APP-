"""
Email Template model — pre-built templates for patient outreach emails.
"""
from datetime import datetime
from app import db


class EmailTemplate(db.Model):
    """
    Stores reusable email templates for patient outreach.
    Supports placeholders like {{patient_name}} that get replaced at send time.
    """
    __tablename__ = 'email_templates'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    subject = db.Column(db.String(500), nullable=False)
    body = db.Column(db.Text, nullable=False)
    list_type = db.Column(db.String(20), nullable=False, default='all')  # nurse | coach | no_reading | all
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'subject': self.subject,
            'body': self.body,
            'list_type': self.list_type,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f'<EmailTemplate {self.id} name={self.name}>'
