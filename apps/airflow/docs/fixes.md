# Secret issue > Patch the StatefulSet

```sh
kubectl patch statefulset redis-airflow-master \
  -n databases-airflow \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/imagePullSecrets","value":[{"name":"harbor-creds"}]}]'
```

# Patch env values to a deployment

```sh
kubectl patch deployment airflow-cv-api-server -n airflow-cv \
  --type='strategic' \
  -p='{
    "spec": {
      "template": {
        "spec": {
          "containers": [
            {
              "name": "api-server",
              "env": [
                {
                  "name": "KEYCLOAK_INTERNAL_HOST",
                  "value": "http://dev-keycloak.keycloak-dev.svc.cluster.local:8080"
                }
              ]
            }
          ]
        }
      }
    }
  }'
```

# Patch keycloak values

```sh
kubectl patch deployment airflow-cv-api-server -n airflow-cv \
  --type='strategic' \
  -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "api-server",
            "env": [
              {
                "name": "KEYCLOAK_HOST",
                "value": "http://keycloak.dev.vtz.corp"
              },
              {
                "name": "AIRFLOW__WEBSERVER__OAUTH_PROVIDERS",
                "value": "[{\"name\": \"keycloak\", \"token_key\": \"access_token\", \"icon\": \"fa-key\", \"remote_app\": {\"client_id\": \"airflow-client\", \"client_secret\": \"cEqzPLsNObqKGzHsrsxF1ziYGuoJifnG\", \"api_base_url\": \"http://keycloak.dev.vtz.corp/realms/mlops/protocol/openid-connect/\", \"client_kwargs\": {\"scope\": \"openid email profile\"}, \"access_token_method\": \"POST\", \"access_token_params\": {\"grant_type\": \"authorization_code\"}, \"request_token_url\": null, \"access_token_url\": \"http://keycloak.dev.vtz.corp/realms/mlops/protocol/openid-connect/token\", \"authorize_url\": \"http://keycloak.dev.vtz.corp/realms/mlops/protocol/openid-connect/auth\"}}]"
              }
            ]
          }
        ]
      }
    }
  }
}'


```
