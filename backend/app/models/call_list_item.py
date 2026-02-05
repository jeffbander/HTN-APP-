"""
Call List Item model — tracks patients who need outreach calls.
"""
from datetime import datetime
from app import db


class CallListItem(db.Model):
    """
    Represents a patient on one of the three call lists (nurse, coach, no_reading).
    Tracks status, priority, follow-up scheduling, and cooldown after auto-close.
    """
    __tablename__ = 'call_list_items'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    list_type = db.Column(db.String(20), nullable=False, index=True)  # nurse | coach | no_reading
    status = db.Column(db.String(10), nullable=False, default='open', index=True)  # open | closed
    close_reason = db.Column(db.String(30), nullable=True)  # resolved | not_needed | auto_closed_3_attempts | other
    close_note = db.Column(db.Text, nullable=True)
    priority = db.Column(db.String(10), nullable=False, default='medium')  # high | medium | low
    priority_title = db.Column(db.String(200), nullable=True)
    priority_detail = db.Column(db.Text, nullable=True)
    cooldown_until = db.Column(db.DateTime, nullable=True)
    follow_up_date = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    closed_at = db.Column(db.DateTime, nullable=True)
    closed_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)

    # Relationships
    patient = db.relationship('User', foreign_keys=[user_id], backref='call_list_items')
    closer = db.relationship('User', foreign_keys=[closed_by])

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'list_type': self.list_type,
            'status': self.status,
            'close_reason': self.close_reason,
            'close_note': self.close_note,
            'priority': self.priority,
            'priority_title': self.priority_title,
            'priority_detail': self.priority_detail,
            'cooldown_until': self.cooldown_until.isoformat() if self.cooldown_until else None,
            'follow_up_date': self.follow_up_date.isoformat() if self.follow_up_date else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'closed_at': self.closed_at.isoformat() if self.closed_at else None,
            'closed_by': self.closed_by,
        }

    def __repr__(self):
        return f'<CallListItem {self.id} user={self.user_id} type={self.list_type}>'
