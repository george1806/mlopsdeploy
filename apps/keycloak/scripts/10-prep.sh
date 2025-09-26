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

function prepare_dirs() {
  mkdir -p "$CHARTS_DIR" "$VALUES_DIR"
}

function pull_chart() {
  echo "📦 Pulling Keycloak Helm chart v${KEYCLOAK_CHART_VERSION}..."
  helm pull bitnami/keycloak \
    --version "${KEYCLOAK_CHART_VERSION}" \
    --untar=false \
    --destination "$CHARTS_DIR"
}

function render_values() {
  echo "📝 Rendering values file..."
  envsubst < "$VALUES_DIR/keycloak-values.yaml" > "$VALUES_DIR/keycloak-values.rendered.yaml"
}

# Main
load_env
prepare_dirs
pull_chart
render_values
echo "✅ Keycloak prep complete: chart + rendered values ready"
