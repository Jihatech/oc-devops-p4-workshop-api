# syntax=docker/dockerfile:1

# ---------- Stage 1 : build Gradle (JDK complet nécessaire) ----------
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace

# Wrapper + fichiers de build d'abord (couche cachée = téléchargement des deps réutilisable)
COPY gradlew ./
COPY gradle ./gradle
COPY settings.gradle build.gradle system.properties ./
# Normalise les fins de ligne (le repo peut être cloné en CRLF sous Windows) puis rend exécutable
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew
RUN ./gradlew --no-daemon dependencies > /dev/null 2>&1 || true

# Code source puis packaging (WAR exécutable Spring Boot). Tests exclus : joués dans la CI.
COPY src ./src
RUN ./gradlew --no-daemon clean bootWar -x test

# ---------- Stage 2 : image finale JRE (PAS de JDK) ----------
FROM eclipse-temurin:21-jre
WORKDIR /app

# Utilisateur non-root
RUN groupadd --system spring && useradd --system --gid spring spring
USER spring:spring

COPY --from=build /workspace/build/libs/*.war app.war

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.war"]
