#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage : %s BASE_URL\n' "$0" >&2
    exit 64
fi

base_url=${1%/}
repertoire_temporaire=$(mktemp -d)
trap 'rm -rf "$repertoire_temporaire"' EXIT

# Ce script vérifie le shell réellement servi : trouver cette ressource dans trois
# réponses HTTP prouve que les routes profondes ne sont pas des 404 masquées par une
# inspection statique de la configuration nginx.
marqueur_flutter='flutter_bootstrap.js'
marqueur_reference=''

verifier_route() {
    local route=$1
    local fichier=$2
    local statut
    local marqueur

    statut=$(curl --silent --show-error --output "$fichier" --write-out '%{http_code}' \
        "$base_url$route")

    if [[ $statut != 200 ]]; then
        printf 'Échec : %s répond HTTP %s (attendu : 200).\n' "$route" "$statut" >&2
        return 1
    fi

    if ! grep --fixed-strings --quiet "$marqueur_flutter" "$fichier"; then
        printf 'Échec : %s ne contient pas le shell Flutter attendu.\n' "$route" >&2
        return 1
    fi

    marqueur=$(grep --fixed-strings --max-count=1 --only-matching "$marqueur_flutter" "$fichier")
    if [[ -z $marqueur_reference ]]; then
        marqueur_reference=$marqueur
    elif [[ $marqueur != "$marqueur_reference" ]]; then
        printf 'Échec : %s ne porte pas le même marqueur Flutter que /.\n' "$route" >&2
        return 1
    fi

    printf 'HTTP 200 : %s — shell Flutter %s\n' "$route" "$marqueur"
}

verifier_route / "$repertoire_temporaire/racine.html"
verifier_route /join/JETON-RECETTE "$repertoire_temporaire/join.html"
verifier_route /rejoindre/PLAN-K7M2X9 "$repertoire_temporaire/rejoindre.html"
