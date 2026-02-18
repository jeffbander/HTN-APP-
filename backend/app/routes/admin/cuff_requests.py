"""Admin cuff request routes."""
import logging
from datetime import datetime, timezone
from flask import request, jsonify, g
from app import db
from app.models import User, CuffRequest
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from . import admin_bp, admin_required

logger = logging.getLogger(__name__)


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
    cuff_request.approved_at = datetime.now(timezone.utc)

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
    cuff_request.shipped_at = datetime.now(timezone.utc)

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
