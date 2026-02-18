"""
Consumer API routes.
"""
import json
from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify, g
import pyotp
from app import db
from app.models import User, BloodPressureReading, Union, CuffRequest, DeviceToken, MfaSecret, MfaSession
from app.models.revoked_token import RevokedToken
from app.models.email_verification import EmailVerification
from app.utils.auth import generate_single_use_token, token_required, decode_token
from app.utils.audit_logger import audit_log, audit_phi_access
from app.utils.encryption import hash_email
from app.utils.validators import validate_registration, validate_reading, validate_profile_update
from app.utils.rate_limiter import rate_limit_login, rate_limit, registration_limiter, mfa_verify_limiter
from app.utils.email_sender import send_verification_email, send_login_otp_email

consumer_bp = Blueprint('consumer', __name__)


@consumer_bp.route('/unions', methods=['GET'])
def get_unions():
    """Return unions as {stringId: name} for Flutter int.parse(key) contract."""
    unions = Union.query.filter_by(is_active=True).all()
    return jsonify({str(u.id): u.name for u in unions}), 200


@consumer_bp.route('/register', methods=['POST'])
@rate_limit(registration_limiter)
def register():
    """Register a new consumer user with encrypted PHI."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    errors = validate_registration(data)
    if errors:
        return jsonify({'error': errors}), 400

    # Check for existing user
    email = data['email'].strip().lower()
    existing = User.find_by_email(email)
    if existing:
        return jsonify({'error': 'A user with this email already exists'}), 409

    # Validate union exists
    union_id = int(data['union_id'])
    union = Union.query.get(union_id)
    if not union:
        return jsonify({'error': 'Invalid union ID'}), 400

    user = User()
    user.name = data['name'].strip()
    user.email = email
    user.dob = data.get('dob')
    user.union_id = union_id

    # New demographic & health fields
    user.gender = data.get('gender')
    user.race = data.get('race')
    user.ethnicity = data.get('ethnicity')
    user.phone = data.get('phone')
    user.address = data.get('address')
    user.work_status = data.get('work_status')
    user.rank = data.get('rank')

    # Height: accept height_inches directly, or compute from height_feet + height_inches
    if data.get('height_inches') is not None:
        user.height_inches = int(data['height_inches'])
    elif data.get('height_feet') is not None:
        feet = int(data.get('height_feet', 0))
        inches = int(data.get('height_inches_part', 0))
        user.height_inches = feet * 12 + inches

    if data.get('weight_lbs') is not None:
        user.weight_lbs = int(data['weight_lbs'])
    elif data.get('weight') is not None:
        user.weight_lbs = int(data['weight'])

    # Chronic conditions — accept list or JSON string
    cc = data.get('chronic_conditions')
    if cc is not None:
        if isinstance(cc, list):
            user.chronic_conditions = json.dumps(cc)
        elif isinstance(cc, str):
            user.chronic_conditions = cc
    user.has_high_blood_pressure = data.get('has_high_blood_pressure')
    user.medications = data.get('medications')
    user.smoking_status = data.get('smoking_status')
    user.on_bp_medication = data.get('on_bp_medication')
    if data.get('missed_doses') is not None:
        user.missed_doses = int(data['missed_doses'])

    db.session.add(user)
    db.session.flush()

    try:
        # Send email verification code
        verification = EmailVerification.create_for_user(user.id)
        send_verification_email(email, verification.code)

        token = generate_single_use_token(user.id, email)

        audit_log('CREATE', 'user', resource_id=str(user.id),
                  details={'action': 'registration'}, user_id=str(user.id))

        db.session.commit()
    except Exception:
        db.session.rollback()
        return jsonify({'error': 'Registration failed. Please try again.'}), 500

    return jsonify({
        'singleUseToken': token,
        'userId': user.id
    }), 200


@consumer_bp.route('/login', methods=['POST'])
@rate_limit_login
def login():
    """Passwordless login by email. Returns token for approved users."""
    data = request.get_json()
    if not data or not data.get('email'):
        return jsonify({'error': 'Email is required'}), 400

    email = data['email'].strip().lower()
    email_hash = hash_email(email)
    user = User.find_by_email(email)

    # Generic response for cases where we must not reveal account status
    generic_mfa_response = jsonify({
        'mfa_required': True,
        'mfa_type': 'email',
        'message': 'If this email is registered, a login code has been sent. Please check your email.',
    }), 200

    if not user:
        audit_log('LOGIN_FAILED', 'user',
                  details={'reason': 'not_found', 'email_hash': email_hash})
        return generic_mfa_response

    if user.user_status == 'deactivated' or not user.is_active:
        audit_log('LOGIN_FAILED', 'user', resource_id=str(user.id),
                  details={'reason': 'deactivated', 'email_hash': email_hash},
                  user_id=str(user.id))
        return generic_mfa_response

    # Email verification required for users past the approval stage
    if not user.is_email_verified and user.user_status != 'pending_approval':
        audit_log('LOGIN_FAILED', 'user', resource_id=str(user.id),
                  details={'reason': 'email_not_verified', 'email_hash': email_hash},
                  user_id=str(user.id))
        return generic_mfa_response

    # MFA: admin users must set up MFA before proceeding
    if user.is_admin and not user.is_mfa_enabled:
        # Issue a temporary token scoped for MFA setup only
        temp_token = generate_single_use_token(user.id, email)
        audit_log('LOGIN', 'user', resource_id=str(user.id),
                  details={'action': 'login_mfa_setup_required'}, user_id=str(user.id))
        return jsonify({
            'mfa_setup_required': True,
            'tempToken': temp_token,
            'userId': user.id,
            'user_status': user.user_status,
        }), 200

    # MFA: if user has active MFA, require verification
    if user.requires_mfa():
        mfa_type = user.mfa_secret.mfa_type
        mfa_session = MfaSession.create_for_user(user.id, mfa_type=mfa_type)

        # For email MFA, send the OTP code
        if mfa_type == 'email':
            send_login_otp_email(email, mfa_session.otp_code)

        audit_log('LOGIN', 'user', resource_id=str(user.id),
                  details={'action': 'login_mfa_required', 'mfa_type': mfa_type},
                  user_id=str(user.id))
        return jsonify({
            'mfa_required': True,
            'mfa_type': mfa_type,
            'mfa_session_token': mfa_session.session_token,
            'user_status': user.user_status,
        }), 200

    # Email OTP for consumer logins (non-admin users)
    if not user.is_admin:
        mfa_session = MfaSession.create_for_user(user.id, mfa_type='email')
        send_login_otp_email(email, mfa_session.otp_code)

        audit_log('LOGIN', 'user', resource_id=str(user.id),
                  details={'action': 'login_mfa_required', 'mfa_type': 'email'},
                  user_id=str(user.id))
        return jsonify({
            'mfa_required': True,
            'mfa_type': 'email',
            'mfa_session_token': mfa_session.session_token,
            'user_status': user.user_status,
        }), 200

    token = generate_single_use_token(user.id, email)

    audit_log('LOGIN', 'user', resource_id=str(user.id),
              details={'action': 'login'}, user_id=str(user.id))

    return jsonify({
        'singleUseToken': token,
        'userId': user.id,
        'user_status': user.user_status,
    }), 200


@consumer_bp.route('/verify-mfa', methods=['POST'])
@rate_limit(mfa_verify_limiter)
def verify_mfa():
    """Verify MFA code (TOTP or email OTP) and issue full JWT."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    session_token = data.get('mfa_session_token')
    code = str(data.get('code', '')).strip()

    if not session_token or not code:
        return jsonify({'error': 'Session token and code are required'}), 400

    mfa_session = MfaSession.query.filter_by(session_token=session_token).first()
    if not mfa_session:
        return jsonify({'error': 'Invalid MFA session'}), 400

    if mfa_session.is_expired:
        audit_log('MFA_VERIFY_FAILED', 'user', resource_id=str(mfa_session.user_id),
                  details={'reason': 'session_expired'}, user_id=str(mfa_session.user_id))
        return jsonify({'error': 'MFA session expired. Please log in again.'}), 400

    if mfa_session.is_verified:
        return jsonify({'error': 'MFA session already verified'}), 400

    if mfa_session.too_many_attempts:
        audit_log('MFA_VERIFY_FAILED', 'user', resource_id=str(mfa_session.user_id),
                  details={'reason': 'too_many_attempts'}, user_id=str(mfa_session.user_id))
        return jsonify({'error': 'Too many failed attempts. Please log in again.'}), 429

    mfa_session.attempts += 1
    user = User.query.get(mfa_session.user_id)

    verified = False
    if mfa_session.mfa_type == 'totp' and user.mfa_secret:
        # Try TOTP code first, then backup code
        totp = pyotp.TOTP(user.mfa_secret.totp_secret)
        if totp.verify(code, valid_window=1):
            verified = True
        elif user.mfa_secret.use_backup_code(code):
            verified = True
    elif mfa_session.mfa_type == 'email':
        if mfa_session.otp_code and mfa_session.otp_code == code:
            verified = True

    if verified:
        mfa_session.verified_at = datetime.utcnow()
        if user.mfa_secret:
            user.mfa_secret.last_used_at = datetime.utcnow()
        db.session.commit()

        token = generate_single_use_token(user.id, user.email)
        audit_log('MFA_VERIFY_SUCCESS', 'user', resource_id=str(user.id),
                  details={'mfa_type': mfa_session.mfa_type}, user_id=str(user.id))
        return jsonify({
            'singleUseToken': token,
            'userId': user.id,
            'user_status': user.user_status,
        }), 200

    db.session.commit()
    audit_log('MFA_VERIFY_FAILED', 'user', resource_id=str(mfa_session.user_id),
              details={'reason': 'invalid_code', 'attempts': mfa_session.attempts},
              user_id=str(mfa_session.user_id))
    return jsonify({'error': 'Invalid verification code'}), 400


@consumer_bp.route('/setup-mfa', methods=['POST'])
@token_required
def setup_mfa():
    """Generate TOTP secret and backup codes for admin MFA setup."""
    user = User.query.get(g.user_id)
    if not user or not user.is_admin:
        return jsonify({'error': 'Admin access required'}), 403

    # Generate new TOTP secret
    secret = pyotp.random_base32()

    # Create or update MfaSecret (inactive until confirmed)
    mfa_secret = MfaSecret.query.filter_by(user_id=user.id).first()
    if not mfa_secret:
        mfa_secret = MfaSecret(user_id=user.id)
        db.session.add(mfa_secret)

    mfa_secret.totp_secret = secret
    mfa_secret.mfa_type = 'totp'
    mfa_secret.is_active = False
    backup_codes = mfa_secret.generate_backup_codes()
    db.session.commit()

    # Generate provisioning URI for QR code
    totp = pyotp.TOTP(secret)
    provisioning_uri = totp.provisioning_uri(
        name=user.email,
        issuer_name='HTN Monitor'
    )

    audit_log('MFA_SETUP_STARTED', 'user', resource_id=str(user.id),
              details={'action': 'mfa_setup_initiated'}, user_id=str(user.id))

    return jsonify({
        'secret': secret,
        'provisioning_uri': provisioning_uri,
        'backup_codes': backup_codes,
    }), 200


@consumer_bp.route('/confirm-mfa-setup', methods=['POST'])
@token_required
def confirm_mfa_setup():
    """Verify TOTP code from authenticator app to activate MFA."""
    data = request.get_json()
    if not data or not data.get('code'):
        return jsonify({'error': 'Verification code is required'}), 400

    user = User.query.get(g.user_id)
    if not user or not user.is_admin:
        return jsonify({'error': 'Admin access required'}), 403

    mfa_secret = MfaSecret.query.filter_by(user_id=user.id).first()
    if not mfa_secret:
        return jsonify({'error': 'MFA setup not initiated. Call /setup-mfa first.'}), 400

    code = str(data['code']).strip()
    totp = pyotp.TOTP(mfa_secret.totp_secret)

    if not totp.verify(code, valid_window=1):
        return jsonify({'error': 'Invalid verification code. Please try again.'}), 400

    mfa_secret.is_active = True
    user.is_mfa_enabled = True
    db.session.commit()

    audit_log('MFA_SETUP_COMPLETE', 'user', resource_id=str(user.id),
              details={'action': 'mfa_activated'}, user_id=str(user.id))

    return jsonify({'message': 'MFA enabled successfully'}), 200


@consumer_bp.route('/resend-mfa-code', methods=['POST'])
def resend_mfa_code():
    """Regenerate and resend email OTP for MFA verification."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    session_token = data.get('mfa_session_token')
    if not session_token:
        return jsonify({'error': 'Session token is required'}), 400

    mfa_session = MfaSession.query.filter_by(session_token=session_token).first()
    if not mfa_session:
        return jsonify({'error': 'Invalid MFA session'}), 400

    if mfa_session.is_expired or mfa_session.is_verified:
        return jsonify({'error': 'MFA session expired or already verified'}), 400

    if mfa_session.mfa_type != 'email':
        return jsonify({'error': 'Resend is only available for email MFA'}), 400

    # Regenerate OTP code and reset attempts
    import secrets as sec_module
    mfa_session.otp_code = str(sec_module.randbelow(1000000)).zfill(6)
    mfa_session.attempts = 0
    db.session.commit()

    user = User.query.get(mfa_session.user_id)
    send_login_otp_email(user.email, mfa_session.otp_code)

    audit_log('MFA_RESEND', 'user', resource_id=str(mfa_session.user_id),
              details={'action': 'mfa_code_resent'}, user_id=str(mfa_session.user_id))

    return jsonify({'message': 'Verification code resent'}), 200


@consumer_bp.route('/logout', methods=['POST'])
@token_required
def logout():
    """Revoke the current token (logout)."""
    revoked = RevokedToken(
        jti=g.token_jti,
        user_id=g.user_id,
        expires_at=datetime.utcfromtimestamp(g.token_exp)
    )
    db.session.add(revoked)
    db.session.commit()

    audit_log('LOGOUT', 'user', resource_id=str(g.user_id),
              details={'action': 'logout'})

    return jsonify({'message': 'Successfully logged out'}), 200


@consumer_bp.route('/verify-email', methods=['POST'])
@token_required
def verify_email():
    """Verify email with a 6-digit code."""
    data = request.get_json()
    if not data or not data.get('code'):
        return jsonify({'error': 'Verification code is required'}), 400

    code = str(data['code']).strip()
    if len(code) != 6 or not code.isdigit():
        return jsonify({'error': 'Invalid verification code format'}), 400

    verification = EmailVerification.query.filter_by(
        user_id=g.user_id,
        code=code,
        used_at=None
    ).filter(
        EmailVerification.expires_at > datetime.utcnow()
    ).first()

    if not verification:
        return jsonify({'error': 'Invalid or expired verification code'}), 400

    verification.used_at = datetime.utcnow()
    user = User.query.get(g.user_id)
    user.is_email_verified = True
    db.session.commit()

    audit_log('UPDATE', 'user', resource_id=str(g.user_id),
              details={'action': 'email_verified'})

    return jsonify({'message': 'Email verified successfully'}), 200


@consumer_bp.route('/resend-verification', methods=['POST'])
@token_required
def resend_verification():
    """Resend email verification code."""
    user = User.query.get(g.user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    if user.is_email_verified:
        return jsonify({'error': 'Email is already verified'}), 409

    verification = EmailVerification.create_for_user(user.id)
    send_verification_email(user.email, verification.code)

    audit_log('UPDATE', 'user', resource_id=str(g.user_id),
              details={'action': 'resend_verification'})

    return jsonify({'message': 'Verification code sent'}), 200


@consumer_bp.route('/readings', methods=['POST'])
@token_required
@audit_phi_access('CREATE', 'reading')
def create_reading():
    """Submit a blood pressure reading. Maps camelCase from Flutter to snake_case."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    errors = validate_reading(data)
    if errors:
        return jsonify({'error': errors}), 400

    try:
        reading_date = datetime.fromisoformat(data['readingDate'].replace('Z', '+00:00'))
    except (ValueError, AttributeError):
        return jsonify({'error': 'Invalid readingDate format'}), 400

    systolic = int(data['systolic'])
    diastolic = int(data['diastolic'])
    heart_rate = int(data['heartRate']) if data.get('heartRate') is not None else None

    # Deduplicate: reject if identical reading exists within 60 seconds
    from sqlalchemy import func
    window = timedelta(seconds=60)
    duplicate = BloodPressureReading.query.filter(
        BloodPressureReading.user_id == g.user_id,
        BloodPressureReading.systolic == systolic,
        BloodPressureReading.diastolic == diastolic,
        BloodPressureReading.reading_date.between(reading_date - window, reading_date + window)
    ).first()

    if duplicate:
        return jsonify(duplicate.to_dict()), 200  # Return existing, don't create duplicate

    reading = BloodPressureReading(
        user_id=g.user_id,
        systolic=systolic,
        diastolic=diastolic,
        heart_rate=heart_rate,
        reading_date=reading_date
    )

    db.session.add(reading)

    # Auto-transition: pending_first_reading → active on first reading
    user = User.query.get(g.user_id)
    if user and user.user_status == 'pending_first_reading':
        user.user_status = 'active'
        audit_log('UPDATE', 'user', resource_id=str(user.id),
                  details={'action': 'auto_status_transition', 'from': 'pending_first_reading', 'to': 'active'},
                  user_id=str(user.id))

    db.session.commit()

    return jsonify(reading.to_dict()), 200


@consumer_bp.route('/readings', methods=['GET'])
@token_required
@audit_phi_access('READ', 'reading')
def get_readings():
    """Return user's readings with pagination."""
    limit = request.args.get('limit', 50, type=int)
    offset = request.args.get('offset', 0, type=int)

    limit = min(limit, 200)

    readings = (BloodPressureReading.query
                .filter_by(user_id=g.user_id)
                .order_by(BloodPressureReading.reading_date.desc())
                .offset(offset)
                .limit(limit)
                .all())

    return jsonify([r.to_dict() for r in readings]), 200


@consumer_bp.route('/profile', methods=['GET'])
@token_required
@audit_phi_access('READ', 'user')
def get_profile():
    """Return the authenticated user's profile with PHI."""
    user = User.query.get(g.user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    return jsonify(user.to_dict(include_phi=True)), 200


@consumer_bp.route('/profile', methods=['PUT'])
@token_required
@audit_phi_access('UPDATE', 'user')
def update_profile():
    """Update the authenticated user's profile. Email cannot be changed."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    errors = validate_profile_update(data)
    if errors:
        return jsonify({'error': errors}), 400

    user = User.query.get(g.user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    changes = {}

    # PHI fields (encrypted via property setters)
    if 'name' in data:
        old_name = user.name
        user.name = data['name'].strip()
        changes['name'] = {'old': old_name, 'new': user.name}

    if 'phone' in data:
        old_phone = user.phone
        user.phone = data['phone'].strip() if data['phone'] else None
        changes['phone'] = {'old': old_phone, 'new': user.phone}

    if 'address' in data:
        old_address = user.address
        user.address = data['address'].strip() if data['address'] else None
        changes['address'] = {'old': old_address, 'new': user.address}

    if 'medications' in data:
        old_medications = user.medications
        user.medications = data['medications'].strip() if data['medications'] else None
        changes['medications'] = {'old': old_medications, 'new': user.medications}

    if 'dob' in data:
        old_dob = user.dob
        user.dob = data['dob'] if data['dob'] else None
        changes['dob'] = {'old': old_dob, 'new': user.dob}

    # Non-PHI demographic fields
    if 'gender' in data:
        changes['gender'] = {'old': user.gender, 'new': data['gender']}
        user.gender = data['gender']

    if 'race' in data:
        changes['race'] = {'old': user.race, 'new': data['race']}
        user.race = data['race']

    if 'ethnicity' in data:
        changes['ethnicity'] = {'old': user.ethnicity, 'new': data['ethnicity']}
        user.ethnicity = data['ethnicity']

    if 'work_status' in data:
        changes['work_status'] = {'old': user.work_status, 'new': data['work_status']}
        user.work_status = data['work_status']

    if 'rank' in data:
        changes['rank'] = {'old': user.rank, 'new': data['rank']}
        user.rank = data['rank']

    if 'height_inches' in data:
        changes['height_inches'] = {'old': user.height_inches, 'new': data['height_inches']}
        user.height_inches = int(data['height_inches']) if data['height_inches'] is not None else None

    if 'weight_lbs' in data:
        changes['weight_lbs'] = {'old': user.weight_lbs, 'new': data['weight_lbs']}
        user.weight_lbs = int(data['weight_lbs']) if data['weight_lbs'] is not None else None

    # Health fields
    if 'chronic_conditions' in data:
        cc = data['chronic_conditions']
        if isinstance(cc, list):
            user.chronic_conditions = json.dumps(cc)
        elif isinstance(cc, str):
            user.chronic_conditions = cc
        changes['chronic_conditions'] = {'updated': True}

    if 'has_high_blood_pressure' in data:
        changes['has_high_blood_pressure'] = {'old': user.has_high_blood_pressure, 'new': data['has_high_blood_pressure']}
        user.has_high_blood_pressure = data['has_high_blood_pressure']

    if 'smoking_status' in data:
        changes['smoking_status'] = {'old': user.smoking_status, 'new': data['smoking_status']}
        user.smoking_status = data['smoking_status']

    if 'on_bp_medication' in data:
        changes['on_bp_medication'] = {'old': user.on_bp_medication, 'new': data['on_bp_medication']}
        user.on_bp_medication = data['on_bp_medication']

    if 'missed_doses' in data:
        changes['missed_doses'] = {'old': user.missed_doses, 'new': data['missed_doses']}
        user.missed_doses = int(data['missed_doses']) if data['missed_doses'] is not None else None

    db.session.commit()

    audit_log('UPDATE', 'user', resource_id=str(g.user_id),
              details={'action': 'profile_update', 'fields_changed': list(changes.keys())},
              user_id=str(g.user_id))

    return jsonify(user.to_dict(include_phi=True)), 200


@consumer_bp.route('/profile/lifestyle', methods=['PUT'])
@token_required
@audit_phi_access('UPDATE', 'user')
def update_lifestyle():
    """Update lifestyle fields for the authenticated user."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    errors = validate_profile_update(data)
    if errors:
        return jsonify({'error': errors}), 400

    user = User.query.get(g.user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    changes = {}

    if 'exercise_days_per_week' in data:
        changes['exercise_days_per_week'] = {'old': user.exercise_days_per_week, 'new': data['exercise_days_per_week']}
        user.exercise_days_per_week = int(data['exercise_days_per_week']) if data['exercise_days_per_week'] is not None else None

    if 'exercise_minutes_per_session' in data:
        changes['exercise_minutes_per_session'] = {'old': user.exercise_minutes_per_session, 'new': data['exercise_minutes_per_session']}
        user.exercise_minutes_per_session = int(data['exercise_minutes_per_session']) if data['exercise_minutes_per_session'] is not None else None

    if 'food_frequency' in data:
        ff = data['food_frequency']
        if isinstance(ff, dict):
            user.food_frequency = json.dumps(ff)
        elif isinstance(ff, str):
            user.food_frequency = ff
        changes['food_frequency'] = {'updated': True}

    if 'financial_stress' in data:
        changes['financial_stress'] = {'old': user.financial_stress, 'new': data['financial_stress']}
        user.financial_stress = data['financial_stress']

    if 'stress_level' in data:
        changes['stress_level'] = {'old': user.stress_level, 'new': data['stress_level']}
        user.stress_level = data['stress_level']

    if 'loneliness' in data:
        changes['loneliness'] = {'old': user.loneliness, 'new': data['loneliness']}
        user.loneliness = data['loneliness']

    if 'sleep_quality' in data:
        changes['sleep_quality'] = {'old': user.sleep_quality, 'new': data['sleep_quality']}
        user.sleep_quality = int(data['sleep_quality']) if data['sleep_quality'] is not None else None

    db.session.commit()

    audit_log('UPDATE', 'user', resource_id=str(g.user_id),
              details={'action': 'lifestyle_update', 'fields_changed': list(changes.keys())},
              user_id=str(g.user_id))

    return jsonify(user.to_dict(include_phi=True)), 200


# ---------- Cuff Requests ----------

@consumer_bp.route('/cuff-request', methods=['POST'])
@token_required
@audit_phi_access('CREATE', 'cuff_request')
def create_cuff_request():
    """Submit a request for a blood pressure cuff."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    address = data.get('address', '').strip()
    if not address:
        return jsonify({'error': 'Shipping address is required'}), 400

    if len(address) > 500:
        return jsonify({'error': 'Address must be 500 characters or fewer'}), 400

    # Check for existing pending/approved/shipped request
    existing = CuffRequest.query.filter(
        CuffRequest.user_id == g.user_id,
        CuffRequest.status.in_(['pending', 'approved', 'shipped'])
    ).first()

    if existing:
        return jsonify({
            'error': 'You already have an active cuff request',
            'existing_request': existing.to_dict()
        }), 409

    cuff_request = CuffRequest(user_id=g.user_id)
    cuff_request.shipping_address = address

    db.session.add(cuff_request)

    # Auto-transition: move to pending_cuff when cuff is requested
    user = User.query.get(g.user_id)
    if user and user.user_status in ('pending_approval', 'pending_registration'):
        old_status = user.user_status
        user.user_status = 'pending_cuff'
        audit_log('UPDATE', 'user', resource_id=str(user.id),
                  details={'action': 'auto_status_transition', 'from': old_status, 'to': 'pending_cuff'},
                  user_id=str(user.id))

    db.session.commit()

    return jsonify(cuff_request.to_dict(include_address=True)), 201


@consumer_bp.route('/cuff-request', methods=['GET'])
@token_required
@audit_phi_access('READ', 'cuff_request')
def get_cuff_request():
    """Get the current user's most recent cuff request status."""
    cuff_request = CuffRequest.query.filter_by(user_id=g.user_id)\
        .order_by(CuffRequest.created_at.desc())\
        .first()

    if not cuff_request:
        return jsonify({'request': None, 'message': 'No cuff request found'}), 200

    return jsonify({
        'request': cuff_request.to_dict(include_address=True)
    }), 200


@consumer_bp.route('/cuff-request/<int:request_id>/received', methods=['PUT'])
@token_required
@audit_phi_access('UPDATE', 'cuff_request')
def mark_cuff_received(request_id):
    """Mark a cuff as received by the user."""
    cuff_request = CuffRequest.query.get(request_id)
    if not cuff_request:
        return jsonify({'error': 'Cuff request not found'}), 404

    if cuff_request.user_id != g.user_id:
        return jsonify({'error': 'Unauthorized'}), 403

    if cuff_request.status != 'shipped':
        return jsonify({'error': f'Cannot mark as received: status is {cuff_request.status}'}), 400

    cuff_request.status = 'delivered'

    # Auto-transition: pending_cuff → pending_first_reading when cuff is received
    user = User.query.get(g.user_id)
    if user and user.user_status == 'pending_cuff':
        user.user_status = 'pending_first_reading'
        audit_log('UPDATE', 'user', resource_id=str(user.id),
                  details={'action': 'auto_status_transition', 'from': 'pending_cuff', 'to': 'pending_first_reading'},
                  user_id=str(user.id))

    db.session.commit()

    audit_log('UPDATE', 'cuff_request', resource_id=str(request_id),
              details={'action': 'marked_received'})

    return jsonify(cuff_request.to_dict(include_address=True)), 200


# ---------- Device Tokens (Push Notifications) ----------

@consumer_bp.route('/device-token', methods=['POST'])
@token_required
def register_device_token():
    """Register or update a device token for push notifications."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    token = data.get('token', '').strip()
    if not token:
        return jsonify({'error': 'Device token is required'}), 400

    if len(token) > 500:
        return jsonify({'error': 'Token too long'}), 400

    platform = data.get('platform')
    if platform and platform not in ('ios', 'android', 'web'):
        return jsonify({'error': 'Invalid platform. Must be ios, android, or web'}), 400

    # Check if token already exists
    existing = DeviceToken.query.filter_by(token=token).first()

    if existing:
        # Update existing token
        existing.user_id = g.user_id
        existing.platform = platform or existing.platform
        existing.device_model = data.get('device_model') or existing.device_model
        existing.app_version = data.get('app_version') or existing.app_version
        existing.is_active = True
        db.session.commit()
        return jsonify({'message': 'Device token updated', 'token_id': existing.id}), 200

    # Create new token
    device_token = DeviceToken(
        user_id=g.user_id,
        token=token,
        platform=platform,
        device_model=data.get('device_model'),
        app_version=data.get('app_version'),
    )
    db.session.add(device_token)
    db.session.commit()

    audit_log('CREATE', 'device_token', resource_id=str(device_token.id),
              details={'platform': platform})

    return jsonify({'message': 'Device token registered', 'token_id': device_token.id}), 201


@consumer_bp.route('/device-token', methods=['DELETE'])
@token_required
def remove_device_token():
    """Remove a device token (for logout/unsubscribe)."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body is required'}), 400

    token = data.get('token', '').strip()
    if not token:
        return jsonify({'error': 'Device token is required'}), 400

    device_token = DeviceToken.query.filter_by(token=token, user_id=g.user_id).first()

    if device_token:
        device_token.is_active = False
        db.session.commit()

        audit_log('DELETE', 'device_token', resource_id=str(device_token.id))

        return jsonify({'message': 'Device token deactivated'}), 200

    return jsonify({'message': 'Device token not found'}), 404
