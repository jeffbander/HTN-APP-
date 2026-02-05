import os
import logging
from flask import Flask, request, redirect
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

db = SQLAlchemy()
migrate = Migrate()


def create_app(config_name=None):
    app = Flask(__name__)

    is_production = os.getenv('FLASK_ENV') == 'production'

    # Require SECRET_KEY — no insecure fallback
    secret_key = os.getenv('SECRET_KEY')
    if not secret_key:
        raise RuntimeError('SECRET_KEY environment variable is required')
    app.config['SECRET_KEY'] = secret_key

    # Database configuration
    database_url = os.getenv('DATABASE_URL')
    if not database_url:
        raise RuntimeError('DATABASE_URL environment variable is required')

    # In production, require PostgreSQL
    if is_production and not database_url.startswith('postgresql'):
        raise RuntimeError(
            'HIPAA requires PostgreSQL in production. '
            'DATABASE_URL must start with postgresql://'
        )

    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }

    # Request size limit (1 MB)
    app.config['MAX_CONTENT_LENGTH'] = 1 * 1024 * 1024

    # Initialize extensions
    db.init_app(app)
    migrate.init_app(app, db)

    # CORS — restrict origins
    allowed_origins = os.getenv('ALLOWED_ORIGINS', '')
    if allowed_origins:
        origins_list = [o.strip() for o in allowed_origins.split(',') if o.strip()]
    elif is_production:
        raise RuntimeError(
            'ALLOWED_ORIGINS environment variable is required in production'
        )
    else:
        # Development: allow localhost variants
        origins_list = [
            'http://localhost:*',
            'http://127.0.0.1:*',
        ]

    CORS(app, resources={
        r"/consumer/*": {"origins": origins_list},
        r"/admin/*": {"origins": origins_list}
    })

    # Redirect HTTP to HTTPS in production
    if is_production:
        @app.before_request
        def enforce_https():
            if not request.is_secure and request.headers.get('X-Forwarded-Proto', 'http') != 'https':
                url = request.url.replace('http://', 'https://', 1)
                return redirect(url, code=301)

    # Security headers
    @app.after_request
    def add_security_headers(response):
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        response.headers['Content-Security-Policy'] = "default-src 'none'; frame-ancestors 'none'"
        response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
        response.headers['Pragma'] = 'no-cache'
        response.headers['Referrer-Policy'] = 'no-referrer'
        response.headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=()'
        response.headers['X-Permitted-Cross-Domain-Policies'] = 'none'
        if is_production or request.is_secure:
            response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
        return response

    # Validate Content-Type on POST/PUT requests (CSRF-like protection for API)
    @app.before_request
    def validate_content_type():
        if request.method in ('POST', 'PUT') and request.path != '/health':
            content_type = request.content_type or ''
            if 'application/json' not in content_type:
                from flask import jsonify
                return jsonify({'error': 'Content-Type must be application/json'}), 415

    # Setup audit logging
    from app.utils.audit_logger import setup_audit_logging
    setup_audit_logging(app)

    # Register blueprints
    from app.routes.consumer import consumer_bp
    from app.routes.admin import admin_bp

    app.register_blueprint(consumer_bp, url_prefix='/consumer')
    app.register_blueprint(admin_bp, url_prefix='/admin')

    # Health check endpoint
    @app.route('/health')
    def health():
        return {'status': 'healthy'}, 200

    # CLI cleanup commands
    @app.cli.command('cleanup-revoked-tokens')
    def cleanup_revoked_tokens():
        """Remove expired revoked token entries."""
        from app.models.revoked_token import RevokedToken
        count = RevokedToken.cleanup_expired()
        print(f'Removed {count} expired revoked token(s).')

    @app.cli.command('cleanup-rate-limits')
    def cleanup_rate_limits():
        """Remove rate limit entries older than 5 minutes."""
        from app.models.rate_limit_entry import RateLimitEntry
        count = RateLimitEntry.cleanup_older_than(300)
        print(f'Removed {count} old rate limit entry/entries.')

    return app
