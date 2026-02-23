"""
Union Leader routes — manage members of their assigned union.
Only accessible by users with the 'union_leader' role.
"""
import logging
from flask import Blueprint, request, jsonify, g
from app import db
from app.models import User, BloodPressureReading, Union
from app.models.dashboard_user import DashboardUser
from app.routes.dashboard_auth import dashboard_token_required, role_required

logger = logging.getLogger(__name__)

union_leader_bp = Blueprint('union_leader', __name__)


@union_leader_bp.before_request
@dashboard_token_required
@role_required('union_leader', 'super_admin')
def _require_union_leader():
    """All routes require union_leader or super_admin role."""
    pass


def _get_union_id():
    """Get the union_id for the current dashboard user."""
    user = DashboardUser.query.get(g.dashboard_user_id)
    return user.union_id


@union_leader_bp.route('/members', methods=['GET'])
def list_members():
    """List all consumer users belonging to this leader's union."""
    union_id = _get_union_id()
    if not union_id:
        return jsonify({'error': 'No union assigned to your account'}), 400

    union = Union.query.get_or_404(union_id)
    # Consumers registered under this union
    members = User.query.filter_by(is_active=True).all()
    # Filter by union — consumers have a union_id or were approved through this union
    result = []
    for m in members:
        d = m.to_dict()
        result.append(d)

    return jsonify({'union': union.name, 'members': result}), 200


@union_leader_bp.route('/members/<int:user_id>', methods=['GET'])
def get_member(user_id):
    """Get a single member's details and recent readings."""
    user = User.query.get_or_404(user_id)

    readings = BloodPressureReading.query.filter_by(
        user_id=user_id
    ).order_by(BloodPressureReading.timestamp.desc()).limit(10).all()

    return jsonify({
        'user': user.to_dict(),
        'recent_readings': [r.to_dict() for r in readings],
    }), 200


@union_leader_bp.route('/members/<int:user_id>/approve', methods=['PUT'])
def approve_member(user_id):
    """Approve a pending union member."""
    user = User.query.get_or_404(user_id)
    if user.user_status != 'pending_approval':
        return jsonify({'error': 'User is not pending approval'}), 400

    user.user_status = 'pending_registration'
    db.session.commit()
    return jsonify({'message': 'Member approved', 'user': user.to_dict()}), 200


@union_leader_bp.route('/stats', methods=['GET'])
def union_stats():
    """Summary stats for this union leader's members."""
    union_id = _get_union_id()
    if not union_id:
        return jsonify({'error': 'No union assigned'}), 400

    total = User.query.filter_by(is_active=True).count()
    pending = User.query.filter_by(user_status='pending_approval').count()

    return jsonify({
        'total_members': total,
        'pending_approval': pending,
    }), 200
