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
  kubectl exec -n "$AIRFLOW_NAMESPACE" deployment/airflow-cv-api-server -- \
    airflow fab-db reset --yes

  # Create admin user
  echo "👤 Creating admin user..."
  kubectl exec -n "$AIRFLOW_NAMESPACE" deployment/airflow-cv-api-server -- \
    airflow users create \
    --username "$AIRFLOW_ADMIN_USERNAME" \
    --firstname "$AIRFLOW_ADMIN_FIRSTNAME" \
    --lastname "$AIRFLOW_ADMIN_LASTNAME" \
    --role Admin \
    --email "$AIRFLOW_ADMIN_EMAIL" \
    --password "$AIRFLOW_ADMIN_PASSWORD"
}

# Main execution
load_env
init_fab_auth
echo "✅ FAB authentication initialized successfully"