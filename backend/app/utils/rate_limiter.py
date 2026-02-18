"""
Persistent DB-backed rate limiter for API endpoints.
"""
from datetime import datetime, timedelta, timezone
from functools import wraps
from flask import request, jsonify


class DBRateLimiter:
    """Database-backed rate limiter that persists across server restarts."""

    def __init__(self, max_attempts=5, window_seconds=60, endpoint_name='default'):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self.endpoint_name = endpoint_name

    def is_limited(self, key):
        from app.models.rate_limit_entry import RateLimitEntry
        cutoff = datetime.now(timezone.utc) - timedelta(seconds=self.window_seconds)
        count = RateLimitEntry.query.filter(
            RateLimitEntry.key == key,
            RateLimitEntry.endpoint == self.endpoint_name,
            RateLimitEntry.timestamp > cutoff
        ).count()
        return count >= self.max_attempts

    def record(self, key):
        from app import db
        from app.models.rate_limit_entry import RateLimitEntry
        entry = RateLimitEntry(
            key=key,
            endpoint=self.endpoint_name,
            timestamp=datetime.now(timezone.utc)
        )
        db.session.add(entry)
        db.session.commit()


# Global login limiter: 5 attempts per minute per IP
login_limiter = DBRateLimiter(max_attempts=5, window_seconds=60, endpoint_name='login')

# Registration limiter: 3 attempts per minute per IP
registration_limiter = DBRateLimiter(max_attempts=3, window_seconds=60, endpoint_name='registration')

# MFA verification limiter: 5 attempts per 10 minutes per IP
mfa_verify_limiter = DBRateLimiter(max_attempts=5, window_seconds=600, endpoint_name='mfa_verify')


def rate_limit(limiter):
    """Decorator factory to rate-limit an endpoint by client IP using a given limiter."""
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            client_ip = request.remote_addr or 'unknown'
            if limiter.is_limited(client_ip):
                return jsonify({'error': 'Too many requests. Try again later.'}), 429
            limiter.record(client_ip)
            return f(*args, **kwargs)
        return wrapper
    return decorator


def rate_limit_login(f):
    """Decorator to rate-limit login by client IP."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        client_ip = request.remote_addr or 'unknown'
        if login_limiter.is_limited(client_ip):
            return jsonify({'error': 'Too many login attempts. Try again later.'}), 429
        login_limiter.record(client_ip)
        return f(*args, **kwargs)
    return wrapper
