"""Admin stats routes."""
from datetime import datetime
from flask import jsonify
from app import db
from app.models import User, BloodPressureReading
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from . import admin_bp, admin_required


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
