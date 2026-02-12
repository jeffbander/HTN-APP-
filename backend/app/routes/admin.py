"""
Admin API routes.
"""
import json
import logging
from datetime import datetime, timedelta
from functools import wraps
from flask import Blueprint, request, jsonify, g, Response
from sqlalchemy import func, or_, and_
from app import db
from app.models import (
    User, BloodPressureReading, AdminNote,
    CallListItem, CallAttempt, EmailTemplate,
    CuffRequest, DeviceToken, Union,
)
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from app.utils.export import generate_users_csv, generate_readings_csv, generate_call_reports_csv, generate_patient_pdf

logger = logging.getLogger(__name__)

admin_bp = Blueprint('admin', __name__)


def admin_required(f):
    """Decorator that requires the authenticated user to be an admin."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        user = User.query.get(g.user_id)
        if not user or not user.is_admin:
            return jsonify({'error': 'Admin access required'}), 403
        return f(*args, **kwargs)
    return wrapper


# ---------- Stats ----------

@admin_bp.route('/stats', methods=['GET'])
@token_required
@admin_required
def get_stats():
    """Aggregate dashboard statistics."""
    total_users = User.query.count()
    pending_approvals = User.query.filter_by(user_status='pending_approval').count()
    approved_users = User.query.filter(User.user_status.in_(['active', 'pending_registration', 'pending_cuff', 'pending_first_reading'])).count()
    deactivated_users = User.query.filter_by(user_status='deactivated').count()
    flagged_users_count = User.query.filter_by(is_flagged=True).count()
    total_readings = BloodPressureReading.query.count()

    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    readings_today = BloodPressureReading.query.filter(
        BloodPressureReading.reading_date >= today_start
    ).count()

    audit_log('READ', 'admin_stats', details={'action': 'view_stats'})

    return jsonify({
        'total_users': total_users,
        'pending_approvals': pending_approvals,
        'approved_users': approved_users,
        'deactivated_users': deactivated_users,
        'flagged_users_count': flagged_users_count,
        'total_readings': total_readings,
        'readings_today': readings_today,
    }), 200


# ---------- User Tab Endpoints ----------

def _last_reading_subquery():
    """Returns subquery: (user_id, last_reading_date)"""
    return (
        db.session.query(
            BloodPressureReading.user_id,
            func.max(BloodPressureReading.reading_date).label('last_reading_date')
        )
        .group_by(BloodPressureReading.user_id)
        .subquery()
    )


def _apply_tab_filters(query, args):
    """Apply search, union, gender, HTN, sort filters from request args."""
    union_id = args.get('union_id', type=int)
    if union_id:
        query = query.filter(User.union_id == union_id)

    gender = args.get('gender', '').strip()
    if gender:
        query = query.filter(User.gender == gender)

    has_htn = args.get('has_htn', '').strip().lower()
    if has_htn == 'true':
        query = query.filter(User.has_high_blood_pressure == True)
    elif has_htn == 'false':
        query = query.filter(User.has_high_blood_pressure == False)

    sort_by = args.get('sort', 'created_at')
    sort_dir = args.get('dir', 'desc')
    sortable = {
        'created_at': User.created_at,
        'updated_at': User.updated_at,
        'union_id': User.union_id,
    }
    sort_col = sortable.get(sort_by, User.created_at)
    query = query.order_by(sort_col.desc() if sort_dir == 'desc' else sort_col.asc())

    page = args.get('page', 1, type=int)
    per_page = min(args.get('per_page', 50, type=int), 200)
    search = args.get('search', '').strip()

    return query, search, page, per_page


def _paginate_and_search(query, search, page, per_page):
    """Execute query, apply text search in Python (post-decryption), paginate."""
    if search:
        all_users = query.all()
        filtered = []
        search_lower = search.lower()
        for u in all_users:
            try:
                name = (u.name or '').lower()
                email = (u.email or '').lower()
                if search_lower in name or search_lower in email:
                    filtered.append(u)
            except Exception:
                continue
        total = len(filtered)
        start = (page - 1) * per_page
        users = filtered[start:start + per_page]
    else:
        total = query.count()
        users = query.offset((page - 1) * per_page).limit(per_page).all()
    return users, total


@admin_bp.route('/users/tab-counts', methods=['GET'])
@token_required
@admin_required
def tab_counts():
    """Return user counts for each dashboard tab."""
    cutoff = datetime.utcnow() - timedelta(days=240)  # 8 months
    last_reading = _last_reading_subquery()

    active_count = (
        db.session.query(func.count(User.id))
        .outerjoin(last_reading, User.id == last_reading.c.user_id)
        .filter(User.user_status == 'active')
        .filter(last_reading.c.last_reading_date >= cutoff)
        .scalar()
    )

    auto_deactivated = (
        db.session.query(func.count(User.id))
        .outerjoin(last_reading, User.id == last_reading.c.user_id)
        .filter(User.user_status == 'active')
        .filter(or_(
            last_reading.c.last_reading_date < cutoff,
            last_reading.c.last_reading_date == None
        ))
        .scalar()
    )

    manual_deactivated = (
        db.session.query(func.count(User.id))
        .filter(User.user_status == 'deactivated')
        .scalar()
    )

    counts = {
        'all': db.session.query(func.count(User.id)).scalar(),
        'active': active_count,
        'pending_approval': User.query.filter_by(user_status='pending_approval').count(),
        'pending_registration': User.query.filter_by(user_status='pending_registration').count(),
        'pending_cuff': User.query.filter_by(user_status='pending_cuff').count(),
        'pending_first_reading': User.query.filter_by(user_status='pending_first_reading').count(),
        'enrollment_only': User.query.filter_by(user_status='enrollment_only').count(),
        'deactivated': auto_deactivated + manual_deactivated,
    }

    return jsonify(counts)


@admin_bp.route('/users/tab/<tab_name>', methods=['GET'])
@token_required
@admin_required
def tab_users(tab_name):
    """Return paginated users for a specific dashboard tab."""
    cutoff = datetime.utcnow() - timedelta(days=240)
    last_reading = _last_reading_subquery()
    args = request.args

    if tab_name == 'all':
        query = User.query
    elif tab_name == 'active':
        query = (
            db.session.query(User)
            .outerjoin(last_reading, User.id == last_reading.c.user_id)
            .filter(User.user_status == 'active')
            .filter(last_reading.c.last_reading_date >= cutoff)
        )
    elif tab_name == 'pending_approval':
        query = User.query.filter_by(user_status='pending_approval')
    elif tab_name == 'pending_registration':
        query = User.query.filter_by(user_status='pending_registration')
    elif tab_name == 'pending_cuff':
        query = User.query.filter_by(user_status='pending_cuff')
    elif tab_name == 'pending_first_reading':
        query = User.query.filter_by(user_status='pending_first_reading')
    elif tab_name == 'enrollment_only':
        query = User.query.filter_by(user_status='enrollment_only')
    elif tab_name == 'deactivated':
        query = (
            db.session.query(User)
            .outerjoin(last_reading, User.id == last_reading.c.user_id)
            .filter(or_(
                User.user_status == 'deactivated',
                and_(
                    User.user_status == 'active',
                    or_(
                        last_reading.c.last_reading_date < cutoff,
                        last_reading.c.last_reading_date == None
                    )
                )
            ))
        )
    else:
        return jsonify({'error': f'Unknown tab: {tab_name}'}), 400

    query, search, page, per_page = _apply_tab_filters(query, args)
    users, total = _paginate_and_search(query, search, page, per_page)

    # Build response with last_reading_date and reading_count
    user_ids = [u.id for u in users]
    reading_dates = {}
    if user_ids:
        results = (
            db.session.query(
                BloodPressureReading.user_id,
                func.max(BloodPressureReading.reading_date).label('last_date'),
                func.count(BloodPressureReading.id).label('reading_count')
            )
            .filter(BloodPressureReading.user_id.in_(user_ids))
            .group_by(BloodPressureReading.user_id)
            .all()
        )
        for r in results:
            reading_dates[r.user_id] = {
                'last_reading_date': r.last_date.isoformat() if r.last_date else None,
                'reading_count': r.reading_count,
            }

    users_data = []
    for u in users:
        d = u.to_dict(include_phi=True)
        rd = reading_dates.get(u.id, {})
        d['last_reading_date'] = rd.get('last_reading_date')
        d['reading_count'] = rd.get('reading_count', 0)
        users_data.append(d)

    return jsonify({
        'users': users_data,
        'total': total,
        'page': page,
        'per_page': per_page,
        'pages': (total + per_page - 1) // per_page,
    })


@admin_bp.route('/users/<int:user_id>/status', methods=['PUT'])
@token_required
@admin_required
def change_user_status(user_id):
    """Admin manually changes a user's status."""
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    data = request.get_json()
    new_status = data.get('user_status')

    valid = [
        'pending_approval', 'pending_registration', 'pending_cuff',
        'pending_first_reading', 'active', 'deactivated', 'enrollment_only',
    ]
    if new_status not in valid:
        return jsonify({'error': f'Invalid status. Must be one of: {valid}'}), 400

    old_status = user.user_status
    user.user_status = new_status
    user.is_active = new_status not in ('deactivated',)

    db.session.commit()

    audit_log('UPDATE', 'user', resource_id=str(user_id),
              details={'action': 'status_change', 'old_status': old_status, 'new_status': new_status})

    return jsonify({
        'message': f'Status changed from {old_status} to {new_status}',
        'user': user.to_dict(include_phi=True),
    })


# ---------- Users ----------

@admin_bp.route('/users', methods=['GET'])
@token_required
@admin_required
def list_users():
    """List users with pagination, status filter, multi-select filters,
    server-side search, and sorting."""
    limit = request.args.get('limit', 50, type=int)
    offset = request.args.get('offset', 0, type=int)
    status_filter = request.args.get('status')
    approved_filter = request.args.get('approved')
    search_query = request.args.get('search', '').strip()

    # Multi-select filter params (comma-separated)
    gender_filter = request.args.get('gender', '').strip()
    race_filter = request.args.get('race', '').strip()
    rank_filter = request.args.get('rank', '').strip()
    work_status_filter = request.args.get('work_status', '').strip()
    union_id_filter = request.args.get('union_id', '').strip()

    # Sort params
    sort_by = request.args.get('sort_by', 'created_at')
    sort_order = request.args.get('sort_order', 'desc')

    limit = min(limit, 200)

    query = User.query

    # Status filter
    if status_filter:
        if status_filter == 'pending':
            query = query.filter_by(user_status='pending_approval')
        elif status_filter == 'approved':
            query = query.filter(User.user_status.in_(['active', 'pending_registration', 'pending_cuff', 'pending_first_reading']))
        elif status_filter == 'deactivated':
            query = query.filter_by(user_status='deactivated')
    elif approved_filter is not None:
        is_approved_val = approved_filter.lower() in ('true', '1', 'yes')
        if is_approved_val:
            query = query.filter(User.user_status != 'pending_approval')
        else:
            query = query.filter_by(user_status='pending_approval')

    # Multi-select filters
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

    # Server-side search on encrypted fields — we have to search after decryption.
    # For scalability this should use the email_hash for exact email matches,
    # but for ILIKE-style partial search we must filter in Python post-query.
    # We'll fetch a larger batch and filter, or if no search, just paginate normally.

    # Sorting
    sort_whitelist = {
        'id': User.id,
        'created_at': User.created_at,
        'union_id': User.union_id,
        'gender': User.gender,
        'rank': User.rank,
    }
    sort_col = sort_whitelist.get(sort_by, User.created_at)
    if sort_order == 'asc':
        query = query.order_by(sort_col.asc())
    else:
        query = query.order_by(sort_col.desc())

    if search_query:
        # For encrypted PHI search, we must fetch all matching non-search filters
        # then filter in Python. This is necessary because name/email are encrypted.
        all_users = query.all()
        q = search_query.lower()
        filtered = []
        for u in all_users:
            try:
                name = (u.name or '').lower()
                email = (u.email or '').lower()
            except Exception:
                name = ''
                email = ''
            if q in name or q in email:
                filtered.append(u)
        total_count = len(filtered)
        page = filtered[offset:offset + limit]
    else:
        total_count = query.count()
        page = query.offset(offset).limit(limit).all()

    audit_log('READ', 'user_list', details={
        'count': len(page),
        'filter_status': status_filter,
        'search': search_query if search_query else None,
    })

    return jsonify({
        'users': [u.to_dict(include_phi=True) for u in page],
        'total_count': total_count,
    }), 200


@admin_bp.route('/users/<int:id>', methods=['GET'])
@token_required
@admin_required
def get_user(id):
    """Get a single user with reading stats."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    user_data = user.to_dict(include_phi=True)

    # Reading stats
    readings = (BloodPressureReading.query
                .filter_by(user_id=id)
                .order_by(BloodPressureReading.reading_date.desc())
                .all())

    total_readings = len(readings)
    latest = readings[0].to_dict() if readings else None

    now = datetime.utcnow()
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

    user_data['total_readings'] = total_readings
    user_data['latest_reading'] = latest
    user_data['avg_7_day'] = avg_7
    user_data['avg_30_day'] = avg_30

    audit_log('READ', 'user', resource_id=str(id), details={'action': 'view_detail'})

    return jsonify(user_data), 200


@admin_bp.route('/users/<int:id>/approve', methods=['PUT'])
@token_required
@admin_required
def approve_user(id):
    """Approve a user account. Also verifies email if not yet verified."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    user.user_status = 'pending_cuff'
    if not user.is_email_verified:
        user.is_email_verified = True
    db.session.commit()

    audit_log('UPDATE', 'user', resource_id=str(id),
              details={'action': 'approve', 'new_status': 'pending_cuff'})

    return jsonify(user.to_dict(include_phi=True)), 200


@admin_bp.route('/users/<int:id>/deactivate', methods=['PUT'])
@token_required
@admin_required
def deactivate_user(id):
    """Deactivate a user account. Prevents login and invalidates tokens via is_active check."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    if user.is_admin:
        return jsonify({'error': 'Cannot deactivate an admin user'}), 403

    if user.user_status == 'deactivated':
        return jsonify({'error': 'User is already deactivated'}), 409

    user.user_status = 'deactivated'
    user.is_active = False
    db.session.commit()

    audit_log('UPDATE', 'user', resource_id=str(id),
              details={'action': 'deactivate', 'deactivated_by': g.user_id})

    return jsonify(user.to_dict(include_phi=True)), 200


@admin_bp.route('/users/<int:id>/flag', methods=['PUT'])
@token_required
@admin_required
def toggle_flag(id):
    """Toggle the is_flagged status of a user."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    user.is_flagged = not user.is_flagged
    db.session.commit()

    audit_log('UPDATE', 'user', resource_id=str(id),
              details={'action': 'toggle_flag', 'is_flagged': user.is_flagged})

    return jsonify(user.to_dict(include_phi=True)), 200


# ---------- Notes ----------

@admin_bp.route('/users/<int:id>/notes', methods=['GET'])
@token_required
@admin_required
def list_notes(id):
    """List admin notes for a user."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    notes = (AdminNote.query
             .filter_by(user_id=id)
             .order_by(AdminNote.created_at.desc())
             .all())

    audit_log('READ', 'admin_notes', resource_id=str(id),
              details={'count': len(notes)})

    return jsonify({'notes': [n.to_dict() for n in notes]}), 200


@admin_bp.route('/users/<int:id>/notes', methods=['POST'])
@token_required
@admin_required
def create_note(id):
    """Create an admin note for a user."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    text = data.get('text', '').strip()
    if not text:
        return jsonify({'error': 'Note text is required'}), 400
    if len(text) > 5000:
        return jsonify({'error': 'Note text must be 5000 characters or fewer'}), 400

    note = AdminNote(
        user_id=id,
        admin_user_id=g.user_id,
    )
    note.text = text
    db.session.add(note)
    db.session.commit()

    audit_log('CREATE', 'admin_note', resource_id=str(note.id),
              details={'user_id': id})

    return jsonify(note.to_dict()), 201


# ---------- Readings ----------

@admin_bp.route('/readings', methods=['GET'])
@token_required
@admin_required
def list_readings():
    """View readings with filters, sorting, user name join, and pagination."""
    limit = request.args.get('limit', 50, type=int)
    offset = request.args.get('offset', 0, type=int)
    user_id_filter = request.args.get('user_id', type=int)
    from_date = request.args.get('from_date')
    to_date = request.args.get('to_date')

    # Multi-select filters
    bp_category_filter = request.args.get('bp_category', '').strip()
    union_id_filter = request.args.get('union_id', '').strip()
    gender_filter = request.args.get('gender', '').strip()

    # BP range filters
    systolic_min = request.args.get('systolic_min', type=int)
    systolic_max = request.args.get('systolic_max', type=int)
    diastolic_min = request.args.get('diastolic_min', type=int)
    diastolic_max = request.args.get('diastolic_max', type=int)

    # Sort params
    sort_by = request.args.get('sort_by', 'reading_date')
    sort_order = request.args.get('sort_order', 'desc')

    limit = min(limit, 200)

    query = BloodPressureReading.query

    if user_id_filter is not None:
        query = query.filter_by(user_id=user_id_filter)

    if from_date:
        try:
            from_dt = datetime.strptime(from_date, '%Y-%m-%d')
            query = query.filter(BloodPressureReading.reading_date >= from_dt)
        except ValueError:
            return jsonify({'error': 'Invalid from_date format. Use YYYY-MM-DD'}), 400

    if to_date:
        try:
            to_dt = datetime.strptime(to_date, '%Y-%m-%d')
            to_dt = to_dt + timedelta(days=1)
            query = query.filter(BloodPressureReading.reading_date < to_dt)
        except ValueError:
            return jsonify({'error': 'Invalid to_date format. Use YYYY-MM-DD'}), 400

    # BP range filters
    if systolic_min is not None:
        query = query.filter(BloodPressureReading.systolic >= systolic_min)
    if systolic_max is not None:
        query = query.filter(BloodPressureReading.systolic <= systolic_max)
    if diastolic_min is not None:
        query = query.filter(BloodPressureReading.diastolic >= diastolic_min)
    if diastolic_max is not None:
        query = query.filter(BloodPressureReading.diastolic <= diastolic_max)

    # Join User for union/gender filters and user_name
    needs_join = union_id_filter or gender_filter
    if needs_join:
        query = query.join(User, BloodPressureReading.user_id == User.id)
        if union_id_filter:
            try:
                union_ids = [int(x) for x in union_id_filter.split(',')]
                query = query.filter(User.union_id.in_(union_ids))
            except ValueError:
                pass
        if gender_filter:
            query = query.filter(User.gender.in_(gender_filter.split(',')))

    # Sorting
    sort_whitelist = {
        'reading_date': BloodPressureReading.reading_date,
        'systolic': BloodPressureReading.systolic,
        'diastolic': BloodPressureReading.diastolic,
        'heart_rate': BloodPressureReading.heart_rate,
        'user_id': BloodPressureReading.user_id,
    }
    sort_col = sort_whitelist.get(sort_by, BloodPressureReading.reading_date)
    if sort_order == 'asc':
        query = query.order_by(sort_col.asc())
    else:
        query = query.order_by(sort_col.desc())

    # BP category filter requires post-query filtering since it's a derived value
    if bp_category_filter:
        categories = [c.strip().lower() for c in bp_category_filter.split(',')]
        all_readings = query.all()
        filtered = []
        for r in all_readings:
            cat = _classify_bp(r.systolic, r.diastolic).lower()
            if cat in categories:
                filtered.append(r)
        total_count = len(filtered)
        page = filtered[offset:offset + limit]
    else:
        total_count = query.count()
        page = query.offset(offset).limit(limit).all()

    # Build response with user names
    readings_out = []
    # Cache user lookups
    user_cache = {}
    for r in page:
        rd = r.to_dict()
        if r.user_id not in user_cache:
            u = User.query.get(r.user_id)
            if u:
                try:
                    user_cache[r.user_id] = u.name or f'User #{r.user_id}'
                except Exception:
                    user_cache[r.user_id] = f'User #{r.user_id}'
            else:
                user_cache[r.user_id] = f'User #{r.user_id}'
        rd['user_name'] = user_cache[r.user_id]
        readings_out.append(rd)

    audit_log('READ', 'readings_list',
              details={
                  'count': len(page),
                  'filter_user_id': user_id_filter,
                  'from_date': from_date,
                  'to_date': to_date,
              })

    return jsonify({
        'readings': readings_out,
        'total_count': total_count,
    }), 200


def _classify_bp(systolic, diastolic):
    """Classify blood pressure reading into a category."""
    if systolic > 180 or diastolic > 120:
        return 'Crisis'
    if systolic >= 140 or diastolic >= 90:
        return 'Stage 2'
    if systolic >= 130 or diastolic >= 80:
        return 'Stage 1'
    if systolic >= 120 and diastolic < 80:
        return 'Elevated'
    return 'Normal'


# ---------- Call List ----------

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
    now = datetime.utcnow()
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
    now = datetime.utcnow()
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
            attempt.follow_up_date = datetime.utcnow() + timedelta(days=int(follow_up_days))
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
            item.closed_at = datetime.utcnow()
            item.closed_by = g.user_id
            item.cooldown_until = datetime.utcnow() + timedelta(days=COOLDOWN_DAYS)
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
    item.closed_at = datetime.utcnow()
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
            item.follow_up_date = datetime.utcnow() + timedelta(days=int(follow_up_days))
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
    now = datetime.utcnow()
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


# ---------- Email Templates ----------

@admin_bp.route('/email-templates', methods=['GET'])
@token_required
@admin_required
def list_email_templates():
    """List email templates, optionally filtered by list_type."""
    list_type = request.args.get('list_type')
    query = EmailTemplate.query.filter_by(is_active=True)
    if list_type:
        query = query.filter(or_(EmailTemplate.list_type == list_type, EmailTemplate.list_type == 'all'))
    templates = query.order_by(EmailTemplate.name).all()
    return jsonify({'templates': [t.to_dict() for t in templates]}), 200


@admin_bp.route('/email-templates', methods=['POST'])
@token_required
@admin_required
def create_email_template():
    """Create a new email template."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    name = data.get('name', '').strip()
    subject = data.get('subject', '').strip()
    body = data.get('body', '').strip()

    if not name or not subject or not body:
        return jsonify({'error': 'name, subject, and body are required'}), 400

    template = EmailTemplate(
        name=name,
        subject=subject,
        body=body,
        list_type=data.get('list_type', 'all'),
    )
    db.session.add(template)
    db.session.commit()

    audit_log('CREATE', 'email_template', resource_id=str(template.id))

    return jsonify(template.to_dict()), 201


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


# ---------- Unions ----------

@admin_bp.route('/unions', methods=['GET'])
@token_required
@admin_required
def list_unions():
    """List all unions for filter dropdowns."""
    unions = Union.query.filter_by(is_active=True).order_by(Union.name).all()
    return jsonify({
        'unions': [{'id': u.id, 'name': u.name} for u in unions]
    }), 200


# ---------- Bulk Operations ----------

MAX_BULK_USERS = 100


@admin_bp.route('/users/bulk-approve', methods=['POST'])
@token_required
@admin_required
def bulk_approve_users():
    """Approve multiple users at once. Max 100 users per operation."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    user_ids = data.get('user_ids', [])
    if not user_ids:
        return jsonify({'error': 'user_ids array is required'}), 400

    if len(user_ids) > MAX_BULK_USERS:
        return jsonify({'error': f'Maximum {MAX_BULK_USERS} users per operation'}), 400

    results = {
        'success': [],
        'skipped': [],
        'error': []
    }

    for user_id in user_ids:
        try:
            user = User.query.get(user_id)
            if not user:
                results['error'].append({'id': user_id, 'reason': 'User not found'})
                continue

            if user.user_status != 'pending_approval':
                results['skipped'].append({'id': user_id, 'reason': 'Not pending approval'})
                continue

            user.user_status = 'pending_cuff'
            if not user.is_email_verified:
                user.is_email_verified = True

            results['success'].append({'id': user_id})

            # Send notification if configured
            try:
                from app.utils.push_notifications import notify_account_approved
                notify_account_approved(user_id)
            except Exception as e:
                logger.warning(f"Failed to send approval notification to user {user_id}: {e}")

            # Send email notification
            try:
                from app.utils.email_sender import send_account_approved_email
                send_account_approved_email(user.email, user.name)
            except Exception as e:
                logger.warning(f"Failed to send approval email to user {user_id}: {e}")

        except Exception as e:
            logger.error(f"Error approving user {user_id}: {e}")
            results['error'].append({'id': user_id, 'reason': 'Internal error during approval'})

    db.session.commit()

    audit_log('UPDATE', 'user_bulk_approve',
              details={
                  'admin_id': g.user_id,
                  'total_requested': len(user_ids),
                  'success_count': len(results['success']),
                  'skipped_count': len(results['skipped']),
                  'error_count': len(results['error']),
              })

    return jsonify({
        'message': f"Approved {len(results['success'])} users",
        'results': results
    }), 200


@admin_bp.route('/users/bulk-deactivate', methods=['POST'])
@token_required
@admin_required
def bulk_deactivate_users():
    """Deactivate multiple users at once. Max 100 users per operation. Admin users cannot be deactivated."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    user_ids = data.get('user_ids', [])
    if not user_ids:
        return jsonify({'error': 'user_ids array is required'}), 400

    if len(user_ids) > MAX_BULK_USERS:
        return jsonify({'error': f'Maximum {MAX_BULK_USERS} users per operation'}), 400

    results = {
        'success': [],
        'skipped': [],
        'error': []
    }

    for user_id in user_ids:
        try:
            user = User.query.get(user_id)
            if not user:
                results['error'].append({'id': user_id, 'reason': 'User not found'})
                continue

            if user.is_admin:
                results['skipped'].append({'id': user_id, 'reason': 'Cannot deactivate admin user'})
                continue

            if user.user_status == 'deactivated':
                results['skipped'].append({'id': user_id, 'reason': 'Already deactivated'})
                continue

            user.user_status = 'deactivated'
            user.is_active = False
            results['success'].append({'id': user_id})

        except Exception as e:
            logger.error(f"Error deactivating user {user_id}: {e}")
            results['error'].append({'id': user_id, 'reason': 'Internal error during deactivation'})

    db.session.commit()

    audit_log('UPDATE', 'user_bulk_deactivate',
              details={
                  'admin_id': g.user_id,
                  'total_requested': len(user_ids),
                  'success_count': len(results['success']),
                  'skipped_count': len(results['skipped']),
                  'error_count': len(results['error']),
              })

    return jsonify({
        'message': f"Deactivated {len(results['success'])} users",
        'results': results
    }), 200


# ---------- Data Export ----------

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
        now = datetime.utcnow()
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
        headers={'Content-Disposition': f'attachment; filename=users_export_{datetime.utcnow().strftime("%Y%m%d_%H%M%S")}.csv'}
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
        headers={'Content-Disposition': f'attachment; filename=readings_export_{datetime.utcnow().strftime("%Y%m%d_%H%M%S")}.csv'}
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
        headers={'Content-Disposition': f'attachment; filename=call_reports_export_{datetime.utcnow().strftime("%Y%m%d_%H%M%S")}.csv'}
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
    now = datetime.utcnow()
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

    import re
    try:
        raw_name = user.name.replace(' ', '_') if user.name else f'patient_{user_id}'
        # Sanitize: allow only alphanumeric, underscore, hyphen
        patient_name = re.sub(r'[^a-zA-Z0-9_\-]', '', raw_name) or f'patient_{user_id}'
    except Exception:
        patient_name = f'patient_{user_id}'

    return Response(
        pdf_output.getvalue(),
        mimetype='application/pdf',
        headers={'Content-Disposition': f'attachment; filename={patient_name}_report_{datetime.utcnow().strftime("%Y%m%d")}.pdf'}
    )


# ---------- Cuff Requests ----------

@admin_bp.route('/cuff-requests', methods=['GET'])
@token_required
@admin_required
def list_cuff_requests():
    """List all cuff requests with filters."""
    status_filter = request.args.get('status')
    limit = request.args.get('limit', 50, type=int)
    offset = request.args.get('offset', 0, type=int)

    limit = min(limit, 200)

    query = CuffRequest.query

    if status_filter:
        query = query.filter_by(status=status_filter)

    query = query.order_by(CuffRequest.created_at.desc())

    total_count = query.count()
    requests = query.offset(offset).limit(limit).all()

    # Build response with user info
    result = []
    for req in requests:
        req_data = req.to_dict(include_address=True)
        if req.user:
            try:
                req_data['user_name'] = req.user.name
                req_data['user_email'] = req.user.email
            except Exception:
                req_data['user_name'] = f'User #{req.user_id}'
                req_data['user_email'] = None
        result.append(req_data)

    # Summary counts
    summary = {
        'pending': CuffRequest.query.filter_by(status='pending').count(),
        'approved': CuffRequest.query.filter_by(status='approved').count(),
        'shipped': CuffRequest.query.filter_by(status='shipped').count(),
        'delivered': CuffRequest.query.filter_by(status='delivered').count(),
    }

    audit_log('READ', 'cuff_requests', details={'count': len(result)})

    return jsonify({
        'requests': result,
        'total_count': total_count,
        'summary': summary,
    }), 200


@admin_bp.route('/cuff-requests/<int:request_id>/approve', methods=['PUT'])
@token_required
@admin_required
def approve_cuff_request(request_id):
    """Approve a cuff request."""
    cuff_request = CuffRequest.query.get(request_id)
    if not cuff_request:
        return jsonify({'error': 'Cuff request not found'}), 404

    if cuff_request.status != 'pending':
        return jsonify({'error': f'Cannot approve request with status: {cuff_request.status}'}), 400

    data = request.get_json() or {}

    cuff_request.status = 'approved'
    cuff_request.approved_by = g.user_id
    cuff_request.approved_at = datetime.utcnow()

    if data.get('admin_notes'):
        cuff_request.admin_notes = data['admin_notes']

    db.session.commit()

    # Send notification
    try:
        from app.utils.push_notifications import notify_cuff_approved
        notify_cuff_approved(cuff_request.user_id)
    except Exception as e:
        logger.warning(f"Failed to send cuff approval notification: {e}")

    audit_log('UPDATE', 'cuff_request', resource_id=str(request_id),
              details={'action': 'approve', 'admin_id': g.user_id})

    return jsonify(cuff_request.to_dict(include_address=True)), 200


@admin_bp.route('/cuff-requests/<int:request_id>/ship', methods=['PUT'])
@token_required
@admin_required
def ship_cuff_request(request_id):
    """Mark a cuff request as shipped with tracking info."""
    cuff_request = CuffRequest.query.get(request_id)
    if not cuff_request:
        return jsonify({'error': 'Cuff request not found'}), 404

    if cuff_request.status not in ('pending', 'approved'):
        return jsonify({'error': f'Cannot ship request with status: {cuff_request.status}'}), 400

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    tracking_number = data.get('tracking_number', '').strip()
    if not tracking_number:
        return jsonify({'error': 'tracking_number is required'}), 400

    cuff_request.status = 'shipped'
    cuff_request.tracking_number = tracking_number
    cuff_request.carrier = data.get('carrier')
    cuff_request.shipped_by = g.user_id
    cuff_request.shipped_at = datetime.utcnow()

    if data.get('admin_notes'):
        cuff_request.admin_notes = data['admin_notes']

    db.session.commit()

    # Send notification and email
    try:
        from app.utils.push_notifications import notify_cuff_shipped
        notify_cuff_shipped(cuff_request.user_id, tracking_number)
    except Exception as e:
        logger.warning(f"Failed to send cuff shipped notification: {e}")

    try:
        from app.utils.email_sender import send_cuff_shipped_email
        user = User.query.get(cuff_request.user_id)
        if user:
            send_cuff_shipped_email(user.email, user.name, tracking_number)
    except Exception as e:
        logger.warning(f"Failed to send cuff shipped email: {e}")

    audit_log('UPDATE', 'cuff_request', resource_id=str(request_id),
              details={'action': 'ship', 'tracking_number': tracking_number})

    return jsonify(cuff_request.to_dict(include_address=True)), 200


@admin_bp.route('/cuff-requests/<int:request_id>/cancel', methods=['PUT'])
@token_required
@admin_required
def cancel_cuff_request(request_id):
    """Cancel a cuff request."""
    cuff_request = CuffRequest.query.get(request_id)
    if not cuff_request:
        return jsonify({'error': 'Cuff request not found'}), 404

    if cuff_request.status in ('shipped', 'delivered'):
        return jsonify({'error': f'Cannot cancel request with status: {cuff_request.status}'}), 400

    data = request.get_json() or {}

    cuff_request.status = 'cancelled'
    if data.get('admin_notes'):
        cuff_request.admin_notes = data['admin_notes']

    db.session.commit()

    audit_log('UPDATE', 'cuff_request', resource_id=str(request_id),
              details={'action': 'cancel', 'admin_id': g.user_id})

    return jsonify(cuff_request.to_dict(include_address=True)), 200
