"""
User model with encrypted PHI fields.
"""
import json
import logging
from datetime import datetime
from app import db
from app.utils.encryption import encrypt_phi, decrypt_phi, hash_email

logger = logging.getLogger(__name__)


class User(db.Model):
    """
    User model storing consumer information.
    PHI fields (name, email, dob, phone, address, medications) are encrypted at rest.
    """
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)

    # Encrypted PHI fields (stored as encrypted base64 strings)
    _name_encrypted = db.Column('name', db.Text, nullable=False)
    _email_encrypted = db.Column('email', db.Text, nullable=False, unique=True)
    _dob_encrypted = db.Column('dob', db.Text, nullable=True)
    _email_hash = db.Column('email_hash', db.String(64), nullable=True, index=True)
    _phone_encrypted = db.Column('phone', db.Text, nullable=True)
    _address_encrypted = db.Column('address', db.Text, nullable=True)
    _medications_encrypted = db.Column('medications', db.Text, nullable=True)

    # Non-PHI demographic fields
    gender = db.Column(db.String(50), nullable=True)
    race = db.Column(db.String(100), nullable=True)
    ethnicity = db.Column(db.String(100), nullable=True)
    work_status = db.Column(db.String(50), nullable=True)
    rank = db.Column(db.String(100), nullable=True)
    height_inches = db.Column(db.Integer, nullable=True)
    weight_lbs = db.Column(db.Integer, nullable=True)
    chronic_conditions = db.Column(db.Text, nullable=True)  # JSON array
    has_high_blood_pressure = db.Column(db.Boolean, nullable=True)
    smoking_status = db.Column(db.String(100), nullable=True)
    on_bp_medication = db.Column(db.Boolean, nullable=True)
    missed_doses = db.Column(db.Integer, nullable=True)

    # Lifestyle fields
    exercise_days_per_week = db.Column(db.Integer, nullable=True)
    exercise_minutes_per_session = db.Column(db.Integer, nullable=True)
    food_frequency = db.Column(db.Text, nullable=True)  # JSON object
    financial_stress = db.Column(db.String(50), nullable=True)
    stress_level = db.Column(db.String(50), nullable=True)
    loneliness = db.Column(db.String(50), nullable=True)
    sleep_quality = db.Column(db.Integer, nullable=True)

    # Non-PHI fields
    union_id = db.Column(db.Integer, db.ForeignKey('unions.id'), nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    is_approved = db.Column(db.Boolean, default=False)
    is_admin = db.Column(db.Boolean, default=False)
    is_email_verified = db.Column(db.Boolean, default=False)
    is_mfa_enabled = db.Column(db.Boolean, default=False)
    is_flagged = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    readings = db.relationship('BloodPressureReading', backref='user', lazy='dynamic')
    union = db.relationship('Union', backref='users')

    # PHI property: name
    @property
    def name(self) -> str:
        return decrypt_phi(self._name_encrypted) if self._name_encrypted else None

    @name.setter
    def name(self, value: str):
        self._name_encrypted = encrypt_phi(value) if value else None

    # PHI property: email
    @property
    def email(self) -> str:
        return decrypt_phi(self._email_encrypted) if self._email_encrypted else None

    @email.setter
    def email(self, value: str):
        self._email_encrypted = encrypt_phi(value) if value else None
        self._email_hash = hash_email(value) if value else None

    # PHI property: date of birth
    @property
    def dob(self) -> str:
        return decrypt_phi(self._dob_encrypted) if self._dob_encrypted else None

    @dob.setter
    def dob(self, value: str):
        self._dob_encrypted = encrypt_phi(value) if value else None

    # PHI property: phone
    @property
    def phone(self) -> str:
        return decrypt_phi(self._phone_encrypted) if self._phone_encrypted else None

    @phone.setter
    def phone(self, value: str):
        self._phone_encrypted = encrypt_phi(value) if value else None

    # PHI property: address
    @property
    def address(self) -> str:
        return decrypt_phi(self._address_encrypted) if self._address_encrypted else None

    @address.setter
    def address(self, value: str):
        self._address_encrypted = encrypt_phi(value) if value else None

    # PHI property: medications
    @property
    def medications(self) -> str:
        return decrypt_phi(self._medications_encrypted) if self._medications_encrypted else None

    @medications.setter
    def medications(self, value: str):
        self._medications_encrypted = encrypt_phi(value) if value else None

    def to_dict(self, include_phi=False):
        """Convert to dictionary. Only include PHI if explicitly requested.
        Wraps PHI decryption in try/except so one bad record doesn't crash the list."""
        data = {
            'id': self.id,
            'union_id': self.union_id,
            'union_name': self.union.name if self.union else None,
            'is_active': self.is_active,
            'is_approved': self.is_approved,
            'is_email_verified': self.is_email_verified,
            'is_flagged': self.is_flagged,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'gender': self.gender,
            'race': self.race,
            'ethnicity': self.ethnicity,
            'work_status': self.work_status,
            'rank': self.rank,
            'height_inches': self.height_inches,
            'weight_lbs': self.weight_lbs,
            'chronic_conditions': json.loads(self.chronic_conditions) if self.chronic_conditions else [],
            'has_high_blood_pressure': self.has_high_blood_pressure,
            'smoking_status': self.smoking_status,
            'on_bp_medication': self.on_bp_medication,
            'missed_doses': self.missed_doses,
            # Lifestyle fields
            'exercise_days_per_week': self.exercise_days_per_week,
            'exercise_minutes_per_session': self.exercise_minutes_per_session,
            'food_frequency': json.loads(self.food_frequency) if self.food_frequency else None,
            'financial_stress': self.financial_stress,
            'stress_level': self.stress_level,
            'loneliness': self.loneliness,
            'sleep_quality': self.sleep_quality,
        }
        if include_phi:
            # Wrap each PHI field individually so one decryption failure
            # doesn't prevent the rest of the record from loading.
            phi_fields = {
                'name': 'name',
                'email': 'email',
                'dob': 'dob',
                'phone': 'phone',
                'address': 'address',
                'medications': 'medications',
            }
            for key, prop in phi_fields.items():
                try:
                    data[key] = getattr(self, prop)
                except Exception:
                    logger.error(
                        'Decryption error for user_id=%s field=%s', self.id, key,
                        exc_info=True,
                    )
                    data[key] = None
        return data

    def requires_mfa_setup(self):
        """True if user is admin and hasn't set up MFA yet."""
        return self.is_admin and not self.is_mfa_enabled

    def requires_mfa(self):
        """True if user has an active MfaSecret."""
        return self.mfa_secret is not None and self.mfa_secret.is_active

    @staticmethod
    def find_by_email(email: str):
        """Find a user by email using deterministic HMAC hash for lookup."""
        email_hash = hash_email(email)
        return User.query.filter_by(_email_hash=email_hash).first()

    def __repr__(self):
        return f'<User {self.id}>'
