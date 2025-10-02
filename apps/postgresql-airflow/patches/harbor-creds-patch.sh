

kubectl patch statefulset postgresql-airflow -n databases-airflow \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/imagePullSecrets","value":[{"name":"harbor-creds"}]}]'
