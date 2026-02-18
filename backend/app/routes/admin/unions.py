"""Admin union routes."""
from flask import jsonify
from app.models import Union
from app.utils.auth import token_required
from . import admin_bp, admin_required


@admin_bp.route('/unions', methods=['GET'])
@token_required
@admin_required
def list_unions():
    """List all unions for filter dropdowns."""
    unions = Union.query.filter_by(is_active=True).order_by(Union.name).all()
    return jsonify({
        'unions': [{'id': u.id, 'name': u.name} for u in unions]
    }), 200
