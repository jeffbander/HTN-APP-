"""
Union model for organizing users.
"""
from datetime import datetime
from app import db


class Union(db.Model):
    """Union/organization that users belong to."""
    __tablename__ = 'unions'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'is_active': self.is_active
        }

    def __repr__(self):
        return f'<Union {self.id}: {self.name}>'
