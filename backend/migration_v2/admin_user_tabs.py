"""
Admin user management endpoints — serves the tabbed dashboard.

Add these routes to app/routes/admin.py (or create a new blueprint).

Tabs:
  1. All Users          — everyone
  2. Active             — user_status='active' AND last reading within 8 months
  3. Pending Approval   — user_status='pending_approval'
  4. Pending Registration — user_status='pending_registration'
  5. Pending Cuff       — user_status='pending_cuff'
  6. Pending First Reading — user_status='pending_first_reading'
  7. Enrollment Only    — user_status='enrollment_only'
  8. Deactivated        — user_status='deactivated' OR (active + no reading in 8 months)
"""

from datetime import datetime, timedelta
from flask import jsonify, request
from sqlalchemy import func, case, and_, or_

from app import db
from app.models.user import User
from app.models.reading import BloodPressureReading


# ---------------------------------------------------------------------------
# Helper: Get last reading date per user as a subquery
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# Helper: Apply common filters from query params
# ---------------------------------------------------------------------------
def _apply_filters(query, args):
    """Apply search, union, and sort filters from request args."""

    # Text search (name or email — requires decryption, so we do it in Python
    # for now. For production, consider a search index.)
    search = args.get('search', '').strip()

    # Union filter
    union_id = args.get('union_id', type=int)
    if union_id:
        query = query.filter(User.union_id == union_id)

    # Gender filter
    gender = args.get('gender', '').strip()
    if gender:
        query = query.filter(User.gender == gender)

    # Has HTN filter
    has_htn = args.get('has_htn', '').strip().lower()
    if has_htn == 'true':
        query = query.filter(User.has_high_blood_pressure == True)
    elif has_htn == 'false':
        query = query.filter(User.has_high_blood_pressure == False)

    # Sort
    sort_by = args.get('sort', 'created_at')
    sort_dir = args.get('dir', 'desc')

    sortable = {
        'created_at': User.created_at,
        'updated_at': User.updated_at,
        'union_id': User.union_id,
    }
    sort_col = sortable.get(sort_by, User.created_at)
    query = query.order_by(sort_col.desc() if sort_dir == 'desc' else sort_col.asc())

    # Pagination
    page = args.get('page', 1, type=int)
    per_page = args.get('per_page', 50, type=int)
    per_page = min(per_page, 200)  # cap

    return query, search, page, per_page


def _paginate_and_search(query, search, page, per_page):
    """Execute query, apply text search in Python (post-decryption), paginate."""
    if search:
        # For encrypted fields we must decrypt and filter in Python.
        # This is O(n) but acceptable for ~1000 users.
        # For scale, add an email_hash search or a search index.
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


# ---------------------------------------------------------------------------
# Tab counts endpoint — returns count for each tab badge
# ---------------------------------------------------------------------------
# GET /admin/users/tab-counts
def get_tab_counts():
    """Return user counts for each dashboard tab."""
    cutoff = datetime.utcnow() - timedelta(days=240)  # 8 months
    last_reading = _last_reading_subquery()

    # Active = status='active' AND last reading within 8 months
    active_count = (
        db.session.query(func.count(User.id))
        .outerjoin(last_reading, User.id == last_reading.c.user_id)
        .filter(User.user_status == 'active')
        .filter(last_reading.c.last_reading_date >= cutoff)
        .scalar()
    )

    # Auto-deactivated = status='active' but last reading > 8 months
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

    # Manually deactivated
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


# ---------------------------------------------------------------------------
# Tab data endpoint — returns filtered/paginated users for a specific tab
# ---------------------------------------------------------------------------
# GET /admin/users/tab/<tab_name>
def get_tab_users(tab_name):
    """Return paginated users for a specific dashboard tab."""
    cutoff = datetime.utcnow() - timedelta(days=240)
    last_reading = _last_reading_subquery()
    args = request.args

    if tab_name == 'all':
        query = User.query

    elif tab_name == 'active':
        # Active AND last reading within 8 months
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
        # Manually deactivated OR active with stale readings
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

    query, search, page, per_page = _apply_filters(query, args)
    users, total = _paginate_and_search(query, search, page, per_page)

    # Build response with last_reading_date included
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


# ---------------------------------------------------------------------------
# Status change endpoint — admin manually changes a user's status
# ---------------------------------------------------------------------------
# PUT /admin/users/<user_id>/status
def update_user_status(user_id):
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

    return jsonify({
        'message': f'Status changed from {old_status} to {new_status}',
        'user': user.to_dict(include_phi=True),
    })


# ---------------------------------------------------------------------------
# Register routes — add these to your admin blueprint
# ---------------------------------------------------------------------------
"""
Add to app/routes/admin.py:

@admin_bp.route('/users/tab-counts', methods=['GET'])
@admin_required
def tab_counts():
    return get_tab_counts()

@admin_bp.route('/users/tab/<tab_name>', methods=['GET'])
@admin_required
def tab_users(tab_name):
    return get_tab_users(tab_name)

@admin_bp.route('/users/<int:user_id>/status', methods=['PUT'])
@admin_required
def change_user_status(user_id):
    return update_user_status(user_id)
"""
