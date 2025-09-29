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
  echo "📦 Checking for local Airflow Helm chart v${AIRFLOW_CHART_VERSION}..."

  # Check if chart already exists locally
  if ls "$CHARTS_DIR"/airflow-*.tgz &>/dev/null; then
    echo "✅ Local chart found, skipping download"
    return 0
  fi

  # For offline environments, the chart should be pre-downloaded
  if [[ "${OFFLINE_MODE:-false}" == "true" ]]; then
    echo "❌ Offline mode: Chart not found locally. Please download airflow-${AIRFLOW_CHART_VERSION}.tgz to $CHARTS_DIR"
    echo "💡 Download command: helm pull apache-airflow/airflow --version ${AIRFLOW_CHART_VERSION} --destination $CHARTS_DIR"
    exit 1
  fi

  # Online mode: pull from repository
  echo "🌐 Online mode: pulling from repository..."
  helm repo add apache-airflow https://airflow.apache.org
  helm repo update
  helm pull apache-airflow/airflow \
    --version "${AIRFLOW_CHART_VERSION}" \
    --destination "$CHARTS_DIR"
}

render_values() {
  echo "📝 Rendering values file..."
  envsubst < "$VALUES_DIR/airflow-values.yaml" > "$VALUES_DIR/airflow-values.rendered.yaml"
}

load_env
prepare_dirs
pull_chart
render_values
echo "✅ Airflow prep complete"
