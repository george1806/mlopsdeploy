#!/bin/bash
set -euo pipefail

NS=airflow-cv
SECRET=harbor-creds

echo "👉 Patching Deployments in $NS"
for d in $(kubectl get deploy -n $NS -o name); do
  echo "  Patching $d"
  kubectl patch $d -n $NS --type='json' -p="[
    {\"op\":\"add\",\"path\":\"/spec/template/spec/imagePullSecrets\",\"value\":[{\"name\":\"$SECRET\"}]}
  ]" || true
done

echo "👉 Patching StatefulSets in $NS"
for s in $(kubectl get sts -n $NS -o name); do
  echo "  Patching $s"
  kubectl patch $s -n $NS --type='json' -p="[
    {\"op\":\"add\",\"path\":\"/spec/template/spec/imagePullSecrets\",\"value\":[{\"name\":\"$SECRET\"}]}
  ]" || true
done

echo "👉 Restarting workloads"
kubectl rollout restart deploy -n $NS
kubectl rollout restart sts -n $NS

echo "✅ Done. Watching pods..."
kubectl get pods -n $NS -w
