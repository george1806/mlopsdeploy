#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="${APP_DIR}/certs"
ENV_FILE="${APP_DIR}/.env.local"

load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

ensure_certs() {
  mkdir -p "$CERTS_DIR"

  local cert_path="$APP_DIR/$TLS_CERT_FILE"
  local key_path="$APP_DIR/$TLS_KEY_FILE"

  if [[ -f "$cert_path" && -f "$key_path" ]]; then
    echo "📄 Found existing certs: $cert_path and $key_path"
  else
    echo "⚠️ No certs found, generating self-signed certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -out "$cert_path" \
      -keyout "$key_path" \
      -subj "/CN=${AIRFLOW_HOST}/O=mlops"
    echo "✅ Self-signed cert generated at $cert_path"
  fi
}

create_secret() {
  echo "🔐 Creating TLS secret: $TLS_SECRET_NAME in namespace $AIRFLOW_NAMESPACE"
  kubectl -n "$AIRFLOW_NAMESPACE" delete secret "$TLS_SECRET_NAME" --ignore-not-found
  kubectl -n "$AIRFLOW_NAMESPACE" create secret tls "$TLS_SECRET_NAME" \
    --cert="$APP_DIR/$TLS_CERT_FILE" \
    --key="$APP_DIR/$TLS_KEY_FILE"
}

load_env
ensure_certs
create_secret
echo "✅ TLS secret $TLS_SECRET_NAME created in namespace $AIRFLOW_NAMESPACE"
