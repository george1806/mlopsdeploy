#!/bin/bash
set -euo pipefail

NS=airflow-cv
echo "🔹 Patching securityContext for Airflow components in namespace: $NS"

patch_and_rollout() {
  KIND=$1
  NAME=$2
  PATCH=$3

  if kubectl get $KIND $NAME -n $NS >/dev/null 2>&1; then
    echo "➡️  Patching $KIND/$NAME"
    kubectl patch $KIND $NAME -n $NS --type='json' -p="$PATCH"

    # echo "🔄 Waiting for rollout of $KIND/$NAME..."
    # if [ "$KIND" = "deployment" ]; then
    #   kubectl rollout status deployment/$NAME -n $NS
    # elif [ "$KIND" = "statefulset" ]; then
    #   kubectl rollout status statefulset/$NAME -n $NS
    # fi
  else
    echo "⚠️  Skipping $KIND/$NAME (not found)"
  fi
}

# --- API Server ---
patch_and_rollout deployment airflow-cv-api-server '[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{
    "seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000
  }},
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }}
]'

# --- Scheduler (main + log-groomer) ---
patch_and_rollout deployment airflow-cv-scheduler '[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{
    "seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000
  }},
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }},
  {"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }}
]'

# --- DAG Processor (main + log-groomer) ---
patch_and_rollout deployment airflow-cv-dag-processor '[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{
    "seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000
  }},
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }},
  {"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }}
]'

# --- Worker (main + log-groomer) ---
patch_and_rollout statefulset airflow-cv-worker '[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{
    "seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000
  }},
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }},
  {"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }}
]'

# --- Triggerer (main + log-groomer) ---
patch_and_rollout statefulset airflow-cv-triggerer '[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{
    "seccompProfile":{"type":"RuntimeDefault"},"fsGroup":1000
  }},
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }},
  {"op":"add","path":"/spec/template/spec/containers/1/securityContext","value":{
    "runAsUser":50000,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }}
]'

# --- StatsD (nobody user) ---
patch_and_rollout deployment airflow-cv-statsd '[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{
    "seccompProfile":{"type":"RuntimeDefault"},"fsGroup":65534
  }},
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser":65534,"runAsNonRoot":true,"allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }}
]'

echo "✅ Finished patching and rolling out Airflow components"
echo "📊 Current pod status:"
kubectl get pods -n $NS -o wide
