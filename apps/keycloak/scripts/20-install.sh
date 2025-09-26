#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"
CHARTS_DIR="${APP_DIR}/charts"
VALUES_DIR="${APP_DIR}/values"

function load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

function ensure_namespace() {
  kubectl create namespace "$KEYCLOAK_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

function create_image_pull_secret() {
  echo "🔐 Creating Harbor imagePullSecret..."
  kubectl -n "$KEYCLOAK_NAMESPACE" delete secret harbor-creds --ignore-not-found
  kubectl -n "$KEYCLOAK_NAMESPACE" create secret docker-registry harbor-creds \
    --docker-server="$HARBOR_URL" \
    --docker-username="$HARBOR_USER" \
    --docker-password="$HARBOR_ADMIN_PASSWORD"
}

function check_tls_secret() {
  if ! kubectl -n "$KEYCLOAK_NAMESPACE" get secret "$TLS_SECRET_NAME" &>/dev/null; then
    echo "⚠️ TLS secret $TLS_SECRET_NAME not found in namespace $KEYCLOAK_NAMESPACE"
    echo "👉 Create it with: kubectl create secret tls $TLS_SECRET_NAME --cert=cert.pem --key=key.pem -n $KEYCLOAK_NAMESPACE"
  fi
}

function install_chart() {
  local chart_tgz
  chart_tgz=$(ls "$CHARTS_DIR"/keycloak-*.tgz | head -n1)
  echo "🚀 Installing Keycloak v${KEYCLOAK_TAG}..."
  helm upgrade --install "$KEYCLOAK_HELM_RELEASE" "$chart_tgz" \
    --namespace "$KEYCLOAK_NAMESPACE" \
    -f "$VALUES_DIR/keycloak-values.rendered.yaml" \
    --set-string imagePullSecrets[0].name=harbor-creds
}

# Main
load_env
ensure_namespace
create_image_pull_secret
check_tls_secret
install_chart
echo "✅ Keycloak installed in namespace $KEYCLOAK_NAMESPACE"
