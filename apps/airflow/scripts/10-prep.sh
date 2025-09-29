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

  # Chart doesn't exist - need to download
  echo "📥 Chart not found locally, downloading..."

  # Check if we should attempt download (both online and offline modes)
  if command -v helm >/dev/null 2>&1; then
    if [[ "${OFFLINE_MODE:-false}" == "true" ]]; then
      echo "🔄 Offline mode: Attempting to download and save chart for future offline use..."
    else
      echo "🌐 Online mode: Downloading chart from repository..."
    fi

    # Add repo and update (works for both modes)
    helm repo add apache-airflow https://airflow.apache.org >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true

    # Try to download the chart
    if helm pull apache-airflow/airflow --version "${AIRFLOW_CHART_VERSION}" --destination "$CHARTS_DIR" 2>/dev/null; then
      if [[ "${OFFLINE_MODE:-false}" == "true" ]]; then
        echo "✅ Chart downloaded and saved to $CHARTS_DIR for future offline use"
      else
        echo "✅ Chart downloaded successfully"
      fi
      return 0
    else
      echo "❌ Failed to download chart from repository"
      if [[ "${OFFLINE_MODE:-false}" == "true" ]]; then
        echo "💡 For offline deployment, manually download with:"
      else
        echo "💡 Please check your internet connection and try:"
      fi
      echo "    helm pull apache-airflow/airflow --version ${AIRFLOW_CHART_VERSION} --destination $CHARTS_DIR"
      exit 1
    fi
  else
    echo "❌ Helm not found. Please install Helm or manually download chart:"
    echo "💡 helm pull apache-airflow/airflow --version ${AIRFLOW_CHART_VERSION} --destination $CHARTS_DIR"
    exit 1
  fi
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
