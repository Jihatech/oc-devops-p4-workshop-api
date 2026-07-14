# Journal de l'IA — workshop-api (Spring Boot)

Ce document trace les tâches confiées à l'assistant IA (Claude Code), la revue humaine
effectuée et les correctifs appliqués, conformément aux exigences du parcours.

| Date | Tâche confiée à l'IA | Revue / Vérification | Correctif / Décision |
|---|---|---|---|
| 2026-07-13 | Rédiger le `Dockerfile` multi-stage (build Gradle → image finale JRE). | Vérifié que l'image finale est bien une **JRE** (`eclipse-temurin:21-jre`) et non un JDK : `javac` absent du conteneur. Image = 557 MB. | Échec au 1er build : `./gradlew: not found` dans le conteneur → **fins de ligne CRLF** (clone Windows) cassant le shebang. Ajout de `sed -i 's/\r$//' gradlew` avant `chmod +x`, et d'un `.gitattributes` (`gradlew text eol=lf`). |
| 2026-07-13 | Compléter `docker-compose.yml` : ajout du volume nommé, du healthcheck PostgreSQL et de `depends_on: condition: service_healthy`. | `docker compose up -d` : séquence observée `db Waiting → Healthy → app Starting` — l'ordonnancement fonctionne. Volume `workshop-api_workshop_pgdata` créé. | Healthcheck via `pg_isready -U workshops_user -d workshopsdb`. Packaging via `bootWar` (l'app publie un WAR exécutable). |
| 2026-07-13 | Vérifier l'accès API sur `:8080`. | Logs : `HikariPool connected`, `Tomcat started on port 8080`, `Started ... in 2.28 s`. Endpoints `/workshops` `/notions` renvoient **404** — normal : le starter OC génère les **interfaces** d'API seulement (`interfaceOnly: true`), sans implémentation de contrôleur. Le serveur répond bien (JSON Spring). | Aucun ; comportement inhérent à l'application fournie par OpenClassrooms. |

## Exercice 2 — Script de tests + CI GitHub Actions

| Date | Tâche confiée à l'IA | Revue / Vérification | Correctif / Décision |
|---|---|---|---|
| 2026-07-13 | Écrire `run-tests.sh` (auto-détection, JUnit XML dans `test-results/`, codes de sortie). | **Testé en local** : détection `java`, `./gradlew clean test` (2 classes PASSED), copie des XML `build/test-results/test/*.xml` → `test-results/`, exit 0. | `set -euo pipefail` pour propager les échecs ; codes dédiés (2 type inconnu, 3 dépendance, 4 pas de rapport). |
| 2026-07-13 | Workflow réutilisable `ci-reusable.yml` (`workflow_call`) + appelant `ci.yml`. | YAML validé (parse OK). Détection Java/Angular dans le job `test`. | Choix : workflow réutilisable **identique** dans les 2 repos (partie factorisée) + appelant identique. Documenté dans le README. |
| 2026-07-13 | Stage build : push GHCR, tag `branche-sha`. | Références calculées avec **owner en minuscules** (contrainte GHCR). Cache `type=gha`. | Login via `GITHUB_TOKEN` (`packages: write`). |
| 2026-07-13 | Stage release : semantic-release (changelog, release GitHub, image en version sémantique, version synchronisée). | `.releaserc.json` validé. `@semantic-release/exec` : `$OWNER_LC`/`$IMAGE_NAME` en variables **shell** (sans accolades) pour ne pas entrer en collision avec le template `${nextRelease.version}` du plugin. | Déclenchement **auto sur push main** (choix documenté). `[skip ci]` sur le commit de release pour éviter la boucle. |

## Points de vigilance retenus

- Ne jamais committer de secret : les identifiants BDD de `docker-compose.yml` sont des valeurs de
  **développement local** ; en Kubernetes ils passeront par des `Secret` (Exercice 3), en CI par le
  `GITHUB_TOKEN` intégré (aucun PAT à créer).
- Le build Docker exclut les tests (`-x test`) : ils sont exécutés séparément dans la CI (Exercice 2).
- La validation « pipeline vert de bout en bout » se fait après le push sur GitHub (Actions).

### Résultat CI (2026-07-14, après push sur `main`)

- Pipeline **vert de bout en bout** : `test` ✅ → `build` ✅ → `release` ✅.
- **Release GitHub `1.0.0`** créée automatiquement + tag `1.0.0` + `CHANGELOG.md` généré.
- Version **synchronisée** : `build.gradle` → `version = '1.0.0'` (commit `chore(release): 1.0.0 [skip ci]`).
- Image poussée sur GHCR : `ghcr.io/jihatech/oc-devops-p4-workshop-api` (tags `branche-sha`, `1.0.0`, `latest`).

## Exercice 3 — Kubernetes & Helm

| Date | Tâche confiée à l'IA | Revue / Vérification | Correctif / Décision |
|---|---|---|---|
| 2026-07-14 | Compléter les TODO `k8s/` (image, secret password, PVC, imagePullSecrets). | Déployé sur **Minikube** : pods `Running`, PVC `Bound`, app connectée à PostgreSQL. | **URL datasource corrigée** : le TODO « check the datasource URL » pointait sur `workshop-organizer-db` alors que le Service s'appelle `workshop-organizer-db-service`. Ajout d'un `PGDATA` en sous-dossier (conflit `lost+found` du volume monté) et d'un `initContainer wait-for-db` pour l'ordre PostgreSQL → app. |
| 2026-07-14 | Créer le chart `workshop-api-chart` (app + PostgreSQL), valeurs extraites. | `helm lint` OK, `--dry-run --debug` conforme, `helm install` réel OK. | Noms de ressources préfixés par `.Release.Name` pour un DNS de service prévisible ; secret généré par le chart via `b64enc`. |
| 2026-07-14 | Multi-env `dev`/`staging` (values différenciées, secrets séparés). | Vérifié : dev = 1 replica, staging = 2 replicas ; mots de passe **distincts** (`dev-oc2024` vs `staging-Xk92mZ7q`). | staging tague l'image en **version sémantique 1.0.0**, dev en `latest`. Différences documentées dans `docs/DEPLOIEMENT_K8S.md`. |
