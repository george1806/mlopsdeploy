#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${APP_DIR}/.env.local"

[[ -f "$ENV_FILE" ]] || { echo "❌ Missing .env.local"; exit 1; }
set -a; source "$ENV_FILE"; set +a

JOB_NAME="airflow-migrate-database"
NAMESPACE="$AIRFLOW_NAMESPACE"

echo "⚙️ Checking Airflow DB migrations in namespace $NAMESPACE..."

# Step 1: Get the current alembic head in DB
DB_CONN="postgresql://${AIRFLOW_DB_USER}:${AIRFLOW_DB_PASSWORD}@${AIRFLOW_DB_HOST}:${AIRFLOW_DB_PORT}/${AIRFLOW_DB_NAME}?sslmode=disable"

LATEST_HEAD=$(kubectl -n "$NAMESPACE" run tmp-airflow-db-check \
  --rm -i --restart=Never \
  --image "${HARBOR_URL}/${HARBOR_PROJECT}/airflow:${AIRFLOW_TAG}" \
  --env "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=$DB_CONN" \
  --command -- airflow db heads 2>/dev/null | tail -1 || echo "")

DB_HEAD=$(kubectl -n "$NAMESPACE" run tmp-airflow-db-version \
  --rm -i --restart=Never \
  --image "${HARBOR_URL}/${HARBOR_PROJECT}/airflow:${AIRFLOW_TAG}" \
  --env "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=$DB_CONN" \
  --command -- airflow db current 2>/dev/null | tail -1 || echo "")

if [[ "$DB_HEAD" == "$LATEST_HEAD" && -n "$DB_HEAD" ]]; then
  echo "✅ Database already at latest migration head ($DB_HEAD). Skipping migration."
  exit 0
fi

echo "🔄 Database not up to date. Running migration job..."

# Step 2: Delete old job if exists
kubectl -n "$NAMESPACE" delete job "$JOB_NAME" --ignore-not-found

# Step 3: Apply new migration job
cat <<EOF | kubectl -n "$NAMESPACE" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrate
          image: ${HARBOR_URL}/${HARBOR_PROJECT}/airflow:${AIRFLOW_TAG}
          env:
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: "$DB_CONN"
          command: ["airflow"]
          args: ["db", "migrate"]
EOF

# Step 4: Wait for job completion
kubectl -n "$NAMESPACE" wait --for=condition=complete --timeout=300s job/$JOB_NAME || {
  echo "❌ Migration job failed. Check logs with: kubectl logs job/$JOB_NAME -n $NAMESPACE"
  exit 1
}

echo "✅ Migration completed successfully!"
