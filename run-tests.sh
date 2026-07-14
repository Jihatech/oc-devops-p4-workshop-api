#!/usr/bin/env bash
#
# run-tests.sh — script de tests unifié (identique dans les deux dépôts P4).
#
# Rôle :
#   1. détecte automatiquement le type de projet (build.gradle => Java, angular.json => Angular) ;
#   2. vérifie la présence des dépendances requises ;
#   3. nettoie les artefacts de tests précédents ;
#   4. lance les tests (Java : Gradle ; Angular : Karma headless) ;
#   5. normalise le rapport JUnit XML dans test-results/ ;
#   6. retourne un code de sortie explicite (0 = succès, != 0 = échec).
#
# Codes de sortie : 0 OK · 2 type inconnu · 3 dépendance manquante · 4 aucun rapport JUnit
set -euo pipefail

# On se place à la racine du projet (répertoire du script)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

RESULTS_DIR="test-results"

log()  { printf '\033[1;34m[run-tests]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[run-tests][ERREUR]\033[0m %s\n' "$*" >&2; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "Dépendance requise introuvable : $1"; exit 3; }
}

# --- 1. Détection du type de projet ---------------------------------------
if [[ -f build.gradle || -f build.gradle.kts ]]; then
  PROJECT_TYPE="java"
elif [[ -f angular.json ]]; then
  PROJECT_TYPE="angular"
else
  err "Type de projet non reconnu (ni build.gradle ni angular.json à la racine)."
  exit 2
fi
log "Type de projet détecté : ${PROJECT_TYPE}"

# --- 2. Nettoyage des artefacts précédents --------------------------------
log "Nettoyage des artefacts de tests précédents…"
rm -rf "${RESULTS_DIR}"
mkdir -p "${RESULTS_DIR}"

# --- 3. Exécution des tests selon le type ---------------------------------
case "${PROJECT_TYPE}" in
  java)
    require java
    log "Exécution des tests Gradle…"
    chmod +x ./gradlew 2>/dev/null || true
    ./gradlew --no-daemon clean test
    # Rapport JUnit produit par Gradle dans build/test-results/test/*.xml
    if compgen -G "build/test-results/test/*.xml" > /dev/null; then
      cp build/test-results/test/*.xml "${RESULTS_DIR}/"
    fi
    ;;

  angular)
    require node
    require npm
    log "Installation des dépendances (npm ci)…"
    if [[ -f package-lock.json ]]; then
      npm ci --no-audit --no-fund
    else
      npm install --no-audit --no-fund
    fi
    log "Exécution des tests Karma (Chrome headless, single run)…"
    npm test
    # karma-junit-reporter écrit dans reports/*.xml (cf. karma.conf.js)
    if compgen -G "reports/*.xml" > /dev/null; then
      cp reports/*.xml "${RESULTS_DIR}/"
    fi
    ;;
esac

# --- 4. Vérification qu'un rapport JUnit a bien été produit ----------------
if ! compgen -G "${RESULTS_DIR}/*.xml" > /dev/null; then
  err "Aucun rapport JUnit XML généré dans ${RESULTS_DIR}/."
  exit 4
fi

log "Rapport(s) JUnit disponible(s) dans ${RESULTS_DIR}/ :"
ls -1 "${RESULTS_DIR}"/*.xml
log "Tests terminés avec succès."
