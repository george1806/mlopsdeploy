# Secret issue > Patch the StatefulSet

```sh
kubectl patch statefulset redis-airflow-master \
  -n databases-airflow \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/imagePullSecrets","value":[{"name":"harbor-creds"}]}]'
```
