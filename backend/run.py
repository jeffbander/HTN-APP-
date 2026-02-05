"""
Flask development server entry point.
"""
import os
from app import create_app

app = create_app()

if __name__ == '__main__':
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', 3001))
    is_production = os.getenv('FLASK_ENV') == 'production'
    debug = not is_production

    ssl_context = None
    cert_path = os.getenv('SSL_CERT_PATH')
    key_path = os.getenv('SSL_KEY_PATH')

    if cert_path and key_path and os.path.exists(cert_path) and os.path.exists(key_path):
        ssl_context = (cert_path, key_path)
    elif is_production:
        raise RuntimeError(
            'SSL certificates are required in production. '
            'Set SSL_CERT_PATH and SSL_KEY_PATH to valid certificate files.'
        )

    app.run(
        host=host,
        port=port,
        debug=debug,
        ssl_context=ssl_context
    )
