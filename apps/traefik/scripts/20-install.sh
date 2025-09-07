#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"
VALUES_TMPL="${APP_DIR}/values/traefik-values.yaml"
VALUES_OUT="${APP_DIR}/values/traefik-values.rendered.yaml"
CHARTS_DIR="${APP_DIR}/charts"

# --- Functions ---

load_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ Missing $ENV_FILE"
    exit 1
  fi
  set -a; source "$ENV_FILE"; set +a
}

find_chart() {
  shopt -s nullglob
  CHART_TGZ=("${CHARTS_DIR}"/traefik-*.tgz)
  shopt -u nullglob
  if (( ${#CHART_TGZ[@]} == 0 )); then
    echo "❌ Traefik chart not found in $CHARTS_DIR"
    exit 1
  fi
  echo "${CHART_TGZ[0]}"
}

render_values() {
  echo "🔹 Rendering values file..."
  sed \
    -e "s|__HARBOR_URL__|${HARBOR_URL}|g" \
    -e "s|__HARBOR_PROJECT__|${HARBOR_PROJECT}|g" \
    -e "s|__TRAEFIK_TAG__|${TRAEFIK_TAG}|g" \
    -e "s|__TRAEFIK_SERVICE_TYPE__|${TRAEFIK_SERVICE_TYPE}|g" \
    "$VALUES_TMPL" > "$VALUES_OUT"
}

ensure_namespace() {
  echo "🔹 Ensuring namespace: ${TRAEFIK_NAMESPACE}"
  kubectl create namespace "${TRAEFIK_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
}

create_pull_secret() {
  echo "🔹 Creating/Updating imagePullSecret for Harbor"
  kubectl delete secret harbor-creds -n "${TRAEFIK_NAMESPACE}" --ignore-not-found
  kubectl create secret docker-registry harbor-creds \
    --docker-server="${HARBOR_URL}" \
    --docker-username="${HARBOR_USER}" \
    --docker-password="${HARBOR_ADMIN_PASSWORD}" \
    -n "${TRAEFIK_NAMESPACE}"
}

install_chart() {
  local chart_file="$1"
  echo "🚀 Installing Traefik"
  echo "   Chart : $(basename "$chart_file")"
  echo "   Image : ${HARBOR_URL}/${HARBOR_PROJECT}/traefik:${TRAEFIK_TAG}"

  helm upgrade --install "${TRAEFIK_RELEASE_NAME}" "$chart_file" \
    --namespace "$TRAEFIK_NAMESPACE" \
    -f "$VALUES_OUT" \
    --set imagePullSecrets[0].name=harbor-creds
}

main() {
  load_env
  local chart_file
  chart_file=$(find_chart)
  render_values
  ensure_namespace
  create_pull_secret
  install_chart "$chart_file"

  echo "✅ Traefik installed."
  echo "🌐 Dashboard available at: http://traefik.local/dashboard/"
  echo "   (make sure /etc/hosts has: <node-ip> traefik.local)"
}

# --- Run ---
main
