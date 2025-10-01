#!/bin/bash
set -euo pipefail

NS=airflow-cv
JOB_NAME="airflow-migrate-database"

echo "🔹 Patching securityContext for Airflow components in namespace: $NS"

patch_and_rollout() {
  KIND=$1
  NAME=$2
  PATCH=$3

  if kubectl get $KIND $NAME -n $NS >/dev/null 2>&1; then
    echo "➡️  Patching $KIND/$NAME"
    kubectl patch $KIND $NAME -n $NS --type='json' -p="$PATCH"
  else
    echo "⚠️  Skipping $KIND/$NAME (not found)"
  fi
}

# === PATCH EXISTING COMPONENTS ===
# (same blocks as your script … unchanged)
# --- API Server ---
patch_and_rollout deployment airflow-cv-api-server '[{"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000}},{"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]'

# --- Scheduler ---
patch_and_rollout deployment airflow-cv-scheduler '[{"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000}},{"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}},{"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]'

# --- DAG Processor ---
patch_and_rollout deployment airflow-cv-dag-processor '[{"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000}},{"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}},{"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]'

# --- Worker ---
patch_and_rollout statefulset airflow-cv-worker '[{"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000}},{"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}},{"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]'

# --- Triggerer ---
patch_and_rollout statefulset airflow-cv-triggerer '[{"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000}},{"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}},{"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{"runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]'

# --- StatsD ---
patch_and_rollout deployment airflow-cv-statsd '[{"op":"add","path":"/spec/template/spec/securityContext","value":{"seccompProfile":{"type":"RuntimeDefault"},"fsGroup":65534}},{"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"runAsUser":65534,"runAsNonRoot":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]'

echo "✅ Finished patching Airflow components"

# === CREATE/RESTART MIGRATION JOB ===
echo "🔹 Deploying DB migration job..."

kubectl -n $NS delete job $JOB_NAME --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: $NS
spec:
  ttlSecondsAfterFinished: 600
  template:
    spec:
      restartPolicy: OnFailure
      imagePullSecrets:
        - name: harbor-creds
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: migrate
        image: vtzkwl-bigdata-harbor01.vodacomtz.corp/mlops/airflow:3.0.2-oauth
        imagePullPolicy: IfNotPresent
        securityContext:
          runAsNonRoot: true
          runAsUser: 50000
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
          seccompProfile:
            type: RuntimeDefault
        env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          valueFrom:
            secretKeyRef:
              name: airflow-cv-metadata
              key: connection
        - name: AIRFLOW__CORE__FERNET_KEY
          valueFrom:
            secretKeyRef:
              name: airflow-cv-fernet-key
              key: fernet-key
        command: ["airflow"]
        args: ["db", "migrate"]
EOF

echo "⏳ Waiting for migration job to finish..."
kubectl -n $NS wait --for=condition=complete --timeout=600s job/$JOB_NAME || {
  echo "❌ Migration job failed. Logs:"
  kubectl logs job/$JOB_NAME -n $NS
  exit 1
}

echo "✅ Migration completed successfully!"
echo "📊 Current pod status:"
kubectl get pods -n $NS -o wide
