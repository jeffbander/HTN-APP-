"""Admin email template routes."""
from flask import request, jsonify
from sqlalchemy import or_
from app import db
from app.models import EmailTemplate
from app.utils.auth import token_required
from app.utils.audit_logger import audit_log
from . import admin_bp, admin_required


@admin_bp.route('/email-templates', methods=['GET'])
@token_required
@admin_required
def list_email_templates():
    """List email templates, optionally filtered by list_type."""
    list_type = request.args.get('list_type')
    query = EmailTemplate.query.filter_by(is_active=True)
    if list_type:
        query = query.filter(or_(EmailTemplate.list_type == list_type, EmailTemplate.list_type == 'all'))
    templates = query.order_by(EmailTemplate.name).all()
    return jsonify({'templates': [t.to_dict() for t in templates]}), 200


@admin_bp.route('/email-templates', methods=['POST'])
@token_required
@admin_required
def create_email_template():
    """Create a new email template."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    name = data.get('name', '').strip()
    subject = data.get('subject', '').strip()
    body = data.get('body', '').strip()

    if not name or not subject or not body:
        return jsonify({'error': 'name, subject, and body are required'}), 400

    template = EmailTemplate(
        name=name,
        subject=subject,
        body=body,
        list_type=data.get('list_type', 'all'),
    )
    db.session.add(template)
    db.session.commit()

    audit_log('CREATE', 'email_template', resource_id=str(template.id))

    return jsonify(template.to_dict()), 201
