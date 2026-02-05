"""
CuffRequest model for tracking blood pressure cuff shipment requests.
"""
from datetime import datetime
from app import db
from app.utils.encryption import encrypt_phi, decrypt_phi


class CuffRequest(db.Model):
    """
    Model for tracking user requests for blood pressure cuffs.
    Shipping address is encrypted as PHI.
    """
    __tablename__ = 'cuff_requests'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    # Encrypted shipping address (PHI)
    _address_encrypted = db.Column('shipping_address', db.Text, nullable=False)

    # Status: pending, approved, shipped, delivered, cancelled
    status = db.Column(db.String(50), default='pending', nullable=False)

    # Tracking information
    tracking_number = db.Column(db.String(100), nullable=True)
    carrier = db.Column(db.String(50), nullable=True)

    # Admin actions
    approved_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    approved_at = db.Column(db.DateTime, nullable=True)
    shipped_by = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    shipped_at = db.Column(db.DateTime, nullable=True)

    # Notes
    admin_notes = db.Column(db.Text, nullable=True)

    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = db.relationship('User', foreign_keys=[user_id], backref='cuff_requests')
    approved_by_user = db.relationship('User', foreign_keys=[approved_by])
    shipped_by_user = db.relationship('User', foreign_keys=[shipped_by])

    # PHI property: shipping address
    @property
    def shipping_address(self) -> str:
        return decrypt_phi(self._address_encrypted) if self._address_encrypted else None

    @shipping_address.setter
    def shipping_address(self, value: str):
        self._address_encrypted = encrypt_phi(value) if value else None

    def to_dict(self, include_address=False):
        """Convert to dictionary."""
        data = {
            'id': self.id,
            'user_id': self.user_id,
            'status': self.status,
            'tracking_number': self.tracking_number,
            'carrier': self.carrier,
            'approved_by': self.approved_by,
            'approved_at': self.approved_at.isoformat() if self.approved_at else None,
            'shipped_by': self.shipped_by,
            'shipped_at': self.shipped_at.isoformat() if self.shipped_at else None,
            'admin_notes': self.admin_notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }

        if include_address:
            try:
                data['shipping_address'] = self.shipping_address
            except Exception:
                data['shipping_address'] = None

        return data

    def __repr__(self):
        return f'<CuffRequest {self.id} user={self.user_id} status={self.status}>'
