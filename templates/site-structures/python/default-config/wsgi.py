# templates/site-structures/python/default-config/wsgi.py
"""
WSGI config for Python applications
"""

import os
import sys

# Add the site directory to the Python path
site_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(site_dir)

# Set environment variables
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.production')
os.environ.setdefault('PYTHON_ENV', 'production')

# Initialize application
try:
    from django.core.wsgi import get_wsgi_application
    application = get_wsgi_application()
except ImportError:
    # Fallback for non-Django applications
    def application(environ, start_response):
        status = '200 OK'
        headers = [('Content-type', 'text/plain')]
        start_response(status, headers)
        return [b'Python application not configured']