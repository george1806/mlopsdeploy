# -*- coding: utf-8 -*-
"""
Flask-AppBuilder configuration file for Airflow 3.0 with Keycloak OAuth integration
"""

import os
from flask_appbuilder.security.manager import AUTH_OAUTH

# Enable OAuth authentication
AUTH_TYPE = AUTH_OAUTH

# OAuth configuration - manual endpoints to avoid metadata discovery issues
KEYCLOAK_INTERNAL_HOST = os.environ.get('KEYCLOAK_INTERNAL_HOST', 'http://keycloak.keycloak.svc.cluster.local:8080')
KEYCLOAK_EXTERNAL_HOST = os.environ.get('KEYCLOAK_HOST', 'https://keycloak.local')
KEYCLOAK_REALM = os.environ.get('KEYCLOAK_REALM', 'mlops')

OAUTH_PROVIDERS = [
    {
        "name": "keycloak",
        "icon": "fa-key",
        "token_key": "access_token",
        "remote_app": {
            "client_id": os.environ.get('KEYCLOAK_CLIENT_ID', 'airflow-client'),
            "client_secret": os.environ.get('KEYCLOAK_CLIENT_SECRET', ''),
            "api_base_url": f"{KEYCLOAK_INTERNAL_HOST}/realms/{KEYCLOAK_REALM}/protocol/",
            "access_token_url": f"{KEYCLOAK_INTERNAL_HOST}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token",
            "authorize_url": f"{KEYCLOAK_EXTERNAL_HOST}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/auth",
            "userinfo_url": f"{KEYCLOAK_INTERNAL_HOST}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/userinfo",
            "jwks_uri": f"{KEYCLOAK_INTERNAL_HOST}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs",
            "issuer": f"{KEYCLOAK_EXTERNAL_HOST}/realms/{KEYCLOAK_REALM}",
            "client_kwargs": {
                "scope": "openid email profile",
                "token_endpoint_auth_method": "client_secret_post"
            },
            "access_token_params": {
                "grant_type": "authorization_code"
            },
            "request_token_url": None,
        },
    }
]

# Additional Flask-AppBuilder security settings
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Admin"

# Role mapping for OAuth users
AUTH_ROLES_MAPPING = {
    "airflow_user": ["User"],
    "airflow_admin": ["Admin"],
}

# Auto-assign default role to OAuth users (Admin for now, can be customized later)
# AUTH_USER_REGISTRATION_ROLE_JMESPATH = "contains(groups[*], 'airflow_admin') && 'Admin' || 'User'"