#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"
PATCHES_DIR="${APP_DIR}/patches"

function load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

function create_tls_secret_patch() {
  echo "🔐 Creating TLS secret patch for ${TLS_SECRET_NAME}..."

  # Check if certificate files exist
  if [[ ! -f "${APP_DIR}/${TLS_CERT_FILE}" ]] || [[ ! -f "${APP_DIR}/${TLS_KEY_FILE}" ]]; then
    echo "❌ Certificate files not found:"
    echo "   Expected cert: ${APP_DIR}/${TLS_CERT_FILE}"
    echo "   Expected key:  ${APP_DIR}/${TLS_KEY_FILE}"
    exit 1
  fi

  # Create patch directory if it doesn't exist
  mkdir -p "$PATCHES_DIR"

  # Generate the TLS secret patch using environment variables
  kubectl create secret tls "$TLS_SECRET_NAME" \
    --cert="${APP_DIR}/${TLS_CERT_FILE}" \
    --key="${APP_DIR}/${TLS_KEY_FILE}" \
    --namespace="$KEYCLOAK_NAMESPACE" \
    --dry-run=client -o yaml > "${PATCHES_DIR}/${TLS_SECRET_NAME}-secret.yaml"

  echo "✅ TLS secret patch created: ${PATCHES_DIR}/${TLS_SECRET_NAME}-secret.yaml"
}

function apply_tls_secret() {
  echo "🚀 Applying TLS secret..."
  kubectl apply -f "${PATCHES_DIR}/${TLS_SECRET_NAME}-secret.yaml"
  echo "✅ TLS secret applied successfully"
}

# Main
load_env
create_tls_secret_patch
apply_tls_secret