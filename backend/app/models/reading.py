"""
Blood Pressure Reading model.
"""
from datetime import datetime
from app import db


class BloodPressureReading(db.Model):
    """
    Blood pressure reading model.
    Readings are linked to users but individual values are not considered
    direct identifiers - the user linkage provides the PHI context.
    """
    __tablename__ = 'blood_pressure_readings'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)

    # Blood pressure values
    systolic = db.Column(db.Integer, nullable=False)
    diastolic = db.Column(db.Integer, nullable=False)
    heart_rate = db.Column(db.Integer, nullable=True)

    # Timestamps
    reading_date = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Device info (non-PHI)
    device_id = db.Column(db.String(255), nullable=True)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'systolic': self.systolic,
            'diastolic': self.diastolic,
            'heart_rate': self.heart_rate,
            'reading_date': self.reading_date.isoformat() if self.reading_date else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

    def __repr__(self):
        return f'<BloodPressureReading {self.id}: {self.systolic}/{self.diastolic}>'
