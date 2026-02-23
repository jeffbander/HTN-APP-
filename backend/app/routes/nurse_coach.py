"""
Nurse Coach routes — patient monitoring and call management.
Only accessible by users with the 'nurse_coach' role.
"""
import logging
from flask import Blueprint, request, jsonify, g
from app import db
from app.models import User, BloodPressureReading, CallListItem, CallAttempt, AdminNote
from app.routes.dashboard_auth import dashboard_token_required, role_required

logger = logging.getLogger(__name__)

nurse_bp = Blueprint('nurse_coach', __name__)


@nurse_bp.before_request
@dashboard_token_required
@role_required('nurse_coach', 'super_admin')
def _require_nurse():
    """All routes require nurse_coach or super_admin role."""
    pass


@nurse_bp.route('/patients', methods=['GET'])
def list_patients():
    """List active patients for monitoring."""
    status = request.args.get('status', 'active')
    patients = User.query.filter_by(
        user_status=status, is_active=True
    ).order_by(User.id.desc()).all()
    return jsonify([p.to_dict() for p in patients]), 200


@nurse_bp.route('/patients/<int:user_id>', methods=['GET'])
def get_patient(user_id):
    """Get patient detail with readings and notes."""
    user = User.query.get_or_404(user_id)
    readings = BloodPressureReading.query.filter_by(
        user_id=user_id
    ).order_by(BloodPressureReading.timestamp.desc()).limit(20).all()
    notes = AdminNote.query.filter_by(
        user_id=user_id
    ).order_by(AdminNote.created_at.desc()).limit(10).all()

    return jsonify({
        'user': user.to_dict(),
        'readings': [r.to_dict() for r in readings],
        'notes': [n.to_dict() for n in notes],
    }), 200


@nurse_bp.route('/patients/<int:user_id>/notes', methods=['POST'])
def add_patient_note(user_id):
    """Add a clinical note to a patient."""
    User.query.get_or_404(user_id)
    data = request.get_json() or {}
    content = (data.get('content') or '').strip()
    if not content:
        return jsonify({'error': 'Note content is required'}), 400

    note = AdminNote(
        user_id=user_id,
        admin_id=g.dashboard_user_id,
        content=content,
    )
    db.session.add(note)
    db.session.commit()
    return jsonify(note.to_dict()), 201


@nurse_bp.route('/call-list', methods=['GET'])
def get_call_list():
    """Get the nurse's call list."""
    items = CallListItem.query.filter_by(
        is_closed=False
    ).order_by(CallListItem.priority.desc(), CallListItem.created_at.asc()).all()
    return jsonify([item.to_dict() for item in items]), 200


@nurse_bp.route('/call-list/<int:item_id>/attempt', methods=['POST'])
def log_call_attempt(item_id):
    """Log a call attempt for a call list item."""
    item = CallListItem.query.get_or_404(item_id)
    data = request.get_json() or {}

    attempt = CallAttempt(
        call_list_item_id=item.id,
        admin_id=g.dashboard_user_id,
        outcome=data.get('outcome', 'no_answer'),
        notes=data.get('notes', ''),
    )
    db.session.add(attempt)
    db.session.commit()
    return jsonify(attempt.to_dict()), 201


@nurse_bp.route('/flagged-patients', methods=['GET'])
def flagged_patients():
    """List patients that have been flagged for attention."""
    patients = User.query.filter_by(
        is_flagged=True, is_active=True
    ).order_by(User.id.desc()).all()
    return jsonify([p.to_dict() for p in patients]), 200


@nurse_bp.route('/stats', methods=['GET'])
def nurse_stats():
    """Summary stats for the nurse dashboard."""
    active = User.query.filter_by(user_status='active', is_active=True).count()
    flagged = User.query.filter_by(is_flagged=True, is_active=True).count()
    open_calls = CallListItem.query.filter_by(is_closed=False).count()

    return jsonify({
        'active_patients': active,
        'flagged_patients': flagged,
        'open_call_items': open_calls,
    }), 200
