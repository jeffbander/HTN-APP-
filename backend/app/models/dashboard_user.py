"""
DashboardUser model for admin dashboard RBAC.
Separate from consumer User model — stores dashboard staff accounts with role-based access.
"""
import bcrypt
from datetime import datetime
from app import db


DASHBOARD_ROLES = ['super_admin', 'union_leader', 'shipping_company', 'nurse_coach']


class DashboardUser(db.Model):
    """Admin dashboard user with role-based access control."""
    __tablename__ = 'dashboard_users'

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), nullable=False, unique=True, index=True)
    name = db.Column(db.String(255), nullable=False)
    password_hash = db.Column(db.String(255), nullable=True)

    # RBAC role
    role = db.Column(db.String(50), nullable=False, default='nurse_coach')

    # Optional: which union this user belongs to (for union_leader role)
    union_id = db.Column(db.Integer, db.ForeignKey('unions.id'), nullable=True)

    # Status
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    is_email_verified = db.Column(db.Boolean, default=False, nullable=False)
    is_mfa_enabled = db.Column(db.Boolean, default=False, nullable=False)

    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login_at = db.Column(db.DateTime, nullable=True)

    # Relationships
    union = db.relationship('Union', backref='dashboard_users')

    def set_password(self, password):
        """Hash and store a password."""
        self.password_hash = bcrypt.hashpw(
            password.encode('utf-8'), bcrypt.gensalt()
        ).decode('utf-8')

    def check_password(self, password):
        """Verify a password against the stored hash."""
        if not self.password_hash:
            return False
        return bcrypt.checkpw(
            password.encode('utf-8'),
            self.password_hash.encode('utf-8'),
        )

    def has_role(self, *roles):
        """Check if user has one of the given roles."""
        return self.role in roles

    def to_dict(self):
        return {
            'id': self.id,
            'email': self.email,
            'name': self.name,
            'role': self.role,
            'union_id': self.union_id,
            'is_active': self.is_active,
            'is_email_verified': self.is_email_verified,
            'is_mfa_enabled': self.is_mfa_enabled,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_login_at': self.last_login_at.isoformat() if self.last_login_at else None,
        }

    def __repr__(self):
        return f'<DashboardUser {self.id} {self.email} role={self.role}>'
