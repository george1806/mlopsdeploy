NS=databases-airflow
STS=redis-airflow-master

kubectl patch statefulset $STS -n $NS --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/securityContext","value":{
    "seccompProfile":{"type":"RuntimeDefault"},
    "fsGroup":1001
  }},
  {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{
    "runAsUser":1001,
    "runAsNonRoot":true,
    "allowPrivilegeEscalation":false,
    "capabilities":{"drop":["ALL"]}
  }}
]'


kubectl rollout status statefulset/$STS -n $NS
kubectl get pods -n $NS -o wide | grep redis