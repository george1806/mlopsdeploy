# Keycloak Setup for Airflow OIDC Authentication

This guide explains how to prepare **Keycloak (v26.x)** for Airflow integration using **OpenID Connect (OIDC)**.  
Follow these steps **before deploying Airflow**.

---

## 1. Log in to Keycloak

-   Open: `https://keycloak.local`
-   Log in as: `admin` (Keycloak administrator)

---

## 2. Create a New Realm

1. In the left-hand menu, click **Realm selector → Create Realm**.
2. Enter:
    - **Realm name**: `mlops`
3. Click **Create**.

---

## 3. Create a Client for Airflow

1. Go to **Clients → Create Client**.
2. Fill in:
    - **Client ID**: `airflow-client`
    - **Client Protocol**: `openid-connect`
    - **Client Authentication**: **ON** (confidential client)
    - **Authorization**: leave **OFF**
3. Click **Save**.

---

## 4. Configure Client Settings

1. Open the newly created client (`airflow-client`).
2. Set the following:

-   **Root URL**
    https://airflow.local

-   **Valid Redirect URIs**

https://airflow.local/*

-   **Web Origins**  
    https://airflow.local

-   **Access Type**: `confidential`
-   **Authentication flow**:
-   ✅ Standard flow
-   ✅ Direct access grants (optional, for CLI/API login)
-   ❌ Leave all others disabled (Implicit, Service accounts, Device flow, CIBA)

3. Click **Save**.

---

## 5. Configure Client Credentials

1. Go to the **Credentials** tab.
2. Copy the generated **Client Secret**.
3. Save it in your Airflow `.env.local` file:

```bash
KEYCLOAK_CLIENT_SECRET=<secret_from_keycloak>
```

---

## 6. Create Test Users (Optional)

1. Go to **Users → Add User**.
2. Fill in:
   - **Username**: `airflow`
   - **Email**: `airflow@example.com`
   - **First name**: `Airflow`
   - **Last name**: `User`
   - **Email Verified**: **ON**
3. Click **Save**.
4. Go to **Credentials** tab → **Set Password**:
   - **Password**: `password`
   - **Temporary**: **OFF**
5. Click **Save**.

---

# Airflow OAuth Setup Guide

This section covers building and deploying Airflow with Keycloak OAuth authentication for offline production environments.

---

## Prerequisites

- Keycloak configured as described above
- Docker and Harbor registry access
- Kubernetes cluster with kubectl access
- Helm installed

---

## Step 1: Build Custom Airflow Image with OAuth Dependencies

### 1.1 Navigate to Airflow Directory
```bash
cd /path/to/mlopsdeploy/apps/airflow
```

### 1.2 Verify OAuth Configuration Files

Ensure the following files exist with correct OAuth configuration:

**`img-prep/webserver_config.py`** - Main OAuth configuration:
```python
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
```

**`img-prep/Dockerfile`** - Custom image definition:
```dockerfile
FROM harbor.local:30002/mlops/airflow:3.0.2

# Install OAuth dependencies
RUN pip install --no-cache-dir \
    requests-oauthlib==1.1.0 \
    flask-oauthlib==0.9.6 \
    authlib==1.2.1

# Verify installations
RUN python -c "import flask_oauthlib; print('flask-oauthlib installed')" && \
    python -c "import authlib; print('authlib installed')" && \
    python -c "import requests_oauthlib; print('requests-oauthlib installed')" && \
    echo "All OAuth dependencies installed successfully"

WORKDIR /opt/airflow

# Copy the webserver configuration
COPY --chown=airflow:root webserver_config.py /opt/airflow/webserver_config.py
```

### 1.3 Build and Push Custom Image

Execute the build script:
```bash
./img-prep/build-custom-image.sh
```

This script will:
- Load environment variables from `.env.local`
- Build the custom Docker image with OAuth dependencies
- Push the image to Harbor registry as `harbor.local:30002/mlops/airflow:3.0.2-oauth`

**Expected Output:**
```
🚀 Building custom Airflow image with OAuth dependencies...
✅ Loaded environment from /home/user/mlopsdeploy/apps/airflow/.env.local
📋 Build configuration:
  Base image: harbor.local:30002/mlops/airflow:3.0.2
  Custom image: harbor.local:30002/mlops/airflow:3.0.2-oauth
🎉 Custom Airflow image with OAuth support ready!
```

---

## Step 2: Configure Environment Variables

### 2.1 Update `.env.local` File

Ensure your `.env.local` file contains all required OAuth variables:

```bash
# Keycloak OAuth Configuration
KEYCLOAK_HOST=https://keycloak.local
KEYCLOAK_REALM=mlops
KEYCLOAK_CLIENT_ID=airflow-client
KEYCLOAK_CLIENT_SECRET=<your_client_secret_from_keycloak>

# Airflow Image Configuration
AIRFLOW_TAG=3.0.2
HARBOR_URL=harbor.local:30002
HARBOR_PROJECT=mlops

# Other required variables...
AIRFLOW_EXECUTOR=CeleryExecutor
AIRFLOW_DB_HOST=postgresql-airflow.databases-airflow.svc.cluster.local
AIRFLOW_DB_PORT=5432
AIRFLOW_DB_NAME=airflow
AIRFLOW_DB_USER=airflow
AIRFLOW_DB_PASSWORD=airflow123
AIRFLOW_REDIS_HOST=redis-airflow-master.databases-airflow.svc.cluster.local
AIRFLOW_REDIS_PORT=6379
AIRFLOW_REDIS_PASSWORD=redis123
AIRFLOW_WEBSERVER_SECRET_KEY=60040b565551b76020baf8d0e0e8de4e236d87c854659bbc0b18cd7042acf135
TLS_SECRET_NAME=airflow-tls
```

---

## Step 3: Deploy Airflow with OAuth Support

### 3.1 Run Preparation Script

Execute the preparation script to set up the environment:
```bash
./scripts/10-prep.sh
```

This script will:
- Create the `airflow` namespace
- Set up Harbor image pull secrets
- Process environment variables from `.env.local`

### 3.2 Deploy Airflow

Execute the installation script:
```bash
./scripts/20-install.sh
```

This script will:
- Create necessary Kubernetes secrets
- Deploy Airflow using Helm with the custom OAuth-enabled image
- Configure ingress with TLS
- Set up all OAuth environment variables

### 3.3 Create OAuth Configuration ConfigMap

Create the webserver configuration ConfigMap:
```bash
kubectl apply -f img-prep/webserver-config.yaml
```

The `webserver-config.yaml` should contain:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: airflow-webserver-config
  namespace: airflow
data:
  webserver_config.py: |
    # [Same OAuth configuration as in img-prep/webserver_config.py]
```

---

## Step 4: Verify OAuth Setup

### 4.1 Check Deployment Status

Wait for all pods to be ready:
```bash
kubectl get pods -n airflow
```

Expected output:
```
NAME                                     READY   STATUS    RESTARTS   AGE
airflow-api-server-xxx-xxx               1/1     Running   0          2m
airflow-scheduler-xxx-xxx                2/2     Running   0          2m
airflow-worker-0                         2/2     Running   0          2m
airflow-triggerer-0                      2/2     Running   0          2m
```

### 4.2 Test OAuth Login

1. Open your browser and navigate to: `https://airflow.local`
2. You should see the OAuth login page with "Sign In with keycloak" button
3. Click the OAuth login button
4. You should be redirected to Keycloak login page
5. Login with your test user credentials (e.g., `airflow` / `password`)
6. After successful authentication, you should be redirected back to Airflow dashboard

### 4.3 Verify Logs

Check for any OAuth-related errors:
```bash
kubectl logs -n airflow deployment/airflow-api-server --tail=20
```

You should see clean logs without OAuth errors like:
- No "Missing jwks_uri in metadata" errors
- No "404 Client Error" for userinfo URLs
- No "JMESPathTypeError" errors
- Successful OAuth redirects (302 Found responses)

---

## Step 5: Troubleshooting

### Common Issues and Solutions

**Issue**: "Missing jwks_uri in metadata" error
**Solution**: Ensure you're using explicit endpoint URLs instead of auto-discovery

**Issue**: "404 Client Error" for userinfo URL
**Solution**: Check that `api_base_url` is set correctly to avoid path duplication

**Issue**: "JMESPathTypeError" during role assignment
**Solution**: Ensure `AUTH_USER_REGISTRATION_ROLE` is set and JMESPath expressions handle null values

**Issue**: OAuth login redirects but shows error page
**Solution**: Check webserver logs for detailed error messages and verify all secrets are properly configured

### Debug Commands

```bash
# Check OAuth configuration
kubectl get configmap airflow-webserver-config -n airflow -o yaml

# Check secrets
kubectl get secrets -n airflow

# Check pod logs
kubectl logs -n airflow deployment/airflow-api-server --tail=50

# Test internal connectivity
kubectl exec -n airflow deployment/airflow-api-server -- curl -s "http://keycloak.keycloak.svc.cluster.local:8080/realms/mlops/protocol/openid-connect/certs"
```

---

## Step 6: Production Considerations

### Security Hardening

1. **Role Assignment**: Customize `AUTH_USER_REGISTRATION_ROLE` based on your needs:
   - Set to "User" for restricted access by default
   - Implement proper JMESPath expressions for group-based roles

2. **Client Secret Management**:
   - Use Kubernetes secrets for sensitive values
   - Rotate client secrets regularly

3. **TLS Configuration**:
   - Ensure all external communications use HTTPS
   - Verify certificate validity

### Offline Deployment

For completely offline environments:

1. **Pre-pull Images**: Ensure the custom OAuth image is available in your private registry
2. **DNS Configuration**: Configure internal DNS to resolve `keycloak.local` and `airflow.local`
3. **Certificate Management**: Use internal CA or self-signed certificates as appropriate

---

## Summary

After following this guide, you will have:

- ✅ Custom Airflow image with OAuth dependencies built and pushed to Harbor
- ✅ Complete OAuth configuration for Keycloak integration
- ✅ Production-ready Kubernetes deployment
- ✅ Working end-to-end OAuth authentication flow
- ✅ No manual patches or interventions required

The system is designed for offline production deployment with minimal configuration changes needed between environments.
