"""Admin data export routes."""
import re
from datetime import datetime, timedelta, timezone
from flask import request, jsonify, Response
from app import db
from app.models import User, BloodPressureReading, CallListItem, CallAttempt
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from app.utils.export import generate_users_csv, generate_readings_csv, generate_call_reports_csv, generate_patient_pdf
from . import admin_bp, admin_required


@admin_bp.route('/export/users', methods=['GET'])
@token_required
@admin_required
def export_users():
    """Export users to CSV with optional filters."""
    # Apply same filters as list_users
    status_filter = request.args.get('status')
    gender_filter = request.args.get('gender', '').strip()
    race_filter = request.args.get('race', '').strip()
    rank_filter = request.args.get('rank', '').strip()
    work_status_filter = request.args.get('work_status', '').strip()
    union_id_filter = request.args.get('union_id', '').strip()

    # Age filters
    age_min = request.args.get('age_min', type=int)
    age_max = request.args.get('age_max', type=int)

    # Date registered filters
    registered_from = request.args.get('registered_from')
    registered_to = request.args.get('registered_to')

    query = User.query

    if status_filter:
        if status_filter == 'pending':
            query = query.filter_by(user_status='pending_approval')
        elif status_filter == 'approved':
            query = query.filter(User.user_status.in_(['active', 'pending_registration', 'pending_cuff', 'pending_first_reading']))
        elif status_filter == 'deactivated':
            query = query.filter_by(user_status='deactivated')

    if gender_filter:
        query = query.filter(User.gender.in_(gender_filter.split(',')))
    if race_filter:
        query = query.filter(User.race.in_(race_filter.split(',')))
    if rank_filter:
        query = query.filter(User.rank.in_(rank_filter.split(',')))
    if work_status_filter:
        query = query.filter(User.work_status.in_(work_status_filter.split(',')))
    if union_id_filter:
        try:
            union_ids = [int(x) for x in union_id_filter.split(',')]
            query = query.filter(User.union_id.in_(union_ids))
        except ValueError:
            pass

    if registered_from:
        try:
            from_dt = datetime.strptime(registered_from, '%Y-%m-%d')
            query = query.filter(User.created_at >= from_dt)
        except ValueError:
            pass

    if registered_to:
        try:
            to_dt = datetime.strptime(registered_to, '%Y-%m-%d') + timedelta(days=1)
            query = query.filter(User.created_at < to_dt)
        except ValueError:
            pass

    users = query.order_by(User.created_at.desc()).all()

    # Filter by age if specified (requires DOB decryption)
    if age_min is not None or age_max is not None:
        now = datetime.now(timezone.utc)
        filtered_users = []
        for user in users:
            try:
                if user.dob:
                    dob = datetime.strptime(user.dob, '%Y-%m-%d')
                    age = (now - dob).days // 365
                    if age_min is not None and age < age_min:
                        continue
                    if age_max is not None and age > age_max:
                        continue
                filtered_users.append(user)
            except Exception:
                filtered_users.append(user)  # Include if DOB can't be parsed
        users = filtered_users

    csv_output = generate_users_csv(users, include_phi=True)

    audit_log('EXPORT', 'users_csv', details={'count': len(users)})

    return Response(
        csv_output.getvalue(),
        mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename=users_export_{datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")}.csv'}
    )


@admin_bp.route('/export/readings', methods=['GET'])
@token_required
@admin_required
def export_readings():
    """Export readings to CSV with filters."""
    user_id_filter = request.args.get('user_id', type=int)
    from_date = request.args.get('from_date')
    to_date = request.args.get('to_date')
    union_id_filter = request.args.get('union_id', '').strip()

    query = BloodPressureReading.query

    if user_id_filter:
        query = query.filter_by(user_id=user_id_filter)

    if from_date:
        try:
            from_dt = datetime.strptime(from_date, '%Y-%m-%d')
            query = query.filter(BloodPressureReading.reading_date >= from_dt)
        except ValueError:
            pass

    if to_date:
        try:
            to_dt = datetime.strptime(to_date, '%Y-%m-%d') + timedelta(days=1)
            query = query.filter(BloodPressureReading.reading_date < to_dt)
        except ValueError:
            pass

    if union_id_filter:
        try:
            union_ids = [int(x) for x in union_id_filter.split(',')]
            query = query.join(User).filter(User.union_id.in_(union_ids))
        except ValueError:
            pass

    readings = query.order_by(BloodPressureReading.reading_date.desc()).all()

    # Build user name cache
    user_ids = list(set(r.user_id for r in readings))
    user_names = {}
    for user in User.query.filter(User.id.in_(user_ids)).all():
        try:
            user_names[user.id] = user.name or f'User #{user.id}'
        except Exception:
            user_names[user.id] = f'User #{user.id}'

    csv_output = generate_readings_csv(readings, user_names)

    audit_log('EXPORT', 'readings_csv', details={'count': len(readings)})

    return Response(
        csv_output.getvalue(),
        mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename=readings_export_{datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")}.csv'}
    )


@admin_bp.route('/export/call-reports', methods=['GET'])
@token_required
@admin_required
def export_call_reports():
    """Export call reports to CSV with filters."""
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    outcome_filter = request.args.get('outcome')
    list_type_filter = request.args.get('list_type')

    query = CallAttempt.query.join(CallListItem)

    if date_from:
        try:
            from_dt = datetime.strptime(date_from, '%Y-%m-%d')
            query = query.filter(CallAttempt.created_at >= from_dt)
        except ValueError:
            pass

    if date_to:
        try:
            to_dt = datetime.strptime(date_to, '%Y-%m-%d') + timedelta(days=1)
            query = query.filter(CallAttempt.created_at < to_dt)
        except ValueError:
            pass

    if outcome_filter:
        query = query.filter(CallAttempt.outcome == outcome_filter)

    if list_type_filter:
        query = query.filter(CallListItem.list_type == list_type_filter)

    attempts = query.order_by(CallAttempt.created_at.desc()).all()

    # Build user name cache
    user_ids = list(set(a.user_id for a in attempts))
    user_names = {}
    for user in User.query.filter(User.id.in_(user_ids)).all():
        try:
            user_names[user.id] = user.name or f'User #{user.id}'
        except Exception:
            user_names[user.id] = f'User #{user.id}'

    csv_output = generate_call_reports_csv(attempts, user_names)

    audit_log('EXPORT', 'call_reports_csv', details={'count': len(attempts)})

    return Response(
        csv_output.getvalue(),
        mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename=call_reports_export_{datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")}.csv'}
    )


@admin_bp.route('/export/users/<int:user_id>/pdf', methods=['GET'])
@token_required
@admin_required
def export_user_pdf(user_id):
    """Export individual patient report as PDF."""
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    # Get readings
    readings = (BloodPressureReading.query
                .filter_by(user_id=user_id)
                .order_by(BloodPressureReading.reading_date.desc())
                .all())

    # Calculate averages
    now = datetime.now(timezone.utc)
    seven_days_ago = now - timedelta(days=7)
    thirty_days_ago = now - timedelta(days=30)

    recent_7 = [r for r in readings if r.reading_date and r.reading_date >= seven_days_ago]
    recent_30 = [r for r in readings if r.reading_date and r.reading_date >= thirty_days_ago]

    avg_7 = None
    if recent_7:
        avg_7 = {
            'systolic': round(sum(r.systolic for r in recent_7) / len(recent_7)),
            'diastolic': round(sum(r.diastolic for r in recent_7) / len(recent_7)),
        }

    avg_30 = None
    if recent_30:
        avg_30 = {
            'systolic': round(sum(r.systolic for r in recent_30) / len(recent_30)),
            'diastolic': round(sum(r.diastolic for r in recent_30) / len(recent_30)),
        }

    pdf_output = generate_patient_pdf(user, readings, avg_7, avg_30)

    audit_log('EXPORT', 'patient_pdf', resource_id=str(user_id))

    try:
        raw_name = user.name.replace(' ', '_') if user.name else f'patient_{user_id}'
        # Sanitize: allow only alphanumeric, underscore, hyphen
        patient_name = re.sub(r'[^a-zA-Z0-9_\-]', '', raw_name) or f'patient_{user_id}'
    except Exception:
        patient_name = f'patient_{user_id}'

    return Response(
        pdf_output.getvalue(),
        mimetype='application/pdf',
        headers={'Content-Disposition': f'attachment; filename={patient_name}_report_{datetime.now(timezone.utc).strftime("%Y%m%d")}.pdf'}
    )
