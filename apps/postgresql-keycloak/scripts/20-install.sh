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
  kubectl create namespace "$POSTGRES_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

function create_image_pull_secret() {
  echo "🔐 Creating Harbor imagePullSecret..."
  kubectl -n "$POSTGRES_NAMESPACE" delete secret harbor-creds --ignore-not-found
  kubectl -n "$POSTGRES_NAMESPACE" create secret docker-registry harbor-creds \
    --docker-server="$HARBOR_URL" \
    --docker-username="$HARBOR_USER" \
    --docker-password="$HARBOR_ADMIN_PASSWORD"
}

function install_chart() {
  local chart_tgz
  chart_tgz=$(ls "$CHARTS_DIR"/postgresql-*.tgz | head -n1)
  echo "🚀 Installing PostgreSQL (Keycloak) v${POSTGRES_IMAGE_TAG}..."
  helm upgrade --install "$POSTGRES_HELM_RELEASE" "$chart_tgz" \
    --namespace "$POSTGRES_NAMESPACE" \
    -f "$VALUES_DIR/postgresql-values.rendered.yaml" \
    --set-string imagePullSecrets[0].name=harbor-creds
}

# Main
load_env
ensure_namespace
create_image_pull_secret
install_chart
echo "✅ PostgreSQL for Keycloak installed in namespace $POSTGRES_NAMESPACE"
