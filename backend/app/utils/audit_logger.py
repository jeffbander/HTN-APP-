"""
HIPAA-compliant audit logging.
Logs all access to PHI with timestamp, user, action, and resource.
"""
import os
import logging
import structlog
from datetime import datetime, timezone
from flask import request, g
from functools import wraps


def setup_audit_logging(app):
    """Configure structured audit logging for HIPAA compliance."""

    log_file = os.getenv('AUDIT_LOG_FILE', 'logs/audit.log')
    os.makedirs(os.path.dirname(log_file), exist_ok=True)

    # Configure structlog for JSON output
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    # File handler for audit logs
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(logging.Formatter('%(message)s'))

    audit_logger = logging.getLogger('audit')
    audit_logger.setLevel(logging.INFO)
    audit_logger.addHandler(file_handler)

    app.config['AUDIT_LOGGER'] = structlog.get_logger('audit')


def get_audit_logger():
    """Get the audit logger instance."""
    from flask import current_app
    return current_app.config.get('AUDIT_LOGGER', structlog.get_logger('audit'))


def audit_log(action: str, resource_type: str, resource_id: str = None,
              details: dict = None, user_id: str = None):
    """
    Log an audit event for HIPAA compliance.

    Args:
        action: The action performed (CREATE, READ, UPDATE, DELETE, LOGIN, etc.)
        resource_type: Type of resource accessed (user, reading, etc.)
        resource_id: ID of the specific resource (optional)
        details: Additional details about the action (optional)
        user_id: ID of the user performing the action (optional, uses g.user_id if not provided)
    """
    logger = get_audit_logger()

    # Get user ID from context if not provided
    if user_id is None:
        user_id = getattr(g, 'user_id', 'anonymous')

    # Get request info
    client_ip = request.remote_addr if request else 'unknown'
    user_agent = request.headers.get('User-Agent', 'unknown') if request else 'unknown'

    log_entry = {
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'action': action,
        'resource_type': resource_type,
        'resource_id': resource_id,
        'user_id': user_id,
        'client_ip': client_ip,
        'user_agent': user_agent,
        'details': details or {}
    }

    logger.info("audit_event", **log_entry)


def audit_phi_access(action: str, resource_type: str):
    """
    Decorator to automatically log PHI access for a route.
    """
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            resource_id = kwargs.get('id') or kwargs.get('user_id')
            audit_log(action, resource_type, resource_id=str(resource_id) if resource_id else None)
            return f(*args, **kwargs)
        return wrapper
    return decorator
