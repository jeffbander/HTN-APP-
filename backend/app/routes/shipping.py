"""
Shipping Company routes — manage cuff shipments.
Only accessible by users with the 'shipping_company' role.
"""
import logging
from flask import Blueprint, request, jsonify, g
from app import db
from app.models import CuffRequest, User
from app.routes.dashboard_auth import dashboard_token_required, role_required

logger = logging.getLogger(__name__)

shipping_bp = Blueprint('shipping', __name__)


@shipping_bp.before_request
@dashboard_token_required
@role_required('shipping_company', 'super_admin')
def _require_shipping():
    """All routes require shipping_company or super_admin role."""
    pass


@shipping_bp.route('/cuff-requests', methods=['GET'])
def list_cuff_requests():
    """List all cuff requests, optionally filtered by status."""
    status = request.args.get('status')
    query = CuffRequest.query.order_by(CuffRequest.created_at.desc())
    if status:
        query = query.filter_by(status=status)

    requests_list = query.all()
    return jsonify([r.to_dict() for r in requests_list]), 200


@shipping_bp.route('/cuff-requests/<int:request_id>/ship', methods=['PUT'])
def mark_shipped(request_id):
    """Mark a cuff request as shipped with tracking info."""
    cuff_req = CuffRequest.query.get_or_404(request_id)
    data = request.get_json() or {}

    tracking_number = data.get('tracking_number', '').strip()
    carrier = data.get('carrier', '').strip()

    cuff_req.status = 'shipped'
    if hasattr(cuff_req, 'tracking_number'):
        cuff_req.tracking_number = tracking_number
    if hasattr(cuff_req, 'carrier'):
        cuff_req.carrier = carrier

    # Update user status to pending_first_reading
    user = User.query.get(cuff_req.user_id)
    if user and user.user_status == 'pending_cuff':
        user.user_status = 'pending_first_reading'

    db.session.commit()
    return jsonify({'message': 'Marked as shipped', 'request': cuff_req.to_dict()}), 200


@shipping_bp.route('/cuff-requests/<int:request_id>/deliver', methods=['PUT'])
def mark_delivered(request_id):
    """Mark a cuff request as delivered."""
    cuff_req = CuffRequest.query.get_or_404(request_id)
    cuff_req.status = 'delivered'
    db.session.commit()
    return jsonify({'message': 'Marked as delivered', 'request': cuff_req.to_dict()}), 200


@shipping_bp.route('/stats', methods=['GET'])
def shipping_stats():
    """Summary stats for shipping operations."""
    from sqlalchemy import func
    counts = db.session.query(
        CuffRequest.status, func.count(CuffRequest.id)
    ).group_by(CuffRequest.status).all()

    return jsonify({
        'by_status': {status: count for status, count in counts},
        'total': sum(c for _, c in counts),
    }), 200
