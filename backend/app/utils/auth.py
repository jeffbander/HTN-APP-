"""
Authentication utilities for JWT tokens.
"""
import os
import secrets
import jwt
from datetime import datetime, timedelta
from functools import wraps
from flask import request, jsonify, g


def generate_single_use_token(user_id: int, email: str) -> str:
    """
    Generate a single-use JWT token for a user.
    Token expires in 1 hour.
    """
    secret = os.getenv('JWT_SECRET_KEY')
    if not secret:
        raise RuntimeError('JWT_SECRET_KEY environment variable is required')
    expires = int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', 3600))

    payload = {
        'user_id': user_id,
        'email': email,
        'jti': secrets.token_hex(16),  # Unique token ID
        'exp': datetime.utcnow() + timedelta(seconds=expires),
        'iat': datetime.utcnow()
    }

    return jwt.encode(payload, secret, algorithm='HS256')


def decode_token(token: str) -> dict:
    """Decode and validate a JWT token."""
    secret = os.getenv('JWT_SECRET_KEY')
    if not secret:
        raise RuntimeError('JWT_SECRET_KEY environment variable is required')
    try:
        payload = jwt.decode(token, secret, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


# Endpoints that don't require email verification
_EMAIL_VERIFY_ALLOWLIST = {
    'consumer.verify_email',
    'consumer.resend_verification',
    'consumer.logout',
    'consumer.setup_mfa',
    'consumer.confirm_mfa_setup',
}


def token_required(f):
    """Decorator to require valid JWT token for a route.

    Also checks:
    - Token has not been revoked (logout)
    - User account is still active (admin deactivation)
    - User email is verified (blocks unverified users from most endpoints)
    """
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'error': 'Missing authorization header'}), 401

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return jsonify({'error': 'Invalid authorization header format'}), 401

        token = parts[1]
        payload = decode_token(token)
        if not payload:
            return jsonify({'error': 'Invalid or expired token'}), 401

        jti = payload.get('jti')

        # Check if token has been revoked
        from app.models.revoked_token import RevokedToken
        if RevokedToken.is_token_revoked(jti):
            return jsonify({'error': 'Token has been revoked'}), 401

        # Check if user is still active
        from app.models.user import User
        user = User.query.get(payload.get('user_id'))
        if not user or not user.is_active:
            return jsonify({'error': 'Account is deactivated'}), 401

        # Store user info in flask g object
        g.user_id = payload.get('user_id')
        g.user_email = payload.get('email')
        g.token_jti = jti
        g.token_exp = payload.get('exp')

        # Check email verification (skip for allowlisted endpoints)
        if request.endpoint not in _EMAIL_VERIFY_ALLOWLIST:
            if not user.is_email_verified:
                return jsonify({'error': 'Email not verified'}), 403

        return f(*args, **kwargs)
    return wrapper
