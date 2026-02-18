"""Admin readings routes."""
from datetime import datetime, timedelta
from flask import request, jsonify
from app import db
from app.models import User, BloodPressureReading
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from . import admin_bp, admin_required


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
