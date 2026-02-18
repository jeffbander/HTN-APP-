"""
Admin API routes.
"""
import logging
from functools import wraps
from flask import Blueprint, jsonify, g
from app.models import User

logger = logging.getLogger(__name__)

admin_bp = Blueprint('admin', __name__)


def admin_required(f):
    """Decorator that requires the authenticated user to be an admin."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        user = User.query.get(g.user_id)
        if not user or not user.is_admin:
            return jsonify({'error': 'Admin access required'}), 403
        return f(*args, **kwargs)
    return wrapper


# Import submodules to register routes on admin_bp
from . import stats      # noqa: E402, F401
from . import users      # noqa: E402, F401
from . import notes      # noqa: E402, F401
from . import readings   # noqa: E402, F401
from . import call_list  # noqa: E402, F401
from . import email_templates  # noqa: E402, F401
from . import unions     # noqa: E402, F401
from . import exports    # noqa: E402, F401
from . import cuff_requests  # noqa: E402, F401
