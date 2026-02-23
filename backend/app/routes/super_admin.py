"""
Super Admin routes — full system management.
Only accessible by users with the 'super_admin' role.
"""
import logging
from flask import Blueprint, request, jsonify, g
from app import db
from app.models.dashboard_user import DashboardUser, DASHBOARD_ROLES
from app.routes.dashboard_auth import dashboard_token_required, role_required
from app.utils.audit_logger import audit_log

logger = logging.getLogger(__name__)

super_admin_bp = Blueprint('super_admin', __name__)


@super_admin_bp.before_request
@dashboard_token_required
@role_required('super_admin')
def _require_super_admin():
    """All routes in this blueprint require super_admin role."""
    pass


# ---------------------------------------------------------------------------
# Dashboard user management
# ---------------------------------------------------------------------------

@super_admin_bp.route('/dashboard-users', methods=['GET'])
def list_dashboard_users():
    """List all dashboard users."""
    users = DashboardUser.query.order_by(DashboardUser.created_at.desc()).all()
    return jsonify([u.to_dict() for u in users]), 200


@super_admin_bp.route('/dashboard-users', methods=['POST'])
def create_dashboard_user():
    """Create a new dashboard user."""
    data = request.get_json() or {}
    email = (data.get('email') or '').strip().lower()
    name = (data.get('name') or '').strip()
    role = data.get('role', 'nurse_coach')

    if not email or not name:
        return jsonify({'error': 'Email and name are required'}), 400
    if role not in DASHBOARD_ROLES:
        return jsonify({'error': f'Invalid role. Must be one of: {DASHBOARD_ROLES}'}), 400

    if DashboardUser.query.filter_by(email=email).first():
        return jsonify({'error': 'A user with this email already exists'}), 409

    user = DashboardUser(
        email=email,
        name=name,
        role=role,
        union_id=data.get('union_id'),
        is_active=True,
    )
    db.session.add(user)
    db.session.commit()

    audit_log('CREATE', 'dashboard_user', resource_id=str(user.id),
              details={'role': role, 'created_by': g.dashboard_user_id})

    return jsonify(user.to_dict()), 201


@super_admin_bp.route('/dashboard-users/<int:user_id>', methods=['GET'])
def get_dashboard_user(user_id):
    """Get a single dashboard user."""
    user = DashboardUser.query.get_or_404(user_id)
    return jsonify(user.to_dict()), 200


@super_admin_bp.route('/dashboard-users/<int:user_id>', methods=['PUT'])
def update_dashboard_user(user_id):
    """Update a dashboard user's role, name, or active status."""
    user = DashboardUser.query.get_or_404(user_id)
    data = request.get_json() or {}

    if 'role' in data:
        if data['role'] not in DASHBOARD_ROLES:
            return jsonify({'error': f'Invalid role. Must be one of: {DASHBOARD_ROLES}'}), 400
        user.role = data['role']
    if 'name' in data:
        user.name = data['name']
    if 'is_active' in data:
        user.is_active = bool(data['is_active'])
    if 'union_id' in data:
        user.union_id = data['union_id']

    db.session.commit()
    audit_log('UPDATE', 'dashboard_user', resource_id=str(user.id),
              details={'updated_by': g.dashboard_user_id})

    return jsonify(user.to_dict()), 200


@super_admin_bp.route('/dashboard-users/<int:user_id>', methods=['DELETE'])
def deactivate_dashboard_user(user_id):
    """Deactivate a dashboard user (soft delete)."""
    user = DashboardUser.query.get_or_404(user_id)
    user.is_active = False
    db.session.commit()
    audit_log('DEACTIVATE', 'dashboard_user', resource_id=str(user.id),
              details={'deactivated_by': g.dashboard_user_id})
    return jsonify({'message': 'User deactivated'}), 200


# ---------------------------------------------------------------------------
# System overview (super admin can see everything)
# ---------------------------------------------------------------------------

@super_admin_bp.route('/stats', methods=['GET'])
def super_admin_stats():
    """System-wide stats: total users by role, active sessions, etc."""
    from app.models import User
    from sqlalchemy import func

    consumer_count = User.query.filter_by(is_active=True).count()
    dashboard_counts = db.session.query(
        DashboardUser.role, func.count(DashboardUser.id)
    ).filter_by(is_active=True).group_by(DashboardUser.role).all()

    return jsonify({
        'active_consumers': consumer_count,
        'dashboard_users_by_role': {role: count for role, count in dashboard_counts},
        'total_dashboard_users': sum(c for _, c in dashboard_counts),
    }), 200
