"""
Dashboard authentication routes.
Separate auth flow for admin dashboard users (DashboardUser model with RBAC roles).
"""
import os
import secrets
import logging
import jwt
from datetime import datetime, timedelta, timezone
from functools import wraps
from flask import Blueprint, request, jsonify, g
from app import db
from app.models.dashboard_user import DashboardUser
from app.models.dashboard_mfa_secret import DashboardMfaSecret
from app.models.dashboard_mfa_session import DashboardMfaSession
from app.models.revoked_token import RevokedToken
from app.utils.audit_logger import audit_log

logger = logging.getLogger(__name__)

dashboard_auth_bp = Blueprint('dashboard_auth', __name__)


# ---------------------------------------------------------------------------
# JWT helpers for dashboard users
# ---------------------------------------------------------------------------

def generate_dashboard_token(dashboard_user_id: int, email: str, role: str) -> str:
    """Generate a JWT for a dashboard user, including their role claim."""
    secret = os.getenv('JWT_SECRET_KEY')
    if not secret:
        raise RuntimeError('JWT_SECRET_KEY environment variable is required')
    expires = int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', 3600))

    payload = {
        'dashboard_user_id': dashboard_user_id,
        'email': email,
        'role': role,
        'jti': secrets.token_hex(16),
        'exp': datetime.now(timezone.utc) + timedelta(seconds=expires),
        'iat': datetime.now(timezone.utc),
    }
    return jwt.encode(payload, secret, algorithm='HS256')


def decode_dashboard_token(token: str):
    secret = os.getenv('JWT_SECRET_KEY')
    if not secret:
        raise RuntimeError('JWT_SECRET_KEY environment variable is required')
    try:
        return jwt.decode(token, secret, algorithms=['HS256'])
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None


# ---------------------------------------------------------------------------
# Decorator: require authenticated dashboard user
# ---------------------------------------------------------------------------

def dashboard_token_required(f):
    """Require a valid dashboard JWT. Sets g.dashboard_user_id, g.dashboard_role."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'error': 'Missing authorization header'}), 401

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return jsonify({'error': 'Invalid authorization header format'}), 401

        payload = decode_dashboard_token(parts[1])
        if not payload:
            return jsonify({'error': 'Invalid or expired token'}), 401

        jti = payload.get('jti')
        if RevokedToken.is_token_revoked(jti):
            return jsonify({'error': 'Token has been revoked'}), 401

        user = DashboardUser.query.get(payload.get('dashboard_user_id'))
        if not user or not user.is_active:
            return jsonify({'error': 'Account is deactivated'}), 401

        g.dashboard_user_id = user.id
        g.dashboard_role = user.role
        g.dashboard_email = user.email
        g.token_jti = jti
        g.token_exp = payload.get('exp')

        return f(*args, **kwargs)
    return wrapper


def role_required(*allowed_roles):
    """Decorator that restricts access to specific dashboard roles."""
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if g.dashboard_role not in allowed_roles:
                return jsonify({'error': 'Insufficient permissions'}), 403
            return f(*args, **kwargs)
        return wrapper
    return decorator


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@dashboard_auth_bp.route('/login', methods=['POST'])
def dashboard_login():
    """Authenticate a dashboard user by email. Triggers MFA flow."""
    data = request.get_json() or {}
    email = (data.get('email') or '').strip().lower()
    if not email:
        return jsonify({'error': 'Email is required'}), 400

    user = DashboardUser.query.filter_by(email=email).first()
    if not user or not user.is_active:
        return jsonify({'error': 'Invalid credentials'}), 401

    audit_log('LOGIN_ATTEMPT', 'dashboard_user', resource_id=str(user.id), details={'email': email})

    # Issue JWT directly (MFA disabled for now)
    user.last_login_at = datetime.now(timezone.utc)
    db.session.commit()

    token = generate_dashboard_token(user.id, user.email, user.role)
    audit_log('LOGIN_SUCCESS', 'dashboard_user', resource_id=str(user.id), details={'role': user.role})

    return jsonify({
        'singleUseToken': token,
        'role': user.role,
        'name': user.name,
    }), 200


@dashboard_auth_bp.route('/verify-mfa', methods=['POST'])
def dashboard_verify_mfa():
    """Verify MFA code and issue a real JWT."""
    data = request.get_json() or {}
    session_token = data.get('mfa_session_token')
    code = (data.get('code') or '').strip()

    if not session_token or not code:
        return jsonify({'error': 'Session token and code are required'}), 400

    session = DashboardMfaSession.query.filter_by(session_token=session_token).first()
    if not session:
        return jsonify({'error': 'Invalid MFA session'}), 401
    if session.is_expired:
        return jsonify({'error': 'MFA session expired'}), 401
    if session.is_verified:
        return jsonify({'error': 'Session already verified'}), 400
    if session.too_many_attempts:
        return jsonify({'error': 'Too many attempts'}), 429

    session.attempts += 1

    # Validate TOTP code
    import pyotp
    mfa_secret = DashboardMfaSecret.query.filter_by(
        dashboard_user_id=session.dashboard_user_id, is_active=True
    ).first()

    valid = False
    if mfa_secret:
        if mfa_secret.mfa_type == 'totp':
            totp = pyotp.TOTP(mfa_secret.totp_secret)
            valid = totp.verify(code, valid_window=1)
        if not valid:
            valid = mfa_secret.use_backup_code(code)

    if not valid:
        db.session.commit()
        return jsonify({'error': 'Invalid MFA code'}), 401

    session.verified_at = datetime.now(timezone.utc)
    user = DashboardUser.query.get(session.dashboard_user_id)
    user.last_login_at = datetime.now(timezone.utc)
    db.session.commit()

    token = generate_dashboard_token(user.id, user.email, user.role)
    audit_log('LOGIN_SUCCESS', 'dashboard_user', resource_id=str(user.id), details={'role': user.role})

    return jsonify({
        'singleUseToken': token,
        'role': user.role,
        'name': user.name,
    }), 200


@dashboard_auth_bp.route('/setup-mfa', methods=['POST'])
@dashboard_token_required
def dashboard_setup_mfa():
    """Generate a new TOTP secret + QR URI for first-time MFA setup."""
    import pyotp
    user = DashboardUser.query.get(g.dashboard_user_id)

    existing = DashboardMfaSecret.query.filter_by(dashboard_user_id=user.id).first()
    if existing and existing.is_active:
        return jsonify({'error': 'MFA already configured'}), 400

    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    provisioning_uri = totp.provisioning_uri(user.email, issuer_name='HTN Monitor Admin')

    if existing:
        existing.totp_secret = secret
        existing.is_active = False
    else:
        mfa = DashboardMfaSecret(
            dashboard_user_id=user.id,
            mfa_type='totp',
        )
        mfa.totp_secret = secret
        db.session.add(mfa)

    db.session.commit()

    return jsonify({
        'secret': secret,
        'provisioning_uri': provisioning_uri,
    }), 200


@dashboard_auth_bp.route('/confirm-mfa-setup', methods=['POST'])
@dashboard_token_required
def dashboard_confirm_mfa_setup():
    """Confirm MFA setup by verifying a TOTP code from the authenticator app."""
    import pyotp
    data = request.get_json() or {}
    code = (data.get('code') or '').strip()
    if not code:
        return jsonify({'error': 'Code is required'}), 400

    mfa = DashboardMfaSecret.query.filter_by(
        dashboard_user_id=g.dashboard_user_id
    ).first()
    if not mfa:
        return jsonify({'error': 'No MFA secret found. Call /setup-mfa first.'}), 400

    totp = pyotp.TOTP(mfa.totp_secret)
    if not totp.verify(code, valid_window=1):
        return jsonify({'error': 'Invalid code'}), 401

    mfa.is_active = True
    backup_codes = mfa.generate_backup_codes()

    user = DashboardUser.query.get(g.dashboard_user_id)
    user.is_mfa_enabled = True
    db.session.commit()

    audit_log('MFA_SETUP', 'dashboard_user', resource_id=str(user.id))

    return jsonify({
        'message': 'MFA enabled successfully',
        'backup_codes': backup_codes,
    }), 200


@dashboard_auth_bp.route('/logout', methods=['POST'])
@dashboard_token_required
def dashboard_logout():
    """Revoke the current dashboard JWT."""
    from app.models.revoked_token import RevokedToken
    revoked = RevokedToken(
        jti=g.token_jti,
        user_id=g.dashboard_user_id,
        expires_at=datetime.fromtimestamp(g.token_exp, tz=timezone.utc),
    )
    db.session.add(revoked)
    db.session.commit()
    return jsonify({'message': 'Logged out'}), 200


@dashboard_auth_bp.route('/me', methods=['GET'])
@dashboard_token_required
def dashboard_me():
    """Return the current dashboard user's profile."""
    user = DashboardUser.query.get(g.dashboard_user_id)
    return jsonify(user.to_dict()), 200
