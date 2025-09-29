#!/bin/bash
set -euo pipefail

# Setup Keycloak client for Airflow OIDC authentication
# This script creates the airflow-client in Keycloak

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"

load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

setup_keycloak_client() {
  echo "🔧 Setting up Keycloak client for Airflow..."

  # Get Keycloak admin token
  echo "🔑 Getting Keycloak admin token..."
  TOKEN=$(curl -k -s -X POST \
    "${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | \
    jq -r '.access_token')

  if [[ -z "$TOKEN" ]]; then
    echo "❌ Failed to get Keycloak admin token"
    exit 1
  fi

  # Check if realm exists, create if not
  echo "🏠 Checking if realm '${KEYCLOAK_REALM}' exists..."
  REALM_RESPONSE=$(curl -k -s -w "%{http_code}" -o /dev/null \
    "${KEYCLOAK_HOST}/admin/realms/${KEYCLOAK_REALM}" \
    -H "Authorization: Bearer ${TOKEN}")

  if [[ "$REALM_RESPONSE" == "404" ]]; then
    echo "📋 Creating realm '${KEYCLOAK_REALM}'..."
    curl -k -s -X POST \
      "${KEYCLOAK_HOST}/admin/realms" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"realm\":\"${KEYCLOAK_REALM}\",\"enabled\":true}"
  fi

  # Check if client already exists
  echo "🔍 Checking if client '${KEYCLOAK_CLIENT_ID}' exists..."
  CLIENT_EXISTS=$(curl -k -s \
    "${KEYCLOAK_HOST}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${KEYCLOAK_CLIENT_ID}" \
    -H "Authorization: Bearer ${TOKEN}" | \
    grep -o '"id"' | wc -l)

  if [[ "$CLIENT_EXISTS" -gt 0 ]]; then
    echo "🔄 Client '${KEYCLOAK_CLIENT_ID}' exists, updating redirect URI..."
    CLIENT_ID=$(curl -k -s \
      "${KEYCLOAK_HOST}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${KEYCLOAK_CLIENT_ID}" \
      -H "Authorization: Bearer ${TOKEN}" | \
      jq -r '.[0].id')

    curl -k -s -X PUT \
      "${KEYCLOAK_HOST}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_ID}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{
        \"redirectUris\": [\"${AIRFLOW_HOST}/oauth-authorized/keycloak\", \"${AIRFLOW_HOST}/auth/oauth-authorized/keycloak\"],
        \"webOrigins\": [\"${AIRFLOW_HOST}\"]
      }"
    echo "✅ Client redirect URI updated"
    return 0
  fi

  # Create the Airflow client
  echo "👥 Creating Airflow client..."
  curl -k -s -X POST \
    "${KEYCLOAK_HOST}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"${KEYCLOAK_CLIENT_ID}\",
      \"name\": \"Airflow Client\",
      \"description\": \"Airflow OIDC Authentication Client\",
      \"enabled\": true,
      \"clientAuthenticatorType\": \"client-secret\",
      \"secret\": \"${KEYCLOAK_CLIENT_SECRET}\",
      \"redirectUris\": [\"${AIRFLOW_HOST}/oauth-authorized/keycloak\", \"${AIRFLOW_HOST}/auth/oauth-authorized/keycloak\"],
      \"webOrigins\": [\"${AIRFLOW_HOST}\"],
      \"standardFlowEnabled\": true,
      \"implicitFlowEnabled\": false,
      \"directAccessGrantsEnabled\": true,
      \"serviceAccountsEnabled\": false,
      \"publicClient\": false,
      \"protocol\": \"openid-connect\",
      \"attributes\": {
        \"saml.assertion.signature\": \"false\",
        \"saml.force.post.binding\": \"false\",
        \"saml.multivalued.roles\": \"false\",
        \"saml.encrypt\": \"false\",
        \"saml.server.signature\": \"false\",
        \"saml.server.signature.keyinfo.ext\": \"false\",
        \"exclude.session.state.from.auth.response\": \"false\",
        \"saml_force_name_id_format\": \"false\",
        \"saml.client.signature\": \"false\",
        \"tls.client.certificate.bound.access.tokens\": \"false\",
        \"saml.authnstatement\": \"false\",
        \"display.on.consent.screen\": \"false\",
        \"saml.onetimeuse.condition\": \"false\"
      }
    }"

  echo "✅ Keycloak client setup completed successfully"
}

# Main execution
load_env
setup_keycloak_client
echo "🎉 Airflow OIDC client is ready for authentication"