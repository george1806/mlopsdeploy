#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"
CHARTS_DIR="${APP_DIR}/charts"
VALUES_DIR="${APP_DIR}/values"

load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

prepare_dirs() {
  mkdir -p "$CHARTS_DIR" "$VALUES_DIR"
}

pull_chart() {
  echo "📦 Pulling Redis Helm chart v${REDIS_CHART_VERSION}..."
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo update
  helm pull bitnami/redis \
    --version "${REDIS_CHART_VERSION}" \
    --destination "$CHARTS_DIR"
}

render_values() {
  echo "📝 Rendering Redis values file..."
  envsubst < "$VALUES_DIR/redis-values.yaml" > "$VALUES_DIR/redis-values.rendered.yaml"
}

load_env
prepare_dirs
pull_chart
render_values
echo "✅ Redis prep complete"
