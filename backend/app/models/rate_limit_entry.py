"""
Persistent rate limit entry model for DB-backed rate limiting.
"""
from datetime import datetime, timedelta
from app import db


class RateLimitEntry(db.Model):
    """Stores rate limit attempts in the database for persistence across restarts."""
    __tablename__ = 'rate_limit_entries'

    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(255), nullable=False, index=True)
    endpoint = db.Column(db.String(255), nullable=False, index=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        db.Index('ix_rate_limit_key_endpoint_ts', 'key', 'endpoint', 'timestamp'),
    )

    @staticmethod
    def cleanup_older_than(seconds):
        """Delete entries older than the given number of seconds."""
        cutoff = datetime.utcnow() - timedelta(seconds=seconds)
        count = RateLimitEntry.query.filter(
            RateLimitEntry.timestamp < cutoff
        ).delete()
        db.session.commit()
        return count

    def __repr__(self):
        return f'<RateLimitEntry {self.key}:{self.endpoint}>'
