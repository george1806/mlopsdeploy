#!/bin/bash
set -euo pipefail

# Initialize FAB authentication tables and create admin user
# This script ensures Airflow 3.0 authentication is properly set up

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"

load_env() {
  [[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
  set -a; source "$ENV_FILE"; set +a
}

init_fab_auth() {
  echo "🔧 Initializing FAB authentication tables..."

  # Reset FAB database to ensure all auth tables exist
  kubectl exec -n "$AIRFLOW_NAMESPACE" deployment/airflow-api-server -- \
    airflow fab-db reset --yes

  # Create admin user
  echo "👤 Creating admin user..."
  kubectl exec -n "$AIRFLOW_NAMESPACE" deployment/airflow-api-server -- \
    airflow users create \
    --username admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com \
    --password admin
}

# Main execution
load_env
init_fab_auth
echo "✅ FAB authentication initialized successfully"