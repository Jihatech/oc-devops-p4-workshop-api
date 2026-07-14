# Journal de l'IA — workshop-api (Spring Boot)

Ce document trace les tâches confiées à l'assistant IA (Claude Code), la revue humaine
effectuée et les correctifs appliqués, conformément aux exigences du parcours.

| Date | Tâche confiée à l'IA | Revue / Vérification | Correctif / Décision |
|---|---|---|---|
| 2026-07-13 | Rédiger le `Dockerfile` multi-stage (build Gradle → image finale JRE). | Vérifié que l'image finale est bien une **JRE** (`eclipse-temurin:21-jre`) et non un JDK : `javac` absent du conteneur. Image = 557 MB. | Échec au 1er build : `./gradlew: not found` dans le conteneur → **fins de ligne CRLF** (clone Windows) cassant le shebang. Ajout de `sed -i 's/\r$//' gradlew` avant `chmod +x`, et d'un `.gitattributes` (`gradlew text eol=lf`). |
| 2026-07-13 | Compléter `docker-compose.yml` : ajout du volume nommé, du healthcheck PostgreSQL et de `depends_on: condition: service_healthy`. | `docker compose up -d` : séquence observée `db Waiting → Healthy → app Starting` — l'ordonnancement fonctionne. Volume `workshop-api_workshop_pgdata` créé. | Healthcheck via `pg_isready -U workshops_user -d workshopsdb`. Packaging via `bootWar` (l'app publie un WAR exécutable). |
| 2026-07-13 | Vérifier l'accès API sur `:8080`. | Logs : `HikariPool connected`, `Tomcat started on port 8080`, `Started ... in 2.28 s`. Endpoints `/workshops` `/notions` renvoient **404** — normal : le starter OC génère les **interfaces** d'API seulement (`interfaceOnly: true`), sans implémentation de contrôleur. Le serveur répond bien (JSON Spring). | Aucun ; comportement inhérent à l'application fournie par OpenClassrooms. |

## Points de vigilance retenus

- Ne jamais committer de secret : les identifiants BDD de `docker-compose.yml` sont des valeurs de
  **développement local** ; en Kubernetes ils passeront par des `Secret` (Exercice 3), en CI par des
  variables/Secrets GitHub.
- Le build Docker exclut les tests (`-x test`) : ils sont exécutés séparément dans la CI (Exercice 2).
