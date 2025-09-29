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

## 7. Create Groups for Role-Based Access Control

For production environments, set up groups to control user access levels. This section shows exactly what to create in Keycloak.

### 7.1 Create Groups

1. **Login to Keycloak Admin Console**: `https://keycloak.local`
2. **Switch to `mlops` realm** (not Master realm)
3. **Go to Groups** (left sidebar)
4. **Click "Create Group"** and create these 4 groups:

#### Groups to Create:

**Group 1: airflow_admin**
- **Group Name**: `airflow_admin`
- **Description**: Full Airflow administrative access
- **Click "Save"**

**Group 2: airflow_op**
- **Group Name**: `airflow_op`
- **Description**: Airflow operators - can manage DAGs and workflows
- **Click "Save"**

**Group 3: airflow_user**
- **Group Name**: `airflow_user`
- **Description**: Standard Airflow users - read-only access
- **Click "Save"**

**Group 4: airflow_viewer**
- **Group Name**: `airflow_viewer`
- **Description**: View-only access to Airflow
- **Click "Save"**

### 7.2 Configure Group Claims (Critical Step!)

The groups must be included in OAuth tokens for role mapping to work:

#### Option A: Use Built-in Groups Scope (Recommended)

1. **Go to Client Scopes** → **groups**
2. **Go to Mappers tab**
3. **Look for existing "groups" mapper** or **Create Mapper** → **By Configuration** → **Group Membership**
4. **Configure the mapper**:
   - **Name**: `groups`
   - **Mapper Type**: `Group Membership`
   - **Token Claim Name**: `groups`
   - **Full group path**: **OFF** ⚠️ (Important - use simple group names)
   - **Add to ID token**: **ON**
   - **Add to access token**: **ON**
   - **Add to userinfo**: **ON**
5. **Click "Save"**

#### Option B: Create Custom Mapper (Alternative)

If you prefer to configure directly on the client:

1. **Go to Clients** → **airflow-client** → **Mappers**
2. **Create Mapper** → **By Configuration** → **Group Membership**
3. **Configure the same settings as Option A above**

### 7.3 Add Groups Scope to Client

1. **Go to Clients** → **airflow-client** → **Client Scopes**
2. **In "Optional Client Scopes"**, find `groups` and click **Add Selected →**
3. **Move `groups` to "Assigned Default Client Scopes"** (so it's always included in tokens)

### 7.4 Create Test Users and Assign to Groups

#### Create Test Users (Optional but Recommended)

Create users to test different role levels:

1. **Go to Users** → **Add User**
2. **Create these test users**:
   ```
   Username: admin-test
   Email: admin-test@example.com
   Email Verified: ON

   Username: operator-test
   Email: operator-test@example.com
   Email Verified: ON

   Username: user-test
   Email: user-test@example.com
   Email Verified: ON

   Username: viewer-test
   Email: viewer-test@example.com
   Email Verified: ON

   Username: no-group-test
   Email: no-group-test@example.com
   Email Verified: ON
   ```
3. **Set passwords** for each user (go to **Credentials** tab → **Set Password**)

#### Assign Users to Groups

1. **Go to Groups** → Select a group (e.g., `airflow_admin`)
2. **Members tab** → **Add member**
3. **Select users** and click **Add**

**Suggested Test Assignment**:
```
admin-test → airflow_admin group
operator-test → airflow_op group
user-test → airflow_user group
viewer-test → airflow_viewer group
no-group-test → (no groups - should get Public role)
```

### 7.5 Verify Group Configuration

#### Test Token Claims:

1. **Test the OAuth flow** with one of your test users
2. **Capture the JWT token** (you can see it in browser developer tools)
3. **Decode the JWT** at https://jwt.io
4. **Check the payload** should contain:
   ```json
   {
     "groups": ["airflow_admin"],
     "email": "admin-test@example.com",
     "preferred_username": "admin-test",
     "given_name": "Admin",
     "family_name": "Test"
   }
   ```

#### Role Mapping Reference:

Once configured, users will automatically get these Airflow roles:

| Keycloak Group | Airflow Role | Access Level |
|----------------|--------------|--------------|
| `airflow_admin` | Admin | Full administrative access |
| `airflow_op` | Op | Manage DAGs, workflows |
| `airflow_user` | User | Read-only access |
| `airflow_viewer` | Viewer | View-only |
| (no groups) | Public | Minimal access |

### 7.6 Configuration Checklist

Before proceeding to Airflow deployment, verify:

- [ ] **Created 4 groups** in Keycloak (`airflow_admin`, `airflow_op`, `airflow_user`, `airflow_viewer`)
- [ ] **Configured groups mapper** with correct settings (Full group path = OFF)
- [ ] **Added groups scope** to airflow-client (in Default Client Scopes)
- [ ] **Created test users** and assigned them to different groups
- [ ] **Verified groups appear** in JWT tokens when testing OAuth flow
- [ ] **Groups scope included** in OAuth request (`openid email profile groups`)

---

# Airflow OAuth Setup Guide

This section covers building and deploying Airflow with Keycloak OAuth authentication for offline production environments.

---

## Complete Deployment Flow

The deployment process is **fully automated** and follows this sequence:

### 📋 **Phase 1: Preparation**
1. **Environment Setup**: Configure `.env.local` with all required variables
2. **Custom Image Build**: Build OAuth-enabled Airflow image and push to Harbor
3. **Keycloak Client Setup**: Automatically create OAuth client in Keycloak

### 🚀 **Phase 2: Deployment**
4. **Preparation Script**: `./scripts/10-prep.sh` - Sets up charts and renders configuration
5. **Installation Script**: `./scripts/20-install.sh` - Deploys complete Airflow stack

### ✅ **Phase 3: Verification**
6. **OAuth Testing**: Test login, logout, and role-based access control

---

## Script Execution Order

Run the following commands in sequence for complete deployment:

```bash
# 1. Configure environment (copy and edit .env.production.template)
cp .env.production.template .env.local
# Edit .env.local with your values

# 2. Build custom OAuth-enabled Airflow image
./img-prep/build-custom-image.sh

# 3. Setup Keycloak OAuth client (automated)
./patches/setup-keycloak-client-simple.sh

# 4. Prepare Airflow deployment (charts, configs)
./scripts/10-prep.sh

# 5. Deploy complete Airflow stack (fully automated)
./scripts/20-install.sh

# 6. Verify deployment
kubectl get pods -n airflow
```

**🎯 That's it! No manual steps required.**

---

## Detailed Script Functions

### 🔧 **`./img-prep/build-custom-image.sh`**
- Builds custom Airflow Docker image with OAuth dependencies
- Installs: `requests-oauthlib`, `flask-oauthlib`, `authlib`
- Copies `webserver_config.py` with production role mapping
- Pushes image to Harbor as `airflow:3.0.2-oauth`
- **Requires**: Docker, Harbor access, `.env.local`

### 🔑 **`./patches/setup-keycloak-client-simple.sh`**
- Automatically creates `airflow-client` in Keycloak
- Configures redirect URIs based on `AIRFLOW_HOST` env var
- Sets up confidential client with authorization code flow
- **No hardcoded values** - all environment-driven
- **Requires**: Keycloak admin access, `.env.local`

### 📦 **`./scripts/10-prep.sh`**
- **Online Mode**: Downloads Airflow Helm chart from repository
- **Offline Mode**: Checks for pre-downloaded chart in `charts/` directory
- Renders `airflow-values.yaml` with environment variables
- Creates necessary directories
- **Supports**: `OFFLINE_MODE=true` for air-gapped deployments

### 🚀 **`./scripts/20-install.sh`**
**Complete automated deployment:**
- Creates `airflow` namespace
- Sets up Harbor `imagePullSecret`
- Checks TLS certificate availability
- **Deploys OAuth ConfigMap** (webserver_config.py)
- Installs Airflow via Helm with rendered values
- **Runs database migrations** automatically
- **Initializes FAB authentication** tables
- **Creates admin user** from environment variables
- Waits for all deployments to be ready

---

## Offline Deployment Support

For **air-gapped production environments**:

### 📥 **Pre-requisites**
1. **Set offline mode** in `.env.local`:
   ```bash
   OFFLINE_MODE=true
   ```

2. **Pre-download Helm chart** (on internet-connected machine):
   ```bash
   mkdir -p charts/
   helm pull apache-airflow/airflow --version 1.17.0 --destination charts/
   # Copy charts/ directory to offline environment
   ```

3. **Pre-built images** in Harbor registry:
   - Base Airflow: `harbor.local:30002/mlops/airflow:3.0.2`
   - OAuth-enabled: `harbor.local:30002/mlops/airflow:3.0.2-oauth`

### 🔄 **Offline Deployment Flow**
The scripts **automatically detect** offline mode and skip internet dependencies:
- **10-prep.sh**: Uses local chart, skips `helm repo add/update`
- **20-install.sh**: Uses local Harbor images only
- **No internet required** after initial setup

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
                "scope": "openid email profile groups",
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
AUTH_USER_REGISTRATION_ROLE = "Public"  # Default role for users without specific groups

# Role mapping for OAuth users - Maps Keycloak groups to Airflow roles
AUTH_ROLES_MAPPING = {
    "airflow_admin": ["Admin"],           # Keycloak group -> Airflow role
    "airflow_op": ["Op"],                 # Operators - can view and manage DAGs
    "airflow_user": ["User"],             # Basic users - read-only access
    "airflow_viewer": ["Viewer"],         # View-only access
}

# Production-ready role assignment with proper error handling
# Use JMESPath to map Keycloak groups to Airflow roles
AUTH_USER_REGISTRATION_ROLE_JMESPATH = """
    (groups && length(groups) > `0`) &&
    (
        (contains(groups, 'airflow_admin') && 'Admin') ||
        (contains(groups, 'airflow_op') && 'Op') ||
        (contains(groups, 'airflow_user') && 'User') ||
        (contains(groups, 'airflow_viewer') && 'Viewer') ||
        'Public'
    ) || 'Public'
"""

# OIDC logout configuration - redirect to Keycloak logout then back to login
AUTH_LOGOUT_REDIRECT_URL = f"{KEYCLOAK_EXTERNAL_HOST}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/logout?post_logout_redirect_uri={KEYCLOAK_EXTERNAL_HOST.replace('keycloak.local', 'airflow.local')}/auth/login/"
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

### 4.2.1 Test Logout Functionality

**Automatic Logout (if working):**
1. While logged in to Airflow, click the "Logout" button/menu
2. You should be redirected to Keycloak logout page
3. After Keycloak logout completes, you should be redirected back to Airflow login page
4. When you click "Sign In with keycloak" again, you should be prompted for credentials

**Manual Logout (if automatic logout doesn't work):**
If you still get automatically logged in after logout, you can manually clear the Keycloak session:

1. After logging out from Airflow, manually navigate to:
   ```
   https://keycloak.local/realms/mlops/protocol/openid-connect/logout
   ```
2. This will clear the Keycloak SSO session
3. Navigate back to Airflow: `https://airflow.local`
4. Click "Sign In with keycloak" - you should now be prompted for credentials

**Alternative - Clear Browser Data:**
- Clear cookies for both `airflow.local` and `keycloak.local` domains
- Or use browser incognito/private mode for testing

### 4.2.2 Test Role-Based Access Control

1. **Setup Test Users with Different Roles**:
   - Create users in Keycloak and assign them to different groups
   - Example: User `admin1` in `airflow_admin` group, User `user1` in `airflow_user` group

2. **Test Admin Access**:
   - Login with user in `airflow_admin` group
   - Verify full access to all Airflow features
   - Check user profile shows "Admin" role

3. **Test User Access**:
   - Login with user in `airflow_user` group
   - Verify limited access (should be read-only)
   - Check user profile shows "User" role

4. **Test Default Access**:
   - Login with user not in any airflow groups
   - Should get "Public" role with minimal access

5. **Verify Role Assignment**:
   - In Airflow, go to **Security** → **List Users**
   - Check that users have correct roles assigned based on their Keycloak groups

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

**Issue**: After logout, clicking OAuth login button doesn't prompt for credentials (auto-login)
**Solution**: This is a common issue with Flask-AppBuilder OAuth implementations. Try these approaches:
- Ensure `AUTH_LOGOUT_REDIRECT_URL` is configured to redirect through Keycloak logout endpoint
- Manual logout: Navigate to `https://keycloak.local/realms/mlops/protocol/openid-connect/logout` after logging out
- Clear browser cookies for both domains
- Use browser incognito/private mode for testing
- Note: This may require additional custom logout handling depending on your Flask-AppBuilder version

**Issue**: Users always get "Public" role regardless of Keycloak groups
**Solution**: Check these configuration items:
- Verify `groups` scope is included in OAuth client configuration
- Ensure Keycloak client includes groups in token claims (Client Scopes → groups)
- Check that users are properly assigned to groups in Keycloak
- Verify JMESPath expression syntax in `AUTH_USER_REGISTRATION_ROLE_JMESPATH`
- Test group claims by examining JWT token content

**Issue**: JMESPathError when processing user groups
**Solution**: The JMESPath expression includes null-safety checks, but verify:
- Groups claim exists in token
- JMESPath syntax is correct
- Check Airflow logs for specific error messages

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

# Verify token claims (for debugging role assignment)
# You can decode JWT tokens at https://jwt.io to verify group claims are included
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
