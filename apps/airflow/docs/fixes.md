### Secret issue > Patch the StatefulSet

```sh
kubectl patch statefulset redis-airflow-master \
  -n databases-airflow \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/imagePullSecrets","value":[{"name":"harbor-creds"}]}]'
```

### Patch env values to a deployment

```sh
kubectl patch deployment airflow-cv-api-server -n airflow-cv \
  --type='strategic' \
  -p='{
    "spec": {
      "template": {
        "spec": {
          "containers": [
            {
              "name": "api-server",
              "env": [
                {
                  "name": "KEYCLOAK_INTERNAL_HOST",
                  "value": "http://dev-keycloak.keycloak-dev.svc.cluster.local:8080"
                }
              ]
            }
          ]
        }
      }
    }
  }'
```

### Patch keycloak values

```sh
kubectl patch deployment airflow-cv-api-server -n airflow-cv \
  --type='strategic' \
  -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "api-server",
            "env": [
              {
                "name": "KEYCLOAK_HOST",
                "value": "http://keycloak.dev.vtz.corp"
              },
              {
                "name": "AIRFLOW__WEBSERVER__OAUTH_PROVIDERS",
                "value": "[{\"name\": \"keycloak\", \"token_key\": \"access_token\", \"icon\": \"fa-key\", \"remote_app\": {\"client_id\": \"airflow-client\", \"client_secret\": \"cEqzPLsNObqKGzHsrsxF1ziYGuoJifnG\", \"api_base_url\": \"http://keycloak.dev.vtz.corp/realms/mlops/protocol/openid-connect/\", \"client_kwargs\": {\"scope\": \"openid email profile\"}, \"access_token_method\": \"POST\", \"access_token_params\": {\"grant_type\": \"authorization_code\"}, \"request_token_url\": null, \"access_token_url\": \"http://keycloak.dev.vtz.corp/realms/mlops/protocol/openid-connect/token\", \"authorize_url\": \"http://keycloak.dev.vtz.corp/realms/mlops/protocol/openid-connect/auth\"}}]"
              }
            ]
          }
        ]
      }
    }
  }
}'
```

---

### Keycloak OAuth Issuer Mismatch Fix

### Problem

After deploying Airflow with Keycloak OAuth integration in an air-gapped environment, login attempts failed with the following error in Keycloak logs:

```
type="USER_INFO_REQUEST_ERROR", realmId="709a9ef8-972e-412d-ad09-d07ba630f5de",
realmName="mlops", clientId="null", userId="null", ipAddress="192.168.2.200",
error="invalid_token", reason="Invalid token issuer. Expected
'http://keycloak.dev.vtz.corp:8080/realms/mlops'", auth_method="validate_access_token"
```

Alternatively, in Airflow logs:

```
ERROR - Error authorizing OAuth access token: invalid_claim: Invalid claim "iss"
```

### Root Cause

The issue was caused by a mismatch between:

- **Keycloak's configured issuer URL**: `http://keycloak.dev.vtz.corp:8080/realms/mlops` (with port `:8080`)
- **Actual access URL by users**: `http://keycloak.dev.vtz.corp/realms/mlops` (without port)
- **Issuer claim in JWT tokens**: Matched the frontend URL (without port)

When users accessed Keycloak through an ingress/proxy without explicitly specifying the port, Keycloak generated tokens with an issuer claim that didn't include the port. However, Keycloak's realm was configured to expect the port in the issuer validation.

### Solution

The fix involves two steps:

#### Step 1: Update Airflow Webserver Config

Modified `/apps/airflow/img-prep/webserver-config.yaml` to use a dynamic issuer that matches what Keycloak actually sends:

```python
# OAuth configuration - manual endpoints to avoid metadata discovery issues
KEYCLOAK_INTERNAL_HOST = os.environ.get('KEYCLOAK_INTERNAL_HOST', 'http://dev-keycloak.keycloak-dev.svc.cluster.local:8080')
KEYCLOAK_EXTERNAL_HOST = os.environ.get('KEYCLOAK_HOST', 'http://keycloak.dev.vtz.corp')
KEYCLOAK_REALM = os.environ.get('KEYCLOAK_REALM', 'mlops')

# Issuer must match what Keycloak sends in the iss claim (external URL as seen by users)
# Even though validation is server-side, the iss claim is based on the frontend URL
KEYCLOAK_ISSUER = os.environ.get('KEYCLOAK_ISSUER', f"{KEYCLOAK_EXTERNAL_HOST}/realms/{KEYCLOAK_REALM}")

OAUTH_PROVIDERS = [
    {
        "name": "keycloak",
        "icon": "fa-key",
        "token_key": "access_token",
        "remote_app": {
            # ... other config ...
            "issuer": KEYCLOAK_ISSUER,  # Use the dynamic issuer
            # ... other config ...
        },
    }
]
```

**Apply the updated ConfigMap and restart:**

```bash
kubectl apply -f apps/airflow/img-prep/webserver-config.yaml
kubectl rollout restart deployment/airflow-cv-api-server -n airflow-cv
```

#### Step 2: Fix Keycloak Realm Frontend URL

Configure Keycloak's realm to use the correct frontend URL without the port.

**Option A: Via Keycloak Admin UI (Recommended)**

1. Login to Keycloak admin console: `http://keycloak.dev.vtz.corp`
2. Navigate to **Realm Settings** → **General** tab
3. Locate **Frontend URL** field
4. Set it to: `http://keycloak.dev.vtz.corp` (without port `:8080`)
5. Click **Save**

**Option B: Via Environment Variables (Keycloak 22+)**

```bash
kubectl set env statefulset/dev-keycloak -n keycloak-dev \
  KC_HOSTNAME_URL=http://keycloak.dev.vtz.corp \
  KC_HOSTNAME_STRICT=false
```

### Verification

After applying both fixes, verify the configuration:

```bash
# Check the issuer URL in Airflow config
kubectl exec -n airflow-cv deployment/airflow-cv-api-server -- \
  python3 -c "import os; print('Issuer:', os.environ.get('KEYCLOAK_HOST', 'http://keycloak.dev.vtz.corp') + '/realms/' + os.environ.get('KEYCLOAK_REALM', 'mlops'))"

# Expected output:
# Issuer: http://keycloak.dev.vtz.corp/realms/mlops

# Test login and check logs
kubectl logs -n airflow-cv deployment/airflow-cv-api-server --tail=50
```

### Key Learnings

1. **Issuer consistency is critical**: The issuer URL in OAuth configs must exactly match what the identity provider sends in JWT tokens
2. **Frontend URL matters**: When Keycloak is accessed via ingress/proxy, the frontend URL configuration determines the issuer claim in tokens
3. **Port handling**: In air-gapped environments with custom networking, explicit port configuration can cause mismatches if not aligned with actual access patterns
4. **Dynamic configuration**: Using environment variables for issuer configuration allows flexibility across different deployment environments
