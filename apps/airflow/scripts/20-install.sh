#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"
CHARTS_DIR="${APP_DIR}/charts"
VALUES_DIR="${APP_DIR}/values"
PATCHES_DIR="${APP_DIR}/patches"

load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

ensure_namespace() {
  kubectl create namespace "$AIRFLOW_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
}

create_image_pull_secret() {
  echo "🔐 Creating Harbor imagePullSecret..."
  kubectl -n "$AIRFLOW_NAMESPACE" delete secret harbor-creds --ignore-not-found
  kubectl -n "$AIRFLOW_NAMESPACE" create secret docker-registry harbor-creds \
    --docker-server="$HARBOR_URL" \
    --docker-username="$HARBOR_USER" \
    --docker-password="$HARBOR_ADMIN_PASSWORD"
}

check_tls_secret() {
  if ! kubectl -n "$AIRFLOW_NAMESPACE" get secret "$TLS_SECRET_NAME" &>/dev/null; then
    echo "⚠️ TLS secret $TLS_SECRET_NAME not found in namespace $AIRFLOW_NAMESPACE"
    echo "👉 Run: ./apps/airflow/patches/create-tls-secret.sh"
    return 1
  fi
}

ensure_webserver_secret() {
  # Remove any existing secret to let Helm manage it
  kubectl -n "$AIRFLOW_NAMESPACE" delete secret airflow-webserver-secret-key --ignore-not-found
  echo "✅ Webserver secret will be managed by Helm"
}

deploy_webserver_config() {
  echo "🔧 Deploying webserver configuration..."
  kubectl -n "$AIRFLOW_NAMESPACE" apply -f "$APP_DIR/img-prep/webserver-config.yaml"
  echo "✅ Webserver config deployed"
}

check_chart_exists() {
  if ! ls "$CHARTS_DIR"/airflow-*.tgz &>/dev/null; then
    echo "❌ No Airflow chart found in $CHARTS_DIR"
    echo "👉 Run: ./apps/airflow/scripts/10-prep.sh first"
    return 1
  fi
}

check_values_rendered() {
  if [[ ! -f "$VALUES_DIR/airflow-values.rendered.yaml" ]]; then
    echo "❌ Rendered values file not found"
    echo "👉 Run: ./apps/airflow/scripts/10-prep.sh first"
    return 1
  fi
}

install_chart() {
  chart_tgz=$(ls "$CHARTS_DIR"/airflow-*.tgz | head -n1)
  echo "🚀 Installing Airflow using local chart: $(basename "$chart_tgz")"

  helm upgrade --install "$AIRFLOW_RELEASE" "$chart_tgz" \
    --namespace "$AIRFLOW_NAMESPACE" \
    -f "$VALUES_DIR/airflow-values.rendered.yaml" \
    --wait --timeout=10m
}

run_migrations() {
  echo "⚙️ Running Airflow DB migrations..."
  bash "$PATCHES_DIR/run-migrate.sh"
}

init_fab_auth() {
  echo "🔧 Initializing FAB authentication..."
  bash "$PATCHES_DIR/init-fab-auth.sh"
}

wait_for_deployment() {
  echo "⏳ Waiting for Airflow deployment to be ready..."
  kubectl wait --for=condition=available --timeout=600s deployment/airflow-cv-scheduler -n "$AIRFLOW_NAMESPACE" || true
  kubectl wait --for=condition=available --timeout=600s deployment/airflow-cv-api-server -n "$AIRFLOW_NAMESPACE" || true
  kubectl wait --for=condition=available --timeout=600s deployment/airflow-cv-dag-processor -n "$AIRFLOW_NAMESPACE" || true
}

# === Main execution ===
load_env
ensure_namespace
create_image_pull_secret
check_tls_secret
ensure_webserver_secret
deploy_webserver_config
check_chart_exists
check_values_rendered
install_chart
run_migrations
wait_for_deployment
init_fab_auth
echo "✅ Airflow installed, migrations applied, and authentication initialized in namespace $AIRFLOW_NAMESPACE"
