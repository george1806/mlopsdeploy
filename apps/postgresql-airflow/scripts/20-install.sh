#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"
CHARTS_DIR="${APP_DIR}/charts"
VALUES_DIR="${APP_DIR}/values"

load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

ensure_namespace() {
  kubectl create namespace "$POSTGRES_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

create_image_pull_secret() {
  echo "🔐 Creating Harbor imagePullSecret..."
  kubectl -n "$POSTGRES_NAMESPACE" delete secret harbor-creds --ignore-not-found
  kubectl -n "$POSTGRES_NAMESPACE" create secret docker-registry harbor-creds \
    --docker-server="$HARBOR_URL" \
    --docker-username="$HARBOR_USER" \
    --docker-password="$HARBOR_ADMIN_PASSWORD"
}

install_chart() {
  chart_tgz=$(ls "$CHARTS_DIR"/postgresql-*.tgz | head -n1)
  echo "🚀 Installing PostgreSQL..."
  helm upgrade --install "$POSTGRES_RELEASE" "$chart_tgz" \
    --namespace "$POSTGRES_NAMESPACE" \
    -f "$VALUES_DIR/postgresql-values.rendered.yaml"
}

load_env
ensure_namespace
create_image_pull_secret
install_chart
echo "✅ PostgreSQL installed in namespace $POSTGRES_NAMESPACE"
