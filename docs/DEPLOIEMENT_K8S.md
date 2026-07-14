# Déploiement Kubernetes & Helm — workshop-api

## 1. Manifestes bruts (`k8s/`) sur Minikube

```bash
minikube start --driver=docker

# (optionnel — l'image GHCR est publique) secret d'accès au registre
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io --docker-username=<user> --docker-password=<token>

kubectl apply -f k8s/
kubectl rollout status deploy/workshop-organizer-db-deployment
kubectl rollout status deploy/workshop-organizer-app-deployment
```

Ressources créées : `Secret` (identifiants BDD), `PersistentVolumeClaim` (persistance PostgreSQL),
`Deployment` PostgreSQL puis `Deployment` Spring Boot (un `initContainer wait-for-db` garantit que la
base est joignable avant le démarrage de l'app), et les deux `Service` associés.

> L'URL JDBC pointe vers le **Service** PostgreSQL (`workshop-organizer-db-service`), pas vers le pod.

## 2. Chart Helm (`helm/workshop-api-chart/`)

Le chart regroupe l'app **et** PostgreSQL. Tout ce qui varie est extrait dans `values.yaml` :
image/tag, replicas, ports, resources, taille du volume, identifiants BDD.

```bash
helm lint helm/workshop-api-chart
helm install workshop-api helm/workshop-api-chart --dry-run --debug
helm install workshop-api helm/workshop-api-chart -n <ns>
```

## 3. Multi-environnements (`dev` / `staging`)

Déploiement différencié via un fichier de valeurs par environnement :

```bash
# DEV
helm install workshop-api helm/workshop-api-chart \
  -f helm/workshop-api-chart/values-dev.yaml -n dev --create-namespace

# STAGING
helm install workshop-api helm/workshop-api-chart \
  -f helm/workshop-api-chart/values-staging.yaml -n staging --create-namespace
```

### Différences dev / staging

| Paramètre | `dev` | `staging` |
|---|---|---|
| Namespace | `dev` | `staging` |
| Replicas (app) | **1** | **2** |
| Tag d'image | `latest` | **`1.0.0`** (version sémantique) |
| Resources | limitées (requests 50m/192Mi) | élargies (requests 250m/384Mi) |
| Secret BDD (mot de passe) | `dev-oc2024` | `staging-Xk92mZ7q` (**distinct**, aucun credential partagé) |

Le secret est généré **par le chart dans chaque namespace** à partir de la valeur `db.password`
propre à l'environnement : les identifiants ne sont jamais partagés entre `dev` et `staging`.

### Validation réalisée

- `helm lint` : 0 échec sur les 2 charts.
- `helm install --dry-run --debug` : rendu conforme (replicas, tag, secret, URL datasource).
- `helm install` réel dans `dev` **et** `staging` : tous les pods `Running`, app connectée à sa BDD
  (`HikariPool - Start completed`, `Tomcat started on port 8080`), front olympic `HTTP 200`.
