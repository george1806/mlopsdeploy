#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"
CHARTS_DIR="${APP_DIR}/charts"

# --- Functions ---

load_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ Missing $ENV_FILE"
    exit 1
  fi
  set -a; source "$ENV_FILE"; set +a
}

ensure_repo() {
  if ! helm repo list | grep -qE '^traefik[[:space:]]'; then
    echo "🔹 Adding Traefik Helm repo"
    helm repo add traefik https://traefik.github.io/charts
  else
    echo "ℹ️ Traefik Helm repo already exists. Updating..."
    helm repo update traefik
  fi
}

fetch_chart() {
  mkdir -p "$CHARTS_DIR"
  echo "🔹 Fetching Traefik chart v${TRAEFIK_CHART_VERSION}"
  helm pull traefik/traefik \
    --version "${TRAEFIK_CHART_VERSION}" \
    --destination "$CHARTS_DIR"

  echo "✅ Chart saved to $CHARTS_DIR"
}

main() {
  load_env
  ensure_repo
  fetch_chart
}

# --- Run ---
main
