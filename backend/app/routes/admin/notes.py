"""Admin notes routes."""
from flask import request, jsonify, g
from app import db
from app.models import User, AdminNote
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from . import admin_bp, admin_required


@admin_bp.route('/users/<int:id>/notes', methods=['GET'])
@token_required
@admin_required
def list_notes(id):
    """List admin notes for a user."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    notes = (AdminNote.query
             .filter_by(user_id=id)
             .order_by(AdminNote.created_at.desc())
             .all())

    audit_log('READ', 'admin_notes', resource_id=str(id),
              details={'count': len(notes)})

    return jsonify({'notes': [n.to_dict() for n in notes]}), 200


@admin_bp.route('/users/<int:id>/notes', methods=['POST'])
@token_required
@admin_required
def create_note(id):
    """Create an admin note for a user."""
    user = User.query.get(id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    text = data.get('text', '').strip()
    if not text:
        return jsonify({'error': 'Note text is required'}), 400
    if len(text) > 5000:
        return jsonify({'error': 'Note text must be 5000 characters or fewer'}), 400

    note = AdminNote(
        user_id=id,
        admin_user_id=g.user_id,
    )
    note.text = text
    db.session.add(note)
    db.session.commit()

    audit_log('CREATE', 'admin_note', resource_id=str(note.id),
              details={'user_id': id})

    return jsonify(note.to_dict()), 201
