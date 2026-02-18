"""Admin user management routes."""
import logging
from datetime import datetime, timedelta
from flask import request, jsonify, g
from sqlalchemy import func, or_, and_
from app import db
from app.models import User, BloodPressureReading
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from . import admin_bp, admin_required

logger = logging.getLogger(__name__)

MAX_BULK_USERS = 100


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
