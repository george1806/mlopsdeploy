#!/bin/bash
set -euo pipefail

NS=airflow-cv
RELEASE=airflow-cv

echo "👉 Uninstalling Helm release"
helm uninstall $RELEASE -n $NS || true

echo "👉 Deleting namespace"
kubectl delete ns $NS --ignore-not-found=true

echo "👉 Waiting for namespace deletion..."
kubectl wait ns/$NS --for=delete --timeout=120s || true

echo "👉 Cleanup PVCs"
kubectl get pvc -A | grep $NS | awk '{print $2}' | while read pvc; do
  kubectl delete pvc $pvc -n $NS --ignore-not-found=true
done

echo "👉 Cleanup leftover secrets/configmaps"
kubectl get secret -A | grep $NS | awk '{print $2}' | while read sec; do
  kubectl delete secret $sec -n $NS --ignore-not-found=true
done
kubectl get cm -A | grep $NS | awk '{print $2}' | while read cm; do
  kubectl delete cm $cm -n $NS --ignore-not-found=true
done

echo "✅ Airflow completely removed. Ready for fresh deploy."
