"""Admin call list routes."""
import logging
from datetime import datetime, timedelta, timezone
from flask import request, jsonify, g
from sqlalchemy import func, or_
from app import db
from app.models import User, BloodPressureReading, CallListItem, CallAttempt
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from . import admin_bp, admin_required

logger = logging.getLogger(__name__)

VALID_OUTCOMES = {
    'completed', 'left_vm', 'no_answer', 'email_sent',
    'requested_callback', 'refused', 'sent_materials',
}
AUTO_CLOSE_OUTCOMES = {'left_vm', 'no_answer', 'refused'}
AUTO_CLOSE_THRESHOLD = 3
COOLDOWN_DAYS = 14


def _evaluate_call_list():
    """
    Batch-evaluate all active+approved users and create/update CallListItem records.
    Nurse: systolic >= 150 OR diastolic >= 86 (7-day avg)
    Coach: systolic 135-149 OR diastolic 80-87 (but NOT nurse-level)
    No-Reading: no readings in 30+ days (or never)
    """
    now = datetime.now(timezone.utc)
    seven_days_ago = now - timedelta(days=7)
    thirty_days_ago = now - timedelta(days=30)

    # Get all active, non-admin users
    users = User.query.filter(User.user_status == 'active', User.is_admin == False).all()

    # Batch-load all readings from last 7 days in 1 query
    recent_readings = (
        BloodPressureReading.query
        .filter(BloodPressureReading.reading_date >= seven_days_ago)
        .all()
    )

    # Also get the latest reading date per user (for no-reading check)
    latest_per_user_q = (
        db.session.query(
            BloodPressureReading.user_id,
            func.max(BloodPressureReading.reading_date).label('latest_date')
        )
        .group_by(BloodPressureReading.user_id)
        .all()
    )
    latest_date_map = {row.user_id: row.latest_date for row in latest_per_user_q}

    # Group 7-day readings by user
    readings_by_user = {}
    for r in recent_readings:
        readings_by_user.setdefault(r.user_id, []).append(r)

    # Get existing open items and cooldowns
    open_items = CallListItem.query.filter_by(status='open').all()
    open_item_map = {}
    for item in open_items:
        open_item_map.setdefault(item.user_id, {})[item.list_type] = item

    cooldown_items = (
        CallListItem.query
        .filter(CallListItem.cooldown_until > now)
        .all()
    )
    cooldown_map = {}
    for item in cooldown_items:
        cooldown_map.setdefault(item.user_id, set()).add(item.list_type)

    count = 0

    for user in users:
        user_readings = readings_by_user.get(user.id, [])
        latest_date = latest_date_map.get(user.id)

        # Calculate 7-day averages
        avg_sys = None
        avg_dia = None
        if user_readings:
            avg_sys = round(sum(r.systolic for r in user_readings) / len(user_readings))
            avg_dia = round(sum(r.diastolic for r in user_readings) / len(user_readings))

        assigned_list = None
        priority = 'medium'
        priority_title = ''
        priority_detail = ''

        # Nurse criteria: systolic >= 150 OR diastolic >= 86
        if avg_sys is not None and (avg_sys >= 150 or avg_dia >= 86):
            assigned_list = 'nurse'
            priority = 'high'
            priority_title = 'Elevated BP — Nurse Review'
            if avg_sys >= 150:
                priority_detail = f'7-day avg: {avg_sys}/{avg_dia} (systolic >= 150)'
            else:
                priority_detail = f'7-day avg: {avg_sys}/{avg_dia} (diastolic >= 86)'

        # Coach criteria: systolic 135-149 OR diastolic 80-87 (not nurse)
        elif avg_sys is not None and (135 <= avg_sys <= 149 or 80 <= avg_dia <= 87):
            assigned_list = 'coach'
            priority = 'medium'
            priority_title = 'Elevated BP — HTN Coach'
            priority_detail = f'7-day avg: {avg_sys}/{avg_dia}'

        # No-reading criteria: last reading > 30 days ago or never
        if assigned_list is None:
            if latest_date is None or latest_date < thirty_days_ago:
                assigned_list = 'no_reading'
                priority = 'low'
                priority_title = 'No Recent Readings'
                if latest_date:
                    days_since = (now - latest_date).days
                    priority_detail = f'Last reading: {days_since} days ago ({latest_date.strftime("%b %d, %Y")})'
                else:
                    priority_detail = 'No readings ever submitted'

        if assigned_list is None:
            continue

        # Skip if in cooldown for this list type
        if user.id in cooldown_map and assigned_list in cooldown_map[user.id]:
            continue

        # Skip if already has open item on this list
        if user.id in open_item_map and assigned_list in open_item_map[user.id]:
            # Update priority info on existing item
            existing = open_item_map[user.id][assigned_list]
            existing.priority = priority
            existing.priority_title = priority_title
            existing.priority_detail = priority_detail
            continue

        # Create new item
        item = CallListItem(
            user_id=user.id,
            list_type=assigned_list,
            status='open',
            priority=priority,
            priority_title=priority_title,
            priority_detail=priority_detail,
        )
        db.session.add(item)
        count += 1

    db.session.commit()
    return count


@admin_bp.route('/call-list/refresh', methods=['POST'])
@token_required
@admin_required
def refresh_call_list():
    """Re-evaluate all users and update call list items."""
    count = _evaluate_call_list()
    audit_log('CREATE', 'call_list_refresh', details={'items_created': count})
    return jsonify({'message': f'Refreshed call list, {count} new items created', 'count': count}), 200


@admin_bp.route('/call-list', methods=['GET'])
@token_required
@admin_required
def get_call_list():
    """Get call list items with filters. Returns enriched data for each item."""
    list_type = request.args.get('list_type', 'nurse')
    status = request.args.get('status', 'open')

    query = CallListItem.query

    if list_type:
        query = query.filter_by(list_type=list_type)
    if status and status != 'all':
        query = query.filter_by(status=status)

    query = query.order_by(
        db.case(
            (CallListItem.priority == 'high', 0),
            (CallListItem.priority == 'medium', 1),
            (CallListItem.priority == 'low', 2),
        ),
        CallListItem.created_at.desc(),
    )

    items = query.all()

    # Batch-load user data and readings
    user_ids = list(set(i.user_id for i in items))
    users_map = {}
    for u in User.query.filter(User.id.in_(user_ids)).all():
        users_map[u.id] = u

    # Get readings for all these users
    now = datetime.now(timezone.utc)
    seven_days_ago = now - timedelta(days=7)
    thirty_days_ago = now - timedelta(days=30)

    all_readings = (
        BloodPressureReading.query
        .filter(BloodPressureReading.user_id.in_(user_ids))
        .order_by(BloodPressureReading.reading_date.desc())
        .all()
    )
    readings_by_user = {}
    for r in all_readings:
        readings_by_user.setdefault(r.user_id, []).append(r)

    # Get attempt counts per item
    attempt_counts = {}
    last_attempts = {}
    for item in items:
        attempts = CallAttempt.query.filter_by(call_list_item_id=item.id).order_by(CallAttempt.created_at.desc()).all()
        attempt_counts[item.id] = len(attempts)
        if attempts:
            last_attempts[item.id] = attempts[0]

    # Build response
    result = []
    for item in items:
        user = users_map.get(item.user_id)
        if not user:
            continue

        user_readings = readings_by_user.get(item.user_id, [])
        latest = user_readings[0].to_dict() if user_readings else None

        recent_7 = [r for r in user_readings if r.reading_date and r.reading_date >= seven_days_ago]
        recent_30 = [r for r in user_readings if r.reading_date and r.reading_date >= thirty_days_ago]

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

        last_attempt = last_attempts.get(item.id)
        last_note = None
        if last_attempt and last_attempt.notes:
            note_text = last_attempt.notes
            last_note = {
                'text': note_text[:150] + ('...' if len(note_text) > 150 else ''),
                'admin_name': last_attempt.admin.name if last_attempt.admin else 'Admin',
                'date': last_attempt.created_at.isoformat() if last_attempt.created_at else None,
            }

        try:
            user_data = {
                'id': user.id,
                'name': user.name,
                'email': user.email,
                'phone': user.phone,
                'union_name': user.union.name if user.union else None,
                'gender': user.gender,
                'rank': user.rank,
                'created_at': user.created_at.isoformat() if user.created_at else None,
            }
        except Exception:
            user_data = {
                'id': user.id,
                'name': f'User #{user.id}',
                'email': None,
                'phone': None,
                'union_name': None,
                'gender': user.gender,
                'rank': user.rank,
                'created_at': user.created_at.isoformat() if user.created_at else None,
            }

        item_data = item.to_dict()
        item_data['user'] = user_data
        item_data['latest_reading'] = latest
        item_data['avg_7_day'] = avg_7
        item_data['avg_30_day'] = avg_30
        item_data['reading_count'] = len(user_readings)
        item_data['attempt_count'] = attempt_counts.get(item.id, 0)
        item_data['last_attempt'] = last_attempt.to_dict() if last_attempt else None
        item_data['last_note'] = last_note

        result.append(item_data)

    # Summary counts
    all_open = CallListItem.query.filter_by(status='open').all()
    summary = {
        'nurse': sum(1 for i in all_open if i.list_type == 'nurse'),
        'coach': sum(1 for i in all_open if i.list_type == 'coach'),
        'no_reading': sum(1 for i in all_open if i.list_type == 'no_reading'),
    }

    audit_log('READ', 'call_list', details={'list_type': list_type, 'count': len(result)})

    return jsonify({
        'items': result,
        'summary': summary,
        'total_count': len(result),
    }), 200


@admin_bp.route('/call-list/<int:item_id>/attempt', methods=['POST'])
@token_required
@admin_required
def log_call_attempt(item_id):
    """Log a call attempt for a call list item."""
    item = CallListItem.query.get(item_id)
    if not item:
        return jsonify({'error': 'Call list item not found'}), 404

    if item.status != 'open':
        return jsonify({'error': 'Cannot log attempt on a closed item'}), 400

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    outcome = data.get('outcome', '').strip()
    if outcome not in VALID_OUTCOMES:
        return jsonify({'error': f'Invalid outcome. Must be one of: {", ".join(sorted(VALID_OUTCOMES))}'}), 400

    attempt = CallAttempt(
        call_list_item_id=item.id,
        user_id=item.user_id,
        admin_id=g.user_id,
        outcome=outcome,
        follow_up_needed=bool(data.get('follow_up_needed')),
        materials_sent=bool(data.get('materials_sent')),
        materials_desc=data.get('materials_desc'),
        referral_made=bool(data.get('referral_made')),
        referral_to=data.get('referral_to'),
    )

    # Set encrypted notes
    notes = data.get('notes', '').strip()
    if notes:
        attempt.notes = notes

    # Handle follow-up date
    follow_up_date_str = data.get('follow_up_date')
    follow_up_days = data.get('follow_up_days')
    if follow_up_date_str:
        try:
            attempt.follow_up_date = datetime.fromisoformat(follow_up_date_str)
        except (ValueError, TypeError):
            return jsonify({'error': 'Invalid follow_up_date format'}), 400
    elif follow_up_days:
        try:
            attempt.follow_up_date = datetime.now(timezone.utc) + timedelta(days=int(follow_up_days))
        except (ValueError, TypeError):
            return jsonify({'error': 'Invalid follow_up_days value'}), 400

    db.session.add(attempt)

    # Update item follow-up date if set on attempt
    if attempt.follow_up_date:
        item.follow_up_date = attempt.follow_up_date

    auto_closed = False

    # Check auto-close: 3 attempts with left_vm/no_answer/refused
    if outcome in AUTO_CLOSE_OUTCOMES:
        close_attempts = (
            CallAttempt.query
            .filter_by(call_list_item_id=item.id)
            .filter(CallAttempt.outcome.in_(AUTO_CLOSE_OUTCOMES))
            .count()
        )
        # +1 for the current attempt not yet committed
        if close_attempts + 1 >= AUTO_CLOSE_THRESHOLD:
            item.status = 'closed'
            item.close_reason = 'auto_closed_3_attempts'
            item.closed_at = datetime.now(timezone.utc)
            item.closed_by = g.user_id
            item.cooldown_until = datetime.now(timezone.utc) + timedelta(days=COOLDOWN_DAYS)
            auto_closed = True

    db.session.commit()

    audit_log('CREATE', 'call_attempt', resource_id=str(attempt.id),
              details={'item_id': item_id, 'outcome': outcome, 'auto_closed': auto_closed})

    return jsonify({
        'attempt': attempt.to_dict(),
        'auto_closed': auto_closed,
        'item': item.to_dict(),
    }), 201


@admin_bp.route('/call-list/<int:item_id>/close', methods=['PUT'])
@token_required
@admin_required
def close_call_item(item_id):
    """Manually close a call list item."""
    item = CallListItem.query.get(item_id)
    if not item:
        return jsonify({'error': 'Call list item not found'}), 404

    if item.status != 'open':
        return jsonify({'error': 'Item is already closed'}), 400

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    reason = data.get('reason', '').strip()
    valid_reasons = {'resolved', 'not_needed', 'other'}
    if reason not in valid_reasons:
        return jsonify({'error': f'Invalid reason. Must be one of: {", ".join(sorted(valid_reasons))}'}), 400

    item.status = 'closed'
    item.close_reason = reason
    item.close_note = data.get('note', '').strip() or None
    item.closed_at = datetime.now(timezone.utc)
    item.closed_by = g.user_id
    db.session.commit()

    audit_log('UPDATE', 'call_list_item', resource_id=str(item_id),
              details={'action': 'manual_close', 'reason': reason})

    return jsonify(item.to_dict()), 200


@admin_bp.route('/call-list/<int:item_id>/schedule', methods=['PUT'])
@token_required
@admin_required
def schedule_follow_up(item_id):
    """Set a follow-up date for a call list item."""
    item = CallListItem.query.get(item_id)
    if not item:
        return jsonify({'error': 'Call list item not found'}), 404

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    follow_up_date_str = data.get('follow_up_date')
    follow_up_days = data.get('follow_up_days')

    if follow_up_date_str:
        try:
            item.follow_up_date = datetime.fromisoformat(follow_up_date_str)
        except (ValueError, TypeError):
            return jsonify({'error': 'Invalid follow_up_date format'}), 400
    elif follow_up_days is not None:
        try:
            item.follow_up_date = datetime.now(timezone.utc) + timedelta(days=int(follow_up_days))
        except (ValueError, TypeError):
            return jsonify({'error': 'Invalid follow_up_days value'}), 400
    else:
        return jsonify({'error': 'Provide follow_up_date or follow_up_days'}), 400

    db.session.commit()

    audit_log('UPDATE', 'call_list_item', resource_id=str(item_id),
              details={'action': 'schedule_follow_up', 'date': item.follow_up_date.isoformat()})

    return jsonify(item.to_dict()), 200


@admin_bp.route('/users/<int:user_id>/call-history', methods=['GET'])
@token_required
@admin_required
def get_call_history(user_id):
    """Get all call attempts for a patient, ordered by date desc."""
    user = User.query.get(user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    attempts = (
        CallAttempt.query
        .filter_by(user_id=user_id)
        .order_by(CallAttempt.created_at.desc())
        .all()
    )

    audit_log('READ', 'call_history', resource_id=str(user_id),
              details={'count': len(attempts)})

    return jsonify({'attempts': [a.to_dict() for a in attempts]}), 200


@admin_bp.route('/call-reports', methods=['GET'])
@token_required
@admin_required
def get_call_reports():
    """Get all call attempts with filters for reporting."""
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    list_type = request.args.get('list_type')
    outcome = request.args.get('outcome')
    admin_id = request.args.get('admin_id', type=int)

    query = CallAttempt.query.join(CallListItem, CallAttempt.call_list_item_id == CallListItem.id)

    if date_from:
        try:
            from_dt = datetime.strptime(date_from, '%Y-%m-%d')
            query = query.filter(CallAttempt.created_at >= from_dt)
        except ValueError:
            return jsonify({'error': 'Invalid date_from format. Use YYYY-MM-DD'}), 400

    if date_to:
        try:
            to_dt = datetime.strptime(date_to, '%Y-%m-%d') + timedelta(days=1)
            query = query.filter(CallAttempt.created_at < to_dt)
        except ValueError:
            return jsonify({'error': 'Invalid date_to format. Use YYYY-MM-DD'}), 400

    if list_type:
        query = query.filter(CallListItem.list_type == list_type)

    if outcome:
        query = query.filter(CallAttempt.outcome == outcome)

    if admin_id:
        query = query.filter(CallAttempt.admin_id == admin_id)

    query = query.order_by(CallAttempt.created_at.desc())
    attempts = query.all()

    # Build enriched results
    user_cache = {}
    results = []
    for a in attempts:
        # Get patient name
        if a.user_id not in user_cache:
            u = User.query.get(a.user_id)
            try:
                user_cache[a.user_id] = u.name if u else f'User #{a.user_id}'
            except Exception:
                user_cache[a.user_id] = f'User #{a.user_id}'

        attempt_data = a.to_dict()
        attempt_data['patient_name'] = user_cache.get(a.user_id, f'User #{a.user_id}')
        attempt_data['list_type'] = a.call_list_item.list_type if a.call_list_item else None
        results.append(attempt_data)

    # Summary stats
    now = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)
    total_all = CallAttempt.query.count()
    total_week = CallAttempt.query.filter(CallAttempt.created_at >= week_ago).count()

    outcome_counts = {}
    for o in VALID_OUTCOMES:
        outcome_counts[o] = CallAttempt.query.filter_by(outcome=o).count()

    audit_log('READ', 'call_reports', details={'count': len(results)})

    return jsonify({
        'attempts': results,
        'total_count': len(results),
        'summary': {
            'total_all': total_all,
            'total_week': total_week,
            'by_outcome': outcome_counts,
        },
    }), 200


@admin_bp.route('/call-list/<int:item_id>/send-email', methods=['POST'])
@token_required
@admin_required
def send_email_to_patient(item_id):
    """Compose and send an email to the patient, logging it as a call attempt."""
    item = CallListItem.query.get(item_id)
    if not item:
        return jsonify({'error': 'Call list item not found'}), 404

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    to_email = data.get('to', '').strip()
    subject = data.get('subject', '').strip()
    body = data.get('body', '').strip()

    if not to_email or not subject or not body:
        return jsonify({'error': 'to, subject, and body are required'}), 400

    # Attempt to send email via Flask-Mail or smtplib
    email_sent = False
    email_error = None
    try:
        from flask_mail import Message
        from flask import current_app
        mail = current_app.extensions.get('mail')
        if mail:
            msg = Message(subject=subject, recipients=[to_email], body=body)
            mail.send(msg)
            email_sent = True
    except ImportError:
        # Flask-Mail not installed — try smtplib
        try:
            import smtplib
            from email.mime.text import MIMEText
            import os
            smtp_host = os.getenv('SMTP_HOST')
            smtp_port = int(os.getenv('SMTP_PORT', '587'))
            smtp_user = os.getenv('SMTP_USER')
            smtp_pass = os.getenv('SMTP_PASS')
            smtp_from = os.getenv('SMTP_FROM', smtp_user)
            if smtp_host and smtp_user:
                msg = MIMEText(body)
                msg['Subject'] = subject
                msg['From'] = smtp_from
                msg['To'] = to_email
                with smtplib.SMTP(smtp_host, smtp_port) as server:
                    server.starttls()
                    server.login(smtp_user, smtp_pass)
                    server.send_message(msg)
                email_sent = True
            else:
                email_error = 'SMTP not configured'
        except Exception as e:
            logger.error(f"SMTP error sending email: {e}")
            email_error = 'Failed to send email'
    except Exception as e:
        logger.error(f"Email preparation error: {e}")
        email_error = 'Failed to send email'

    # Log the attempt regardless of send success
    attempt = CallAttempt(
        call_list_item_id=item.id,
        user_id=item.user_id,
        admin_id=g.user_id,
        outcome='email_sent',
    )
    attempt.notes = f'Email to: {to_email}\nSubject: {subject}\n\n{body}'
    db.session.add(attempt)
    db.session.commit()

    audit_log('CREATE', 'email_sent', resource_id=str(attempt.id),
              details={'item_id': item_id, 'sent': email_sent})

    response = {
        'attempt': attempt.to_dict(),
        'email_sent': email_sent,
    }
    if email_error:
        response['email_error'] = email_error
        response['message'] = 'Email attempt logged but delivery failed. Check SMTP configuration.'

    return jsonify(response), 201
