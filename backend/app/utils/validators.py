"""
Input validation for registration, readings, and profile updates.
"""
import re
from datetime import datetime
from email_validator import validate_email, EmailNotValidError


def validate_profile_update(data: dict) -> list:
    """Validate profile update input. Returns list of error strings (empty = valid)."""
    errors = []

    # Cannot change email via profile update
    if 'email' in data:
        errors.append('Email cannot be changed via profile update')

    name = data.get('name')
    if name is not None:
        name = str(name).strip()
        if len(name) < 1:
            errors.append('Name cannot be empty')
        if len(name) > 200:
            errors.append('Name must be 200 characters or fewer')

    phone = data.get('phone')
    if phone is not None and phone != '':
        phone = str(phone).strip()
        if len(phone) > 20:
            errors.append('Phone must be 20 characters or fewer')

    address = data.get('address')
    if address is not None and address != '':
        if len(str(address)) > 500:
            errors.append('Address must be 500 characters or fewer')

    dob = data.get('dob')
    if dob is not None and dob != '':
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', str(dob)):
            errors.append('DOB must be in YYYY-MM-DD format')
        else:
            try:
                parsed = datetime.strptime(str(dob), '%Y-%m-%d')
                if parsed > datetime.now():
                    errors.append('DOB cannot be in the future')
            except ValueError:
                errors.append('DOB is not a valid date')

    height_inches = data.get('height_inches')
    if height_inches is not None:
        try:
            h = int(height_inches)
            if h < 24 or h > 108:
                errors.append('Height must be between 24 and 108 inches')
        except (ValueError, TypeError):
            errors.append('Height must be an integer')

    weight_lbs = data.get('weight_lbs')
    if weight_lbs is not None:
        try:
            w = int(weight_lbs)
            if w < 50 or w > 700:
                errors.append('Weight must be between 50 and 700 lbs')
        except (ValueError, TypeError):
            errors.append('Weight must be an integer')

    missed_doses = data.get('missed_doses')
    if missed_doses is not None:
        try:
            m = int(missed_doses)
            if m < 0 or m > 30:
                errors.append('Missed doses must be between 0 and 30')
        except (ValueError, TypeError):
            errors.append('Missed doses must be an integer')

    # Validate lifestyle fields if present
    exercise_days = data.get('exercise_days_per_week')
    if exercise_days is not None:
        try:
            e = int(exercise_days)
            if e < 0 or e > 7:
                errors.append('Exercise days per week must be between 0 and 7')
        except (ValueError, TypeError):
            errors.append('Exercise days per week must be an integer')

    exercise_minutes = data.get('exercise_minutes_per_session')
    if exercise_minutes is not None:
        try:
            e = int(exercise_minutes)
            if e < 0 or e > 300:
                errors.append('Exercise minutes per session must be between 0 and 300')
        except (ValueError, TypeError):
            errors.append('Exercise minutes per session must be an integer')

    sleep_quality = data.get('sleep_quality')
    if sleep_quality is not None:
        try:
            s = int(sleep_quality)
            if s < 1 or s > 10:
                errors.append('Sleep quality must be between 1 and 10')
        except (ValueError, TypeError):
            errors.append('Sleep quality must be an integer')

    valid_stress_levels = ['low', 'moderate', 'high', 'very_high', None, '']
    if data.get('stress_level') not in valid_stress_levels:
        errors.append('Invalid stress level')

    valid_financial_stress = ['not_at_all', 'somewhat', 'very', 'extremely', None, '']
    if data.get('financial_stress') not in valid_financial_stress:
        errors.append('Invalid financial stress level')

    valid_loneliness = ['never', 'rarely', 'sometimes', 'often', 'always', None, '']
    if data.get('loneliness') not in valid_loneliness:
        errors.append('Invalid loneliness value')

    return errors


def validate_registration(data: dict) -> list:
    """Validate registration input. Returns list of error strings (empty = valid)."""
    errors = []

    name = (data.get('name') or '').strip()
    if not name or len(name) < 1:
        errors.append('Name is required')
    if len(name) > 200:
        errors.append('Name must be 200 characters or fewer')

    email = (data.get('email') or '').strip()
    if not email:
        errors.append('Email is required')
    else:
        try:
            validate_email(email, check_deliverability=False)
        except EmailNotValidError:
            errors.append('Invalid email format')

    union_id = data.get('union_id')
    if union_id is None:
        errors.append('Union ID is required')
    else:
        try:
            int(union_id)
        except (ValueError, TypeError):
            errors.append('Union ID must be an integer')

    dob = data.get('dob')
    if dob is not None and dob != '':
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', str(dob)):
            errors.append('DOB must be in YYYY-MM-DD format')
        else:
            from datetime import datetime
            try:
                parsed = datetime.strptime(str(dob), '%Y-%m-%d')
                if parsed > datetime.now():
                    errors.append('DOB cannot be in the future')
            except ValueError:
                errors.append('DOB is not a valid date')

    return errors


def validate_reading(data: dict) -> list:
    """Validate blood pressure reading input. Returns list of error strings."""
    errors = []

    systolic = data.get('systolic')
    if systolic is None:
        errors.append('Systolic is required')
    else:
        try:
            s = int(systolic)
            if s < 60 or s > 300:
                errors.append('Systolic must be between 60 and 300')
        except (ValueError, TypeError):
            errors.append('Systolic must be an integer')

    diastolic = data.get('diastolic')
    if diastolic is None:
        errors.append('Diastolic is required')
    else:
        try:
            d = int(diastolic)
            if d < 30 or d > 200:
                errors.append('Diastolic must be between 30 and 200')
        except (ValueError, TypeError):
            errors.append('Diastolic must be an integer')

    heart_rate = data.get('heartRate')
    if heart_rate is not None:
        try:
            hr = int(heart_rate)
            if hr < 30 or hr > 250:
                errors.append('Heart rate must be between 30 and 250')
        except (ValueError, TypeError):
            errors.append('Heart rate must be an integer')

    if not data.get('readingDate'):
        errors.append('Reading date is required')

    return errors
